local addonName, BOD = ...

BOD.SalesHistory = {}

local SCHEMA_VERSION = 1
local MAX_TRACKED_ITEMS = 500

local function now()
    if type(time) == "function" then return time() end
    return os.time()
end

local function normalizeName(value)
    if type(value) ~= "string" then return "" end
    return value:lower():gsub("^%s+", ""):gsub("%s+$", "")
end

local function itemKeyFromLink(link)
    if type(link) ~= "string" then return nil end
    local itemString = link:match("Hitem:([^|%]]+)")
    if not itemString then return nil end
    local itemID = tonumber(itemString:match("^(%d+)"))
    local maxStack = type(GetItemInfo) == "function" and select(8, GetItemInfo(link)) or nil
    if itemID and tonumber(maxStack) and tonumber(maxStack) > 1 then
        return "item:" .. tostring(itemID)
    end
    return "itemString:" .. itemString
end

local function ensureDB()
    if not BOD.db then BOD:InitializeDatabase() end
    BOD.db.salesHistory = type(BOD.db.salesHistory) == "table" and BOD.db.salesHistory or {}
    local db = BOD.db.salesHistory
    local realmKey = BOD.MarketData and BOD.MarketData:GetRealmKey() or "unknown"
    if db.realmKey and db.realmKey ~= realmKey then
        db.items = {}
        db.mailboxCounts = {}
    end
    db.realmKey = realmKey
    db.schemaVersion = SCHEMA_VERSION
    db.items = type(db.items) == "table" and db.items or {}
    db.mailboxCounts = type(db.mailboxCounts) == "table" and db.mailboxCounts or {}
    return db
end

local function resolveKey(itemName, itemLink)
    local linkKey = itemKeyFromLink(itemLink)
    if linkKey then return linkKey end
    if BOD.MarketData and BOD.MarketData.FindExactItemByName then
        local item = BOD.MarketData:FindExactItemByName(itemName)
        if item and item.itemKey then return item.itemKey end
    end
    local name = normalizeName(itemName)
    return name ~= "" and ("name:" .. name) or nil
end

local function prune(db)
    local count = 0
    for _ in pairs(db.items) do count = count + 1 end
    while count > MAX_TRACKED_ITEMS do
        local oldestKey, oldestAt
        for key, item in pairs(db.items) do
            local updatedAt = tonumber(item.lastOutcomeAt) or 0
            if not oldestAt or updatedAt < oldestAt then oldestKey, oldestAt = key, updatedAt end
        end
        if not oldestKey then break end
        db.items[oldestKey] = nil
        count = count - 1
    end
end

local function addOutcome(db, key, itemName, sold, gross, net)
    if not key then return end
    local item = db.items[key]
    if not item then
        item = { itemKey = key, itemName = itemName, soldCount = 0, expiredCount = 0, grossRevenue = 0, netRevenue = 0 }
        db.items[key] = item
    end
    item.itemName = item.itemName or itemName
    item.lastOutcomeAt = now()
    if sold then
        item.soldCount = (tonumber(item.soldCount) or 0) + 1
        item.grossRevenue = (tonumber(item.grossRevenue) or 0) + math.max(0, tonumber(gross) or 0)
        item.netRevenue = (tonumber(item.netRevenue) or 0) + math.max(0, tonumber(net) or 0)
        item.lastSaleAt = item.lastOutcomeAt
    else
        item.expiredCount = (tonumber(item.expiredCount) or 0) + 1
        item.lastExpiredAt = item.lastOutcomeAt
    end
end

