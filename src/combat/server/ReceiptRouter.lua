local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local ReceiptRouter = {}

local handlersByProductId = {}
local processedPurchaseIds = {}
local warnedUnknownProductIds = {}
local started = false

local function processReceipt(receiptInfo)
	local purchaseId = tostring(receiptInfo.PurchaseId)
	if processedPurchaseIds[purchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local productId = tonumber(receiptInfo.ProductId) or 0
	local handler = handlersByProductId[productId]
	if not handler then
		if not warnedUnknownProductIds[productId] then
			warnedUnknownProductIds[productId] = true
			warn(("[ReceiptRouter] No handler registered for ProductId %d."):format(productId))
		end
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
	if not player then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ok, granted = pcall(handler, receiptInfo, player)
	if not ok then
		warn(("[ReceiptRouter] ProductId %d handler failed: %s"):format(productId, tostring(granted)))
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if granted == false then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	processedPurchaseIds[purchaseId] = true
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function ReceiptRouter.RegisterProduct(productId, handler)
	local normalizedProductId = math.floor(tonumber(productId) or 0)
	if normalizedProductId <= 0 then
		return false
	end

	if type(handler) ~= "function" then
		error("Receipt handler must be a function.", 2)
	end

	local existing = handlersByProductId[normalizedProductId]
	if existing and existing ~= handler then
		error(("ProductId %d already has a receipt handler."):format(normalizedProductId), 2)
	end

	handlersByProductId[normalizedProductId] = handler
	return true
end

function ReceiptRouter.Start()
	if started then
		return
	end

	started = true
	MarketplaceService.ProcessReceipt = processReceipt
end

return ReceiptRouter
