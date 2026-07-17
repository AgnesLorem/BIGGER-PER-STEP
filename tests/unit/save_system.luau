local task = require("@lune/task")
local fs = require("@lune/fs")
local luau = require("@lune/luau")
local PlayerProfileSchema = require("../../src/server/Core/Utilities/PlayerProfileSchema")
local SaveConfig = require("../../src/server/Core/Config/SaveConfig")
local Profiles = require("../../src/server/Core/Registry/RuntimeRegistry/Profiles")
local Sessions = require("../../src/server/Core/Registry/RuntimeRegistry/Sessions")

local function expectError(Callback)
	local Success = pcall(Callback)
	assert(Success == false)
end

local function repeated(Character, Count)
	return string.rep(Character, Count)
end

local function dictionary(Prefix, Count)
	local Result = {}
	for Index = 1, Count do
		Result[Prefix .. tostring(Index)] = true
	end
	return Result
end

local Defaults = PlayerProfileSchema.Defaults()
assert(Defaults.SchemaVersion == 1)
assert(Defaults.Bigger == 1)
assert(Defaults.Destruction == 0)
assert(Defaults.Rebirth == 0)
assert(next(Defaults.UnlockedGrowthUpgrades) == nil)
assert(Defaults.EquippedGrowthUpgrade == nil)
assert(next(Defaults.CompletedPortals) == nil)
assert(Defaults.Settings.SoundEnabled == true)
assert(Defaults.Settings.MusicEnabled == true)
assert(Defaults.HasDoubleMultiplier == false)
assert(Defaults.HasVip == false)
assert(next(Defaults.ProcessedPurchaseIds) == nil)
assert(Defaults.LastActiveTimestamp == 0)
assert(Defaults.LastLogoutTimestamp == 0)
assert(Defaults.LastSaveTimestamp == 0)
assert(Defaults.LeaseOwner == nil)
assert(Defaults.LeaseExpiresAt == nil)

local Legacy = PlayerProfileSchema.Normalize({ Bigger = 12, UnknownLegacyField = "discard" })
assert(Legacy.Bigger == 12)
assert(Legacy.SchemaVersion == 1)
assert(Legacy.UnknownLegacyField == nil)

expectError(function()
	PlayerProfileSchema.Normalize("not a table")
end)
expectError(function()
	PlayerProfileSchema.Normalize({ SchemaVersion = 2 })
end)
expectError(function()
	PlayerProfileSchema.Normalize({ Bigger = 0 })
end)
expectError(function()
	PlayerProfileSchema.Normalize({ Bigger = 0 / 0 })
end)
expectError(function()
	PlayerProfileSchema.Normalize({ Bigger = math.huge })
end)
expectError(function()
	PlayerProfileSchema.Normalize({ Bigger = 9007199254740992 })
end)
expectError(function()
	PlayerProfileSchema.Normalize({ Settings = { SoundEnabled = true, Unknown = false } })
end)

local AtUpgradeLimit = PlayerProfileSchema.Normalize({
	UnlockedGrowthUpgrades = dictionary("Upgrade_", 64),
})
assert(AtUpgradeLimit.UnlockedGrowthUpgrades.Upgrade_64 == true)
expectError(function()
	PlayerProfileSchema.Normalize({ UnlockedGrowthUpgrades = dictionary("Upgrade_", 65) })
end)

local AtPortalLimit = PlayerProfileSchema.Normalize({
	CompletedPortals = dictionary("Portal_", 256),
})
assert(AtPortalLimit.CompletedPortals.Portal_256 == true)
expectError(function()
	PlayerProfileSchema.Normalize({ CompletedPortals = dictionary("Portal_", 257) })
end)

local Content64 = repeated("A", 64)
assert(PlayerProfileSchema.IsContentId(Content64) == true)
assert(PlayerProfileSchema.IsContentId(repeated("A", 65)) == false)
assert(PlayerProfileSchema.IsContentId("bad id") == false)

local Purchase128 = repeated("P", 128)
assert(PlayerProfileSchema.IsPurchaseId(Purchase128) == true)
assert(PlayerProfileSchema.IsPurchaseId(repeated("P", 129)) == false)
assert(PlayerProfileSchema.IsPurchaseId("bad/id") == false)

local AtReceiptLimit = PlayerProfileSchema.Normalize({
	ProcessedPurchaseIds = dictionary("Purchase:", 5000),
})
assert(AtReceiptLimit.ProcessedPurchaseIds["Purchase:5000"] == true)
expectError(function()
	PlayerProfileSchema.Normalize({ ProcessedPurchaseIds = dictionary("Purchase:", 5001) })
end)

