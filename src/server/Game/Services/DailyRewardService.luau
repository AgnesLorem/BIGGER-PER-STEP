--!strict
-- DailyRewardService.luau
-- Authoritative server service managing daily login rewards, cooldowns, and reward dispatching.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sessions = require(script.Parent.Parent.Parent.Core.Registry.RuntimeRegistry.Sessions)
local Logger = require(script.Parent.Parent.Parent.Core.Utilities.Logger)
local EventBus = require(script.Parent.Parent.Parent.Core.Events.EventBus)
local RewardDispatcher = require(script.Parent.Parent.Parent.Core.Utilities.RewardDispatcher)
local DailyRewardConfig = require(script.Parent.Parent.Config.DailyRewardConfig)

export type DailyStatus = {
	Day: number,
	CanClaim: boolean,
	TimeUntilNext: number,
	CurrentReward: DailyRewardConfig.DailyReward?,
	NextReward: DailyRewardConfig.DailyReward?,
	LastClaimTimestamp: number,
}

local GetDailyStatusRemoteFunc: RemoteFunction? = nil
local RequestClaimDailyRemote: RemoteEvent? = nil
local DailyStatusUpdatedRemote: RemoteEvent? = nil
local Initialized = false

local function EnsureRemoteEvent(Name: string): RemoteEvent
	local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if not RemotesFolder then
		RemotesFolder = Instance.new("Folder")
		RemotesFolder.Name = "Remotes"
		RemotesFolder.Parent = ReplicatedStorage
	end

	local Existing = RemotesFolder:FindFirstChild(Name)
	if Existing and (not Existing.IsA or Existing:IsA("RemoteEvent")) then
		return Existing :: RemoteEvent
	end

	local Remote = Instance.new("RemoteEvent")
	Remote.Name = Name
	Remote.Parent = RemotesFolder
	return Remote
end

local function EnsureRemoteFunction(Name: string): RemoteFunction
	local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if not RemotesFolder then
		RemotesFolder = Instance.new("Folder")
		RemotesFolder.Name = "Remotes"
		RemotesFolder.Parent = ReplicatedStorage
	end

	local Existing = RemotesFolder:FindFirstChild(Name)
	if Existing and (not Existing.IsA or Existing:IsA("RemoteFunction")) then
		return Existing :: RemoteFunction
	end

	local Remote = Instance.new("RemoteFunction")
	Remote.Name = Name
	Remote.Parent = RemotesFolder
	return Remote
end

local DailyRewardService = {}

function DailyRewardService:Init()
	if Initialized then
		return
	end
	Initialized = true

	GetDailyStatusRemoteFunc = EnsureRemoteFunction("GetDailyStatus")
	RequestClaimDailyRemote = EnsureRemoteEvent("RequestClaimDaily")
	DailyStatusUpdatedRemote = EnsureRemoteEvent("DailyStatusUpdated")

	if GetDailyStatusRemoteFunc then
		GetDailyStatusRemoteFunc.OnServerInvoke = function(Client: Player)
			return self:GetDailyStatus(Client)
		end
	end

	if RequestClaimDailyRemote and RequestClaimDailyRemote.OnServerEvent then
		RequestClaimDailyRemote.OnServerEvent:Connect(function(Client: Player)
			self:ClaimDaily(Client)
		end)
	end

	EventBus.Subscribe("PlayerSessionCreated", function(Player: Player)
		task.spawn(function()
			task.wait()
			self:PushDailyStatus(Player)
		end)
	end)

	Logger.Info("DailyReward", "DailyRewardService initialized")
end

function DailyRewardService:Start()
	for _, Player in Players:GetPlayers() do
		if Sessions.Get(Player) then
			task.spawn(function()
				self:PushDailyStatus(Player)
			end)
		end
	end
end

function DailyRewardService:GetDailyStatus(Player: Player): DailyStatus?
	local Session = Sessions.Get(Player)
	if not Session then
		return nil
	end

	local Day = Session.DailyRewardDay or 1
	if Day < 1 or Day > 7 then
		Day = 1
	end

	local LastClaim = Session.LastDailyClaimTimestamp or 0
	local CanClaim = DailyRewardConfig.IsEligible(LastClaim)
	local TimeUntilNext = DailyRewardConfig.GetTimeUntilNext(LastClaim)
	local CurrentReward = DailyRewardConfig.GetDay(Day)
	local NextDay = if Day >= 7 then 1 else Day + 1
	local NextReward = DailyRewardConfig.GetDay(NextDay)

	return {
		Day = Day,
		CanClaim = CanClaim,
		TimeUntilNext = TimeUntilNext,
		CurrentReward = CurrentReward,
		NextReward = NextReward,
		LastClaimTimestamp = LastClaim,
	}
end

function DailyRewardService:PushDailyStatus(Player: Player)
	local Status = self:GetDailyStatus(Player)
	if Status and DailyStatusUpdatedRemote then
		pcall(function()
			DailyStatusUpdatedRemote:FireClient(Player, Status)
		end)
	end
end

function DailyRewardService:ClaimDaily(Player: Player): (boolean, string?)
	if not Player or (Player.IsA and not Player:IsA("Player")) then
		return false, "InvalidPlayer"
	end

	local Session = Sessions.Get(Player)
	if not Session or Session.ProfileMutationsFrozen then
		return false, "SessionUnavailable"
	end

	local LastClaim = Session.LastDailyClaimTimestamp or 0
	if not DailyRewardConfig.IsEligible(LastClaim) then
		return false, "CooldownActive"
	end

	local Day = Session.DailyRewardDay or 1
	if Day < 1 or Day > 7 then
		Day = 1
	end

	local DayConfig = DailyRewardConfig.GetDay(Day)
	if not DayConfig then
		return false, "InvalidConfig"
	end

	local DispatchResult = RewardDispatcher.Dispatch(Player, { DayConfig.Reward })
	if not DispatchResult.Success then
		Logger.Warn(
			"DailyReward",
			string.format("Reward dispatch failed for %s: %s", Player.Name, tostring(DispatchResult.ErrorCode))
		)
		return false, DispatchResult.ErrorCode or "DispatchFailed"
	end

	local NextDay = if Day >= 7 then 1 else Day + 1
	local Now = os.time()

	Sessions.Mutate(Player, function(CurrentSession)
		CurrentSession.DailyRewardDay = NextDay
		CurrentSession.LastDailyClaimTimestamp = Now
	end)

	self:PushDailyStatus(Player)
	EventBus.Publish("DailyRewardClaimed", Player, Day, DayConfig.Reward)
	Logger.Info("DailyReward", string.format("Player %s claimed Day %d daily reward", Player.Name, Day))

	return true, nil
end

return DailyRewardService
