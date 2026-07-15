--!strict
--// Raw Requirings \\--

local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Requirings \\--

local Sessions = require(script.Parent.Parent.Parent.Core.Registry.RuntimeRegistry.Sessions)
local ServiceRegistry = require(script.Parent.Parent.Parent.Core.Registry.ServiceRegistry)
local Logger = require(script.Parent.Parent.Parent.Core.Utilities.Logger)
local World1Config = require(script.Parent.Parent.Config.World1Config)
local LevelFormula = require(ReplicatedStorage.BiggerShared.Game.Progression.LevelFormula)

--// Variables \\--

local PortalDebounces: { [Player]: boolean } = {}
local Connections: { RBXScriptConnection } = {}

--// Helpers \\--

local function GetPlayerFromHit(Hit: BasePart): Player?
	local Character = Hit:FindFirstAncestorOfClass("Model")
	if not Character then
		return nil
	end
	return game:GetService("Players"):GetPlayerFromCharacter(Character)
end

local function GetDerivedLevel(Session: Sessions.Session): number
	return LevelFormula.GetLevelFromBigger(Session.Bigger)
end

local function GetPortalParts(): { BasePart }
	local Portal = Workspace:FindFirstChild(World1Config.PortalName)
	local Parts: { BasePart } = {}
	if not Portal then
		return Parts
	end

	for _, Descendant in Portal:GetDescendants() do
		if Descendant:IsA("BasePart") then
			table.insert(Parts, Descendant)
		end
	end
	return Parts
end

local function ClearDebounce(Player: Player)
	PortalDebounces[Player] = nil
end

local function HoldDebounce(Player: Player, Duration: number)
	PortalDebounces[Player] = true
	task.delay(Duration, function()
		if PortalDebounces[Player] then
			ClearDebounce(Player)
		end
	end)
end

--// Service \\--

local PortalService = {}

function PortalService:Init()
	for _, Part in GetPortalParts() do
		table.insert(
			Connections,
			Part.Touched:Connect(function(Hit)
				self:TryEnterPortal(Hit)
			end)
		)
	end
end

function PortalService:Start() end

function PortalService:TryEnterPortal(Hit: BasePart)
	local Player = GetPlayerFromHit(Hit)
	if not Player or PortalDebounces[Player] then
		return
	end

	local Session = Sessions.Get(Player)
	if not Session or Session.State ~= "InLobby" then
		return
	end
	if GetDerivedLevel(Session) < World1Config.RequiredLevel then
		return
	end

	PortalDebounces[Player] = true
	Session.State = "EnteringWorld"

	local Success, WorldInstanceService = pcall(function()
		return ServiceRegistry.Get("WorldInstanceService")
	end)

	if not Success or not WorldInstanceService then
		Session.State = "InLobby"
		ClearDebounce(Player)
		Logger.Warn("Portal", "WorldInstanceService missing for PlayerUserId=%d", Player.UserId)
		return
	end

	local WorldInstance = WorldInstanceService:CreateWorldForPlayer(Player)
	if not WorldInstance then
		Session.State = "InLobby"
		ClearDebounce(Player)
		return
	end

	Session.State = "InWorld"
	ClearDebounce(Player)
end

function PortalService:ClearDebounce(Player: Player)
	ClearDebounce(Player)
end

function PortalService:HoldDebounce(Player: Player, Duration: number)
	HoldDebounce(Player, Duration)
end

function PortalService:Destroy()
	for _, Connection in Connections do
		Connection:Disconnect()
	end
	table.clear(Connections)
	table.clear(PortalDebounces)
end

return PortalService
