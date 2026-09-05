local fs = require("@lune/fs")
local luau = require("@lune/luau")
local task = require("@lune/task")

local Sessions = require("../../src/server/Core/Registry/RuntimeRegistry/Sessions")
local ServiceRegistry = require("../../src/server/Core/Registry/ServiceRegistry")
local RewardType = require("../../src/shared/Core/Enums/RewardType")

local Failures = {}

local function check(Name: string, Callback: () -> ())
	local Success, Message = pcall(Callback)
	if not Success then
		table.insert(Failures, string.format("%s: %s", Name, tostring(Message)))
		print(string.format("  FAIL: %s - %s", Name, tostring(Message)))
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

local function createMockEventBus()
	local Subscribers = {}
	return {
		Subscribe = function(Name: string, Callback: (...any) -> ())
			Subscribers[Name] = Subscribers[Name] or {}
			table.insert(Subscribers[Name], Callback)
		end,
		Publish = function(Name: string, ...: any)
			for _, Callback in Subscribers[Name] or {} do
				Callback(...)
			end
		end,
	}
end

local function createMockRewardDispatcher()
	return {
		Dispatch = function(Player: any, Rewards: { any })
			for _, Reward in Rewards do
				if Reward.Type == "Bigger" or Reward.Type == RewardType.Bigger then
					Sessions.Mutate(Player, function(S)
						S.Bigger += (Reward.Amount or 0)
					end)
				elseif Reward.Type == "Destruction" or Reward.Type == RewardType.Destruction then
					Sessions.Mutate(Player, function(S)
						S.Destruction += (Reward.Amount or 0)
					end)
				elseif Reward.Type == "SpinTokens" or Reward.Type == RewardType.SpinTokens then
					Sessions.Mutate(Player, function(S)
						S.SpinTokens += (Reward.Amount or 0)
					end)
				elseif Reward.Type == "Trail" or Reward.Type == RewardType.Trail then
					local Id = Reward.Id or Reward.ContentId
					Sessions.Mutate(Player, function(S)
						S.UnlockedTrails[Id] = true
					end)
				elseif Reward.Type == "Title" or Reward.Type == RewardType.Title then
					local Id = Reward.Id or Reward.ContentId
					Sessions.Mutate(Player, function(S)
						S.UnlockedTitles[Id] = true
					end)
				end
			end
			return { Success = true }
		end,
	}
end

local function fakeRemoteEvent(Name: string)
	local Remote = {
		Name = Name,
		ClassName = "RemoteEvent",
		OnServerEvent = fakeSignal(),
		OnClientEvent = fakeSignal(),
		FiredClientEvents = {},
		FiredServerEvents = {},
	}
	function Remote:IsA(ClassName: string)
		return ClassName == "RemoteEvent" or ClassName == "Instance"
	end
	function Remote:FireServer(...)
		table.insert(self.FiredServerEvents, { ... })
		self.OnServerEvent:Fire(nil, ...)
	end
	function Remote:FireClient(Player: any, ...)
		table.insert(self.FiredClientEvents, { Player = Player, Args = { ... } })
		self.OnClientEvent:Fire(...)
	end
	function Remote:FireAllClients(...)
		table.insert(self.FiredClientEvents, { Player = "All", Args = { ... } })
		self.OnClientEvent:Fire(...)
	end
	return Remote
end

local function fakeRemoteFunction(Name: string)
	local Remote = {
		Name = Name,
		ClassName = "RemoteFunction",
		OnServerInvoke = nil,
		OnClientInvoke = nil,
	}
	function Remote:IsA(ClassName: string)
		return ClassName == "RemoteFunction" or ClassName == "Instance"
	end
	function Remote:InvokeServer(...)
		if self.OnServerInvoke then
			return self.OnServerInvoke(nil, ...)
		end
		return nil
	end
	function Remote:InvokeClient(Player: any, ...)
		if self.OnClientInvoke then
			return self.OnClientInvoke(...)
		end
		return nil
	end
	return Remote
