local fs = require("@lune/fs")
local luau = require("@lune/luau")
local task = require("@lune/task")

local Sessions = require("../../src/server/Core/Registry/RuntimeRegistry/Sessions")

local TEST_SYNTHETIC_WORLD1_TRIPLE_REWARD_PRODUCT_ID = 920001
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

local function loadWorld1Config()
	return loadModule("src/server/Game/Config/World1Config.luau", "World1Config", {
		Vector3 = {
			new = function(X, Y, Z)
				return { X = X, Y = Y, Z = Z }
			end,
		},
		table = {
			freeze = function(t)
				return t
			end,
		},
	})
end
local World1Config = loadWorld1Config()

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
	function Player:IsA(ClassName: string)
		return ClassName == "Player"
	end
	return Player
end

local function fakeSession(Player: any)
	return {
		Player = Player,
		Bigger = 100000, -- High bigger so derived level >= RequiredLevel (5)
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
		CurrentWorldInstanceId = nil,
	}
end

local function loadLevelFormula()
	local BalanceConfig = loadModule("src/shared/Game/Progression/BalanceConfig.luau", "BalanceConfig")
	return loadModule("src/shared/Game/Progression/LevelFormula.luau", "LevelFormula", {
		script = { Parent = { BalanceConfig = BalanceConfig } },
		require = function()
			return BalanceConfig
		end,
	})
end

