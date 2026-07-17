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
		ApparentErrors = 0,
		BeforeUpdate = nil,
	}
	function Store:UpdateAsync(Key, Transform)
		self.UpdateCalls += 1
		if self.BeforeUpdate then
			local Callback = self.BeforeUpdate
			self.BeforeUpdate = nil
			Callback()
		end
		if self.FailWrites > 0 then
			self.FailWrites -= 1
			error("expected datastore failure")
		end
		local Updated = Transform(self.Data[Key])
		if Updated ~= nil then
			self.Data[Key] = Updated
		end
		if self.ApparentErrors > 0 then
			self.ApparentErrors -= 1
			error("expected apparent datastore failure")
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
		Config = { SaveConfig = SaveConfig },
		Events = { EventBus = EventBus },
		Registry = { RuntimeRegistry = { Profiles = Profiles, Sessions = Sessions } },
		Utilities = { Logger = Logger },
	}
	ServicesFolder.Parent = CoreFolder
	local Game = {}
	function Game:GetService(Name)
		assert(Name == "Players")
		return Players
	end
	function Game:BindToClose() end

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

local function loadShutdownSessionService(BlockedUserId)
	local ShutdownCallbacks = {}
	local Players = { Players = {} }
	function Players:GetPlayers()
		return self.Players
	end
	Players.PlayerAdded = { Connect = function() end }
	Players.PlayerRemoving = { Connect = function() end }

	local Clock = 0
	local FakeTask = {}
	function FakeTask.spawn(Callback, ...)
		return task.spawn(Callback, ...)
	end
	function FakeTask.wait()
		Clock += 0.1
		task.wait()
	end

	local ReleaseBlocked = BlockedUserId ~= nil
	local SaveService = {
		ActiveReleases = 0,
		AllFrozenAtRelease = true,
		MaximumActiveReleases = 0,
		ReleaseCalls = 0,
		SaveCalls = 0,
	}
	function SaveService:LoadProfile()
		return PlayerProfileSchema.Defaults()
	end
	function SaveService:FreezeMutations(Player)
		local Session = Sessions.Get(Player)
		if Session then
			Session.ProfileMutationsFrozen = true
		end
		return Session ~= nil
	end
	function SaveService:SaveProfile()
		self.SaveCalls += 1
	end
	function SaveService:ReleaseProfile(Player)
		self.ReleaseCalls += 1
		for _, CurrentPlayer in Players.Players do
			local CurrentSession = Sessions.Get(CurrentPlayer)
			if CurrentSession and not CurrentSession.ProfileMutationsFrozen then
				self.AllFrozenAtRelease = false
			end
		end
		self.ActiveReleases += 1
		self.MaximumActiveReleases = math.max(self.MaximumActiveReleases, self.ActiveReleases)
		while ReleaseBlocked and Player.UserId == BlockedUserId do
			task.wait()
		end
		task.wait()
		self.ActiveReleases -= 1
		return true
	end

	local RuntimeEntries = {}
	local FakeProfiles = {}
	function FakeProfiles.Get(UserId)
		return RuntimeEntries[UserId]
	end
	local Logger = { Warnings = {} }
	function Logger.Info() end
	function Logger.Warn(Category, Message, ...)
		table.insert(Logger.Warnings, Category .. ": " .. string.format(Message, ...))
	end
	local EventBus = { Publish = function() end }
	local GrowthService = { UpdateMultiplierAttribute = function() end }
	local ServicesFolder = { SaveService = SaveService, GrowthService = GrowthService }
	local CoreFolder = {
		Config = { SaveConfig = SaveConfig },
		Events = { EventBus = EventBus },
		Registry = { RuntimeRegistry = { Profiles = FakeProfiles, Sessions = Sessions } },
		Utilities = { Logger = Logger },
	}
	ServicesFolder.Parent = CoreFolder
	local Game = {}
	function Game:GetService(Name)
		assert(Name == "Players")
		return Players
	end
	function Game:BindToClose(Callback)
		table.insert(ShutdownCallbacks, Callback)
	end

	local Source = fs.readFile("src/server/Core/Services/SessionService.luau")
	local Chunk = luau.load(Source, "ShutdownSessionService")
	setfenv(
		Chunk,
		setmetatable({
			game = Game,
			script = { Parent = ServicesFolder },
			Instance = { new = function() end },
			task = FakeTask,
			os = {
				clock = function()
					return Clock
				end,
			},
			require = function(Dependency)
				return Dependency
			end,
		}, { __index = getfenv() })
	)

	for Index = 1, 2 do
		local Player = { UserId = 5000 + Index, Name = "ShutdownPlayer" .. Index }
		table.insert(Players.Players, Player)
		Sessions.Set(Player, sessionFromProfile(Player, PlayerProfileSchema.Defaults()))
		RuntimeEntries[Player.UserId] = {
			Phase = if Player.UserId == BlockedUserId then "Releasing" else "Active",
			WriteQueue = if Player.UserId == BlockedUserId then { {}, {} } else {},
			LastError = if Player.UserId == BlockedUserId then "blocked write" else nil,
		}
	end

	local Service = Chunk()
	Service:Init()
	return {
		Clock = function()
			return Clock
		end,
		Logger = Logger,
		Players = Players,
		SaveService = SaveService,
		SetReleaseBlocked = function(Value)
			ReleaseBlocked = Value
		end,
		ShutdownCallbacks = ShutdownCallbacks,
	}