expectError(function()
	PlayerProfileSchema.Normalize({ EquippedGrowthUpgrade = "Upgrade_1" })
end)
local Equipped = PlayerProfileSchema.Normalize({
	UnlockedGrowthUpgrades = { Upgrade_1 = true },
	EquippedGrowthUpgrade = "Upgrade_1",
})
assert(Equipped.EquippedGrowthUpgrade == "Upgrade_1")

local NewProfile, NewOfflineReward = PlayerProfileSchema.Acquire(nil, 1000, "server-a", 1180, 4)
assert(NewOfflineReward == 0)
assert(NewProfile.Bigger == 1)
assert(NewProfile.LeaseOwner == "server-a")
assert(NewProfile.LeaseExpiresAt == 1180)
assert(NewProfile.LastActiveTimestamp == 1000)
assert(NewProfile.LastSaveTimestamp == 1000)

local LegacyProfile, LegacyOfflineReward = PlayerProfileSchema.Acquire({ Bigger = 3 }, 1000, "server-a", 1180, 4)
assert(LegacyOfflineReward == 0)
assert(LegacyProfile.Bigger == 3)

assert(SaveConfig.StoreName == "BiggerPlayerProfiles_v1")
assert(SaveConfig.ProductionPlaceId == 104031194350622)
assert(SaveConfig.ResolveScope(true, SaveConfig.ProductionPlaceId) == "Studio")
assert(SaveConfig.ResolveScope(false, SaveConfig.ProductionPlaceId) == "Production")
expectError(function()
	SaveConfig.ResolveScope(false, 123)
end)
assert(SaveConfig.ProfileKey(42) == "Player_42")
expectError(function()
	SaveConfig.ProfileKey(0)
end)

local function await(Request)
	local Success, Value = Profiles.Await(Request)
	assert(Success == true)
	return Value
end

local FirstEntry = Profiles.Create(1001, "owner-1001", function()
	return 1
end)
expectError(function()
	Profiles.Create(1001, "duplicate", function()
		return 1
	end)
end)
expectError(function()
	Profiles.Enqueue(FirstEntry, "Autosave", function() end)
end)

local Order = {}
local LoadRequest = Profiles.Enqueue(FirstEntry, "Load", function()
	table.insert(Order, "load")
	return "loaded"
end)
local ReceiptRequest = Profiles.Enqueue(FirstEntry, "Receipt", function()
	table.insert(Order, "receipt")
	return "durable"
end)
assert(await(LoadRequest) == "loaded")
assert(await(ReceiptRequest) == "durable")
assert(table.concat(Order, ",") == "load,receipt")

local AutosaveRuns = 0
local AutosaveA = Profiles.Enqueue(FirstEntry, "Autosave", function()
	AutosaveRuns += 1
	task.wait()
	return "saved"
end)
local AutosaveB = Profiles.Enqueue(FirstEntry, "Autosave", function()
	AutosaveRuns += 1
	return "unexpected"
end)
assert(AutosaveA == AutosaveB)
assert(await(AutosaveA) == "saved")
assert(AutosaveRuns == 1)

local ReceiptRuns = 0
local ReceiptA = Profiles.Enqueue(FirstEntry, "Receipt", function()
	ReceiptRuns += 1
end)
local ReceiptB = Profiles.Enqueue(FirstEntry, "Receipt", function()
	ReceiptRuns += 1
end)
assert(ReceiptA ~= ReceiptB)
await(ReceiptA)
await(ReceiptB)
assert(ReceiptRuns == 2)

local ActiveCallbacks = 0
local MaximumActiveCallbacks = 0
local function concurrentCallback()
	ActiveCallbacks += 1
	MaximumActiveCallbacks = math.max(MaximumActiveCallbacks, ActiveCallbacks)
	task.wait()
	ActiveCallbacks -= 1
end
local SecondEntry = Profiles.Create(1002, "owner-1002", function()
	return 1
end)
local SecondLoad = Profiles.Enqueue(SecondEntry, "Load", concurrentCallback)
local ParallelSaveA = Profiles.Enqueue(FirstEntry, "Receipt", concurrentCallback)
await(SecondLoad)
await(ParallelSaveA)
assert(MaximumActiveCallbacks == 2)

