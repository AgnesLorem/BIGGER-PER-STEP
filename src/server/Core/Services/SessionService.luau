--// Raw Requirings \\--

local Players = game:GetService("Players")

--// Requirings \\--
local Sessions = require(script.Parent.Parent.Registry.RuntimeRegistry.Sessions)
local Logger = require(script.Parent.Parent.Utilities.Logger)
local EventBus = require(script.Parent.Parent.Events.EventBus)
local SaveService = require(script.Parent.SaveService)

--// Types \\--
type Session = Sessions.Session

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

local function OnPlayerAdded(Player: Player)
	local Profile = SaveService:LoadProfile(Player)
	local Session: Session = {
		Player = Player,
		Bigger = Profile.Bigger,
		Destruction = Profile.Destruction,
		Rebirth = Profile.Rebirth,
		State = "Ready",
		JoinedAt = tick(),
		PurchaseHistory = Profile.ProcessedPurchaseIds or {},
	}

	Sessions.Set(Player, Session)
	CreateLeaderstats(Player, Session)
	Player:SetAttribute("Bigger", Session.Bigger)
	
	local Level = math.floor((Session.Bigger / 236) ^ 0.25) + 1
	Player:SetAttribute("Level", Level)

	EventBus.Publish("PlayerSessionCreated", Player, Session)
	Logger.Info("Session", "Session created for %s", Player.Name)
end

local function OnPlayerRemoving(Player: Player)
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

return SessionService
