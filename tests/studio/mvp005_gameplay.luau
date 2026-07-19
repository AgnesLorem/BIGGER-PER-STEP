--!strict

local HttpService = game:GetService("HttpService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")

local Core = game.ServerScriptService.BiggerServer.Core
local GameLayer = game.ServerScriptService.BiggerServer.Game
local DeveloperProductConfig = require(Core.Config.DeveloperProductConfig)
local GamePassConfig = require(Core.Config.GamePassConfig)
local EventBus = require(Core.Events.EventBus)
local ServiceRegistry = require(Core.Registry.ServiceRegistry)
local Sessions = require(Core.Registry.RuntimeRegistry.Sessions)
local WorldInstances = require(Core.Registry.RuntimeRegistry.WorldInstances)
local ReceiptProcessingService = require(Core.Services.ReceiptProcessingService)
local RewardPortalService = require(GameLayer.Services.RewardPortalService)
local World1Config = require(GameLayer.Config.World1Config)

local TEST_SYNTHETIC_DISCONNECTED_USER_ID = 2147480000
local TEST_SYNTHETIC_UNKNOWN_PRODUCT_OFFSET = 1000000

local MVP005Gameplay = {}

local function WaitForPlayerAndSession(): (Player, Sessions.Session)
	local Deadline = os.clock() + 15
	repeat
		local Player = Players:GetPlayers()[1]
		if Player then
			local Session = Sessions.Get(Player)
			if Session then
				return Player, Session
			end
		end
		task.wait(0.1)
	until os.clock() >= Deadline
	error("MVP005 Studio: authoritative session did not load", 2)
end

