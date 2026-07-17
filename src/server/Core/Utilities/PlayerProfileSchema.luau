--!strict

export type StringSet = { [string]: boolean }

export type Settings = {
	SoundEnabled: boolean,
	MusicEnabled: boolean,
}

export type Profile = {
	SchemaVersion: number,
	Bigger: number,
	Destruction: number,
	Rebirth: number,
	UnlockedGrowthUpgrades: StringSet,
	EquippedGrowthUpgrade: string?,
	CompletedPortals: StringSet,
	Settings: Settings,
	HasDoubleMultiplier: boolean,
	HasVip: boolean,
	ProcessedPurchaseIds: StringSet,
	LastActiveTimestamp: number,
	LastLogoutTimestamp: number,
	LastSaveTimestamp: number,
	LeaseOwner: string?,
	LeaseExpiresAt: number?,
}

local PlayerProfileSchema = {}

PlayerProfileSchema.SchemaVersion = 1
PlayerProfileSchema.MaximumSafeInteger = 9007199254740991
PlayerProfileSchema.MaximumUnlockedGrowthUpgrades = 64
PlayerProfileSchema.MaximumCompletedPortals = 256
PlayerProfileSchema.MaximumProcessedPurchaseIds = 5000
PlayerProfileSchema.MaximumContentIdLength = 64
PlayerProfileSchema.MaximumPurchaseIdLength = 128
PlayerProfileSchema.MaximumOfflineSeconds = 28800
PlayerProfileSchema.OfflineRewardPerMinute = 30

local function Fail(Field: string, Reason: string): never
	error(string.format("PlayerProfileSchema: invalid %s (%s)", Field, Reason), 3)
end

local function IsFinite(Value: number): boolean
	return Value == Value and Value > -math.huge and Value < math.huge
end

local function RequireSafeInteger(Value: any, Minimum: number, Field: string): number
	if type(Value) ~= "number" or not IsFinite(Value) or Value % 1 ~= 0 then
		Fail(Field, "expected a finite integer")
	end
	if Value < Minimum or Value > PlayerProfileSchema.MaximumSafeInteger then
		Fail(Field, "outside the safe integer range")
	end
	return Value
end

local function RequireBoolean(Value: any, Field: string): boolean
	if type(Value) ~= "boolean" then
		Fail(Field, "expected a boolean")
	end
	return Value
end

function PlayerProfileSchema.IsContentId(Value: any): boolean
	return type(Value) == "string"
		and #Value >= 1
		and #Value <= PlayerProfileSchema.MaximumContentIdLength
		and string.match(Value, "^[A-Za-z0-9_-]+$") ~= nil
end

function PlayerProfileSchema.IsPurchaseId(Value: any): boolean
	return type(Value) == "string"
		and #Value >= 1
		and #Value <= PlayerProfileSchema.MaximumPurchaseIdLength
		and string.match(Value, "^[A-Za-z0-9_.:-]+$") ~= nil
end

local function CopySet(Value: any, MaximumCount: number, Validator: (any) -> boolean, Field: string): StringSet
	if type(Value) ~= "table" then
		Fail(Field, "expected a table")
	end

	local Result: StringSet = {}
	local Count = 0
	for Key, Enabled in pairs(Value) do
		if not Validator(Key) or Enabled ~= true then
			Fail(Field, "expected validated string keys mapped to true")
		end
		Count += 1
		if Count > MaximumCount then
			Fail(Field, "collection limit exceeded")
		end
		Result[Key] = true
	end
	return Result
end

local function CopySettings(Value: any): Settings
	if type(Value) ~= "table" then
		Fail("Settings", "expected a table")
	end
	for Key in pairs(Value) do
		if Key ~= "SoundEnabled" and Key ~= "MusicEnabled" then
			Fail("Settings", "unknown schema-v1 key")
		end
	end
	return {
		SoundEnabled = if Value.SoundEnabled == nil
			then true
			else RequireBoolean(Value.SoundEnabled, "Settings.SoundEnabled"),
		MusicEnabled = if Value.MusicEnabled == nil
			then true
			else RequireBoolean(Value.MusicEnabled, "Settings.MusicEnabled"),
	}
end

function PlayerProfileSchema.Defaults(): Profile
	return {
		SchemaVersion = PlayerProfileSchema.SchemaVersion,
		Bigger = 1,
		Destruction = 0,
		Rebirth = 0,
		UnlockedGrowthUpgrades = {},
		CompletedPortals = {},
		Settings = {
			SoundEnabled = true,
			MusicEnabled = true,
		},
		HasDoubleMultiplier = false,
		HasVip = false,
		ProcessedPurchaseIds = {},
		LastActiveTimestamp = 0,
		LastLogoutTimestamp = 0,
		LastSaveTimestamp = 0,
	}
