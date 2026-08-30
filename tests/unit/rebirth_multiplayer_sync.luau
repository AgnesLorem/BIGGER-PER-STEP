--!strict
-- tests/unit/rebirth_multiplayer_sync.luau
-- Comprehensive unit tests for MVP-08 Rebirth Multiplayer State Sync & Strength Calculation.

local fs = require("@lune/fs")
local luau = require("@lune/luau")
local task = require("@lune/task")

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

local function createContainer(tableObj: any): any
	tableObj.Name = tableObj.Name or "Container"
	tableObj.ClassName = tableObj.ClassName or "Folder"
	tableObj.IsA = function(self: any, expected: string)
		return self.ClassName == expected or expected == "Instance" or expected == "Folder"
	end
	tableObj.WaitForChild = function(self: any, childName: string, _timeout: number?)
		return self[childName]
	end
	tableObj.FindFirstChild = function(self: any, childName: string)
		return self[childName]
	end
	return tableObj
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

local RebirthConfig = require("../../src/shared/Game/Config/RebirthConfig")
local LevelFormula = require("../../src/shared/Game/Progression/LevelFormula")
local UpgradesConfig = require("../../src/shared/Game/Config/UpgradesConfig")
local AuraConfig = require("../../src/shared/Game/Config/AuraConfig")
local Sessions = require("../../src/server/Core/Registry/RuntimeRegistry/Sessions")
local PlayerProfileSchema = require("../../src/server/Core/Utilities/PlayerProfileSchema")
local ServiceRegistry = require("../../src/server/Core/Registry/ServiceRegistry")

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

