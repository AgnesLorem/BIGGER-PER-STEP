--!strict
--// Raw Requirings \\--

local Players = game:GetService("Players")

--// Requirings \\--

local Sessions = require(script.Parent.Parent.Parent.Core.Registry.RuntimeRegistry.Sessions)
local WorldInstances = require(script.Parent.Parent.Parent.Core.Registry.RuntimeRegistry.WorldInstances)
local ServiceRegistry = require(script.Parent.Parent.Parent.Core.Registry.ServiceRegistry)
local Logger = require(script.Parent.Parent.Parent.Core.Utilities.Logger)
local World1Config = require(script.Parent.Parent.Config.World1Config)

--// Types \\--

type WorldInstance = WorldInstances.WorldInstance
type Portal = {
	Model: Model,
	Visual: BasePart,
	Trigger: BasePart,
	LabelPart: BasePart,
	SurfaceGui: SurfaceGui,
	TextLabel: TextLabel,
}

--// Helpers \\--

local function GetPlayerFromHit(Hit: BasePart): Player?
	local Character = Hit:FindFirstAncestorOfClass("Model")
	if not Character then
		return nil
	end
	return Players:GetPlayerFromCharacter(Character)
end

local function GetPortal(WorldModel: Instance, Name: string): Portal?
	local Model = WorldModel:FindFirstChild(Name)
	if not Model or not Model:IsA("Model") then
		return nil
	end

	local Visual = Model:FindFirstChild("Visual")
	local Trigger = Model:FindFirstChild("Trigger")
	local LabelPart = Model:FindFirstChild("LabelPart")
	local SurfaceGui = LabelPart and LabelPart:FindFirstChild("SurfaceGui")
	local TextLabel = SurfaceGui and SurfaceGui:FindFirstChild("TextLabel")
	if
		not Visual
		or not Visual:IsA("BasePart")
		or not Trigger
		or not Trigger:IsA("BasePart")
		or not LabelPart
		or not LabelPart:IsA("BasePart")
		or not SurfaceGui
		or not SurfaceGui:IsA("SurfaceGui")
		or not TextLabel
		or not TextLabel:IsA("TextLabel")
	then
		return nil
	end

	return {
		Model = Model,
		Visual = Visual,
		Trigger = Trigger,
		LabelPart = LabelPart,
		SurfaceGui = SurfaceGui,
		TextLabel = TextLabel,
	}
end

local function GetPortals(WorldInstance: WorldInstance): (Portal?, Portal?)
	local PortalConfig = World1Config.RewardPortals
	return GetPortal(WorldInstance.Model, PortalConfig.FreeName), GetPortal(WorldInstance.Model, PortalConfig.PaidName)
end

local function SetPortalActive(Portal: Portal, Visible: boolean, TouchEnabled: boolean)
	Portal.Visual.Transparency = if Visible then 0 else 1
	Portal.Trigger.Transparency = 1
	Portal.Trigger.CanCollide = false
	Portal.Trigger.CanQuery = false
	Portal.Trigger.CanTouch = Visible and TouchEnabled
	Portal.LabelPart.Transparency = 1
	Portal.LabelPart.CanCollide = false
	Portal.LabelPart.CanQuery = false
	Portal.LabelPart.CanTouch = false
	Portal.SurfaceGui.Enabled = Visible
end

local function SetChoicesActive(WorldInstance: WorldInstance, Visible: boolean, FreeTouchEnabled: boolean): boolean
	local FreePortal, PaidPortal = GetPortals(WorldInstance)
	if not FreePortal or not PaidPortal then
		return false
	end

	local PortalConfig = World1Config.RewardPortals
	FreePortal.TextLabel.Text = PortalConfig.FreeLabel
	PaidPortal.TextLabel.Text = PortalConfig.PaidLabel
	SetPortalActive(FreePortal, Visible, FreeTouchEnabled)
	SetPortalActive(PaidPortal, Visible, false)
	return true
end

local function IsCurrentOwner(WorldInstance: WorldInstance, Player: Player): boolean
	if Player ~= WorldInstance.OwnerPlayer or Player.UserId ~= WorldInstance.OwnerUserId then
		return false
	end

	local Session = Sessions.Get(Player)
	return Session ~= nil
		and not Session.ProfileMutationsFrozen
		and Session.State == "InWorld"
		and Session.CurrentWorldInstanceId == WorldInstance.WorldInstanceId
		and WorldInstances.Get(Player) == WorldInstance
