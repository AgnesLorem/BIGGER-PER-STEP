--// Raw Requirings \\--

local Players = game:GetService("Players")

--// Requirings \\--
local SaveConfig = require(script.Parent.Parent.Config.SaveConfig)
local Profiles = require(script.Parent.Parent.Registry.RuntimeRegistry.Profiles)
local Sessions = require(script.Parent.Parent.Registry.RuntimeRegistry.Sessions)
local Logger = require(script.Parent.Parent.Utilities.Logger)
local EventBus = require(script.Parent.Parent.Events.EventBus)
local SaveService = require(script.Parent.SaveService)
local GrowthService = require(script.Parent.GrowthService)

--// Types \\--
type Session = Sessions.Session

--// Variables \\--
local AllowedTransitions: { [string]: { [string]: boolean } } = table.freeze({
	InLobby = table.freeze({ EnteringWorld = true }),
	EnteringWorld = table.freeze({ InWorld = true }),
	InWorld = table.freeze({ Returning = true }),
	Returning = table.freeze({}),
})
local ShutdownStarted = false
local LoadingPlayers: { [Player]: {} } = {}

--// Helpers \\--
local function CreateLeaderstats(Player: Player, Session: Session)
	local Leaderstats = Instance.new("Folder")
	Leaderstats.Name = "leaderstats"

	local BiggerValue = Instance.new("IntValue")
	BiggerValue.Name = "Bigger"
	BiggerValue.Value = Session.Bigger
	BiggerValue.Parent = Leaderstats

	local DestructionValue = Instance.new("IntValue")
	DestructionValue.Name = "Destruction"
	DestructionValue.Value = Session.Destruction
	DestructionValue.Parent = Leaderstats

	Leaderstats.Parent = Player
end

local function ClearObjectiveAttributes(Player: Player)
	Player:SetAttribute("CurrentWorldId", nil)
	Player:SetAttribute("ObjectiveActive", false)
	Player:SetAttribute("ObjectiveText", nil)
	Player:SetAttribute("ObjectiveReward", nil)
end

local FinalizePlayer: (Player, string) -> boolean

local function OnPlayerAdded(Player: Player)
	if Sessions.Get(Player) or LoadingPlayers[Player] then
		return
	end
	local LoadToken = {}
	LoadingPlayers[Player] = LoadToken
	local Loaded, Profile = pcall(SaveService.LoadProfile, SaveService, Player)
	if LoadingPlayers[Player] ~= LoadToken then
		return
	end
	if not Loaded then
		LoadingPlayers[Player] = nil
		Logger.Warn("Session", "Profile load failed for %s: %s", Player.Name, tostring(Profile))
		if Sessions.Get(Player) or Profiles.Get(Player.UserId) then
			return
		end
		Player:Kick("Your data could not be loaded safely. Please rejoin.")
		return
	end
	local RuntimeProfile = Profiles.Get(Player.UserId)
	if not RuntimeProfile or RuntimeProfile.Phase ~= "Active" then
		LoadingPlayers[Player] = nil
		return
	end
	local ExpectedOwnerToken = RuntimeProfile.OwnerToken
	local Session: Session = {
		Player = Player,
		Bigger = Profile.Bigger,
		Destruction = Profile.Destruction,
		Rebirth = Profile.Rebirth,
		UnlockedGrowthUpgrades = Profile.UnlockedGrowthUpgrades,
		EquippedGrowthUpgrade = Profile.EquippedGrowthUpgrade,
		CompletedPortals = Profile.CompletedPortals,
		Settings = Profile.Settings,
		HasDoubleMultiplier = Profile.HasDoubleMultiplier,
		HasVip = Profile.HasVip,
		HasPremiumZonePass = Profile.HasPremiumZonePass,
		GrowthRemainder = 0,
		CurrentAFKZone = nil,
		PremiumZonePromptedThisEntry = false,
		GamePassQueryGenerations = { Vip = 0, PremiumZone = 0 },
		State = "InLobby",
		JoinedAt = tick(),
		PurchaseHistory = Profile.ProcessedPurchaseIds,
		CurrentWorldInstanceId = nil,
		LastActiveTimestamp = Profile.LastActiveTimestamp,
		LastLogoutTimestamp = Profile.LastLogoutTimestamp,
		LastSaveTimestamp = Profile.LastSaveTimestamp,
		ProfileMutationsFrozen = false,
		ProfileMutationFreezeReason = nil,
	}

	if
		LoadingPlayers[Player] ~= LoadToken
		or Profiles.Get(Player.UserId) ~= RuntimeProfile
		or RuntimeProfile.OwnerToken ~= ExpectedOwnerToken
		or RuntimeProfile.Phase ~= "Active"
	then
		if LoadingPlayers[Player] == LoadToken then
			LoadingPlayers[Player] = nil
		end
		return
	end
	Sessions.Set(Player, Session)
	LoadingPlayers[Player] = nil
	if Player.Parent ~= Players then
		FinalizePlayer(Player, "DisconnectedDuringLoad")
		return
	end
	CreateLeaderstats(Player, Session)
	Player:SetAttribute("Bigger", Session.Bigger)
	Player:SetAttribute("Destruction", Session.Destruction)
	ClearObjectiveAttributes(Player)
	GrowthService:UpdateMultiplierAttribute(Player)

	local Level = math.floor((Session.Bigger / 236) ^ 0.25) + 1
	Player:SetAttribute("Level", Level)
	EventBus.Publish("PlayerSessionCreated", Player, Session)
	Logger.Info("Session", "Session created for %s", Player.Name)
	Player:LoadCharacter()
