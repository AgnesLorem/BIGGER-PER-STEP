local fs = require("@lune/fs")
local luau = require("@lune/luau")
local task = require("@lune/task")

local Sessions = require("../../src/server/Core/Registry/RuntimeRegistry/Sessions")
local UpgradeConfig = require("../../src/server/Game/Config/UpgradeConfig")

local MAXIMUM_SAFE_INTEGER = 9007199254740991

local Failures = {}

local function check(Name: string, Callback: () -> ())
	local Success, Message = pcall(Callback)
	if not Success then
		table.insert(Failures, string.format("%s: %s", Name, tostring(Message)))
	else
		print(string.format("  PASS: %s", Name))
	end
end

local function loadModule(Path: string, Name: string, Environment: { [string]: any }?)
	assert(fs.isFile(Path), Name .. " production module is missing: " .. Path)
	local Chunk = luau.load(fs.readFile(Path), Name)
	setfenv(Chunk, setmetatable(Environment or {}, { __index = getfenv() }))
	return Chunk()
end

local BalanceConfig = loadModule("src/shared/Game/Progression/BalanceConfig.luau", "BalanceConfig", {})
local LevelFormula = loadModule("src/shared/Game/Progression/LevelFormula.luau", "LevelFormula", {
	script = {
		Parent = {
			BalanceConfig = BalanceConfig,
		},
	},
	require = function(Dep)
		return Dep
	end,
})
local ScaleConfig = loadModule("src/shared/Core/Config/ScaleConfig.luau", "ScaleConfig", {})
local ScaleCurve = loadModule("src/shared/Core/Utilities/ScaleCurve.luau", "ScaleCurve", {
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
	require = function(Dep)
		return Dep
	end,
})

local function childContainer(Children: { [string]: any })
	local Container = Children or {}
	function Container:WaitForChild(Name: string)
		return assert(self[Name], "missing child " .. Name)
	end
	function Container:FindFirstChild(Name: string)
		return self[Name]
	end
	return Container
end

local function fakeSignal()
	local Signal = { Callbacks = {} }
	function Signal:Connect(Callback)
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
		for _, Callback in self.Callbacks do
			Callback(...)
		end
	end
	return Signal
end

local function fakePlayer(UserId: number)
	local DestructionStat = { Value = 0 }
	function DestructionStat:IsA(ClassName: string)
		return ClassName == "IntValue"
	end

	local Leaderstats = {
		Destruction = DestructionStat,
	}
	function Leaderstats:FindFirstChild(Name: string)
		return self[Name]
	end

	local Player = {
		UserId = UserId,
		Name = "TestPlayer_" .. tostring(UserId),
		Attributes = {},
		leaderstats = Leaderstats,
		DestructionStat = DestructionStat,
	}
	function Player:SetAttribute(Key: string, Value: any)
		self.Attributes[Key] = Value
	end
	function Player:GetAttribute(Key: string)
		return self.Attributes[Key]
	end
	function Player:FindFirstChild(Name: string)
		return self[Name]
	end
	return Player
end

local function fakeSession(Player: any)
	return {
		Player = Player,
		Bigger = 1,
		Destruction = 0,
		Rebirth = 0,
		UnlockedGrowthUpgrades = {},
		EquippedGrowthUpgrade = nil,
		CompletedPortals = {},
		Settings = { SoundEnabled = true, MusicEnabled = true },
		HasDoubleMultiplier = false,
		HasVip = false,
		HasPremiumZonePass = false,
		HasAutoWins = false,
		DailyRewardDay = 1,
		LastDailyClaimTimestamp = 0,
		SpinTokens = 0,
		UnlockedTrails = {},
		EquippedTrail = nil,
		UnlockedTitles = {},
		EquippedTitle = nil,
		ProcessedPurchaseIds = {},
		ProfileMutationsFrozen = false,
		State = "InLobby",
		GrowthRemainder = 0,
	}
end

