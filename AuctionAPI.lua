local addonName, BOD = ...

BOD.AuctionAPI = {
    auctionHouseOpen = false,
    itemInfoCache = {},
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

function BOD.AuctionAPI:CanQuery()
    local family = self:GetFamily()
    if family == "legacy" then
        local canQuery, canQueryAll, detail = self:GetQueryReadiness()
        if canQuery then
            return true, "legacy query ready; full scan ready=" .. tostring(canQueryAll)
        end
        return false, detail or "legacy query cooldown"
    end

    if family == "modern" then
        return false, "modern C_AuctionHouse detected but not implemented for this milestone"
    end

    return false, "auction query API unavailable"
end

function BOD.AuctionAPI:GetQueryReadiness()
    if self:GetFamily() ~= "legacy" then
        return false, false, "legacy Auction House API unavailable"
    end
    if not isFunction("CanSendAuctionQuery") then
        return false, false, "CanSendAuctionQuery unavailable"
    end

    local ok, canQuery, canQueryAll = pcall(CanSendAuctionQuery)
    if not ok then
        return false, false, "CanSendAuctionQuery error"
    end
    return canQuery and true or false, canQueryAll == true, "queryReady=" .. tostring(canQuery) .. ", fullScanReady=" .. tostring(canQueryAll)
end

function BOD.AuctionAPI:CanFullScan()
    local canQuery, canQueryAll, detail = self:GetQueryReadiness()
    if canQuery and canQueryAll then
        return true, "legacy full scan ready; fullScanReady=" .. tostring(canQueryAll)
    end
    return false, "legacy full scan cooldown; " .. tostring(detail)
end

function BOD.AuctionAPI:SendFullScanProbe()
    local family = self:GetFamily()
    if family ~= "legacy" then
        return false, "Only legacy full-scan probing is implemented"
    end
    if not isFunction("QueryAuctionItems") then
        return false, "QueryAuctionItems unavailable"
    end

    -- The 2.5.6 legacy browse frame can briefly ask for the get-all sentinel quality.
    if type(ITEM_QUALITY_COLORS) == "table" and not ITEM_QUALITY_COLORS[-1] then
        ITEM_QUALITY_COLORS[-1] = { r = 0, g = 0, b = 0 }
    end

    local signature = [[QueryAuctionItems("", nil, nil, 0, nil, nil, true, false, nil)]]
    local ok, errorMessage = pcall(QueryAuctionItems, "", nil, nil, 0, nil, nil, true, false, nil)
    if not ok then
        return false, tostring(errorMessage), signature
    end
    return true, "legacy getAll probe query sent", signature
end

function BOD.AuctionAPI:SendTargetedSearch(itemName)
    if self:GetFamily() ~= "legacy" or not isFunction("QueryAuctionItems") then
        return false, "Legacy targeted search is unavailable."
    end
    local canQuery = self:GetQueryReadiness()
    if canQuery ~= true then return false, "Auction search is on cooldown." end
    itemName = type(itemName) == "string" and itemName:gsub("^%s+", ""):gsub("%s+$", "") or ""
    if itemName == "" then return false, "An exact item name is required." end
    local signature = [[QueryAuctionItems(itemName, nil, nil, 0, nil, nil, false, false, nil)]]
    local ok, errorMessage = pcall(QueryAuctionItems, itemName, nil, nil, 0, nil, nil, false, false, nil)
    if not ok then return false, tostring(errorMessage), signature end
    return true, "Targeted item search sent.", signature
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

function BOD.AuctionAPI:ResetResultCache()
    self.itemInfoCache = {}
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

    stackCount = tonumber(stackCount) or 0
    buyoutTotal = tonumber(buyoutTotal) or 0

    local resolvedItemID = tonumber(itemID) or getItemIDFromLink(itemLink)
    local infoName, itemType, itemSubType, maxStack, equipSlot, vendorPrice
    local cachedInfo = resolvedItemID and self.itemInfoCache[resolvedItemID] or nil
    if cachedInfo then
        infoName = cachedInfo.name
        itemType = cachedInfo.itemType
        itemSubType = cachedInfo.itemSubType
        maxStack = cachedInfo.maxStack
        equipSlot = cachedInfo.equipSlot
        vendorPrice = cachedInfo.vendorPrice
    elseif isFunction("GetItemInfo") then
        local infoOk, resolvedName, _, _, _, _, resolvedType, resolvedSubType, resolvedMaxStack, resolvedEquipSlot, _, resolvedVendorPrice =
            pcall(GetItemInfo, itemLink or resolvedItemID)
        if infoOk then
            infoName = resolvedName
            itemType = resolvedType
            itemSubType = resolvedSubType
            maxStack = tonumber(resolvedMaxStack)
            equipSlot = resolvedEquipSlot
            vendorPrice = tonumber(resolvedVendorPrice)
            if resolvedItemID and resolvedName and maxStack and maxStack > 0 then
                self.itemInfoCache[resolvedItemID] = {
                    name = infoName,
                    itemType = itemType,
                    itemSubType = itemSubType,
                    maxStack = maxStack,
                    equipSlot = equipSlot,
                    vendorPrice = vendorPrice,
                }
            end
        end
    end

    local result = {
        index = index,
        name = name or infoName,
        itemLink = itemLink,
        itemID = resolvedItemID,
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
        saleStatus = saleStatus,
        hasAllInfo = hasAllInfo,
        itemType = itemType,
        itemSubType = itemSubType,
        maxStack = maxStack,
        equipSlot = equipSlot,
        vendorPrice = vendorPrice,
    }

    if buyoutTotal > 0 and stackCount > 0 then
        result.buyoutPerUnit = math.floor(buyoutTotal / stackCount)
    end

    return result
end
