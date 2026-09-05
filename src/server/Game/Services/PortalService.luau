--!strict
--// Raw Requirings \\--

local ReplicatedStorageFound, ReplicatedStorage = pcall(function()
	return game:GetService("ReplicatedStorage")
end)

--// Requirings \\--

local Sessions = require(script.Parent.Parent.Parent.Core.Registry.RuntimeRegistry.Sessions)
local ServiceRegistry = require(script.Parent.Parent.Parent.Core.Registry.ServiceRegistry)
local Logger = require(script.Parent.Parent.Parent.Core.Utilities.Logger)
local ConfigFolder = script.Parent.Parent.Config
local MapsConfig = require((ConfigFolder :: any).MapsConfig or (ConfigFolder :: any).World1Config)
local LevelFormula = require(
	if ReplicatedStorageFound and ReplicatedStorage
		then ReplicatedStorage:WaitForChild("BiggerShared")
			:WaitForChild("Game")
			:WaitForChild("Progression")
			:WaitForChild("LevelFormula")
		else script.Parent.Parent.Parent.Parent.shared.Game.Progression.LevelFormula
)

--// Variables \\--

local PortalDebounces: { [Player]: boolean } = {}
local Connections: { RBXScriptConnection } = {}
local RequestSelectMapRemote: RemoteEvent? = nil

--// Helpers \\--

local function EnsureRemote(Name: string): RemoteEvent?
	if not ReplicatedStorageFound or not ReplicatedStorage then
		return nil
	end

	local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if not RemotesFolder then
		RemotesFolder = Instance.new("Folder")
		RemotesFolder.Name = "Remotes"
		RemotesFolder.Parent = ReplicatedStorage
	end

	local Existing = RemotesFolder:FindFirstChild(Name)
	if Existing and (not Existing.IsA or Existing:IsA("RemoteEvent")) then
		return Existing
	end

	local Remote = Instance.new("RemoteEvent")
	Remote.Name = Name
	Remote.Parent = RemotesFolder
	return Remote
end

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
	RequestSelectMapRemote = EnsureRemote("RequestSelectMap")
	if RequestSelectMapRemote and RequestSelectMapRemote.OnServerEvent then
		RequestSelectMapRemote.OnServerEvent:Connect(function(Client: Player, MapId: any)
			self:SelectMap(Client, MapId)
		end)
	end
end

function PortalService:Start() end

function PortalService:SelectMap(
	Player: Player,
	MapId: any,
	OptionalSessionService: any?,
	OptionalWorldInstanceService: any?
): boolean
	if not Player or PortalDebounces[Player] then
		return false
	end

	local Session = Sessions.Get(Player)
	if not Session or Session.ProfileMutationsFrozen or Session.State ~= "InLobby" then
		return false
	end

	local TargetMapId = if typeof(MapId) == "string" and MapId ~= "" then MapId else "MAP1"
	local MapDef = if MapsConfig and MapsConfig.GetMap then MapsConfig.GetMap(TargetMapId) else nil
	if not MapDef and MapsConfig and MapsConfig.RequiredLevel then
		local Upper = string.upper(TargetMapId)
		if Upper == "WORLD1" or Upper == "MAP1" or Upper == "WORLD_1" or Upper == "MAP_1" then
			MapDef = {
				MapId = MapsConfig.WorldId or "MAP1",
				RequiredLevel = MapsConfig.RequiredLevel,
				IsComingSoon = false,
			}
		end
	end

	if not MapDef or MapDef.IsComingSoon then
		return false
	end

	if GetDerivedLevel(Session) < MapDef.RequiredLevel then
		return false
	end

	TargetMapId = MapDef.MapId
	PortalDebounces[Player] = true

	local SessionService = OptionalSessionService
	local WorldInstanceService = OptionalWorldInstanceService
	if not SessionService or not WorldInstanceService then
		local ServicesFound, SvcSession, SvcWorld = pcall(function()
			return ServiceRegistry.Get("SessionService"), ServiceRegistry.Get("WorldInstanceService")
		end)
		if not ServicesFound then
			ClearDebounce(Player)
			return false
		end
		SessionService = SessionService or SvcSession
		WorldInstanceService = WorldInstanceService or SvcWorld
	end

	if not SessionService or not WorldInstanceService then
		ClearDebounce(Player)
		return false
	end

	local OwnershipRead, RegisteredWorld = pcall(function()
		return WorldInstanceService:GetPlayerWorld(Player)
	end)
	if not OwnershipRead then
		RecoverPlayer(WorldInstanceService, Player, "PortalOwnershipQueryFailed")
		return false
	end

	if RegisteredWorld or Session.CurrentWorldInstanceId then
		local Checked = pcall(function()
			if WorldInstanceService.CreateWorld then
				WorldInstanceService:CreateWorld(Player, TargetMapId)
			else
				WorldInstanceService:CreateWorldForPlayer(Player)
			end
		end)
		if not Checked then
			RecoverPlayer(WorldInstanceService, Player, "PortalOwnershipReconciliationFailed")
		end
		ClearDebounce(Player)
		return false
	end

	local EnteringCalled, EnteringWorld = pcall(function()
		return SessionService:TransitionState(Player, "InLobby", "EnteringWorld")
	end)
	if not EnteringCalled or not EnteringWorld then
		RecoverPlayer(WorldInstanceService, Player, "PortalEnteringTransitionFailed")
		return false
	end

	local Created, WorldInstance = pcall(function()
		if WorldInstanceService.CreateWorld then
			return WorldInstanceService:CreateWorld(Player, TargetMapId)
		else
			return WorldInstanceService:CreateWorldForPlayer(Player)
		end
	end)
	if not Created or not WorldInstance then
		RecoverPlayer(WorldInstanceService, Player, "PortalWorldCreationFailed")
		Logger.Warn("Portal", "World entry failed for PlayerUserId=%d: %s", Player.UserId, tostring(WorldInstance))
		return false
	end

	if WorldInstanceService.EnterWorld then
		local Entered, EnterSuccess = pcall(function()
			return WorldInstanceService:EnterWorld(Player, WorldInstance)
		end)
		if not Entered or not EnterSuccess then
			RecoverPlayer(WorldInstanceService, Player, "PortalInWorldTransitionFailed")
			return false
		end
	else
		local InWorldCalled, InWorld = pcall(function()
			return SessionService:TransitionState(Player, "EnteringWorld", "InWorld")
		end)
		if not InWorldCalled or not InWorld then
			RecoverPlayer(WorldInstanceService, Player, "PortalInWorldTransitionFailed")
			return false
		end
		local Activated, ActivationSuccess = pcall(function()
			return WorldInstanceService:ActivateWorld(Player)
		end)
		if not Activated or not ActivationSuccess then
			RecoverPlayer(WorldInstanceService, Player, "PortalObjectiveActivationFailed")
			return false
		end
	end

	ClearDebounce(Player)
	return true
end

function PortalService:TryEnterPortal(Hit: BasePart, SessionService: any, WorldInstanceService: any)
	local Player = GetPlayerFromHit(Hit)
	if not Player then
		return
	end
	self:SelectMap(Player, "MAP1", SessionService, WorldInstanceService)
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