local FailureRequest = Profiles.Enqueue(FirstEntry, "Receipt", function()
	error("expected worker failure")
end)
local FailureSuccess, FailureError = Profiles.Await(FailureRequest)
assert(FailureSuccess == false)
assert(string.find(FailureError, "expected worker failure", 1, true) ~= nil)
assert(string.find(FirstEntry.LastError, "expected worker failure", 1, true) ~= nil)

local MultiResultRequest = Profiles.Enqueue(FirstEntry, "Receipt", function()
	return "first", "second"
end)
local MultiResultSuccess, FirstResult, SecondResult = Profiles.Await(MultiResultRequest)
assert(MultiResultSuccess == true)
assert(FirstResult == "first")
assert(SecondResult == "second")

local SerialEntry = Profiles.Create(1003, "owner-1003", function()
	return 1
end)
await(Profiles.Enqueue(SerialEntry, "Load", function() end))
local SerialActive = 0
local SerialMaximum = 0
local function serialCallback()
	SerialActive += 1
	SerialMaximum = math.max(SerialMaximum, SerialActive)
	task.wait()
	SerialActive -= 1
end
local SerialA = Profiles.Enqueue(SerialEntry, "Receipt", serialCallback)
local SerialB = Profiles.Enqueue(SerialEntry, "Receipt", serialCallback)
await(SerialA)
await(SerialB)
assert(SerialMaximum == 1)
Profiles.Remove(1003, SerialEntry)

