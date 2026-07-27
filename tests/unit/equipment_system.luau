--!strict
-- tests/unit/equipment_system.luau
-- Comprehensive unit tests for Equipment System (UpgradesConfig, GrowthFormula, EquipmentService, EquipmentController, Persistence).

local luneRequire: any = require
local fs = luneRequire("@lune/fs")
local luau = luneRequire("@lune/luau")
local task = luneRequire("@lune/task")

local UpgradesConfig = luneRequire("../../src/shared/Game/Config/UpgradesConfig")
local LevelFormula = luneRequire("../../src/shared/Game/Progression/LevelFormula")
local Sessions = luneRequire("../../src/server/Core/Registry/RuntimeRegistry/Sessions")

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
	local callbacks = {}
	local signal = {}

	function signal:Connect(callback: (...any) -> ())
		table.insert(callbacks, callback)
		return {
			Disconnect = function()
				local index = table.find(callbacks, callback)
				if index then
					table.remove(callbacks, index)
				end
			end,
		}
	end

	function signal:Fire(...: any)
		for _, callback in table.clone(callbacks) do
			callback(...)
		end
	end

	return signal
end

local PlayersMock: any

local function createInstance(className: string): any
	local object: any = {
		ClassName = className,
		Name = className,
	}

	function object:IsA(expectedClassName: string): boolean
		return self.ClassName == expectedClassName
	end

	function object:FindFirstChild(childName: string): any
		return self[childName]
	end

	function object:WaitForChild(childName: string, _timeout: number?): any
		return self[childName]
	end

	if className == "RemoteEvent" then
		object.OnClientEvent = createSignal()
		object.FireClientCalls = {}
		function object:FireClient(player: any, state: any)
			if self.FailFireClient then
				error("forced FireClient failure")
			end
			table.insert(self.FireClientCalls, { Player = player, State = state })
			if PlayersMock.LocalPlayer == player then
				self.OnClientEvent:Fire(state)
			end
		end
	elseif className == "RemoteFunction" then
		function object:InvokeServer(...: any): ...any
			return self.OnServerInvoke(PlayersMock.LocalPlayer, ...)
		end
	end

	return setmetatable(object, {
		__newindex = function(self: any, key: any, value: any)
			rawset(self, key, value)
			if key == "Parent" and value then
				value[self.Name] = self
			end
		end,
	})
end

PlayersMock = {
	Name = "Players",
	PlayerRemoving = createSignal(),
}

local function createContainer(tableObj: any): any
	tableObj.WaitForChild = function(self: any, childName: string, _timeout: number?)
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
	GetService = function(_self: any, serviceName: string): any
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

local EquipmentLoggerMock = {
	Warnings = {},
	Infos = {},
}
function EquipmentLoggerMock.Warn(...: any)
	table.insert(EquipmentLoggerMock.Warnings, table.pack(...))
end
function EquipmentLoggerMock.Info(...: any)
	table.insert(EquipmentLoggerMock.Infos, table.pack(...))
end

local EquipmentServiceModule = loadModule("src/server/Game/Services/EquipmentService.luau", "EquipmentService", {
	game = MockGame,
	Instance = {
		new = createInstance,
	},
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
							Logger = createModuleContainer(EquipmentLoggerMock),
						}),
					}),
				}),
			}),
		}),
	}),
})

