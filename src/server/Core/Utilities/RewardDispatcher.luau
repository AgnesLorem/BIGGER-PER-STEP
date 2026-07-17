--!strict
-- RewardDispatcher.luau
-- Two-phase reward executor: validates ALL rewards first, then applies atomically.
-- Prevents partial bundle application on validation failure.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServiceRegistry = require(script.Parent.Parent.Registry.ServiceRegistry)

local RewardType = require(
	ReplicatedStorage:WaitForChild("BiggerShared"):WaitForChild("Core"):WaitForChild("Enums"):WaitForChild("RewardType")
)
local RewardError = require(
	ReplicatedStorage:WaitForChild("BiggerShared")
		:WaitForChild("Core")
		:WaitForChild("Enums")
		:WaitForChild("RewardError")
)
local Sessions = require(script.Parent.Parent.Registry.RuntimeRegistry.Sessions)

--// Types \\--

export type Reward = {
	Type: string,
	Amount: number?,
	[string]: any,
}

export type DispatchResult = {
	Success: boolean,
	ErrorCode: string?,
	AppliedRewards: { Reward }?,
	FailedReward: Reward?,
}

--// Helpers \\--

local function GetGrowthService()
	return ServiceRegistry.Get("GrowthService")
end

-- Validation-only checks (no side effects)
local Validators = table.freeze({
	[RewardType.Bigger] = function(Player: Player, Reward: Reward): (boolean, string?)
		if not GetGrowthService() then return false, "GrowthService unavailable" end
		if not Reward.Amount or Reward.Amount <= 0 then return false, "Invalid Bigger amount" end
		return true, nil
	end,
	[RewardType.Coins] = function(_Player: Player, _Reward: Reward): (boolean, string?)
		return true, nil
	end,
	[RewardType.Aura] = function(_Player: Player, _Reward: Reward): (boolean, string?)
		return true, nil
	end,
	[RewardType.Boost] = function(_Player: Player, _Reward: Reward): (boolean, string?)
		return true, nil
	end,
	[RewardType.Item] = function(_Player: Player, _Reward: Reward): (boolean, string?)
		return true, nil
	end,
	[RewardType.DoubleMultiplier] = function(Player: Player, _Reward: Reward): (boolean, string?)
		local session = Sessions.Get(Player)
		if not session then return false, "No session" end
		return true, nil
	end,
	[RewardType.Vip] = function(Player: Player, _Reward: Reward): (boolean, string?)
		local session = Sessions.Get(Player)
		if not session then return false, "No session" end
		return true, nil
	end,
})

-- Apply-only handlers (mutate state; called only after full validation passes)
local Appliers = table.freeze({
	[RewardType.Bigger] = function(Player: Player, Reward: Reward)
		local GrowthService = GetGrowthService()
		GrowthService:AddBiggerAbsolute(Player, Reward.Amount or 0)
	end,
	[RewardType.Coins] = function(_Player: Player, _Reward: Reward)
		-- CurrencyService stub
	end,
	[RewardType.Aura] = function(_Player: Player, _Reward: Reward)
	end,
	[RewardType.Boost] = function(_Player: Player, _Reward: Reward)
	end,
	[RewardType.Item] = function(_Player: Player, _Reward: Reward)
	end,
	[RewardType.DoubleMultiplier] = function(Player: Player, _Reward: Reward)
		local session = Sessions.Get(Player)
		if not session then return end
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
	end,
	[RewardType.Vip] = function(Player: Player, _Reward: Reward)
		local session = Sessions.Get(Player)
		if not session then return end
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
			task.spawn(function()
				CharacterScaleService:UpdateVipTag(Player)
			end)
		end
	end,
})

--// Service \\--

local RewardDispatcher = {}

function RewardDispatcher.Validate(Player: Player, Rewards: {Reward}): (boolean, string?, Reward?)
	for _, reward in ipairs(Rewards) do
		local validator = Validators[reward.Type]
		if not validator then
			return false, RewardError.UnknownReward, reward
		end
		local pcallOk, valid, validErr = pcall(validator, Player, reward)
		if not pcallOk then
			return false, RewardError.DispatcherFailed, reward
		end
		if not valid then
			return false, validErr or RewardError.DispatcherFailed, reward
		end
	end
	return true, nil, nil
end

function RewardDispatcher.Apply(Player: Player, Rewards: {Reward})
	for _, reward in ipairs(Rewards) do
		local applier = Appliers[reward.Type]
		if applier then
			applier(Player, reward)
		end
	end
end

function RewardDispatcher.Dispatch(Player: Player, Rewards: {Reward}): DispatchResult
	local valid, err, failedReward = RewardDispatcher.Validate(Player, Rewards)
	if not valid then
		return {
			Success = false,
			ErrorCode = err,
			FailedReward = failedReward,
		}
	end

	RewardDispatcher.Apply(Player, Rewards)

	return {
		Success = true,
		AppliedRewards = Rewards,
	}
end

return RewardDispatcher
