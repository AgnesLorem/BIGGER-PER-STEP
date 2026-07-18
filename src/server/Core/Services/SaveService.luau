--!strict
--// Raw Requirings \--

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

--// Requirings \--

local SaveConfig = require(script.Parent.Parent.Config.SaveConfig)
local Profiles = require(script.Parent.Parent.Registry.RuntimeRegistry.Profiles)
local Sessions = require(script.Parent.Parent.Registry.RuntimeRegistry.Sessions)
local Scheduler = require(script.Parent.Parent.Scheduler.Scheduler)
local Logger = require(script.Parent.Parent.Utilities.Logger)
local PlayerProfileSchema = require(script.Parent.Parent.Utilities.PlayerProfileSchema)

--// Types \--

export type Profile = PlayerProfileSchema.Profile
type RuntimeProfile = Profiles.Entry

--// Variables \--

local LoadRetryDelays = table.freeze({ 1, 2, 4, 8 })
local WriteRetryDelays = table.freeze({ 1, 2, 4 })
local ProfileStore: any = nil
local OwnerToken = ""

--// Helpers \--

local function Retry(Callback: () -> ...any, Delays: { number }): ...any
	local LastError = "unknown persistence failure"
	for Attempt = 1, #Delays + 1 do
		local Results = table.pack(pcall(Callback))
		if Results[1] then
			return table.unpack(Results, 2, Results.n)
		end
		LastError = tostring(Results[2])
		if Attempt <= #Delays then
			task.wait(Delays[Attempt])
		end
	end
	error(LastError, 0)
end

local function RuntimeFor(Player: Player): RuntimeProfile?
	return Profiles.Get(Player.UserId)
end

local function CopyPurchaseIds(PurchaseIds: { [string]: boolean }): { [string]: boolean }
	local Copy = {}
	for PurchaseId in PurchaseIds do
		Copy[PurchaseId] = true
	end
	return Copy
end

local function Snapshot(
	Player: Player,
	RuntimeProfile: RuntimeProfile,
	IncludedPendingPurchaseIds: { [string]: boolean }?
): Profile
	local Session = Sessions.Get(Player)
	if not Session then
		error("SaveService: authoritative session is unavailable", 2)
	end
	local ProcessedPurchaseIds = CopyPurchaseIds(Session.PurchaseHistory)
	if IncludedPendingPurchaseIds then
		for PurchaseId in IncludedPendingPurchaseIds do
			ProcessedPurchaseIds[PurchaseId] = true
		end
	end
	return PlayerProfileSchema.Normalize({
		SchemaVersion = PlayerProfileSchema.SchemaVersion,
		Bigger = Session.Bigger,
		Destruction = Session.Destruction,
		Rebirth = Session.Rebirth,
		UnlockedGrowthUpgrades = Session.UnlockedGrowthUpgrades,
		EquippedGrowthUpgrade = Session.EquippedGrowthUpgrade,
		CompletedPortals = Session.CompletedPortals,
		Settings = Session.Settings,
		HasDoubleMultiplier = Session.HasDoubleMultiplier,
		HasVip = Session.HasVip,
		ProcessedPurchaseIds = ProcessedPurchaseIds,
		LastActiveTimestamp = Session.LastActiveTimestamp,
		LastLogoutTimestamp = Session.LastLogoutTimestamp,
		LastSaveTimestamp = Session.LastSaveTimestamp,
		LeaseOwner = RuntimeProfile.OwnerToken,
		LeaseExpiresAt = RuntimeProfile.LeaseExpiresAt,
	})
end

local function IsOwnershipError(Message: string): boolean
	return string.find(Message, "profile lease is owned by another server", 1, true) ~= nil
		or string.find(Message, "profile is not owned by this server", 1, true) ~= nil
end

--// Service \--

local SaveService = {}

function SaveService:IsProfileWritable(Player: Player): boolean
	local Session = Sessions.Get(Player)
	local RuntimeProfile = RuntimeFor(Player)
	return Session ~= nil
		and Session.ProfileMutationsFrozen ~= true
		and RuntimeProfile ~= nil
		and RuntimeProfile.Phase == "Active"
		and not RuntimeProfile.Released
end

