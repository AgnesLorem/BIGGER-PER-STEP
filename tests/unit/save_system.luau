local task = require("@lune/task")
local PlayerProfileSchema = require("../../src/server/Core/Utilities/PlayerProfileSchema")
local SaveConfig = require("../../src/server/Core/Config/SaveConfig")
local Profiles = require("../../src/server/Core/Registry/RuntimeRegistry/Profiles")

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

print("save_system: PASS")
