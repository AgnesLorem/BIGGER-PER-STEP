--!strict
--// Raw Requirings \\--

local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

--// Requirings \\--

local Sessions = require(script.Parent.Parent.Parent.Core.Registry.RuntimeRegistry.Sessions)
local WorldInstances = require(script.Parent.Parent.Parent.Core.Registry.RuntimeRegistry.WorldInstances)
local ServiceRegistry = require(script.Parent.Parent.Parent.Core.Registry.ServiceRegistry)
local Logger = require(script.Parent.Parent.Parent.Core.Utilities.Logger)
local World1Config = require(script.Parent.Parent.Config.World1Config)

--// Types \\--

type Session = Sessions.Session
type WorldInstance = WorldInstances.WorldInstance

--// Variables \\--

local NextInstanceIndex = 0

--// Helpers \\--

local function ClearObjectiveAttributes(Player: Player)
	Player:SetAttribute("CurrentWorldId", nil)
	Player:SetAttribute("ObjectiveActive", false)
	Player:SetAttribute("ObjectiveText", nil)
	Player:SetAttribute("ObjectiveReward", nil)
end

local function GetRuntimeFolder(): Folder
	local RuntimeFolder = Workspace:FindFirstChild(World1Config.RuntimeFolderName)
	if RuntimeFolder and RuntimeFolder:IsA("Folder") then
		return RuntimeFolder
	end

	RuntimeFolder = Instance.new("Folder")
	RuntimeFolder.Name = World1Config.RuntimeFolderName
	RuntimeFolder.Parent = Workspace
	return RuntimeFolder
end

local function GetTemplate(): Instance?
	local TemplateFolder = ServerStorage:FindFirstChild(World1Config.TemplateFolderName)
	if not TemplateFolder then
		return nil
	end
	return TemplateFolder:FindFirstChild(World1Config.TemplateName)
end

local function GetCharacterRoot(Player: Player): BasePart?
	local Character = Player.Character
	local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
	if RootPart and RootPart:IsA("BasePart") then
		return RootPart
	end
	return nil
end

local function GetMarker(Container: Instance, MarkerName: string): BasePart?
	local Marker = Container:FindFirstChild(MarkerName, true)
	if Marker and Marker:IsA("BasePart") then
		return Marker
	end
	return nil
end

local function GetReturnMarker(): BasePart?
	local ReturnWorld = Workspace:FindFirstChild(World1Config.ReturnWorldName)
	if not ReturnWorld then
		return nil
	end

	local Marker = ReturnWorld:FindFirstChild(World1Config.ReturnMarkerName)
	if Marker and Marker:IsA("BasePart") then
		return Marker
	end
	return nil
end

local function SetModelCFrame(Model: Instance, TargetCFrame: CFrame)
	if Model:IsA("Model") then
		Model:PivotTo(TargetCFrame)
		return
	end
	if Model:IsA("BasePart") then
		Model.CFrame = TargetCFrame
	end
end

local function TeleportPlayerToMarker(Player: Player, Marker: BasePart): boolean
	local RootPart = GetCharacterRoot(Player)
	if not RootPart then
		return false
	end

	RootPart.AssemblyLinearVelocity = Vector3.zero
	RootPart.CFrame = Marker.CFrame + Vector3.new(0, World1Config.TeleportHeightOffset, 0)
	return true
end

local function DisconnectWorld(WorldInstance: WorldInstance)
	for _, Connection in WorldInstance.Connections do
		Connection:Disconnect()
	end
	table.clear(WorldInstance.Connections)
end

local function LogFailure(Player: Player, WorldInstanceId: string?, Message: string)
	Logger.Warn(
		"WorldInstance",
		"%s PlayerUserId=%d WorldInstanceId=%s",
		Message,
		Player.UserId,
		WorldInstanceId or "nil"
	)
end

--// Service \\--

local WorldInstanceService = {}

function WorldInstanceService:Init()
	Players.PlayerRemoving:Connect(function(Player)
		self:CleanupPlayer(Player, "PlayerRemoving")
	end)
end

function WorldInstanceService:Start() end

function WorldInstanceService:GetPlayerWorld(Player: Player): WorldInstance?
	return WorldInstances.Get(Player)
end

function WorldInstanceService:GetReturnMarker(): BasePart?
	return GetReturnMarker()
end

