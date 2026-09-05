local fs = require("@lune/fs")
local luau = require("@lune/luau")
local task = require("@lune/task")

local Sessions = require("../../src/server/Core/Registry/RuntimeRegistry/Sessions")
local AFKZones = require("../../src/server/Game/Config/AFKZones")

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

local function fakePlayer(UserId: number)
	local Player = {
		UserId = UserId,
		Name = "TestPlayer_" .. tostring(UserId),
		Attributes = {},
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
		CurrentAFKZone = nil,
		PremiumZonePromptedThisEntry = false,
		GamePassQueryGenerations = { Vip = 0, PremiumZone = 0, AutoWins = 0 },
	}
end

local function loadAFKZoneSystem(Options: {
	FolderName: string?,
	Zones: { [string]: { Size: { X: number, Y: number, Z: number }, Position: { X: number, Y: number, Z: number } } }?,
	AFKConfig: any?,
}?)
	Options = Options or {}
	local FolderName = Options.FolderName or "CheeseDiningTables"
	local Config = Options.AFKConfig or AFKZones

	local PlayersList = {}
	local Players = {
		GetPlayers = function()
			return PlayersList
		end,
	}

	local ZoneParts = {}
	for ZoneName, ZoneData in Options.Zones or {} do
		local Part = {
			Name = ZoneName,
			Size = setmetatable(ZoneData.Size, {
				__div = function(_, Divisor)
					return {
						X = ZoneData.Size.X / Divisor,
						Y = ZoneData.Size.Y / Divisor,
						Z = ZoneData.Size.Z / Divisor,
					}
				end,
			}),
			CFrame = {
				PointToObjectSpace = function(_, WorldPos)
					return {
						X = WorldPos.X - ZoneData.Position.X,
						Y = WorldPos.Y - ZoneData.Position.Y,
						Z = WorldPos.Z - ZoneData.Position.Z,
					}
				end,
			},
		}
		function Part:IsA(ClassName: string)
			return ClassName == "BasePart"
		end
		ZoneParts[ZoneName] = Part
	end

	local TableFolder = {
		FindFirstChild = function(_, Name: string)
			return ZoneParts[Name]
		end,
	}

	local Workspace = {
		FindFirstChild = function(_, Name: string)
			if Name == FolderName then
				return TableFolder
			end
			return nil
		end,
	}

	local GrowthService = { Calls = {} }
	function GrowthService:AddBigger(TargetPlayer, Context)
		table.insert(self.Calls, { TargetPlayer = TargetPlayer, Context = Context })
	end

	local GamePassService = {
		PromptCalls = {},
		IsOwned = function(self, TargetPlayer, PassKey)
			local Session = Sessions.Get(TargetPlayer)
			if not Session then
				return false
			end
			if PassKey == "Vip" then
				return Session.HasVip == true
			elseif PassKey == "PremiumZone" then
				return Session.HasPremiumZonePass == true
			end
			return false
		end,
		Prompt = function(self, TargetPlayer, PassKey)
			table.insert(self.PromptCalls, { Player = TargetPlayer, PassKey = PassKey })
			return true
		end,
	}

	local ServiceRegistry = {
		Get = function(Name: string)
			if Name == "GrowthService" then
				return GrowthService
			elseif Name == "GamePassService" then
				return GamePassService
			end
			error("unknown service " .. Name)
		end,
	}

	local Scheduler = { Jobs = {} }
	function Scheduler.AddJob(JobConfig)
		Scheduler.Jobs[JobConfig.Name] = JobConfig
	end

	local GrowthSource = { AFKZone = "AFKZone" }
	local ReplicatedStorage = childContainer({
		BiggerShared = childContainer({
			Core = childContainer({ Enums = childContainer({ GrowthSource = GrowthSource }) }),
		}),
	})

	local Game = {
		GetService = function(_, Name: string)
			if Name == "Players" then
				return Players
			elseif Name == "Workspace" then
				return Workspace
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

	local SystemsFolder = {
		Parent = {
			Config = { AFKZones = Config },
			Parent = {
				Core = {
					Registry = {
						RuntimeRegistry = { Sessions = Sessions },
						ServiceRegistry = ServiceRegistry,
					},
					Scheduler = { Scheduler = Scheduler },
					Utilities = { Logger = Logger },
				},
			},
		},
	}

	local System = loadModule("src/server/Game/Systems/AFKZoneSystem.luau", "AFKZoneSystem", {
		game = Game,
		script = { Parent = SystemsFolder },
		require = function(Dependency)
			return Dependency
		end,
	})

	System.Start()

	return {
		System = System,
		Process = assert(Scheduler.Jobs.AFKZoneCheck).Callback,
		GrowthService = GrowthService,
		GamePassService = GamePassService,
		PlayersList = PlayersList,
		ZoneParts = ZoneParts,
	}
end

print("=== Running MVP-006 Task 4 Unit Tests ===")

--// 1. Config Definition Tests \\--
check(
	"AFKZones config defines 5 public dining tables (50x-250x) and 2 VIP tables (300x, 400x) + backward compatibility",
	function()
		assert(AFKZones ~= nil, "AFKZones module must exist")

		local ExpectedPublicTables = {
			{ Name = "Table1", Multiplier = 50, MinRebirth = 0 },
			{ Name = "Table2", Multiplier = 100, MinRebirth = 5 },
			{ Name = "Table3", Multiplier = 150, MinRebirth = 10 },
			{ Name = "Table4", Multiplier = 200, MinRebirth = 15 },
			{ Name = "Table5", Multiplier = 250, MinRebirth = 20 },
		}

		for _, Expected in ipairs(ExpectedPublicTables) do
			local Config = (AFKZones :: any)[Expected.Name]
			assert(Config ~= nil, "Missing config for " .. Expected.Name)
			assert(
				Config.ZoneMultiplier == Expected.Multiplier,
				string.format(
					"%s multiplier mismatch: expected %d, got %s",
					Expected.Name,
					Expected.Multiplier,
					tostring(Config.ZoneMultiplier)
				)
			)
			assert(
				Config.MinRebirth == Expected.MinRebirth,
				string.format(
					"%s MinRebirth mismatch: expected %d, got %s",
					Expected.Name,
					Expected.MinRebirth,
					tostring(Config.MinRebirth)
				)
			)
			assert(Config.BaseGain == 1, Expected.Name .. " BaseGain must be 1")
			assert(Config.TickRate == 1, Expected.Name .. " TickRate must be 1")
			assert(Config.PassKey == nil, Expected.Name .. " PassKey must be nil")
		end

		local ExpectedVipTables = {
			{ Name = "VipTable1", Multiplier = 300, MinRebirth = 0, PassKey = "Vip" },
			{ Name = "VipTable2", Multiplier = 400, MinRebirth = 0, PassKey = "Vip" },
		}

		for _, Expected in ipairs(ExpectedVipTables) do
			local Config = (AFKZones :: any)[Expected.Name]
			assert(Config ~= nil, "Missing config for " .. Expected.Name)
			assert(
				Config.ZoneMultiplier == Expected.Multiplier,
				string.format(
					"%s multiplier mismatch: expected %d, got %s",
					Expected.Name,
					Expected.Multiplier,
					tostring(Config.ZoneMultiplier)
				)
			)
			assert(
				Config.MinRebirth == Expected.MinRebirth,
				string.format(
					"%s MinRebirth mismatch: expected %d, got %s",
					Expected.Name,
					Expected.MinRebirth,
					tostring(Config.MinRebirth)
				)
			)
			assert(
				Config.PassKey == Expected.PassKey,
				string.format(
					"%s PassKey mismatch: expected %s, got %s",
					Expected.Name,
					Expected.PassKey,
					tostring(Config.PassKey)
				)
			)
			assert(Config.BaseGain == 1, Expected.Name .. " BaseGain must be 1")
			assert(Config.TickRate == 1, Expected.Name .. " TickRate must be 1")
		end

		-- Backward compatibility aliases
		assert(AFKZones.AFKZone1 == AFKZones.Table1, "AFKZone1 must map to Table1")
		assert(AFKZones.AFKZone2 == AFKZones.Table2, "AFKZone2 must map to Table2")
		assert(AFKZones.AFKZone3 == AFKZones.Table3, "AFKZone3 must map to Table3")
		assert(AFKZones.AFKZone4 == AFKZones.Table4, "AFKZone4 must map to Table4")
		assert(AFKZones.AFKZone5 == AFKZones.Table5, "AFKZone5 must map to Table5")
		assert(AFKZones.AFKZone6 == AFKZones.VipTable1, "AFKZone6 must map to VipTable1")
		assert(AFKZones.AFKZone7 == AFKZones.VipTable2, "AFKZone7 must map to VipTable2")
	end
)

--// 2. Rebirth Gating Tests \\--
check("Rebirth gating: player with Rebirth < MinRebirth does not receive multiplier", function()
	local DefaultZones = {
		Table1 = { Size = { X = 10, Y = 10, Z = 10 }, Position = { X = 0, Y = 0, Z = 0 } },
		Table3 = { Size = { X = 10, Y = 10, Z = 10 }, Position = { X = 50, Y = 0, Z = 0 } },
		Table5 = { Size = { X = 10, Y = 10, Z = 10 }, Position = { X = 100, Y = 0, Z = 0 } },
	}
	local Harness = loadAFKZoneSystem({ Zones = DefaultZones })
	local Player = fakePlayer(8001)
	local Session = fakeSession(Player)
	Sessions.Set(Player, Session)
	table.insert(Harness.PlayersList, Player)

	local RootPart = {
		Position = { X = 50, Y = 0, Z = 0 }, -- inside Table3 (MinRebirth = 10, 150x)
	}
	function RootPart:IsA(ClassName: string)
		return ClassName == "BasePart"
	end
	Player.Character = {
		FindFirstChild = function(_, Name: string)
			return if Name == "HumanoidRootPart" then RootPart else nil
		end,
	}

	-- Player has Rebirth = 0 (< 10 required for Table3)
	Session.Rebirth = 0
	Harness.Process()
	assert(#Harness.GrowthService.Calls == 0, "Player with Rebirth 0 should NOT receive Table3 payout")

	-- Player has Rebirth = 9 (< 10 required for Table3)
	Session.Rebirth = 9
	Harness.Process()
	assert(#Harness.GrowthService.Calls == 0, "Player with Rebirth 9 should NOT receive Table3 payout")

	-- Player has Rebirth = 10 (meets requirement)
	Session.Rebirth = 10
	Harness.Process()
	assert(#Harness.GrowthService.Calls == 1, "Player with Rebirth 10 SHOULD receive Table3 payout")
	local Call = Harness.GrowthService.Calls[1]
	assert(Call.TargetPlayer == Player, "Call target player mismatch")
	assert(
		Call.Context.ZoneMultiplier == 150,
		string.format("Expected 150x, got %s", tostring(Call.Context.ZoneMultiplier))
	)
	assert(
		Call.Context.SourceId == "Table3",
		string.format("Expected SourceId Table3, got %s", tostring(Call.Context.SourceId))
	)

	-- Move player to Table5 (MinRebirth = 20, 250x) with Rebirth = 10 -> fails
	RootPart.Position = { X = 100, Y = 0, Z = 0 }
	Harness.Process()
	assert(#Harness.GrowthService.Calls == 1, "Player with Rebirth 10 should NOT receive Table5 payout")

	-- Player reaches Rebirth = 20 -> receives Table5 payout (250x)
	Session.Rebirth = 20
	Harness.Process()
	assert(#Harness.GrowthService.Calls == 2, "Player with Rebirth 20 SHOULD receive Table5 payout")
	local Call2 = Harness.GrowthService.Calls[2]
	assert(
		Call2.Context.ZoneMultiplier == 250,
		string.format("Expected 250x, got %s", tostring(Call2.Context.ZoneMultiplier))
	)
	assert(
		Call2.Context.SourceId == "Table5",
		string.format("Expected SourceId Table5, got %s", tostring(Call2.Context.SourceId))
	)

	Sessions.Remove(Player)
end)

--// 3. VIP Gating Tests \\--
check("VIP gating: player without VIP pass in VIP table gets prompted once and does not receive multiplier", function()
	local DefaultZones = {
		VipTable1 = { Size = { X = 10, Y = 10, Z = 10 }, Position = { X = 0, Y = 0, Z = 0 } },
		VipTable2 = { Size = { X = 10, Y = 10, Z = 10 }, Position = { X = 50, Y = 0, Z = 0 } },
		Table1 = { Size = { X = 10, Y = 10, Z = 10 }, Position = { X = 100, Y = 0, Z = 0 } },
	}
	local Harness = loadAFKZoneSystem({ Zones = DefaultZones })
	local Player = fakePlayer(8002)
	local Session = fakeSession(Player)
	Sessions.Set(Player, Session)
	table.insert(Harness.PlayersList, Player)

	local RootPart = {
		Position = { X = 0, Y = 0, Z = 0 }, -- inside VipTable1 (300x, PassKey = "Vip")
	}
	function RootPart:IsA(ClassName: string)
		return ClassName == "BasePart"
	end
	Player.Character = {
		FindFirstChild = function(_, Name: string)
			return if Name == "HumanoidRootPart" then RootPart else nil
		end,
	}

	-- 1. Unowned VIP: First tick prompts and gives no reward
	Session.HasVip = false
	Harness.Process()
	assert(#Harness.GrowthService.Calls == 0, "Unowned VIP should not receive growth")
	assert(#Harness.GamePassService.PromptCalls == 1, "Unowned VIP should trigger purchase prompt")
	assert(Harness.GamePassService.PromptCalls[1].PassKey == "Vip", "Prompted pass key should be Vip")

	-- 2. Second tick: should NOT re-prompt while staying in VIP table
	Harness.Process()
	assert(#Harness.GrowthService.Calls == 0, "Unowned VIP still should not receive growth")
	assert(#Harness.GamePassService.PromptCalls == 1, "Should not re-prompt on subsequent ticks in same entry")

	-- 3. Walk out to Table1 (public, no pass), then walk back to VipTable1
	RootPart.Position = { X = 100, Y = 0, Z = 0 } -- Table1
	Harness.Process()
	assert(#Harness.GrowthService.Calls == 1, "Table1 should give public growth")
	assert(Harness.GrowthService.Calls[1].Context.ZoneMultiplier == 50)

	RootPart.Position = { X = 0, Y = 0, Z = 0 } -- Re-enter VipTable1
	Harness.Process()
	assert(#Harness.GrowthService.Calls == 1, "Re-entering VipTable1 without pass gives no growth")
	assert(#Harness.GamePassService.PromptCalls == 2, "Re-entering VipTable1 should prompt again")

	-- 4. Player purchases VIP pass -> receives 300x growth
	Session.HasVip = true
	Harness.Process()
	assert(#Harness.GrowthService.Calls == 2, "Owned VIP should receive growth")
	local VipCall = Harness.GrowthService.Calls[2]
	assert(
		VipCall.Context.ZoneMultiplier == 300,
		string.format("Expected 300x, got %s", tostring(VipCall.Context.ZoneMultiplier))
	)
	assert(VipCall.Context.SourceId == "VipTable1")

	-- 5. Move to VipTable2 (400x)
	RootPart.Position = { X = 50, Y = 0, Z = 0 }
	Harness.Process()
	assert(#Harness.GrowthService.Calls == 3, "VipTable2 should give 400x growth")
	local Vip2Call = Harness.GrowthService.Calls[3]
	assert(
		Vip2Call.Context.ZoneMultiplier == 400,
		string.format("Expected 400x, got %s", tostring(Vip2Call.Context.ZoneMultiplier))
	)
	assert(Vip2Call.Context.SourceId == "VipTable2")

	Sessions.Remove(Player)
end)

--// 4. Height Scaling Invariant Tests \\--
check(
	"Height scaling invariant: player with large Y height is still detected inside zone if X/Z bounds and Y >= floor match",
	function()
		local DefaultZones = {
			Table1 = { Size = { X = 20, Y = 10, Z = 20 }, Position = { X = 0, Y = 5, Z = 0 } },
		}
		local Harness = loadAFKZoneSystem({ Zones = DefaultZones })
		local Player = fakePlayer(8003)
		local Session = fakeSession(Player)
		Sessions.Set(Player, Session)
		table.insert(Harness.PlayersList, Player)

		local RootPart = {
			Position = { X = 0, Y = 5, Z = 0 }, -- center of zone
		}
		function RootPart:IsA(ClassName: string)
			return ClassName == "BasePart"
		end
		Player.Character = {
			FindFirstChild = function(_, Name: string)
				return if Name == "HumanoidRootPart" then RootPart else nil
			end,
		}

		-- Standard size player inside zone
		Harness.Process()
		assert(#Harness.GrowthService.Calls == 1, "Standard player should be detected")

		-- Giant player scaled up (HumanoidRootPart Y = 500 above table floor)
		RootPart.Position = { X = 0, Y = 500, Z = 0 }
		Harness.Process()
		assert(
			#Harness.GrowthService.Calls == 2,
			"Giant scaled player with large Y height MUST be detected inside zone"
		)

		-- Player near edge of X/Z bounds at high Y
		RootPart.Position = { X = 9, Y = 250, Z = -9 }
		Harness.Process()
		assert(#Harness.GrowthService.Calls == 3, "Giant player within X/Z bounds MUST be detected")

		-- Player outside X/Z bounds (even at high Y) -> not detected
		RootPart.Position = { X = 15, Y = 250, Z = 0 }
		Harness.Process()
		assert(#Harness.GrowthService.Calls == 3, "Player outside X/Z bounds should NOT be detected")

		-- Player way below the floor (Y = -50) -> not detected
		RootPart.Position = { X = 0, Y = -50, Z = 0 }
		Harness.Process()
		assert(#Harness.GrowthService.Calls == 3, "Player below floor should NOT be detected")

		Sessions.Remove(Player)
	end
)

--// 5. Folder Discovery & Priority Tests \\--
check("Workspace folder discovery supports both CheeseDiningTables and legacy AFKZones", function()
	-- Test CheeseDiningTables folder
	local Harness1 = loadAFKZoneSystem({
		FolderName = "CheeseDiningTables",
		Zones = { Table1 = { Size = { X = 10, Y = 10, Z = 10 }, Position = { X = 0, Y = 0, Z = 0 } } },
	})
	local Player1 = fakePlayer(8004)
	local Session1 = fakeSession(Player1)
	Sessions.Set(Player1, Session1)
	table.insert(Harness1.PlayersList, Player1)
	Player1.Character = {
		FindFirstChild = function(_, Name: string)
			return if Name == "HumanoidRootPart"
				then {
					Position = { X = 0, Y = 0, Z = 0 },
					IsA = function(_, C)
						return C == "BasePart"
					end,
				}
				else nil
		end,
	}
	Harness1.Process()
	assert(#Harness1.GrowthService.Calls == 1, "CheeseDiningTables folder should be discovered")
	Sessions.Remove(Player1)

	-- Test legacy AFKZones folder
	local Harness2 = loadAFKZoneSystem({
		FolderName = "AFKZones",
		Zones = { AFKZone1 = { Size = { X = 10, Y = 10, Z = 10 }, Position = { X = 0, Y = 0, Z = 0 } } },
	})
	local Player2 = fakePlayer(8005)
	local Session2 = fakeSession(Player2)
	Sessions.Set(Player2, Session2)
	table.insert(Harness2.PlayersList, Player2)
	Player2.Character = {
		FindFirstChild = function(_, Name: string)
			return if Name == "HumanoidRootPart"
				then {
					Position = { X = 0, Y = 0, Z = 0 },
					IsA = function(_, C)
						return C == "BasePart"
					end,
				}
				else nil
		end,
	}
	Harness2.Process()
	assert(#Harness2.GrowthService.Calls == 1, "AFKZones folder should be discovered for backward compatibility")
	Sessions.Remove(Player2)
end)

if #Failures > 0 then
	print("\n--- TEST FAILURES ---")
	for _, Failure in ipairs(Failures) do
		print("  FAIL: " .. Failure)
	end
	error(string.format("%d tests failed", #Failures))
else
	print("\n=== ALL MVP-006 TASK 4 UNIT TESTS PASSED ===")
end
