--!strict
-- tests/unit/equipment_system.luau
-- Comprehensive unit tests for Equipment System (UpgradesConfig, GrowthFormula, EquipmentService, Persistence).

local fs = require("@lune/fs")
local luau = require("@lune/luau")

local UpgradesConfig = require("../../src/shared/Game/Config/UpgradesConfig")
local LevelFormula = require("../../src/shared/Game/Progression/LevelFormula")
local Sessions = require("../../src/server/Core/Registry/RuntimeRegistry/Sessions")

local function createModuleContainer(ModuleObj: any): any
	return { Module = ModuleObj }
end

local function loadModule(Path: string, Name: string, Environment: any): any
	assert(fs.isFile(Path), Name .. " production module is missing")
	local Chunk = luau.load(fs.readFile(Path), Name)
	local Env = setmetatable(Environment or {}, { __index = getfenv() })
	Env.require = function(Target: any)
		if type(Target) == "string" then
			return (getfenv() :: any).require(Target)
		elseif type(Target) == "table" and Target.Module then
			return Target.Module
		end
		return Target
	end
	setfenv(Chunk, Env)
	return Chunk()
end

local PlayersMock = { Name = "Players" }

local function createContainer(tableObj: any): any
	tableObj.WaitForChild = function(self: any, childName: string)
		assert(self[childName], "Missing mock child: " .. tostring(childName))
		return self[childName]
	end
	tableObj.FindFirstChild = function(self: any, childName: string)
		return self[childName]
	end
	return tableObj
end

local BiggerShared = createContainer({
	Game = createContainer({
		Config = createContainer({
			UpgradesConfig = createModuleContainer(UpgradesConfig),
		}),
		Progression = createContainer({
			LevelFormula = createModuleContainer(LevelFormula),
		}),
	}),
	Core = createContainer({
		Types = createContainer({
			GrowthTypes = createModuleContainer({}),
		}),
	}),
})

local ReplicatedStorage = createContainer({
	BiggerShared = BiggerShared,
})

local MockGame = {
	GetService = function(self: any, serviceName: string): any
		if serviceName == "ReplicatedStorage" then
			return ReplicatedStorage
		elseif serviceName == "Players" then
			return PlayersMock
		end
		return nil
	end,
}

local LoggerModule = loadModule("src/server/Core/Utilities/Logger.luau", "Logger", { game = MockGame })

local EventBusModule = loadModule("src/server/Core/Events/EventBus.luau", "EventBus", {
	game = MockGame,
	script = createContainer({
		Parent = createContainer({
			Parent = createContainer({
				Utilities = createContainer({
					Logger = createModuleContainer(LoggerModule),
				}),
			}),
		}),
	}),
})

local ServiceRegistryModule = loadModule("src/server/Core/Registry/ServiceRegistry.luau", "ServiceRegistry", {
	game = MockGame,
})

local GrowthFormulaModule = loadModule("src/server/Game/Formula/GrowthFormula.luau", "GrowthFormula", {
	game = MockGame,
	script = createContainer({
		Parent = createContainer({
			Parent = createContainer({
				Parent = createContainer({
					Core = createContainer({
						Registry = createContainer({
							RuntimeRegistry = createContainer({
								Sessions = createModuleContainer(Sessions),
							}),
						}),
					}),
				}),
			}),
		}),
	}),
})

local EquipmentServiceModule = loadModule("src/server/Game/Services/EquipmentService.luau", "EquipmentService", {
	game = MockGame,
	script = createContainer({
		Parent = createContainer({
			Parent = createContainer({
				Parent = createContainer({
					Core = createContainer({
						Registry = createContainer({
							RuntimeRegistry = createContainer({
								Sessions = createModuleContainer(Sessions),
							}),
							ServiceRegistry = createModuleContainer(ServiceRegistryModule),
						}),
						Events = createContainer({
							EventBus = createModuleContainer(EventBusModule),
						}),
						Utilities = createContainer({
							Logger = createModuleContainer(LoggerModule),
						}),
					}),
				}),
			}),
		}),
	}),
})

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
assert(
	UpgradesConfig.CanUnlock(EmptyMap, 1, 5, "Protein") == true,
	"Protein should unlock when requirements met without None=true"
)
assert(UpgradesConfig.CanUnlock(EmptyMap, 0, 5, "Protein") == false, "Protein unlock fails if Destruction < 1")
assert(UpgradesConfig.CanUnlock(EmptyMap, 1, 4, "Protein") == false, "Protein unlock fails if Level < 5")
assert(
	UpgradesConfig.CanUnlock(EmptyMap, 100, 100, "SilverProtein") == false,
	"SilverProtein fails without Protein unlocked"
)

