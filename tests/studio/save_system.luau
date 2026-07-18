--!strict

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Core = game.ServerScriptService.BiggerServer.Core
local SaveConfig = require(Core.Config.SaveConfig)
local Sessions = require(Core.Registry.RuntimeRegistry.Sessions)
local GrowthService = require(Core.Services.GrowthService)
local SaveService = require(Core.Services.SaveService)
local PlayerProfileSchema = require(Core.Utilities.PlayerProfileSchema)

local SaveSystem = {}

local function WaitForPlayerAndSession(): (Player, Sessions.Session)
	local Deadline = os.clock() + 15
	repeat
		local Player = Players:GetPlayers()[1]
		if Player then
			local Session = Sessions.Get(Player)
			if Session then
				return Player, Session
			end
		end
		task.wait(0.1)
	until os.clock() >= Deadline
	error("MVP004 Studio: authoritative session did not load", 2)
end

local function StoreForStudio()
	assert(RunService:IsStudio(), "MVP004 Studio harness must never run outside Studio")
	assert(SaveConfig.ResolveScope(true, game.PlaceId) == "Studio", "Studio scope resolution failed")
	return DataStoreService:GetDataStore(SaveConfig.StoreName, "Studio")
end

local function RunDefaults(Store: any, ProfileKey: string)
	Store:RemoveAsync(ProfileKey)
	local Stored = Store:UpdateAsync(ProfileKey, function(Value)
		return PlayerProfileSchema.Normalize(Value)
	end)
	assert(Stored.SchemaVersion == 1, "default schema version mismatch")
	assert(Stored.Bigger == 1, "default Bigger mismatch")
	assert(next(Stored.ProcessedPurchaseIds) == nil, "default receipt history was not empty")
end

local function RunAutosave(Store: any, ControlKey: string, Player: Player, Session: Sessions.Session)
	local Target = Session.Bigger + 123
	assert(GrowthService:SetBigger(Player, Target), "autosave setup mutation failed")
	SaveService:SaveProfile(Player)
	local Stored = Store:GetAsync(SaveConfig.ProfileKey(Player.UserId))
	assert(Stored.Bigger == Target, "autosave did not persist the target Bigger value")
	Store:UpdateAsync(ControlKey, function()
		return { ExpectedBigger = Target }
	end)
end

local function RunRestorationAndFreeze(Store: any, ControlKey: string, Player: Player, Session: Sessions.Session)
	local Control = Store:GetAsync(ControlKey)
	assert(type(Control) == "table" and type(Control.ExpectedBigger) == "number", "autosave control record is missing")
	assert(Session.Bigger >= Control.ExpectedBigger, "autosaved Bigger value was not restored")
	local Before = Session.Bigger
	assert(SaveService:FreezeMutations(Player, "MVP004StudioFreeze"), "profile freeze failed")
	assert(GrowthService:SetBigger(Player, Before + 100) == false, "frozen Growth mutation succeeded")
	assert(Session.Bigger == Before, "frozen session Bigger changed")
end

local function RunOfflineExactlyOnce(Store: any, ProfileKey: string)
	local Now = os.time()
	Store:RemoveAsync(ProfileKey)
	Store:UpdateAsync(ProfileKey, function()
		local Profile = PlayerProfileSchema.Defaults()
		Profile.LastActiveTimestamp = Now - 600
		Profile.LastLogoutTimestamp = Now - 600
		return Profile
	end)
	local FirstReward = 0
	Store:UpdateAsync(ProfileKey, function(Stored)
		local Acquired, Reward = PlayerProfileSchema.Acquire(Stored, Now, "StudioHarnessA", Now + 180, 1)
		FirstReward = Reward
		return Acquired
	end)
	assert(FirstReward == 300, "first offline claim was not 300 Bigger")
	Store:UpdateAsync(ProfileKey, function(Stored)
		return PlayerProfileSchema.Release(Stored, Now, "StudioHarnessA")
	end)
	local SecondReward = -1
	local Reconnected = Store:UpdateAsync(ProfileKey, function(Stored)
		local Acquired, Reward = PlayerProfileSchema.Acquire(Stored, Now, "StudioHarnessB", Now + 180, 1)
		SecondReward = Reward
		return Acquired
	end)
	assert(SecondReward == 0, "offline interval was claimed twice")
	assert(Reconnected.Bigger == 301, "offline reward total mismatch")
end

local function RunFinalSave(
	Store: any,
	ProfileKey: string,
	ControlKey: string,
	Player: Player,
	Session: Sessions.Session
)
	local Target = Session.Bigger + 77
	assert(GrowthService:SetBigger(Player, Target), "final-save setup mutation failed")
	assert(SaveService:ReleaseProfile(Player), "final release failed")
	assert(Session.ProfileMutationsFrozen, "final release did not freeze mutations")
	local Stored = Store:GetAsync(SaveConfig.ProfileKey(Player.UserId))
	assert(Stored.Bigger == Target, "final save did not persist the target Bigger value")
	assert(Stored.LeaseOwner == nil, "final save did not clear the lease owner")
	assert(Stored.LeaseExpiresAt == nil, "final save did not clear the lease expiry")
	Store:RemoveAsync(ProfileKey)
	Store:RemoveAsync(ControlKey)
end

function SaveSystem.Run(Stage: number)
	assert(
		type(Stage) == "number" and Stage % 1 == 0 and Stage >= 1 and Stage <= 5,
		"Studio stage must be an integer from 1 through 5"
	)
	local Player, Session = WaitForPlayerAndSession()
	local Store = StoreForStudio()
	local ProfileKey = string.format("MVP004_Harness_Profile_%d", Player.UserId)
	local ControlKey = string.format("MVP004_Harness_Control_%d", Player.UserId)

	if Stage == 1 then
		RunDefaults(Store, ProfileKey)
	elseif Stage == 2 then
		RunAutosave(Store, ControlKey, Player, Session)
	elseif Stage == 3 then
		RunRestorationAndFreeze(Store, ControlKey, Player, Session)
	elseif Stage == 4 then
		RunOfflineExactlyOnce(Store, ProfileKey)
	else
		RunFinalSave(Store, ProfileKey, ControlKey, Player, Session)
	end
	print(string.format("[MVP004 Studio] Stage %d: PASS", Stage))
end

return table.freeze(SaveSystem)
