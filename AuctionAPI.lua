local addonName, BOD = ...

BOD.AuctionAPI = {
    auctionHouseOpen = false,
}

local function isFunction(name)
    return type(_G[name]) == "function"
end

local function getItemIDFromLink(itemLink)
    if type(itemLink) ~= "string" then
        return nil
    end
    local itemID = itemLink:match("item:(%d+)")
    return tonumber(itemID)
end

function BOD.AuctionAPI:OnEvent(event)
    if event == "AUCTION_HOUSE_SHOW" then
        self.auctionHouseOpen = true
    elseif event == "AUCTION_HOUSE_CLOSED" then
        self.auctionHouseOpen = false
    end
end

function BOD.AuctionAPI:IsAuctionHouseOpen()
    if AuctionFrame and AuctionFrame.IsShown and AuctionFrame:IsShown() then
        return true
    end
    if AuctionHouseFrame and AuctionHouseFrame.IsShown and AuctionHouseFrame:IsShown() then
        return true
    end
    return self.auctionHouseOpen == true
end

function BOD.AuctionAPI:GetFamily()
    if isFunction("QueryAuctionItems") and isFunction("GetNumAuctionItems") and isFunction("GetAuctionItemInfo") then
        return "legacy"
    end
    if type(C_AuctionHouse) == "table" and type(C_AuctionHouse.SendSearchQuery) == "function" then
        return "modern"
    end
    return "unavailable"
end

function BOD.AuctionAPI:GetCapabilities()
    local canQuery, queryDetail = self:CanQuery()
    return {
        family = self:GetFamily(),
        ahOpen = self:IsAuctionHouseOpen(),
        canQuery = canQuery,
        queryDetail = queryDetail,
        legacyQuery = isFunction("QueryAuctionItems"),
        legacyCanQuery = isFunction("CanSendAuctionQuery"),
        legacyResults = isFunction("GetAuctionItemInfo"),
        modernAuctionHouse = type(C_AuctionHouse) == "table",
        modernSearch = type(C_AuctionHouse) == "table" and type(C_AuctionHouse.SendSearchQuery) == "function",
        fullScanAvailable = isFunction("QueryAuctionItems") and isFunction("CanSendAuctionQuery")
            or (type(C_AuctionHouse) == "table" and type(C_AuctionHouse.ReplicateItems) == "function"),
    }
end

function BOD.AuctionAPI:CanQuery()
    local family = self:GetFamily()
    if family == "legacy" then
        if not isFunction("CanSendAuctionQuery") then
            return false, "CanSendAuctionQuery unavailable"
        end

        local ok, canQuery, canQueryAll = pcall(CanSendAuctionQuery)
        if not ok then
            return false, "CanSendAuctionQuery error"
        end
        if canQuery then
            return true, "legacy query ready; full scan ready=" .. tostring(canQueryAll)
        end
        return false, "legacy query cooldown"
    end

    if family == "modern" then
        return false, "modern C_AuctionHouse detected but not implemented for this milestone"
    end

    return false, "auction query API unavailable"
end

function BOD.AuctionAPI:SendTargetedSearch(searchText)
    local family = self:GetFamily()
    if family ~= "legacy" then
        return false, "Only legacy targeted queries are implemented in this milestone"
    end
    if not isFunction("QueryAuctionItems") then
        return false, "QueryAuctionItems unavailable"
    end

    -- Legacy Classic search. The getAll argument is explicitly false; this targeted query never performs a full scan.
    local ok, errorMessage = pcall(QueryAuctionItems, searchText or "", nil, nil, 0, false, nil, false, false)
    if not ok then
        return false, tostring(errorMessage)
    end
    return true, "legacy targeted query sent"
end

function BOD.AuctionAPI:GetResultCount()
    if self:GetFamily() ~= "legacy" or not isFunction("GetNumAuctionItems") then
        return 0
    end

    local ok, listCount = pcall(GetNumAuctionItems, "list")
    if not ok then
        BOD:SetError("AuctionAPI", "GetNumAuctionItems failed: " .. tostring(listCount))
        return 0
    end
    return tonumber(listCount) or 0
end

function BOD.AuctionAPI:GetResult(index)
    if self:GetFamily() ~= "legacy" or not isFunction("GetAuctionItemInfo") then
        return nil
    end

    local ok, name, texture, stackCount, quality, canUse, requiredLevel, levelColHeader,
        minimumBid, minimumIncrement, buyoutTotal, currentBid, highBidder,
        bidderFullName, owner, ownerFullName, saleStatus, itemID, hasAllInfo =
        pcall(GetAuctionItemInfo, "list", index)

    if not ok then
        BOD:SetError("AuctionAPI", "GetAuctionItemInfo failed: " .. tostring(name))
        return nil
    end

    local itemLink
    if isFunction("GetAuctionItemLink") then
        local linkOk, link = pcall(GetAuctionItemLink, "list", index)
        if linkOk then
            itemLink = link
        end
    end

    local timeLeft
    if isFunction("GetAuctionItemTimeLeft") then
        local timeOk, value = pcall(GetAuctionItemTimeLeft, "list", index)
        if timeOk then
            timeLeft = value
        end
    end

    stackCount = tonumber(stackCount) or 0
    buyoutTotal = tonumber(buyoutTotal) or 0

    local result = {
        index = index,
        name = name,
        itemLink = itemLink,
        itemID = tonumber(itemID) or getItemIDFromLink(itemLink),
        texture = texture,
        stackCount = stackCount,
        quality = quality,
        requiredLevel = requiredLevel,
        minimumBid = tonumber(minimumBid) or 0,
        minimumIncrement = tonumber(minimumIncrement) or 0,
        buyoutTotal = buyoutTotal,
        currentBid = tonumber(currentBid) or 0,
        owner = owner,
        ownerFullName = ownerFullName,
        timeLeft = timeLeft,
        saleStatus = saleStatus,
        hasAllInfo = hasAllInfo,
    }

    if buyoutTotal > 0 and stackCount > 0 then
        result.buyoutPerUnit = math.floor(buyoutTotal / stackCount)
    end

    return result
end