local EquipmentControllerModule = loadModule("src/client/controllers/EquipmentController.luau", "EquipmentController", {
	game = MockGame,
	task = task,
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

local ExpectedDefinitions = {
	{ "None", 1.0, 0, 1 },
	{ "Protein", 1.5, 1, 5 },
	{ "SilverProtein", 2.0, 5, 10 },
	{ "GoldProtein", 3.0, 15, 25 },
	{ "DiamondProtein", 5.0, 30, 50 },
	{ "GrowthSerum", 10.0, 60, 100 },
	{ "AdvancedSerum", 25.0, 120, 200 },
	{ "TitanSerum", 50.0, 250, 500 },
}
for index, expected in ExpectedDefinitions do
	local id = expected[1] :: string
	local definition = UpgradesConfig.Upgrades[id]
	assert(UpgradesConfig.Sequence[index] == id, "Upgrade sequence mismatch at " .. tostring(index))
	assert(definition.Multiplier == expected[2], id .. " multiplier mismatch")
	assert(definition.RequiredDestruction == expected[3], id .. " Destruction requirement mismatch")
	assert(definition.RequiredLevel == expected[4], id .. " Level requirement mismatch")
end

local ConfigSource = fs.readFile("src/shared/Game/Config/UpgradesConfig.luau")
local MissingDefinitionSource, ReplacementCount =
	string.gsub(ConfigSource, "\n\tTitanSerum = TitanSerumDefinition,", "", 1)
assert(ReplacementCount == 1, "Config mutation fixture must remove one definition")
local MissingDefinitionChunk = luau.load(MissingDefinitionSource, "UpgradesConfigMissingDefinition")
setfenv(MissingDefinitionChunk, getfenv())
assert(pcall(MissingDefinitionChunk) == false, "UpgradesConfig validation must reject a Sequence ID with no definition")

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

local SaveServiceMock = {
	QueueCalls = 0,
	ReturnValue = true,
	Throw = false,
}
function SaveServiceMock:QueueProfileSave(_player: any): boolean
	self.QueueCalls += 1
	if self.Throw then
		error("forced save queue failure")
	end
	return self.ReturnValue
end

local GrowthServiceMock = {
	UpdateCalls = 0,
}
function GrowthServiceMock:UpdateMultiplierAttribute(player: any)
	self.UpdateCalls += 1
	local currentSession = Sessions.Get(player)
	if currentSession then
		player:SetAttribute("GrowthMultiplier", GrowthFormulaModule.GetMultiplier(currentSession))
	end
end

ServiceRegistryModule.Register("SaveService", SaveServiceMock)
ServiceRegistryModule.Register("GrowthService", GrowthServiceMock)
EquipmentServiceModule:Init()
EquipmentServiceModule:Start()

local longPayloadPlayer = CreateMockPlayer("LongPayloadUser", 999900)
local unlockCalls = 0
local payloadGuardService = setmetatable({
	UnlockUpgrade = function(_self: any, _player: any, _upgradeId: string)
		unlockCalls += 1
		return true, "Success"
	end,
}, { __index = EquipmentServiceModule })
local longPayloadOk, longPayloadCode =
	EquipmentServiceModule.InvokeUnlockSafe(payloadGuardService, longPayloadPlayer, string.rep("A", 129))
assert(
	longPayloadOk == false and longPayloadCode == "InvalidUpgrade" and unlockCalls == 0,
	"Oversized upgrade IDs must be rejected before reaching unlock logic"
)
EquipmentServiceModule:OnSessionDestroyed(longPayloadPlayer)

local mockPlayer = CreateMockPlayer("EquipmentTestUser", 999901)
PlayersMock.LocalPlayer = mockPlayer
local StateChangedRemoteMock = ReplicatedStorage.BiggerEvents.Equipment.EquipmentStateChanged
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
assert(session.EquippedGrowthUpgrade == nil, "Unlocking must not auto-equip Protein")
assert(SaveServiceMock.QueueCalls == 1, "Successful unlock must queue exactly one save")
assert(#StateChangedRemoteMock.FireClientCalls == 1, "Successful unlock must publish one state event")
assert(
	StateChangedRemoteMock.FireClientCalls[1].State.UnlockedUpgradeIds[1] == "Protein",
	"Published unlock state must use canonical sequence ordering"
)

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
assert(mockPlayer:GetAttribute("GrowthMultiplier") == 1.5, "GrowthMultiplier attribute must reflect Protein")
assert(SaveServiceMock.QueueCalls == 2, "Successful equip must queue exactly one additional save")
assert(GrowthServiceMock.UpdateCalls == 1, "Successful equip must refresh multiplier presentation")
assert(#StateChangedRemoteMock.FireClientCalls == 2, "Successful equip must publish one additional state event")

-- Equip no-op test
local noopOk, noopCode = EquipmentServiceModule:EquipUpgrade(mockPlayer, "Protein")
assert(noopOk == true and noopCode == "Success", "Equipping currently equipped upgrade returns success no-op")
assert(SaveServiceMock.QueueCalls == 2, "No-op equip must not queue a save")
assert(GrowthServiceMock.UpdateCalls == 1, "No-op equip must not refresh multiplier presentation")
assert(#StateChangedRemoteMock.FireClientCalls == 2, "No-op equip must not publish state")

-- Unequip test
local unequipOk, unequipCode = EquipmentServiceModule:EquipUpgrade(mockPlayer, "None")
assert(unequipOk == true and unequipCode == "Success", "Unequipping to None must succeed")
assert(session.EquippedGrowthUpgrade == nil, "EquippedGrowthUpgrade session field must be nil when unequipped")
assert(mockPlayer:GetAttribute("EquippedGrowthUpgrade") == "None", "Attribute mirrors virtual state None")
assert(mockPlayer:GetAttribute("GrowthMultiplier") == 1.0, "Unequip must restore the base equipment multiplier")
assert(SaveServiceMock.QueueCalls == 3, "Unequip must queue exactly one additional save")
assert(GrowthServiceMock.UpdateCalls == 2, "Unequip must refresh multiplier presentation")

-- Frozen session test
session.ProfileMutationsFrozen = true
local frozenUnlockOk, frozenUnlockCode = EquipmentServiceModule:UnlockUpgrade(mockPlayer, "SilverProtein")
assert(frozenUnlockOk == false and frozenUnlockCode == "Frozen", "Unlock on frozen session must return Frozen")

local frozenEquipOk, frozenEquipCode = EquipmentServiceModule:EquipUpgrade(mockPlayer, "Protein")
assert(frozenEquipOk == false and frozenEquipCode == "Frozen", "Equip on frozen session must return Frozen")

local invokeService = setmetatable({
	UnlockUpgrade = function(_self: any, _player: any, _upgradeId: string)
		return true, "Success"
	end,
}, { __index = EquipmentServiceModule })
local ratePlayer = CreateMockPlayer("RateLimitUser", 999902)
assert(
	EquipmentServiceModule.InvokeUnlockSafe(invokeService, ratePlayer, "Protein") == true,
	"First mutation request must pass the rate limit"
)
local rateOk, rateCode = EquipmentServiceModule.InvokeUnlockSafe(invokeService, ratePlayer, "Protein")
assert(rateOk == false and rateCode == "RateLimited", "Rapid sequential requests must be rate limited")
EquipmentServiceModule:OnSessionDestroyed(ratePlayer)
assert(
	EquipmentServiceModule.InvokeUnlockSafe(invokeService, ratePlayer, "Protein") == true,
	"Session cleanup must clear rate-limit state"
)

local removingPlayer = CreateMockPlayer("RemovingUser", 999903)
assert(
	EquipmentServiceModule.InvokeUnlockSafe(invokeService, removingPlayer, "Protein") == true,
	"PlayerRemoving test setup request must succeed"
)
PlayersMock.PlayerRemoving:Fire(removingPlayer)
assert(
	EquipmentServiceModule.InvokeUnlockSafe(invokeService, removingPlayer, "Protein") == true,
	"PlayerRemoving cleanup must clear request state"
)

local nestedCode: string? = nil
local inFlightService: any
inFlightService = setmetatable({
	UnlockUpgrade = function(self: any, player: any, upgradeId: string)
		local _, nestedResultCode = EquipmentServiceModule.InvokeUnlockSafe(self, player, upgradeId)
		nestedCode = nestedResultCode
		return true, "Success"
	end,
}, { __index = EquipmentServiceModule })
local inFlightPlayer = CreateMockPlayer("InFlightUser", 999904)
assert(
	EquipmentServiceModule.InvokeUnlockSafe(inFlightService, inFlightPlayer, "Protein") == true,
	"Outer in-flight test request must succeed"
)
assert(nestedCode == "RequestInFlight", "Concurrent mutation request must be rejected")

local exceptionService = setmetatable({
	ShouldThrow = true,
	UnlockUpgrade = function(self: any, _player: any, _upgradeId: string)
		if self.ShouldThrow then
			error("forced unlock failure")
		end
		return true, "Success"
	end,
}, { __index = EquipmentServiceModule })
local exceptionPlayer = CreateMockPlayer("ExceptionUser", 999905)
local exceptionOk, exceptionCode = EquipmentServiceModule.InvokeUnlockSafe(exceptionService, exceptionPlayer, "Protein")
assert(exceptionOk == false and exceptionCode == "MutationFailed", "Exceptions must return a stable result code")
task.wait(0.11)
exceptionService.ShouldThrow = false
assert(
	EquipmentServiceModule.InvokeUnlockSafe(exceptionService, exceptionPlayer, "Protein") == true,
	"Request lock must release after an exception"
)

local disconnectedPlayer = CreateMockPlayer("DisconnectedUser", 999906)
disconnectedPlayer.Parent = nil
local disconnectedOk, disconnectedCode =
	EquipmentServiceModule.InvokeUnlockSafe(invokeService, disconnectedPlayer, "Protein")
assert(
	disconnectedOk == false and disconnectedCode == "PlayerDisconnected",
	"Disconnected players must be rejected before mutation"
)

session.ProfileMutationsFrozen = false
Sessions.Remove(mockPlayer)

local saveFailurePlayer = CreateMockPlayer("SaveFailureUser", 999907)
local saveFailureSession = table.clone(session)
saveFailureSession.Player = saveFailurePlayer
saveFailureSession.UnlockedGrowthUpgrades = {}
saveFailureSession.EquippedGrowthUpgrade = nil
saveFailureSession.ProfileMutationsFrozen = false
Sessions.Set(saveFailurePlayer, saveFailureSession)
local saveCallsBeforeFailure = SaveServiceMock.QueueCalls
local warningsBeforeSaveFailure = #EquipmentLoggerMock.Warnings
SaveServiceMock.Throw = true
local saveFailureOk, saveFailureCode = EquipmentServiceModule:InvokeUnlockSafe(saveFailurePlayer, "Protein")
SaveServiceMock.Throw = false
assert(
	saveFailureOk == true and saveFailureCode == "Success",
	"A save-queue exception must not convert a valid in-memory mutation into a failed request"
)
assert(saveFailureSession.UnlockedGrowthUpgrades.Protein == true, "Valid mutation must survive save-queue failure")
assert(
	SaveServiceMock.QueueCalls == saveCallsBeforeFailure + 1,
	"Save-queue failure path must make exactly one non-blocking queue attempt"
)
assert(#EquipmentLoggerMock.Warnings == warningsBeforeSaveFailure + 1, "Save-queue failure must emit one warning")
Sessions.Remove(saveFailurePlayer)

local stateFailurePlayer = CreateMockPlayer("StateFailureUser", 999908)
local stateFailureSession = table.clone(session)
stateFailureSession.Player = stateFailurePlayer
stateFailureSession.UnlockedGrowthUpgrades = {}
stateFailureSession.EquippedGrowthUpgrade = nil
stateFailureSession.ProfileMutationsFrozen = false
Sessions.Set(stateFailurePlayer, stateFailureSession)
local saveCallsBeforeStateFailure = SaveServiceMock.QueueCalls
local warningsBeforeStateFailure = #EquipmentLoggerMock.Warnings
StateChangedRemoteMock.FailFireClient = true
local stateFailureOk, stateFailureCode = EquipmentServiceModule:InvokeUnlockSafe(stateFailurePlayer, "Protein")
StateChangedRemoteMock.FailFireClient = false
assert(
	stateFailureOk == true and stateFailureCode == "Success",
	"A presentation exception must not convert a valid in-memory mutation into a failed request"
)
assert(
	SaveServiceMock.QueueCalls == saveCallsBeforeStateFailure + 1,
	"A presentation exception must not prevent immediate save queuing"
)
assert(#EquipmentLoggerMock.Warnings == warningsBeforeStateFailure + 1, "Presentation failure must emit one warning")
Sessions.Remove(stateFailurePlayer)

local frozenRepairPlayer = CreateMockPlayer("FrozenRepairUser", 999909)
local frozenRepairSession = table.clone(session)
frozenRepairSession.Player = frozenRepairPlayer
frozenRepairSession.UnlockedGrowthUpgrades = {}
frozenRepairSession.EquippedGrowthUpgrade = "GoldProtein"
frozenRepairSession.ProfileMutationsFrozen = true
Sessions.Set(frozenRepairPlayer, frozenRepairSession)
frozenRepairPlayer:SetAttribute("EquippedGrowthUpgrade", "None")
local repairStateCallsBefore = #StateChangedRemoteMock.FireClientCalls
local repairSaveCallsBefore = SaveServiceMock.QueueCalls
local warningsBeforeFrozenRepair = #EquipmentLoggerMock.Warnings
EquipmentServiceModule:OnSessionCreated(frozenRepairPlayer, frozenRepairSession)
assert(
	frozenRepairSession.EquippedGrowthUpgrade == "GoldProtein",
	"Frozen invalid loaded state must not be assigned directly outside Sessions.Mutate"
)
assert(
	frozenRepairPlayer:GetAttribute("EquippedGrowthUpgrade") == "None",
	"Failed loaded-state repair must not publish an invalid equipped attribute"
)
assert(
	#StateChangedRemoteMock.FireClientCalls == repairStateCallsBefore,
	"Failed loaded-state repair must not publish invalid equipment state"
)
assert(SaveServiceMock.QueueCalls == repairSaveCallsBefore, "Failed loaded-state repair must not queue a save")
assert(
	#EquipmentLoggerMock.Warnings == warningsBeforeFrozenRepair + 1,
	"Failed loaded-state repair must emit one warning"
)
Sessions.Remove(frozenRepairPlayer)

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
local repairMutationSaveCallsBefore = SaveServiceMock.QueueCalls
local repairMutationStateCallsBefore = #StateChangedRemoteMock.FireClientCalls
EquipmentServiceModule:OnSessionCreated(mockPlayer, loadedSession)
assert(
	loadedSession.EquippedGrowthUpgrade == nil,
	"Invalid persisted equipped upgrade must fail safe to nil via session mutation repair on session load"
)
assert(mockPlayer:GetAttribute("EquippedGrowthUpgrade") == "None", "Attribute must reset to None")
assert(
	SaveServiceMock.QueueCalls == repairMutationSaveCallsBefore + 1,
	"Successful loaded-state repair must queue one save"
)
assert(
	#StateChangedRemoteMock.FireClientCalls == repairMutationStateCallsBefore + 1,
	"Successful loaded-state repair must publish corrected state"
)
local repairedState = EquipmentServiceModule:GetEquipmentState(mockPlayer)
assert(repairedState ~= nil, "Loaded session must expose authoritative equipment state")
table.insert((repairedState :: any).UnlockedUpgradeIds, "SpoofedItem")
assert(
	loadedSession.UnlockedGrowthUpgrades.SpoofedItem == nil,
	"Server state snapshots must not expose mutable session tables"
)
Sessions.Remove(mockPlayer)

print("equipment_system service tests: PASS")

-- 4. EquipmentController client tests
EquipmentControllerModule.Init()

local stateCopy1 = EquipmentControllerModule.GetState()
assert(stateCopy1.EquippedUpgradeId == "None", "Default client state equipped upgrade must be None")
assert(#stateCopy1.UnlockedUpgradeIds == 0, "Default client state unlocked list must be empty")

-- Verify defensive copy isolation
table.insert(stateCopy1.UnlockedUpgradeIds, "SpoofedItem")
local stateCopy2 = EquipmentControllerModule.GetState()
assert(#stateCopy2.UnlockedUpgradeIds == 0, "Mutating returned GetState table must not mutate internal client state")

local rejoinSession = table.clone(session)
rejoinSession.Player = mockPlayer
rejoinSession.UnlockedGrowthUpgrades = { Protein = true }
rejoinSession.EquippedGrowthUpgrade = "Protein"
rejoinSession.ProfileMutationsFrozen = false
Sessions.Set(mockPlayer, rejoinSession)
EquipmentControllerModule.Start()
task.wait()
local rejoinState = EquipmentControllerModule.GetState()
assert(rejoinState.EquippedUpgradeId == "Protein", "Initial state request must restore persisted equipped state")
assert(rejoinState.UnlockedUpgradeIds[1] == "Protein", "Initial state request must restore persisted unlocks")
Sessions.Remove(mockPlayer)

StateChangedRemoteMock.OnClientEvent:Fire({
	EquippedUpgradeId = 5,
	UnlockedUpgradeIds = { "Protein" },
})
assert(
	EquipmentControllerModule.GetState().EquippedUpgradeId == "Protein",
	"Malformed incoming state must be rejected instead of partially accepted"
)

local malformedUnlockedIds: any = { "Protein" }
malformedUnlockedIds.UnknownKey = "GoldProtein"
StateChangedRemoteMock.OnClientEvent:Fire({
	EquippedUpgradeId = "Protein",
	UnlockedUpgradeIds = malformedUnlockedIds,
})
assert(
	#EquipmentControllerModule.GetState().UnlockedUpgradeIds == 1,
	"Incoming unlocked IDs must be a strict string array"
)

local serverUnlockedIds = { "Protein" }
StateChangedRemoteMock.OnClientEvent:Fire({
	EquippedUpgradeId = "Protein",
	UnlockedUpgradeIds = serverUnlockedIds,
})
table.insert(serverUnlockedIds, "GoldProtein")
local copiedServerState = EquipmentControllerModule.GetState()
assert(copiedServerState.EquippedUpgradeId == "Protein", "Valid incoming state must replace the client snapshot")
assert(#copiedServerState.UnlockedUpgradeIds == 1, "Incoming state arrays must be copied defensively")

-- Verify callback registration and unsubscribe
local callbackFired = false
local callbackCount = 0
local unsubscribe = EquipmentControllerModule.OnStateChanged(function(state)
	callbackFired = true
	callbackCount += 1
	if callbackCount > 1 then
		table.insert(state.UnlockedUpgradeIds, "CallbackMutation")
	end
end)
assert(callbackFired == true, "OnStateChanged must fire immediately upon subscription with current state")
StateChangedRemoteMock.OnClientEvent:Fire({
	EquippedUpgradeId = "Protein",
	UnlockedUpgradeIds = { "Protein" },
})
assert(
	#EquipmentControllerModule.GetState().UnlockedUpgradeIds == 1,
	"State callbacks must not receive mutable internal tables"
)
unsubscribe()

-- Verify connected request methods return stable server result codes.
local reqOk, reqMsg = EquipmentControllerModule.RequestUnlock("Protein")
assert(
	reqOk == false and reqMsg == "NoSession",
	"RequestUnlock must return the stable authoritative server result code"
)

task.wait(0.11)
local equipReqOk, equipReqMsg = EquipmentControllerModule.RequestEquip("Protein")
assert(
	equipReqOk == false and equipReqMsg == "NoSession",
	"RequestEquip must return the stable authoritative server result code"
)

local function loadControllerForStorage(storage: any, name: string): any
	return loadModule("src/client/controllers/EquipmentController.luau", name, {
		game = {
			GetService = function(_self: any, serviceName: string)
				if serviceName == "ReplicatedStorage" then
					return storage
				end
				return nil
			end,
		},
		task = task,
	})
end

local emptyController = loadControllerForStorage(createContainer({}), "EquipmentControllerEmpty")
emptyController.Init()
local notReadyOk, notReadyCode = emptyController.RequestUnlock("Protein")
assert(notReadyOk == false and notReadyCode == "RemoteNotReady", "Missing remotes must return RemoteNotReady")

local wrongEquipmentFolder = createInstance("Folder")
wrongEquipmentFolder.Name = "Equipment"
wrongEquipmentFolder.UnlockUpgrade = createInstance("Folder")
local wrongEventsFolder = createInstance("Folder")
wrongEventsFolder.Name = "BiggerEvents"
wrongEventsFolder.Equipment = wrongEquipmentFolder
local wrongClassStorage = createContainer({
	BiggerEvents = wrongEventsFolder,
})
local wrongClassController = loadControllerForStorage(wrongClassStorage, "EquipmentControllerWrongClass")
wrongClassController.Init()
local wrongClassOk, wrongClassCode = wrongClassController.RequestUnlock("Protein")
assert(
	wrongClassOk == false and wrongClassCode == "RemoteNotReady",
	"Wrong-class remote instances must be rejected during resolution"
)

print("equipment_system controller tests: PASS")