end

local CompletedShutdown = loadShutdownSessionService(nil)
assert(#CompletedShutdown.ShutdownCallbacks == 1)
CompletedShutdown.ShutdownCallbacks[1]()
assert(CompletedShutdown.SaveService.ReleaseCalls == 2)
assert(CompletedShutdown.SaveService.MaximumActiveReleases == 2)
assert(CompletedShutdown.SaveService.AllFrozenAtRelease == true)
assert(CompletedShutdown.SaveService.SaveCalls == 0)
assert(CompletedShutdown.Clock() < SaveConfig.ShutdownTimeoutSeconds)
for _, Player in CompletedShutdown.Players.Players do
	assert(Sessions.Get(Player) == nil)
end
CompletedShutdown.ShutdownCallbacks[1]()
assert(CompletedShutdown.SaveService.ReleaseCalls == 2)

local BlockedShutdown = loadShutdownSessionService(5001)
assert(#BlockedShutdown.ShutdownCallbacks == 1)
BlockedShutdown.ShutdownCallbacks[1]()
assert(BlockedShutdown.Clock() >= SaveConfig.ShutdownTimeoutSeconds)
assert(BlockedShutdown.Clock() < SaveConfig.ShutdownTimeoutSeconds + 0.2)
assert(BlockedShutdown.SaveService.SaveCalls == 0)
local Diagnostics = table.concat(BlockedShutdown.Logger.Warnings, "\n")
assert(string.find(Diagnostics, "UserId 5001", 1, true) ~= nil)
assert(string.find(Diagnostics, "Releasing", 1, true) ~= nil)
assert(string.find(Diagnostics, "queue=2", 1, true) ~= nil)
assert(string.find(Diagnostics, "blocked write", 1, true) ~= nil)
BlockedShutdown.SetReleaseBlocked(false)
task.wait(0.05)
for _, Player in BlockedShutdown.Players.Players do
	Sessions.Remove(Player)
end

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

local ReceiptSaveService, ReceiptPersistence = loadSaveService(nil)
ReceiptSaveService:Init()
local ReceiptProfile = ReceiptSaveService:LoadProfile(ReceiptPersistence.Player)
local ReceiptSession = sessionFromProfile(ReceiptPersistence.Player, ReceiptProfile)
Sessions.Set(ReceiptPersistence.Player, ReceiptSession)
local ReceiptEntry = assert(Profiles.Get(2001))

ReceiptSession.Bigger = 51
ReceiptEntry.PendingPurchaseIds["Purchase:One"] = true
assert(ReceiptSaveService:CommitTransaction(ReceiptPersistence.Player, {
	PurchaseId = "Purchase:One",
	Rewards = { { Type = "Bigger", Amount = 999999 } },
}) == true)
assert(ReceiptSession.Bigger == 51)
assert(ReceiptSession.PurchaseHistory["Purchase:One"] == true)
assert(ReceiptEntry.PendingPurchaseIds["Purchase:One"] == nil)
assert(ReceiptPersistence.Store.Data.Player_2001.ProcessedPurchaseIds["Purchase:One"] == true)

ReceiptEntry.PendingPurchaseIds["Purchase:Two"] = true
ReceiptEntry.PendingPurchaseIds["Purchase:Three"] = true
assert(ReceiptSaveService:CommitTransaction(ReceiptPersistence.Player, {
	PurchaseId = "Purchase:Two",
	Rewards = {},
}) == true)
assert(ReceiptSession.PurchaseHistory["Purchase:Two"] == true)
assert(ReceiptSession.PurchaseHistory["Purchase:Three"] == true)

ReceiptEntry.PendingPurchaseIds["Purchase:Snapshot"] = true
ReceiptPersistence.Store.BeforeUpdate = function()
	ReceiptEntry.PendingPurchaseIds["Purchase:Late"] = true
end
assert(ReceiptSaveService:CommitTransaction(ReceiptPersistence.Player, {
	PurchaseId = "Purchase:Snapshot",
	Rewards = {},
}) == true)
assert(ReceiptSession.PurchaseHistory["Purchase:Snapshot"] == true)
assert(ReceiptSession.PurchaseHistory["Purchase:Late"] == nil)
assert(ReceiptEntry.PendingPurchaseIds["Purchase:Late"] == true)
assert(ReceiptPersistence.Store.Data.Player_2001.ProcessedPurchaseIds["Purchase:Late"] == nil)

ReceiptEntry.PendingPurchaseIds["Purchase:Failure"] = true
ReceiptPersistence.Store.FailWrites = 4
assert(ReceiptSaveService:CommitTransaction(ReceiptPersistence.Player, {
	PurchaseId = "Purchase:Failure",
	Rewards = {},
}) == false)
assert(ReceiptEntry.PendingPurchaseIds["Purchase:Failure"] == true)
assert(ReceiptSession.PurchaseHistory["Purchase:Failure"] == nil)

ReceiptEntry.PendingPurchaseIds["Purchase:Ambiguous"] = true
ReceiptPersistence.Store.ApparentErrors = 4
assert(ReceiptSaveService:CommitTransaction(ReceiptPersistence.Player, {
	PurchaseId = "Purchase:Ambiguous",
	Rewards = {},
}) == false)
assert(ReceiptPersistence.Store.Data.Player_2001.ProcessedPurchaseIds["Purchase:Ambiguous"] == true)
assert(ReceiptEntry.PendingPurchaseIds["Purchase:Ambiguous"] == true)
assert(ReceiptSaveService:CommitTransaction(ReceiptPersistence.Player, {
	PurchaseId = "Purchase:Ambiguous",
	Rewards = {},
}) == true)
assert(ReceiptSession.PurchaseHistory["Purchase:Ambiguous"] == true)

ReceiptEntry.PendingPurchaseIds["Purchase:Final"] = true
assert(ReceiptSaveService:ReleaseProfile(ReceiptPersistence.Player) == true)
assert(ReceiptPersistence.Store.Data.Player_2001.ProcessedPurchaseIds["Purchase:Final"] == true)
assert(ReceiptPersistence.Store.Data.Player_2001.ProcessedPurchaseIds["Purchase:Late"] == true)
assert(ReceiptPersistence.Store.Data.Player_2001.ProcessedPurchaseIds["Purchase:Failure"] == true)
Sessions.Remove(ReceiptPersistence.Player)

local RepeatedReleaseService, RepeatedRelease = loadSaveService(nil)
RepeatedReleaseService:Init()
local RepeatedReleaseProfile = RepeatedReleaseService:LoadProfile(RepeatedRelease.Player)
Sessions.Set(RepeatedRelease.Player, sessionFromProfile(RepeatedRelease.Player, RepeatedReleaseProfile))
local ReleaseBlocked = true
RepeatedRelease.Store.BeforeUpdate = function()
	while ReleaseBlocked do
		task.wait()
	end
end
local ReleaseResults = {}
task.spawn(function()
	ReleaseResults[1] = RepeatedReleaseService:ReleaseProfile(RepeatedRelease.Player)
end)
task.wait()
task.spawn(function()
	ReleaseResults[2] = RepeatedReleaseService:ReleaseProfile(RepeatedRelease.Player)
end)
task.wait()
ReleaseBlocked = false
task.wait(0.05)
assert(ReleaseResults[1] == true)
assert(ReleaseResults[2] == true)
assert(RepeatedRelease.Store.UpdateCalls == 2)
Sessions.Remove(RepeatedRelease.Player)

local ReceiptThenReleaseService, ReceiptThenRelease = loadSaveService(nil)
ReceiptThenReleaseService:Init()
local ReceiptThenReleaseProfile = ReceiptThenReleaseService:LoadProfile(ReceiptThenRelease.Player)
Sessions.Set(ReceiptThenRelease.Player, sessionFromProfile(ReceiptThenRelease.Player, ReceiptThenReleaseProfile))
local ReceiptThenReleaseEntry = assert(Profiles.Get(2001))
ReceiptThenReleaseEntry.PendingPurchaseIds["Purchase:BeforeShutdown"] = true
local ReceiptWriteBlocked = true
ReceiptThenRelease.Store.BeforeUpdate = function()
	while ReceiptWriteBlocked do
		task.wait()
	end
end
local ReceiptCommitResult = nil
local ReceiptReleaseResult = nil
task.spawn(function()
	ReceiptCommitResult = ReceiptThenReleaseService:CommitTransaction(ReceiptThenRelease.Player, {
		PurchaseId = "Purchase:BeforeShutdown",
		Rewards = {},
	})
end)
task.wait()
task.spawn(function()
	ReceiptReleaseResult = ReceiptThenReleaseService:ReleaseProfile(ReceiptThenRelease.Player)
end)
task.wait()
assert(ReceiptThenReleaseEntry.ActiveRequest.Kind == "Receipt")
assert(ReceiptThenReleaseEntry.WriteQueue[1].Kind == "Final")
ReceiptWriteBlocked = false
task.wait(0.05)
assert(ReceiptCommitResult == true)
assert(ReceiptReleaseResult == true)
assert(ReceiptThenRelease.Store.UpdateCalls == 3)
assert(ReceiptThenRelease.Store.Data.Player_2001.ProcessedPurchaseIds["Purchase:BeforeShutdown"] == true)
assert(ReceiptThenRelease.Store.Data.Player_2001.LeaseOwner == nil)
Sessions.Remove(ReceiptThenRelease.Player)

local function loadReceiptProcessingService(UserId, PurchaseHistory, PendingPurchaseIds, GrantResult, CommitResult)
	local Player = {
		UserId = UserId,
		Name = "ReceiptPlayer",
	}
	local Players = {}
	function Players:GetPlayerByUserId(RequestedUserId)
		return if RequestedUserId == UserId then Player else nil
	end

	local MarketplaceService = {}
	local Logger = { CriticalWarnings = 0 }
	function Logger.Info() end
	function Logger.Warn(Category)
		if Category == "Critical" then
			Logger.CriticalWarnings += 1
		end
	end
	function Logger.Error() end

	local RewardService = { GrantCalls = 0, PendingSeenDuringGrant = false }
	function RewardService:Grant(_, _)
		self.GrantCalls += 1
		local RuntimeProfile = assert(Profiles.Get(UserId))
		self.PendingSeenDuringGrant = next(RuntimeProfile.PendingPurchaseIds) ~= nil
		return GrantResult
	end
	local SaveService = { CommitCalls = 0 }
	function SaveService:IsProfileWritable()
		return true
	end
	function SaveService:CommitTransaction(_, Transaction)
		self.CommitCalls += 1
		self.LastTransaction = Transaction
		return CommitResult
	end
	local ServiceRegistry = {}
	function ServiceRegistry.Get(Name)
		return if Name == "RewardService" then RewardService else SaveService
	end

	local DeveloperProductConfig = {
		BiggerPack = {
			ProductId = 1234,
			Rewards = { { Type = "Bigger", Amount = 10 } },
			AnalyticsKey = "Bigger_Pack",
		},
	}
	local ServicesFolder = {}
	local CoreFolder = {
		Config = { DeveloperProductConfig = DeveloperProductConfig },
		Registry = {
			ServiceRegistry = ServiceRegistry,
			RuntimeRegistry = { Profiles = Profiles, Sessions = Sessions },
		},
		Utilities = { Logger = Logger, PlayerProfileSchema = PlayerProfileSchema },
	}
	ServicesFolder.Parent = CoreFolder
	local Game = {}
	function Game:GetService(Name)
		return if Name == "MarketplaceService" then MarketplaceService else Players
	end

	local Source = fs.readFile("src/server/Core/Services/ReceiptProcessingService.luau")
	local Chunk = luau.load(Source, "ReceiptProcessingService")
	setfenv(
		Chunk,
		setmetatable({
			game = Game,
			script = { Parent = ServicesFolder },
			Enum = {
				ProductPurchaseDecision = {
					NotProcessedYet = "NotProcessedYet",
					PurchaseGranted = "PurchaseGranted",
				},
			},
			require = function(Dependency)
				return Dependency
			end,
		}, { __index = getfenv() })
	)

	local Entry = Profiles.Create(UserId, "receipt-owner", function()
		return 1
	end)
	await(Profiles.Enqueue(Entry, "Load", function() end))
	Entry.PendingPurchaseIds = PendingPurchaseIds
	Sessions.Set(Player, {
		Player = Player,
		PurchaseHistory = PurchaseHistory,
		ProfileMutationsFrozen = false,
	})
	local Service = Chunk()
	Service:Init()
	return {
		Entry = Entry,
		Logger = Logger,
		MarketplaceService = MarketplaceService,
		Player = Player,
		RewardService = RewardService,
		SaveService = SaveService,
	}
end

local function receiptInfo(UserId, PurchaseId)
	return {
		PlayerId = UserId,
		ProductId = 1234,
		PurchaseId = PurchaseId,
	}
end

local DurableHistory = dictionary("Durable:", 5000)
DurableHistory["Durable:5000"] = nil
DurableHistory["Purchase:Duplicate"] = true
local DurableDuplicate = loadReceiptProcessingService(3001, DurableHistory, {}, { Success = true }, true)
assert(DurableDuplicate.MarketplaceService.ProcessReceipt(receiptInfo(3001, "Purchase:Duplicate")) == "PurchaseGranted")
assert(DurableDuplicate.RewardService.GrantCalls == 0)
assert(DurableDuplicate.SaveService.CommitCalls == 0)

local AtCapacity = loadReceiptProcessingService(3002, dictionary("Durable:", 5000), {}, { Success = true }, true)
assert(AtCapacity.MarketplaceService.ProcessReceipt(receiptInfo(3002, "Purchase:New")) == "NotProcessedYet")
assert(AtCapacity.RewardService.GrantCalls == 0)
assert(AtCapacity.Logger.CriticalWarnings == 1)

local PendingDuplicate = loadReceiptProcessingService(
	3003,
	dictionary("Durable:", 4999),
	{ ["Purchase:Pending"] = true },
	{ Success = true },
	true
)
assert(PendingDuplicate.MarketplaceService.ProcessReceipt(receiptInfo(3003, "Purchase:Pending")) == "PurchaseGranted")
assert(PendingDuplicate.RewardService.GrantCalls == 0)
assert(PendingDuplicate.SaveService.CommitCalls == 1)

local NewReceipt = loadReceiptProcessingService(3004, {}, {}, { Success = true }, true)
assert(NewReceipt.MarketplaceService.ProcessReceipt(receiptInfo(3004, "Purchase:New")) == "PurchaseGranted")
assert(NewReceipt.RewardService.GrantCalls == 1)
assert(NewReceipt.RewardService.PendingSeenDuringGrant == true)
assert(NewReceipt.SaveService.CommitCalls == 1)
assert(NewReceipt.MarketplaceService.ProcessReceipt(receiptInfo(3004, "bad/id")) == "NotProcessedYet")
assert(NewReceipt.RewardService.GrantCalls == 1)

local FailedDispatch = loadReceiptProcessingService(3005, {}, {}, { Success = false }, true)
assert(FailedDispatch.MarketplaceService.ProcessReceipt(receiptInfo(3005, "Purchase:Failed")) == "NotProcessedYet")
assert(FailedDispatch.Entry.PendingPurchaseIds["Purchase:Failed"] == nil)
assert(FailedDispatch.SaveService.CommitCalls == 0)

local FailedCommit = loadReceiptProcessingService(3006, {}, {}, { Success = true }, false)
assert(FailedCommit.MarketplaceService.ProcessReceipt(receiptInfo(3006, "Purchase:Retry")) == "NotProcessedYet")
assert(FailedCommit.Entry.PendingPurchaseIds["Purchase:Retry"] == true)
assert(FailedCommit.MarketplaceService.ProcessReceipt(receiptInfo(3006, "Purchase:Retry")) == "NotProcessedYet")
assert(FailedCommit.RewardService.GrantCalls == 1)
assert(FailedCommit.SaveService.CommitCalls == 2)

for _, Case in { DurableDuplicate, AtCapacity, PendingDuplicate, NewReceipt, FailedDispatch, FailedCommit } do
	Profiles.Remove(Case.Player.UserId, Case.Entry)
	Sessions.Remove(Case.Player)
end

local RewardServiceSource = fs.readFile("src/server/Core/Services/RewardService.luau")
assert(string.find(RewardServiceSource, "RewardDispatcher.Dispatch", 1, true) ~= nil)
assert(string.find(RewardServiceSource, "CommitTransaction", 1, true) == nil)
assert(string.find(RewardServiceSource, "PurchaseHistory[transactionId] = true", 1, true) == nil)

print("save_system: PASS")
