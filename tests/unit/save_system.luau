local PlayerProfileSchema = require("../../src/server/Core/Utilities/PlayerProfileSchema")
local SaveConfig = require("../../src/server/Core/Config/SaveConfig")

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

print("save_system: PASS")
