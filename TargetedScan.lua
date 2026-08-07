local addonName, BOD = ...

BOD.TargetedScan = { active = false, token = 0 }

local function now()
    return type(time) == "function" and time() or os.time()
end

local function median(values)
    table.sort(values)
    if #values == 0 then return nil end
    local middle = math.floor((#values + 1) / 2)
    return #values % 2 == 1 and values[middle] or math.floor((values[middle] + values[middle + 1]) / 2)
end

local function weightedMedian(samples)
    table.sort(samples, function(left, right) return left.price < right.price end)
    local total = 0
    for _, sample in ipairs(samples) do total = total + sample.quantity end
    local threshold, seen = math.floor((total + 1) / 2), 0
    for _, sample in ipairs(samples) do
        seen = seen + sample.quantity
        if seen >= threshold then return sample.price end
    end
end

function BOD.TargetedScan:Start(itemKey, itemName, itemID)
    if self.active then return false, "Another targeted check is already running." end
    if BOD.FullScanProbe and BOD.FullScanProbe.active then return false, "Wait for the full scan to finish." end
    if not BOD.AuctionAPI:IsAuctionHouseOpen() then return false, "Open the Auction House first." end
    if type(itemKey) ~= "string" or itemKey == "" or type(itemName) ~= "string" or itemName == "" then return false, "Choose an item first." end
    self.active, self.itemKey, self.itemName, self.itemID = true, itemKey, itemName, tonumber(itemID)
    self.token = self.token + 1
    local token = self.token
    local ok, message = BOD.AuctionAPI:SendTargetedSearch(itemName)
    if not ok then
        self.active = false
        self.token = self.token + 1
        return false, message
    end
    if C_Timer and type(C_Timer.After) == "function" then
        C_Timer.After(15, function()
            if self.active and self.token == token then self:Finish(nil, "Targeted item check timed out.") end
        end)
    end
    return true, "Checking current listings for " .. itemName .. "."
end

function BOD.TargetedScan:BuildItem()
    local prices, weighted = {}, {}
    local lowest, bestStack, bestTotal, listingCount, totalQuantity, sample
    listingCount, totalQuantity = 0, 0
    for index = 1, BOD.AuctionAPI:GetResultCount() do
        local result = BOD.AuctionAPI:GetResult(index)
        local sameID = self.itemID and result and tonumber(result.itemID) == self.itemID
        local sameName = result and tostring(result.name or ""):lower() == tostring(self.itemName):lower()
        local quantity, total = result and tonumber(result.stackCount), result and tonumber(result.buyoutTotal)
        if (sameID or (not self.itemID and sameName)) and quantity and quantity > 0 and total and total > 0 then
            local unit = math.floor(total / quantity)
            if unit > 0 then
                listingCount, totalQuantity = listingCount + 1, totalQuantity + quantity
                prices[#prices + 1] = unit
                weighted[#weighted + 1] = { price = unit, quantity = quantity }
                if not lowest or unit < lowest or (unit == lowest and total < bestTotal) then
                    lowest, bestStack, bestTotal = unit, quantity, total
                end
                sample = sample or result
            end
        end
    end
    if listingCount == 0 then return nil end
    return {
        itemKey = self.itemKey, itemID = self.itemID or sample.itemID, itemName = self.itemName,
        lowestUnitBuyout = lowest, bestListingStackCount = bestStack, bestListingBuyoutTotal = bestTotal,
        medianUnitBuyout = median(prices), weightedMedianUnitBuyout = weightedMedian(weighted),
        totalQuantity = totalQuantity, listingCount = listingCount, sampleCount = listingCount,
        vendorPrice = tonumber(sample.vendorPrice) or 0, maxStack = tonumber(sample.maxStack) or 1, equipSlot = sample.equipSlot,
        targetedValidationAt = now(), source = "TARGETED_ITEM",
    }
end

function BOD.TargetedScan:Finish(item, errorMessage)
    self.active = false
    self.token = self.token + 1
    if item then
        BOD.MarketData:RecordTargetedOverlay(self.itemKey, item, item.targetedValidationAt)
        self.lastMessage = self.itemName .. " checked against current Auction House results."
    else
        if BOD.MarketData and BOD.MarketData.ClearTargetedOverlay then BOD.MarketData:ClearTargetedOverlay(self.itemKey) end
        self.lastMessage = errorMessage or "No current buyout listings were found for " .. tostring(self.itemName) .. "."
    end
    if BOD.TradeService then BOD.TradeService:Invalidate() end
    if BOD.Sidecar then BOD.Sidecar:Refresh() end
    return item
end

function BOD.TargetedScan:OnEvent(event)
    if event == "AUCTION_ITEM_LIST_UPDATE" and self.active then
        self:Finish(self:BuildItem())
    elseif event == "AUCTION_HOUSE_CLOSED" and self.active then
        self:Finish(nil, "Targeted item check stopped because the Auction House closed.")
    end
end