local ProteinUnlocked = { Protein = true }
assert(UpgradesConfig.CanUnlock(ProteinUnlocked, 5, 10, "SilverProtein") == true, "SilverProtein unlocks after Protein")
assert(
	UpgradesConfig.CanUnlock(ProteinUnlocked, 5, 10, "Protein") == false,
	"Already unlocked Protein cannot unlock again"
)
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

assert(GrowthFormulaModule.GetMultiplier(CreateMockSession(nil)) == 1.0, "None equipped multiplier must be 1.0")
assert(
	GrowthFormulaModule.GetMultiplier(CreateMockSession("None")) == 1.0,
	"None string equipped multiplier must be 1.0"
)
assert(
	GrowthFormulaModule.GetMultiplier(CreateMockSession("Protein")) == 1.5,
	"Protein equipped multiplier must be 1.5"
)
assert(
	GrowthFormulaModule.GetMultiplier(CreateMockSession("SilverProtein")) == 2.0,
	"SilverProtein multiplier must be 2.0"
)
assert(GrowthFormulaModule.GetMultiplier(CreateMockSession("GoldProtein")) == 3.0, "GoldProtein multiplier must be 3.0")
assert(
	GrowthFormulaModule.GetMultiplier(CreateMockSession("DiamondProtein")) == 5.0,
	"DiamondProtein multiplier must be 5.0"
)
assert(
	GrowthFormulaModule.GetMultiplier(CreateMockSession("GrowthSerum")) == 10.0,
	"GrowthSerum multiplier must be 10.0"
)
assert(
	GrowthFormulaModule.GetMultiplier(CreateMockSession("AdvancedSerum")) == 25.0,
	"AdvancedSerum multiplier must be 25.0"
)
assert(GrowthFormulaModule.GetMultiplier(CreateMockSession("TitanSerum")) == 50.0, "TitanSerum multiplier must be 50.0")

assert(GrowthFormulaModule.GetMultiplier(CreateMockSession("Protein", false, true)) == 3.0, "Protein + VIP must be 3.0")
assert(
	GrowthFormulaModule.GetMultiplier(CreateMockSession("Protein", true, false)) == 3.0,
	"Protein + Double must be 3.0"
)
assert(
	GrowthFormulaModule.GetMultiplier(CreateMockSession("Protein", true, true)) == 6.0,
	"Protein + VIP + Double must be 6.0"
)
assert(
	GrowthFormulaModule.GetMultiplier(CreateMockSession("TitanSerum", true, true)) == 200.0,
	"TitanSerum + VIP + Double must be 200.0"
)

-- Verify fractional calculation preservation from MVP-005
local FractionalGain = GrowthFormulaModule.Calculate(CreateMockSession("Protein"), {
	BaseGain = 0.5,
	ZoneMultiplier = 1.0,
})
assert(FractionalGain == 0.75, "GrowthFormula.Calculate must preserve fractional gain (0.5 * 1.5 = 0.75)")

print("equipment_system formula tests: PASS")

-- 3. EquipmentService tests
local function CreateMockPlayer(name: string, userId: number): any
	local player = {
		Name = name,
		UserId = userId,
		Parent = PlayersMock,
		Attributes = {},
	}
	function player:SetAttribute(key: string, val: any)
		self.Attributes[key] = val
	end
	function player:GetAttribute(key: string): any
		return self.Attributes[key]
	end
	return player
end

local mockPlayer = CreateMockPlayer("EquipmentTestUser", 999901)
assert(EquipmentServiceModule:UnlockUpgrade(mockPlayer, "Protein") == false, "Unlock without session must fail")

-- Create valid session
local session: Sessions.Session = {
	Player = mockPlayer,
	Bigger = LevelFormula.GetRequirementForLevel(5), -- Level 5 requirement for Protein
	Destruction = 1,
	Rebirth = 0,
	UnlockedGrowthUpgrades = {},
	EquippedGrowthUpgrade = nil,
	CompletedPortals = {},
	Settings = { SoundEnabled = true, MusicEnabled = true },
	State = "InLobby",
	JoinedAt = os.time(),
	PurchaseHistory = {},
	CurrentWorldInstanceId = nil,
	HasDoubleMultiplier = false,
	HasVip = false,
	LastActiveTimestamp = os.time(),
	LastLogoutTimestamp = os.time(),
	LastSaveTimestamp = os.time(),
	ProfileMutationsFrozen = false,
	ProfileMutationFreezeReason = nil,
}

Sessions.Set(mockPlayer, session)

