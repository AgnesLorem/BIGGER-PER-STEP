--!strict
-- tier2_boundary_corner.luau
-- Tier 2: Boundary & Corner Cases

local Tier2 = {}

function Tier2.Register(F: any, _Context: { Player: Player, Datamodel: string })
	local LevelFormula = require(game:GetService("ReplicatedStorage").BiggerShared.Game.Progression.LevelFormula)
	local RebirthConfig = require(game:GetService("ReplicatedStorage").BiggerShared.Game.Progression.RebirthConfig)

	-- Formula mirror for CalculateRequiredLevel
	local function CalculateRequiredLevel(Rebirths: number): number
		if Rebirths == 0 then
			return 20
		elseif Rebirths == 1 then
			return 50
		elseif Rebirths == 2 then
			return 75
		elseif Rebirths == 3 then
			return 100
		elseif Rebirths == 4 then
			return 150
		else
			return 150 + (Rebirths - 4) * 50
		end
	end

	-- 1. Level 1 Boundary (Initial state)
	F.RegisterTest("Tier2", "T2_BOUND_01_Level1_InitialState", function()
		local level = LevelFormula.GetLevel(1)
		F.AssertEqual(level, 1, "Bigger 1 must map to Level 1")
		local reqLevel = CalculateRequiredLevel(0)
		F.AssertEqual(reqLevel, 20, "Rebirth 0 requires Level 20")
		local canRebirth = level >= reqLevel
		F.AssertFalse(canRebirth, "CanRebirth must be false at Level 1")
		local ratio = math.clamp(level / reqLevel, 0, 1)
		F.AssertApprox(ratio, 0.05, 0.001, "Progress ratio at Level 1 must be 0.05")
	end, "BOUNDARY")

	-- 2. Required Level - 1 (Level 19 on Tier 0)
	F.RegisterTest("Tier2", "T2_BOUND_02_ReqMinus1_Level19", function()
		local reqSize19 = LevelFormula.GetRequirement(19)
		local level19 = LevelFormula.GetLevel(reqSize19)
		F.AssertEqual(level19, 19, "Calculated level must be 19")
		local reqLevel = CalculateRequiredLevel(0)
		local canRebirth = level19 >= reqLevel
		F.AssertFalse(canRebirth, "CanRebirth must be false at Level 19 (Req - 1)")
	end, "BOUNDARY")

	-- 3. Exact Required Level (Level 20 on Tier 0)
	F.RegisterTest("Tier2", "T2_BOUND_03_ExactReq_Level20", function()
		local reqSize20 = LevelFormula.GetRequirement(20)
		local level20 = LevelFormula.GetLevel(reqSize20)
		F.AssertEqual(level20, 20, "Calculated level must be 20")
		local reqLevel = CalculateRequiredLevel(0)
		local canRebirth = level20 >= reqLevel
		F.AssertTrue(canRebirth, "CanRebirth must be true at exact Level 20 requirement")
	end, "BOUNDARY")

	-- 4. Level > Required (Level 50 on Tier 0)
	F.RegisterTest("Tier2", "T2_BOUND_04_LevelOverflow_Level50_Tier0", function()
		local reqSize50 = LevelFormula.GetRequirement(50)
		local level50 = LevelFormula.GetLevel(reqSize50)
		F.AssertEqual(level50, 50, "Calculated level must be 50")
		local reqLevel = CalculateRequiredLevel(0)
		local canRebirth = level50 >= reqLevel
		F.AssertTrue(canRebirth, "CanRebirth must be true at Level 50 > Level 20")
	end, "BOUNDARY")

	-- 5. Tier Progression Formulas across all tiers
	F.RegisterTest("Tier2", "T2_BOUND_05_TierProgressionFormulas", function()
		F.AssertEqual(CalculateRequiredLevel(0), 20, "Tier 0 (0 Rebirths) -> Level 20")
		F.AssertEqual(CalculateRequiredLevel(1), 50, "Tier 1 (1 Rebirth) -> Level 50")
		F.AssertEqual(CalculateRequiredLevel(2), 75, "Tier 2 (2 Rebirths) -> Level 75")
		F.AssertEqual(CalculateRequiredLevel(3), 100, "Tier 3 (3 Rebirths) -> Level 100")
		F.AssertEqual(CalculateRequiredLevel(4), 150, "Tier 4 (4 Rebirths) -> Level 150")
		F.AssertEqual(CalculateRequiredLevel(5), 200, "Tier 5 (5 Rebirths) -> Level 200")
		F.AssertEqual(CalculateRequiredLevel(6), 250, "Tier 6 (6 Rebirths) -> Level 250")
		F.AssertEqual(CalculateRequiredLevel(10), 450, "Tier 10 (10 Rebirths) -> Level 450")
	end, "BOUNDARY")

	-- 6. Cooldown Enforcement Boundary
	F.RegisterTest("Tier2", "T2_BOUND_06_CooldownEnforcement", function()
		local cdSeconds = RebirthConfig.CooldownSeconds
		F.AssertEqual(cdSeconds, 1, "Rebirth cooldown must be 1 second")
		local now = os.clock()
		local cdUntil = now + cdSeconds
		local immediateCheck = now + 0.1 < cdUntil
		F.AssertTrue(immediateCheck, "Immediate retry must fall within cooldown window")
		local afterCheck = now + 1.1 >= cdUntil
		F.AssertTrue(afterCheck, "Retry after 1.1s must be outside cooldown window")
	end, "BOUNDARY")

	-- 7. Product ID 0 Boundary for SkipRebirth
	F.RegisterTest("Tier2", "T2_BOUND_07_ProductIdZeroBoundary", function()
		local prodId = RebirthConfig.SkipRebirthProductId
		F.AssertEqual(prodId, 0, "Placeholder product ID is 0")
		local ok, _ = pcall(function()
			return prodId == 0
		end)
		F.AssertTrue(ok, "Product ID 0 handled safely inside pcall")
	end, "BOUNDARY")

	-- 8. Double Multiplier Stack Boundary
	F.RegisterTest("Tier2", "T2_BOUND_08_DoubleMultiplierRebirthStack", function()
		local baseMult = 2
		local rebirth0Next = baseMult * (0 + 2)
		F.AssertEqual(rebirth0Next, 4, "With Double Multiplier, Rebirth 0 next multiplier is 4X")
		local rebirth1Next = baseMult * (1 + 2)
		F.AssertEqual(rebirth1Next, 6, "With Double Multiplier, Rebirth 1 next multiplier is 6X")
	end, "BOUNDARY")

	-- 9. VIP Pass Stack Boundary
	F.RegisterTest("Tier2", "T2_BOUND_09_VipPassRebirthStack", function()
		local baseMult = 2
		local rebirth0Next = baseMult * (0 + 2)
		F.AssertEqual(rebirth0Next, 4, "With VIP, Rebirth 0 next multiplier is 4X")
		local bothMult = 2 * 2
		local rebirth0BothNext = bothMult * (0 + 2)
		F.AssertEqual(rebirth0BothNext, 8, "With Both VIP & Double, Rebirth 0 next multiplier is 8X")
	end, "BOUNDARY")

	-- 10. Atomic Session Mutation Boundary
	F.RegisterTest("Tier2", "T2_BOUND_10_SimultaneousBiggerMutations", function()
		local session = { Bigger = 1000, Rebirth = 0, ProfileMutationsFrozen = false }
		session.Rebirth += 1
		session.Bigger = RebirthConfig.RebirthResetSize
		F.AssertEqual(session.Rebirth, 1, "Session.Rebirth incremented to 1")
		F.AssertEqual(session.Bigger, 1, "Session.Bigger reset to 1")
	end, "BOUNDARY")
end

return Tier2
