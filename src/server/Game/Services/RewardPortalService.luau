--!strict
--// Raw Requirings \\--

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")

--// Requirings \\--

local Sessions = require(script.Parent.Parent.Parent.Core.Registry.RuntimeRegistry.Sessions)
local WorldInstances = require(script.Parent.Parent.Parent.Core.Registry.RuntimeRegistry.WorldInstances)
local ServiceRegistry = require(script.Parent.Parent.Parent.Core.Registry.ServiceRegistry)
local Logger = require(script.Parent.Parent.Parent.Core.Utilities.Logger)
local World1Config = require(script.Parent.Parent.Config.World1Config)
local DeveloperProductConfig = require(script.Parent.Parent.Parent.Core.Config.DeveloperProductConfig)
local ConfigValidationService = require(script.Parent.Parent.Parent.Core.Services.ConfigValidationService)
local EventBus = require(script.Parent.Parent.Parent.Core.Events.EventBus)

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

local function GetPortals(WorldInstance: WorldInstance): (Portal?, Portal?, Portal?)
	local PortalConfig = World1Config.RewardPortals
	return GetPortal(WorldInstance.Model, PortalConfig.ExitName),
		GetPortal(WorldInstance.Model, PortalConfig.FreeName),
		GetPortal(WorldInstance.Model, PortalConfig.PaidName)
end

local function GetPaidRewardStatus()
	return ConfigValidationService:GetDeveloperProductStatus(World1Config.RewardProductKey)
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

local function SetChoicesActive(WorldInstance: WorldInstance, Visible: boolean, TouchEnabled: boolean): boolean
	local ExitPortal, FreePortal, PaidPortal = GetPortals(WorldInstance)
	if not ExitPortal or not FreePortal or not PaidPortal then
		return false
	end

	local PortalConfig = World1Config.RewardPortals
	ExitPortal.TextLabel.Text = PortalConfig.ExitLabel
	FreePortal.TextLabel.Text = PortalConfig.FreeLabel
	local PaidConfigured = GetPaidRewardStatus().IsConfigured
	PaidPortal.TextLabel.Text = if PaidConfigured then PortalConfig.PaidLabel else "UNAVAILABLE"
	SetPortalActive(ExitPortal, Visible, TouchEnabled)
	SetPortalActive(FreePortal, Visible, TouchEnabled)
	SetPortalActive(PaidPortal, Visible, TouchEnabled and PaidConfigured)
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

local function TryExitChoice(WorldInstance: WorldInstance, Hit: BasePart, WorldInstanceService: any)
	if WorldInstance.RewardState ~= "Choosing" then
		return
	end
	local Player = GetPlayerFromHit(Hit)
	if not Player or not IsCurrentOwner(WorldInstance, Player) then
		return
	end
	WorldInstance.RewardState = "Settled"
	SetChoicesActive(WorldInstance, false, false)

	local Found, SessionService = pcall(function()
		return ServiceRegistry.Get("SessionService")
	end)
	if not Found or not SessionService then
		RecoverPlayer(WorldInstanceService, Player, "MissingExitGateServices", false)
		return
	end
	local Transitioned, TransitionSuccess = pcall(function()
		return SessionService:TransitionState(Player, "InWorld", "Returning")
	end)
	if not Transitioned or not TransitionSuccess then
		RecoverPlayer(WorldInstanceService, Player, "ExitGateTransitionFailed", false)
		return
	end
	local Returned, ReturnSuccess = pcall(function()
		return WorldInstanceService:ReturnPlayerToLobby(Player)
	end)
	if not Returned or not ReturnSuccess then
		RecoverPlayer(WorldInstanceService, Player, "ExitGateReturnFailed", true)
		return
	end
	RecoverPlayer(WorldInstanceService, Player, "ExitGateSettled", false)
	local Debounced = pcall(function()
		ServiceRegistry.Get("PortalService"):HoldDebounce(Player, World1Config.ReturnPortalDebounceSeconds)
	end)
	if not Debounced then
		Logger.Warn("RewardPortal", "Exit gate debounce failed for PlayerUserId=%d", Player.UserId)
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

local function RestoreChoices(WorldInstance: WorldInstance)
	WorldInstance.PendingRewardPrompt = nil
	WorldInstance.RewardState = "Choosing"
	SetChoicesActive(WorldInstance, true, true)
end