end

local function fakeFolder(Name: string, ChildrenDict: { [string]: any }?)
	local Folder = {
		Name = Name,
		ClassName = "Folder",
		Children = {},
	}
	if ChildrenDict then
		for ChildName, Child in ChildrenDict do
			if type(Child) == "table" then
				pcall(function()
					Child.Parent = Folder
				end)
				table.insert(Folder.Children, Child)
				Folder[ChildName] = Child
			end
		end
	end
	function Folder:IsA(ClassName: string)
		return ClassName == "Folder" or ClassName == "Instance"
	end
	function Folder:FindFirstChild(ChildName: string)
		for _, Child in self.Children do
			if Child.Name == ChildName then
				return Child
			end
		end
		return self[ChildName]
	end
	function Folder:WaitForChild(ChildName: string, _Timeout: number?)
		local Found = self:FindFirstChild(ChildName)
		if Found then
			return Found
		end
		return self[ChildName]
	end
	function Folder:GetChildren()
		local List = {}
		for _, v in self.Children do
			table.insert(List, v)
		end
		return List
	end
	return Folder
end

local function fakePlayer(UserId: number)
	local AttributeSignals: { [string]: any } = {}
	local Player = {
		UserId = UserId,
		Name = "TestPlayer_" .. tostring(UserId),
		Attributes = {},
	}
	function Player:IsA(ClassName: string)
		return ClassName == "Player" or ClassName == "Instance"
	end
	function Player:SetAttribute(Key: string, Value: any)
		local Old = self.Attributes[Key]
		self.Attributes[Key] = Value
		if Old ~= Value and AttributeSignals[Key] then
			AttributeSignals[Key]:Fire(Value)
		end
	end
	function Player:GetAttribute(Key: string)
		return self.Attributes[Key]
	end
	function Player:GetAttributeChangedSignal(Key: string)
		if not AttributeSignals[Key] then
			AttributeSignals[Key] = fakeSignal()
		end
		return AttributeSignals[Key]
	end
	function Player:FindFirstChild(Name: string)
		return self[Name]
	end
	function Player:WaitForChild(Name: string, _Timeout: number?)
		return self[Name]
	end
	return Player
end

local function createMockSession(Player: any, Overrides: { [string]: any }?)
	local Session = {
		Player = Player,
		Bigger = 100,
		Destruction = 0,
		Rebirth = 0,
		UnlockedGrowthUpgrades = {},
		EquippedGrowthUpgrade = nil,
		CompletedPortals = {},
		Settings = {
			SoundEnabled = true,
			MusicEnabled = true,
		},
		State = "InLobby",
		JoinedAt = os.time(),
		PurchaseHistory = {},
		CurrentWorldInstanceId = nil,
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
		AutoWinsEnabled = false,
		GrowthRemainder = 0,
		CurrentAFKZone = nil,
		PremiumZonePromptedThisEntry = false,
		GamePassQueryGenerations = { Vip = 0, PremiumZone = 0 },
		LastActiveTimestamp = os.time(),
		LastLogoutTimestamp = 0,
		LastSaveTimestamp = os.time(),
		ProfileMutationsFrozen = false,
		ProfileMutationFreezeReason = nil,
	}
	if Overrides then
		for K, V in Overrides do
			Session[K] = V
		end
	end
	return Session
end

