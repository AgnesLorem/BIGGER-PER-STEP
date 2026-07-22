--!strict
-- RewardDispatcher.luau
-- Helper utility responsible strictly for executing valid rewards (SRP).

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

-- Registry lookup helpers
local function GetGrowthService()
	return ServiceRegistry.Get("GrowthService")
end

local function GetDestructionService()
	return ServiceRegistry.Get("DestructionService")
end

-- Frozen mapping table of reward executors
local Handlers = table.freeze({
	[RewardType.Bigger] = function(Player: Player, Reward: Reward): boolean
		local GrowthService = GetGrowthService()
		if not GrowthService then
			return false
		end
		local Session = Sessions.Get(Player)
		if not Session then
			return false
		end
		local ExpectedBigger = math.floor(Session.Bigger + (Reward.Amount or 0))
		local Called, Applied = pcall(GrowthService.AddBiggerAbsolute, GrowthService, Player, Reward.Amount or 0)
		if Called then
			return Applied == true
		end
		local CurrentSession = Sessions.Get(Player)
		return CurrentSession ~= nil and CurrentSession.Bigger == ExpectedBigger
	end,
	[RewardType.Destruction] = function(Player: Player, Reward: Reward): boolean
		local DestructionService = GetDestructionService()
		return DestructionService ~= nil and DestructionService:GrantDestruction(Player, Reward.Amount or 0) == true
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
		local Mutated = Sessions.Mutate(Player, function(Session)
			Session.HasDoubleMultiplier = true
		end)
		if Mutated then
			pcall(function()
				local GrowthService = GetGrowthService()
				if GrowthService then
					GrowthService:UpdateMultiplierAttribute(Player)
				end
			end)
		end
		return Mutated
	end,
	[RewardType.Vip] = function(Player: Player, _Reward: Reward): boolean
		local Mutated = Sessions.Mutate(Player, function(Session)
			Session.HasVip = true
		end)
		if Mutated then
			pcall(function()
				local GrowthService = GetGrowthService()
				if GrowthService then
					GrowthService:UpdateMultiplierAttribute(Player)
				end
			end)
			pcall(function()
				local CharacterScaleService = ServiceRegistry.Get("CharacterScaleService")
				if CharacterScaleService then
					CharacterScaleService:UpdateVipTag(Player)
				end
			end)
		end
		return Mutated
	end,
})

local RewardDispatcher = {}

function RewardDispatcher.Dispatch(Player: Player, Rewards: { Reward }): DispatchResult
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
