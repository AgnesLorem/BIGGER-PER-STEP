--!strict
-- tests/unit/progression_balance.luau
-- Comprehensive unit test for MVP-08 math: LevelFormula, ScaleCurve, RebirthFormula, UpgradesConfig

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local LevelFormula = require("../../src/shared/Game/Progression/LevelFormula")
local RebirthConfig = require("../../src/shared/Game/Config/RebirthConfig")
local UpgradesConfig = require("../../src/shared/Game/Config/UpgradesConfig")
local ScaleConfig = require("../../src/shared/Core/Config/ScaleConfig")

-- Load RebirthFormula with mocked script/require
local rebirthFormulaSource = fs.readFile("src/shared/Game/Progression/RebirthFormula.luau")
local rebirthFormulaChunk = luau.load(rebirthFormulaSource, "RebirthFormula")
local rebirthEnv = {
	script = {
		Parent = {
			Parent = {
				Config = {
					RebirthConfig = RebirthConfig,
				},
			},
		},
	},
	require = function(Target: any)
		if Target == RebirthConfig or (type(Target) == "table" and Target.BaseLevelRequirement) then
			return RebirthConfig
		end
		return Target
	end,
	assert = assert,
	type = type,
	math = math,
	table = table,
}
setmetatable(rebirthEnv, { __index = getfenv() })
setfenv(rebirthFormulaChunk, rebirthEnv)
local RebirthFormula = rebirthFormulaChunk()

-- Load ScaleCurve with mocked script/require
local scaleCurveSource = fs.readFile("src/shared/Core/Utilities/ScaleCurve.luau")
local scaleCurveChunk = luau.load(scaleCurveSource, "ScaleCurve")
local scaleEnv = {
	script = {
		Parent = {
			Parent = {
				Parent = {
					Game = {
						Progression = {
							LevelFormula = LevelFormula,
						},
					},
				},
			},
		},
	},
	require = function(Target: any)
		if Target == LevelFormula or (type(Target) == "table" and Target.GetLevelFromBigger) then
			return LevelFormula
		end
		return Target
	end,
	assert = assert,
	type = type,
	math = math,
	table = table,
}
setmetatable(scaleEnv, { __index = getfenv() })
setfenv(scaleCurveChunk, scaleEnv)
local ScaleCurve = scaleCurveChunk()

local function Assert(Condition: boolean, Msg: string)
	if not Condition then
		error("TEST ASSERTION FAILED: " .. Msg, 2)
	end
end

local function ApproxEq(A: number, B: number, Epsilon: number?): boolean
	local Eps = Epsilon or 0.01
	return math.abs(A - B) <= Eps
end

print("--- Testing LevelFormula (MVP-08 Quadratic Curve) ---")
-- Test Level 1: 0 Bigger
Assert(LevelFormula.GetLevelFromBigger(0) == 1, "Level 0 Bigger should be Level 1")
Assert(LevelFormula.GetRequirementForLevel(1) == 0, "Requirement for Level 1 should be 0")

-- Test Level 2: 2 Bigger
Assert(LevelFormula.GetLevelFromBigger(2) == 2, "Level 2 Bigger should be Level 2")

-- Test Level 5: ~27 Bigger
local Req5 = LevelFormula.GetRequirementForLevel(5)
print(string.format("Level 5 requirement: %.2f Bigger", Req5))
Assert(ApproxEq(Req5, 26.59, 0.5), "Level 5 requirement should be ~27 Bigger")
Assert(LevelFormula.GetLevelFromBigger(27) == 5, "27 Bigger should yield Level 5")

-- Test Level 8 (World 1 Entry): ~81 Bigger
local Req8 = LevelFormula.GetRequirementForLevel(8)
print(string.format("Level 8 (World 1 Portal) requirement: %.2f Bigger", Req8))
Assert(ApproxEq(Req8, 81.44, 0.5), "Level 8 requirement should be ~81 Bigger")
Assert(LevelFormula.GetLevelFromBigger(82) == 8, "82 Bigger should yield Level 8")

-- Test Level 20: 600 Bigger (5 min walking baseline)
local Req20 = LevelFormula.GetRequirementForLevel(20)
print(string.format("Level 20 requirement: %.2f Bigger (target: 600)", Req20))
Assert(ApproxEq(Req20, 600, 1.0), "Level 20 requirement should be ~600 Bigger")
Assert(LevelFormula.GetLevelFromBigger(600) == 20, "600 Bigger should yield Level 20")

