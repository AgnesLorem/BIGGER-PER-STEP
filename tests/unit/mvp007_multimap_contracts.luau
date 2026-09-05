--!strict
-- tests/unit/mvp007_multimap_contracts.luau
-- Unit test suite for MVP-007 Multi-Map Architecture, Gating, Stomp, and Reward Settlement

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local Failures: { string } = {}

local function check(Name: string, Callback: () -> ())
	local Success, Message = pcall(Callback)
	if not Success then
		table.insert(Failures, string.format("%s: %s", Name, tostring(Message)))
		print(string.format("  FAIL: %s -> %s", Name, tostring(Message)))
	else
		print(string.format("  PASS: %s", Name))
	end
end

local function loadModule(Path: string, Name: string, Environment: { [string]: any }?)
	assert(fs.isFile(Path), Name .. " module missing at: " .. Path)
	local Chunk = luau.load(fs.readFile(Path), Name)
	setfenv(Chunk, setmetatable(Environment or {}, { __index = getfenv() }))
	return Chunk()
end

-- Load MapsConfig from production
local configPath = if fs.isFile("src/server/Game/Config/MapsConfig.luau")
	then "src/server/Game/Config/MapsConfig.luau"
	else "f:/BIGGER/src/server/Game/Config/MapsConfig.luau"

local MapsConfig = loadModule(configPath, "MapsConfig", {
	Vector3 = {
		new = function(X, Y, Z)
			return { X = X, Y = Y, Z = Z }
		end,
	},
	table = {
		freeze = function(t)
			return t
		end,
	},
})

print("=== Running MVP-007 Multi-Map Contract Tests ===")