local function loadGrowthFormula()
	local GrowthTypes = {}
	local ReplicatedStorage = childContainer({
		BiggerShared = childContainer({
			Core = childContainer({ Types = childContainer({ GrowthTypes = GrowthTypes }) }),
		}),
	})
	local Game = {
		GetService = function(_, Name)
			assert(Name == "ReplicatedStorage")
			return ReplicatedStorage
		end,
	}
	local FormulaFolder = {
		Parent = {
			Config = { UpgradeConfig = UpgradeConfig },
			Parent = {
				Core = {
					Registry = {
						RuntimeRegistry = { Sessions = Sessions },
					},
				},
			},
		},
	}
	return loadModule("src/server/Game/Formula/GrowthFormula.luau", "GrowthFormula", {
		game = Game,
		script = { Parent = FormulaFolder },
		require = function(Dependency)
			return Dependency
		end,
	})
end

local function loadDestructionService()
	local Players = {
		GetPlayerFromCharacter = function()
			return nil
		end,
	}
	local Debris = {
		AddItem = function() end,
	}
	local StompValidation = {
		IsValid = function()
			return true
		end,
	}
	local ReplicatedStorage = childContainer({
		BiggerShared = childContainer({
			Core = childContainer({
				Utilities = childContainer({
					StompValidation = StompValidation,
					ScaleCurve = ScaleCurve,
				}),
				Config = childContainer({
					ScaleConfig = ScaleConfig,
				}),
			}),
		}),
	})
	local Game = {
		GetService = function(_, Name)
			if Name == "Players" then
				return Players
			elseif Name == "Debris" then
				return Debris
			elseif Name == "ReplicatedStorage" then
				return ReplicatedStorage
			end
			error("unexpected service " .. Name)
		end,
	}
	local Logger = {
		Info = function() end,
		Warn = function() end,
	}
	local ServiceRegistry = require("../../src/server/Core/Registry/ServiceRegistry")
	local World1Config = {
		ReturnPortalDebounceSeconds = 1.5,
		Objective = {
			ModelName = "Spider",
			HitboxName = "ObjectiveHitbox",
			DestructionReward = 1,
			HorizontalPadding = 1,
			MaximumRootHeight = 8,
			MinimumDownwardVelocity = -2,
		},
	}
	local ServicesFolder = {
		Parent = {
			Config = { World1Config = World1Config },
			Parent = {
				Core = {
					Registry = {
						RuntimeRegistry = { Sessions = Sessions },
						ServiceRegistry = ServiceRegistry,
					},
					Utilities = { Logger = Logger },
				},
			},
		},
	}
	return loadModule("src/server/Game/Services/DestructionService.luau", "DestructionService", {
		game = Game,
		script = { Parent = ServicesFolder },
		require = function(Dependency)
			return Dependency
		end,
	})
end

local function loadUpgradeService(DestructionService)
	local EventBus = {
		Subscribers = {},
		EventsFired = {},
	}
	function EventBus.Subscribe(Name: string, Callback: (...any) -> ())
		EventBus.Subscribers[Name] = EventBus.Subscribers[Name] or {}
		table.insert(EventBus.Subscribers[Name], Callback)
	end
	function EventBus.Publish(Name: string, ...: any)
		table.insert(EventBus.EventsFired, { Name = Name, Args = { ... } })
		for _, Callback in EventBus.Subscribers[Name] or {} do
			Callback(...)
		end
	end

	local Remotes = childContainer({
		RequestBuyUpgrade = { OnServerEvent = fakeSignal() },
		RequestEquipUpgrade = { OnServerEvent = fakeSignal() },
		UpdateUpgradeStatus = {
			ClientFired = {},
			FireClient = function(self, Player, Payload)
				table.insert(self.ClientFired, { Player = Player, Payload = Payload })
			end,
		},
	})
	local ReplicatedStorage = childContainer({
		Remotes = Remotes,
	})
	local Players = {
		GetPlayers = function()
			return {}
		end,
	}
	local Game = {
		GetService = function(_, Name)
			if Name == "Players" then
				return Players
			elseif Name == "ReplicatedStorage" then
				return ReplicatedStorage
			end
			error("unexpected service " .. Name)
		end,
	}
	local Logger = {
		Info = function() end,
		Warn = function() end,
	}
	local ServiceRegistry = {
		Get = function(Name)
			if Name == "DestructionService" then
				return DestructionService
			end
			error("unknown service " .. Name)
		end,
	}
	local ServicesFolder = {
		Parent = {
			Config = { UpgradeConfig = UpgradeConfig },
			Parent = {
				Core = {
					Registry = {
						RuntimeRegistry = { Sessions = Sessions },
						ServiceRegistry = ServiceRegistry,
					},
					Events = { EventBus = EventBus },
					Utilities = { Logger = Logger },
				},
			},
		},
	}
	local Service = loadModule("src/server/Game/Services/UpgradeService.luau", "UpgradeService", {
		game = Game,
		script = { Parent = ServicesFolder },
		require = function(Dependency)
			return Dependency
		end,
		task = {
			spawn = function(Callback, ...)
				Callback(...)
			end,
			wait = function() end,
		},
	})
	return Service, EventBus, Remotes
