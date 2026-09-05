local PlayerProfileSchema = require("../../src/server/Core/Utilities/PlayerProfileSchema")

local function expectError(Callback)
	local Success = pcall(Callback)
	assert(Success == false, "expected error but call succeeded")
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

-- Test 1: Defaults() produces SchemaVersion = 2 with new fields
local Defaults = PlayerProfileSchema.Defaults()
assert(Defaults.SchemaVersion == 2, "Defaults SchemaVersion should be 2")
assert(Defaults.HasAutoWins == false, "Defaults HasAutoWins should be false")
assert(Defaults.DailyRewardDay == 1, "Defaults DailyRewardDay should be 1")
assert(Defaults.LastDailyClaimTimestamp == 0, "Defaults LastDailyClaimTimestamp should be 0")
assert(Defaults.SpinTokens == 0, "Defaults SpinTokens should be 0")
assert(type(Defaults.UnlockedTrails) == "table", "Defaults UnlockedTrails should be a table")
assert(next(Defaults.UnlockedTrails) == nil, "Defaults UnlockedTrails should be empty")
assert(Defaults.EquippedTrail == nil, "Defaults EquippedTrail should be nil")
assert(type(Defaults.UnlockedTitles) == "table", "Defaults UnlockedTitles should be a table")
assert(next(Defaults.UnlockedTitles) == nil, "Defaults UnlockedTitles should be empty")
assert(Defaults.EquippedTitle == nil, "Defaults EquippedTitle should be nil")

-- Existing fields must remain intact in Defaults()
assert(Defaults.Bigger == 1, "Defaults Bigger should be 1")
assert(Defaults.Destruction == 0, "Defaults Destruction should be 0")
assert(Defaults.Rebirth == 0, "Defaults Rebirth should be 0")
assert(next(Defaults.UnlockedGrowthUpgrades) == nil, "Defaults UnlockedGrowthUpgrades should be empty")
assert(Defaults.EquippedGrowthUpgrade == nil, "Defaults EquippedGrowthUpgrade should be nil")
assert(next(Defaults.CompletedPortals) == nil, "Defaults CompletedPortals should be empty")
assert(Defaults.Settings.SoundEnabled == true, "Defaults SoundEnabled should be true")
assert(Defaults.Settings.MusicEnabled == true, "Defaults MusicEnabled should be true")
assert(Defaults.HasDoubleMultiplier == false, "Defaults HasDoubleMultiplier should be false")
assert(Defaults.HasVip == false, "Defaults HasVip should be false")
assert(Defaults.HasPremiumZonePass == false, "Defaults HasPremiumZonePass should be false")
assert(next(Defaults.ProcessedPurchaseIds) == nil, "Defaults ProcessedPurchaseIds should be empty")
assert(Defaults.LastActiveTimestamp == 0, "Defaults LastActiveTimestamp should be 0")
assert(Defaults.LastLogoutTimestamp == 0, "Defaults LastLogoutTimestamp should be 0")
assert(Defaults.LastSaveTimestamp == 0, "Defaults LastSaveTimestamp should be 0")

-- Test 2: Normalize(v1Data) upgrades SchemaVersion to 2 and populates missing defaults
local v1Data = {
	SchemaVersion = 1,
	Bigger = 500,
	Destruction = 100,
	Rebirth = 3,
	UnlockedGrowthUpgrades = { Upgrade_1 = true },
	EquippedGrowthUpgrade = "Upgrade_1",
	CompletedPortals = { Portal_1 = true },
	Settings = { SoundEnabled = false, MusicEnabled = true },
	Consumables = nil,
	HasDoubleMultiplier = true,
	HasVip = true,
	HasPremiumZonePass = true,
	ProcessedPurchaseIds = { ["DevProd:1001"] = true },
	LastActiveTimestamp = 5000,
	LastLogoutTimestamp = 4900,
	LastSaveTimestamp = 5000,
}

local Migrated = PlayerProfileSchema.Normalize(v1Data)
assert(Migrated.SchemaVersion == 2, "Migrated SchemaVersion should be upgraded to 2")
assert(Migrated.Bigger == 500, "Migrated Bigger should be preserved")
assert(Migrated.Destruction == 100, "Migrated Destruction should be preserved")
assert(Migrated.Rebirth == 3, "Migrated Rebirth should be preserved")
assert(Migrated.UnlockedGrowthUpgrades.Upgrade_1 == true, "Migrated UnlockedGrowthUpgrades preserved")
assert(Migrated.EquippedGrowthUpgrade == "Upgrade_1", "Migrated EquippedGrowthUpgrade preserved")
assert(Migrated.CompletedPortals.Portal_1 == true, "Migrated CompletedPortals preserved")
assert(Migrated.Settings.SoundEnabled == false, "Migrated Settings preserved")
assert(Migrated.HasDoubleMultiplier == true, "Migrated HasDoubleMultiplier preserved")
assert(Migrated.HasVip == true, "Migrated HasVip preserved")
assert(Migrated.HasPremiumZonePass == true, "Migrated HasPremiumZonePass preserved")
assert(Migrated.ProcessedPurchaseIds["DevProd:1001"] == true, "Migrated ProcessedPurchaseIds preserved")
-- Check new fields are backfilled with defaults
assert(Migrated.HasAutoWins == false, "Migrated HasAutoWins should default to false")
assert(Migrated.DailyRewardDay == 1, "Migrated DailyRewardDay should default to 1")
assert(Migrated.LastDailyClaimTimestamp == 0, "Migrated LastDailyClaimTimestamp should default to 0")
assert(Migrated.SpinTokens == 0, "Migrated SpinTokens should default to 0")
assert(next(Migrated.UnlockedTrails) == nil, "Migrated UnlockedTrails should default to empty")
assert(Migrated.EquippedTrail == nil, "Migrated EquippedTrail should default to nil")
assert(next(Migrated.UnlockedTitles) == nil, "Migrated UnlockedTitles should default to empty")
assert(Migrated.EquippedTitle == nil, "Migrated EquippedTitle should default to nil")