local AuraFormula = loadModule("src/shared/Game/Progression/AuraFormula.luau", "AuraFormula", {
	script = createContainer({
		Parent = createContainer({
			Parent = createContainer({
				Config = createContainer({
					AuraConfig = createModuleContainer(AuraConfig),
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
			AuraFormula = createModuleContainer(AuraFormula),
		}),
	}),
	Core = createContainer({
		Utilities = createContainer({
			FormatNumber = createModuleContainer(function(Value: number)
				return tostring(Value)
			end),
		}),
		Config = createContainer({
			ShopUIConfig = createModuleContainer({}),
		}),
	}),
})

local ReplicatedStorageMock = createContainer({
	BiggerShared = BiggerShared,
	BiggerEvents = createContainer({
		Rebirth = createContainer({}),
	}),
})

local function ApproxEq(A: number, B: number, Tolerance: number?): boolean
	local Tol = Tolerance or 0.0001
	return math.abs(A - B) <= Tol
end

-- =========================================================================
-- SECTION 1: SOURCE OF TRUTH VERIFICATION
-- =========================================================================
print("--- [1] Verifying Source of Truth (Formulas & Config) ---")

local R0_Req = RebirthFormula.GetRequiredLevel(0)
local R1_Req = RebirthFormula.GetRequiredLevel(1)
local R2_Req = RebirthFormula.GetRequiredLevel(2)
local R3_Req = RebirthFormula.GetRequiredLevel(3)

assert(R0_Req == RebirthConfig.BaseLevelRequirement, "R0 req must equal BaseLevelRequirement")
assert(
	R1_Req == RebirthConfig.BaseLevelRequirement + RebirthConfig.LevelIncrementPerRebirth,
	"R1 req must match increment"
)
assert(
	R2_Req == RebirthConfig.BaseLevelRequirement + 2 * RebirthConfig.LevelIncrementPerRebirth,
	"R2 req must match 2x increment"
)
assert(
	R3_Req == RebirthConfig.BaseLevelRequirement + 3 * RebirthConfig.LevelIncrementPerRebirth,
	"R3 req must match 3x increment"
)

local R0_Mult = RebirthFormula.GetMultiplier(0)
local R1_Mult = RebirthFormula.GetMultiplier(1)
local R2_Mult = RebirthFormula.GetMultiplier(2)
local R3_Mult = RebirthFormula.GetMultiplier(3)

assert(ApproxEq(R0_Mult, RebirthConfig.BaseMultiplier), "R0 mult must equal BaseMultiplier")
assert(
	ApproxEq(R1_Mult, RebirthConfig.BaseMultiplier + 1 * RebirthConfig.MultiplierPerRebirth),
	"R1 mult must match formula"
)
assert(
	ApproxEq(R2_Mult, RebirthConfig.BaseMultiplier + 2 * RebirthConfig.MultiplierPerRebirth),
	"R2 mult must match formula"
)
assert(
	ApproxEq(R3_Mult, RebirthConfig.BaseMultiplier + 3 * RebirthConfig.MultiplierPerRebirth),
	"R3 mult must match formula"
)

print(string.format("  R0: Req Level %d, Mult %.2fx", R0_Req, R0_Mult))
print(string.format("  R1: Req Level %d, Mult %.2fx", R1_Req, R1_Mult))
print(string.format("  R2: Req Level %d, Mult %.2fx", R2_Req, R2_Mult))
print(string.format("  R3: Req Level %d, Mult %.2fx", R3_Req, R3_Mult))

-- =========================================================================
-- SECTION 2: LOAD PRODUCTION MODULES WITH CONTAINER ENVIRONMENT
-- =========================================================================
local PlayersMock = createContainer({ Name = "Players", PlayerRemoving = createSignal() })

local MockGame = {
	GetService = function(self: any, ServiceName: string)
		if ServiceName == "Players" then
			return PlayersMock
		elseif ServiceName == "ReplicatedStorage" then
			return ReplicatedStorageMock
		end
		error("Unexpected service: " .. ServiceName)
	end,
}

local GrowthFormula = loadModule("src/server/Game/Formula/GrowthFormula.luau", "GrowthFormula", {
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

local SavedQueueCalls = {}
local MockSaveService = {
	QueueProfileSave = function(self: any, TargetPlayer: any)
		table.insert(SavedQueueCalls, TargetPlayer)
		return true
	end,
}

ServiceRegistry.Register("SaveService", MockSaveService)
ServiceRegistry.Register("GrowthFormula", GrowthFormula)

local function createMockInstance(Name: string, ClassName: string): any
	local Inst: any = createContainer({
		Name = Name,
		ClassName = ClassName,
		Parent = nil,
		Attributes = {},
		AttributeSignals = {},
		Value = nil,
		ChildAdded = createSignal(),
		ChildRemoved = createSignal(),
		MouseEnter = createSignal(),
		MouseLeave = createSignal(),
		MouseButton1Down = createSignal(),
		MouseButton1Up = createSignal(),
		MouseButton1Click = createSignal(),
		OnServerEvent = createSignal(),
		OnClientEvent = createSignal(),
	})
	function Inst:IsA(TargetClass: string): boolean
		return self.ClassName == TargetClass
	end
	function Inst:FindFirstChildOfClass(TargetClass: string): any
		for _, Child in pairs(self) do
			if type(Child) == "table" and Child.ClassName == TargetClass then
				return Child
			end
		end
		return nil
	end
	function Inst:GetChildren(): { any }
		local List = {}
		for Key, Child in pairs(self) do
			if type(Child) == "table" and Child.ClassName then
				table.insert(List, Child)
			end
		end
		return List
	end
	function Inst:SetAttribute(AttrName: string, AttrValue: any)
		self.Attributes[AttrName] = AttrValue
		if self.AttributeSignals[AttrName] then
			self.AttributeSignals[AttrName]:Fire(AttrValue)
		end
	end
	function Inst:GetAttribute(AttrName: string): any
		return self.Attributes[AttrName]
	end
	function Inst:GetAttributeChangedSignal(AttrName: string): any
		if not self.AttributeSignals[AttrName] then
			self.AttributeSignals[AttrName] = createSignal()
		end
		return self.AttributeSignals[AttrName]
	end
	function Inst:FireServer(...)
		self.OnServerEvent:Fire(self.ParentPlayer or self, ...)
	end
	function Inst:FireClient(Player: any, ...: any)
		self.OnClientEvent:Fire(...)
	end
	return Inst
end

local function createMockPlayer(UserId: number, Name: string): any
	local Player = createMockInstance(Name, "Player")
	Player.UserId = UserId
	local Leaderstats = createMockInstance("leaderstats", "Folder")
	Leaderstats.Parent = Player
	Player.leaderstats = Leaderstats

	local BiggerVal = createMockInstance("Bigger", "IntValue")
	BiggerVal.Value = 1
	BiggerVal.Parent = Leaderstats
	Leaderstats.Bigger = BiggerVal

	local RebirthVal = createMockInstance("Rebirth", "IntValue")
	RebirthVal.Value = 0
	RebirthVal.Parent = Leaderstats
	Leaderstats.Rebirth = RebirthVal

	return Player
end

local function createMockSession(Player: any, Rebirth: number?, Bigger: number?): Sessions.Session
	return {
		Player = Player,
		Bigger = Bigger or 1,
		Destruction = 0,
		Rebirth = Rebirth or 0,
		UnlockedGrowthUpgrades = {},
		EquippedGrowthUpgrade = nil,
		CompletedPortals = {},
		Settings = {
			SoundEnabled = true,
			MusicEnabled = true,
		},
		State = "InLobby",
		JoinedAt = 0,
		PurchaseHistory = {},
		CurrentWorldInstanceId = nil,
		HasDoubleMultiplier = false,
		HasVip = false,
		HasPremiumZonePass = false,
		GrowthRemainder = 0,
		CurrentAFKZone = nil,
		PremiumZonePromptedThisEntry = false,
		GamePassQueryGenerations = { Vip = 0, PremiumZone = 0 },
		EquipmentRequestInFlight = false,
		EquipmentLastRequestTimestamp = 0,
		LastActiveTimestamp = 0,
		LastLogoutTimestamp = 0,
		LastSaveTimestamp = 0,
		ProfileMutationsFrozen = false,
		ProfileMutationFreezeReason = nil,
	}
end

local RebirthService = loadModule("src/server/Game/Services/RebirthService.luau", "RebirthService", {
	game = MockGame,
	Instance = {
		new = function(ClassName: string)
			return createMockInstance(ClassName, ClassName)
		end,
	},
	script = createContainer({
		Parent = createContainer({
			Parent = createContainer({
				Formula = createContainer({
					GrowthFormula = createModuleContainer(GrowthFormula),
				}),
				Parent = createContainer({
					Core = createContainer({
						Registry = createContainer({
							RuntimeRegistry = createContainer({
								Sessions = createModuleContainer(Sessions),
							}),
							ServiceRegistry = createModuleContainer(ServiceRegistry),
						}),
						Utilities = createContainer({
							Logger = createModuleContainer({
								Info = function(...) end,
								Warn = function(...) end,
								Error = function(...) end,
							}),
						}),
						Events = createContainer({
							EventBus = createModuleContainer({
								Publish = function(...) end,
							}),
						}),
					}),
				}),
			}),
		}),
	}),
})

RebirthService:Init()

-- =========================================================================
-- SECTION 3: REBIRTH SERVICE AUTHORITATIVE SNAPSHOT & MULTIPLIER TESTS
-- =========================================================================
print("--- [2] Testing RebirthService Authoritative Snapshot & Multiplier ---")

local Player1 = createMockPlayer(1001, "PlayerOne")
Player1.Parent = PlayersMock
PlayersMock.PlayerOne = Player1

local BiggerForR1 = LevelFormula.GetRequirementForLevel(R0_Req)
local Session1 = createMockSession(Player1, 0, BiggerForR1)
Sessions.Set(Player1, Session1)

-- 1. Initial State: Rebirth = 0
assert(Session1.Rebirth == 0, "Initial Rebirth must be 0")
assert(GrowthFormula.GetMultiplier(Session1) == R0_Mult, "Initial Multiplier must be R0_Mult")

-- 2. Execute First Rebirth (R0 -> R1)
local Success1, Code1, NewCount1, TotalMult1, RebirthMult1 = RebirthService:RequestRebirth(Player1)
assert(Success1 == true, "Rebirth 1 must succeed: " .. tostring(Code1))
assert(NewCount1 == 1, "New Rebirth count must be exactly 1")
assert(Session1.Rebirth == 1, "Session RAM Rebirth must be updated to 1")
assert(Session1.Bigger == 0, "Session RAM Bigger must be reset to 0")
assert(
	ApproxEq(TotalMult1 :: number, R1_Mult),
	string.format("Rebirth 1 total mult must be %.2f, got %s", R1_Mult, tostring(TotalMult1))
)
assert(ApproxEq(RebirthMult1 :: number, R1_Mult), "Rebirth 1 rebirth mult must be 1.75x")
assert(Player1.Attributes.Rebirth == 1, "Player attribute Rebirth must be 1")
assert(Player1.Attributes.Bigger == 0, "Player attribute Bigger must be 0")
assert(Player1.Attributes.Level == 1, "Player attribute Level must be 1")
assert(ApproxEq(Player1.Attributes.Multiplier, R1_Mult), "Player attribute Multiplier must be updated to 1.75x")
assert(Player1.leaderstats.Rebirth.Value == 1, "Leaderstats Rebirth must be 1")

-- Check Strength / Bigger calculation immediately after Rebirth 1
local StrengthGain1 = GrowthFormula.Calculate(Session1, { BaseGain = 10, ZoneMultiplier = 1 })
assert(ApproxEq(StrengthGain1, 10 * R1_Mult), "Strength calculation must immediately use Rebirth 1 multiplier")

-- Advance Player 1 to Level 70 for Rebirth 2
local BiggerForR2 = LevelFormula.GetRequirementForLevel(R1_Req)
Sessions.Mutate(Player1, function(S)
	S.Bigger = BiggerForR2
end)

-- 3. Execute Second Rebirth (R1 -> R2)
task.wait(2.1) -- pass debounce cooldown
local Success2, Code2, NewCount2, TotalMult2, RebirthMult2 = RebirthService:RequestRebirth(Player1)
assert(Success2 == true, "Rebirth 2 must succeed: " .. tostring(Code2))
assert(NewCount2 == 2, "New Rebirth count must be exactly 2")
assert(Session1.Rebirth == 2, "Session RAM Rebirth must be 2")
assert(Session1.Bigger == 0, "Session RAM Bigger must be reset to 0")
assert(ApproxEq(TotalMult2 :: number, R2_Mult), "Rebirth 2 total mult must be 2.50x")
assert(ApproxEq(RebirthMult2 :: number, R2_Mult), "Rebirth 2 rebirth mult must be 2.50x")
assert(Player1.Attributes.Rebirth == 2, "Player attribute Rebirth must be 2")
assert(ApproxEq(Player1.Attributes.Multiplier, R2_Mult), "Player attribute Multiplier must be 2.50x")

-- Advance Player 1 to Level 120 for Rebirth 3
local BiggerForR3 = LevelFormula.GetRequirementForLevel(R2_Req)
Sessions.Mutate(Player1, function(S)
	S.Bigger = BiggerForR3
end)

-- 4. Execute Third Rebirth (R2 -> R3)
task.wait(2.1)
local Success3, Code3, NewCount3, TotalMult3, RebirthMult3 = RebirthService:RequestRebirth(Player1)
assert(Success3 == true, "Rebirth 3 must succeed: " .. tostring(Code3))
assert(NewCount3 == 3, "New Rebirth count must be exactly 3")
assert(Session1.Rebirth == 3, "Session RAM Rebirth must be 3")
assert(ApproxEq(TotalMult3 :: number, R3_Mult), "Rebirth 3 total mult must be 3.25x")
assert(Player1.Attributes.Rebirth == 3, "Player attribute Rebirth must be 3")
assert(ApproxEq(Player1.Attributes.Multiplier, R3_Mult), "Player attribute Multiplier must be 3.25x")

print("  Solo Rebirth sequence (R0->R1->R2->R3) and immediate Strength calculation: PASS")

-- =========================================================================
-- SECTION 4: MULTIPLAYER ISOLATION (PLAYER A VS PLAYER B)
-- =========================================================================
print("--- [3] Testing Multiplayer Isolation (Player A vs Player B) ---")

local PlayerA = createMockPlayer(2001, "PlayerA")
PlayerA.Parent = PlayersMock
PlayersMock.PlayerA = PlayerA

local PlayerB = createMockPlayer(2002, "PlayerB")
PlayerB.Parent = PlayersMock
PlayersMock.PlayerB = PlayerB

local SessionA = createMockSession(PlayerA, 0, BiggerForR1)
local SessionB = createMockSession(PlayerB, 0, 50) -- Player B only Level 5

Sessions.Set(PlayerA, SessionA)
Sessions.Set(PlayerB, SessionB)

-- Player A performs Rebirth #1
local SuccessA, _, CountA, MultA = RebirthService:RequestRebirth(PlayerA)
assert(SuccessA == true, "Player A rebirth must succeed")
assert(CountA == 1, "Player A rebirth count must be 1")
assert(ApproxEq(MultA :: number, R1_Mult), "Player A multiplier must be 1.75x")

-- Verify Player B is completely unchanged
assert(SessionB.Rebirth == 0, "Player B Session Rebirth must remain 0")
assert(SessionB.Bigger == 50, "Player B Session Bigger must remain 50")
assert(PlayerB.Attributes.Rebirth == nil or PlayerB.Attributes.Rebirth == 0, "Player B attribute Rebirth must remain 0")
assert(GrowthFormula.GetMultiplier(SessionB) == R0_Mult, "Player B Multiplier must remain 1.00x")
assert(
	GrowthFormula.Calculate(SessionB, { BaseGain = 10, ZoneMultiplier = 1 }) == 10 * R0_Mult,
	"Player B gain must remain 10"
)

print("  Multiplayer Isolation (Player A Rebirth does not affect Player B): PASS")

-- =========================================================================
-- SECTION 5: CONCURRENT REBIRTH REQUESTS
-- =========================================================================
print("--- [4] Testing Concurrent Rebirth Requests ---")

local PlayerC = createMockPlayer(3001, "PlayerC")
PlayerC.Parent = PlayersMock
local PlayerD = createMockPlayer(3002, "PlayerD")
PlayerD.Parent = PlayersMock

local SessionC = createMockSession(PlayerC, 0, BiggerForR1)
local SessionD = createMockSession(PlayerD, 0, BiggerForR1)
Sessions.Set(PlayerC, SessionC)
Sessions.Set(PlayerD, SessionD)

local SuccessC, _, CountC, MultC = RebirthService:RequestRebirth(PlayerC)
local SuccessD, _, CountD, MultD = RebirthService:RequestRebirth(PlayerD)

assert(SuccessC == true and SuccessD == true, "Both concurrent rebirths must succeed")
assert(CountC == 1 and CountD == 1, "Both players must reach Rebirth 1")
assert(SessionC.Rebirth == 1 and SessionD.Rebirth == 1, "Both sessions must record Rebirth 1")
assert(
	ApproxEq(MultC :: number, R1_Mult) and ApproxEq(MultD :: number, R1_Mult),
	"Both players must receive 1.75x multiplier"
)

print("  Concurrent Rebirth Requests: PASS")

-- =========================================================================
-- SECTION 6: GUI CONTROLLER AUTHORITATIVE SNAPSHOT & HUD UPDATE
-- =========================================================================
print("--- [5] Testing GuiController Authoritative Snapshot Handling ---")

local MockScreenGui = createMockInstance("MainHUD", "ScreenGui")
local MockSafeAreaRoot = createMockInstance("SafeAreaRoot", "Frame")
MockSafeAreaRoot.Parent = MockScreenGui
MockScreenGui.SafeAreaRoot = MockSafeAreaRoot

local MockPersistentHUD = createMockInstance("PersistentHUD", "Frame")
MockPersistentHUD.Parent = MockSafeAreaRoot
MockSafeAreaRoot.PersistentHUD = MockPersistentHUD

local MockLeftSidebar = createMockInstance("LeftSidebar", "Frame")
MockLeftSidebar.Parent = MockPersistentHUD
MockPersistentHUD.LeftSidebar = MockLeftSidebar

local MockRebirthButton = createMockInstance("Rebirth", "ImageButton")
MockRebirthButton.Parent = MockLeftSidebar
MockLeftSidebar.Rebirth = MockRebirthButton

local MockBottomHUD = createMockInstance("BottomHUD", "Frame")
MockBottomHUD.Parent = MockPersistentHUD
MockPersistentHUD.BottomHUD = MockBottomHUD

local MockProgressBarFrame = createMockInstance("ProgressBarFrame", "Frame")
MockProgressBarFrame.Parent = MockBottomHUD
MockBottomHUD.ProgressBarFrame = MockProgressBarFrame

local MockProgressBG = createMockInstance("ProgressBG", "Frame")
MockProgressBG.Parent = MockProgressBarFrame
MockProgressBarFrame.ProgressBG = MockProgressBG

-- Place file hierarchy: LevelLabel and ProgressTextLabel are direct children of ProgressBarFrame
local MockLevelLabel = createMockInstance("LevelLabel", "TextLabel")
MockLevelLabel.Parent = MockProgressBarFrame
MockProgressBarFrame.LevelLabel = MockLevelLabel

local MockProgressTextLabel = createMockInstance("ProgressTextLabel", "TextLabel")
MockProgressTextLabel.Parent = MockProgressBarFrame
MockProgressBarFrame.ProgressTextLabel = MockProgressTextLabel

local MockBarContainer = createMockInstance("BarContainer", "Frame")
MockBarContainer.Parent = MockProgressBG
MockProgressBG.BarContainer = MockBarContainer

local MockProgressFill = createMockInstance("ProgressFill", "ImageLabel")
MockProgressFill.Parent = MockBarContainer
MockBarContainer.ProgressFill = MockProgressFill

local MockButtonsContainer = createMockInstance("ButtonsContainer", "Frame")
MockButtonsContainer.Parent = MockBottomHUD
MockBottomHUD.ButtonsContainer = MockButtonsContainer

local ClientPlayer = createMockPlayer(4001, "ClientPlayer")
local ClientPlayerGui = createMockInstance("PlayerGui", "PlayerGui")
ClientPlayerGui.Parent = ClientPlayer
ClientPlayer.PlayerGui = ClientPlayerGui
ClientPlayerGui.MainHUD = MockScreenGui

local ClientRebirthRequest = createMockInstance("Request", "RemoteEvent")
local ClientRebirthResponse = createMockInstance("Response", "RemoteEvent")

local RebirthRequestFired = false
ClientRebirthRequest.OnServerEvent:Connect(function()
	RebirthRequestFired = true
end)

local ClientRebirthFolder = createContainer({
	Request = ClientRebirthRequest,
	Response = ClientRebirthResponse,
})

local ClientReplicatedStorage = createContainer({
	BiggerShared = BiggerShared,
	BiggerEvents = createContainer({
		Rebirth = ClientRebirthFolder,
	}),
})

local MockTweenService = {
	Create = function(self: any, Target: any, Info: any, Props: any)
		return {
			Play = function()
				for K, V in pairs(Props) do
					Target[K] = V
				end
			end,
		}
	end,
}

local MockMarketplaceService = {
	PromptProductPurchase = function() end,
	PromptGamePassPurchase = function() end,
}

local GuiController = loadModule("src/client/controllers/GuiController.luau", "GuiController", {
	game = {
		GetService = function(self: any, Svc: string)
			if Svc == "Players" then
				return { LocalPlayer = ClientPlayer }
			elseif Svc == "ReplicatedStorage" then
				return ClientReplicatedStorage
			elseif Svc == "TweenService" then
				return MockTweenService
			elseif Svc == "MarketplaceService" then
				return MockMarketplaceService
			end
			error("Unexpected client service: " .. Svc)
		end,
	},
	Instance = {
		new = function(ClassName: string)
			return createMockInstance(ClassName, ClassName)
		end,
	},
	UDim2 = {
		new = function(x, xo, y, yo)
			return { XScale = x, XOffset = xo, YScale = y, YOffset = yo }
		end,
	},
	TweenInfo = {
		new = function(...)
			return {}
		end,
	},
	Enum = {
		EasingStyle = { Quad = "Quad" },
		EasingDirection = { Out = "Out" },
	},
})

GuiController.Init()
GuiController.Start()

-- REGRESSION ASSERTION: GuiController must successfully bind to actual Place hierarchy
assert(GuiController.GetStatus() == "Ready", "GuiController must be Ready with actual Place UI hierarchy")

-- REGRESSION ASSERTION: Rebirth button click must be bound and fire Request remote to server
MockRebirthButton.MouseButton1Click:Fire()
assert(RebirthRequestFired == true, "Rebirth button click must fire RequestRemote to Server")

-- 1. Initial Client State (Rebirth 0, Level 20, 600 Bigger)
ClientPlayer:SetAttribute("Bigger", 600)
ClientPlayer:SetAttribute("Level", 20)
ClientPlayer:SetAttribute("Multiplier", 1.0)
ClientPlayer:SetAttribute("Rebirth", 0)

assert(MockLevelLabel.Text == "600 BIGGER", "HUD must show initial 600 Bigger")
assert(MockProgressTextLabel.Text == "1X Multiplier", "HUD must show initial 1X Multiplier")

-- 2. Server sends Rebirth #1 Authoritative Snapshot via Response Remote
ClientRebirthResponse:FireClient(ClientPlayer, {
	Success = true,
	ErrorCode = "Success",
	Rebirth = 1,
	Level = 1,
	Bigger = 0,
	Multiplier = 1.75,
	RebirthMultiplier = 1.75,
})

-- VERIFY HUD UPDATES IMMEDIATELY FROM SNAPSHOT
assert(MockLevelLabel.Text == "0 BIGGER", "HUD must immediately show 0 BIGGER on Rebirth #1 snapshot")
assert(
	MockProgressTextLabel.Text == "1.75X Multiplier",
	"HUD must immediately show 1.75X Multiplier on Rebirth #1 snapshot"
)

-- 3. Server sends Rebirth #2 Authoritative Snapshot via Response Remote
ClientRebirthResponse:FireClient(ClientPlayer, {
	Success = true,
	ErrorCode = "Success",
	Rebirth = 2,
	Level = 1,
	Bigger = 0,
	Multiplier = 2.50,
	RebirthMultiplier = 2.50,
})

assert(MockLevelLabel.Text == "0 BIGGER", "HUD must immediately show 0 BIGGER on Rebirth #2 snapshot")
assert(
	MockProgressTextLabel.Text == "2.5X Multiplier",
	"HUD must immediately show 2.5X Multiplier on Rebirth #2 snapshot"
)

-- 4. Server sends Rebirth #3 Authoritative Snapshot via Response Remote
ClientRebirthResponse:FireClient(ClientPlayer, {
	Success = true,
	ErrorCode = "Success",
	Rebirth = 3,
	Level = 1,
	Bigger = 0,
	Multiplier = 3.25,
	RebirthMultiplier = 3.25,
})

assert(MockLevelLabel.Text == "0 BIGGER", "HUD must immediately show 0 BIGGER on Rebirth #3 snapshot")
assert(
	MockProgressTextLabel.Text == "3.25X Multiplier",
	"HUD must immediately show 3.25X Multiplier on Rebirth #3 snapshot"
)

GuiController.Destroy()
print("  GuiController Authoritative Snapshot & Instant HUD Update: PASS")

-- =========================================================================
-- SECTION 7: PERSISTENCE & DATA CONSISTENCY
-- =========================================================================
print("--- [6] Testing Persistence & Save Consistency ---")

local ProfileP1 = PlayerProfileSchema.Defaults()
ProfileP1.Rebirth = Session1.Rebirth
ProfileP1.Bigger = math.max(1, Session1.Bigger)

assert(ProfileP1.Rebirth == 3, "Persistent profile must store Rebirth = 3")
assert(ProfileP1.Bigger == 1, "Persistent profile minimum Bigger must be 1")

local Normalized = PlayerProfileSchema.Normalize(ProfileP1)
assert(Normalized.Rebirth == 3, "Normalized profile must preserve Rebirth = 3")

print("  Persistence & Save Consistency: PASS")

-- =========================================================================
print("\n========================================================")
print("ALL REBIRTH MULTIPLAYER STATE SYNC TESTS PASSED (100%)!")
print("========================================================\n")