local function loadRewardDispatcher(MockServiceRegistry, MockSessions)
	local RewardError = {
		PersistenceFailed = "PersistenceFailed",
		DuplicateTransaction = "DuplicateTransaction",
		InvalidPayload = "InvalidPayload",
		DispatcherFailed = "DispatcherFailed",
		UnknownReward = "UnknownReward",
	}

	local RewardTypeEnum = {
		Bigger = "Bigger",
		Destruction = "Destruction",
		Coins = "Coins",
		Aura = "Aura",
		Boost = "Boost",
		Item = "Item",
		DoubleMultiplier = "DoubleMultiplier",
		Vip = "Vip",
		SkipRebirth = "SkipRebirth",
		SpinTokens = "SpinTokens",
		Trail = "Trail",
		Title = "Title",
	}

	local BiggerShared = fakeFolder("BiggerShared", {
		Core = fakeFolder("Core", {
			Enums = fakeFolder("Enums", {
				RewardType = RewardTypeEnum,
				RewardError = RewardError,
			}),
		}),
	})

	local UtilitiesFolder = {
		Parent = {
			Registry = {
				ServiceRegistry = MockServiceRegistry,
				RuntimeRegistry = { Sessions = MockSessions },
			},
		},
	}

	return loadModule("src/server/Core/Utilities/RewardDispatcher.luau", "RewardDispatcher", {
		game = {
			GetService = function(_self, Name: string)
				if Name == "ReplicatedStorage" then
					return fakeFolder("ReplicatedStorage", { BiggerShared = BiggerShared })
				end
				return nil
			end,
		},
		script = { Parent = UtilitiesFolder },
		require = function(dep)
			return dep
		end,
	})
end

print("=== Running MVP-006 Task 8 Unit Tests (Daily Rewards & Lucky Spins) ===")