-- Monotonicity check across wide range
local PrevLevel = 1
for Bigger = 0, 50000, 137 do
	local L = LevelFormula.GetLevelFromBigger(Bigger)
	Assert(L >= PrevLevel, "Level must be monotonically increasing")
	PrevLevel = L
end

print("--- Testing ScaleCurve (MVP-08 Power Curve) ---")
-- Level 1: 1.00x
local Scale1 = ScaleCurve.GetVisualScale(0, ScaleConfig.Formula, ScaleConfig.Coefficient, ScaleConfig.Exponent)
print(string.format("Scale at Level 1: %.2fx", Scale1))
Assert(ApproxEq(Scale1, 1.0, 0.01), "Scale at Level 1 should be 1.0x")

-- Level 10 (135 Bigger): ~1.50x
local Scale10 = ScaleCurve.GetVisualScale(135, ScaleConfig.Formula, ScaleConfig.Coefficient, ScaleConfig.Exponent)
print(string.format("Scale at Level 10 (135 Bigger): %.2fx (target: ~1.50x)", Scale10))
Assert(ApproxEq(Scale10, 1.5, 0.05), "Scale at Level 10 should be ~1.50x")

-- Level 50 (3991 Bigger): ~3.04x
local Scale50 = ScaleCurve.GetVisualScale(3991, ScaleConfig.Formula, ScaleConfig.Coefficient, ScaleConfig.Exponent)
print(string.format("Scale at Level 50 (3,991 Bigger): %.2fx (target: ~3.0x)", Scale50))
Assert(ApproxEq(Scale50, 3.04, 0.1), "Scale at Level 50 should be ~3.04x")

-- Level 100 (16290 Bigger): ~4.66x
local Scale100 = ScaleCurve.GetVisualScale(16290, ScaleConfig.Formula, ScaleConfig.Coefficient, ScaleConfig.Exponent)
print(string.format("Scale at Level 100 (16,290 Bigger): %.2fx (target: ~4.7x)", Scale100))
Assert(ApproxEq(Scale100, 4.66, 0.1), "Scale at Level 100 should be ~4.66x")

-- Level 500 (413852 Bigger): ~15.00x
local Scale500 = ScaleCurve.GetVisualScale(413852, ScaleConfig.Formula, ScaleConfig.Coefficient, ScaleConfig.Exponent)
print(string.format("Scale at Level 500 (413,852 Bigger): %.2fx (target: ~15.0x)", Scale500))
Assert(ApproxEq(Scale500, 15.0, 0.2), "Scale at Level 500 should be ~15.0x")

-- MaxVisualScale configured to 200
Assert(ScaleConfig.MaxVisualScale == 200, "MaxVisualScale must be 200")

print("--- Testing RebirthFormula (MVP-08 Pacing Model) ---")
-- Rebirth level requirements: ReqLevel(R) = 20 + R * 50
Assert(RebirthFormula.GetRequiredLevel(0) == 20, "Rebirth 1 req should be Level 20")
Assert(RebirthFormula.GetRequiredLevel(1) == 70, "Rebirth 2 req should be Level 70")
Assert(RebirthFormula.GetRequiredLevel(2) == 120, "Rebirth 3 req should be Level 120")
Assert(RebirthFormula.GetRequiredLevel(3) == 170, "Rebirth 4 req should be Level 170")
Assert(RebirthFormula.GetRequiredLevel(4) == 220, "Rebirth 5 req should be Level 220")
Assert(RebirthFormula.GetRequiredLevel(9) == 470, "Rebirth 10 req should be Level 470")

