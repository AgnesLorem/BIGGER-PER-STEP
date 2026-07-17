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

local function RecoverPlayer(WorldInstanceService: any, Player: Player, Reason: string)
	local Recovered, RecoveryMessage = pcall(function()
		WorldInstanceService:RecoverPlayer(Player, Reason, false)
	end)
	if not Recovered then
		Logger.Warn(
			"Portal",
			"Recovery failed for PlayerUserId=%d (%s): %s",
			Player.UserId,
			Reason,
			tostring(RecoveryMessage)
		)
	end
end

--// Service \\--

local PortalService = {}

function PortalService:Init()
	local ServicesFound, SessionService, WorldInstanceService = pcall(function()
		return ServiceRegistry.Get("SessionService"), ServiceRegistry.Get("WorldInstanceService")
	end)
	if not ServicesFound or not SessionService or not WorldInstanceService then
		Logger.Warn("Portal", "Entry callbacks not bound because required services are unavailable")
		return
	end

	for _, Part in GetPortalParts() do
		table.insert(
			Connections,
			Part.Touched:Connect(function(Hit)
				self:TryEnterPortal(Hit, SessionService, WorldInstanceService)
			end)
		)
	end
end

function PortalService:Start() end

function PortalService:TryEnterPortal(Hit: BasePart, SessionService: any, WorldInstanceService: any)
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
	local OwnershipRead, RegisteredWorld = pcall(function()
		return WorldInstanceService:GetPlayerWorld(Player)
	end)
	if not OwnershipRead then
		RecoverPlayer(WorldInstanceService, Player, "PortalOwnershipQueryFailed")
		return
	end

	if RegisteredWorld or Session.CurrentWorldInstanceId then
		local Checked = pcall(function()
			WorldInstanceService:CreateWorldForPlayer(Player)
		end)
		if not Checked then
			RecoverPlayer(WorldInstanceService, Player, "PortalOwnershipReconciliationFailed")
		end
		ClearDebounce(Player)
		return
	end

	local EnteringCalled, EnteringWorld = pcall(function()
		return SessionService:TransitionState(Player, "InLobby", "EnteringWorld")
	end)
	if not EnteringCalled then
		RecoverPlayer(WorldInstanceService, Player, "PortalEnteringTransitionFailed")
		return
	end
	if not EnteringWorld then
		RecoverPlayer(WorldInstanceService, Player, "PortalEnteringTransitionRejected")
		return
	end

	local Created, WorldInstance = pcall(function()
		return WorldInstanceService:CreateWorldForPlayer(Player)
	end)
	if not Created then
		RecoverPlayer(WorldInstanceService, Player, "PortalWorldCreationFailed")
		Logger.Warn("Portal", "World entry failed for PlayerUserId=%d: %s", Player.UserId, tostring(WorldInstance))
		return
	end
	if not WorldInstance then
		RecoverPlayer(WorldInstanceService, Player, "PortalWorldCreationReturnedNil")
		return
	end

	local InWorldCalled, InWorld = pcall(function()
		return SessionService:TransitionState(Player, "EnteringWorld", "InWorld")
	end)
	if not InWorldCalled then
		RecoverPlayer(WorldInstanceService, Player, "PortalInWorldTransitionFailed")
		return
	end
	if not InWorld then
		RecoverPlayer(WorldInstanceService, Player, "PortalInWorldTransitionRejected")
		return
	end
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
