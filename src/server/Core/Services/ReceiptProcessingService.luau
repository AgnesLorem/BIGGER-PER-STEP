--!strict
-- ReceiptProcessingService.luau
-- Infrastructure service that handles MarketplaceService.ProcessReceipt on the server.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Logger = require(script.Parent.Parent.Utilities.Logger)
local ServiceRegistry = require(script.Parent.Parent.Registry.ServiceRegistry)
local Sessions = require(script.Parent.Parent.Registry.RuntimeRegistry.Sessions)
local DeveloperProductConfig = require(script.Parent.Parent.Config.DeveloperProductConfig)

type ReceiptInfo = {
	PlayerId: number,
	PlaceIdAssociatedWithPurchase: number,
	ProductId: number,
	PurchaseId: string,
	CurrencyType: Enum.CurrencyType,
	CurrencySpent: number,
}

local ReceiptProcessingService = {}

local function GetRewardService()
	return ServiceRegistry.Get("RewardService")
end

local function ProcessReceipt(receiptInfo: ReceiptInfo): Enum.ProductPurchaseDecision
	local purchaseId = receiptInfo.PurchaseId
	local userId = receiptInfo.PlayerId

	local player = Players:GetPlayerByUserId(userId)
	if not player then
		Logger.Info("Receipt", "Player with UserId %d not found in server. Returning NotProcessedYet for transaction %s.", userId, purchaseId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local session = Sessions.Get(player)
	if not session then
		Logger.Info("Receipt", "Session not loaded yet for %s. Returning NotProcessedYet for transaction %s.", player.Name, purchaseId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- 1. Check runtime cache first to prevent double-spending in retry loops
	if session.PurchaseHistory[purchaseId] then
		Logger.Info("Receipt", "Duplicate purchase check: transaction %s already processed in session cache for %s. Granting purchase.", purchaseId, player.Name)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- 2. Lookup configuration by ProductId
	local targetConfig = nil
	local productKey = nil
	for key, config in pairs(DeveloperProductConfig) do
		if config.ProductId == receiptInfo.ProductId then
			targetConfig = config
			productKey = key
			break
		end
	end

	if not targetConfig then
		Logger.Warn("Receipt", "Unknown ProductId %d for transaction %s. Returning NotProcessedYet.", receiptInfo.ProductId, purchaseId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- 3. Call RewardService to grant the product rewards
	local RewardService = GetRewardService()
	if not RewardService then
		Logger.Error("Receipt", "RewardService not found in ServiceRegistry, cannot process transaction %s", purchaseId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local grantResult = RewardService:Grant(player, {
		Rewards = targetConfig.Rewards,
		Source = "DeveloperProduct",
		TransactionId = purchaseId,
		AnalyticsKey = targetConfig.AnalyticsKey,
	})

	if grantResult.Success then
		Logger.Info("Receipt", "Developer Product purchase processed successfully for %s: %s (Product: %s, Transaction: %s)", player.Name, targetConfig.AnalyticsKey, productKey, purchaseId)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	else
		Logger.Warn("Receipt", "Failed to grant developer product rewards for %s: %s (Transaction: %s). Returning NotProcessedYet.", player.Name, tostring(grantResult.ErrorCode), purchaseId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
end

function ReceiptProcessingService:Init()
	local success, err = pcall(function()
		MarketplaceService.ProcessReceipt = ProcessReceipt
	end)

	if not success then
		Logger.Error("Receipt", "Failed to register ProcessReceipt callback: %s", tostring(err))
	else
		Logger.Info("Receipt", "ProcessReceipt callback registered successfully")
	end
end

function ReceiptProcessingService:Start() end

return ReceiptProcessingService
