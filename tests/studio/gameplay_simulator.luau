--!strict
-- tests/studio/gameplay_simulator.luau
-- Automated Gameplay Simulator harness for MVP-007 Multi-Map Teleporter System & Forest Zone (Maps 1-3)
-- Can be executed via execute_luau in Roblox Studio during Play Solo mode.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local Core = game.ServerScriptService.BiggerServer.Core
local GameLayer = game.ServerScriptService.BiggerServer.Game

local Sessions = require(Core.Registry.RuntimeRegistry.Sessions)
local WorldInstances = require(Core.Registry.RuntimeRegistry.WorldInstances)
local MapsConfig = require(GameLayer.Config.MapsConfig)
local PortalService = require(GameLayer.Services.PortalService)
local WorldInstanceService = require(GameLayer.Services.WorldInstanceService)
local DestructionService = require(GameLayer.Services.DestructionService)
local RewardPortalService = require(GameLayer.Services.RewardPortalService)
local EventBus = require(Core.Events.EventBus)

local GameplaySimulator = {}

local function Log(Step: string, Message: string)
	print(string.format("[GameplaySimulator] [%s] %s", Step, Message))
end

local function GetActivePlayer(): Player
	local Deadline = os.clock() + 10
	repeat
		local Player = Players:GetPlayers()[1]
		if Player and Player.Character and Sessions.Get(Player) then
			return Player
		end
		task.wait(0.1)
	until os.clock() >= Deadline
	error("[GameplaySimulator] Timed out waiting for active player with loaded session", 2)
end

function GameplaySimulator.Step1_LobbyBaseline(): Player
	Log("STEP 1", "Verifying Lobby Baseline & Player Spawn...")
	local Player = GetActivePlayer()
	local Character = Player.Character
	assert(Character, "Character missing")

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	local RootPart = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	assert(Humanoid and RootPart, "Humanoid or RootPart missing")

	local Session = Sessions.Get(Player)
	assert(Session, "Player authoritative session missing")
	assert(Session.State == "InLobby", string.format("Expected state InLobby, got %s", Session.State))

	Log(
		"STEP 1",
		string.format(
			"Passed! Player %s (UserId=%d) in Lobby at scale %s",
			Player.Name,
			Player.UserId,
			tostring(Session.Bigger)
		)
	)
	return Player
end

function GameplaySimulator.Step2_TeleporterArch(): BasePart
	Log("STEP 2", "Verifying Workspace Teleporter Master Arch...")
	local Teleporter = Workspace:FindFirstChild("Teleporter")
	assert(Teleporter, "Workspace.Teleporter missing")

	local TouchZone = Teleporter:FindFirstChild("TeleporterTouchZone", true) :: BasePart?
	assert(TouchZone and TouchZone:IsA("BasePart"), "TeleporterTouchZone missing or not a BasePart")

	local Prompt = Teleporter:FindFirstChildWhichIsA("ProximityPrompt", true)
	assert(Prompt, "Teleporter ProximityPrompt missing")

	Log("STEP 2", "Passed! Teleporter arch, TouchZone, and ProximityPrompt verified in Workspace.")
	return TouchZone
end

function GameplaySimulator.Step3_TestMapFlow(Player: Player, MapId: string)
	Log("STEP 3", string.format("Testing full loop for %s...", MapId))
	local MapDef = MapsConfig.GetMap(MapId)
	assert(MapDef, string.format("MapsConfig definition missing for %s", MapId))

	-- 1. Ensure Player meets requirements
	Sessions.Mutate(Player, function(Session)
		if Session.Bigger < MapDef.RequiredSize then
			Session.Bigger = MapDef.RequiredSize + 100
		end
		Session.State = "InLobby"
	end)

	local Session = Sessions.Get(Player)
	assert(Session, "Session missing")

	-- 2. Simulate Teleportation / Map Selection
	PortalService:ClearDebounce(Player)
	Log("STEP 3", string.format("Requesting SelectMap for %s...", MapId))
	local Selected = PortalService:SelectMap(Player, MapId)
	assert(Selected, string.format("PortalService:SelectMap failed for %s", MapId))

	local WorldInstance = WorldInstances.Get(Player)
	assert(WorldInstance, string.format("WorldInstance missing after SelectMap for %s", MapId))
	local InstanceMapId = WorldInstance.MapId or WorldInstance.Model:GetAttribute("MapId")
	assert(
		InstanceMapId == MapId,
		string.format("WorldInstance MapId mismatch: expected %s, got %s", MapId, tostring(InstanceMapId))
	)

	-- 3. Verify Scale-Adaptive Spawn Position
	local Character = Player.Character
	assert(Character, "Character missing")
	local RootPart = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	assert(RootPart, "HumanoidRootPart missing")

	local EntrySpawn = WorldInstance.Model:FindFirstChild("EntrySpawn", true) :: BasePart?
	assert(EntrySpawn, "EntrySpawn missing in WorldInstance")
	local ExpectedMinY = EntrySpawn.Position.Y + 3
	assert(
		RootPart.Position.Y >= ExpectedMinY - 1,
		string.format(
			"Scale-Adaptive Spawn check failed: Player Y=%.2f < ExpectedMinY=%.2f",
			RootPart.Position.Y,
			ExpectedMinY
		)
	)

	-- 4. Activate World & Objective
	DestructionService:ActivateWorld(WorldInstance)
	assert(WorldInstance.ObjectiveActive == true, "Objective failed to activate")

	-- 5. Stomp & Debris Shatter
	local PreDestruction = Session.Destruction
	Log(
		"STEP 3",
		string.format("Simulating Stomp & Shatter for objective %s in %s...", MapDef.Objective.ModelName, MapId)
	)
	local StompSuccess = DestructionService:CompleteObjective(WorldInstance, WorldInstanceService)
	assert(StompSuccess, string.format("CompleteObjective failed for %s", MapId))
	assert(WorldInstance.ObjectiveCompleted == true, "Objective not marked completed")
	assert(WorldInstance.RewardState == "Choosing", "Expected RewardState to be Choosing after stomp")
	assert(
		Session.Destruction == PreDestruction,
		string.format(
			"Premature reward bug: Destruction was incremented upon stomp! PreDestruction=%d, Current=%d",
			PreDestruction,
			Session.Destruction
		)
	)

	-- 6. Settle Free Reward via UI Remote
	Log("STEP 3", string.format("Settling Free Reward via UI remote (PreDestruction=%d)...", PreDestruction))
	local Settled = RewardPortalService:RequestClaimReward(Player, "Free")
	assert(Settled, string.format("RequestClaimReward failed for %s", MapId))

	local PostDestruction = Session.Destruction
	local ExpectedReward = MapDef.Rewards.FreeDestruction
	assert(
		PostDestruction == PreDestruction + ExpectedReward,
		string.format(
			"Destruction reward mismatch: expected +%d, got %d -> %d",
			ExpectedReward,
			PreDestruction,
			PostDestruction
		)
	)

	-- 7. Verify Return to Lobby & Cleanup
	assert(Sessions.Get(Player).State == "InLobby", "Player not returned to InLobby state")
	assert(WorldInstances.Get(Player) == nil, "WorldInstance was not cleaned up after reward settlement")

	Log("STEP 3", string.format("Passed! %s loop succeeded (+%d Destruction).", MapId, ExpectedReward))
