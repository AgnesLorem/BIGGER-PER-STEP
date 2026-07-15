--!strict
-- RewardService.luau
-- Central entrypoint service for all gameplay rewards.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logger = require(script.Parent.Parent.Utilities.Logger)
local ServiceRegistry = require(script.Parent.Parent.Registry.ServiceRegistry)
local Sessions = require(script.Parent.Parent.Registry.RuntimeRegistry.Sessions)

local RewardType = require(ReplicatedStorage:WaitForChild("BiggerShared"):WaitForChild("Core"):WaitForChild("Enums"):WaitForChild("RewardType"))
local RewardError = require(ReplicatedStorage:WaitForChild("BiggerShared"):WaitForChild("Core"):WaitForChild("Enums"):WaitForChild("RewardError"))
local DeveloperProductConfig = require(script.Parent.Parent.Config.DeveloperProductConfig)
local RewardDispatcher = require(script.Parent.Parent.Utilities.RewardDispatcher)

type Reward = RewardDispatcher.Reward

export type GrantOptions = {
	Rewards: {Reward},
	Source: string,
	TransactionId: string,
	AnalyticsKey: string,
}

export type GrantResult = {
	Success: boolean,
	ErrorCode: string?,
	AppliedRewards: {Reward}?,
	FailedReward: Reward?,
}

local RewardService = {}

function RewardService:Init() end
function RewardService:Start() end

function RewardService:Preview(ProductKey: string): {Reward}?
	local config = DeveloperProductConfig[ProductKey]
	return config and config.Rewards
end

function RewardService:Grant(Player: Player, Options: GrantOptions): GrantResult
	-- 1. Validate payload
	if not Player or not Player:IsDescendantOf(game:GetService("Players")) then
		return { Success = false, ErrorCode = RewardError.InvalidPayload }
	end

	local session = Sessions.Get(Player)
	if not session then
		return { Success = false, ErrorCode = RewardError.InvalidPayload }
	end

	local transactionId = Options.TransactionId
	if not transactionId or typeof(transactionId) ~= "string" or string.len(transactionId) == 0 then
		return { Success = false, ErrorCode = RewardError.InvalidPayload }
	end

	local rewards = Options.Rewards
	if not rewards or typeof(rewards) ~= "table" or #rewards == 0 then
		return { Success = false, ErrorCode = RewardError.InvalidPayload }
	end

	-- Check for duplicate transaction cache
	if session.PurchaseHistory[transactionId] then
		-- Giao dịch đã được ghi nhận trong bộ nhớ trước đó (có thể là retry sau khi save thất bại)
		-- Bỏ qua bước Dispatch (không cấp lại vật phẩm để tránh nhân đôi) và chuyển thẳng sang bước ghi nhận lưu trữ.
		Logger.Info("Reward", "Transaction %s already dispatched in memory cache for %s. Bypassing dispatch.", transactionId, Player.Name)
	else
		-- 2. Dispatch rewards in memory (mutates memory stats)
		local dispatchResult = RewardDispatcher.Dispatch(Player, rewards)
		if not dispatchResult.Success then
			Logger.Warn("Reward", "Failed to dispatch rewards for %s: %s", Player.Name, tostring(dispatchResult.ErrorCode))
			return {
				Success = false,
				ErrorCode = dispatchResult.ErrorCode,
				FailedReward = dispatchResult.FailedReward,
			}
		end

		-- 3. Update runtime session cache IMMEDIATELY after dispatching
		session.PurchaseHistory[transactionId] = true
		Logger.Info("Reward", "Successfully dispatched rewards in memory for %s (Transaction: %s)", Player.Name, transactionId)
	end

	-- 4. Persistently save profile data via SaveService
	local SaveService = ServiceRegistry.Get("SaveService")
	if not SaveService then
		Logger.Error("Reward", "SaveService not found in ServiceRegistry, cannot commit transaction %s", transactionId)
		return { Success = false, ErrorCode = RewardError.PersistenceFailed }
	end

	local persistSuccess = SaveService:CommitTransaction(Player, {
		PurchaseId = transactionId,
		Rewards = rewards,
	})

	if not persistSuccess then
		Logger.Warn("Reward", "SaveService failed to commit transaction %s for %s", transactionId, Player.Name)
		return { Success = false, ErrorCode = RewardError.PersistenceFailed }
	end

	-- 5. Write structured audit log
	local rewardsStringList = {}
	for _, reward in ipairs(rewards) do
		local desc = reward.Type .. " " .. (reward.Amount and ("+" .. tostring(reward.Amount)) or "")
		table.insert(rewardsStringList, desc)
	end
	
	print(string.format(
		"[Purchase]\nPlayer=%s\nProductSource=%s\nTransactionId=%s\nRewards=%s\nTime=%s",
		Player.Name,
		Options.Source,
		transactionId,
		table.concat(rewardsStringList, ", "),
		DateTime.now():FormatUniversalTime("YYYY-MM-DD HH:mm:ss", "en-us")
	))

	return {
		Success = true,
		AppliedRewards = rewards,
	}
end

return RewardService
