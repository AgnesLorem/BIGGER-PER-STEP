--!strict
-- tests/unit/aura_system.luau

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local AuraConfig = require("../../src/shared/Game/Config/AuraConfig")
local SoundConfig = require("../../src/shared/Core/Config/SoundConfig")

-- Load AuraFormula with mocked script/require
local auraFormulaSource = fs.readFile("src/shared/Game/Progression/AuraFormula.luau")
local auraFormulaChunk = luau.load(auraFormulaSource, "AuraFormula")
local auraEnv = {
	script = {
		Parent = {
			Parent = {
				Config = {
					AuraConfig = AuraConfig,
				},
			},
		},
	},
	require = function(Target: any)
		if Target == AuraConfig or (type(Target) == "table" and Target.Tiers) then
			return AuraConfig
		end
		return Target
	end,
	assert = assert,
	type = type,
	math = math,
	table = table,
	ipairs = ipairs,
}
setmetatable(auraEnv, { __index = getfenv() })
setfenv(auraFormulaChunk, auraEnv)
local AuraFormula = auraFormulaChunk()

local function Assert(Condition: boolean, Msg: string)
	if not Condition then
		error("TEST ASSERTION FAILED: " .. Msg, 2)
	end
end

local function ApproxEq(A: number, B: number, Epsilon: number?): boolean
	local Eps = Epsilon or 0.01
	return math.abs(A - B) <= Eps
end

print("--- Testing AuraConfig ---")
Assert(#AuraConfig.Tiers == 4, "Should have exactly 4 tiers")
Assert(
	AuraConfig.Tiers[1].Id == "GreenKi"
		and AuraConfig.Tiers[1].RequiredDestruction == 10
		and ApproxEq(AuraConfig.Tiers[1].Multiplier, 1.15),
	"Tier 1 must be GreenKi, req 10, mult 1.15"
)
Assert(
	AuraConfig.Tiers[2].Id == "BlueKi"
		and AuraConfig.Tiers[2].RequiredDestruction == 30
		and ApproxEq(AuraConfig.Tiers[2].Multiplier, 1.30),
	"Tier 2 must be BlueKi, req 30, mult 1.30"
)
Assert(
	AuraConfig.Tiers[3].Id == "GoldKi"
		and AuraConfig.Tiers[3].RequiredDestruction == 60
		and ApproxEq(AuraConfig.Tiers[3].Multiplier, 1.50),
	"Tier 3 must be GoldKi, req 60, mult 1.50"
)
Assert(
	AuraConfig.Tiers[4].Id == "GodKi"
		and AuraConfig.Tiers[4].RequiredDestruction == 100
		and ApproxEq(AuraConfig.Tiers[4].Multiplier, 1.75),
	"Tier 4 must be GodKi, req 100, mult 1.75"
)

print("--- Testing AuraFormula.GetMultiplier ---")
Assert(ApproxEq(AuraFormula.GetMultiplier({}), 1.0), "Empty unlocked mult should be 1.0")
Assert(ApproxEq(AuraFormula.GetMultiplier({ GreenKi = true }), 1.15), "GreenKi only mult should be 1.15")
Assert(
	ApproxEq(AuraFormula.GetMultiplier({ GreenKi = true, BlueKi = true }), 1.30),
	"GreenKi+BlueKi mult should be 1.30"
)
Assert(
	ApproxEq(AuraFormula.GetMultiplier({ GreenKi = true, BlueKi = true, GoldKi = true, GodKi = true }), 1.75),
	"All unlocked mult should be 1.75"
)

print("--- Testing AuraFormula.GetHighestUnlockedTier ---")
Assert(AuraFormula.GetHighestUnlockedTier({}) == nil, "Empty unlocked highest tier should be nil")
Assert(
	AuraFormula.GetHighestUnlockedTier({ GreenKi = true }) == AuraConfig.Tiers[1],
	"GreenKi only highest tier should be GreenKi"
)
Assert(
	AuraFormula.GetHighestUnlockedTier({ GreenKi = true, BlueKi = true, GoldKi = true, GodKi = true })
		== AuraConfig.Tiers[4],
	"All unlocked highest tier should be GodKi"
)

print("--- Testing AuraFormula.GetUnlockableAuras ---")
local u0 = AuraFormula.GetUnlockableAuras(0)
Assert(#u0 == 0, "0 destruction unlockables should be empty")

local u10 = AuraFormula.GetUnlockableAuras(10)
Assert(#u10 == 1 and u10[1] == "GreenKi", "10 destruction unlockables should be {GreenKi}")

local u35 = AuraFormula.GetUnlockableAuras(35)
Assert(
	#u35 == 2 and u35[1] == "GreenKi" and u35[2] == "BlueKi",
	"35 destruction unlockables should be {GreenKi, BlueKi}"
)

local u100 = AuraFormula.GetUnlockableAuras(100)
Assert(#u100 == 4, "100 destruction unlockables should be all 4")

print("--- Testing AuraFormula.CanEquip ---")
Assert(AuraFormula.CanEquip({}, "None"), "None always equippable")
Assert(AuraFormula.CanEquip({ GreenKi = true }, "GreenKi"), "Unlocked tier equippable")
Assert(AuraFormula.CanEquip({ GreenKi = true }, "BlueKi") == false, "Not-unlocked tier not equippable")

print("--- Testing SoundConfig ---")
local expectedSounds = { "Footstep", "StompImpact", "LevelUp", "Rebirth", "PortalEnter", "AuraActivate" }
for _, name in ipairs(expectedSounds) do
	local sound = SoundConfig[name]
	Assert(sound ~= nil, name .. " must exist")
	Assert(type(sound.AssetId) == "number" and sound.AssetId >= 0, name .. " AssetId must be >= 0")
	Assert(
		type(sound.Volume) == "number" and sound.Volume >= 0 and sound.Volume <= 1,
		name .. " Volume must be in [0,1]"
	)
end

print("ALL AURA SYSTEM TESTS PASSED")
