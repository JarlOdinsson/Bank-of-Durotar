local addonName, BOD = ...

BOD.RecommendationPolicy = {}

local DEFAULT_MAX_AGE_SECONDS = 86400
local TRUST_RANK = { AVOID = 0, SPECULATIVE = 1, FAIR = 2, STRONG = 3 }

local RISK_TEXT = {
    INVALID_DATA = "Required market data is missing.",
    OLD_MARKET_DATA = "Old market data",
    NO_EXPECTED_PROFIT = "Expected profit is not positive.",
    BELOW_MINIMUM_PROFIT = "Expected profit is below your minimum.",
    PRICE_ABOVE_SAFE_LIMIT = "Current price is above the safe buy price.",
    VENDOR_VALUE_DOMINATES = "Vendor value makes this Auction House flip misleading.",
    RELISTING_ERASES_PROFIT = "Deposit and relisting costs erase the opportunity.",
    INSUFFICIENT_DATA = "There is not enough reliable market data.",
    PRICE_MAY_BE_MANIPULATED = "Price may be manipulated",
    OWNED_EXPOSURE_REACHED = "You already own enough in your bags.",
    LOW_HISTORICAL_CONFIDENCE = "Low historical confidence",
    HIGH_DEPOSIT_COST = "High deposit cost",
    PROFIT_DEPENDS_ON_RELISTING = "Profit depends on relisting",
    OWNED_INVENTORY = "You already own items in your bags",
    CURRENT_PRICE_NEAR_MAXIMUM = "Current listing is near the maximum buy price",
    THIN_CURRENT_SUPPLY = "Thin current supply",
    LOW_ABSOLUTE_PROFIT = "Low absolute profit",
    MARKET_CAN_CHANGE = "Market conditions can change",
    PRICE_CHANGED = "The scanned price is no longer safe.",
    SCAN_REQUIRED = "Run a new scan before buying.",
    BUDGET_TOO_LOW = "The safe stack costs more than the available budget.",
    POOR_PERSONAL_SALES = "This item has usually expired for you.",
}

local function wholeNumber(value)
    local number = tonumber(value)
    if not number or number ~= number or number < 0 or number == math.huge then return nil end
    return math.floor(number)
end

local function signedWholeNumber(value)
    local number = tonumber(value)
    if not number or number ~= number or number == math.huge or number == -math.huge then return nil end
    return number >= 0 and math.floor(number) or math.ceil(number)
end

local function reject(code)
    return {
        actionable = false,
        trustLabel = "AVOID",
        rejectionCode = code,
        mainRiskCode = code,
        mainRisk = RISK_TEXT[code] or RISK_TEXT.INVALID_DATA,
        recommendedPurchaseQuantity = 0,
    }
end

-- Primary risk order is intentionally deterministic and safety-first:
-- manipulation, weak history, deposit exposure, relisting dependence, owned
-- inventory, price headroom, thin supply, low absolute profit, then general risk.
local function choosePrimaryRisk(candidate, minimumProfit)
    local current = tonumber(candidate.currentUnitPrice) or 0
    local reference = tonumber(candidate.referenceUnitPrice) or 0
    local historyCount = wholeNumber(candidate.historyObservationCount) or 0
    local historyDays = wholeNumber(candidate.historyDayCount) or 0
    local grossSale = wholeNumber(candidate.grossSale) or 0
    local deposit = wholeNumber(candidate.estimatedDeposit) or 0
    local expectedProfit = wholeNumber(candidate.expectedNetProfit) or 0
    local conservativeProfit = wholeNumber(candidate.conservativeNetProfit) or 0
    local owned = wholeNumber(candidate.ownedQuantity) or 0
    local maximum = wholeNumber(candidate.maximumSafeUnitPrice) or 0
    local listings = wholeNumber(candidate.listingCount) or 0
    local quantity = wholeNumber(candidate.totalMarketQuantity) or 0

    if reference > 0 and current > 0 and current < (reference * 0.35) then return "PRICE_MAY_BE_MANIPULATED" end
    if historyCount < 5 or historyDays < 3 then return "LOW_HISTORICAL_CONFIDENCE" end
    if grossSale > 0 and deposit >= (grossSale * 0.10) then return "HIGH_DEPOSIT_COST" end
    if expectedProfit > 0 and conservativeProfit < (expectedProfit * 0.5) then return "PROFIT_DEPENDS_ON_RELISTING" end
    if owned > 0 then return "OWNED_INVENTORY" end
    if maximum > 0 and current >= (maximum * 0.90) then return "CURRENT_PRICE_NEAR_MAXIMUM" end
    if listings < 3 or quantity < 5 then return "THIN_CURRENT_SUPPLY" end
    if conservativeProfit < (minimumProfit * 2) then return "LOW_ABSOLUTE_PROFIT" end
    return "MARKET_CAN_CHANGE"
