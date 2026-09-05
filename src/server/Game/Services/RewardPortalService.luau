--!strict
--// Raw Requirings \\--

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorageFound, ReplicatedStorage = pcall(function()
	return game:GetService("ReplicatedStorage")
end)

--// Requirings \\--

local Sessions = require(script.Parent.Parent.Parent.Core.Registry.RuntimeRegistry.Sessions)
local WorldInstances = require(script.Parent.Parent.Parent.Core.Registry.RuntimeRegistry.WorldInstances)
local ServiceRegistry = require(script.Parent.Parent.Parent.Core.Registry.ServiceRegistry)
local Logger = require(script.Parent.Parent.Parent.Core.Utilities.Logger)
local ConfigFolder = script.Parent.Parent.Config
local MapsConfig = require((ConfigFolder :: any).MapsConfig or (ConfigFolder :: any).World1Config)
local DeveloperProductConfig = require(script.Parent.Parent.Parent.Core.Config.DeveloperProductConfig)
local ConfigValidationService = require(script.Parent.Parent.Parent.Core.Services.ConfigValidationService)
local EventBus = require(script.Parent.Parent.Parent.Core.Events.EventBus)

--// Types \\--

type WorldInstance = WorldInstances.WorldInstance

--// Variables \\--

local ShowRewardPopupRemote: RemoteEvent? = nil
local RequestClaimRewardRemote: RemoteEvent? = nil

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

local function GetMapConfigForInstance(WorldInstance: any): any
	local MapId = WorldInstance.MapId
	if not MapId and WorldInstance.Model then
		local Model = WorldInstance.Model
		if typeof(Model) == "Instance" or (typeof(Model) == "table" and typeof(Model.GetAttribute) == "function") then
			MapId = Model:GetAttribute("MapId")
		end
	end
	if MapsConfig and MapsConfig.GetMap then
		return MapsConfig.GetMap(MapId or "MAP1") or MapsConfig.Maps["MAP1"]
	end
	local FallbackProductKey = (MapsConfig and MapsConfig.RewardProductKey) or "World1TripleReward"
	return {
		MapId = (MapsConfig and MapsConfig.WorldId) or "WORLD1",
		Rewards = (MapsConfig and (MapsConfig.Rewards or MapsConfig.RewardPortals)) or {
			FreeName = "FreeRewardPortal",
			PaidName = "PaidRewardPortal",
			FreeDestruction = 1,
			PaidDestruction = 3,
			PaidProductKey = FallbackProductKey,
			FreeLabel = "FREE\n+1 DESTRUCTION",
			PaidLabel = "3 DESTRUCTION • 29 R$",
		},
	}
end

local function GetPaidRewardStatus(ProductKey: string)
	return ConfigValidationService:GetDeveloperProductStatus(ProductKey)
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

local function ExecuteFreeChoice(WorldInstance: WorldInstance, Player: Player, WorldInstanceService: any): boolean
	if WorldInstance.RewardState ~= "Choosing" then
		return false
	end

	if not IsCurrentOwner(WorldInstance, Player) then
		return false
	end

	WorldInstance.RewardState = "Settled"

	local ServicesFound, DestructionService, SessionService = pcall(function()
		return ServiceRegistry.Get("DestructionService"), ServiceRegistry.Get("SessionService")
	end)
	if not ServicesFound or not DestructionService or not SessionService then
		RecoverPlayer(WorldInstanceService, Player, "MissingFreeRewardServices", false)
		return false
	end

	local MapConfig = GetMapConfigForInstance(WorldInstance)
	local FreeRewardAmount = if MapConfig.Rewards and MapConfig.Rewards.FreeDestruction
		then MapConfig.Rewards.FreeDestruction
		else 1

	local Granted, GrantSuccess = pcall(function()
		return DestructionService:GrantDestruction(Player, FreeRewardAmount)
	end)
	if not Granted or not GrantSuccess then
		RecoverPlayer(WorldInstanceService, Player, "FreeRewardGrantFailed", false)
		return false
	end

	local Transitioned, TransitionSuccess = pcall(function()
		return SessionService:TransitionState(Player, "InWorld", "Returning")
	end)
	if not Transitioned or not TransitionSuccess then
		RecoverPlayer(WorldInstanceService, Player, "FreeRewardTransitionFailed", false)
		return false
	end

	local Returned, ReturnSuccess = pcall(function()
		return WorldInstanceService:ReturnPlayerToLobby(Player)
	end)
	if not Returned or not ReturnSuccess then
		RecoverPlayer(WorldInstanceService, Player, "FreeRewardReturnFailed", true)
		return false
	end

	RecoverPlayer(WorldInstanceService, Player, "FreeRewardSettled", false)
	local DebounceSeconds = if MapsConfig and MapsConfig.ReturnPortalDebounceSeconds
		then MapsConfig.ReturnPortalDebounceSeconds
		else 1.5
	local Debounced = pcall(function()
		ServiceRegistry.Get("PortalService"):HoldDebounce(Player, DebounceSeconds)
	end)
	if not Debounced then
		Logger.Warn("RewardPortal", "Return portal debounce failed for PlayerUserId=%d", Player.UserId)
	end
	return true