end

function GameplaySimulator.Step4_TitanWalkingAndMovementGrowth(Player: Player)
	Log("STEP 4", "Verifying 500k Titan Scale, WalkSpeed curve, and Movement Growth...")

	local Character = Player.Character
	assert(Character, "Character missing")
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	assert(Humanoid, "Humanoid missing")
	local RootPart = Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	assert(RootPart, "HumanoidRootPart missing")

	-- 1. Set Bigger to 500,000 to trigger Titan Scaling
	Sessions.Mutate(Player, function(Session)
		Session.Bigger = 500000
		Session.State = "InLobby"
	end)
	EventBus.Publish("BiggerChanged", Player, 500000)
	task.wait(0.6)

	-- 2. Verify VisualScale
	local VisualScale = Player:GetAttribute("VisualScale") :: number?
	assert(
		VisualScale and VisualScale >= 40.0 and VisualScale <= 45.0,
		string.format("Expected VisualScale ~43.0 at 500k Bigger, got %s", tostring(VisualScale))
	)

	-- 3. Verify Heavy Titan WalkSpeed curve (math.clamp(16 * (VisualScale ^ 0.22), 16, 32))
	local WalkSpeed = Humanoid.WalkSpeed
	assert(
		WalkSpeed >= 31.5 and WalkSpeed <= 32.5,
		string.format("Titan WalkSpeed must be clamped at 32.0 studs/s at scale 43, got %.2f", WalkSpeed)
	)

	Log(
		"STEP 4",
		string.format(
			"VisualScale = %.2f, WalkSpeed = %.2f studs/s (Heavy Titan Stride verified)",
			VisualScale,
			WalkSpeed
		)
	)

	-- 4. Verify MovementGrowthSystem grants Bigger when walking
	local InitialBigger = Sessions.Get(Player).Bigger
	Log("STEP 4", string.format("Simulating titan walking displacement at WalkSpeed=%.2f studs/s...", WalkSpeed))

	-- Move RootPart forward over several ticks to accumulate distance
	local MoveVector = Vector3.new(0, 0, 1)
	for _ = 1, 6 do
		RootPart.CFrame = RootPart.CFrame + MoveVector * (WalkSpeed * 0.2)
		task.wait(0.2)
	end

	-- Allow MovementGrowthSystem tick to settle
	task.wait(0.5)

	local FinalBigger = Sessions.Get(Player).Bigger
	assert(
		FinalBigger > InitialBigger,
		string.format("Movement growth failed: initial Bigger=%.0f, final Bigger=%.0f", InitialBigger, FinalBigger)
	)

	Log(
		"STEP 4",
		string.format(
			"Passed! Walking granted Bigger growth (%.0f -> %.0f). Movement anti-cheat allows giant locomotion!",
			InitialBigger,
			FinalBigger
		)
	)
end

function GameplaySimulator.RunAll()
	print("\n=======================================================")
	print("       STARTING MVP-007 GAMEPLAY SIMULATOR HARNESS      ")
	print("=======================================================\n")

	local Player = GameplaySimulator.Step1_LobbyBaseline()
	GameplaySimulator.Step2_TeleporterArch()

	for _, mapId in ipairs({ "MAP1", "MAP2", "MAP3" }) do
		GameplaySimulator.Step3_TestMapFlow(Player, mapId)
		task.wait(1.6)
	end

	GameplaySimulator.Step4_TitanWalkingAndMovementGrowth(Player)

	print("\n=======================================================")
	print("  ALL MVP-007 MULTI-MAP SIMULATOR CHECKS PASSED (100%) ")
	print("=======================================================\n")
	return true
end

return GameplaySimulator