function SaveService:FreezeMutations(Player: Player, Reason: string): boolean
	local Session = Sessions.Get(Player)
	if not Session then
		return false
	end
	if Session.ProfileMutationsFrozen then
		return true
	end
	Session.ProfileMutationsFrozen = true
	Session.ProfileMutationFreezeReason = Reason
	return true
end

local function HandleOwnershipLoss(Player: Player, Message: string)
	SaveService:FreezeMutations(Player, "LeaseOwnershipLost")
	Logger.Warn("Save", "Lease ownership lost for %s: %s", Player.Name, Message)
	Player:Kick("Your data session moved to another server. Please rejoin.")
end

local function WriteProfile(
	Player: Player,
	RuntimeProfile: RuntimeProfile,
	Release: boolean,
	IncludedPendingPurchaseIds: { [string]: boolean }?
): Profile
	local Captured = Snapshot(Player, RuntimeProfile, IncludedPendingPurchaseIds)
	local Now = os.time()
	local LeaseExpiresAt = Now + SaveConfig.LeaseDurationSeconds
	local Key = SaveConfig.ProfileKey(Player.UserId)

	local Result = Retry(function()
		return ProfileStore:UpdateAsync(Key, function(Stored: any)
			local Current = PlayerProfileSchema.Normalize(Stored)
			if Current.LeaseOwner ~= RuntimeProfile.OwnerToken then
				error("SaveService: profile lease is owned by another server")
			end
			if Release then
				return PlayerProfileSchema.Release(Captured, Now, RuntimeProfile.OwnerToken)
			end
			return PlayerProfileSchema.Save(Captured, Now, RuntimeProfile.OwnerToken, LeaseExpiresAt)
		end)
	end, WriteRetryDelays)

	if not Release then
		RuntimeProfile.LeaseExpiresAt = LeaseExpiresAt
	end
	return Result
end

local function QueueSave(Player: Player, Kind: Profiles.RequestKind): Profiles.Request?
	local RuntimeProfile = RuntimeFor(Player)
	if not RuntimeProfile or RuntimeProfile.Released then
		return nil
	end
	return Profiles.Enqueue(RuntimeProfile, Kind, function()
		local Success, Result = pcall(WriteProfile, Player, RuntimeProfile, false, nil)
		if not Success then
			local Message = tostring(Result)
			if IsOwnershipError(Message) then
				HandleOwnershipLoss(Player, Message)
			end
			error(Message, 0)
		end
		return Result
	end)
end

local function ExistingFinalRequest(RuntimeProfile: RuntimeProfile): Profiles.Request?
	if RuntimeProfile.ActiveRequest and RuntimeProfile.ActiveRequest.Kind == "Final" then
		return RuntimeProfile.ActiveRequest
	end
	for _, Request in RuntimeProfile.WriteQueue do
		if Request.Kind == "Final" then
			return Request
		end
	end
	return nil
end

function SaveService:Init()
	Players.CharacterAutoLoads = false
	local Scope = SaveConfig.ResolveScope(RunService:IsStudio(), game.PlaceId)
	ProfileStore = DataStoreService:GetDataStore(SaveConfig.StoreName, Scope)
	OwnerToken = if game.JobId ~= "" then game.JobId else "Studio-" .. HttpService:GenerateGUID(false)
end

function SaveService:Start()
	Scheduler.AddJob({
		Name = "ProfileAutosave",
		IntervalSeconds = SaveConfig.AutosaveIntervalSeconds,
		Callback = function()
			for _, Player in Players:GetPlayers() do
				if self:IsProfileWritable(Player) then
					QueueSave(Player, "Autosave")
				end
			end
		end,
	})
end

