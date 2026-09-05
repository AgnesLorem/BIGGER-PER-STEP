local fs = require("@lune/fs")
local luau = require("@lune/luau")
local task = require("@lune/task")

local Sessions = require("../../src/server/Core/Registry/RuntimeRegistry/Sessions")
local WorldInstances = require("../../src/server/Core/Registry/RuntimeRegistry/WorldInstances")

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

local function childContainer(Children: { [string]: any })
	local Container = Children or {}
	function Container:WaitForChild(Name: string, _Timeout: number?)
		return assert(self[Name], "missing child " .. Name)
	end
	function Container:FindFirstChild(Name: string, _Recursive: boolean?)
		return self[Name]
	end
	function Container:FindFirstChildWhichIsA(ClassName: string, _Recursive: boolean?)
		for _, child in self do
			if type(child) == "table" and child.IsA and child:IsA(ClassName) then
				return child
			end
		end
		return nil
	end
	function Container:GetChildren()
		local list = {}
		for _, v in self do
			if type(v) == "table" then
				table.insert(list, v)
			end
		end
		return list
	end
	function Container:GetDescendants()
		local list = {}
		for _, v in self do
			if type(v) == "table" then
				table.insert(list, v)
			end
		end
		return list
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

	local AttributeSignals = {}

	local Player = {
		UserId = UserId,
		Name = "TestPlayer_" .. tostring(UserId),
		Attributes = {},
		leaderstats = Leaderstats,
		DestructionStat = DestructionStat,
	}
	function Player:IsA(ClassName: string)
		return ClassName == "Player"
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

local function fakeSession(Player: any)
	return {
		Player = Player,
		Bigger = 500, -- Level 5+ to satisfy map portal gate
		Destruction = 0,
		Rebirth = 0,
		UnlockedGrowthUpgrades = {},
		EquippedGrowthUpgrade = nil,
		CompletedPortals = {},
		Settings = { SoundEnabled = true, MusicEnabled = true },
		State = "InLobby",
		JoinedAt = 0,
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
		GamePassQueryGenerations = { Vip = 0, PremiumZone = 0, AutoWins = 0 },
		LastActiveTimestamp = 0,
		LastLogoutTimestamp = 0,
		LastSaveTimestamp = 0,
		ProfileMutationsFrozen = false,
		ProfileMutationFreezeReason = nil,
	}
end

local function fakeRemoteEvent(Name: string)
	local Remote = {
		Name = Name,
		ClassName = "RemoteEvent",
		OnServerEvent = fakeSignal(),
		OnClientEvent = fakeSignal(),
		ServerCalls = {},
		ClientCalls = {},
	}
	function Remote:IsA(ClassName: string)
		return ClassName == "RemoteEvent" or ClassName == "Instance"
	end
	function Remote:FireServer(...)
		table.insert(self.ServerCalls, { ... })
		self.OnServerEvent:Fire(fakePlayer(1), ...)
	end
	function Remote:FireClient(TargetPlayer: any, ...)
		table.insert(self.ClientCalls, { Player = TargetPlayer, Args = { ... } })
		self.OnClientEvent:Fire(...)
	end
	return Remote
end

