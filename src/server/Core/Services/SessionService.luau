--// Raw Requirings \\--

local Players = game:GetService("Players")

--// Requirings \\--
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

local function OnPlayerAdded(Player: Player)
	if Sessions.Get(Player) then
		return
	end
	local Loaded, Profile = pcall(SaveService.LoadProfile, SaveService, Player)
	if not Loaded then
		Logger.Warn("Session", "Profile load failed for %s: %s", Player.Name, tostring(Profile))
		Player:Kick("Your data could not be loaded safely. Please rejoin.")
		return
	end
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

	Sessions.Set(Player, Session)
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

local function OnPlayerRemoving(Player: Player)
	if not Sessions.Get(Player) then
		return
	end
	SaveService:FreezeMutations(Player, "PlayerRemoving")
	if not SaveService:ReleaseProfile(Player) then
		Logger.Warn("Session", "Final profile release failed for %s", Player.Name)
		return
	end
	Sessions.Remove(Player)
	EventBus.Publish("PlayerSessionDestroyed", Player)
	Logger.Info("Session", "Session destroyed for %s", Player.Name)
end

--// Service \\--

local SessionService = {}

function SessionService:Init()
	Players.PlayerAdded:Connect(OnPlayerAdded)
	Players.PlayerRemoving:Connect(OnPlayerRemoving)
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