local function loadPortalHarness()
	local Player = fakePlayer(9001)
	local Session = fakeSession(Player)
	Sessions.Set(Player, Session)

	local Remotes = childContainer({
		RequestSelectMap = { OnServerEvent = fakeSignal() },
	})
	local LevelFormula = loadLevelFormula()
	local ReplicatedStorage = childContainer({
		Remotes = Remotes,
		BiggerShared = childContainer({
			Game = childContainer({
				Progression = childContainer({
					LevelFormula = LevelFormula,
				}),
			}),
		}),
	})

	local Workspace = {
		FindFirstChild = function(_, _Name)
			return nil
		end,
	}

	local CreatedWorlds = {}
	local EnteredWorlds = {}
	local RecoveredCalls = {}

	local WorldInstanceService = {
		CreatedWorlds = CreatedWorlds,
		EnteredWorlds = EnteredWorlds,
		RecoveredCalls = RecoveredCalls,
		GetPlayerWorld = function(_, TargetPlayer)
			return CreatedWorlds[TargetPlayer]
		end,
		CreateWorld = function(self, TargetPlayer, MapId)
			local World = {
				WorldInstanceId = (MapId or "WORLD1") .. "_" .. tostring(TargetPlayer.UserId),
				OwnerPlayer = TargetPlayer,
				OwnerUserId = TargetPlayer.UserId,
				Model = { Parent = {} },
				ObjectiveInitialized = false,
				ObjectiveActive = false,
				ObjectiveCompleted = false,
				RewardState = "Inactive",
				Connections = {},
			}
			CreatedWorlds[TargetPlayer] = World
			local S = Sessions.Get(TargetPlayer)
			if S then
				S.CurrentWorldInstanceId = World.WorldInstanceId
			end
			return World
		end,
		CreateWorldForPlayer = function(self, TargetPlayer)
			return self:CreateWorld(TargetPlayer, "WORLD1")
		end,
		EnterWorld = function(self, TargetPlayer, WorldInstance)
			table.insert(self.EnteredWorlds, { Player = TargetPlayer, WorldInstance = WorldInstance })
			local S = Sessions.Get(TargetPlayer)
			if S then
				S.State = "InWorld"
			end
			return true
		end,
		ActivateWorld = function(_, _TargetPlayer)
			return true
		end,
		RecoverPlayer = function(self, TargetPlayer, Reason, Respawn)
			table.insert(self.RecoveredCalls, { Player = TargetPlayer, Reason = Reason, Respawn = Respawn })
			local S = Sessions.Get(TargetPlayer)
			if S then
				S.State = "InLobby"
				S.CurrentWorldInstanceId = nil
			end
			CreatedWorlds[TargetPlayer] = nil
		end,
		ReturnPlayerToLobby = function(_, TargetPlayer)
			local S = Sessions.Get(TargetPlayer)
			if S then
				S.State = "InLobby"
				S.CurrentWorldInstanceId = nil
			end
			return true
		end,
	}

	local SessionService = {
		TransitionState = function(_, TargetPlayer, Expected, Next)
			local S = Sessions.Get(TargetPlayer)
			if not S or S.State ~= Expected then
				return false
			end
			S.State = Next
			return true
		end,
		RecoverToLobby = function(_, TargetPlayer, _Reason)
			local S = Sessions.Get(TargetPlayer)
			if S then
				S.State = "InLobby"
				S.CurrentWorldInstanceId = nil
			end
			return true
		end,
	}

	local ServiceRegistry = {
		Get = function(Name: string)
			if Name == "SessionService" then
				return SessionService
			elseif Name == "WorldInstanceService" then
				return WorldInstanceService
			end
			error("unknown service " .. Name)
		end,
	}

	local Logger = {
		Info = function() end,
		Warn = function() end,
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

	local Game = {
		GetService = function(_, Name: string)
			if Name == "Workspace" then
				return Workspace
			elseif Name == "ReplicatedStorage" then
				return ReplicatedStorage
			elseif Name == "Players" then
				return {
					GetPlayerFromCharacter = function()
						return Player
					end,
				}
			end
			error("unexpected service " .. Name)
		end,
	}

	local PortalService = loadModule("src/server/Game/Services/PortalService.luau", "PortalService", {
		game = Game,
		script = { Parent = ServicesFolder },
		require = function(Dependency)
			return Dependency
		end,
		task = {
			delay = function(_, Callback)
				Callback()
			end,
		},
	})
	PortalService:Init()

	return {
		PortalService = PortalService,
		WorldInstanceService = WorldInstanceService,
		SessionService = SessionService,
		Remotes = Remotes,
		Player = Player,
		Session = Session,
	}
end

local function loadRewardHarness(ProductId: number?)
	local Player = fakePlayer(9002)
	local Session = fakeSession(Player)
	Session.State = "InWorld"
	Session.CurrentWorldInstanceId = "WORLD1_9002"
	Sessions.Set(Player, Session)

	local ConfiguredProductId = ProductId or TEST_SYNTHETIC_WORLD1_TRIPLE_REWARD_PRODUCT_ID

	local Remotes = childContainer({
		ShowRewardPopup = {
			FiredClients = {},
			FireClient = function(self, TargetPlayer, Payload)
				table.insert(self.FiredClients, { Player = TargetPlayer, Payload = Payload })
			end,
		},
		RequestClaimReward = { OnServerEvent = fakeSignal() },
	})

	local MarketplaceService = {
		PromptProductPurchaseFinished = fakeSignal(),
		Prompts = {},
		PromptProductPurchase = function(self, PromptPlayer, PId)
			table.insert(self.Prompts, { Player = PromptPlayer, ProductId = PId })
		end,
	}

	local HttpService = {
		GenerateGUID = function()
			return "TEST_REWARD_GUID"
		end,
	}

	local DestructionService = {
		GrantCalls = {},
		GrantDestruction = function(self, TargetPlayer, Amount)
			table.insert(self.GrantCalls, { Player = TargetPlayer, Amount = Amount })
			local S = Sessions.Get(TargetPlayer)
			if S then
				S.Destruction += Amount
			end
			return true
		end,
	}

	local SessionService = {
		TransitionState = function(_, TargetPlayer, Expected, Next)
			local S = Sessions.Get(TargetPlayer)
			if not S or S.State ~= Expected then
				return false
			end
			S.State = Next
			return true
		end,
	}

	local WorldInstance = {
		WorldInstanceId = "WORLD1_9002",
		OwnerPlayer = Player,
		OwnerUserId = Player.UserId,
		Model = {
			FindFirstChild = function()
				return nil
			end,
		},
		ObjectiveInitialized = true,
		ObjectiveActive = false,
		ObjectiveCompleted = true,
		RewardState = "Inactive",
		PendingRewardPrompt = nil,
		Connections = {},
	}

	local WorldInstances = {
		Get = function(TargetPlayer)
			return if TargetPlayer == Player then WorldInstance else nil
		end,
		Remove = function() end,
	}

	local WorldInstanceService = {
		ReturnCalls = {},
		RecoverCalls = {},
		ReturnPlayerToLobby = function(self, TargetPlayer)
			table.insert(self.ReturnCalls, TargetPlayer)
			local S = Sessions.Get(TargetPlayer)
			if S then
				S.State = "InLobby"
				S.CurrentWorldInstanceId = nil
			end
			return true
		end,
		RecoverPlayer = function(self, TargetPlayer, Reason, Respawn)
			table.insert(self.RecoverCalls, { Player = TargetPlayer, Reason = Reason, Respawn = Respawn })
			local S = Sessions.Get(TargetPlayer)
			if S then
				S.State = "InLobby"
				S.CurrentWorldInstanceId = nil
			end
		end,
	}

	local PortalService = {
		DebounceCalls = {},
		HoldDebounce = function(self, TargetPlayer, Duration)
			table.insert(self.DebounceCalls, { Player = TargetPlayer, Duration = Duration })
		end,
	}

	local SaveService = {
		IsProfileWritable = function(_, TargetPlayer)
			local S = Sessions.Get(TargetPlayer)
			return S ~= nil and not S.ProfileMutationsFrozen
		end,
	}

	local ServiceRegistry = {
		Get = function(Name: string)
			if Name == "DestructionService" then
				return DestructionService
			elseif Name == "SessionService" then
				return SessionService
			elseif Name == "WorldInstanceService" then
				return WorldInstanceService
			elseif Name == "PortalService" then
				return PortalService
			elseif Name == "SaveService" then
				return SaveService
			end
			error("unknown service " .. Name)
		end,
	}

	local Subscribers: { [string]: { (...any) -> () } } = {}
	local EventsFired = {}
	local EventBus = {
		Subscribers = Subscribers,
		EventsFired = EventsFired,
		Subscribe = function(Name: string, Callback: (...any) -> ())
			Subscribers[Name] = Subscribers[Name] or {}
			table.insert(Subscribers[Name], Callback)
		end,
		Publish = function(Name: string, ...: any)
			table.insert(EventsFired, { Name = Name, Args = { ... } })
			for _, Callback in Subscribers[Name] or {} do
				Callback(...)
			end
		end,
	}

	local DeveloperProductConfig = {
		World1TripleReward = {
			ProductId = ConfiguredProductId,
			Price = 29,
			Surface = "PortalOnly",
			Rewards = { { Type = "Destruction", Amount = 3 } },
		},
	}

	local ConfigValidationService = {
		GetDeveloperProductStatus = function(_, _Key)
			return if ConfiguredProductId > 0
				then { IsConfigured = true }
				else { IsConfigured = false, ErrorCode = "MissingProductId" }
		end,
	}

	local Logger = {
		Info = function() end,
		Warn = function() end,
	}

	local ServicesFolder = {
		Parent = {
			Config = { World1Config = World1Config },
			Parent = {
				Core = {
					Config = { DeveloperProductConfig = DeveloperProductConfig },
					Services = { ConfigValidationService = ConfigValidationService },
					Registry = {
						RuntimeRegistry = { Sessions = Sessions, WorldInstances = WorldInstances },
						ServiceRegistry = ServiceRegistry,
					},
					Events = { EventBus = EventBus },
					Utilities = { Logger = Logger },
				},
			},
		},
	}

	local Players = {
		GetPlayerByUserId = function(_, UserId)
			return if UserId == Player.UserId then Player else nil
		end,
		GetPlayerFromCharacter = function(_, _Char)
			return Player
		end,
	}

	local ReplicatedStorage = childContainer({
		Remotes = Remotes,
	})

	local Game = {
		GetService = function(_, Name: string)
			if Name == "MarketplaceService" then
				return MarketplaceService
			elseif Name == "Players" then
				return Players
			elseif Name == "HttpService" then
				return HttpService
			elseif Name == "ReplicatedStorage" then
				return ReplicatedStorage
			end
			error("unexpected service " .. Name)
		end,
	}

	local RewardPortalService = loadModule("src/server/Game/Services/RewardPortalService.luau", "RewardPortalService", {
		game = Game,
		script = { Parent = ServicesFolder },
		require = function(Dependency)
			return Dependency
		end,
	})
	RewardPortalService:Init()

	return {
		RewardPortalService = RewardPortalService,
		WorldInstance = WorldInstance,
		WorldInstanceService = WorldInstanceService,
		DestructionService = DestructionService,
		MarketplaceService = MarketplaceService,
		EventBus = EventBus,
		Remotes = Remotes,
		Player = Player,
		Session = Session,
	}
end

print("=== Running MVP-006 Task 5 Unit Tests (Map Selector & Reward Popup) ===")

--// 1. RequestSelectMap Remote & Validation Tests \\--
check("RequestSelectMap validates session state is InLobby, creates world, and transitions to InWorld", function()
	local Harness = loadPortalHarness()
	local Player = Harness.Player
	local Session = Harness.Session

	-- Successful map selection from InLobby
	assert(Session.State == "InLobby")
	Harness.Remotes.RequestSelectMap.OnServerEvent:Fire(Player, "WORLD1")

	assert(#Harness.WorldInstanceService.EnteredWorlds == 1, "WorldInstanceService:EnterWorld should be called")
	assert(Session.State == "InWorld", "Player state should transition to InWorld")
	assert(Session.CurrentWorldInstanceId ~= nil, "CurrentWorldInstanceId should be set")

	Sessions.Remove(Player)
end)

check("RequestSelectMap rejects requests when not in InLobby state or session is frozen", function()
	local Harness = loadPortalHarness()
	local Player = Harness.Player
	local Session = Harness.Session

	-- Rejection when already InWorld
	Session.State = "InWorld"
	Harness.Remotes.RequestSelectMap.OnServerEvent:Fire(Player, "WORLD1")
	assert(#Harness.WorldInstanceService.EnteredWorlds == 0, "Should not enter world when state is InWorld")

	-- Rejection when profile is frozen
	Session.State = "InLobby"
	Session.ProfileMutationsFrozen = true
	Harness.Remotes.RequestSelectMap.OnServerEvent:Fire(Player, "WORLD1")
	assert(#Harness.WorldInstanceService.EnteredWorlds == 0, "Should not enter world when session is frozen")

	-- Rejection when level requirement is not met
	Session.ProfileMutationsFrozen = false
	Session.Bigger = 1 -- Level 1 < RequiredLevel (5)
	Harness.Remotes.RequestSelectMap.OnServerEvent:Fire(Player, "WORLD1")
	assert(#Harness.WorldInstanceService.EnteredWorlds == 0, "Should not enter world when level requirement not met")

	-- Rejection when invalid MapId provided
	Session.Bigger = 100000
	Harness.Remotes.RequestSelectMap.OnServerEvent:Fire(Player, "NonexistentWorld99")
	assert(#Harness.WorldInstanceService.EnteredWorlds == 0, "Should not enter world with invalid MapId")

	Sessions.Remove(Player)
end)

--// 2. Objective Completion & ShowRewardPopup Event Tests \\--
check("ActivateChoices fires ShowRewardPopup remote event with reward payload to player", function()
	local Harness = loadRewardHarness()
	local WorldInstance = Harness.WorldInstance

	assert(WorldInstance.RewardState == "Inactive")
	local Activated = Harness.RewardPortalService:ActivateChoices(WorldInstance, Harness.WorldInstanceService)
	assert(Activated == true, "ActivateChoices should return true")
	assert(WorldInstance.RewardState == "Choosing", "RewardState should be Choosing")

	-- Check that ShowRewardPopup was fired
	local FiredList = Harness.Remotes.ShowRewardPopup.FiredClients
	assert(#FiredList == 1, "ShowRewardPopup should be fired to client once")
	assert(FiredList[1].Player == Harness.Player, "ShowRewardPopup should be fired to owner player")

	local Payload = FiredList[1].Payload
	assert(Payload ~= nil, "Payload should be present")
	assert(Payload.FreeReward ~= nil, "Payload.FreeReward should be present")
	assert(Payload.FreeReward.Amount == 1, "FreeReward amount should be 1")
	assert(Payload.PaidReward ~= nil, "Payload.PaidReward should be present")
	assert(Payload.PaidReward.Amount == 3, "PaidReward amount should be 3")
	assert(Payload.PaidReward.Price == 29, "PaidReward price should be 29")

	Sessions.Remove(Harness.Player)
end)

--// 3. RequestClaimReward: Free Choice Tests \\--
check("RequestClaimReward('Free') grants 1 Destruction, transitions state, and returns to Lobby", function()
	local Harness = loadRewardHarness()
	local WorldInstance = Harness.WorldInstance
	local Player = Harness.Player
	local Session = Harness.Session

	Harness.RewardPortalService:ActivateChoices(WorldInstance, Harness.WorldInstanceService)
	assert(WorldInstance.RewardState == "Choosing")

	-- Fire Free claim request
	Harness.Remotes.RequestClaimReward.OnServerEvent:Fire(Player, "Free")

	assert(WorldInstance.RewardState == "Settled", "RewardState should be Settled")
	assert(#Harness.DestructionService.GrantCalls == 1, "DestructionService:GrantDestruction should be called once")
	assert(Harness.DestructionService.GrantCalls[1].Amount == 1, "Destruction grant amount should be 1")
	assert(Session.Destruction == 1, "Session destruction should be 1")
	assert(#Harness.WorldInstanceService.ReturnCalls == 1, "Player should be returned to lobby")
	assert(Session.State == "InLobby", "Player state should be InLobby")

	-- Second claim attempt should be rejected (already settled)
	Harness.Remotes.RequestClaimReward.OnServerEvent:Fire(Player, "Free")
	assert(#Harness.DestructionService.GrantCalls == 1, "Should not grant destruction again on settled state")

	Sessions.Remove(Player)
end)

--// 4. RequestClaimReward: PaidTriple Choice Tests \\--
check("RequestClaimReward('PaidTriple') opens Marketplace prompt when configured", function()
	local Harness = loadRewardHarness(TEST_SYNTHETIC_WORLD1_TRIPLE_REWARD_PRODUCT_ID)
	local WorldInstance = Harness.WorldInstance
	local Player = Harness.Player

	Harness.RewardPortalService:ActivateChoices(WorldInstance, Harness.WorldInstanceService)
	assert(WorldInstance.RewardState == "Choosing")

	-- Fire Paid claim request
	Harness.Remotes.RequestClaimReward.OnServerEvent:Fire(Player, "PaidTriple")

	assert(WorldInstance.RewardState == "PromptOpen", "RewardState should be PromptOpen")
	assert(#Harness.MarketplaceService.Prompts == 1, "Marketplace prompt should be triggered")
	assert(
		Harness.MarketplaceService.Prompts[1].ProductId == TEST_SYNTHETIC_WORLD1_TRIPLE_REWARD_PRODUCT_ID,
		"Prompted product ID mismatch"
	)

	-- Simulate successful purchase and DeveloperProductCommitted receipt
	Harness.MarketplaceService.PromptProductPurchaseFinished:Fire(
		Player.UserId,
		TEST_SYNTHETIC_WORLD1_TRIPLE_REWARD_PRODUCT_ID,
		true
	)
	assert(WorldInstance.RewardState == "AwaitingReceipt")

	Harness.EventBus.Publish("DeveloperProductCommitted", Player, "World1TripleReward", "PURCHASE_123")
	assert(WorldInstance.RewardState == "Settled")
	assert(#Harness.WorldInstanceService.ReturnCalls == 1, "Player returned to lobby after receipt committed")
	assert(Harness.Session.State == "InLobby")

	Sessions.Remove(Player)
end)

check("RequestClaimReward('PaidTriple') handles unconfigured placeholder safely", function()
	local Harness = loadRewardHarness(0) -- ProductId = 0 (unconfigured)
	local WorldInstance = Harness.WorldInstance
	local Player = Harness.Player

	Harness.RewardPortalService:ActivateChoices(WorldInstance, Harness.WorldInstanceService)
	assert(WorldInstance.RewardState == "Choosing")

	-- Fire Paid claim request when unconfigured
	Harness.Remotes.RequestClaimReward.OnServerEvent:Fire(Player, "PaidTriple")

	assert(#Harness.MarketplaceService.Prompts == 0, "Should NOT trigger marketplace prompt when unconfigured")
	assert(WorldInstance.RewardState == "Choosing", "RewardState should remain Choosing")

	Sessions.Remove(Player)
end)

--// 5. Invalid Choice & Invalid State Rejections \\--
check("RequestClaimReward rejects invalid choices and requests from invalid states", function()
	local Harness = loadRewardHarness()
	local WorldInstance = Harness.WorldInstance
	local Player = Harness.Player
	local Session = Harness.Session

	-- Attempt to claim before activation (RewardState == "Inactive")
	Harness.Remotes.RequestClaimReward.OnServerEvent:Fire(Player, "Free")
	assert(#Harness.DestructionService.GrantCalls == 0, "Cannot claim reward when Inactive")

	-- Activate choices
	Harness.RewardPortalService:ActivateChoices(WorldInstance, Harness.WorldInstanceService)
	assert(WorldInstance.RewardState == "Choosing")

	-- Attempt invalid choice strings
	for _, InvalidChoice in { "Invalid", "Free100x", "", 123, false, {} } do
		Harness.Remotes.RequestClaimReward.OnServerEvent:Fire(Player, InvalidChoice)
		assert(
			#Harness.DestructionService.GrantCalls == 0,
			"Invalid choice string must be rejected: " .. tostring(InvalidChoice)
		)
		assert(WorldInstance.RewardState == "Choosing", "State should remain Choosing on invalid choice")
	end

	-- Attempt claim when frozen
	Session.ProfileMutationsFrozen = true
	Harness.Remotes.RequestClaimReward.OnServerEvent:Fire(Player, "Free")
	assert(#Harness.DestructionService.GrantCalls == 0, "Frozen session must be rejected")
	Session.ProfileMutationsFrozen = false

	-- Attempt claim when state is not InWorld
	Session.State = "InLobby"
	Harness.Remotes.RequestClaimReward.OnServerEvent:Fire(Player, "Free")
	assert(#Harness.DestructionService.GrantCalls == 0, "Non-InWorld state must be rejected")

	Sessions.Remove(Player)
end)

--// 6. Client Controllers Tests \\--
check("MapSelectorController: Init, Start, Open, SelectMap, and Destroy lifecycle", function()
	local FiredMaps = {}
	local RequestSelectMapRemote = {
		FireServer = function(_, MapId)
			table.insert(FiredMaps, MapId)
		end,
		IsA = function(_, ClassName)
			return ClassName == "RemoteEvent"
		end,
	}
	local Remotes = childContainer({
		RequestSelectMap = RequestSelectMapRemote,
	})
	local ReplicatedStorage = childContainer({
		Remotes = Remotes,
	})
	local LocalPlayer = fakePlayer(9003)
	LocalPlayer.PlayerGui = childContainer({})
	local Players = {
		LocalPlayer = LocalPlayer,
	}
	local ContextActionService = {
		BindAction = function() end,
		UnbindAction = function() end,
	}
	local GuiService = {
		GetGuiInset = function()
			return { X = 0, Y = 0 }, { X = 0, Y = 0 }
		end,
	}
	local TweenService = {
		Create = function()
			return { Play = function() end, Cancel = function() end }
		end,
	}
	local MockWorkspace = childContainer({})
	local Game = {
		GetService = function(_, Name: string)
			if Name == "Players" then
				return Players
			elseif Name == "ReplicatedStorage" then
				return ReplicatedStorage
			elseif Name == "ContextActionService" then
				return ContextActionService
			elseif Name == "GuiService" then
				return GuiService
			elseif Name == "TweenService" then
				return TweenService
			elseif Name == "Workspace" then
				return MockWorkspace
			end
			error("unexpected service " .. Name)
		end,
	}

	local UIEventBus = {
		Subscribe = function()
			return { Disconnect = function() end }
		end,
		Publish = function() end,
	}

	local Controller = loadModule("src/client/controllers/MapSelectorController.luau", "MapSelectorController", {
		game = Game,
		script = {
			Parent = {
				UIEventBus = UIEventBus,
				WaitForChild = function(_, Name)
					if Name == "UIEventBus" then
						return UIEventBus
					end
					error("unexpected child " .. Name)
				end,
			},
		},
		require = function(Dependency)
			return Dependency
		end,
	})

	Controller.Init()
	Controller.Start()

	assert(Controller.IsOpen() == false)
	Controller.Open()
	assert(Controller.IsOpen() == true)
	Controller.Close()
	assert(Controller.IsOpen() == false)
	Controller.Toggle()
	assert(Controller.IsOpen() == true)

	Controller.SelectMap("WORLD1")
	assert(#FiredMaps == 1 and FiredMaps[1] == "WORLD1", "SelectMap must fire RequestSelectMap with WORLD1")

	Controller.Destroy()
	assert(Controller.IsOpen() == false)
end)

check("RewardPopupController: Init, Start, Show, ClaimReward, and Destroy lifecycle", function()
	local ClaimRequests = {}
	local ShowRewardSignal = fakeSignal()
	local ShowRewardPopupRemote = {
		OnClientEvent = ShowRewardSignal,
		IsA = function(_, ClassName)
			return ClassName == "RemoteEvent"
		end,
	}
	local RequestClaimRewardRemote = {
		FireServer = function(_, Choice)
			table.insert(ClaimRequests, Choice)
		end,
		IsA = function(_, ClassName)
			return ClassName == "RemoteEvent"
		end,
	}

	local Remotes = childContainer({
		ShowRewardPopup = ShowRewardPopupRemote,
		RequestClaimReward = RequestClaimRewardRemote,
	})
	local ReplicatedStorage = childContainer({
		Remotes = Remotes,
	})
	local LocalPlayer = fakePlayer(9004)
	LocalPlayer.PlayerGui = childContainer({})
	local Players = {
		LocalPlayer = LocalPlayer,
	}
	local Game = {
		GetService = function(_, Name: string)
			if Name == "Players" then
				return Players
			elseif Name == "ReplicatedStorage" then
				return ReplicatedStorage
			end
			error("unexpected service " .. Name)
		end,
	}

	local Controller = loadModule("src/client/controllers/RewardPopupController.luau", "RewardPopupController", {
		game = Game,
		script = {
			Parent = {},
		},
		require = function(Dependency)
			return Dependency
		end,
		Instance = {
			new = function(ClassName)
				local Inst = {
					Name = ClassName,
					Parent = nil,
					Destroy = function(self)
						self.Parent = nil
					end,
					Activated = fakeSignal(),
				}
				function Inst:IsA(Name)
					return Name == ClassName
				end
				function Inst:FindFirstChild(Name)
					return self[Name]
				end
				return Inst
			end,
		},
		UDim2 = {
			fromScale = function(X, Y)
				return { X = X, Y = Y }
			end,
			fromOffset = function(X, Y)
				return { X = X, Y = Y }
			end,
			new = function(X, XO, Y, YO)
				return { X = X, XO = XO, Y = Y, YO = YO }
			end,
		},
		UDim = {
			new = function(Scale, Offset)
				return { Scale = Scale, Offset = Offset }
			end,
		},
		Vector2 = {
			new = function(X, Y)
				return { X = X, Y = Y }
			end,
		},
		Color3 = {
			fromRGB = function(R, G, B)
				return { R = R, G = G, B = B }
			end,
		},
		Enum = {
			Font = { Gotham = "Gotham", GothamBold = "GothamBold" },
		},
	})

	Controller.Init()
	Controller.Start()

	assert(Controller.IsOpen() == false)

	-- Simulate ShowRewardPopup event from server
	local Payload = {
		WorldId = "WORLD1",
		FreeReward = { Type = "Destruction", Amount = 1, Label = "Claim 1x Free" },
		PaidReward = { Type = "Destruction", Amount = 3, Price = 29, Label = "Claim 3x (29 R$)" },
	}
	ShowRewardSignal:Fire(Payload)

	assert(Controller.IsOpen() == true, "Popup should be open after ShowRewardPopup event")
	assert(Controller.GetCachedRewardData() == Payload, "Cached payload should match")

	-- Claim Free
	Controller.ClaimReward("Free")
	assert(#ClaimRequests == 1 and ClaimRequests[1] == "Free", "ClaimReward('Free') should fire server remote")
	assert(Controller.IsOpen() == false, "Popup should close after claiming Free")

	-- Show again and claim PaidTriple
	Controller.Show(Payload)
	assert(Controller.IsOpen() == true)
	Controller.ClaimReward("PaidTriple")
	assert(
		#ClaimRequests == 2 and ClaimRequests[2] == "PaidTriple",
		"ClaimReward('PaidTriple') should fire server remote"
	)
	assert(Controller.IsOpen() == false, "Popup should close after claiming PaidTriple")

	Controller.Destroy()
	assert(Controller.IsOpen() == false)
end)

if #Failures > 0 then
	print("\n--- TEST FAILURES ---")
	for _, Failure in ipairs(Failures) do
		print("  FAIL: " .. Failure)
	end
	error(string.format("%d tests failed", #Failures))
else
	print("\n=== ALL MVP-006 TASK 5 UNIT TESTS PASSED ===")
end