function WorldInstanceService:RecoverPlayer(Player: Player, Reason: string, Respawn: boolean)
	local WorldInstance = WorldInstances.Get(Player)
	if WorldInstance then
		WorldInstance.PendingRewardPrompt = nil
		local Disconnected, DisconnectMessage = pcall(function()
			DisconnectWorld(WorldInstance)
		end)
		if not Disconnected then
			Logger.Warn(
				"WorldInstance",
				"Runtime disconnect failed for %s: %s",
				Player.Name,
				tostring(DisconnectMessage)
			)
		end

		local Destroyed, DestroyMessage = pcall(function()
			WorldInstance.Model:Destroy()
		end)
		if not Destroyed then
			Logger.Warn("WorldInstance", "Runtime destroy failed for %s: %s", Player.Name, tostring(DestroyMessage))
		end
	end

	local Removed, RemoveMessage = pcall(function()
		WorldInstances.Remove(Player)
	end)
	if not Removed then
		Logger.Warn("WorldInstance", "Runtime registry cleanup failed for %s: %s", Player.Name, tostring(RemoveMessage))
	end

	local PortalFound, PortalService = pcall(function()
		return ServiceRegistry.Get("PortalService")
	end)
	if PortalFound and PortalService then
		local Cleared, ClearMessage = pcall(function()
			PortalService:ClearDebounce(Player)
		end)
		if not Cleared then
			Logger.Warn(
				"WorldInstance",
				"Portal debounce cleanup failed for %s: %s",
				Player.Name,
				tostring(ClearMessage)
			)
		end
	end

	local Recovered, RecoveryMessage = pcall(function()
		local SessionService = ServiceRegistry.Get("SessionService")
		if not SessionService:RecoverToLobby(Player, Reason) then
			error("session unavailable")
		end
	end)
	if not Recovered then
		Logger.Warn(
			"WorldInstance",
			"Authoritative lobby recovery failed for %s: %s",
			Player.Name,
			tostring(RecoveryMessage)
		)
	end
	local ObjectiveCleared, ObjectiveMessage = pcall(function()
		ClearObjectiveAttributes(Player)
	end)
	if not ObjectiveCleared then
		Logger.Warn("WorldInstance", "Objective cleanup failed for %s: %s", Player.Name, tostring(ObjectiveMessage))
	end

	if not Respawn or not Player.Parent then
		return
	end

	local Respawned, RespawnMessage = pcall(function()
		Player:LoadCharacter()
	end)
	if not Respawned then
		Logger.Warn("WorldInstance", "Lobby respawn failed for %s: %s", Player.Name, tostring(RespawnMessage))
	end
end

function WorldInstanceService:ClearPlayerRuntime(Player: Player)
	self:RecoverPlayer(Player, "ClearPlayerRuntime", false)
end

function WorldInstanceService:CleanupPlayer(Player: Player, Reason: string?)
	self:RecoverPlayer(Player, Reason or "Unknown", false)
	Logger.Info("WorldInstance", "Cleaned player world for %s (%s)", Player.Name, Reason or "Unknown")
end