end

local function RecoverPlayer(WorldInstanceService: any, Player: Player, Reason: string, Respawn: boolean)
	local Recovered, RecoveryError = pcall(function()
		WorldInstanceService:RecoverPlayer(Player, Reason, Respawn)
	end)
	if not Recovered then
		Logger.Warn(
			"RewardPortal",
			"Recovery failed for PlayerUserId=%d (%s): %s",
			Player.UserId,
			Reason,
			tostring(RecoveryError)
		)
	end
end

local function TryFreeChoice(WorldInstance: WorldInstance, Hit: BasePart, WorldInstanceService: any)
	if WorldInstance.RewardState ~= "Choosing" then
		return
	end

	local Player = GetPlayerFromHit(Hit)
	if not Player or not IsCurrentOwner(WorldInstance, Player) then
		return
	end

	WorldInstance.RewardState = "Settled"
	SetChoicesActive(WorldInstance, false, false)

	local ServicesFound, DestructionService, SessionService = pcall(function()
		return ServiceRegistry.Get("DestructionService"), ServiceRegistry.Get("SessionService")
	end)
	if not ServicesFound or not DestructionService or not SessionService then
		RecoverPlayer(WorldInstanceService, Player, "MissingFreeRewardServices", false)
		return
	end

	local Granted, GrantSuccess = pcall(function()
		return DestructionService:GrantDestruction(Player, World1Config.RewardPortals.FreeDestruction)
	end)
	if not Granted or not GrantSuccess then
		RecoverPlayer(WorldInstanceService, Player, "FreeRewardGrantFailed", false)
		return
	end

	local Transitioned, TransitionSuccess = pcall(function()
		return SessionService:TransitionState(Player, "InWorld", "Returning")
	end)
	if not Transitioned or not TransitionSuccess then
		RecoverPlayer(WorldInstanceService, Player, "FreeRewardTransitionFailed", false)
		return
	end

	local Returned, ReturnSuccess = pcall(function()
		return WorldInstanceService:ReturnPlayerToLobby(Player)
	end)
	if not Returned or not ReturnSuccess then
		RecoverPlayer(WorldInstanceService, Player, "FreeRewardReturnFailed", true)
		return
	end

	RecoverPlayer(WorldInstanceService, Player, "FreeRewardSettled", false)
	local Debounced = pcall(function()
		ServiceRegistry.Get("PortalService"):HoldDebounce(Player, World1Config.ReturnPortalDebounceSeconds)
	end)
	if not Debounced then
		Logger.Warn("RewardPortal", "Return portal debounce failed for PlayerUserId=%d", Player.UserId)
	end
end

--// Service \\--

local RewardPortalService = {}

function RewardPortalService:Init() end

function RewardPortalService:Start() end

function RewardPortalService:BindWorld(WorldInstance: WorldInstance, WorldInstanceService: any): boolean
	local FreePortal, PaidPortal = GetPortals(WorldInstance)
	if not FreePortal or not PaidPortal then
		Logger.Warn(
			"RewardPortal",
			"Portal hierarchy missing for PlayerUserId=%d WorldInstanceId=%s",
			WorldInstance.OwnerUserId,
			WorldInstance.WorldInstanceId
		)
		return false
	end

	WorldInstance.RewardState = "Inactive"
	if not SetChoicesActive(WorldInstance, false, false) then
		return false
	end

	table.insert(
		WorldInstance.Connections,
		FreePortal.Trigger.Touched:Connect(function(Hit)
			TryFreeChoice(WorldInstance, Hit, WorldInstanceService)
		end)
	)
	return true
end

function RewardPortalService:ActivateChoices(WorldInstance: WorldInstance, _WorldInstanceService: any): boolean
	if
		WorldInstance.RewardState ~= "Inactive"
		or WorldInstance.ObjectiveActive
		or not WorldInstance.ObjectiveCompleted
		or not IsCurrentOwner(WorldInstance, WorldInstance.OwnerPlayer)
	then
		return false
	end

	if not SetChoicesActive(WorldInstance, true, true) then
		return false
	end
	WorldInstance.RewardState = "Choosing"
	return true
end

return RewardPortalService