function SaveService:LoadProfile(Player: Player): Profile
	if ProfileStore == nil then
		error("SaveService: service is not initialized", 2)
	end

	local RuntimeProfile = Profiles.Create(Player.UserId, OwnerToken, function(Profile: Profile)
		local Multiplier = if Profile.HasDoubleMultiplier then 2 else 1
		return if Profile.HasVip then Multiplier * 2 else Multiplier
	end)
	local ExpectedOwnerToken = RuntimeProfile.OwnerToken
	local function IsCurrentLoad(): boolean
		return Profiles.Get(Player.UserId) == RuntimeProfile and RuntimeProfile.OwnerToken == ExpectedOwnerToken
	end
	local Request = Profiles.Enqueue(RuntimeProfile, "Load", function()
		local AcquiredLeaseExpiresAt: number? = nil
		local Loaded = Retry(function()
			local AttemptNow = os.time()
			local AttemptLeaseExpiresAt = AttemptNow + SaveConfig.LeaseDurationSeconds
			local Result = ProfileStore:UpdateAsync(SaveConfig.ProfileKey(Player.UserId), function(Stored: any)
				if not IsCurrentLoad() then
					error("SaveService: profile load is no longer current")
				end
				local Normalized = PlayerProfileSchema.Normalize(Stored)
				local Acquired = PlayerProfileSchema.Acquire(
					Stored,
					AttemptNow,
					RuntimeProfile.OwnerToken,
					AttemptLeaseExpiresAt,
					RuntimeProfile.EntitlementProbe(Normalized)
				)
				return Acquired
			end)
			AcquiredLeaseExpiresAt = AttemptLeaseExpiresAt
			return Result
		end, LoadRetryDelays)
		RuntimeProfile.LeaseExpiresAt = assert(AcquiredLeaseExpiresAt, "SaveService: acquired lease expiry missing")
		return Loaded
	end)

	local Success, Result = Profiles.Await(Request)
	if not Success then
		error(
			string.format("SaveService: failed to load profile for UserId %d: %s", Player.UserId, tostring(Result)),
			2
		)
	end
	if not IsCurrentLoad() or RuntimeProfile.Phase ~= "Active" then
		error(string.format("SaveService: stale profile load completed for UserId %d", Player.UserId), 2)
	end
	return Result
end

function SaveService:SaveProfile(Player: Player)
	if not self:IsProfileWritable(Player) then
		return
	end
	local Request = QueueSave(Player, "Autosave")
	if Request then
		Profiles.Await(Request)
	end
end

function SaveService:CommitTransaction(
	Player: Player,
	TransactionData: { PurchaseId: string, Rewards: { [any]: any } }
): boolean
	if
		type(TransactionData) ~= "table"
		or not PlayerProfileSchema.IsPurchaseId(TransactionData.PurchaseId)
		or type(TransactionData.Rewards) ~= "table"
		or not self:IsProfileWritable(Player)
	then
		return false
	end
	local RuntimeProfile = RuntimeFor(Player)
	if not RuntimeProfile then
		return false
	end
	local Request = Profiles.Enqueue(RuntimeProfile, "Receipt", function()
		local Session = Sessions.Get(Player)
		if not Session then
			return false
		end
		if Session.PurchaseHistory[TransactionData.PurchaseId] then
			return true
		end
		if not RuntimeProfile.PendingPurchaseIds[TransactionData.PurchaseId] then
			return false
		end

		local IncludedPendingPurchaseIds = CopyPurchaseIds(RuntimeProfile.PendingPurchaseIds)
		WriteProfile(Player, RuntimeProfile, false, IncludedPendingPurchaseIds)
		Sessions.Mutate(Player, function(CurrentSession)
			for PurchaseId in IncludedPendingPurchaseIds do
				CurrentSession.PurchaseHistory[PurchaseId] = true
				RuntimeProfile.PendingPurchaseIds[PurchaseId] = nil
			end
		end)
		return true
	end)
	local Success, Durable = Profiles.Await(Request)
	return Success and Durable == true
end

function SaveService:ReleaseProfile(Player: Player): boolean
	local RuntimeProfile = RuntimeFor(Player)
	if not RuntimeProfile then
		return true
	end
	if RuntimeProfile.Released then
		return true
	end
	self:FreezeMutations(Player, "ProfileRelease")
	local Request = ExistingFinalRequest(RuntimeProfile)
	if not Request then
		Request = Profiles.Enqueue(RuntimeProfile, "Final", function()
			local IncludedPendingPurchaseIds = CopyPurchaseIds(RuntimeProfile.PendingPurchaseIds)
			local Success, Result = pcall(WriteProfile, Player, RuntimeProfile, true, IncludedPendingPurchaseIds)
			if not Success then
				local Message = tostring(Result)
				if IsOwnershipError(Message) then
					HandleOwnershipLoss(Player, Message)
				end
				error(Message, 0)
			end
			return Result
		end)
	end
	local Success = Profiles.Await(Request)
	return Success
end

return SaveService