-- Rebirth multipliers: 1 + R * 0.75
local Mult0 = RebirthFormula.GetMultiplier(0)
Assert(ApproxEq(Mult0, 1.0, 0.01), "Rebirth 0 mult should be 1.00x")
local Mult1 = RebirthFormula.GetMultiplier(1)
print(string.format("Rebirth 1 mult: %.2fx (expected 1.75x)", Mult1))
Assert(ApproxEq(Mult1, 1.75, 0.01), "Rebirth 1 mult should be 1.75x")
local Mult2 = RebirthFormula.GetMultiplier(2)
print(string.format("Rebirth 2 mult: %.2fx (expected 2.50x)", Mult2))
Assert(ApproxEq(Mult2, 2.50, 0.01), "Rebirth 2 mult should be 2.50x")
local Mult3 = RebirthFormula.GetMultiplier(3)
print(string.format("Rebirth 3 mult: %.2fx (expected 3.25x)", Mult3))
Assert(ApproxEq(Mult3, 3.25, 0.01), "Rebirth 3 mult should be 3.25x")
local Mult5 = RebirthFormula.GetMultiplier(5)
print(string.format("Rebirth 5 mult: %.2fx (expected 4.75x)", Mult5))
Assert(ApproxEq(Mult5, 4.75, 0.01), "Rebirth 5 mult should be 4.75x")
local Mult10 = RebirthFormula.GetMultiplier(10)
print(string.format("Rebirth 10 mult: %.2fx (expected 8.50x)", Mult10))
Assert(ApproxEq(Mult10, 8.50, 0.01), "Rebirth 10 mult should be 8.50x")
local Mult20 = RebirthFormula.GetMultiplier(20)
print(string.format("Rebirth 20 mult: %.2fx (expected 16.00x)", Mult20))
Assert(ApproxEq(Mult20, 16.00, 0.01), "Rebirth 20 mult should be 16.00x")

-- CanRebirth checks
Assert(RebirthFormula.CanRebirth(19, 0) == false, "Level 19 cannot Rebirth 1")
Assert(RebirthFormula.CanRebirth(20, 0) == true, "Level 20 CAN Rebirth 1")
Assert(RebirthFormula.CanRebirth(69, 1) == false, "Level 69 cannot Rebirth 2")
Assert(RebirthFormula.CanRebirth(70, 1) == true, "Level 70 CAN Rebirth 2")

print("--- Testing UpgradesConfig (MVP-08 Destruction-Only Gates) ---")
-- Protein: 1.5x, 1 Destruction
Assert(UpgradesConfig.CanUnlock({}, 0, "Protein") == false, "Protein requires 1 Destruction")
Assert(UpgradesConfig.CanUnlock({}, 1, "Protein") == true, "Protein unlocks at 1 Destruction")

-- SilverProtein: 2.0x, 3 Destruction (requires Protein)
Assert(UpgradesConfig.CanUnlock({}, 3, "SilverProtein") == false, "SilverProtein requires Protein predecessor")
Assert(
	UpgradesConfig.CanUnlock({ Protein = true }, 2, "SilverProtein") == false,
	"SilverProtein requires 3 Destruction"
)
Assert(
	UpgradesConfig.CanUnlock({ Protein = true }, 3, "SilverProtein") == true,
	"SilverProtein unlocks at 3 Destruction"
)

-- GoldProtein: 3.0x, 8 Destruction
Assert(
	UpgradesConfig.CanUnlock({ Protein = true, SilverProtein = true }, 8, "GoldProtein") == true,
	"GoldProtein unlocks at 8 Destruction"
)

-- DiamondProtein: 5.0x, 15 Destruction
Assert(
	UpgradesConfig.CanUnlock({ Protein = true, SilverProtein = true, GoldProtein = true }, 15, "DiamondProtein") == true,
	"DiamondProtein unlocks at 15 Destruction"
)

-- GrowthSerum: 10.0x, 30 Destruction
Assert(
	UpgradesConfig.CanUnlock(
		{ Protein = true, SilverProtein = true, GoldProtein = true, DiamondProtein = true },
		30,
		"GrowthSerum"
	) == true,
	"GrowthSerum unlocks at 30 Destruction"
)

-- AdvancedSerum: 25.0x, 60 Destruction
Assert(
	UpgradesConfig.CanUnlock(
		{ Protein = true, SilverProtein = true, GoldProtein = true, DiamondProtein = true, GrowthSerum = true },
		60,
		"AdvancedSerum"
	) == true,
	"AdvancedSerum unlocks at 60 Destruction"
)

-- TitanSerum: 50.0x, 100 Destruction
Assert(UpgradesConfig.CanUnlock({
	Protein = true,
	SilverProtein = true,
	GoldProtein = true,
	DiamondProtein = true,
	GrowthSerum = true,
	AdvancedSerum = true,
}, 100, "TitanSerum") == true, "TitanSerum unlocks at 100 Destruction")
Assert(UpgradesConfig.GetMultiplier("TitanSerum") == 50.0, "TitanSerum mult is 50.0x")

print("\n========================================================")
print("ALL MVP-08 PROGRESSION BALANCE TESTS PASSED (100%)!")
print("========================================================")
