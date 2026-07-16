--!strict
-- RewardDispatcher.luau
-- Helper utility responsible strictly for executing valid rewards (SRP).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServiceRegistry = require(script.Parent.Parent.Registry.ServiceRegistry)

local RewardType = require(ReplicatedStorage:WaitForChild("BiggerShared"):WaitForChild("Core"):WaitForChild("Enums"):WaitForChild("RewardType"))
local RewardError = require(ReplicatedStorage:WaitForChild("BiggerShared"):WaitForChild("Core"):WaitForChild("Enums"):WaitForChild("RewardError"))
local Sessions = require(script.Parent.Parent.Registry.RuntimeRegistry.Sessions)

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
	[RewardType.Coins] = function(_Player: Player, _Reward: Reward): boolean
		-- CurrencyService or similar would be called here
		return true
	end,
	[RewardType.Aura] = function(_Player: Player, _Reward: Reward): boolean
		return true
	end,
	[RewardType.Boost] = function(_Player: Player, _Reward: Reward): boolean
		return true
	end,
	[RewardType.Item] = function(_Player: Player, _Reward: Reward): boolean
		return true
	end,
	[RewardType.DoubleMultiplier] = function(Player: Player, _Reward: Reward): boolean
		local session = Sessions.Get(Player)
		if session then
			session.HasDoubleMultiplier = true
			local SaveService = ServiceRegistry.Get("SaveService")
			if SaveService then
				local profile = SaveService:LoadProfile(Player)
				if profile then
					profile.HasDoubleMultiplier = true
				end
			end
			local GrowthService = GetGrowthService()
			if GrowthService then
				GrowthService:UpdateMultiplierAttribute(Player)
			end
		end
		return true
	end,
	[RewardType.Vip] = function(Player: Player, _Reward: Reward): boolean
		local session = Sessions.Get(Player)
		if session then
			session.HasVip = true
			local SaveService = ServiceRegistry.Get("SaveService")
			if SaveService then
				local profile = SaveService:LoadProfile(Player)
				if profile then
					profile.HasVip = true
				end
			end
			local GrowthService = GetGrowthService()
			if GrowthService then
				GrowthService:UpdateMultiplierAttribute(Player)
			end
			local CharacterScaleService = ServiceRegistry.Get("CharacterScaleService")
			if CharacterScaleService then
				CharacterScaleService:UpdateVipTag(Player)
			end
		end
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
		local ok = pcall(function()
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