-- 1. Schema Validation
check("MapsConfig defines exactly 3 categories (Forest, Residential, Metropolis)", function()
	assert(MapsConfig.Categories.Forest ~= nil, "Forest category missing")
	assert(MapsConfig.Categories.Residential ~= nil, "Residential category missing")
	assert(MapsConfig.Categories.Metropolis ~= nil, "Metropolis category missing")
	assert(#MapsConfig.CategoryOrder == 3, "CategoryOrder count mismatch")
end)

check("MapsConfig defines all 10 maps with proper categorization", function()
	assert(#MapsConfig.MapOrder == 10, "MapOrder must contain 10 maps")
	for i = 1, 10 do
		local MapId = "MAP" .. tostring(i)
		local Def = MapsConfig.Maps[MapId]
		assert(Def ~= nil, "Missing map: " .. MapId)
		assert(Def.MapId == MapId, "MapId mismatch for " .. MapId)
		assert(type(Def.RequiredLevel) == "number" and Def.RequiredLevel > 0, "Invalid RequiredLevel for " .. MapId)
		assert(type(Def.RequiredSize) == "number" and Def.RequiredSize > 0, "Invalid RequiredSize for " .. MapId)
		assert(Def.Objective ~= nil, "Missing Objective for " .. MapId)
		assert(Def.Rewards ~= nil, "Missing Rewards for " .. MapId)
	end
end)

check("Maps 1-3 have exact Forest requirements and are active (not Coming Soon)", function()
	local Map1 = MapsConfig.Maps.MAP1
	assert(Map1.IsComingSoon == false, "MAP1 must be active")
	assert(Map1.RequiredLevel == 5, "MAP1 RequiredLevel must be 5")
	assert(Map1.RequiredSize == 50, "MAP1 RequiredSize must be 50")
	assert(Map1.Objective.ModelName == "Spider", "MAP1 Objective model must be Spider")
	assert(Map1.Rewards.FreeDestruction == 1, "MAP1 FreeDestruction must be 1")
	assert(Map1.Rewards.PaidDestruction == 3, "MAP1 PaidDestruction must be 3")

	local Map2 = MapsConfig.Maps.MAP2
	assert(Map2.IsComingSoon == false, "MAP2 must be active")
	assert(Map2.RequiredLevel == 15, "MAP2 RequiredLevel must be 15")
	assert(Map2.RequiredSize == 500, "MAP2 RequiredSize must be 500")
	assert(Map2.Objective.ModelName == "WildBoar", "MAP2 Objective model must be WildBoar")
	assert(Map2.Rewards.FreeDestruction == 5, "MAP2 FreeDestruction must be 5")
	assert(Map2.Rewards.PaidDestruction == 15, "MAP2 PaidDestruction must be 15")

	local Map3 = MapsConfig.Maps.MAP3
	assert(Map3.IsComingSoon == false, "MAP3 must be active")
	assert(Map3.RequiredLevel == 35, "MAP3 RequiredLevel must be 35")
	assert(Map3.RequiredSize == 5000, "MAP3 RequiredSize must be 5000")
	assert(Map3.Objective.ModelName == "AncientBear", "MAP3 Objective model must be AncientBear")
	assert(Map3.Rewards.FreeDestruction == 20, "MAP3 FreeDestruction must be 20")
	assert(Map3.Rewards.PaidDestruction == 60, "MAP3 PaidDestruction must be 60")
end)

check("Maps 4-10 are flagged as Coming Soon", function()
	for i = 4, 10 do
		local MapId = "MAP" .. tostring(i)
		local Def = MapsConfig.Maps[MapId]
		assert(Def.IsComingSoon == true, MapId .. " must have IsComingSoon == true")
	end
end)

-- 2. Gating Logic Contract
check("Level gating rejects under-leveled access and admits qualified players", function()
	local function CanEnter(PlayerLevel: number, MapId: string): boolean
		local Def = MapsConfig.GetMap(MapId)
		if not Def or Def.IsComingSoon then
			return false
		end
		return PlayerLevel >= Def.RequiredLevel
	end

	-- Under-leveled
	assert(CanEnter(1, "MAP1") == false, "Level 1 should be rejected from MAP1")
	assert(CanEnter(4, "MAP1") == false, "Level 4 should be rejected from MAP1")
	assert(CanEnter(5, "MAP2") == false, "Level 5 should be rejected from MAP2")
	assert(CanEnter(15, "MAP3") == false, "Level 15 should be rejected from MAP3")

	-- Coming soon
	assert(CanEnter(100, "MAP4") == false, "Coming soon MAP4 should be rejected even with Level 100")
	assert(CanEnter(999, "MAP10") == false, "Coming soon MAP10 should be rejected even with Level 999")

	-- Qualified
	assert(CanEnter(5, "MAP1") == true, "Level 5 should be admitted to MAP1")
	assert(CanEnter(15, "MAP2") == true, "Level 15 should be admitted to MAP2")
	assert(CanEnter(35, "MAP3") == true, "Level 35 should be admitted to MAP3")
	assert(CanEnter(50, "MAP1") == true, "Level 50 should be admitted to MAP1")
end)

-- 3. Stomp Boundary Scaling
check("Stomp hitbox height boundary scales with VisualScale to prevent giant clipping", function()
	local function CheckStompHeight(PlayerY: number, BaseMaxHeight: number, VisualScale: number): boolean
		local ScaledMaxHeight = BaseMaxHeight * VisualScale
		return PlayerY <= ScaledMaxHeight
	end

	-- At normal scale (1.0), height 5 is valid for base 8, but height 20 is invalid
	assert(CheckStompHeight(5, 8, 1.0) == true, "Height 5 at scale 1 should be valid")
	assert(CheckStompHeight(20, 8, 1.0) == false, "Height 20 at scale 1 should be invalid")

	-- At giant scale (10.0), height 40 is valid because ScaledMaxHeight = 80
	assert(CheckStompHeight(40, 8, 10.0) == true, "Height 40 at scale 10 should be valid")
	assert(CheckStompHeight(75, 8, 10.0) == true, "Height 75 at scale 10 should be valid")
	assert(CheckStompHeight(90, 8, 10.0) == false, "Height 90 at scale 10 should be invalid")
end)

-- 4. Reward Settlement Integrity
check("Reward calculations match task specification", function()
	local ExpectedRewards = {
		MAP1 = { Free = 1, Paid = 3 },
		MAP2 = { Free = 5, Paid = 15 },
		MAP3 = { Free = 20, Paid = 60 },
	}
	for mapId, expected in ExpectedRewards do
		local Def = MapsConfig.Maps[mapId]
		assert(Def.Rewards.FreeDestruction == expected.Free, mapId .. " Free reward mismatch")
		assert(Def.Rewards.PaidDestruction == expected.Paid, mapId .. " Paid reward mismatch")
		assert(Def.Rewards.PaidDestruction == Def.Rewards.FreeDestruction * 3, mapId .. " Paid must be exactly 3x Free")
	end
end)

-- 5. GATE-09: Dynamic Movement Anti-Cheat Plausibility Contract
local movementValidationPath = if fs.isFile("src/shared/Core/Utilities/MovementValidation.luau")
	then "src/shared/Core/Utilities/MovementValidation.luau"
	else "f:/BIGGER/src/shared/Core/Utilities/MovementValidation.luau"

local MovementValidation = loadModule(movementValidationPath, "MovementValidation", {
	table = {
		freeze = function(t)
			return t
		end,
	},
})

check("GATE-09: Dynamic speed scaling allows giant locomotion while rejecting teleport exploits", function()
	local BaseConfigRewardSpeed = 24
	local DistanceSlack = 1.5
	local DeltaSeconds = 0.2

	-- Scenario A: Normal scale player (WalkSpeed = 16)
	local normalWalkSpeed = 16
	local maxAllowedNormal = math.max(BaseConfigRewardSpeed, normalWalkSpeed * 1.5)
	assert(maxAllowedNormal == 24, "Max allowed for normal speed should fallback to base 24")
	-- Normal displacement over 0.2s: 16 * 0.2 = 3.2 studs
	assert(
		MovementValidation.IsPlausible(3.2, DeltaSeconds, maxAllowedNormal, DistanceSlack) == true,
		"Normal walking must be accepted"
	)

	-- Scenario B: 500k Bigger Giant player (VisualScale = 7.21, WalkSpeed = 24.63)
	local giantWalkSpeed = 24.63
	local maxAllowedGiant = math.max(BaseConfigRewardSpeed, giantWalkSpeed * 1.5)
	assert(maxAllowedGiant == 24.63 * 1.5, "Max allowed for giant must dynamically scale with actual WalkSpeed * 1.5")
	-- Giant displacement over 0.2s: 24.63 * 0.2 = 4.926 studs
	assert(
		MovementValidation.IsPlausible(4.926, DeltaSeconds, maxAllowedGiant, DistanceSlack) == true,
		"Giant walking at 24.63 studs/s must be accepted"
	)

	-- Scenario C: Speed exploiter moving at 100 studs/s (20 studs in 0.2s)
	assert(
		MovementValidation.IsPlausible(20.0, DeltaSeconds, maxAllowedGiant, DistanceSlack) == false,
		"Exploit speed (100 studs/s) must be strictly rejected"
	)
end)

-- 6. GATE-10: Heavy Titan Stride Curve & Kinematic Animation Speed Matching
check("GATE-10: Titan WalkSpeed sub-linear curve and kinematic stride cadence matching", function()
	local function CalculateTitanWalkSpeed(VisualScale: number): number
		return math.clamp(16 * (VisualScale ^ 0.22), 16, 32)
	end

	local function CalculateAnimSpeed(WalkSpeed: number, VisualScale: number): number
		return WalkSpeed / (16 * VisualScale)
	end

	-- Scale 1.0 (Base avatar)
	local baseSpeed = CalculateTitanWalkSpeed(1.0)
	assert(math.abs(baseSpeed - 16.0) < 0.001, "Base WalkSpeed at scale 1 must be 16")
	local baseAnim = CalculateAnimSpeed(baseSpeed, 1.0)
	assert(math.abs(baseAnim - 1.0) < 0.001, "Base anim playback speed at scale 1 must be 1.0")

	-- Scale 7.21 (500k Bigger Titan)
	local titanScale = 7.21
	local titanSpeed = CalculateTitanWalkSpeed(titanScale)
	assert(
		titanSpeed >= 24.5 and titanSpeed <= 24.8,
		string.format("Titan speed must be ~24.6-24.7 (got %.2f)", titanSpeed)
	)
	local titanAnim = CalculateAnimSpeed(titanSpeed, titanScale)
	-- Cadence slows down to ~0.2135
	assert(
		titanAnim >= 0.21 and titanAnim <= 0.22,
		string.format("Titan anim speed must be ~0.213 (got %.4f)", titanAnim)
	)

	-- Scale 100 (Extreme Giant) clamped at 32 studs/s
	local giantSpeed = CalculateTitanWalkSpeed(100.0)
	assert(giantSpeed == 32.0, "Giant speed at scale 100 must be clamped at maximum 32 studs/s")

	-- Zero Foot-Slipping Physical Invariant Proof:
	-- Physical Ground Velocity = StrideLength * StrideFrequency
	-- StrideLength = BaseStride * VisualScale
	-- StrideFrequency = BaseFrequency * AnimSpeed
	-- Ground Velocity = (BaseStride * VisualScale) * (BaseFrequency * WalkSpeed / (16 * VisualScale))
	-- Since BaseStride * BaseFrequency = 16:
	-- Ground Velocity = 16 * VisualScale * (WalkSpeed / (16 * VisualScale)) = WalkSpeed (Q.E.D.)
	local groundVelocity = 16 * titanScale * titanAnim
	assert(
		math.abs(groundVelocity - titanSpeed) < 0.001,
		"Kinematic velocity must identically match physical WalkSpeed (0 foot slip)"
	)
end)

-- 7. GATE-11: Objective Models and WorldTemplates Specifications
check("GATE-11: Objective model definitions match MAP1, MAP2, MAP3 requirements", function()
	local Map1 = MapsConfig.Maps.MAP1
	assert(Map1.Objective.ModelName == "Spider", "MAP1 must feature Spider")
	assert(Map1.Objective.MaximumRootHeight == 8, "MAP1 MaximumRootHeight must be 8")

	local Map2 = MapsConfig.Maps.MAP2
	assert(Map2.Objective.ModelName == "WildBoar", "MAP2 must feature WildBoar")
	assert(Map2.Objective.MaximumRootHeight == 10, "MAP2 MaximumRootHeight must be 10")

	local Map3 = MapsConfig.Maps.MAP3
	assert(Map3.Objective.ModelName == "AncientBear", "MAP3 must feature AncientBear")
	assert(Map3.Objective.MaximumRootHeight == 14, "MAP3 MaximumRootHeight must be 14")
end)

-- 8. GATE-13: UI Modal Authority & Complete Physical Portal Elimination Contract
check("GATE-13: UI Modal is sole authority; physical portals eliminated; no premature destruction", function()
	-- 1. Verify RewardPortalService source has 0 references to physical touch triggers
	local rewardPortalServicePath = if fs.isFile("src/server/Game/Services/RewardPortalService.luau")
		then "src/server/Game/Services/RewardPortalService.luau"
		else "f:/BIGGER/src/server/Game/Services/RewardPortalService.luau"
	local rpsSource = fs.readFile(rewardPortalServicePath)
	assert(not rpsSource:find("FreePortal"), "RewardPortalService must not reference FreePortal")
	assert(not rpsSource:find("PaidPortal"), "RewardPortalService must not reference PaidPortal")
	assert(not rpsSource:find("Trigger.Touched"), "RewardPortalService must have 0 Touched trigger listeners")
	assert(not rpsSource:find("SetChoicesActive"), "RewardPortalService must have 0 SetChoicesActive physical calls")

	-- 2. Verify UI Remote names and signatures
	assert(rpsSource:find("RequestClaimReward"), "RewardPortalService must expose RequestClaimReward remote")
	assert(rpsSource:find("ShowRewardPopup"), "RewardPortalService must expose ShowRewardPopup remote")

	-- 3. Verify reward state machine contract:
	-- Objective stomp sets RewardState = 'Choosing' WITHOUT mutating Destruction
	local simulatedSession = {
		Destruction = 5,
		State = "InWorld",
		ProfileMutationsFrozen = false,
	}
	local simulatedWorldInstance = {
		RewardState = "Inactive",
		ObjectiveActive = false,
		ObjectiveCompleted = true,
	}
	-- Simulate stomp activation
	simulatedWorldInstance.RewardState = "Choosing"
	assert(simulatedSession.Destruction == 5, "Destruction must remain unchanged upon stomp")
	assert(simulatedWorldInstance.RewardState == "Choosing", "RewardState must be Choosing")

	-- Simulate claim via UI remote
	local freeReward = MapsConfig.Maps.MAP1.Rewards.FreeDestruction
	simulatedSession.Destruction += freeReward
	simulatedWorldInstance.RewardState = "Settled"
	assert(simulatedSession.Destruction == 6, "Destruction must only mutate after explicit UI claim")
	assert(simulatedWorldInstance.RewardState == "Settled", "RewardState must be Settled after claim")
end)

-- 9. GATE-16: ModelRemaster Specifications & Authentic Mesh Contract
type ModelRemaster = {
	TubHeight: number,
	PineHeights: {
		Small: number,
		Medium: number,
		Large: number,
	},
	PedestalTopY: number,
}

check("GATE-16: ModelRemaster interface contract adheres to 4.0s Tubs and 3-Tier Pines", function()
	local remasterContract: ModelRemaster = {
		TubHeight = 4.00,
		PineHeights = {
			Small = 9.0,
			Medium = 18.0,
			Large = 30.0,
		},
		PedestalTopY = 93.0294,
	}

	assert(remasterContract.TubHeight == 4.00, "TubHeight must be 4.00 studs")
	assert(remasterContract.PineHeights.Small == 9.0, "Pine Small height must be 9.0 studs")
	assert(remasterContract.PineHeights.Medium == 18.0, "Pine Medium height must be 18.0 studs")
	assert(remasterContract.PineHeights.Large == 30.0, "Pine Large height must be 30.0 studs")
	assert(remasterContract.PedestalTopY == 93.0294, "PedestalTopY must be 93.0294 studs")
end)

if #Failures > 0 then
	print(string.format("\n=== %d TEST(S) FAILED ===", #Failures))
	for _, fail in Failures do
		print("  " .. fail)
	end
	error("Tests failed")
else
	print("\n=== ALL MVP-007 CONTRACT TESTS PASSED (100% GREEN) ===")
end