end

function BOD.RecommendationPolicy:GetRiskText(code)
    return RISK_TEXT[code] or RISK_TEXT.INVALID_DATA
end

function BOD.RecommendationPolicy:Evaluate(candidate, options)
    candidate = type(candidate) == "table" and candidate or {}
    options = type(options) == "table" and options or {}
    local minimumProfit = wholeNumber(options.minimumExpectedProfitCopper) or 0
    local maximumAge = wholeNumber(options.maximumAgeSeconds) or DEFAULT_MAX_AGE_SECONDS
    local current = wholeNumber(candidate.currentUnitPrice)
    local maximum = wholeNumber(candidate.maximumSafeUnitPrice)
    local expectedProfit = signedWholeNumber(candidate.expectedNetProfit)
    local conservativeProfit = signedWholeNumber(candidate.conservativeNetProfit)
    local purchaseQuantity = wholeNumber(candidate.purchaseQuantity)
    local capital = wholeNumber(candidate.capitalRequired)
    local age = wholeNumber(candidate.dataAgeSeconds)
    local confidence = tostring(candidate.confidence or "NONE"):upper()
    local historyCount = wholeNumber(candidate.historyObservationCount) or 0
    local historyDays = wholeNumber(candidate.historyDayCount) or 0
    local listings = wholeNumber(candidate.listingCount) or 0
    local sampleCount = wholeNumber(candidate.sampleCount) or 0
    local owned = wholeNumber(candidate.ownedQuantity) or 0
    local reference = wholeNumber(candidate.referenceUnitPrice) or 0
    local vendorValue = wholeNumber(candidate.vendorValue) or 0
    local expectedNetSale = wholeNumber(candidate.expectedNetSale) or 0

    if not current or current <= 0 or not maximum or maximum <= 0 or not expectedProfit
        or not conservativeProfit or not purchaseQuantity or purchaseQuantity <= 0 or not capital or capital <= 0 or age == nil
    then
        return reject("INVALID_DATA")
    elseif age > maximumAge then
        return reject("OLD_MARKET_DATA")
    elseif expectedProfit <= 0 then
        return reject("NO_EXPECTED_PROFIT")
    elseif conservativeProfit <= 0 then
        return reject("RELISTING_ERASES_PROFIT")
    elseif conservativeProfit < minimumProfit then
        return reject("BELOW_MINIMUM_PROFIT")
    elseif current > maximum then
        return reject("PRICE_ABOVE_SAFE_LIMIT")
    elseif vendorValue > 0 and expectedNetSale > 0 and vendorValue >= expectedNetSale then
        return reject("VENDOR_VALUE_DOMINATES")
    elseif confidence == "NONE" or confidence == "LOW" or sampleCount < 6 then
        return reject("INSUFFICIENT_DATA")
    elseif reference > 0 and current < (reference * 0.20) and (historyCount < 5 or historyDays < 3) then
        return reject("PRICE_MAY_BE_MANIPULATED")
    elseif owned >= purchaseQuantity then
        local result = reject("OWNED_EXPOSURE_REACHED")
        result.ownedQuantity = owned
        return result
    end

    -- Classic listings are normally indivisible. Only subtract owned units when a
    -- caller explicitly knows the suggested quantity can be assembled from singles.
    local recommendedPurchaseQuantity = purchaseQuantity
    if candidate.supportsPartialPurchase == true and owned > 0 then
        recommendedPurchaseQuantity = math.max(0, purchaseQuantity - owned)
    end

    local trustLabel = "SPECULATIVE"
    if confidence == "HIGH" and age <= 21600 and historyDays >= 3 and historyCount >= 5
        and listings >= 5 and conservativeProfit >= (minimumProfit * 2) and current <= (maximum * 0.85)
    then
        trustLabel = "STRONG"
    elseif (confidence == "HIGH" or confidence == "MEDIUM") and historyCount >= 2 and listings >= 3 then
        trustLabel = "FAIR"
    end

    local riskCode = choosePrimaryRisk(candidate, minimumProfit)
    return {
        actionable = true,
        trustLabel = trustLabel,
        rejectionCode = nil,
        mainRiskCode = riskCode,
        mainRisk = RISK_TEXT[riskCode],
        ownedQuantity = owned,
        recommendedPurchaseQuantity = recommendedPurchaseQuantity,
    }
