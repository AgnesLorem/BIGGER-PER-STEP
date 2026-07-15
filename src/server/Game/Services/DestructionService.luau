--!strict
--// Raw Requirings \\--

local Players = game:GetService("Players")

--// Requirings \\--

local Sessions = require(script.Parent.Parent.Parent.Core.Registry.RuntimeRegistry.Sessions)
local ServiceRegistry = require(script.Parent.Parent.Parent.Core.Registry.ServiceRegistry)
local Logger = require(script.Parent.Parent.Parent.Core.Utilities.Logger)
local World1Config = require(script.Parent.Parent.Config.World1Config)

--// Helpers \\--

local function GetPlayerFromHit(Hit: BasePart): Player?
	local Character = Hit:FindFirstAncestorOfClass("Model")
	if not Character then
		return nil
	end
	return Players:GetPlayerFromCharacter(Character)
end

local function GetRootPart(Player: Player): BasePart?
	local Character = Player.Character
	local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
	if RootPart and RootPart:IsA("BasePart") then
		return RootPart
	end
	return nil
end

local function GetHitbox(WorldModel: Instance): BasePart?
	local Spider = WorldModel:FindFirstChild(World1Config.Objective.ModelName, true)
	if not Spider then
		return nil
	end

	local Hitbox = Spider:FindFirstChild(World1Config.Objective.HitboxName)
	if Hitbox and Hitbox:IsA("BasePart") then
		return Hitbox
	end

	return nil
end

local function IsValidStomp(Player: Player, Hitbox: BasePart): boolean
	local RootPart = GetRootPart(Player)
	if not RootPart then
		return false
	end
	if RootPart.Position.Y <= Hitbox.Position.Y + World1Config.Objective.AboveHitboxPadding then
		return false
	end
	return RootPart.AssemblyLinearVelocity.Y <= World1Config.Objective.MinimumDownwardVelocity
end

local function SyncDestruction(Player: Player, Destruction: number)
	Player:SetAttribute("Destruction", Destruction)

	local Leaderstats = Player:FindFirstChild("leaderstats")
	local DestructionStat = Leaderstats and Leaderstats:FindFirstChild("Destruction")
	if DestructionStat and DestructionStat:IsA("IntValue") then
		DestructionStat.Value = Destruction
	end
end

local function PlayPlaceholderEffect(Hitbox: BasePart)
	local OriginalTransparency = Hitbox.Transparency
	Hitbox.Transparency = 0.7
	task.delay(0.25, function()
		if Hitbox.Parent then
			Hitbox.Transparency = OriginalTransparency
		end
	end)
end

local function ClearObjectiveAttributes(Player: Player)
	Player:SetAttribute("CurrentWorldId", nil)
	Player:SetAttribute("ObjectiveActive", false)
	Player:SetAttribute("ObjectiveText", nil)
	Player:SetAttribute("ObjectiveReward", nil)
end

--// Service \\--

local DestructionService = {}

function DestructionService:Init() end

function DestructionService:Start() end

function DestructionService:BindWorld(WorldInstance)
	local Hitbox = GetHitbox(WorldInstance.Model)
	if not Hitbox then
		Logger.Warn(
			"Destruction",
			"Spider.ObjectiveHitbox missing for PlayerUserId=%d WorldInstanceId=%s",
			WorldInstance.OwnerUserId,
			WorldInstance.WorldInstanceId
		)
		return false
	end

	Hitbox.CanTouch = true
	table.insert(
		WorldInstance.Connections,
		Hitbox.Touched:Connect(function(Hit)
			self:TryCompleteObjective(WorldInstance, Hitbox, Hit)
		end)
	)
	return true
end

function DestructionService:TryCompleteObjective(WorldInstance, Hitbox: BasePart, Hit: BasePart)
	local Player = GetPlayerFromHit(Hit)
	if not Player or Player.UserId ~= WorldInstance.OwnerUserId then
		return
	end

	local Session = Sessions.Get(Player)
	if not Session or Session.State ~= "InWorld" then
		return
	end
	if Session.CurrentWorldInstanceId ~= WorldInstance.WorldInstanceId then
		return
	end
	if not WorldInstance.ObjectiveActive or WorldInstance.ObjectiveCompleted then
		return
	end
	if not IsValidStomp(Player, Hitbox) then
		return
	end

	WorldInstance.ObjectiveCompleted = true
	WorldInstance.ObjectiveActive = false
	Hitbox.CanTouch = false

	Session.Destruction = Session.Destruction + World1Config.Objective.DestructionReward
	SyncDestruction(Player, Session.Destruction)

	local EffectSuccess = pcall(function()
		PlayPlaceholderEffect(Hitbox)
	end)
	if not EffectSuccess then
		Logger.Warn(
			"Destruction",
			"Destruction effect failed for PlayerUserId=%d WorldInstanceId=%s",
			Player.UserId,
			WorldInstance.WorldInstanceId
		)
	end

	Session.State = "Returning"

	local WorldInstanceService = ServiceRegistry.Get("WorldInstanceService")
	local PortalService = ServiceRegistry.Get("PortalService")
	PortalService:HoldDebounce(Player, World1Config.ReturnPortalDebounceSeconds)

	local ReturnSuccess = WorldInstanceService:ReturnPlayerToLobby(Player)
	if not ReturnSuccess then
		Logger.Warn(
			"Destruction",
			"Return teleport failed for PlayerUserId=%d WorldInstanceId=%s",
			Player.UserId,
			WorldInstance.WorldInstanceId
		)
	end

	WorldInstanceService:CleanupPlayer(Player, "ObjectiveCompleted")
	ClearObjectiveAttributes(Player)
	Session.State = "InLobby"
end

return DestructionService