end

print("=== Running MVP-006 Task 3 Unit Tests ===")

--// 1. UpgradeConfig Tests \\--
check("UpgradeConfig definitions: exactly 15 upgrades with correct values & helpers", function()
	assert(UpgradeConfig ~= nil, "UpgradeConfig module must exist")
	assert(type(UpgradeConfig.List) == "table", "UpgradeConfig.List must be a table")
	assert(#UpgradeConfig.List == 15, string.format("Expected exactly 15 upgrades, got %d", #UpgradeConfig.List))

	local ExpectedUpgrades = {
		{ Order = 1, Name = "Protein", AdditiveGrowth = 5, Cost = 1 },
		{ Order = 2, Name = "Silver Protein", AdditiveGrowth = 20, Cost = 5 },
		{ Order = 3, Name = "Gold Protein", AdditiveGrowth = 60, Cost = 20 },
		{ Order = 4, Name = "Diamond Protein", AdditiveGrowth = 200, Cost = 50 },
		{ Order = 5, Name = "Emerald Protein", AdditiveGrowth = 650, Cost = 150 },
		{ Order = 6, Name = "Ruby Protein", AdditiveGrowth = 2000, Cost = 500 },
		{ Order = 7, Name = "Obsidian Protein", AdditiveGrowth = 6500, Cost = 1000000 },
		{ Order = 8, Name = "Growth Serum", AdditiveGrowth = 20000, Cost = 5000000 },
		{ Order = 9, Name = "Silver Serum", AdditiveGrowth = 65000, Cost = 25000000 },
		{ Order = 10, Name = "Gold Serum", AdditiveGrowth = 200000, Cost = 100000000 },
		{ Order = 11, Name = "Diamond Serum", AdditiveGrowth = 650000, Cost = 500000000 },
		{ Order = 12, Name = "Advanced Serum", AdditiveGrowth = 2000000, Cost = 2500000000 },
		{ Order = 13, Name = "Titan Serum", AdditiveGrowth = 6500000, Cost = 10000000000 },
		{ Order = 14, Name = "Cosmic Serum", AdditiveGrowth = 20000000, Cost = 50000000000 },
		{ Order = 15, Name = "Infinity Serum", AdditiveGrowth = 65000000, Cost = 250000000000 },
	}

	for Index, Expected in ipairs(ExpectedUpgrades) do
		local Actual = UpgradeConfig.List[Index]
		assert(Actual ~= nil, string.format("Missing upgrade at index %d", Index))
		assert(
			Actual.Order == Expected.Order,
			string.format(
				"Upgrade %d Order mismatch: expected %d, got %s",
				Index,
				Expected.Order,
				tostring(Actual.Order)
			)
		)
		assert(
			Actual.Name == Expected.Name,
			string.format("Upgrade %d Name mismatch: expected %s, got %s", Index, Expected.Name, tostring(Actual.Name))
		)
		assert(
			Actual.AdditiveGrowth == Expected.AdditiveGrowth,
			string.format(
				"Upgrade %s AdditiveGrowth mismatch: expected %d, got %s",
				Expected.Name,
				Expected.AdditiveGrowth,
				tostring(Actual.AdditiveGrowth)
			)
		)
		assert(
			Actual.Cost == Expected.Cost,
			string.format(
				"Upgrade %s Cost mismatch: expected %d, got %s",
				Expected.Name,
				Expected.Cost,
				tostring(Actual.Cost)
			)
		)
	end

	-- Test UpgradeConfig.Get
	local Protein = UpgradeConfig.Get("Protein")
	assert(
		Protein ~= nil and Protein.Name == "Protein" and Protein.AdditiveGrowth == 5,
		"UpgradeConfig.Get('Protein') failed"
	)
	local SilverProtein = UpgradeConfig.Get("Silver Protein")
	assert(
		SilverProtein ~= nil and SilverProtein.Name == "Silver Protein" and SilverProtein.AdditiveGrowth == 20,
		"UpgradeConfig.Get('Silver Protein') failed"
	)
	assert(UpgradeConfig.Get("NonexistentUpgrade") == nil, "UpgradeConfig.Get with invalid name should return nil")
	assert(UpgradeConfig.Get(1) ~= nil and UpgradeConfig.Get(1).Name == "Protein", "UpgradeConfig.Get(1) failed")

	-- Test UpgradeConfig.GetPrevious
	assert(UpgradeConfig.GetPrevious("Protein") == nil, "GetPrevious('Protein') should be nil (first upgrade)")
	assert(UpgradeConfig.GetPrevious(Protein) == nil, "GetPrevious(Protein) should be nil")
	local PrevOfSilver = UpgradeConfig.GetPrevious("Silver Protein")
	assert(
		PrevOfSilver ~= nil and PrevOfSilver.Name == "Protein",
		"GetPrevious('Silver Protein') should return Protein"
	)
	local PrevOfInfinity = UpgradeConfig.GetPrevious("Infinity Serum")
	assert(
		PrevOfInfinity ~= nil and PrevOfInfinity.Name == "Cosmic Serum",
		"GetPrevious('Infinity Serum') should return Cosmic Serum"
	)
	assert(UpgradeConfig.GetPrevious("NonexistentUpgrade") == nil, "GetPrevious on unknown should return nil")
end)

--// 2. GrowthFormula Additive Growth Tests \\--
check("GrowthFormula calculates additive growth with ZoneMultiplier and Multipliers", function()
	local GrowthFormula = loadGrowthFormula()
	local Player = fakePlayer(7001)
	local Session = fakeSession(Player)

	-- Base test without upgrade: BaseGain = 10, Zone = 1, Mult = 1 -> 10
	local Gain0 = GrowthFormula.Calculate(Session, { BaseGain = 10, ZoneMultiplier = 1 })
	assert(Gain0 == 10, string.format("Expected 10, got %s", tostring(Gain0)))

	-- Equipped Protein (+5): (10 + 5) * 1 * 1 = 15
	Session.EquippedGrowthUpgrade = "Protein"
	local Gain1 = GrowthFormula.Calculate(Session, { BaseGain = 10, ZoneMultiplier = 1 })
	assert(Gain1 == 15, string.format("Expected 15, got %s", tostring(Gain1)))

	-- Equipped Silver Protein (+20) with DoubleMultiplier (Mult = 2): (10 + 20) * 1 * 2 = 60
	Session.EquippedGrowthUpgrade = "Silver Protein"
	Session.HasDoubleMultiplier = true
	local Gain2 = GrowthFormula.Calculate(Session, { BaseGain = 10, ZoneMultiplier = 1 })
	assert(Gain2 == 60, string.format("Expected 60, got %s", tostring(Gain2)))

	-- Equipped Emerald Protein (+650), ZoneMultiplier = 3, Rebirth = 2 (Mult = 2 * 3 = 6 with DoubleMultiplier and Rebirth + 1): (5 + 650) * 3 * 6 = 11790
	Session.EquippedGrowthUpgrade = "Emerald Protein"
	Session.Rebirth = 2
	local Gain3 = GrowthFormula.Calculate(Session, { BaseGain = 5, ZoneMultiplier = 3 })
	assert(Gain3 == 11790, string.format("Expected 11790, got %s", tostring(Gain3)))

	-- Unknown equipped upgrade: defaults additive to 0
	Session.EquippedGrowthUpgrade = "InvalidUpgrade"
	Session.HasDoubleMultiplier = false
	Session.Rebirth = 0
	local Gain4 = GrowthFormula.Calculate(Session, { BaseGain = 10, ZoneMultiplier = 1 })
	assert(Gain4 == 10, string.format("Expected 10, got %s", tostring(Gain4)))
end)

--// 3. DestructionService DeductDestruction Tests \\--
check("DestructionService:DeductDestruction validates integers, safe mutation, and sync", function()
	local DestructionService = loadDestructionService()
	local Player = fakePlayer(7002)
	local Session = fakeSession(Player)
	Sessions.Set(Player, Session)

	-- DeductDestruction is deprecated per GAME.md and returns false
	local Ok = DestructionService:DeductDestruction(Player, 40)
	assert(Ok == false, "DeductDestruction should return false when deprecated")
	assert(Session.Destruction == 0, "Destruction should remain unchanged")

	Sessions.Remove(Player)
end)

--// 4. UpgradeService Buy & Equip Tests \\--
check(
	"UpgradeService: RequestBuyUpgrade validates cost, locks, sequential order, auto-equips, deducts Destruction",
	function()
		local DestructionService = loadDestructionService()
		local UpgradeService, EventBus, Remotes = loadUpgradeService(DestructionService)
		local Player = fakePlayer(7003)
		local Session = fakeSession(Player)
		Sessions.Set(Player, Session)

		-- 1. Attempt to buy with 0 Destruction (Protein requires 1) -> fails
		Session.Destruction = 0
		local BuyNoFunds = UpgradeService:RequestBuyUpgrade(Player, "Protein")
		assert(BuyNoFunds == false, "Buy without enough Destruction should fail")
		assert(Session.UnlockedGrowthUpgrades["Protein"] == nil, "Protein should not be unlocked")

		-- 2. Attempt to buy Silver Protein (Order 2) without unlocking Order 1 -> fails
		Session.Destruction = 10000
		local BuySkipped = UpgradeService:RequestBuyUpgrade(Player, "Silver Protein")
		assert(BuySkipped == false, "Buying out of order should fail")

		-- 3. Buy Order 1 (Protein, Requirement: 1) with 100 Destruction -> succeeds without deduction
		Session.Destruction = 100
		Player:SetAttribute("Destruction", 100)
		Player.DestructionStat.Value = 100

		local BuyProtein = UpgradeService:RequestBuyUpgrade(Player, "Protein")
		assert(BuyProtein == true, "Buying Protein with 100 Destruction should succeed")
		assert(Session.Destruction == 100, string.format("Destruction should remain 100, got %d", Session.Destruction))
		assert(Session.UnlockedGrowthUpgrades["Protein"] == true, "Protein should be in UnlockedGrowthUpgrades")
		assert(Session.EquippedGrowthUpgrade == "Protein", "Protein should be auto-equipped")

		-- 4. Re-buying already unlocked upgrade -> fails
		local RebuyProtein = UpgradeService:RequestBuyUpgrade(Player, "Protein")
		assert(RebuyProtein == false, "Re-buying already unlocked upgrade should fail")
		assert(Session.Destruction == 100, "Destruction should not be deducted on failed re-buy")

		-- 5. Buy Order 2 (Silver Protein, Requirement: 5) -> succeeds without deduction
		Session.Destruction = 600
		Player:SetAttribute("Destruction", 600)
		Player.DestructionStat.Value = 600

		local BuySilver = UpgradeService:RequestBuyUpgrade(Player, "Silver Protein")
		assert(BuySilver == true, "Buying Silver Protein should succeed")
		assert(Session.Destruction == 600, string.format("Destruction should remain 600, got %d", Session.Destruction))
		assert(
			Session.UnlockedGrowthUpgrades["Silver_Protein"] == true
				or Session.UnlockedGrowthUpgrades["Silver Protein"] == true,
			"Silver Protein should be unlocked"
		)
		local Equipped = Session.EquippedGrowthUpgrade
		assert(Equipped == "Silver Protein" or Equipped == "Silver_Protein", "Silver Protein should be auto-equipped")

		Sessions.Remove(Player)
	end
)

check("UpgradeService: RequestEquipUpgrade validates ownership and updates equipped state", function()
	local DestructionService = loadDestructionService()
	local UpgradeService, EventBus, Remotes = loadUpgradeService(DestructionService)
	local Player = fakePlayer(7004)
	local Session = fakeSession(Player)
	Sessions.Set(Player, Session)

	-- Unlock Protein and Silver Protein
	Session.UnlockedGrowthUpgrades["Protein"] = true
	Session.UnlockedGrowthUpgrades["Silver_Protein"] = true
	Session.UnlockedGrowthUpgrades["Silver Protein"] = true
	Session.EquippedGrowthUpgrade = "Silver_Protein"

	-- Try equipping locked Gold Protein -> fails
	local EquipLocked = UpgradeService:RequestEquipUpgrade(Player, "Gold Protein")
	assert(EquipLocked == false, "Equipping locked upgrade should fail")
	assert(Session.EquippedGrowthUpgrade == "Silver_Protein", "Equipped upgrade should remain unchanged")

	-- Equip unlocked Protein -> succeeds
	local EquipProtein = UpgradeService:RequestEquipUpgrade(Player, "Protein")
	assert(EquipProtein == true, "Equipping unlocked Protein should succeed")
	assert(Session.EquippedGrowthUpgrade == "Protein", "Equipped upgrade should be Protein")

	-- Re-equip Silver Protein -> succeeds
	local EquipSilver = UpgradeService:RequestEquipUpgrade(Player, "Silver Protein")
	assert(EquipSilver == true, "Equipping unlocked Silver Protein should succeed")
	local Eq = Session.EquippedGrowthUpgrade
	assert(Eq == "Silver Protein" or Eq == "Silver_Protein", "Equipped upgrade should be Silver Protein")

	-- Invalid player session -> fails
	Sessions.Remove(Player)
	assert(UpgradeService:RequestEquipUpgrade(Player, "Protein") == false, "Missing session should fail")
end)

check("UpgradeService: GetUpgradeStatus returns complete status payload", function()
	local DestructionService = loadDestructionService()
	local UpgradeService, EventBus, Remotes = loadUpgradeService(DestructionService)
	local Player = fakePlayer(7005)
	local Session = fakeSession(Player)
	Session.Destruction = 1000
	Session.UnlockedGrowthUpgrades["Protein"] = true
	Session.EquippedGrowthUpgrade = "Protein"
	Sessions.Set(Player, Session)

	local Status = UpgradeService:GetUpgradeStatus(Player)
	assert(Status ~= nil, "GetUpgradeStatus should return a status table")
	assert(Status.EquippedUpgrade == "Protein", "Status.EquippedUpgrade mismatch")
	assert(type(Status.List) == "table", "Status.List must be a table")
	assert(#Status.List == 15, "Status.List should contain 15 upgrades")

	-- Check first upgrade (Protein: unlocked, equipped, cannot buy)
	local First = Status.List[1]
	assert(First.Name == "Protein" and First.IsUnlocked == true and First.IsEquipped == true and First.CanBuy == false)

	-- Check second upgrade (Silver Protein: locked, previous unlocked, cost 500 <= 1000 destruction -> CanBuy == true)
	local Second = Status.List[2]
	assert(Second.Name == "Silver Protein" and Second.IsUnlocked == false and Second.CanBuy == true)

	-- Check third upgrade (Gold Protein: locked, previous NOT unlocked -> CanBuy == false)
	local Third = Status.List[3]
	assert(Third.Name == "Gold Protein" and Third.IsUnlocked == false and Third.CanBuy == false)

	Sessions.Remove(Player)
end)

if #Failures > 0 then
	print("\n--- TEST FAILURES ---")
	for _, Failure in ipairs(Failures) do
		print("  FAIL: " .. Failure)
	end
	error(string.format("%d tests failed", #Failures))
else
	print("\n=== ALL MVP-006 TASK 3 UNIT TESTS PASSED ===")
end