end

FinalizePlayer = function(Player: Player, Reason: string): boolean
	if not Sessions.Get(Player) then
		return true
	end
	SaveService:FreezeMutations(Player, Reason)
	local Called, Released = pcall(SaveService.ReleaseProfile, SaveService, Player)
	if not Called or not Released then
		Logger.Warn("Session", "Final profile release failed for %s", Player.Name)
		return false
	end
	if Sessions.Get(Player) then
		Sessions.Remove(Player)
		EventBus.Publish("PlayerSessionDestroyed", Player)
		Logger.Info("Session", "Session destroyed for %s", Player.Name)
	end
	return true
end

local function OnPlayerRemoving(Player: Player)
	FinalizePlayer(Player, "PlayerRemoving")
end

local function OnShutdown()
	if ShutdownStarted then
		return
	end
	ShutdownStarted = true

	local PlayersToRelease = {}
	for _, Player in Players:GetPlayers() do
		if Sessions.Get(Player) then
			table.insert(PlayersToRelease, Player)
			SaveService:FreezeMutations(Player, "Shutdown")
		end
	end

	local Completed: { [Player]: boolean } = {}
	local CompletedCount = 0
	for _, Player in PlayersToRelease do
		task.spawn(function()
			FinalizePlayer(Player, "Shutdown")
			Completed[Player] = true
			CompletedCount += 1
		end)
	end

	local Deadline = os.clock() + SaveConfig.ShutdownTimeoutSeconds
	while CompletedCount < #PlayersToRelease do
		local Remaining = Deadline - os.clock()
		if Remaining <= 0 then
			break
		end
		task.wait(math.min(Remaining, 0.1))
	end

	for _, Player in PlayersToRelease do
		if not Completed[Player] then
			local RuntimeProfile = Profiles.Get(Player.UserId)
			Logger.Warn(
				"Session",
				"Shutdown final save unresolved for UserId %d (phase=%s, queue=%d, lastError=%s)",
				Player.UserId,
				if RuntimeProfile then RuntimeProfile.Phase else "Missing",
				if RuntimeProfile then #RuntimeProfile.WriteQueue else 0,
				if RuntimeProfile then tostring(RuntimeProfile.LastError) else "nil"
			)
		end
	end
end

--// Service \\--

local SessionService = {}

function SessionService:Init()
	Players.PlayerAdded:Connect(OnPlayerAdded)
	Players.PlayerRemoving:Connect(OnPlayerRemoving)
	game:BindToClose(OnShutdown)
end

function SessionService:Start()
	for _, Player in Players:GetPlayers() do
		task.spawn(OnPlayerAdded, Player)
	end
end

function SessionService:GetSession(Player: Player): Session?
	return Sessions.Get(Player)
end

function SessionService:TransitionState(Player: Player, ExpectedState: string, NextState: string): boolean
	local Session = Sessions.Get(Player)
	if not Session or Session.State ~= ExpectedState then
		return false
	end

	local NextStates = AllowedTransitions[ExpectedState]
	if not NextStates or not NextStates[NextState] then
		return false
	end

	Session.State = NextState
	return true
end

function SessionService:RecoverToLobby(Player: Player, Reason: string): boolean
	local Session = Sessions.Get(Player)
	if not Session then
		Logger.Warn("Session", "Lobby recovery skipped without session for %s (%s)", Player.Name, Reason)
		return false
	end

	Session.State = "InLobby"
	Session.CurrentWorldInstanceId = nil
	ClearObjectiveAttributes(Player)
	Logger.Warn("Session", "Recovered %s to lobby state (%s)", Player.Name, Reason)
	return true
end

return SessionService