-- Test 3: Normalize(v2Data) preserves valid v2 fields
local v2Data = {
	SchemaVersion = 2,
	Bigger = 10,
	HasAutoWins = true,
	DailyRewardDay = 5,
	LastDailyClaimTimestamp = 1700000000,
	SpinTokens = 3,
	UnlockedTrails = { Rainbow = true, Fire = true },
	EquippedTrail = "Rainbow",
	UnlockedTitles = { Giant = true, Titan = true },
	EquippedTitle = "Titan",
}

local NormalizedV2 = PlayerProfileSchema.Normalize(v2Data)
assert(NormalizedV2.SchemaVersion == 2, "V2 SchemaVersion is 2")
assert(NormalizedV2.HasAutoWins == true, "V2 HasAutoWins preserved")
assert(NormalizedV2.DailyRewardDay == 5, "V2 DailyRewardDay preserved")
assert(NormalizedV2.LastDailyClaimTimestamp == 1700000000, "V2 LastDailyClaimTimestamp preserved")
assert(NormalizedV2.SpinTokens == 3, "V2 SpinTokens preserved")
assert(
	NormalizedV2.UnlockedTrails.Rainbow == true and NormalizedV2.UnlockedTrails.Fire == true,
	"V2 UnlockedTrails preserved"
)
assert(NormalizedV2.EquippedTrail == "Rainbow", "V2 EquippedTrail preserved")
assert(
	NormalizedV2.UnlockedTitles.Giant == true and NormalizedV2.UnlockedTitles.Titan == true,
	"V2 UnlockedTitles preserved"
)
assert(NormalizedV2.EquippedTitle == "Titan", "V2 EquippedTitle preserved")

-- Test 4: Validation & error handling for new fields
-- Future schema version (>2) should error
expectError(function()
	PlayerProfileSchema.Normalize({ SchemaVersion = 3 })
end)

-- Invalid HasAutoWins
expectError(function()
	PlayerProfileSchema.Normalize({ HasAutoWins = "yes" })
end)

-- Invalid DailyRewardDay (< 1 or non-integer)
expectError(function()
	PlayerProfileSchema.Normalize({ DailyRewardDay = 0 })
end)
expectError(function()
	PlayerProfileSchema.Normalize({ DailyRewardDay = 1.5 })
end)

-- Invalid LastDailyClaimTimestamp (< 0 or non-integer)
expectError(function()
	PlayerProfileSchema.Normalize({ LastDailyClaimTimestamp = -1 })
end)

-- Invalid SpinTokens (< 0 or non-integer)
expectError(function()
	PlayerProfileSchema.Normalize({ SpinTokens = -1 })
end)
expectError(function()
	PlayerProfileSchema.Normalize({ SpinTokens = 2.5 })
end)

-- Invalid EquippedTrail (not in UnlockedTrails or invalid format)
expectError(function()
	PlayerProfileSchema.Normalize({ EquippedTrail = "Rainbow" })
end)
expectError(function()
	PlayerProfileSchema.Normalize({
		UnlockedTrails = { ["Invalid Name with Spaces"] = true },
	})
end)
expectError(function()
	PlayerProfileSchema.Normalize({
		UnlockedTrails = { Rainbow = true },
		EquippedTrail = "Fire",
	})
end)

-- Invalid EquippedTitle (not in UnlockedTitles or invalid format)
expectError(function()
	PlayerProfileSchema.Normalize({ EquippedTitle = "Titan" })
end)
expectError(function()
	PlayerProfileSchema.Normalize({
		UnlockedTitles = { ["Invalid Name!"] = true },
	})
end)
expectError(function()
	PlayerProfileSchema.Normalize({
		UnlockedTitles = { Titan = true },
		EquippedTitle = "Giant",
	})
end)

-- Trail and Title collection limits
local AtTrailLimit = PlayerProfileSchema.Normalize({
	UnlockedTrails = dictionary("Trail_", 64),
})
assert(AtTrailLimit.UnlockedTrails.Trail_64 == true)
expectError(function()
	PlayerProfileSchema.Normalize({ UnlockedTrails = dictionary("Trail_", 65) })
end)
local AtTitleLimit = PlayerProfileSchema.Normalize({
	UnlockedTitles = dictionary("Title_", 64),
})
assert(AtTitleLimit.UnlockedTitles.Title_64 == true)
expectError(function()
	PlayerProfileSchema.Normalize({ UnlockedTitles = dictionary("Title_", 65) })
end)

print("mvp006_schema: ALL TESTS PASSED")