end

function PlayerProfileSchema.Normalize(Stored: any): Profile
	if Stored == nil then
		return PlayerProfileSchema.Defaults()
	end
	if type(Stored) ~= "table" then
		Fail("profile", "expected a table")
	end
	if Stored.SchemaVersion ~= nil then
		local Version = RequireSafeInteger(Stored.SchemaVersion, 1, "SchemaVersion")
		if Version ~= PlayerProfileSchema.SchemaVersion then
			Fail("SchemaVersion", "future or unsupported schema")
		end
	end

	local Profile = PlayerProfileSchema.Defaults()
	if Stored.Bigger ~= nil then
		Profile.Bigger = RequireSafeInteger(Stored.Bigger, 1, "Bigger")
	end
	if Stored.Destruction ~= nil then
		Profile.Destruction = RequireSafeInteger(Stored.Destruction, 0, "Destruction")
	end
	if Stored.Rebirth ~= nil then
		Profile.Rebirth = RequireSafeInteger(Stored.Rebirth, 0, "Rebirth")
	end
	if Stored.UnlockedGrowthUpgrades ~= nil then
		Profile.UnlockedGrowthUpgrades = CopySet(
			Stored.UnlockedGrowthUpgrades,
			PlayerProfileSchema.MaximumUnlockedGrowthUpgrades,
			PlayerProfileSchema.IsContentId,
			"UnlockedGrowthUpgrades"
		)
	end
	if Stored.CompletedPortals ~= nil then
		Profile.CompletedPortals = CopySet(
			Stored.CompletedPortals,
			PlayerProfileSchema.MaximumCompletedPortals,
			PlayerProfileSchema.IsContentId,
			"CompletedPortals"
		)
	end
	if Stored.Settings ~= nil then
		Profile.Settings = CopySettings(Stored.Settings)
	end
	if Stored.HasDoubleMultiplier ~= nil then
		Profile.HasDoubleMultiplier = RequireBoolean(Stored.HasDoubleMultiplier, "HasDoubleMultiplier")
	end
	if Stored.HasVip ~= nil then
		Profile.HasVip = RequireBoolean(Stored.HasVip, "HasVip")
	end
	if Stored.ProcessedPurchaseIds ~= nil then
		Profile.ProcessedPurchaseIds = CopySet(
			Stored.ProcessedPurchaseIds,
			PlayerProfileSchema.MaximumProcessedPurchaseIds,
			PlayerProfileSchema.IsPurchaseId,
			"ProcessedPurchaseIds"
		)
	end
	if Stored.LastActiveTimestamp ~= nil then
		Profile.LastActiveTimestamp = RequireSafeInteger(Stored.LastActiveTimestamp, 0, "LastActiveTimestamp")
	end
	if Stored.LastLogoutTimestamp ~= nil then
		Profile.LastLogoutTimestamp = RequireSafeInteger(Stored.LastLogoutTimestamp, 0, "LastLogoutTimestamp")
	end
	if Stored.LastSaveTimestamp ~= nil then
		Profile.LastSaveTimestamp = RequireSafeInteger(Stored.LastSaveTimestamp, 0, "LastSaveTimestamp")
	end

	if Stored.EquippedGrowthUpgrade ~= nil then
		if not PlayerProfileSchema.IsContentId(Stored.EquippedGrowthUpgrade) then
			Fail("EquippedGrowthUpgrade", "expected a content ID")
		end
		if Profile.UnlockedGrowthUpgrades[Stored.EquippedGrowthUpgrade] ~= true then
			Fail("EquippedGrowthUpgrade", "upgrade is not unlocked")
		end
		Profile.EquippedGrowthUpgrade = Stored.EquippedGrowthUpgrade
	end

	if Stored.LeaseOwner ~= nil then
		if type(Stored.LeaseOwner) ~= "string" or #Stored.LeaseOwner < 1 or #Stored.LeaseOwner > 128 then
			Fail("LeaseOwner", "expected a non-empty string of at most 128 characters")
		end
		Profile.LeaseOwner = Stored.LeaseOwner
	end
	if Stored.LeaseExpiresAt ~= nil then
		Profile.LeaseExpiresAt = RequireSafeInteger(Stored.LeaseExpiresAt, 0, "LeaseExpiresAt")
	end
	if (Profile.LeaseOwner == nil) ~= (Profile.LeaseExpiresAt == nil) then
		Fail("lease", "owner and expiry must both be present or absent")
	end

	return Profile