local function World1Product()
	local ProductConfig = DeveloperProductConfig.World1TripleReward
	assert(ProductConfig, "World1TripleReward configuration missing")
	assert(ProductConfig.Surface == "PortalOnly", "World1TripleReward must be portal-only")
	assert(ProductConfig.Price == 29, "World1TripleReward price mismatch")
	assert(#ProductConfig.Rewards == 1, "World1TripleReward must contain one reward")
	assert(ProductConfig.Rewards[1].Type == "Destruction", "World1TripleReward reward type mismatch")
	assert(ProductConfig.Rewards[1].Amount == 3, "World1TripleReward reward amount mismatch")
	return ProductConfig
end

local function FindPortal(Template: Instance, Name: string): Instance
	local Portal = Template:FindFirstChild(Name)
	assert(Portal, `WORLD1.{Name} missing`)
	assert(Portal:FindFirstChild("Visual"), `{Name}.Visual missing`)
	assert(Portal:FindFirstChild("Trigger"), `{Name}.Trigger missing`)
	local LabelPart = Portal:FindFirstChild("LabelPart")
	assert(LabelPart, `{Name}.LabelPart missing`)
	local SurfaceGui = LabelPart:FindFirstChild("SurfaceGui")
	assert(SurfaceGui, `{Name}.LabelPart.SurfaceGui missing`)
	assert(SurfaceGui:FindFirstChild("TextLabel"), `{Name}.LabelPart.SurfaceGui.TextLabel missing`)
	return Portal
end

local function SyntheticReceipt(PlayerId: number, ProductId: number, PurchaseId: string)
	return {
		PlayerId = PlayerId,
		PlaceIdAssociatedWithPurchase = game.PlaceId,
		ProductId = ProductId,
		PurchaseId = PurchaseId,
		CurrencyType = Enum.CurrencyType.Robux,
		CurrencySpent = 0,
	}
end

local function RunConfigAndAssets()
	local ProductConfig = World1Product()
	assert(type(ProductConfig.ProductId) == "number" and ProductConfig.ProductId > 0, "real ProductId missing")
	assert(GamePassConfig.Vip.Price == 199, "VIP price mismatch")
	assert(GamePassConfig.PremiumZone.Price == 99, "Premium Zone price mismatch")

	local WorldTemplates = ServerStorage:FindFirstChild(World1Config.TemplateFolderName)
	local Template = WorldTemplates and WorldTemplates:FindFirstChild(World1Config.TemplateName)
	assert(Template, "WORLD1 template missing")
	local FreePortal = FindPortal(Template, "FreeRewardPortal")
	local PaidPortal = FindPortal(Template, "PaidRewardPortal")
	assert((FreePortal:FindFirstChild("Trigger") :: BasePart).CanTouch == false, "free portal started active")
	assert((PaidPortal:FindFirstChild("Trigger") :: BasePart).CanTouch == false, "paid portal started active")
end

local function RunPromptCorrelation()
	local Player, Session = WaitForPlayerAndSession()
	local WorldInstance = WorldInstances.Get(Player)
	assert(WorldInstance, "enter WORLD1 before running prompt-correlation stage")
	WorldInstance.ObjectiveActive = false
	WorldInstance.ObjectiveCompleted = true
	local WorldInstanceService = ServiceRegistry.Get("WorldInstanceService")
	assert(
		RewardPortalService:ActivateChoices(WorldInstance, WorldInstanceService) == true,
		"reward choices did not activate"
	)
	assert(WorldInstance.RewardState == "Choosing", "reward state did not enter Choosing")

	WorldInstance.RewardState = "AwaitingReceipt"
	WorldInstance.PendingRewardPrompt = {
		WorldInstanceId = "TEST_SYNTHETIC_MISMATCHED_WORLD",
		ProductKey = "World1TripleReward",
		ProductId = World1Product().ProductId,
		PromptToken = "TEST_SYNTHETIC_MISMATCHED_TOKEN",
		State = "AwaitingReceipt",
	}
	EventBus.Publish("DeveloperProductCommitted", Player, "World1TripleReward", "TEST_SYNTHETIC_MISMATCHED_PURCHASE")
	assert(WorldInstance.RewardState == "AwaitingReceipt", "mismatched receipt settled the world")
	assert(Session.State == "InWorld", "mismatched receipt returned the player")

	local CurrentPromptToken = "TEST_SYNTHETIC_CURRENT_PROMPT_TOKEN"
	WorldInstance.PromptToken = CurrentPromptToken
	WorldInstance.RewardPromptToken = CurrentPromptToken
	WorldInstance.PendingRewardPrompt = {
		WorldInstanceId = WorldInstance.WorldInstanceId,
		ProductKey = "World1TripleReward",
		ProductId = World1Product().ProductId,
		PromptToken = "TEST_SYNTHETIC_STALE_PROMPT_TOKEN",
		State = "AwaitingReceipt",
	}
	EventBus.Publish("DeveloperProductCommitted", Player, "World1TripleReward", "TEST_SYNTHETIC_STALE_TOKEN_PURCHASE")
	assert(WorldInstance.RewardState == "AwaitingReceipt", "stale prompt token settled the world")
	assert(Session.State == "InWorld", "stale prompt token returned the player")

	WorldInstance.PendingRewardPrompt.PromptToken = CurrentPromptToken
	Session.CurrentWorldInstanceId = "TEST_SYNTHETIC_NEWER_WORLD"
	EventBus.Publish("DeveloperProductCommitted", Player, "World1TripleReward", "TEST_SYNTHETIC_OLDER_WORLD_PURCHASE")
	assert(WorldInstance.RewardState == "AwaitingReceipt", "older receipt settled a newer world")
	assert(Session.State == "InWorld", "older receipt returned the newer world")

	Session.CurrentWorldInstanceId = WorldInstance.WorldInstanceId
	EventBus.Publish("DeveloperProductCommitted", Player, "World1TripleReward", "TEST_SYNTHETIC_MATCHING_PURCHASE")
	assert(WorldInstance.RewardState == "Settled", "matching committed receipt did not settle")
	assert(Session.State == "InLobby", "matching committed receipt did not return to Lobby")
	assert(WorldInstances.Get(Player) == nil, "matching committed receipt left the old world registered")
end

local function RunSyntheticReceipts()
	local Player, Session = WaitForPlayerAndSession()
	local ProductConfig = World1Product()
	local ProcessReceipt = MarketplaceService.ProcessReceipt
	assert(type(ProcessReceipt) == "function", "ProcessReceipt was not registered")
	assert(ReceiptProcessingService, "ReceiptProcessingService missing")
	local ActiveWorld = WorldInstances.Get(Player)
	assert(ActiveWorld, "enter WORLD1 before running synthetic receipt stage")
	ActiveWorld.RewardState = "Choosing"
	ActiveWorld.PendingRewardPrompt = nil

	local PurchaseId = "MVP005_SYNTHETIC_NORMAL_" .. HttpService:GenerateGUID(false)
	local Before = Session.Destruction
	local Decision = ProcessReceipt(SyntheticReceipt(Player.UserId, ProductConfig.ProductId, PurchaseId))
	assert(Decision == Enum.ProductPurchaseDecision.PurchaseGranted, "synthetic normal receipt was not granted")
	assert(Session.Destruction == Before + 3, "synthetic normal receipt did not grant exactly 3 Destruction")
	local DuplicateDecision = ProcessReceipt(SyntheticReceipt(Player.UserId, ProductConfig.ProductId, PurchaseId))
	assert(
		DuplicateDecision == Enum.ProductPurchaseDecision.PurchaseGranted,
		"synthetic duplicate was not acknowledged"
	)
	assert(Session.Destruction == Before + 3, "synthetic duplicate granted twice")

	local UnknownProductId = ProductConfig.ProductId + TEST_SYNTHETIC_UNKNOWN_PRODUCT_OFFSET
	local UnknownDecision = ProcessReceipt(
		SyntheticReceipt(
			Player.UserId,
			UnknownProductId,
			"MVP005_SYNTHETIC_WRONG_PRODUCT_" .. HttpService:GenerateGUID(false)
		)
	)
	assert(UnknownDecision == Enum.ProductPurchaseDecision.NotProcessedYet, "synthetic wrong product was granted")
	assert(Session.Destruction == Before + 3, "synthetic wrong product mutated Destruction")

	local DisconnectedDecision = ProcessReceipt(
		SyntheticReceipt(
			TEST_SYNTHETIC_DISCONNECTED_USER_ID,
			ProductConfig.ProductId,
			"MVP005_SYNTHETIC_DISCONNECTED_" .. HttpService:GenerateGUID(false)
		)
	)
	assert(DisconnectedDecision == Enum.ProductPurchaseDecision.NotProcessedYet, "disconnected receipt was granted")
	assert(Session.Destruction == Before + 3, "disconnected receipt mutated Destruction")

	local DelayedPurchaseId = "MVP005_SYNTHETIC_DELAYED_" .. HttpService:GenerateGUID(false)
	local DelayedDecision = ProcessReceipt(SyntheticReceipt(Player.UserId, ProductConfig.ProductId, DelayedPurchaseId))
	assert(DelayedDecision == Enum.ProductPurchaseDecision.PurchaseGranted, "synthetic delayed receipt was not granted")
	assert(Session.Destruction == Before + 6, "synthetic delayed receipt did not grant exactly once")
	assert(WorldInstances.Get(Player) == ActiveWorld, "synthetic delayed receipt cleaned the active world")
	assert(ActiveWorld.RewardState == "Choosing", "synthetic delayed receipt settled an uncorrelated world")
	assert(Session.State == "InWorld", "synthetic delayed receipt returned an uncorrelated world")

	local WorldInstanceService = ServiceRegistry.Get("WorldInstanceService")
	WorldInstanceService:ClearPlayerRuntime(Player)
	assert(WorldInstances.Get(Player) == nil, "synthetic post-cleanup setup left a world registered")
	assert(Session.State == "InLobby", "synthetic post-cleanup setup did not recover Lobby state")
	local PostCleanupPurchaseId = "MVP005_SYNTHETIC_POST_CLEANUP_" .. HttpService:GenerateGUID(false)
	local PostCleanupDecision =
		ProcessReceipt(SyntheticReceipt(Player.UserId, ProductConfig.ProductId, PostCleanupPurchaseId))
	assert(
		PostCleanupDecision == Enum.ProductPurchaseDecision.PurchaseGranted,
		"synthetic post-cleanup receipt was not granted"
	)
	assert(Session.Destruction == Before + 9, "synthetic post-cleanup receipt did not grant exactly once")
	assert(WorldInstances.Get(Player) == nil, "synthetic post-cleanup receipt recreated or settled a world")
	assert(Session.State == "InLobby", "synthetic post-cleanup receipt changed Lobby state")
end

function MVP005Gameplay.Run(Stage: number)
	assert(type(Stage) == "number" and Stage % 1 == 0 and Stage >= 1 and Stage <= 3, "Stage must be 1, 2, or 3")
	if Stage == 1 then
		RunConfigAndAssets()
	elseif Stage == 2 then
		RunPromptCorrelation()
	else
		RunSyntheticReceipts()
	end
	print(string.format("[MVP005 Studio synthetic] Stage %d: PASS", Stage))
end

return table.freeze(MVP005Gameplay)