local function setupHarness()
	local RemotesFolder = {
		Name = "Remotes",
		Children = {},
	}
	function RemotesFolder:FindFirstChild(Name: string)
		return self.Children[Name]
	end
	function RemotesFolder:WaitForChild(Name: string, _Timeout: number?)
		return self.Children[Name]
	end

	local ToggleAutoWinsRemote = fakeRemoteEvent("ToggleAutoWins")
	RemotesFolder.Children["ToggleAutoWins"] = ToggleAutoWinsRemote

	local ReplicatedStorage = childContainer({
		Remotes = RemotesFolder,
	})

	local PlayersList = {}
	local PlayersService = {
		LocalPlayer = nil,
		GetPlayers = function()
			return PlayersList
		end,
		GetPlayerByUserId = function(_, UserId: number)
			for _, p in PlayersList do
				if p.UserId == UserId then
					return p
				end
			end
			return nil
		end,
		GetPlayerFromCharacter = function(_, Character: any)
			for _, p in PlayersList do
				if p.Character == Character then
					return p
				end
			end
			return nil
		end,
	}

	local GamePassPrompts = {}
	local GamePassService = {
		Prompt = function(_, TargetPlayer: any, PassKey: string)
			table.insert(GamePassPrompts, { Player = TargetPlayer, PassKey = PassKey })
			return true
		end,
		IsOwned = function(_, TargetPlayer: any, PassKey: string)
			local S = Sessions.Get(TargetPlayer)
			if not S then
				return false
			end
			if PassKey == "AutoWins" then
				return S.HasAutoWins == true
			end
			return false
		end,
	}

	local CreatedWorlds = {}
	local WorldInstanceCounter = 0
	local PortalSelectMapCalls = {}
	local PortalService = {
		SelectMap = function(self, TargetPlayer: any, MapId: string)
			table.insert(PortalSelectMapCalls, { Player = TargetPlayer, MapId = MapId })
			local S = Sessions.Get(TargetPlayer)
			if not S or S.ProfileMutationsFrozen or S.State ~= "InLobby" then
				return false
			end

			WorldInstanceCounter += 1
			local WorldId = "world_" .. tostring(WorldInstanceCounter)
			local WorldModel = {
				Name = "World1Runtime",
				FindFirstChild = function(this, name, rec)
					if name == "Spider" then
						return {
							FindFirstChild = function(_, subname)
								if subname == "ObjectiveHitbox" then
									return {
										Name = "ObjectiveHitbox",
										IsA = function()
											return true
										end,
										CanTouch = true,
									}
								end
								return nil
							end,
							GetDescendants = function()
								return {}
							end,
						}
					end
					return nil
				end,
			}
			local WorldInstance = {
				WorldInstanceId = WorldId,
				OwnerUserId = TargetPlayer.UserId,
				OwnerPlayer = TargetPlayer,
				Model = WorldModel,
				ObjectiveInitialized = true,
				ObjectiveActive = true,
				ObjectiveCompleted = false,
				ObjectiveId = "WORLD1_SPIDER",
				RewardState = "Inactive",
				Connections = {},
			}
			CreatedWorlds[TargetPlayer] = WorldInstance
			WorldInstances.Set(TargetPlayer, WorldInstance)
			S.CurrentWorldInstanceId = WorldId
			S.State = "InWorld"
			return true
		end,
	}

	local DestructionService = {
		CompleteObjectiveCalls = 0,
		CompleteObjective = function(self, WorldInstance: any, _WorldInstanceService: any)
			self.CompleteObjectiveCalls += 1
			WorldInstance.ObjectiveCompleted = true
			WorldInstance.ObjectiveActive = false
			WorldInstance.RewardState = "Choosing"
			local Player = WorldInstance.OwnerPlayer
			if Player then
				Player:SetAttribute("ObjectiveActive", false)
			end
			return true
		end,
		TryCompleteObjective = function(self, WorldInstance: any, _Hitbox: any, _Hit: any, WorldInstanceService: any)
			return self:CompleteObjective(WorldInstance, WorldInstanceService)
		end,
		GrantDestruction = function(_, TargetPlayer: any, Amount: number)
			local S = Sessions.Get(TargetPlayer)
			if S then
				S.Destruction += Amount
				TargetPlayer:SetAttribute("Destruction", S.Destruction)
			end
			return true
		end,
	}

	local RewardPortalService = {
		RequestClaimRewardCalls = {},
		RequestClaimReward = function(self, TargetPlayer: any, Choice: string)
			table.insert(self.RequestClaimRewardCalls, { Player = TargetPlayer, Choice = Choice })
			local S = Sessions.Get(TargetPlayer)
			local World = WorldInstances.Get(TargetPlayer)
			if not S or not World or World.RewardState ~= "Choosing" then
				return false
			end
			if Choice == "Free" then
				DestructionService:GrantDestruction(TargetPlayer, 1)
				World.RewardState = "Settled"
				S.State = "InLobby"
				S.CurrentWorldInstanceId = nil
				WorldInstances.Remove(TargetPlayer)
				CreatedWorlds[TargetPlayer] = nil
				return true
			end
			return false
		end,
	}

	local WorldInstanceService = {
		ReturnPlayerToLobby = function(_, TargetPlayer: any)
			local S = Sessions.Get(TargetPlayer)
			if S then
				S.State = "InLobby"
				S.CurrentWorldInstanceId = nil
			end
			WorldInstances.Remove(TargetPlayer)
			CreatedWorlds[TargetPlayer] = nil
			return true
		end,
	}

	local SchedulerJobs = {}
	local Scheduler = {
		AddJob = function(Config: any)
			SchedulerJobs[Config.Name] = Config
		end,
		RemoveJob = function(Name: string)
			SchedulerJobs[Name] = nil
		end,
	}

	local ServiceRegistryServices = {
		GamePassService = GamePassService,
		PortalService = PortalService,
		DestructionService = DestructionService,
		RewardPortalService = RewardPortalService,
		WorldInstanceService = WorldInstanceService,
		Scheduler = Scheduler,
	}
	local ServiceRegistry = {
		Services = ServiceRegistryServices,
		Get = function(...)
			local args = { ... }
			local Name = args[#args]
			local Svc = ServiceRegistryServices[Name]
			if not Svc then
				error("Service not found: " .. tostring(Name))
			end
			return Svc
		end,
		Register = function(...)
			local args = { ... }
			local Svc = args[#args]
			local Name = args[#args - 1]
			ServiceRegistryServices[Name] = Svc
		end,
	}

	local Logger = {
		Info = function() end,
		Warn = function() end,
		Error = function() end,
	}

	local Instance = {
		new = function(ClassName: string)
			if ClassName == "Folder" then
				return childContainer({})
			elseif ClassName == "RemoteEvent" then
				return fakeRemoteEvent("NewRemote")
			end
			return childContainer({})
		end,
	}

	local Game = {
		GetService = function(_, Name: string)
			if Name == "Players" then
				return PlayersService
			elseif Name == "ReplicatedStorage" then
				return ReplicatedStorage
			end
			error("unhandled mock service: " .. Name)
		end,
	}

	local ServicesFolder = {
		Parent = {
			Parent = {
				Core = {
					Registry = {
						RuntimeRegistry = {
							Sessions = Sessions,
							WorldInstances = WorldInstances,
						},
						ServiceRegistry = ServiceRegistry,
					},
					Scheduler = {
						Scheduler = Scheduler,
					},
					Utilities = {
						Logger = Logger,
					},
				},
			},
		},
	}

	local AutoWinsService = loadModule("src/server/Game/Services/AutoWinsService.luau", "AutoWinsService", {
		game = Game,
		Instance = Instance,
		script = { Parent = ServicesFolder },
		require = function(Dependency)
			return Dependency
		end,
	})

	return {
		AutoWinsService = AutoWinsService,
		ToggleAutoWinsRemote = ToggleAutoWinsRemote,
		GamePassService = GamePassService,
		GamePassPrompts = GamePassPrompts,
		PortalService = PortalService,
		PortalSelectMapCalls = PortalSelectMapCalls,
		DestructionService = DestructionService,
		RewardPortalService = RewardPortalService,
		WorldInstanceService = WorldInstanceService,
		Scheduler = Scheduler,
		SchedulerJobs = SchedulerJobs,
		PlayersList = PlayersList,
		PlayersService = PlayersService,
		ServiceRegistry = ServiceRegistry,
		RemotesFolder = RemotesFolder,
	}
end

print("=== Running MVP-006 Task 6 Unit Tests (Auto Wins Loop Service & Controller) ===")

-- Test 1: Toggle remote allows player with HasAutoWins = true to enable/disable
check("Toggle remote allows player with HasAutoWins = true to toggle AutoWinsEnabled", function()
	local H = setupHarness()
	H.AutoWinsService:Init()

	local Player = fakePlayer(1001)
	local Session = fakeSession(Player)
	Session.HasAutoWins = true
	Session.AutoWinsEnabled = false
	Sessions.Set(Player, Session)
	table.insert(H.PlayersList, Player)

	-- Enable
	local Result = H.AutoWinsService:Toggle(Player, true)
	assert(Result == true, "Toggle(true) should return true for pass owner")
	assert(Session.AutoWinsEnabled == true, "Session.AutoWinsEnabled should be true")
	assert(Player:GetAttribute("AutoWinsActive") == true, "Player AutoWinsActive attribute should be true")
	assert(#H.GamePassPrompts == 0, "No GamePass prompt should occur for pass owner")

	-- Disable
	local Result2 = H.AutoWinsService:Toggle(Player, false)
	assert(Result2 == true, "Toggle(false) should return true for pass owner")
	assert(Session.AutoWinsEnabled == false, "Session.AutoWinsEnabled should be false")
	assert(Player:GetAttribute("AutoWinsActive") == false, "Player AutoWinsActive attribute should be false")

	Sessions.Remove(Player)
end)

-- Test 2: Player without HasAutoWins is prompted for GamePass and AutoWinsEnabled remains false
check("Player without HasAutoWins gets prompted and toggle is rejected", function()
	local H = setupHarness()
	H.AutoWinsService:Init()

	local Player = fakePlayer(1002)
	local Session = fakeSession(Player)
	Session.HasAutoWins = false
	Session.AutoWinsEnabled = false
	Sessions.Set(Player, Session)
	table.insert(H.PlayersList, Player)

	local Result = H.AutoWinsService:Toggle(Player, true)
	assert(Result == false, "Toggle should return false when player does not own AutoWins")
	assert(Session.AutoWinsEnabled == false, "AutoWinsEnabled must remain false")
	assert(Player:GetAttribute("AutoWinsActive") == false, "Player AutoWinsActive attribute must be false")
	assert(#H.GamePassPrompts == 1, "GamePassService:Prompt should be called once")
	assert(H.GamePassPrompts[1].Player == Player, "Prompt player matches")
	assert(H.GamePassPrompts[1].PassKey == "AutoWins", "Prompt PassKey is AutoWins")

	Sessions.Remove(Player)
end)

-- Test 3: Frozen session rejects toggle and does not prompt
check("Frozen session rejects toggle", function()
	local H = setupHarness()
	H.AutoWinsService:Init()

	local Player = fakePlayer(1003)
	local Session = fakeSession(Player)
	Session.HasAutoWins = true
	Session.AutoWinsEnabled = false
	Session.ProfileMutationsFrozen = true
	Sessions.Set(Player, Session)
	table.insert(H.PlayersList, Player)

	local Result = H.AutoWinsService:Toggle(Player, true)
	assert(Result == false, "Toggle should return false for frozen session")
	assert(Session.AutoWinsEnabled == false, "AutoWinsEnabled should remain false")
	assert(#H.GamePassPrompts == 0, "No prompt on frozen session")

	Sessions.Remove(Player)
end)

-- Test 4: Remote event invocation triggers Toggle
check("ToggleAutoWins remote event triggers Toggle method on server", function()
	local H = setupHarness()
	H.AutoWinsService:Init()

	local Player = fakePlayer(1004)
	local Session = fakeSession(Player)
	Session.HasAutoWins = true
	Sessions.Set(Player, Session)
	table.insert(H.PlayersList, Player)

	H.ToggleAutoWinsRemote.OnServerEvent:Fire(Player, true)
	assert(Session.AutoWinsEnabled == true, "Remote event should enable AutoWins")
	assert(Player:GetAttribute("AutoWinsActive") == true, "Remote event sets AutoWinsActive attribute")

	H.ToggleAutoWinsRemote.OnServerEvent:Fire(Player, false)
	assert(Session.AutoWinsEnabled == false, "Remote event should disable AutoWins")
	assert(Player:GetAttribute("AutoWinsActive") == false, "Remote event sets AutoWinsActive attribute to false")

	Sessions.Remove(Player)
end)

-- Test 5: AutoWins execution cycle (Lobby -> InWorld -> Objective Complete -> Claim -> Lobby -> Repeat)
check("AutoWins execution cycle loops through World 1 and rewards player", function()
	local H = setupHarness()
	H.AutoWinsService:Init()
	H.AutoWinsService:Start()

	-- Verify Scheduler job registered
	assert(H.SchedulerJobs["AutoWinsLoop"] ~= nil, "AutoWinsLoop job must be registered with Scheduler")
	assert(H.SchedulerJobs["AutoWinsLoop"].IntervalSeconds == 1, "Cadence should be 1 second")

	local Player = fakePlayer(1005)
	local Session = fakeSession(Player)
	Session.HasAutoWins = true
	Session.AutoWinsEnabled = true
	Session.State = "InLobby"
	Session.Bigger = 500
	Session.Destruction = 0
	Sessions.Set(Player, Session)
	table.insert(H.PlayersList, Player)

	-- Cycle 1, Step 1: InLobby -> triggers map entry
	H.AutoWinsService:ProcessLoop()
	assert(#H.PortalSelectMapCalls == 1, "PortalService:SelectMap should be called for lobby player")
	assert(H.PortalSelectMapCalls[1].Player == Player, "Player passed to SelectMap")
	assert(H.PortalSelectMapCalls[1].MapId == "WORLD1", "Target map WORLD1")
	assert(Session.State == "InWorld", "Session transitioned to InWorld")

	local World = WorldInstances.Get(Player)
	assert(World ~= nil, "World instance exists")

	-- Cycle 1, Step 2: InWorld -> completes objective & claims reward -> returns to Lobby
	H.AutoWinsService:ProcessLoop()
	assert(H.DestructionService.CompleteObjectiveCalls == 1, "DestructionService:CompleteObjective called")
	assert(#H.RewardPortalService.RequestClaimRewardCalls == 1, "RequestClaimReward called")
	assert(H.RewardPortalService.RequestClaimRewardCalls[1].Choice == "Free", "Reward choice is Free")
	assert(Session.Destruction == 1, "Destruction stat incremented by 1")
	assert(Session.State == "InLobby", "Session returned to InLobby")
	assert(WorldInstances.Get(Player) == nil, "World instance cleaned up")

	-- Cycle 2: InLobby -> automatically enters World 1 again!
	H.AutoWinsService:ProcessLoop()
	assert(#H.PortalSelectMapCalls == 2, "Second cycle SelectMap called")
	assert(Session.State == "InWorld", "Session transitioned back to InWorld for loop")

	-- Cycle 2, Step 2: Complete & claim again
	H.AutoWinsService:ProcessLoop()
	assert(H.DestructionService.CompleteObjectiveCalls == 2, "Second objective completion")
	assert(Session.Destruction == 2, "Destruction stat incremented to 2")
	assert(Session.State == "InLobby", "Returned to Lobby after second loop")

	Sessions.Remove(Player)
end)

-- Test 6: AutoWins loop halts when disabled, pass unowned, or session frozen
check("AutoWins loop stops when disabled, unowned, or frozen", function()
	local H = setupHarness()
	H.AutoWinsService:Init()

	local Player = fakePlayer(1006)
	local Session = fakeSession(Player)
	Session.HasAutoWins = true
	Session.AutoWinsEnabled = true
	Session.State = "InLobby"
	Sessions.Set(Player, Session)
	table.insert(H.PlayersList, Player)

	-- Case A: Disabled
	Session.AutoWinsEnabled = false
	H.AutoWinsService:ProcessLoop()
	assert(#H.PortalSelectMapCalls == 0, "No map select when AutoWinsEnabled is false")

	-- Case B: Unowned pass
	Session.AutoWinsEnabled = true
	Session.HasAutoWins = false
	H.AutoWinsService:ProcessLoop()
	assert(#H.PortalSelectMapCalls == 0, "No map select when HasAutoWins is false")
	assert(Session.AutoWinsEnabled == false, "AutoWinsEnabled disabled when pass not owned")
	assert(Player:GetAttribute("AutoWinsActive") == false, "Attribute set to false")

	-- Case C: Frozen session
	Session.HasAutoWins = true
	Session.AutoWinsEnabled = true
	Session.ProfileMutationsFrozen = true
	H.AutoWinsService:ProcessLoop()
	assert(#H.PortalSelectMapCalls == 0, "No map select when profile is frozen")

	Sessions.Remove(Player)
end)

-- Test 7: AutoWinsController lifecycle & bindings
check("AutoWinsController: Init, Start, Toggle, and attribute tracking", function()
	local ToggleAutoWinsRemote = fakeRemoteEvent("ToggleAutoWins")
	local RemotesFolder = {
		Name = "Remotes",
		FindFirstChild = function(_, name)
			if name == "ToggleAutoWins" then
				return ToggleAutoWinsRemote
			end
			return nil
		end,
		WaitForChild = function(_, name, _timeout)
			if name == "ToggleAutoWins" then
				return ToggleAutoWinsRemote
			end
			return nil
		end,
	}

	local UIEventBusListeners = {}
	local UIEventBus = {
		Subscribe = function(eventName, callback)
			if not UIEventBusListeners[eventName] then
				UIEventBusListeners[eventName] = {}
			end
			table.insert(UIEventBusListeners[eventName], callback)
			return {
				Disconnect = function()
					local list = UIEventBusListeners[eventName]
					if list then
						local idx = table.find(list, callback)
						if idx then
							table.remove(list, idx)
						end
					end
				end,
			}
		end,
		Publish = function(eventName, ...)
			local list = UIEventBusListeners[eventName]
			if list then
				for _, cb in list do
					cb(...)
				end
			end
		end,
	}

	local LocalPlayer = fakePlayer(9999)
	LocalPlayer:SetAttribute("AutoWinsActive", false)

	local AutoWinsButton = {
		Name = "AutoWins",
		ClassName = "ImageButton",
		Activated = fakeSignal(),
		MouseButton1Click = fakeSignal(),
		IsA = function(_, className)
			return className == "ImageButton" or className == "GuiButton"
		end,
		FindFirstChild = function()
			return nil
		end,
	}

	local LeftSidebar = childContainer({
		AutoWins = AutoWinsButton,
	})
	local PersistentHUD = childContainer({
		LeftSidebar = LeftSidebar,
	})
	local SafeAreaRoot = childContainer({
		PersistentHUD = PersistentHUD,
	})
	local MainHUD = childContainer({
		SafeAreaRoot = SafeAreaRoot,
	})
	local PlayerGui = childContainer({
		MainHUD = MainHUD,
	})
	LocalPlayer.PlayerGui = PlayerGui

	local ReplicatedStorage = childContainer({
		Remotes = RemotesFolder,
	})

	local Game = {
		GetService = function(_, Name: string)
			if Name == "Players" then
				return { LocalPlayer = LocalPlayer }
			elseif Name == "ReplicatedStorage" then
				return ReplicatedStorage
			end
			error("unhandled mock service: " .. Name)
		end,
	}

	local ControllersFolder = {
		WaitForChild = function(_, name)
			if name == "UIEventBus" then
				return UIEventBus
			end
			error("unknown child " .. name)
		end,
	}

	local AutoWinsController = loadModule("src/client/controllers/AutoWinsController.luau", "AutoWinsController", {
		game = Game,
		script = { Parent = ControllersFolder },
		require = function(Dependency)
			if Dependency == UIEventBus then
				return UIEventBus
			end
			return Dependency
		end,
	})

	AutoWinsController.Init()
	AutoWinsController.Start()

	assert(AutoWinsController.IsActive() == false, "Initially inactive")

	-- Toggle via public method
	AutoWinsController.Toggle(true)
	assert(#ToggleAutoWinsRemote.ServerCalls == 1, "Remote fired on toggle")
	assert(ToggleAutoWinsRemote.ServerCalls[1][1] == true, "Remote argument true")

	-- Simulate server attribute update
	LocalPlayer:SetAttribute("AutoWinsActive", true)
	assert(AutoWinsController.IsActive() == true, "IsActive returns true when attribute is true")

	-- Toggle without arg flips state
	AutoWinsController.Toggle()
	assert(#ToggleAutoWinsRemote.ServerCalls == 2, "Remote fired second time")
	assert(ToggleAutoWinsRemote.ServerCalls[2][1] == false, "Toggled to false")

	-- UIEventBus event triggers toggle
	UIEventBus.Publish("ToggleAutoWins", true)
	assert(#ToggleAutoWinsRemote.ServerCalls == 3, "UIEventBus ToggleAutoWins fired remote")
	assert(ToggleAutoWinsRemote.ServerCalls[3][1] == true, "UIEventBus payload passed")

	-- Sidebar button click triggers toggle
	LocalPlayer:SetAttribute("AutoWinsActive", false)
	UIEventBus.Publish("SidebarButtonClicked", "AutoWins")
	assert(#ToggleAutoWinsRemote.ServerCalls == 4, "SidebarButtonClicked AutoWins fired remote")

	AutoWinsController.Destroy()
end)

if #Failures > 0 then
	print(string.format("\n=== %d TESTS FAILED ===", #Failures))
	for _, Failure in Failures do
		print("  - " .. Failure)
	end
	error("MVP-006 Task 6 unit tests failed")
else
	print("\n=== ALL MVP-006 TASK 6 UNIT TESTS PASSED ===")
end
