--!strict
-- tests/unit/equipment_system.luau
-- Comprehensive unit tests for Equipment System (UpgradesConfig, GrowthFormula, EquipmentService, EquipmentController, Persistence).

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local task = require("@lune/task")

local UpgradesConfig = require("../../src/shared/Game/Config/UpgradesConfig")
local LevelFormula = require("../../src/shared/Game/Progression/LevelFormula")
local Sessions = require("../../src/server/Core/Registry/RuntimeRegistry/Sessions")

local LevelThresholds = {
	[5] = LevelFormula.GetRequirementForLevel(5),
	[10] = LevelFormula.GetRequirementForLevel(10),
	[20] = LevelFormula.GetRequirementForLevel(20),
	[50] = LevelFormula.GetRequirementForLevel(50),
	[100] = LevelFormula.GetRequirementForLevel(100),
	[200] = LevelFormula.GetRequirementForLevel(200),
	[500] = LevelFormula.GetRequirementForLevel(500),
}

assert(LevelFormula.GetLevelFromBigger(0) == 1, "Bigger 0 must be Level 1")
assert(LevelFormula.GetRequirementForLevel(1) == 0, "Level 1 must require Bigger 0")

for Level, Requirement in LevelThresholds do
	assert(
		LevelFormula.GetRequirementForLevel(Level) == Requirement,
		string.format("Level %d requirement must be %d", Level, Requirement)
	)
	if Requirement > 0 then
		assert(
			LevelFormula.GetLevelFromBigger(Requirement - 1) == Level - 1,
			string.format("Bigger immediately below Level %d must remain Level %d", Level, Level - 1)
		)
	end
	assert(
		LevelFormula.GetLevelFromBigger(Requirement) == Level,
		string.format("Exact Level %d requirement must reach that Level", Level)
	)
	assert(
		LevelFormula.GetLevelFromBigger(Requirement + 1) == Level,
		string.format("Bigger immediately above Level %d requirement must remain at that Level", Level)
	)
end

local LevelFiveRequirement = LevelFormula.GetRequirementForLevel(5)
local LevelFiveProgress = LevelFormula.GetProgress(LevelFiveRequirement)
assert(LevelFiveProgress.Level == 5, "Progress must report canonical Level")
assert(LevelFiveProgress.CurrentRequirement == LevelFiveRequirement, "Progress must expose current requirement")
assert(
	LevelFiveProgress.NextRequirement == LevelFormula.GetRequirementForLevel(6),
	"Level 5 next requirement must be Level 6 requirement"
)
assert(LevelFiveProgress.BiggerIntoLevel == 0, "Progress must reset at exact Level requirement")
assert(LevelFiveProgress.Progress == 0, "Progress ratio must reset at exact Level requirement")

local function AssertRejected(Callback: () -> (), Message: string)
	local Success = pcall(Callback)
	assert(not Success, Message)
end

AssertRejected(function()
	LevelFormula.GetLevelFromBigger(-1)
end, "Negative Bigger must be rejected")
AssertRejected(function()
	LevelFormula.GetLevelFromBigger(0 / 0)
end, "NaN Bigger must be rejected")
AssertRejected(function()
	LevelFormula.GetLevelFromBigger(math.huge)
end, "Infinite Bigger must be rejected")
AssertRejected(function()
	LevelFormula.GetRequirementForLevel(0)
end, "Level zero must be rejected")
AssertRejected(function()
	LevelFormula.GetRequirementForLevel(1.5)
end, "Fractional Level must be rejected")

local PreviousLevel = 1
for Bigger = 0, 200000, 997 do
	local CurrentLevel = LevelFormula.GetLevelFromBigger(Bigger)
	assert(CurrentLevel >= PreviousLevel, "Level must be monotonic as Bigger increases")
	PreviousLevel = CurrentLevel
end

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

local function createSignal(): any
	local Signal = { Callbacks = {} }
	function Signal:Connect(Callback: (...any) -> ())
		table.insert(self.Callbacks, Callback)
		local Connected = true
		return {
			Disconnect = function()
				if not Connected then
					return
				end
				Connected = false
				local Index = table.find(self.Callbacks, Callback)
				if Index then
					table.remove(self.Callbacks, Index)
				end
			end,
		}
	end
	function Signal:Fire(...)
		for _, Callback in table.clone(self.Callbacks) do
			Callback(...)
		end
	end
	return Signal