local CoalescedCallbackResults = {}
local CoalescedA = Profiles.Enqueue(FirstEntry, "Autosave", function()
	task.wait()
	return "coalesced"
end, function(Success, Value)
	table.insert(CoalescedCallbackResults, { Success, Value })
end)
local CoalescedB = Profiles.Enqueue(FirstEntry, "Autosave", function()
	return "unexpected"
end, function(Success, Value)
	table.insert(CoalescedCallbackResults, { Success, Value })
end)
assert(CoalescedA == CoalescedB)
assert(await(CoalescedA) == "coalesced")
assert(#CoalescedCallbackResults == 2)
assert(CoalescedCallbackResults[1][1] == true and CoalescedCallbackResults[1][2] == "coalesced")
assert(CoalescedCallbackResults[2][1] == true and CoalescedCallbackResults[2][2] == "coalesced")

local ChainedAutosaveRuns = 0
local ChainedAutosaveB
local ChainedAutosaveA = Profiles.Enqueue(FirstEntry, "Autosave", function()
	ChainedAutosaveRuns += 1
	task.wait()
end, function()
	ChainedAutosaveB = Profiles.Enqueue(FirstEntry, "Autosave", function()
		ChainedAutosaveRuns += 1
	end)
end)
await(ChainedAutosaveA)
task.wait()
assert(ChainedAutosaveB ~= nil)
assert(ChainedAutosaveB ~= ChainedAutosaveA)
await(ChainedAutosaveB)
assert(ChainedAutosaveRuns == 2)

local FinalRequest = Profiles.Enqueue(FirstEntry, "Final", function()
	table.insert(Order, "final")
	return "released"
end)
assert(await(FinalRequest) == "released")
assert(FirstEntry.Released == true)
assert(FirstEntry.Phase == "Released")
expectError(function()
	Profiles.Enqueue(FirstEntry, "Receipt", function() end)
end)
task.wait()
assert(Profiles.Get(1001) == nil)

local RejoinedEntry = Profiles.Create(1001, "owner-1001-rejoin", function()
	return 1
end)
Profiles.Remove(1001, RejoinedEntry)

local LoadFailureEntry = Profiles.Create(1004, "owner-1004", function()
	return 1
end)
local LoadFailureRequest = Profiles.Enqueue(LoadFailureEntry, "Load", function()
	task.wait()
	error("expected load failure")
end)
local QueuedAfterLoadFailure = Profiles.Enqueue(LoadFailureEntry, "Receipt", function()
	error("must not run after load failure")
end)
task.wait(0.05)
assert(LoadFailureRequest.Completed == true)
assert(LoadFailureRequest.Success == false)
assert(QueuedAfterLoadFailure.Completed == true)
assert(QueuedAfterLoadFailure.Success == false)
assert(Profiles.Get(1004) == nil)

local FinalFailureEntry = Profiles.Create(1005, "owner-1005", function()
	return 1
end)
await(Profiles.Enqueue(FinalFailureEntry, "Load", function() end))
local FailedFinal = Profiles.Enqueue(FinalFailureEntry, "Final", function()
	error("expected final failure")
end)
local FailedFinalSuccess = Profiles.Await(FailedFinal)
assert(FailedFinalSuccess == false)
assert(FinalFailureEntry.Phase == "Releasing")
assert(FinalFailureEntry.Released == false)
assert(Profiles.Get(1005) == FinalFailureEntry)
expectError(function()
	Profiles.Create(1005, "blocked-rejoin", function()
		return 1
	end)
end)
assert(await(Profiles.Enqueue(FinalFailureEntry, "Final", function()
	return "retried"
end)) == "retried")
task.wait()
assert(Profiles.Get(1005) == nil)

local MultipleFinalEntry = Profiles.Create(1006, "owner-1006", function()
	return 1
end)
await(Profiles.Enqueue(MultipleFinalEntry, "Load", function() end))
local FinalRuns = 0
local FinalA = Profiles.Enqueue(MultipleFinalEntry, "Final", function()
	FinalRuns += 1
	task.wait()
	return "player-removing"
end)
local FinalB = Profiles.Enqueue(MultipleFinalEntry, "Final", function()
	FinalRuns += 1
	return "shutdown"
end)
assert(FinalA ~= FinalB)
task.wait(0.05)
assert(FinalA.Completed == true)
assert(FinalB.Completed == true)
assert(FinalRuns == 2)
assert(Profiles.Get(1006) == nil)

Profiles.Remove(1001, FirstEntry)
Profiles.Remove(1002, SecondEntry)

local function loadSaveService(StoredProfile)
	local PlayerRemovingCallbacks = {}
	local Players = {
		CharacterAutoLoads = true,
		Players = {},
		PlayerRemoving = {
			Connect = function(_, Callback)
				table.insert(PlayerRemovingCallbacks, Callback)
			end,
		},
	}
	function Players:GetPlayers()
		return self.Players
	end

	local Store = {
		Data = { Player_2001 = StoredProfile },
		UpdateCalls = 0,
		FailWrites = 0,
	}
	function Store:UpdateAsync(Key, Transform)
		self.UpdateCalls += 1
		if self.FailWrites > 0 then
			self.FailWrites -= 1
			error("expected datastore failure")
		end
		local Updated = Transform(self.Data[Key])
		if Updated ~= nil then
			self.Data[Key] = Updated
		end
		return self.Data[Key]
	end

	local DataStoreService = {
		StoreName = nil,
		Scope = nil,
	}
	function DataStoreService:GetDataStore(StoreName, Scope)
		self.StoreName = StoreName
		self.Scope = Scope
		return Store
	end

	local RunService = {}
	function RunService:IsStudio()
		return true
	end
	local HttpService = {}
	function HttpService:GenerateGUID()
		return "guid-test"
	end

	local Scheduler = { Jobs = {} }
	function Scheduler.AddJob(Config)
		Scheduler.Jobs[Config.Name] = Config
	end

	local Logger = {}
	function Logger.Info() end
	function Logger.Warn() end
	function Logger.Error(_, Message, ...)
		error(string.format(Message, ...))
	end

	local FakeTask = { Delays = {} }
	function FakeTask.wait(Delay)
		table.insert(FakeTask.Delays, Delay)
		return Delay or 0
	end

	local ServicesFolder = {}
	local CoreFolder = {
		Config = { SaveConfig = SaveConfig },
		Registry = { RuntimeRegistry = { Profiles = Profiles, Sessions = Sessions } },
		Scheduler = { Scheduler = Scheduler },
		Utilities = { Logger = Logger, PlayerProfileSchema = PlayerProfileSchema },
	}
	ServicesFolder.Parent = CoreFolder
	local Script = { Parent = ServicesFolder }
	local Game = {
		JobId = "job-test",
		PlaceId = SaveConfig.ProductionPlaceId,
	}
	function Game:GetService(Name)
		if Name == "Players" then
			return Players
		elseif Name == "DataStoreService" then
			return DataStoreService
		elseif Name == "RunService" then
			return RunService
		elseif Name == "HttpService" then
			return HttpService
		end
		error("unexpected service: " .. Name)
	end

	local Source = fs.readFile("src/server/Core/Services/SaveService.luau")
	local Chunk = luau.load(Source, "SaveService")
	setfenv(
		Chunk,
		setmetatable({
			game = Game,
			script = Script,
			task = FakeTask,
			os = {
				time = function()
					return 1000
				end,
			},
			require = function(Dependency)
				return Dependency
			end,
		}, { __index = getfenv() })
	)

	local Player = {
		UserId = 2001,
		Name = "LifecyclePlayer",
		Kicked = nil,
	}
	function Player:Kick(Message)
		self.Kicked = Message
	end

	return Chunk(),
		{
			DataStoreService = DataStoreService,
			FakeTask = FakeTask,
			Player = Player,
			Players = Players,
			Scheduler = Scheduler,
			Store = Store,
		}
end

local ExistingRuntime = Profiles.Get(2001)
if ExistingRuntime then
	Profiles.Remove(2001, ExistingRuntime)
end

local LifecycleSaveService, Lifecycle = loadSaveService(nil)
LifecycleSaveService:Init()
assert(Lifecycle.Players.CharacterAutoLoads == false)
assert(Lifecycle.DataStoreService.StoreName == SaveConfig.StoreName)
assert(Lifecycle.DataStoreService.Scope == "Studio")
assert(type(LifecycleSaveService.IsProfileWritable) == "function")
assert(type(LifecycleSaveService.FreezeMutations) == "function")
assert(type(LifecycleSaveService.ReleaseProfile) == "function")

local LoadedProfile = LifecycleSaveService:LoadProfile(Lifecycle.Player)
assert(Lifecycle.Store.UpdateCalls == 1)
assert(LoadedProfile.Bigger == 1)
assert(LoadedProfile.LeaseOwner == "job-test")
assert(LoadedProfile.LeaseExpiresAt == 1180)
local LifecycleEntry = Profiles.Get(2001)
assert(LifecycleEntry ~= nil)
assert(LifecycleEntry.Phase == "Active")

local function sessionFromProfile(Player, Profile)
	return {
		Player = Player,
		Bigger = Profile.Bigger,
		Destruction = Profile.Destruction,
		Rebirth = Profile.Rebirth,
		UnlockedGrowthUpgrades = Profile.UnlockedGrowthUpgrades,
		EquippedGrowthUpgrade = Profile.EquippedGrowthUpgrade,
		CompletedPortals = Profile.CompletedPortals,
		Settings = Profile.Settings,
		HasDoubleMultiplier = Profile.HasDoubleMultiplier,
		HasVip = Profile.HasVip,
		PurchaseHistory = Profile.ProcessedPurchaseIds,
		LastActiveTimestamp = Profile.LastActiveTimestamp,
		LastLogoutTimestamp = Profile.LastLogoutTimestamp,
		LastSaveTimestamp = Profile.LastSaveTimestamp,
		ProfileMutationsFrozen = false,
		State = "InLobby",
		JoinedAt = 1000,
	}
end

local LifecycleSession = sessionFromProfile(Lifecycle.Player, LoadedProfile)
Sessions.Set(Lifecycle.Player, LifecycleSession)
assert(LifecycleSaveService:IsProfileWritable(Lifecycle.Player) == true)
LifecycleSaveService:Start()
local AutosaveJob = Lifecycle.Scheduler.Jobs.ProfileAutosave
assert(AutosaveJob ~= nil)
assert(AutosaveJob.IntervalSeconds == 60)

local BeforeSaveCalls = Lifecycle.Store.UpdateCalls
LifecycleSession.Bigger = 25
LifecycleSaveService:SaveProfile(Lifecycle.Player)
assert(Lifecycle.Store.UpdateCalls == BeforeSaveCalls + 1)
assert(Lifecycle.Store.Data.Player_2001.Bigger == 25)
assert(Lifecycle.Store.Data.Player_2001.LeaseOwner == "job-test")
assert(Lifecycle.Store.Data.Player_2001.LastLogoutTimestamp == 0)

Lifecycle.Store.FailWrites = 2
table.clear(Lifecycle.FakeTask.Delays)
LifecycleSaveService:SaveProfile(Lifecycle.Player)
assert(table.concat(Lifecycle.FakeTask.Delays, ",") == "1,2")

assert(LifecycleSaveService:ReleaseProfile(Lifecycle.Player) == true)
assert(LifecycleSession.ProfileMutationsFrozen == true)
assert(Lifecycle.Store.Data.Player_2001.LeaseOwner == nil)
assert(Lifecycle.Store.Data.Player_2001.LeaseExpiresAt == nil)
assert(Lifecycle.Store.Data.Player_2001.LastLogoutTimestamp == 1000)
assert(Profiles.Get(2001) == nil)
Sessions.Remove(Lifecycle.Player)

local ForeignProfile = PlayerProfileSchema.Defaults()
ForeignProfile.LeaseOwner = "foreign-server"
ForeignProfile.LeaseExpiresAt = 2000
local ForeignSaveService, Foreign = loadSaveService(ForeignProfile)
ForeignSaveService:Init()
local ForeignLoadSuccess, ForeignLoadError = pcall(ForeignSaveService.LoadProfile, ForeignSaveService, Foreign.Player)
assert(ForeignLoadSuccess == false)
assert(string.find(ForeignLoadError, "unexpired foreign lease", 1, true) ~= nil)
assert(Foreign.Store.UpdateCalls == 5)
assert(table.concat(Foreign.FakeTask.Delays, ",") == "1,2,4,8")
assert(Profiles.Get(2001) == nil)

local OwnershipSaveService, Ownership = loadSaveService(nil)
OwnershipSaveService:Init()
local OwnershipProfile = OwnershipSaveService:LoadProfile(Ownership.Player)
local OwnershipSession = sessionFromProfile(Ownership.Player, OwnershipProfile)
Sessions.Set(Ownership.Player, OwnershipSession)
Ownership.Store.Data.Player_2001.LeaseOwner = "foreign-server"
Ownership.Store.Data.Player_2001.LeaseExpiresAt = 2000
OwnershipSaveService:SaveProfile(Ownership.Player)
assert(OwnershipSession.ProfileMutationsFrozen == true)
assert(Ownership.Player.Kicked ~= nil)
local OwnershipEntry = Profiles.Get(2001)
assert(OwnershipEntry ~= nil)
Profiles.Remove(2001, OwnershipEntry)
Sessions.Remove(Ownership.Player)

local SaveSource = fs.readFile("src/server/Core/Services/SaveService.luau")
assert(string.find(SaveSource, ":UpdateAsync", 1, true) ~= nil)
assert(string.find(SaveSource, ":SetAsync", 1, true) == nil)
assert(string.find(SaveSource, ":GetAsync", 1, true) == nil)

local function loadSessionService()
	local AddedCallbacks = {}
	local RemovingCallbacks = {}
	local Players = {
		PlayerAdded = {
			Connect = function(_, Callback)
				table.insert(AddedCallbacks, Callback)
			end,
		},
		PlayerRemoving = {
			Connect = function(_, Callback)
				table.insert(RemovingCallbacks, Callback)
			end,
		},
	}
	function Players:GetPlayers()
		return {}
	end

	local SaveService = {
		FailLoad = false,
		ReleaseSawSession = false,
	}
	function SaveService:LoadProfile()
		if self.FailLoad then
			error("expected controlled load failure")
		end
		return PlayerProfileSchema.Defaults()
	end
	function SaveService:FreezeMutations(Player)
		local Session = Sessions.Get(Player)
		if Session then
			Session.ProfileMutationsFrozen = true
		end
		return Session ~= nil
	end
	function SaveService:ReleaseProfile(Player)
		self.ReleaseSawSession = Sessions.Get(Player) ~= nil
		return true
	end

	local EventBus = { Publish = function() end }
	local GrowthService = { UpdateMultiplierAttribute = function() end }
	local Logger = { Info = function() end, Warn = function() end }
	local ServicesFolder = { SaveService = SaveService, GrowthService = GrowthService }
	local CoreFolder = {
		Events = { EventBus = EventBus },
		Registry = { RuntimeRegistry = { Sessions = Sessions } },
		Utilities = { Logger = Logger },
	}
	ServicesFolder.Parent = CoreFolder
	local Game = {}
	function Game:GetService(Name)
		assert(Name == "Players")
		return Players
	end

	local FakeInstance = {}
	function FakeInstance.new(ClassName)
		return {
			ClassName = ClassName,
			IsA = function(self, Expected)
				return self.ClassName == Expected
			end,
		}
	end

	local Source = fs.readFile("src/server/Core/Services/SessionService.luau")
	local Chunk = luau.load(Source, "SessionService")
	setfenv(
		Chunk,
		setmetatable({
			game = Game,
			script = { Parent = ServicesFolder },
			Instance = FakeInstance,
			task = task,
			tick = function()
				return 1000
			end,
			require = function(Dependency)
				return Dependency
			end,
		}, { __index = getfenv() })
	)

	local Player = {
		UserId = 3001,
		Name = "SessionPlayer",
		Attributes = {},
		Kicked = nil,
		LoadCharacterCalls = 0,
	}
	function Player:SetAttribute(Key, Value)
		self.Attributes[Key] = Value
	end
	function Player:LoadCharacter()
		self.LoadCharacterCalls += 1
	end
	function Player:Kick(Message)
		self.Kicked = Message
	end
	function Player:FindFirstChild()
		return nil
	end

	return Chunk(),
		{
			AddedCallbacks = AddedCallbacks,
			Player = Player,
			RemovingCallbacks = RemovingCallbacks,
			SaveService = SaveService,
		}
end

local LifecycleSessionService, SessionLifecycle = loadSessionService()
LifecycleSessionService:Init()
SessionLifecycle.SaveService.FailLoad = true
local FailedJoinCallback = SessionLifecycle.AddedCallbacks[1]
local FailedJoinSuccess = pcall(FailedJoinCallback, SessionLifecycle.Player)
assert(FailedJoinSuccess == true)
assert(Sessions.Get(SessionLifecycle.Player) == nil)
assert(SessionLifecycle.Player.Kicked ~= nil)
assert(SessionLifecycle.Player.LoadCharacterCalls == 0)

SessionLifecycle.SaveService.FailLoad = false
SessionLifecycle.Player.Kicked = nil
FailedJoinCallback(SessionLifecycle.Player)
local AuthoritativeSession = Sessions.Get(SessionLifecycle.Player)
assert(AuthoritativeSession ~= nil)
assert(AuthoritativeSession.ProfileMutationsFrozen == false)
assert(AuthoritativeSession.UnlockedGrowthUpgrades ~= nil)
assert(AuthoritativeSession.Settings ~= nil)
assert(SessionLifecycle.Player.LoadCharacterCalls == 1)

SessionLifecycle.RemovingCallbacks[1](SessionLifecycle.Player)
assert(SessionLifecycle.SaveService.ReleaseSawSession == true)
assert(Sessions.Get(SessionLifecycle.Player) == nil)

local BootstrapSource = fs.readFile("src/server/Core/Bootstrap/CoreBootstrap.luau")
local SaveBootIndex = assert(string.find(BootstrapSource, '{ Name = "SaveService"', 1, true))
local SessionBootIndex = assert(string.find(BootstrapSource, '{ Name = "SessionService"', 1, true))
assert(SaveBootIndex < SessionBootIndex)

local FrozenPlayer = { UserId = 4001, Name = "FrozenPlayer" }
local FrozenProfile = PlayerProfileSchema.Defaults()
local FrozenSession = sessionFromProfile(FrozenPlayer, FrozenProfile)
FrozenSession.ProfileMutationsFrozen = true
Sessions.Set(FrozenPlayer, FrozenSession)

local function persistentSnapshot(Session)
	return PlayerProfileSchema.Normalize({
		SchemaVersion = 1,
		Bigger = Session.Bigger,
		Destruction = Session.Destruction,
		Rebirth = Session.Rebirth,
		UnlockedGrowthUpgrades = Session.UnlockedGrowthUpgrades,
		EquippedGrowthUpgrade = Session.EquippedGrowthUpgrade,
		CompletedPortals = Session.CompletedPortals,
		Settings = Session.Settings,
		HasDoubleMultiplier = Session.HasDoubleMultiplier,
		HasVip = Session.HasVip,
		ProcessedPurchaseIds = Session.PurchaseHistory,
		LastActiveTimestamp = Session.LastActiveTimestamp,
		LastLogoutTimestamp = Session.LastLogoutTimestamp,
		LastSaveTimestamp = Session.LastSaveTimestamp,
	})
end

local function deepEqual(Left, Right)
	if type(Left) ~= type(Right) then
		return false
	end
	if type(Left) ~= "table" then
		return Left == Right
	end
	for Key, Value in Left do
		if not deepEqual(Value, Right[Key]) then
			return false
		end
	end
	for Key in Right do
		if Left[Key] == nil then
			return false
		end
	end
	return true
end

local BeforeFrozenMutations = persistentSnapshot(FrozenSession)
local FrozenMutations = {
	function(Session)
		Session.Bigger = 99
	end,
	function(Session)
		Session.Destruction = 99
	end,
	function(Session)
		Session.Rebirth = 99
	end,
	function(Session)
		Session.UnlockedGrowthUpgrades.Upgrade_1 = true
	end,
	function(Session)
		Session.EquippedGrowthUpgrade = "Upgrade_1"
	end,
	function(Session)
		Session.CompletedPortals.Portal_1 = true
	end,
	function(Session)
		Session.Settings.SoundEnabled = false
	end,
	function(Session)
		Session.HasDoubleMultiplier = true
	end,
	function(Session)
		Session.HasVip = true
	end,
	function(Session)
		Session.PurchaseHistory["Purchase:Frozen"] = true
	end,
}
for _, Mutation in FrozenMutations do
	assert(Sessions.Mutate(FrozenPlayer, Mutation) == false)
end
local AfterFrozenMutations = persistentSnapshot(FrozenSession)
assert(deepEqual(BeforeFrozenMutations, AfterFrozenMutations))
Sessions.Remove(FrozenPlayer)

local function offlineProfile(LastActiveTimestamp, LastLogoutTimestamp, Bigger)
	local Profile = PlayerProfileSchema.Defaults()
	Profile.Bigger = Bigger or 1
	Profile.LastActiveTimestamp = LastActiveTimestamp
	Profile.LastLogoutTimestamp = LastLogoutTimestamp
	return Profile
end

local OneMinuteProfile, OneMinuteReward = PlayerProfileSchema.Acquire(offlineProfile(940, 0), 1000, "offline", 1180, 1)
assert(OneMinuteReward == 30)
assert(OneMinuteProfile.Bigger == 31)

local DoubleProfile, DoubleReward = PlayerProfileSchema.Acquire(offlineProfile(940, 0), 1000, "offline", 1180, 2)
assert(DoubleReward == 60)
assert(DoubleProfile.Bigger == 61)

local QuadProfile, QuadReward = PlayerProfileSchema.Acquire(offlineProfile(940, 0), 1000, "offline", 1180, 4)
assert(QuadReward == 120)
assert(QuadProfile.Bigger == 121)

local FractionalProfile, FractionalReward =
	PlayerProfileSchema.Acquire(offlineProfile(881, 0), 1000, "offline", 1180, 1)
assert(FractionalReward == 59)
assert(FractionalProfile.Bigger == 60)

local FutureProfile, FutureReward = PlayerProfileSchema.Acquire(offlineProfile(1200, 0), 1000, "offline", 1180, 1)
assert(FutureReward == 0)
assert(FutureProfile.Bigger == 1)

local CappedProfile, CappedReward = PlayerProfileSchema.Acquire(offlineProfile(1, 0), 100000, "offline", 100180, 1)
assert(CappedReward == 14400)
assert(CappedProfile.Bigger == 14401)
local CappedQuadProfile, CappedQuadReward =
	PlayerProfileSchema.Acquire(offlineProfile(1, 0), 100000, "offline", 100180, 4)
assert(CappedQuadReward == 57600)
assert(CappedQuadProfile.Bigger == 57601)

local SavedTimestampProfile = PlayerProfileSchema.Save(OneMinuteProfile, 1100, "offline", 1280)
assert(SavedTimestampProfile.LastActiveTimestamp == 1100)
assert(SavedTimestampProfile.LastSaveTimestamp == 1100)
assert(SavedTimestampProfile.LastLogoutTimestamp == 0)
local ReleasedTimestampProfile = PlayerProfileSchema.Release(SavedTimestampProfile, 1200, "offline")
assert(ReleasedTimestampProfile.LastActiveTimestamp == 1200)
assert(ReleasedTimestampProfile.LastLogoutTimestamp == 1200)
assert(ReleasedTimestampProfile.LastSaveTimestamp == 1200)
local ReconnectedProfile, ReconnectedReward =
	PlayerProfileSchema.Acquire(ReleasedTimestampProfile, 1200, "offline-next", 1380, 1)
assert(ReconnectedReward == 0)
assert(ReconnectedProfile.Bigger == ReleasedTimestampProfile.Bigger)

local OverflowProfile = offlineProfile(940, 0, PlayerProfileSchema.MaximumSafeInteger)
expectError(function()
	PlayerProfileSchema.Acquire(OverflowProfile, 1000, "offline", 1180, 1)
end)

local EntitledStoredProfile = offlineProfile(400, 0)
EntitledStoredProfile.HasDoubleMultiplier = true
EntitledStoredProfile.HasVip = true
local EntitledSaveService, Entitled = loadSaveService(EntitledStoredProfile)
EntitledSaveService:Init()
local EntitledLoaded = EntitledSaveService:LoadProfile(Entitled.Player)
assert(EntitledLoaded.Bigger == 1201)
local EntitledEntry = Profiles.Get(2001)
assert(EntitledEntry ~= nil)
Profiles.Remove(2001, EntitledEntry)

print("save_system: PASS")
