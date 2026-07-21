--!strict
-- tests/unit/equipment_system.luau
-- Comprehensive unit tests for Equipment System (UpgradesConfig, GrowthFormula, EquipmentService, Persistence).

local UpgradesConfig = require("../../src/shared/Game/Config/UpgradesConfig")

-- Mock game global for Lune environment
local env = getfenv() :: any
if not env.game then
	local ReplicatedStorage = {
		UpgradesConfig = UpgradesConfig,
		GrowthTypes = {},
	}
	env.game = {
		GetService = function(self: any, serviceName: string): any
			if serviceName == "ReplicatedStorage" then
				return ReplicatedStorage
			end
			return nil
		end,
	}
end

local GrowthFormula = require("../../src/server/Game/Formula/GrowthFormula")

-- 1. Configuration tests
assert(#UpgradesConfig.Sequence == 8, "Sequence must contain exactly 8 upgrade IDs")
assert(UpgradesConfig.Sequence[1] == "None", "First ID in sequence must be None")
assert(UpgradesConfig.Sequence[2] == "Protein", "Second ID in sequence must be Protein")
assert(UpgradesConfig.Sequence[8] == "TitanSerum", "Last ID in sequence must be TitanSerum")

-- Unique IDs & Definition completeness check
local SeenIds = {}
for _, Id in UpgradesConfig.Sequence do
	assert(not SeenIds[Id], "Sequence IDs must be unique: " .. tostring(Id))
	SeenIds[Id] = true
	local Def = UpgradesConfig.Upgrades[Id]
	assert(Def ~= nil, "Every Sequence ID must have a definition: " .. tostring(Id))
	assert(Def.Id == Id, "Definition Id must match table key")
	assert(Def.Multiplier >= 1, "Multiplier must be >= 1")
	assert(Def.RequiredDestruction >= 0, "RequiredDestruction must be >= 0")
	assert(Def.RequiredLevel >= 1, "RequiredLevel must be >= 1")
	assert(table.isfrozen(Def), "Definition must be frozen: " .. tostring(Id))
end

for Key in UpgradesConfig.Upgrades do
	assert(table.find(UpgradesConfig.Sequence, Key) ~= nil, "No definition outside Sequence: " .. tostring(Key))
end

assert(table.isfrozen(UpgradesConfig.Sequence), "Sequence table must be frozen")
assert(table.isfrozen(UpgradesConfig.Upgrades), "Upgrades table must be frozen")
assert(table.isfrozen(UpgradesConfig), "UpgradesConfig module must be frozen")

-- Multiplier lookup tests
assert(UpgradesConfig.GetMultiplier(nil) == 1.0, "GetMultiplier(nil) must return 1.0")
assert(UpgradesConfig.GetMultiplier("") == 1.0, "GetMultiplier('') must return 1.0")
assert(UpgradesConfig.GetMultiplier("None") == 1.0, "GetMultiplier('None') must return 1.0")
assert(UpgradesConfig.GetMultiplier("Protein") == 1.5, "Protein multiplier must be 1.5")
assert(UpgradesConfig.GetMultiplier("TitanSerum") == 50.0, "TitanSerum multiplier must be 50.0")
assert(UpgradesConfig.GetMultiplier("InvalidID") == 1.0, "Unknown ID must fail safe to 1.0")

-- Unlock validation tests
local EmptyMap = {}
assert(UpgradesConfig.CanUnlock(EmptyMap, 1, 5, "Protein") == true, "Protein should unlock when requirements met without None=true")
assert(UpgradesConfig.CanUnlock(EmptyMap, 0, 5, "Protein") == false, "Protein unlock fails if Destruction < 1")
assert(UpgradesConfig.CanUnlock(EmptyMap, 1, 4, "Protein") == false, "Protein unlock fails if Level < 5")
assert(UpgradesConfig.CanUnlock(EmptyMap, 100, 100, "SilverProtein") == false, "SilverProtein fails without Protein unlocked")

local ProteinUnlocked = { Protein = true }
assert(UpgradesConfig.CanUnlock(ProteinUnlocked, 5, 10, "SilverProtein") == true, "SilverProtein unlocks after Protein")
assert(UpgradesConfig.CanUnlock(ProteinUnlocked, 5, 10, "Protein") == false, "Already unlocked Protein cannot unlock again")
assert(UpgradesConfig.CanUnlock(ProteinUnlocked, 5, 10, "None") == false, "None cannot be unlocked")
assert(UpgradesConfig.CanUnlock(ProteinUnlocked, 5, 10, "Unknown") == false, "Unknown ID cannot be unlocked")

-- Equip validation tests
assert(UpgradesConfig.CanEquip(EmptyMap, nil) == true, "nil is always equippable")
assert(UpgradesConfig.CanEquip(EmptyMap, "None") == true, "None is always equippable")
assert(UpgradesConfig.CanEquip(EmptyMap, "Protein") == false, "Protein cannot be equipped if locked")
assert(UpgradesConfig.CanEquip(ProteinUnlocked, "Protein") == true, "Protein can be equipped when unlocked")

print("equipment_system config tests: PASS")

-- 2. GrowthFormula tests
local function CreateMockSession(equipped: string?, doubleMult: boolean?, vip: boolean?): any
	return {
		EquippedGrowthUpgrade = equipped,
		HasDoubleMultiplier = doubleMult == true,
		HasVip = vip == true,
	}
end

assert(GrowthFormula.GetMultiplier(CreateMockSession(nil)) == 1.0, "None equipped multiplier must be 1.0")
assert(GrowthFormula.GetMultiplier(CreateMockSession("None")) == 1.0, "None string equipped multiplier must be 1.0")
assert(GrowthFormula.GetMultiplier(CreateMockSession("Protein")) == 1.5, "Protein equipped multiplier must be 1.5")
assert(GrowthFormula.GetMultiplier(CreateMockSession("SilverProtein")) == 2.0, "SilverProtein multiplier must be 2.0")
assert(GrowthFormula.GetMultiplier(CreateMockSession("GoldProtein")) == 3.0, "GoldProtein multiplier must be 3.0")
assert(GrowthFormula.GetMultiplier(CreateMockSession("DiamondProtein")) == 5.0, "DiamondProtein multiplier must be 5.0")
assert(GrowthFormula.GetMultiplier(CreateMockSession("GrowthSerum")) == 10.0, "GrowthSerum multiplier must be 10.0")
assert(GrowthFormula.GetMultiplier(CreateMockSession("AdvancedSerum")) == 25.0, "AdvancedSerum multiplier must be 25.0")
assert(GrowthFormula.GetMultiplier(CreateMockSession("TitanSerum")) == 50.0, "TitanSerum multiplier must be 50.0")

assert(GrowthFormula.GetMultiplier(CreateMockSession("Protein", false, true)) == 3.0, "Protein + VIP must be 3.0")
assert(GrowthFormula.GetMultiplier(CreateMockSession("Protein", true, false)) == 3.0, "Protein + Double must be 3.0")
assert(GrowthFormula.GetMultiplier(CreateMockSession("Protein", true, true)) == 6.0, "Protein + VIP + Double must be 6.0")
assert(GrowthFormula.GetMultiplier(CreateMockSession("TitanSerum", true, true)) == 200.0, "TitanSerum + VIP + Double must be 200.0")

-- Verify fractional calculation preservation from MVP-005
local FractionalGain = GrowthFormula.Calculate(CreateMockSession("Protein"), {
	BaseGain = 0.5,
	ZoneMultiplier = 1.0,
})
assert(FractionalGain == 0.75, "GrowthFormula.Calculate must preserve fractional gain (0.5 * 1.5 = 0.75)")

print("equipment_system formula tests: PASS")