-- TEST 1: DailyRewardConfig & SpinWheelConfig definitions
check("DailyRewardConfig & SpinWheelConfig definitions", function()
	local DailyRewardConfig = loadModule("src/server/Game/Config/DailyRewardConfig.luau", "DailyRewardConfig")
	local SpinWheelConfig = loadModule("src/server/Game/Config/SpinWheelConfig.luau", "SpinWheelConfig")

	assert(type(DailyRewardConfig) == "table", "DailyRewardConfig should be a table")
	assert(
		DailyRewardConfig.CooldownSeconds == 86400 or DailyRewardConfig.CooldownInterval == 86400,
		"Cooldown should be 86400 seconds (24 hours)"
	)
	assert(DailyRewardConfig.Days ~= nil or DailyRewardConfig.List ~= nil, "DailyRewardConfig should define days")

	for Day = 1, 7 do
		local DayConfig = DailyRewardConfig.GetDay and DailyRewardConfig.GetDay(Day)
			or (DailyRewardConfig.Days and DailyRewardConfig.Days[Day])
			or (DailyRewardConfig.List and DailyRewardConfig.List[Day])
		assert(DayConfig ~= nil, "Day " .. Day .. " config must exist")
		assert(DayConfig.Day == Day, "DayConfig.Day should match " .. Day)
		assert(type(DayConfig.Reward) == "table", "Day " .. Day .. " must define a Reward table")
		assert(type(DayConfig.Reward.Type) == "string", "Day " .. Day .. " reward must have a Type string")
	end

	-- DailyRewardConfig helpers
	local Now = 1000000
	assert(DailyRewardConfig.IsEligible(0, Now) == true, "Claim at 0 timestamp should be eligible")
	assert(DailyRewardConfig.IsEligible(Now - 86400, Now) == true, "Claim at 24h ago should be eligible")
	assert(DailyRewardConfig.IsEligible(Now - 3600, Now) == false, "Claim at 1h ago should NOT be eligible")
	assert(DailyRewardConfig.GetTimeUntilNext(Now - 3600, Now) == 82800, "Time until next should be 82800s")
	assert(DailyRewardConfig.GetTimeUntilNext(Now - 86400, Now) == 0, "Time until next should be 0 when eligible")

	-- SpinWheelConfig definitions
	assert(type(SpinWheelConfig) == "table", "SpinWheelConfig should be a table")
	assert(type(SpinWheelConfig.Sectors) == "table", "SpinWheelConfig.Sectors must be a table")
	assert(#SpinWheelConfig.Sectors == 8, "SpinWheelConfig must have exactly 8 sectors")

	local TotalWeight = 0
	for i = 1, 8 do
		local Sector = SpinWheelConfig.Sectors[i]
		assert(Sector.Index == i, "Sector index should be " .. i)
		assert(type(Sector.Name) == "string" and #Sector.Name > 0, "Sector " .. i .. " must have a Name")
		assert(type(Sector.Weight) == "number" and Sector.Weight > 0, "Sector " .. i .. " Weight must be > 0")
		assert(type(Sector.Reward) == "table", "Sector " .. i .. " must have a Reward table")
		assert(type(Sector.Reward.Type) == "string", "Sector " .. i .. " Reward must have a Type")
		TotalWeight += Sector.Weight
	end

	-- SpinWheelConfig.SelectRandom
	assert(type(SpinWheelConfig.SelectRandom) == "function", "SelectRandom helper must exist")
	local Chosen = SpinWheelConfig.SelectRandom()
	assert(type(Chosen) == "table" and Chosen.Index >= 1 and Chosen.Index <= 8, "SelectRandom returned valid sector")
end)

-- TEST 2: DailyRewardService - GetDailyStatus, Cooldown validation, ClaimDaily with Reward Dispatch & Day Wrap
check("DailyRewardService: GetDailyStatus and authoritative ClaimDaily", function()
	local DailyRewardConfig = loadModule("src/server/Game/Config/DailyRewardConfig.luau", "DailyRewardConfig")
	local SpinWheelConfig = loadModule("src/server/Game/Config/SpinWheelConfig.luau", "SpinWheelConfig")

	local RemotesFolder = fakeFolder("Remotes", {
		GetDailyStatus = fakeRemoteFunction("GetDailyStatus"),
		RequestClaimDaily = fakeRemoteEvent("RequestClaimDaily"),
		DailyStatusUpdated = fakeRemoteEvent("DailyStatusUpdated"),
	})
	local MockReplicatedStorage = fakeFolder("ReplicatedStorage", {
		Remotes = RemotesFolder,
	})

	local MockGrowthService = {
		AddBiggerAbsolute = function(_self, Player, Amount)
			Sessions.Mutate(Player, function(S)
				S.Bigger += Amount
			end)
			return true
		end,
	}
	local MockDestructionService = {
		GrantDestruction = function(_self, Player, Amount)
			Sessions.Mutate(Player, function(S)
				S.Destruction += Amount
			end)
			return true
		end,
	}

	pcall(ServiceRegistry.Register, "GrowthService", MockGrowthService)
	pcall(ServiceRegistry.Register, "DestructionService", MockDestructionService)

	local Logger = {
		Info = function(...) end,
		Warn = function(...) end,
		Error = function(...) end,
	}
	local EventBus = createMockEventBus()
	local RewardDispatcher = loadRewardDispatcher(ServiceRegistry, Sessions)

	local ServerServicesFolder = {
		Parent = {
			Config = {
				DailyRewardConfig = DailyRewardConfig,
				SpinWheelConfig = SpinWheelConfig,
			},
			Parent = {
				Core = {
					Registry = {
						RuntimeRegistry = { Sessions = Sessions },
						ServiceRegistry = ServiceRegistry,
					},
					Utilities = {
						Logger = Logger,
						RewardDispatcher = RewardDispatcher,
					},
					Events = {
						EventBus = EventBus,
					},
				},
			},
		},
	}

	local DailyRewardService = loadModule("src/server/Game/Services/DailyRewardService.luau", "DailyRewardService", {
		game = {
			GetService = function(_self, ServiceName: string)
				if ServiceName == "ReplicatedStorage" then
					return MockReplicatedStorage
				elseif ServiceName == "Players" then
					return {
						GetPlayers = function()
							return {}
						end,
					}
				end
				return nil
			end,
		},
		script = { Parent = ServerServicesFolder },
		require = function(Dependency)
			return Dependency
		end,
	})

	DailyRewardService:Init()

	local Player = fakePlayer(101)
	local Session = createMockSession(Player, {
		DailyRewardDay = 1,
		LastDailyClaimTimestamp = 0,
		Bigger = 500,
		Destruction = 10,
		SpinTokens = 0,
	})
	Sessions.Set(Player, Session)

	-- 1. GetDailyStatus on fresh player
	local Status = DailyRewardService:GetDailyStatus(Player)
	assert(Status ~= nil, "Status should not be nil")
	assert(Status.Day == 1, "Day should be 1")
	assert(Status.CanClaim == true, "CanClaim should be true for fresh player")
	assert(Status.TimeUntilNext == 0, "TimeUntilNext should be 0")

	-- 2. Claim Day 1 reward (Bigger reward)
	local Success, Err = DailyRewardService:ClaimDaily(Player)
	assert(Success == true, "ClaimDaily should succeed: " .. tostring(Err))
	assert(Session.DailyRewardDay == 2, "DailyRewardDay should increment to 2")
	assert(Session.LastDailyClaimTimestamp > 0, "LastDailyClaimTimestamp should update to > 0")
	assert(Session.Bigger > 500, "Bigger should have increased from Day 1 reward")

	-- 3. Immediate re-claim should be rejected due to cooldown
	local ReclaimSuccess, ReclaimErr = DailyRewardService:ClaimDaily(Player)
	assert(ReclaimSuccess == false, "Reclaim should fail while cooldown active")
	assert(ReclaimErr == "CooldownActive" or ReclaimErr ~= nil, "Error code should indicate cooldown")
	assert(Session.DailyRewardDay == 2, "DailyRewardDay should stay 2")

	-- 4. Status during cooldown
	local CooldownStatus = DailyRewardService:GetDailyStatus(Player)
	assert(CooldownStatus.Day == 2, "Day is 2")
	assert(CooldownStatus.CanClaim == false, "CanClaim should be false during cooldown")
	assert(CooldownStatus.TimeUntilNext > 0, "TimeUntilNext should be > 0")

	-- 5. Test 7-day wrapping (Day 7 -> Day 1)
	Session.DailyRewardDay = 7
	Session.LastDailyClaimTimestamp = 0 -- Reset cooldown for testing
	local Day7Success = DailyRewardService:ClaimDaily(Player)
	assert(Day7Success == true, "Day 7 claim should succeed")
	assert(Session.DailyRewardDay == 1, "Day 7 should wrap back to Day 1")

	Sessions.Remove(Player)
end)

-- TEST 3: SpinWheelService - Token validation, Authoritative random selection, Reward Dispatch
check("SpinWheelService: Token validation, authoritative SpinWheel, and reward dispatch", function()
	local SpinWheelConfig = loadModule("src/server/Game/Config/SpinWheelConfig.luau", "SpinWheelConfig")
	local RemotesFolder = fakeFolder("Remotes", {
		GetSpinStatus = fakeRemoteFunction("GetSpinStatus"),
		RequestSpinWheel = fakeRemoteEvent("RequestSpinWheel"),
		SpinCompleted = fakeRemoteEvent("SpinCompleted"),
	})
	local MockReplicatedStorage = fakeFolder("ReplicatedStorage", {
		Remotes = RemotesFolder,
	})

	local MockGrowthService = {
		AddBiggerAbsolute = function(_self, Player, Amount)
			Sessions.Mutate(Player, function(S)
				S.Bigger += Amount
			end)
			return true
		end,
	}
	local MockDestructionService = {
		GrantDestruction = function(_self, Player, Amount)
			Sessions.Mutate(Player, function(S)
				S.Destruction += Amount
			end)
			return true
		end,
	}

	pcall(ServiceRegistry.Register, "GrowthService", MockGrowthService)
	pcall(ServiceRegistry.Register, "DestructionService", MockDestructionService)

	local Logger = {
		Info = function(...) end,
		Warn = function(...) end,
		Error = function(...) end,
	}
	local EventBus = createMockEventBus()
	local RewardDispatcher = loadRewardDispatcher(ServiceRegistry, Sessions)

	local ServerServicesFolder = {
		Parent = {
			Config = {
				SpinWheelConfig = SpinWheelConfig,
			},
			Parent = {
				Core = {
					Registry = {
						RuntimeRegistry = { Sessions = Sessions },
						ServiceRegistry = ServiceRegistry,
					},
					Utilities = {
						Logger = Logger,
						RewardDispatcher = RewardDispatcher,
					},
					Events = {
						EventBus = EventBus,
					},
				},
			},
		},
	}

	local SpinWheelService = loadModule("src/server/Game/Services/SpinWheelService.luau", "SpinWheelService", {
		game = {
			GetService = function(_self, ServiceName: string)
				if ServiceName == "ReplicatedStorage" then
					return MockReplicatedStorage
				elseif ServiceName == "Players" then
					return {
						GetPlayers = function()
							return {}
						end,
					}
				end
				return nil
			end,
		},
		script = { Parent = ServerServicesFolder },
		require = function(Dependency)
			return Dependency
		end,
	})

	SpinWheelService:Init()

	local Player = fakePlayer(202)
	local Session = createMockSession(Player, {
		Bigger = 1000,
		Destruction = 50,
		SpinTokens = 0,
	})
	Sessions.Set(Player, Session)

	-- 1. Spin when SpinTokens == 0 should fail
	local Tokens = SpinWheelService:GetSpinTokens(Player)
	assert(Tokens == 0, "Tokens should be 0")
	local SpinOk, SpinErr = SpinWheelService:SpinWheel(Player)
	assert(SpinOk == false, "Spin should fail when tokens == 0")
	assert(SpinErr == "InsufficientTokens" or SpinErr ~= nil, "Expected InsufficientTokens error")
	assert(Session.SpinTokens == 0, "Tokens should remain 0")

	-- 2. Add tokens and spin
	Session.SpinTokens = 2
	local MockRng = {
		NextInteger = function(_self, _min, _max)
			return 1 -- Sector 1 (100 Bigger)
		end,
		NextNumber = function(_self, _min, _max)
			return 1
		end,
	}
	local SpinOk2, Result = SpinWheelService:SpinWheel(Player, MockRng)
	assert(SpinOk2 == true, "Spin should succeed with tokens >= 1")
	assert(Session.SpinTokens == 1, "Spin tokens should have decremented by 1 (was 2, now 1)")
	assert(Result ~= nil, "Spin result should not be nil")
	local Sector = if type(Result) == "table" and Result.Sector then Result.Sector else Result
	assert(type(Sector) == "table", "Result must contain sector table")
	assert(Sector.Index >= 1 and Sector.Index <= 8, "Sector index must be 1..8")

	-- 3. SpinCompleted remote event fired
	local SpinCompletedRemote = RemotesFolder.SpinCompleted
	assert(#SpinCompletedRemote.FiredClientEvents > 0, "SpinCompleted remote should have fired to client")

	Sessions.Remove(Player)
end)

-- TEST 4: DailyRewardController client lifecycle & UI handling
check("DailyRewardController: Init, Start, UIEventBus, remote claiming, Destroy", function()
	local RequestClaimDailyRemote = fakeRemoteEvent("RequestClaimDaily")
	local DailyStatusUpdatedRemote = fakeRemoteEvent("DailyStatusUpdated")
	local RemotesFolder = fakeFolder("Remotes", {
		RequestClaimDaily = RequestClaimDailyRemote,
		DailyStatusUpdated = DailyStatusUpdatedRemote,
	})
	local MockReplicatedStorage = fakeFolder("ReplicatedStorage", {
		Remotes = RemotesFolder,
	})

	local LocalPlayer = fakePlayer(303)
	local MockPlayers = {
		LocalPlayer = LocalPlayer,
	}

	local UIEventBus = loadModule("src/client/controllers/UIEventBus.luau", "UIEventBus")

	local DailyRewardController =
		loadModule("src/client/controllers/DailyRewardController.luau", "DailyRewardController", {
			game = {
				GetService = function(_self, ServiceName: string)
					if ServiceName == "ReplicatedStorage" then
						return MockReplicatedStorage
					elseif ServiceName == "Players" then
						return MockPlayers
					end
					return nil
				end,
			},
			script = {
				Parent = fakeFolder("controllers", {
					UIEventBus = UIEventBus,
				}),
			},
			require = function(Dependency)
				if Dependency == UIEventBus then
					return UIEventBus
				end
				return Dependency
			end,
		})

	DailyRewardController.Init()
	DailyRewardController.Start()

	-- Status update via remote
	local DummyStatus = {
		Day = 3,
		CanClaim = true,
		TimeUntilNext = 0,
	}
	DailyStatusUpdatedRemote.OnClientEvent:Fire(DummyStatus)

	local Cached = DailyRewardController.GetStatus()
	assert(Cached ~= nil and Cached.Day == 3, "Cached status should update to Day 3")

	-- Claim trigger
	DailyRewardController.Claim()
	assert(#RequestClaimDailyRemote.FiredServerEvents > 0, "Claim() should fire RequestClaimDaily to server")

	-- Open / Close modal
	DailyRewardController.Open()
	assert(DailyRewardController.IsOpen() == true, "Modal should be open")
	DailyRewardController.Close()
	assert(DailyRewardController.IsOpen() == false, "Modal should be closed")

	DailyRewardController.Destroy()
end)

-- TEST 5: SpinWheelController client lifecycle & animation/spin handling
check("SpinWheelController: Init, Start, UIEventBus, remote spinning, Destroy", function()
	local RequestSpinWheelRemote = fakeRemoteEvent("RequestSpinWheel")
	local SpinCompletedRemote = fakeRemoteEvent("SpinCompleted")
	local RemotesFolder = fakeFolder("Remotes", {
		RequestSpinWheel = RequestSpinWheelRemote,
		SpinCompleted = SpinCompletedRemote,
	})
	local MockReplicatedStorage = fakeFolder("ReplicatedStorage", {
		Remotes = RemotesFolder,
	})

	local LocalPlayer = fakePlayer(404)
	local MockPlayers = {
		LocalPlayer = LocalPlayer,
	}

	local UIEventBus = loadModule("src/client/controllers/UIEventBus.luau", "UIEventBus")

	local SpinWheelController = loadModule("src/client/controllers/SpinWheelController.luau", "SpinWheelController", {
		game = {
			GetService = function(_self, ServiceName: string)
				if ServiceName == "ReplicatedStorage" then
					return MockReplicatedStorage
				elseif ServiceName == "Players" then
					return MockPlayers
				end
				return nil
			end,
		},
		script = {
			Parent = fakeFolder("controllers", {
				UIEventBus = UIEventBus,
			}),
		},
		require = function(Dependency)
			if Dependency == UIEventBus then
				return UIEventBus
			end
			return Dependency
		end,
	})

	SpinWheelController.Init()
	SpinWheelController.Start()

	-- Open / Close modal
	SpinWheelController.Open()
	assert(SpinWheelController.IsOpen() == true, "SpinWheel modal should be open")

	-- Spin trigger
	SpinWheelController.Spin()
	assert(#RequestSpinWheelRemote.FiredServerEvents > 0, "Spin() should fire RequestSpinWheel to server")

	-- SpinCompleted remote handler
	local DummyResult = {
		Sector = {
			Index = 4,
			Name = "1 Spin Token",
			Reward = { Type = RewardType.SpinTokens, Amount = 1 },
		},
		RemainingTokens = 3,
	}
	SpinCompletedRemote.OnClientEvent:Fire(DummyResult)

	assert(SpinWheelController.GetTokens() == 3, "Tokens should be updated to 3")

	SpinWheelController.Close()
	assert(SpinWheelController.IsOpen() == false, "SpinWheel modal should be closed")

	SpinWheelController.Destroy()
end)

print("\n=== TEST SUMMARY ===")
if #Failures > 0 then
	print(string.format("FAILED: %d tests failed", #Failures))
	for _, Failure in Failures do
		print("  - " .. Failure)
	end
	error("Tests failed")
else
	print("ALL MVP-006 TASK 8 TESTS PASSED")
end