end

local PlayersMock = { Name = "Players", PlayerRemoving = createSignal() }
local ClientPlayer = { Name = "EquipmentClient", UserId = 999800, Parent = PlayersMock }
PlayersMock.LocalPlayer = ClientPlayer

local InstanceMock = {}
function InstanceMock.new(ClassName: string): any
	local Object = {
		ClassName = ClassName,
		Name = "",
		ClientPlayer = ClientPlayer,
	}
	function Object:IsA(Expected: string): boolean
		return self.ClassName == Expected
	end
	function Object:FindFirstChild(Name: string): any
		return self[Name]
	end
	function Object:WaitForChild(Name: string): any
		return self[Name]
	end
	if ClassName == "RemoteEvent" then
		Object.OnServerEvent = createSignal()
		Object.OnClientEvent = createSignal()
		Object.ClientCalls = {}
		function Object:FireClient(Player: any, ...)
			table.insert(self.ClientCalls, { Player, ... })
			self.OnClientEvent:Fire(...)
		end
		function Object:FireServer(...)
			self.OnServerEvent:Fire(self.ClientPlayer, ...)
		end
	end
	return setmetatable(Object, {
		__newindex = function(Self, Key, Value)
			rawset(Self, Key, Value)
			if Key == "Parent" and Value then
				Value[Self.Name] = Self
			end
		end,
	})
end

local function createContainer(tableObj: any): any
	tableObj.WaitForChild = function(self: any, childName: string, timeout: number?)
		return self[childName]
	end
	tableObj.FindFirstChild = function(self: any, childName: string)
		return self[childName]
	end
	return tableObj
end

local RebirthConfig = require("../../src/shared/Game/Config/RebirthConfig")
local RebirthFormula = loadModule("src/shared/Game/Progression/RebirthFormula.luau", "RebirthFormula", {
	script = createContainer({
		Parent = createContainer({
			Parent = createContainer({
				Config = createContainer({
					RebirthConfig = createModuleContainer(RebirthConfig),
				}),
			}),
		}),
	}),
})