-- Verify server level derived from Bigger, NOT Player attribute
mockPlayer:SetAttribute("Level", 1) -- Spoofed client attribute
local ok, code = EquipmentServiceModule:UnlockUpgrade(mockPlayer, "Protein")
assert(
	ok == true and code == "Success",
	"Unlock should use server-derived level from Bigger (Level 5), ignoring client attribute (Level 1). Got: "
		.. tostring(code)
)
assert(session.UnlockedGrowthUpgrades["Protein"] == true, "Protein should now be in UnlockedGrowthUpgrades")
assert(session.UnlockedGrowthUpgrades["None"] == nil, "None must NEVER be written to UnlockedGrowthUpgrades")

-- Verify duplicate unlock attempt fails
local dupOk, dupCode = EquipmentServiceModule:UnlockUpgrade(mockPlayer, "Protein")
assert(dupOk == false and dupCode == "AlreadyUnlocked", "Duplicate unlock must return AlreadyUnlocked")

-- Verify skipping upgrade fails (SilverProtein requires Protein unlocked and Level 10, Destruction 5)
local skipOk, skipCode = EquipmentServiceModule:UnlockUpgrade(mockPlayer, "SilverProtein")
assert(
	skipOk == false and skipCode == "RequirementsNotMet",
	"SilverProtein unlock fails if Destruction/Level requirements not met"
)

-- Equip tests
assert(
	EquipmentServiceModule:EquipUpgrade(mockPlayer, "SilverProtein") == false,
	"Equipping locked SilverProtein must fail"
)

local equipOk, equipCode = EquipmentServiceModule:EquipUpgrade(mockPlayer, "Protein")
assert(equipOk == true and equipCode == "Success", "Equipping unlocked Protein must succeed")
assert(session.EquippedGrowthUpgrade == "Protein", "EquippedGrowthUpgrade session field must be Protein")
assert(mockPlayer:GetAttribute("EquippedGrowthUpgrade") == "Protein", "EquippedGrowthUpgrade attribute must be Protein")

-- Equip no-op test
local noopOk, noopCode = EquipmentServiceModule:EquipUpgrade(mockPlayer, "Protein")
assert(noopOk == true and noopCode == "Success", "Equipping currently equipped upgrade returns success no-op")

-- Unequip test
local unequipOk, unequipCode = EquipmentServiceModule:EquipUpgrade(mockPlayer, "None")
assert(unequipOk == true and unequipCode == "Success", "Unequipping to None must succeed")
assert(session.EquippedGrowthUpgrade == nil, "EquippedGrowthUpgrade session field must be nil when unequipped")
assert(mockPlayer:GetAttribute("EquippedGrowthUpgrade") == "None", "Attribute mirrors virtual state None")

-- Frozen session test
session.ProfileMutationsFrozen = true
local frozenUnlockOk, frozenUnlockCode = EquipmentServiceModule:UnlockUpgrade(mockPlayer, "SilverProtein")
assert(frozenUnlockOk == false and frozenUnlockCode == "Frozen", "Unlock on frozen session must return Frozen")

local frozenEquipOk, frozenEquipCode = EquipmentServiceModule:EquipUpgrade(mockPlayer, "Protein")
assert(frozenEquipOk == false and frozenEquipCode == "Frozen", "Equip on frozen session must return Frozen")

session.ProfileMutationsFrozen = false
Sessions.Remove(mockPlayer)

-- Initial session creation lifecycle sync test
local loadedSession: Sessions.Session = {
	Player = mockPlayer,
	Bigger = 1,
	Destruction = 0,
	Rebirth = 0,
	UnlockedGrowthUpgrades = {}, -- Empty unlocks
	EquippedGrowthUpgrade = "GoldProtein", -- Invalid persisted equipped state (locked item)
	CompletedPortals = {},
	Settings = { SoundEnabled = true, MusicEnabled = true },
	State = "InLobby",
	JoinedAt = os.time(),
	PurchaseHistory = {},
	CurrentWorldInstanceId = nil,
	HasDoubleMultiplier = false,
	HasVip = false,
	LastActiveTimestamp = os.time(),
	LastLogoutTimestamp = os.time(),
	LastSaveTimestamp = os.time(),
	ProfileMutationsFrozen = false,
	ProfileMutationFreezeReason = nil,
}

EquipmentServiceModule:OnSessionCreated(mockPlayer, loadedSession)
assert(
	loadedSession.EquippedGrowthUpgrade == nil,
	"Invalid persisted equipped upgrade must fail safe to nil on session load"
)
assert(mockPlayer:GetAttribute("EquippedGrowthUpgrade") == "None", "Attribute must reset to None")

print("equipment_system service tests: PASS")