function WorldInstanceService:CreateWorldForPlayer(Player: Player): WorldInstance?
	local Session: Session? = Sessions.Get(Player)
	if not Session then
		return nil
	end

	local RegisteredWorld = WorldInstances.Get(Player)
	local SessionWorldInstanceId = Session.CurrentWorldInstanceId
	local HasConsistentActiveWorld = RegisteredWorld
		and RegisteredWorld.OwnerPlayer == Player
		and RegisteredWorld.OwnerUserId == Player.UserId
		and RegisteredWorld.WorldInstanceId == SessionWorldInstanceId
		and RegisteredWorld.Model.Parent ~= nil

	if HasConsistentActiveWorld then
		LogFailure(Player, RegisteredWorld.WorldInstanceId, "Duplicate world allocation rejected")
		return nil
	end

	if RegisteredWorld or SessionWorldInstanceId then
		self:RecoverPlayer(Player, "InconsistentWorldOwnership", false)
		return nil
	end

	if not GetReturnMarker() then
		self:RecoverPlayer(Player, "MissingReturnSpawnBeforeEntry", false)
		return nil
	end

	local Template = GetTemplate()
	if not Template then
		self:RecoverPlayer(Player, "MissingWorldTemplate", false)
		return nil
	end

	NextInstanceIndex = NextInstanceIndex + 1
	local WorldInstanceId = `{World1Config.WorldId}_{Player.UserId}_{NextInstanceIndex}`
	local Cloned, RuntimeWorld = pcall(function()
		return Template:Clone()
	end)
	if not Cloned or typeof(RuntimeWorld) ~= "Instance" then
		self:RecoverPlayer(Player, "WorldCloneFailed", false)
		return nil
	end

	local WorldInstance: WorldInstance = {
		WorldInstanceId = WorldInstanceId,
		OwnerUserId = Player.UserId,
		OwnerPlayer = Player,
		Model = RuntimeWorld,
		ObjectiveInitialized = false,
		ObjectiveActive = false,
		ObjectiveCompleted = false,
		ObjectiveId = World1Config.Objective.ObjectiveId,
		RewardState = "Inactive",
		PendingRewardPrompt = nil,
		Connections = {},
	}

	Session.CurrentWorldInstanceId = WorldInstanceId
	WorldInstances.Set(Player, WorldInstance)

	local SpawnOffset = World1Config.RuntimeOffset * NextInstanceIndex
	local Prepared = pcall(function()
		RuntimeWorld.Name = WorldInstanceId
		RuntimeWorld:SetAttribute("OwnerUserId", Player.UserId)
		RuntimeWorld:SetAttribute("WorldInstanceId", WorldInstanceId)
		RuntimeWorld.Parent = GetRuntimeFolder()

		if RuntimeWorld:IsA("Model") then
			RuntimeWorld:PivotTo(RuntimeWorld:GetPivot() + SpawnOffset)
		elseif RuntimeWorld:IsA("Folder") then
			for _, Child in RuntimeWorld:GetChildren() do
				if Child:IsA("Model") then
					SetModelCFrame(Child, Child:GetPivot() + SpawnOffset)
				elseif Child:IsA("BasePart") then
					Child.CFrame = Child.CFrame + SpawnOffset
				end
			end
		end
	end)
	if not Prepared then
		self:RecoverPlayer(Player, "WorldPreparationFailed", false)
		return nil
	end

	local EntryMarker = GetMarker(RuntimeWorld, World1Config.EntryMarkerName)
	if not EntryMarker then
		self:RecoverPlayer(Player, "MissingEntrySpawn", false)
		return nil
	end

	local Success, DestructionService = pcall(function()
		return ServiceRegistry.Get("DestructionService")
	end)
	local Called, Bound = pcall(function()
		return Success and DestructionService and DestructionService:BindWorld(WorldInstance, self)
	end)
	if not Called or not Bound then
		self:RecoverPlayer(Player, "ObjectiveBindingFailed", false)
		return nil
	end

	local RewardServiceFound, RewardPortalService = pcall(function()
		return ServiceRegistry.Get("RewardPortalService")
	end)
	local RewardCalled, RewardBound = pcall(function()
		return RewardServiceFound and RewardPortalService and RewardPortalService:BindWorld(WorldInstance, self)
	end)
	if not RewardCalled or not RewardBound then
		self:RecoverPlayer(Player, "RewardPortalBindingFailed", false)
		return nil
	end

	local Teleported, EntrySuccess = pcall(function()
		return TeleportPlayerToMarker(Player, EntryMarker)
	end)
	if not Teleported or not EntrySuccess then
		self:RecoverPlayer(Player, "EntryTeleportFailed", false)
		return nil
	end

	local Presented = pcall(function()
		Player:SetAttribute("CurrentWorldId", World1Config.WorldId)
		Player:SetAttribute("ObjectiveActive", false)
		Player:SetAttribute("ObjectiveText", World1Config.Objective.Text)
		Player:SetAttribute("ObjectiveReward", World1Config.Objective.Reward)
	end)
	if not Presented then
		self:RecoverPlayer(Player, "ObjectivePresentationFailed", false)
		return nil
	end

	return WorldInstance
end

function WorldInstanceService:ActivateWorld(Player: Player): boolean
	local Session = Sessions.Get(Player)
	local WorldInstance = WorldInstances.Get(Player)
	if
		not Session
		or Session.State ~= "InWorld"
		or not WorldInstance
		or WorldInstance.OwnerPlayer ~= Player
		or WorldInstance.WorldInstanceId ~= Session.CurrentWorldInstanceId
	then
		return false
	end
	local Found, DestructionService = pcall(function()
		return ServiceRegistry.Get("DestructionService")
	end)
	local Called, Activated = pcall(function()
		return Found and DestructionService and DestructionService:ActivateWorld(WorldInstance)
	end)
	if not Called or not Activated then
		return false
	end
	local Presented = pcall(function()
		Player:SetAttribute("ObjectiveActive", true)
	end)
	return Presented
end

function WorldInstanceService:ReturnPlayerToLobby(Player: Player): boolean
	local ReturnMarker = GetReturnMarker()
	if not ReturnMarker then
		LogFailure(Player, nil, "Missing Big Island.ReturnSpawn")
		return false
	end

	local Teleported, ReturnSuccess = pcall(function()
		return TeleportPlayerToMarker(Player, ReturnMarker)
	end)
	return Teleported and ReturnSuccess
end

return WorldInstanceService
