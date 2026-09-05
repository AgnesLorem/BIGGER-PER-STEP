--!strict
-- SpinWheelService.luau
-- Authoritative server service managing the Lucky Spin Wheel spins, token validation, and reward dispatching.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sessions = require(script.Parent.Parent.Parent.Core.Registry.RuntimeRegistry.Sessions)
local Logger = require(script.Parent.Parent.Parent.Core.Utilities.Logger)
local EventBus = require(script.Parent.Parent.Parent.Core.Events.EventBus)
local RewardDispatcher = require(script.Parent.Parent.Parent.Core.Utilities.RewardDispatcher)
local SpinWheelConfig = require(script.Parent.Parent.Config.SpinWheelConfig)

type Sector = SpinWheelConfig.Sector

local GetSpinStatusRemoteFunc: RemoteFunction? = nil
local RequestSpinWheelRemote: RemoteEvent? = nil
local SpinCompletedRemote: RemoteEvent? = nil
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

local SpinWheelService = {}

function SpinWheelService:Init()
	if Initialized then
		return
	end
	Initialized = true

	GetSpinStatusRemoteFunc = EnsureRemoteFunction("GetSpinStatus")
	RequestSpinWheelRemote = EnsureRemoteEvent("RequestSpinWheel")
	SpinCompletedRemote = EnsureRemoteEvent("SpinCompleted")

	if GetSpinStatusRemoteFunc then
		GetSpinStatusRemoteFunc.OnServerInvoke = function(Client: Player)
			return self:GetSpinTokens(Client)
		end
	end

	if RequestSpinWheelRemote and RequestSpinWheelRemote.OnServerEvent then
		RequestSpinWheelRemote.OnServerEvent:Connect(function(Client: Player)
			self:SpinWheel(Client)
		end)
	end

	Logger.Info("SpinWheel", "SpinWheelService initialized")
end

function SpinWheelService:Start()
	-- No standing loop required; event driven
end

function SpinWheelService:GetSpinTokens(Player: Player): number
	if not Player or (Player.IsA and not Player:IsA("Player")) then
		return 0
	end

	local Session = Sessions.Get(Player)
	if not Session then
		return 0
	end

	return Session.SpinTokens or 0
end

function SpinWheelService:SpinWheel(Player: Player, OptionalRng: Random?): (boolean, any)
	if not Player or (Player.IsA and not Player:IsA("Player")) then
		return false, "InvalidPlayer"
	end

	local Session = Sessions.Get(Player)
	if not Session or Session.ProfileMutationsFrozen then
		return false, "SessionUnavailable"
	end

	local CurrentTokens = Session.SpinTokens or 0
	if CurrentTokens < 1 then
		return false, "InsufficientTokens"
	end

	-- Deduct token
	Sessions.Mutate(Player, function(CurrentSession)
		CurrentSession.SpinTokens = math.max(0, CurrentSession.SpinTokens - 1)
	end)

	-- Select winning sector authoritatively
	local Sector = SpinWheelConfig.SelectRandom(OptionalRng)

	-- Apply reward
	local DispatchResult = RewardDispatcher.Dispatch(Player, { Sector.Reward })
	if not DispatchResult.Success then
		Logger.Warn(
			"SpinWheel",
			string.format(
				"Reward dispatch failed for %s on Sector %d: %s",
				Player.Name,
				Sector.Index,
				tostring(DispatchResult.ErrorCode)
			)
		)
	end

	local ResultPayload = {
		Sector = Sector,
		RemainingTokens = Session.SpinTokens,
	}

	if SpinCompletedRemote then
		pcall(function()
			SpinCompletedRemote:FireClient(Player, ResultPayload)
		end)
	end

	EventBus.Publish("SpinWheelCompleted", Player, Sector, Session.SpinTokens)
	Logger.Info(
		"SpinWheel",
		string.format(
			"Player %s spun the wheel and landed on Sector %d (%s), %d tokens left",
			Player.Name,
			Sector.Index,
			Sector.Name,
			Session.SpinTokens
		)
	)

	return true, ResultPayload
end

return SpinWheelService