end

local function RequireTimestamp(Value: any, Field: string): number
	return RequireSafeInteger(Value, 0, Field)
end

local function RequireOwnerToken(Value: any): string
	if type(Value) ~= "string" or #Value < 1 or #Value > 128 then
		Fail("OwnerToken", "expected a non-empty string of at most 128 characters")
	end
	return Value
end

function PlayerProfileSchema.Acquire(
	Stored: any,
	Now: number,
	OwnerToken: string,
	LeaseExpiresAt: number,
	GrowthMultiplier: number
): (Profile, number)
	Now = RequireTimestamp(Now, "Now")
	OwnerToken = RequireOwnerToken(OwnerToken)
	LeaseExpiresAt = RequireTimestamp(LeaseExpiresAt, "LeaseExpiresAt")
	if LeaseExpiresAt <= Now then
		Fail("LeaseExpiresAt", "must be later than Now")
	end
	if type(GrowthMultiplier) ~= "number" or not IsFinite(GrowthMultiplier) or GrowthMultiplier <= 0 then
		Fail("GrowthMultiplier", "expected a positive finite number")
	end

	local HadActivityTimestamp = type(Stored) == "table"
		and (Stored.LastActiveTimestamp ~= nil or Stored.LastLogoutTimestamp ~= nil)
	local Profile = PlayerProfileSchema.Normalize(Stored)
	if
		Profile.LeaseOwner ~= nil
		and Profile.LeaseOwner ~= OwnerToken
		and Profile.LeaseExpiresAt ~= nil
		and Profile.LeaseExpiresAt > Now
	then
		Fail("LeaseOwner", "profile has an unexpired foreign lease")
	end

	local OfflineReward = 0
	if HadActivityTimestamp then
		local Baseline = math.max(Profile.LastActiveTimestamp, Profile.LastLogoutTimestamp)
		local OfflineSeconds = math.clamp(Now - Baseline, 0, PlayerProfileSchema.MaximumOfflineSeconds)
		OfflineReward = math.floor(OfflineSeconds / 60 * PlayerProfileSchema.OfflineRewardPerMinute * GrowthMultiplier)
		RequireSafeInteger(OfflineReward, 0, "OfflineReward")
		if Profile.Bigger > PlayerProfileSchema.MaximumSafeInteger - OfflineReward then
			Fail("Bigger", "offline reward would overflow")
		end
		Profile.Bigger += OfflineReward
	end

	Profile.LeaseOwner = OwnerToken
	Profile.LeaseExpiresAt = LeaseExpiresAt
	Profile.LastActiveTimestamp = Now
	Profile.LastSaveTimestamp = Now
	return Profile, OfflineReward
end

function PlayerProfileSchema.Save(Profile: any, Now: number, OwnerToken: string, LeaseExpiresAt: number): Profile
	local Result = PlayerProfileSchema.Normalize(Profile)
	Now = RequireTimestamp(Now, "Now")
	OwnerToken = RequireOwnerToken(OwnerToken)
	LeaseExpiresAt = RequireTimestamp(LeaseExpiresAt, "LeaseExpiresAt")
	if Result.LeaseOwner ~= OwnerToken then
		Fail("LeaseOwner", "profile is not owned by this server")
	end
	if LeaseExpiresAt <= Now then
		Fail("LeaseExpiresAt", "must be later than Now")
	end
	Result.LastActiveTimestamp = Now
	Result.LastSaveTimestamp = Now
	Result.LeaseExpiresAt = LeaseExpiresAt
	return Result
end

function PlayerProfileSchema.Release(Profile: any, Now: number, OwnerToken: string): Profile
	local Result = PlayerProfileSchema.Normalize(Profile)
	Now = RequireTimestamp(Now, "Now")
	OwnerToken = RequireOwnerToken(OwnerToken)
	if Result.LeaseOwner ~= OwnerToken then
		Fail("LeaseOwner", "profile is not owned by this server")
	end
	Result.LastActiveTimestamp = Now
	Result.LastLogoutTimestamp = Now
	Result.LastSaveTimestamp = Now
	Result.LeaseOwner = nil
	Result.LeaseExpiresAt = nil
	return Result
end

return table.freeze(PlayerProfileSchema)
