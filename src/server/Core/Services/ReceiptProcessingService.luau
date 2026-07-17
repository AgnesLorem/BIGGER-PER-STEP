--!strict
-- ReceiptProcessingService.luau
-- Infrastructure service that handles MarketplaceService.ProcessReceipt on the server.
-- Uses PurchaseState enum for idempotent receipt processing with persistent profile checks.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Logger = require(script.Parent.Parent.Utilities.Logger)
local ServiceRegistry = require(script.Parent.Parent.Registry.ServiceRegistry)
local Sessions = require(script.Parent.Parent.Registry.RuntimeRegistry.Sessions)
local DeveloperProductConfig = require(script.Parent.Parent.Config.DeveloperProductConfig)
local PurchaseState = require(ReplicatedStorage:WaitForChild("BiggerShared"):WaitForChild("Core"):WaitForChild("Enums"):WaitForChild("PurchaseState"))

--// Types \\--

type ReceiptInfo = {
	PlayerId: number,
	PlaceIdAssociatedWithPurchase: number,
	ProductId: number,
	PurchaseId: string,
	CurrencyType: Enum.CurrencyType,
	CurrencySpent: number,
}

--// Service \\--

local ReceiptProcessingService = {}

local function GetRewardService()
	return ServiceRegistry.Get("RewardService")
end

local function ProcessReceipt(receiptInfo: ReceiptInfo): Enum.ProductPurchaseDecision
	local purchaseId = receiptInfo.PurchaseId
	local userId = receiptInfo.PlayerId

	local player = Players:GetPlayerByUserId(userId)
	if not player then
		Logger.Info(
			"Receipt",
			"Player with UserId %d not found in server. Returning NotProcessedYet for transaction %s.",
			userId,
			purchaseId
		)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local session = Sessions.Get(player)
	if not session then
		Logger.Info(
			"Receipt",
			"Session not loaded yet for %s. Returning NotProcessedYet for transaction %s.",
			player.Name,
			purchaseId
		)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- 1. Check in-memory session cache for completed transactions
	if session.PurchaseHistory[purchaseId] == PurchaseState.Completed then
		Logger.Info(
			"Receipt",
			"Duplicate purchase check: transaction %s already completed in session cache for %s. Granting purchase.",
			purchaseId,
			player.Name
		)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- 2. Check persistent profile data (source of truth)
	local SaveService = ServiceRegistry.Get("SaveService")
	if SaveService then
		local profile = SaveService:LoadProfile(player)
		if profile and profile.ProcessedPurchaseIds[purchaseId] then
			session.PurchaseHistory[purchaseId] = PurchaseState.Completed
			Logger.Info("Receipt", "Transaction %s found in Profile ProcessedPurchaseIds for %s. Syncing cache and granting.", purchaseId, player.Name)
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end
	end

	-- 3. Lookup configuration by ProductId
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
		Logger.Warn(
			"Receipt",
			"Unknown ProductId %d for transaction %s. Returning NotProcessedYet.",
			receiptInfo.ProductId,
			purchaseId
		)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- 4. Call RewardService to grant the product rewards (handles dispatch + persistence)
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
		Logger.Info(
			"Receipt",
			"Developer Product purchase processed successfully for %s: %s (Product: %s, Transaction: %s)",
			player.Name,
			targetConfig.AnalyticsKey,
			productKey,
			purchaseId
		)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	else
		Logger.Warn(
			"Receipt",
			"Failed to grant developer product rewards for %s: %s (Transaction: %s). Returning NotProcessedYet.",
			player.Name,
			tostring(grantResult.ErrorCode),
			purchaseId
		)
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
