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

function WorldInstanceService:ClearPlayerRuntime(Player: Player)
	local Session = Sessions.Get(Player)
	if Session then
		Session.CurrentWorldInstanceId = nil
	end
	ClearObjectiveAttributes(Player)
	WorldInstances.Remove(Player)
end

function WorldInstanceService:CleanupPlayer(Player: Player, Reason: string?)
	local WorldInstance = WorldInstances.Get(Player)
	if WorldInstance then
		DisconnectWorld(WorldInstance)
		WorldInstance.Model:Destroy()
	end

	self:ClearPlayerRuntime(Player)
	Logger.Info("WorldInstance", "Cleaned player world for %s (%s)", Player.Name, Reason or "Unknown")
end

function WorldInstanceService:FailEntry(Player: Player, WorldInstance: WorldInstance?, Message: string)
	if WorldInstance then
		DisconnectWorld(WorldInstance)
		WorldInstance.Model:Destroy()
	end

	local Session = Sessions.Get(Player)
	if Session then
		Session.State = "InLobby"
		Session.CurrentWorldInstanceId = nil
	end

	ClearObjectiveAttributes(Player)
	WorldInstances.Remove(Player)
	LogFailure(Player, WorldInstance and WorldInstance.WorldInstanceId or nil, Message)
end

function WorldInstanceService:CreateWorldForPlayer(Player: Player): WorldInstance?
	local Session: Session? = Sessions.Get(Player)
	if not Session then
		return nil
	end

	local Template = GetTemplate()
	if not Template then
		self:FailEntry(Player, nil, "WORLD1 template missing")
		return nil
	end

	NextInstanceIndex = NextInstanceIndex + 1
	local WorldInstanceId = `{World1Config.WorldId}_{Player.UserId}_{NextInstanceIndex}`
	local RuntimeWorld = Template:Clone()
	RuntimeWorld.Name = WorldInstanceId
	RuntimeWorld:SetAttribute("OwnerUserId", Player.UserId)
	RuntimeWorld:SetAttribute("WorldInstanceId", WorldInstanceId)
	RuntimeWorld.Parent = GetRuntimeFolder()

	local SpawnOffset = World1Config.RuntimeOffset * NextInstanceIndex
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

	local EntryMarker = GetMarker(RuntimeWorld, World1Config.EntryMarkerName)
	if not EntryMarker then
		EntryMarker = Instance.new("Part")
		EntryMarker.Name = World1Config.EntryMarkerName
		EntryMarker.Size = Vector3.new(6, 1, 6)
		EntryMarker.Anchored = true
		EntryMarker.CanCollide = false
		EntryMarker.CanTouch = false
		EntryMarker.CanQuery = false
		EntryMarker.Transparency = 1
		EntryMarker.CFrame = CFrame.new(SpawnOffset + Vector3.new(1470, 58, -290))
		EntryMarker.Parent = RuntimeWorld
	end

	local WorldInstance: WorldInstance = {
		WorldInstanceId = WorldInstanceId,
		OwnerUserId = Player.UserId,
		OwnerPlayer = Player,
		Model = RuntimeWorld,
		ObjectiveActive = true,
		ObjectiveCompleted = false,
		ObjectiveId = World1Config.Objective.ObjectiveId,
		Connections = {},
	}

	Session.CurrentWorldInstanceId = WorldInstanceId
	WorldInstances.Set(Player, WorldInstance)

	local Success, DestructionService = pcall(function()
		return ServiceRegistry.Get("DestructionService")
	end)
	if not Success or not DestructionService or not DestructionService:BindWorld(WorldInstance) then
		self:FailEntry(Player, WorldInstance, "Failed to bind Spider objective")
		return nil
	end

	if not TeleportPlayerToMarker(Player, EntryMarker) then
		self:FailEntry(Player, WorldInstance, "Failed to teleport player to WORLD1 EntrySpawn")
		return nil
	end

	Player:SetAttribute("CurrentWorldId", World1Config.WorldId)
	Player:SetAttribute("ObjectiveActive", true)
	Player:SetAttribute("ObjectiveText", World1Config.Objective.Text)
	Player:SetAttribute("ObjectiveReward", World1Config.Objective.Reward)

	return WorldInstance
end

function WorldInstanceService:ReturnPlayerToLobby(Player: Player): boolean
	local ReturnMarker = GetReturnMarker()
	if not ReturnMarker then
		LogFailure(Player, nil, "Missing Big Island.ReturnSpawn")
		return false
	end

	return TeleportPlayerToMarker(Player, ReturnMarker)
end

return WorldInstanceService