local function subjectMatches(subject, globalName)
    local template = _G[globalName]
    if type(subject) ~= "string" or type(template) ~= "string" then return false end
    local prefix = template:match("^(.-)%%[%d%$%.%-]*s") or template
    return prefix ~= "" and subject:sub(1, #prefix) == prefix
end

function BOD.SalesHistory:ScanMailbox()
    if type(GetInboxNumItems) ~= "function" or type(GetInboxHeaderInfo) ~= "function" then return end
    local db = ensureDB()
    local currentCounts = {}
    local records = {}
    local inboxCount = math.max(0, tonumber(GetInboxNumItems()) or 0)

    for index = 1, inboxCount do
        local header = { pcall(GetInboxHeaderInfo, index) }
        local headerOK = table.remove(header, 1)
        local sender = headerOK and header[3] or nil
        local subject = headerOK and header[4] or nil
        local money = headerOK and header[5] or nil
        local cod = headerOK and header[6] or nil
        local attachmentCount = headerOK and header[8] or nil
        money, cod = tonumber(money) or 0, tonumber(cod) or 0
        local invoiceType, itemName, playerName, bid, buyout, deposit, consignment
        if type(GetInboxInvoiceInfo) == "function" then
            local invoice = { pcall(GetInboxInvoiceInfo, index) }
            if table.remove(invoice, 1) then
                invoiceType, itemName, playerName, bid, buyout, deposit, consignment = unpack(invoice)
            end
        end
        if invoiceType == "seller" and type(itemName) == "string" and itemName ~= "" and money > 0 then
            local fingerprint = table.concat({ "sold", itemName, tostring(playerName or ""), tostring(bid or 0), tostring(buyout or 0), tostring(deposit or 0), tostring(consignment or 0), tostring(money) }, "|")
            currentCounts[fingerprint] = (currentCounts[fingerprint] or 0) + 1
            records[#records + 1] = { fingerprint = fingerprint, sold = true, name = itemName, gross = tonumber(buyout) or money, net = money }
        elseif (tonumber(attachmentCount) or 0) > 0 and cod == 0 and subjectMatches(subject, "AUCTION_EXPIRED_MAIL_SUBJECT") then
            local link = type(GetInboxItemLink) == "function" and GetInboxItemLink(index, 1) or nil
            local attachmentName = type(GetItemInfo) == "function" and link and GetItemInfo(link) or subject
            local fingerprint = table.concat({ "expired", tostring(sender or ""), tostring(subject or ""), tostring(link or "") }, "|")
            currentCounts[fingerprint] = (currentCounts[fingerprint] or 0) + 1
            records[#records + 1] = { fingerprint = fingerprint, sold = false, name = attachmentName, link = link }
        end
    end

    local seenThisPass = {}
    for _, record in ipairs(records) do
        local ordinal = (seenThisPass[record.fingerprint] or 0) + 1
        seenThisPass[record.fingerprint] = ordinal
        if ordinal > (tonumber(db.mailboxCounts[record.fingerprint]) or 0) then
            addOutcome(db, resolveKey(record.name, record.link), record.name, record.sold, record.gross, record.net)
        end
    end
    db.mailboxCounts = currentCounts
    db.lastMailboxScanAt = now()
    prune(db)
end

function BOD.SalesHistory:GetLearningStatus()
    local db = ensureDB()
    local sold, expired, items = 0, 0, 0
    for _, item in pairs(db.items) do
        sold = sold + (tonumber(item.soldCount) or 0)
        expired = expired + (tonumber(item.expiredCount) or 0)
        items = items + 1
    end
    return { soldCount = sold, expiredCount = expired, trackedItems = items, outcomeCount = sold + expired }
end

function BOD.SalesHistory:GetSummary(itemKey, itemName)
    local db = ensureDB()
    local item = type(itemKey) == "string" and db.items[itemKey] or nil
    if not item then item = db.items["name:" .. normalizeName(itemName)] end
    if not item then return { soldCount = 0, expiredCount = 0, outcomeCount = 0 } end
    local sold = tonumber(item.soldCount) or 0
    local expired = tonumber(item.expiredCount) or 0
    local outcomes = sold + expired
    return {
        soldCount = sold,
        expiredCount = expired,
        outcomeCount = outcomes,
        saleRate = outcomes > 0 and (sold / outcomes) or nil,
        grossRevenue = tonumber(item.grossRevenue) or 0,
        netRevenue = tonumber(item.netRevenue) or 0,
        lastSaleAt = item.lastSaleAt,
        lastExpiredAt = item.lastExpiredAt,
    }
end

function BOD.SalesHistory:OnEvent(event)
    if event == "MAIL_SHOW" or event == "MAIL_INBOX_UPDATE" then self:ScanMailbox() end
end