local BiggerShared = createContainer({
	Game = createContainer({
		Config = createContainer({
			UpgradesConfig = createModuleContainer(UpgradesConfig),
			RebirthConfig = createModuleContainer(RebirthConfig),
		}),
		Progression = createContainer({
			LevelFormula = createModuleContainer(LevelFormula),
			RebirthFormula = createModuleContainer(RebirthFormula),
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

local HttpServiceMock = { Counter = 0 }
function HttpServiceMock:GenerateGUID()
	self.Counter += 1
	return string.format("00000000-0000-0000-0000-%012d", self.Counter)
end

local MockGame = {
	GetService = function(self: any, serviceName: string): any
		if serviceName == "ReplicatedStorage" then
			return ReplicatedStorage
		elseif serviceName == "Players" then
			return PlayersMock
		elseif serviceName == "HttpService" then
			return HttpServiceMock
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

local SaveServiceSpy = { QueueCalls = 0 }
function SaveServiceSpy:QueueProfileSave()
	self.QueueCalls += 1
	return true
end
ServiceRegistryModule.Register("SaveService", SaveServiceSpy)
ServiceRegistryModule.Register("GrowthService", { UpdateMultiplierAttribute = function() end })

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
	Instance = InstanceMock,
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

local PortalPlayers = { CurrentPlayer = nil }
function PortalPlayers:GetPlayerFromCharacter()
	return self.CurrentPlayer
end
local PortalReplicatedStorage = {
	BiggerShared = { Game = { Progression = { LevelFormula = createModuleContainer(LevelFormula) } } },
}
local PortalGame = {}
function PortalGame:GetService(Name: string): any
	if Name == "Players" then
		return PortalPlayers
	elseif Name == "ReplicatedStorage" then
		return PortalReplicatedStorage
	elseif Name == "Workspace" then
		return {
			FindFirstChild = function()
				return nil
			end,
		}
	end
	error("unexpected PortalService dependency " .. Name)
end
local PortalServicesFolder = {}
local PortalGameFolder = {
	Config = { World1Config = { PortalName = "World1Portal", RequiredLevel = 5 } },
}
local PortalRoot = {
	Core = {
		Registry = {
			RuntimeRegistry = { Sessions = createModuleContainer(Sessions) },
			ServiceRegistry = createModuleContainer(ServiceRegistryModule),
		},
		Utilities = { Logger = createModuleContainer(LoggerModule) },
	},
}
PortalServicesFolder.Parent = PortalGameFolder
PortalGameFolder.Parent = PortalRoot
local PortalServiceModule = loadModule("src/server/Game/Services/PortalService.luau", "PortalService", {
	game = PortalGame,
	script = { Parent = PortalServicesFolder },
	require = function(Dependency: any): any
		return if type(Dependency) == "table" and Dependency.Module then Dependency.Module else Dependency
	end,
})

local EquipmentControllerModule = loadModule("src/client/controllers/EquipmentController.luau", "EquipmentController", {
	game = MockGame,
	task = task,
	warn = function() end,
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
	UpgradesConfig.CanUnlock(EmptyMap, 1, "Protein") == true,
	"Protein should unlock when requirements met without None=true"
)
assert(UpgradesConfig.CanUnlock(EmptyMap, 0, "Protein") == false, "Protein unlock fails if Destruction < 1")
assert(
	UpgradesConfig.CanUnlock(EmptyMap, 100, "SilverProtein") == false,
	"SilverProtein fails without Protein unlocked"
)

local ProteinUnlocked = { Protein = true }
assert(UpgradesConfig.CanUnlock(ProteinUnlocked, 3, "SilverProtein") == true, "SilverProtein unlocks after Protein")
assert(UpgradesConfig.CanUnlock(ProteinUnlocked, 3, "Protein") == false, "Already unlocked Protein cannot unlock again")
assert(UpgradesConfig.CanUnlock(ProteinUnlocked, 3, "None") == false, "None cannot be unlocked")
assert(UpgradesConfig.CanUnlock(ProteinUnlocked, 3, "Unknown") == false, "Unknown ID cannot be unlocked")

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

local function CreateEquipmentSession(Player: any, Bigger: number, UpgradeIndex: number): any
	local Unlocked = {}
	for Index = 2, UpgradeIndex - 1 do
		Unlocked[UpgradesConfig.Sequence[Index]] = true
	end
	local Definition = UpgradesConfig.Upgrades[UpgradesConfig.Sequence[UpgradeIndex]]
	return {
		Player = Player,
		Bigger = Bigger,
		Destruction = Definition.RequiredDestruction,
		Rebirth = 0,
		UnlockedGrowthUpgrades = Unlocked,
		EquippedGrowthUpgrade = nil,
		CompletedPortals = {},
		Settings = { SoundEnabled = true, MusicEnabled = true },
		State = "InLobby",
		JoinedAt = os.time(),
		PurchaseHistory = {},
		CurrentWorldInstanceId = nil,
		HasDoubleMultiplier = false,
		HasVip = false,
		HasPremiumZonePass = false,
		GrowthRemainder = 0,
		CurrentAFKZone = nil,
		PremiumZonePromptedThisEntry = false,
		GamePassQueryGenerations = { Vip = 0, PremiumZone = 0 },
		LastActiveTimestamp = os.time(),
		LastLogoutTimestamp = os.time(),
		LastSaveTimestamp = os.time(),
		ProfileMutationsFrozen = false,
		ProfileMutationFreezeReason = nil,
	}
end

local function TryPortal(Bigger: number, Frozen: boolean, SpoofedLevel: number): (boolean, number)
	local Player = CreateMockPlayer("PortalBoundary", 998000 + math.max(0, Bigger))
	Player:SetAttribute("Level", SpoofedLevel)
	PortalPlayers.CurrentPlayer = Player
	local Session = CreateEquipmentSession(Player, Bigger, 2)
	Session.State = "InLobby"
	Session.ProfileMutationsFrozen = Frozen
	Sessions.Set(Player, Session)
	local Creates = 0
	local SessionService = {}
	function SessionService:TransitionState(_, Expected, Next)
		if Session.State ~= Expected then
			return false
		end
		Session.State = Next
		return true
	end
	local WorldInstanceService = {}
	function WorldInstanceService:GetPlayerWorld()
		return nil
	end
	function WorldInstanceService:CreateWorldForPlayer()
		Creates += 1
		return {}
	end
	function WorldInstanceService:RecoverPlayer() end
	local Hit = {}
	function Hit:FindFirstAncestorOfClass()
		return {}
	end
	local Success =
		pcall(PortalServiceModule.TryEnterPortal, PortalServiceModule, Hit, SessionService, WorldInstanceService)
	Sessions.Remove(Player)
	PortalServiceModule:ClearDebounce(Player)
	return Success, Creates
end

for UpgradeIndex = 2, #UpgradesConfig.Sequence do
	local UpgradeId = UpgradesConfig.Sequence[UpgradeIndex]
	local Definition = UpgradesConfig.Upgrades[UpgradeId]

	local BelowPlayer = CreateMockPlayer("Below" .. UpgradeId, 990000 + UpgradeIndex * 10)
	local BelowSession = CreateEquipmentSession(BelowPlayer, 0, UpgradeIndex)
	BelowSession.Destruction = Definition.RequiredDestruction - 1
	Sessions.Set(BelowPlayer, BelowSession)
	local BelowOk, BelowCode = EquipmentServiceModule:UnlockUpgrade(BelowPlayer, UpgradeId)
	if Definition.RequiredDestruction > 0 then
		assert(not BelowOk and BelowCode == "RequirementsNotMet", UpgradeId .. " must reject Destruction - 1")
	end
	Sessions.Remove(BelowPlayer)

	local Player = CreateMockPlayer("AtOrAbove" .. UpgradeId, 990001 + UpgradeIndex * 10)
	local Session = CreateEquipmentSession(Player, 0, UpgradeIndex)
	Session.Destruction = Definition.RequiredDestruction
	Sessions.Set(Player, Session)
	local SavesBefore = SaveServiceSpy.QueueCalls
	local Ok, Code = EquipmentServiceModule:UnlockUpgrade(Player, UpgradeId)
	assert(Ok and Code == "Success", UpgradeId .. " must unlock at required Destruction")
	assert(Session.EquippedGrowthUpgrade == nil, "Unlock must not auto-equip " .. UpgradeId)
	assert(SaveServiceSpy.QueueCalls == SavesBefore + 1, "Successful unlock must queue one save")
	Sessions.Remove(Player)
end

assert(
	not UpgradesConfig.CanUnlock({}, 9007199254740992, "Protein"),
	"Destruction above the safe integer range must fail closed"
)

local InvalidDestructionPlayer = CreateMockPlayer("InvalidDestruction", 999890)
local InvalidDestructionSession = CreateEquipmentSession(InvalidDestructionPlayer, 0, 2)
InvalidDestructionSession.Destruction = -1
Sessions.Set(InvalidDestructionPlayer, InvalidDestructionSession)
local InvalidDestructionOk, InvalidDestructionCode =
	EquipmentServiceModule:UnlockUpgrade(InvalidDestructionPlayer, "Protein")
assert(
	not InvalidDestructionOk and InvalidDestructionCode == "RequirementsNotMet",
	"Invalid authoritative Destruction must fail closed without throwing"
)
Sessions.Remove(InvalidDestructionPlayer)

local ReqLevel5 = LevelFormula.GetRequirementForLevel(5)
local BelowPortalOk, BelowPortalCreates = TryPortal(ReqLevel5 - 1, false, 999999)
assert(BelowPortalOk and BelowPortalCreates == 0, "Spoofed Level must not bypass portal Bigger requirement")
local ExactPortalOk, ExactPortalCreates = TryPortal(ReqLevel5, false, 1)
assert(ExactPortalOk and ExactPortalCreates == 1, "Exact authoritative Bigger must enter the portal")
local FrozenPortalOk, FrozenPortalCreates = TryPortal(ReqLevel5, true, 999999)
assert(FrozenPortalOk and FrozenPortalCreates == 0, "Frozen session must fail portal entry closed")
local InvalidPortalOk, InvalidPortalCreates = TryPortal(-1, false, 999999)
assert(InvalidPortalOk and InvalidPortalCreates == 0, "Invalid authoritative Bigger must fail portal entry closed")

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

-- Initial session creation lifecycle sync & repair test
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

Sessions.Set(mockPlayer, loadedSession)
EquipmentServiceModule:OnSessionCreated(mockPlayer, loadedSession)
assert(
	loadedSession.EquippedGrowthUpgrade == nil,
	"Invalid persisted equipped upgrade must fail safe to nil via session mutation repair on session load"
)
assert(mockPlayer:GetAttribute("EquippedGrowthUpgrade") == "None", "Attribute must reset to None")
Sessions.Remove(mockPlayer)

print("equipment_system service tests: PASS")

-- 4. RemoteEvent and lifecycle tests
EquipmentServiceModule:Init()
EquipmentServiceModule:Init()
EquipmentServiceModule:Start()
EquipmentServiceModule:Start()
local EquipmentFolder = assert(ReplicatedStorage.BiggerEvents and ReplicatedStorage.BiggerEvents.Equipment)
local RequestRemote = assert(EquipmentFolder.Request, "Equipment Request RemoteEvent must exist")
local ResponseRemote = assert(EquipmentFolder.Response, "Equipment Response RemoteEvent must exist")
local StateChangedRemote = assert(EquipmentFolder.StateChanged, "Equipment StateChanged RemoteEvent must exist")
assert(RequestRemote:IsA("RemoteEvent") and ResponseRemote:IsA("RemoteEvent") and StateChangedRemote:IsA("RemoteEvent"))
assert(#RequestRemote.OnServerEvent.Callbacks == 1, "Init must connect one request handler")
assert(#PlayersMock.PlayerRemoving.Callbacks == 1, "Start must connect one PlayerRemoving handler")
assert(EquipmentFolder.UnlockUpgrade == nil and EquipmentFolder.EquipUpgrade == nil)
assert(EquipmentFolder.GetEquipmentState == nil and EquipmentFolder.EquipmentStateChanged == nil)

function ClientPlayer:SetAttribute(Key: string, Value: any)
	self[Key] = Value
end
function ClientPlayer:GetAttribute(Key: string): any
	return self[Key]
end
local ClientSession = CreateEquipmentSession(ClientPlayer, LevelFormula.GetRequirementForLevel(5), 2)
ClientSession.EquipmentRequestInFlight = false
ClientSession.EquipmentLastRequestTimestamp = 0
Sessions.Set(ClientPlayer, ClientSession)

RequestRemote.OnServerEvent:Fire(ClientPlayer, {
	RequestId = "state-1",
	Operation = "GetState",
	Payload = {},
})
assert(#ResponseRemote.ClientCalls == 1)
assert(ResponseRemote.ClientCalls[1][1] == ClientPlayer)
assert(ResponseRemote.ClientCalls[1][2].RequestId == "state-1")
assert(ResponseRemote.ClientCalls[1][2].Success == true)

ClientSession.EquipmentLastRequestTimestamp = -math.huge
local SavesBeforeRemoteUnlock = SaveServiceSpy.QueueCalls
RequestRemote.OnServerEvent:Fire(ClientPlayer, {
	RequestId = "unlock-1",
	Operation = "Unlock",
	Payload = { UpgradeId = "Protein" },
})
assert(#ResponseRemote.ClientCalls == 2)
assert(ResponseRemote.ClientCalls[2][2].RequestId == "unlock-1")
assert(ResponseRemote.ClientCalls[2][2].Success == true)
assert(ClientSession.UnlockedGrowthUpgrades.Protein == true)
assert(ClientSession.EquippedGrowthUpgrade == nil)
assert(SaveServiceSpy.QueueCalls == SavesBeforeRemoteUnlock + 1)

RequestRemote.OnServerEvent:Fire(ClientPlayer, {
	RequestId = "equip-rate-limited",
	Operation = "Equip",
	Payload = { UpgradeId = "Protein" },
})
assert(#ResponseRemote.ClientCalls == 3)
assert(ResponseRemote.ClientCalls[3][2].ErrorCode == "RateLimited")
assert(ClientSession.EquipmentRequestInFlight == false)

local ResponsesBeforeMalformed = #ResponseRemote.ClientCalls
RequestRemote.OnServerEvent:Fire(ClientPlayer, {
	RequestId = string.rep("x", 65),
	Operation = "GetState",
})
assert(#ResponseRemote.ClientCalls == ResponsesBeforeMalformed, "Oversized RequestId must be dropped")

ClientSession.EquipmentRequestInFlight = true
ClientSession.EquipmentLastRequestTimestamp = 10
PlayersMock.PlayerRemoving:Fire(ClientPlayer)
assert(ClientSession.EquipmentRequestInFlight == false and ClientSession.EquipmentLastRequestTimestamp == 0)

-- 5. EquipmentController client tests
EquipmentControllerModule.Init()

local stateCopy1 = EquipmentControllerModule.GetState()
assert(stateCopy1.EquippedUpgradeId == "None", "Default client state equipped upgrade must be None")
assert(#stateCopy1.UnlockedUpgradeIds == 0, "Default client state unlocked list must be empty")

-- Verify defensive copy isolation
table.insert(stateCopy1.UnlockedUpgradeIds, "SpoofedItem")
local stateCopy2 = EquipmentControllerModule.GetState()
assert(#stateCopy2.UnlockedUpgradeIds == 0, "Mutating returned GetState table must not mutate internal client state")

-- Verify callback registration and unsubscribe
local callbackFired = false
local unsubscribe = EquipmentControllerModule.OnStateChanged(function(state)
	callbackFired = true
end)
assert(callbackFired == true, "OnStateChanged must fire immediately upon subscription with current state")
unsubscribe()

local ResponseCallbackCalls = 0
ClientSession.EquipmentLastRequestTimestamp = -math.huge
local StateRequestId, StateRequestError = EquipmentControllerModule.RequestState(function(Success, ErrorCode, State)
	ResponseCallbackCalls += 1
	assert(Success == true and ErrorCode == "Success")
	assert(State.EquippedUpgradeId == "None")
end)
assert(type(StateRequestId) == "string" and StateRequestError == nil)
assert(ResponseCallbackCalls == 1)

local StateBeforeMalformed = EquipmentControllerModule.GetState()
StateChangedRemote:FireClient(ClientPlayer, {
	EquippedUpgradeId = "Protein",
	UnlockedUpgradeIds = { "Protein", "Protein" },
})
local StateAfterMalformed = EquipmentControllerModule.GetState()
assert(StateAfterMalformed.EquippedUpgradeId == StateBeforeMalformed.EquippedUpgradeId)
assert(#StateAfterMalformed.UnlockedUpgradeIds == #StateBeforeMalformed.UnlockedUpgradeIds)

ResponseRemote:FireClient(ClientPlayer, {
	RequestId = StateRequestId,
	Success = true,
	ErrorCode = "Success",
	StateSnapshot = { EquippedUpgradeId = "None", UnlockedUpgradeIds = {} },
})
assert(ResponseCallbackCalls == 1, "Duplicate response must be ignored")

local ServerCallbacks = table.clone(RequestRemote.OnServerEvent.Callbacks)
table.clear(RequestRemote.OnServerEvent.Callbacks)
local TimeoutCalls = 0
local TimeoutRequestId = EquipmentControllerModule.RequestState(function(Success, ErrorCode, State)
	TimeoutCalls += 1
	assert(Success == false and ErrorCode == "Timeout" and State == nil)
end)
assert(type(TimeoutRequestId) == "string")
task.wait(5.1)
assert(TimeoutCalls == 1)
for _, Callback in ServerCallbacks do
	table.insert(RequestRemote.OnServerEvent.Callbacks, Callback)
end

print("equipment_system controller tests: PASS")
Sessions.Remove(ClientPlayer)
