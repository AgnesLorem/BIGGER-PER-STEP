--!strict
-- RewardDispatcher.luau
-- Helper utility responsible strictly for executing valid rewards (SRP).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServiceRegistry = require(script.Parent.Parent.Registry.ServiceRegistry)

local RewardType = require(ReplicatedStorage:WaitForChild("BiggerShared"):WaitForChild("Core"):WaitForChild("Enums"):WaitForChild("RewardType"))
local RewardError = require(ReplicatedStorage:WaitForChild("BiggerShared"):WaitForChild("Core"):WaitForChild("Enums"):WaitForChild("RewardError"))

export type Reward = {
	Type: string,
	Amount: number?,
	[string]: any,
}

export type DispatchResult = {
	Success: boolean,
	ErrorCode: string?,
	AppliedRewards: {Reward}?,
	FailedReward: Reward?,
}

-- Registry lookup helpers
local function GetGrowthService()
	return ServiceRegistry.Get("GrowthService")
end

-- Frozen mapping table of reward executors
local Handlers = table.freeze({
	[RewardType.Bigger] = function(Player: Player, Reward: Reward): boolean
		local GrowthService = GetGrowthService()
		if not GrowthService then
			return false
		end
		GrowthService:AddBiggerAbsolute(Player, Reward.Amount or 0)
		return true
	end,
	
	-- Stub handlers for other reward types (for extensibility)
	[RewardType.Coins] = function(Player: Player, Reward: Reward): boolean
		-- CurrencyService or similar would be called here
		return true
	end,
	[RewardType.Aura] = function(Player: Player, Reward: Reward): boolean
		return true
	end,
	[RewardType.Boost] = function(Player: Player, Reward: Reward): boolean
		return true
	end,
	[RewardType.Item] = function(Player: Player, Reward: Reward): boolean
		return true
	end,
})

local RewardDispatcher = {}

function RewardDispatcher.Dispatch(Player: Player, Rewards: {Reward}): DispatchResult
	local appliedRewards = {}
	
	for _, reward in ipairs(Rewards) do
		local handler = Handlers[reward.Type]
		if not handler then
			return {
				Success = false,
				ErrorCode = RewardError.UnknownReward,
				FailedReward = reward,
			}
		end
		
		local success = false
		local ok, err = pcall(function()
			success = handler(Player, reward)
		end)
		
		if not ok or not success then
			return {
				Success = false,
				ErrorCode = RewardError.DispatcherFailed,
				FailedReward = reward,
			}
		end
		
		table.insert(appliedRewards, reward)
	end
	
	return {
		Success = true,
		AppliedRewards = appliedRewards,
	}
end

return RewardDispatcher