end

local function RestoreChoices(WorldInstance: WorldInstance)
	WorldInstance.PendingRewardPrompt = nil
	WorldInstance.RewardState = "Choosing"
end

local function ExecutePaidChoice(WorldInstance: WorldInstance, Player: Player, WorldInstanceService: any): boolean
	if WorldInstance.RewardState ~= "Choosing" then
		return false
	end

	if not IsCurrentOwner(WorldInstance, Player) then
		return false
	end

	local MapConfig = GetMapConfigForInstance(WorldInstance)
	local ProductKey = if MapConfig.Rewards and MapConfig.Rewards.PaidProductKey
		then MapConfig.Rewards.PaidProductKey
		else ((MapsConfig and MapsConfig.RewardProductKey) or "World1TripleReward")
	local Product = DeveloperProductConfig[ProductKey]
	local ProductId = Product and Product.ProductId
	local ProductStatus = GetPaidRewardStatus(ProductKey)
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
		return false
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

	local Prompted = pcall(MarketplaceService.PromptProductPurchase, MarketplaceService, Player, ProductId)
	if not Prompted then
		RestoreChoices(WorldInstance)
		return false
	end
	return true
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

	ShowRewardPopupRemote = EnsureRemote("ShowRewardPopup")
	RequestClaimRewardRemote = EnsureRemote("RequestClaimReward")
	if RequestClaimRewardRemote and RequestClaimRewardRemote.OnServerEvent then
		RequestClaimRewardRemote.OnServerEvent:Connect(function(Client: Player, Choice: any)
			self:RequestClaimReward(Client, Choice)
		end)
	end

	MarketplaceService.PromptProductPurchaseFinished:Connect(OnPromptFinished)
	EventBus.Subscribe("DeveloperProductCommitted", OnProductCommitted)
end

function RewardPortalService:Start() end

function RewardPortalService:GetPaidRewardStatus(ProductKey: string?)
	return GetPaidRewardStatus(ProductKey or "World1TripleReward")
end

function RewardPortalService:BindWorld(WorldInstance: WorldInstance, _WorldInstanceService: any): boolean
	WorldInstance.RewardState = "Inactive"
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

	WorldInstance.RewardState = "Choosing"

	local Player = WorldInstance.OwnerPlayer
	if Player and ShowRewardPopupRemote and ShowRewardPopupRemote.FireClient then
		local MapConfig = GetMapConfigForInstance(WorldInstance)
		local RewardsConfig = MapConfig.Rewards
		local ProductKey = if RewardsConfig and RewardsConfig.PaidProductKey
			then RewardsConfig.PaidProductKey
			else ((MapsConfig and MapsConfig.RewardProductKey) or "World1TripleReward")
		local PaidConfigured = GetPaidRewardStatus(ProductKey).IsConfigured
		local FreeAmount = if RewardsConfig and RewardsConfig.FreeDestruction then RewardsConfig.FreeDestruction else 1
		local PaidAmount = if RewardsConfig and RewardsConfig.PaidDestruction
			then RewardsConfig.PaidDestruction
			else FreeAmount * 3
		local Payload = {
			WorldId = MapConfig.MapId,
			FreeReward = {
				Type = "Destruction",
				Amount = FreeAmount,
				Label = string.format("Claim %dx Free", FreeAmount),
			},
			PaidReward = {
				Type = "Destruction",
				Amount = PaidAmount,
				Price = 29,
				Label = string.format("Claim %dx (29 R$)", PaidAmount),
				ProductKey = ProductKey,
				IsConfigured = PaidConfigured,
			},
		}
		pcall(function()
			ShowRewardPopupRemote:FireClient(Player, Payload)
		end)
	end

	return true
end

function RewardPortalService:RequestClaimReward(Player: Player, Choice: any): boolean
	if not Player or (Player.IsA and not Player:IsA("Player")) then
		return false
	end

	if type(Choice) ~= "string" then
		return false
	end

	local WorldInstance = WorldInstances.Get(Player)
	if not WorldInstance or WorldInstance.RewardState ~= "Choosing" or not IsCurrentOwner(WorldInstance, Player) then
		return false
	end

	local WorldInstanceServiceFound, WorldInstanceService = pcall(function()
		return ServiceRegistry.Get("WorldInstanceService")
	end)
	if not WorldInstanceServiceFound or not WorldInstanceService then
		return false
	end

	if Choice == "Free" then
		return ExecuteFreeChoice(WorldInstance, Player, WorldInstanceService)
	elseif Choice == "PaidTriple" or Choice == "Paid" then
		return ExecutePaidChoice(WorldInstance, Player, WorldInstanceService)
	else
		return false
	end
end

return RewardPortalService