local function TryPaidChoice(WorldInstance: WorldInstance, Hit: BasePart, WorldInstanceService: any)
	if WorldInstance.RewardState ~= "Choosing" then
		return
	end

	local Player = GetPlayerFromHit(Hit)
	if not Player or not IsCurrentOwner(WorldInstance, Player) then
		return
	end

	local ProductKey = World1Config.RewardProductKey
	local Product = DeveloperProductConfig[ProductKey]
	local ProductId = Product and Product.ProductId
	local ProductStatus = GetPaidRewardStatus()
	local SaveFound, SaveService = pcall(function()
		return ServiceRegistry.Get("SaveService")
	end)
	if
		not Product
		or not ProductStatus.IsConfigured
		or Product.Surface ~= "PortalOnly"
		or type(ProductId) ~= "number"
		or ProductId <= 0
		or ProductId % 1 ~= 0
		or not SaveFound
		or not SaveService:IsProfileWritable(Player)
	then
		return
	end

	WorldInstance.PendingRewardPrompt = {
		WorldInstanceId = WorldInstance.WorldInstanceId,
		ProductKey = ProductKey,
		ProductId = ProductId,
		PromptToken = HttpService:GenerateGUID(false),
		State = "PromptOpen",
		WorldInstanceService = WorldInstanceService,
	}
	WorldInstance.RewardState = "PromptOpen"
	SetChoicesActive(WorldInstance, true, false)

	local Prompted = pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, Player, ProductId)
	if not Prompted then
		RestoreChoices(WorldInstance)
	end
end

local function OnPromptFinished(UserId: number, ProductId: number, WasPurchased: boolean)
	local Player = Players:GetPlayerByUserId(UserId)
	if not Player then
		return
	end

	local WorldInstance = WorldInstances.Get(Player)
	local Pending = WorldInstance and WorldInstance.PendingRewardPrompt
	if
		not WorldInstance
		or not Pending
		or Pending.State ~= "PromptOpen"
		or Pending.ProductId ~= ProductId
		or not IsCurrentOwner(WorldInstance, Player)
	then
		return
	end

	if not WasPurchased then
		RestoreChoices(WorldInstance)
		return
	end

	Pending.State = "AwaitingReceipt"
	WorldInstance.RewardState = "AwaitingReceipt"
end

local function OnProductCommitted(Player: Player, ProductKey: string, _PurchaseId: string)
	local WorldInstance = WorldInstances.Get(Player)
	local Pending = WorldInstance and WorldInstance.PendingRewardPrompt
	if
		not WorldInstance
		or not Pending
		or Pending.State ~= "AwaitingReceipt"
		or Pending.ProductKey ~= ProductKey
		or not IsCurrentOwner(WorldInstance, Player)
	then
		return
	end

	local WorldInstanceService = Pending.WorldInstanceService
	WorldInstance.PendingRewardPrompt = nil
	WorldInstance.RewardState = "Settled"
	SetChoicesActive(WorldInstance, false, false)

	local ServicesFound, SessionService = pcall(function()
		return ServiceRegistry.Get("SessionService")
	end)
	if not ServicesFound or not SessionService then
		RecoverPlayer(WorldInstanceService, Player, "MissingPaidRewardServices", false)
		return
	end
	if not SessionService:TransitionState(Player, "InWorld", "Returning") then
		RecoverPlayer(WorldInstanceService, Player, "PaidRewardTransitionFailed", false)
		return
	end
	if not WorldInstanceService:ReturnPlayerToLobby(Player) then
		RecoverPlayer(WorldInstanceService, Player, "PaidRewardReturnFailed", true)
		return
	end
	RecoverPlayer(WorldInstanceService, Player, "PaidRewardSettled", false)
end

--// Service \\--

local RewardPortalService = {}
local Initialized = false

function RewardPortalService:Init()
	if Initialized then
		return
	end
	Initialized = true
	MarketplaceService.PromptProductPurchaseFinished:Connect(OnPromptFinished)
	EventBus.Subscribe("DeveloperProductCommitted", OnProductCommitted)
end

function RewardPortalService:Start() end

function RewardPortalService:GetPaidRewardStatus()
	return GetPaidRewardStatus()
end

function RewardPortalService:BindWorld(WorldInstance: WorldInstance, WorldInstanceService: any): boolean
	local ExitPortal, FreePortal, PaidPortal = GetPortals(WorldInstance)
	if not ExitPortal or not FreePortal or not PaidPortal then
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
		ExitPortal.Trigger.Touched:Connect(function(Hit)
			TryExitChoice(WorldInstance, Hit, WorldInstanceService)
		end)
	)
	table.insert(
		WorldInstance.Connections,
		FreePortal.Trigger.Touched:Connect(function(Hit)
			TryFreeChoice(WorldInstance, Hit, WorldInstanceService)
		end)
	)
	table.insert(
		WorldInstance.Connections,
		PaidPortal.Trigger.Touched:Connect(function(Hit)
			TryPaidChoice(WorldInstance, Hit, WorldInstanceService)
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