end

function BOD.RecommendationPolicy:IsBetterOpportunity(left, right)
    if not right then return true end
    local leftTrust = TRUST_RANK[tostring(left and left.trustLabel or "AVOID"):upper()] or 0
    local rightTrust = TRUST_RANK[tostring(right and right.trustLabel or "AVOID"):upper()] or 0
    if leftTrust ~= rightTrust then return leftTrust > rightTrust end
    local leftOwned = wholeNumber(left and left.ownedQuantity) or 0
    local rightOwned = wholeNumber(right and right.ownedQuantity) or 0
    if leftOwned ~= rightOwned then return leftOwned < rightOwned end
    local leftProfit = wholeNumber(left and left.conservativeNetProfit) or 0
    local rightProfit = wholeNumber(right and right.conservativeNetProfit) or 0
    if leftProfit ~= rightProfit then return leftProfit > rightProfit end
    local leftCapital = wholeNumber(left and left.capitalRequired) or 0
    local rightCapital = wholeNumber(right and right.capitalRequired) or 0
    if leftCapital ~= rightCapital then return leftCapital < rightCapital end
    local leftScore = wholeNumber(left and left.flipScore) or 0
    local rightScore = wholeNumber(right and right.flipScore) or 0
    if leftScore ~= rightScore then return leftScore > rightScore end
    return tostring(left and (left.itemName or left.itemKey) or "") < tostring(right and (right.itemName or right.itemKey) or "")
end

function BOD.RecommendationPolicy:CheckFreshness(recommendation, currentItem, snapshot, nowValue, maximumAgeSeconds)
    if type(recommendation) ~= "table" or type(currentItem) ~= "table" or type(snapshot) ~= "table" then
        return { safe = false, state = "SCAN_REQUIRED", message = RISK_TEXT.SCAN_REQUIRED }
    end
    local observedAt = wholeNumber(snapshot.observationTimestamp or snapshot.completedAt)
    local currentTime = wholeNumber(nowValue)
    local maximumAge = wholeNumber(maximumAgeSeconds) or DEFAULT_MAX_AGE_SECONDS
    local maximumPrice = wholeNumber(recommendation.maximumSafeUnitPrice)
    local currentPrice = wholeNumber(currentItem.lowestUnitBuyout)
    if not observedAt or not currentTime or not maximumPrice or maximumPrice <= 0 or not currentPrice or currentPrice <= 0 then
        return { safe = false, state = "SCAN_REQUIRED", message = RISK_TEXT.SCAN_REQUIRED }
    elseif math.max(0, currentTime - observedAt) > maximumAge then
        return { safe = false, state = "STALE", message = "Market data is too old. Run a new scan before buying." }
    elseif currentPrice > maximumPrice then
        return { safe = false, state = "PRICE_CHANGED", message = RISK_TEXT.PRICE_CHANGED }
    end
    local currentSnapshotId = snapshot.scanId or snapshot.id
    local changedSnapshot = recommendation.snapshotId and currentSnapshotId and recommendation.snapshotId ~= currentSnapshotId
    return {
        safe = true,
        state = changedSnapshot and "UPDATED_SAFE" or "SAFE_AT_SCAN_TIME",
        currentUnitPrice = currentPrice,
        message = changedSnapshot and "The newest scan is still below the safe limit." or "Safe in the latest scan; this is not a live price check.",
    }
end
