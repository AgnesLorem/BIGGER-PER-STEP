--!strict
-- ReceiptProcessingService.luau
-- Infrastructure service that handles MarketplaceService.ProcessReceipt on the server.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")

local Logger = require(script.Parent.Parent.Utilities.Logger)
local PlayerProfileSchema = require(script.Parent.Parent.Utilities.PlayerProfileSchema)
local ServiceRegistry = require(script.Parent.Parent.Registry.ServiceRegistry)
local Profiles = require(script.Parent.Parent.Registry.RuntimeRegistry.Profiles)
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

local function GetSaveService()
	return ServiceRegistry.Get("SaveService")
end

local function CountTrackedPurchases(
	PurchaseHistory: { [string]: boolean },
	PendingPurchaseIds: { [string]: boolean }
): number
	local Count = 0
	for _ in PurchaseHistory do
		Count += 1
	end
	for PurchaseId in PendingPurchaseIds do
		if not PurchaseHistory[PurchaseId] then
			Count += 1
		end
	end
	return Count
end

local function ProcessReceipt(receiptInfo: ReceiptInfo): Enum.ProductPurchaseDecision
	local purchaseId = receiptInfo.PurchaseId
	local userId = receiptInfo.PlayerId
	if not PlayerProfileSchema.IsPurchaseId(purchaseId) then
		Logger.Warn("Receipt", "Invalid transaction id received for UserId %d.", userId)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

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

	-- 1. Check runtime cache first to prevent double-spending in retry loops
	if session.PurchaseHistory[purchaseId] then
		Logger.Info(
			"Receipt",
			"Duplicate purchase check: transaction %s already processed in session cache for %s. Granting purchase.",
			purchaseId,
			player.Name
		)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local runtimeProfile = Profiles.Get(userId)
	local SaveService = GetSaveService()
	if not runtimeProfile or session.ProfileMutationsFrozen or not SaveService:IsProfileWritable(player) then
		Logger.Info(
			"Receipt",
			"Profile is not writable for %s. Returning NotProcessedYet for transaction %s.",
			player.Name,
			purchaseId
		)
		return Enum.ProductPurchaseDecision.NotProcessedYet
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
		Logger.Warn(
			"Receipt",
			"Unknown ProductId %d for transaction %s. Returning NotProcessedYet.",
			receiptInfo.ProductId,
			purchaseId
		)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if runtimeProfile.PendingPurchaseIds[purchaseId] then
		local Success, Durable = pcall(SaveService.CommitTransaction, SaveService, player, {
			PurchaseId = purchaseId,
			Rewards = targetConfig.Rewards,
		})
		return if Success and Durable
			then Enum.ProductPurchaseDecision.PurchaseGranted
			else Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if
		CountTrackedPurchases(session.PurchaseHistory, runtimeProfile.PendingPurchaseIds)
		>= PlayerProfileSchema.MaximumProcessedPurchaseIds
	then
		Logger.Warn(
			"Critical",
			"Receipt history capacity reached for UserId %d; transaction %s was not admitted.",
			userId,
			purchaseId
		)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- 3. Call RewardService to grant the product rewards
	runtimeProfile.PendingPurchaseIds[purchaseId] = true
	local RewardService = GetRewardService()
	local grantSuccess, grantResult = pcall(RewardService.Grant, RewardService, player, {
		Rewards = targetConfig.Rewards,
		Source = "DeveloperProduct",
		TransactionId = purchaseId,
		AnalyticsKey = targetConfig.AnalyticsKey,
	})

	if not grantSuccess or not grantResult.Success then
		runtimeProfile.PendingPurchaseIds[purchaseId] = nil
		Logger.Warn(
			"Receipt",
			"Failed to grant developer product rewards for %s: %s (Transaction: %s). Returning NotProcessedYet.",
			player.Name,
			tostring(if grantSuccess then grantResult.ErrorCode else grantResult),
			purchaseId
		)
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local persistSuccess, Durable = pcall(SaveService.CommitTransaction, SaveService, player, {
		PurchaseId = purchaseId,
		Rewards = targetConfig.Rewards,
	})
	if persistSuccess and Durable then
		Logger.Info(
			"Receipt",
			"Developer Product purchase processed successfully for %s: %s (Product: %s, Transaction: %s)",
			player.Name,
			targetConfig.AnalyticsKey,
			productKey,
			purchaseId
		)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	Logger.Warn(
		"Receipt",
		"Failed to persist developer product transaction %s for %s. Returning NotProcessedYet.",
		purchaseId,
		player.Name
	)
	return Enum.ProductPurchaseDecision.NotProcessedYet
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
