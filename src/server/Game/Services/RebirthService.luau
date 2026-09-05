--!strict
-- RebirthService.luau
-- Server-authoritative Rebirth system: validates, mutates Session.Rebirth, resets Size via GrowthService.

--// Raw Requirings \\--
local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Requirings \\--
local Sessions = require(script.Parent.Parent.Parent.Core.Registry.RuntimeRegistry.Sessions)
local ServiceRegistry = require(script.Parent.Parent.Parent.Core.Registry.ServiceRegistry)
local Logger = require(script.Parent.Parent.Parent.Core.Utilities.Logger)
local RebirthTypes = require(
	ReplicatedStorage:WaitForChild("BiggerShared")
		:WaitForChild("Core")
		:WaitForChild("Types")
		:WaitForChild("RebirthTypes")
)
local RebirthConfig = require(
	ReplicatedStorage:WaitForChild("BiggerShared")
		:WaitForChild("Game")
		:WaitForChild("Progression")
		:WaitForChild("RebirthConfig")
)
local LevelFormula = require(
	ReplicatedStorage:WaitForChild("BiggerShared")
		:WaitForChild("Game")
		:WaitForChild("Progression")
		:WaitForChild("LevelFormula")
)
local RebirthError = require(
	ReplicatedStorage:WaitForChild("BiggerShared")
		:WaitForChild("Core")
		:WaitForChild("Enums")
		:WaitForChild("RebirthError")
)
local GrowthFormula = require(script.Parent.Parent.Formula.GrowthFormula)

--// Types \\--
type Session = Sessions.Session
type RebirthTierSnapshot = RebirthTypes.RebirthTierSnapshot
type RebirthUpdate = RebirthTypes.RebirthUpdate

--// Variables \\--
local RebirthCooldowns: { [Player]: number } = {}
local PlayerRegistries: { [Player]: { Connections: { RBXScriptConnection }, Destroyed: boolean } } = {}
local RequestRebirthRemote: RemoteEvent
local RequestSkipRebirthRemote: RemoteEvent
local UpdateRebirthRemote: RemoteEvent
local UpdateVersion = 0

--// Helpers \\--

-- Ensure a RemoteEvent exists under ReplicatedStorage.Remotes (idempotent).
local function EnsureRemote(Name: string): RemoteEvent
	local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if not RemotesFolder then
		RemotesFolder = Instance.new("Folder")
		RemotesFolder.Name = "Remotes"
		RemotesFolder.Parent = ReplicatedStorage
	end

	local Existing = RemotesFolder:FindFirstChild(Name)
	if Existing and Existing:IsA("RemoteEvent") then
		return Existing
	end

	local Remote = Instance.new("RemoteEvent")
	Remote.Name = Name
	Remote.Parent = RemotesFolder
	return Remote
end

local function GetGrowthService()
	return ServiceRegistry.Get("GrowthService")
end

-- Calculate the RequiredLevel for a given rebirth count (server-only).
-- Rebirth 0 -> 1: Level 20
-- Rebirth 1 -> 2: Level 50
-- Rebirth 2 -> 3: Level 75
-- Rebirth 3 -> 4: Level 100
-- Rebirth 4 -> 5: Level 150
-- Rebirth 5+: 150 + ((CurrentRebirth - 4) * 50)
local function CalculateRequiredLevel(Rebirths: number): number
	if Rebirths == 0 then
		return 20
	elseif Rebirths == 1 then
		return 50
	elseif Rebirths == 2 then
		return 75
	elseif Rebirths == 3 then
		return 100
	elseif Rebirths == 4 then
		return 150
	else
		return 150 + (Rebirths - 4) * 50
	end
end

-- Calculate the RequiredSize for a given RequiredLevel.
local function CalculateRequiredSize(RequiredLevel: number): number
	return LevelFormula.GetRequirement(RequiredLevel)
end

-- Build a preview snapshot for N future tiers after CurrentRebirths.
local function BuildPreviewTiers(CurrentRebirths: number): { RebirthTierSnapshot }
	local Tiers: { RebirthTierSnapshot } = {}
	for i = 0, RebirthConfig.MaxPreviewTiers - 1 do
		local FutureRebirths = CurrentRebirths + 1 + i
		local FutureReqLevel = CalculateRequiredLevel(CurrentRebirths + i)
		table.insert(Tiers, {
			RequiredSize = CalculateRequiredSize(FutureReqLevel),
			GrowthMultiplier = math.max(1, FutureRebirths + 1),
		})
	end
	return Tiers
end

-- Compute the full RebirthUpdate payload for a player.
local function BuildUpdate(Player: Player, Error: string?): RebirthUpdate
	UpdateVersion += 1
	local Session = Sessions.Get(Player)
	if not Session then
		return {
			Version = UpdateVersion,
			Timestamp = os.time(),
			CurrentSize = 0,
			RequiredSize = 0,
			CurrentLevel = 1,
			RequiredLevel = 20,
			GrowthMultiplier = 1,
			NextGrowthMultiplier = 2,
			Rebirths = 0,
			CanRebirth = false,
			PreviewTiers = {},
			Error = Error or RebirthError.SessionMissing,
		}
	end

	local CurrentSize = Session.Bigger
	local CurrentLevel = LevelFormula.GetLevel(CurrentSize)
	local RequiredLevel = CalculateRequiredLevel(Session.Rebirth)
	local RequiredSize = CalculateRequiredSize(RequiredLevel)
	local CanRebirth = CurrentLevel >= RequiredLevel
	local Multiplier = GrowthFormula.GetMultiplier(Session)
	local BaseMult = (if Session.HasDoubleMultiplier then 2 else 1) * (if Session.HasVip then 2 else 1)
	local NextMultiplier = BaseMult * (Session.Rebirth + 2)

	return {
		Version = UpdateVersion,
		Timestamp = os.time(),
		CurrentSize = CurrentSize,
		RequiredSize = RequiredSize,
		CurrentLevel = CurrentLevel,
		RequiredLevel = RequiredLevel,
		GrowthMultiplier = Multiplier,
		NextGrowthMultiplier = NextMultiplier,
		Rebirths = Session.Rebirth,
		CanRebirth = CanRebirth,
		PreviewTiers = BuildPreviewTiers(Session.Rebirth),
		Error = Error or RebirthError.None,
	}
end

-- Push the authoritative snapshot to the client.
local function PushUpdate(Player: Player, Error: string?)
	local Payload = BuildUpdate(Player, Error)
	local Ok, Err = pcall(function()
		UpdateRebirthRemote:FireClient(Player, Payload)
	end)
	if not Ok then
		Logger.Warn("Rebirth", "Failed to push UpdateRebirth to %s: %s", Player.Name, tostring(Err))
	end
end

-- Core rebirth mutation: increment Rebirth, reset Size via GrowthService.
-- Returns true on success.
local function ApplyRebirth(Player: Player, SkipSizeCheck: boolean): boolean
	local Session = Sessions.Get(Player)
	if not Session then
		PushUpdate(Player, RebirthError.SessionMissing)
		return false
	end
	if Session.ProfileMutationsFrozen then
		PushUpdate(Player, RebirthError.Frozen)
		return false
	end
	if Session.State ~= "InLobby" then
		PushUpdate(Player, RebirthError.NotInLobby)
		return false
	end

	local RequiredLevel = CalculateRequiredLevel(Session.Rebirth)
	local CurrentLevel = LevelFormula.GetLevel(Session.Bigger)
	if not SkipSizeCheck and CurrentLevel < RequiredLevel then
		PushUpdate(Player, RebirthError.SizeRequirementNotMet)
		return false
	end

	-- Mutate: increment Rebirth
	local Mutated = Sessions.Mutate(Player, function(S: Session)
		S.Rebirth += 1
	end)
	if not Mutated then
		PushUpdate(Player, RebirthError.Frozen)
		return false
	end

	-- Reset Size via GrowthService pipeline (attribute + leaderstats + BiggerChanged event + CharacterScaleService)
	local GrowthService = GetGrowthService()
	if GrowthService then
		pcall(function()
			GrowthService:SetBigger(Player, RebirthConfig.RebirthResetSize)
		end)
	end

	-- Refresh Multiplier attribute (reflects new Rebirth factor)
	if GrowthService then
		pcall(function()
			GrowthService:UpdateMultiplierAttribute(Player)
		end)
	end

	-- Set cooldown
	RebirthCooldowns[Player] = os.clock() + RebirthConfig.CooldownSeconds
	task.delay(RebirthConfig.CooldownSeconds, function()
		RebirthCooldowns[Player] = nil
	end)

	Logger.Info("Rebirth", "Player %s completed rebirth (Rebirths=%d)", Player.Name, Session.Rebirth)
	PushUpdate(Player, nil)
	return true
end

local function OnRequestRebirth(Player: Player, Action: string?)
	if Action == "Refresh" then
		PushUpdate(Player, nil)
		return
	end
	-- Cooldown check (per-player, never blocks other players)
	if RebirthCooldowns[Player] and os.clock() < RebirthCooldowns[Player] then
		PushUpdate(Player, RebirthError.OnCooldown)
		return
	end
	ApplyRebirth(Player, false)
end

local function OnRequestSkipRebirth(Player: Player)
	-- Cooldown check
	if RebirthCooldowns[Player] and os.clock() < RebirthCooldowns[Player] then
		PushUpdate(Player, RebirthError.OnCooldown)
		return
	end

	-- Prompt the marketplace purchase. The actual reward grant flows through
	-- ReceiptProcessingService -> RewardService -> RewardDispatcher [SkipRebirth].
	pcall(function()
		MarketplaceService:PromptProductPurchase(Player, RebirthConfig.SkipRebirthProductId)
	end)
end

-- Per-player Registry management.
local function DestroyPlayerRegistry(Player: Player)
	local Registry = PlayerRegistries[Player]
	if not Registry then
		return
	end
	if Registry.Destroyed then
		return
	end
	Registry.Destroyed = true

	for _, Connection in Registry.Connections do
		Connection:Disconnect()
	end
	table.clear(Registry.Connections)

	PlayerRegistries[Player] = nil
end

local function OnPlayerAdded(Player: Player)
	local Registry = {
		Connections = {},
		Destroyed = false,
	}
	PlayerRegistries[Player] = Registry
end

local function OnPlayerRemoving(Player: Player)
	-- Clear cooldown (RebirthService-owned)
	RebirthCooldowns[Player] = nil
	-- Destroy player Registry (RebirthService-owned)
	DestroyPlayerRegistry(Player)
	-- Session ownership remains with SessionService — do NOT remove session references.
end

local function OnSessionCreated(Player: Player)
	-- Push initial authoritative snapshot after session is ready.
	-- Delay 1 frame to ensure GrowthService attributes are projected.
	task.spawn(function()
		task.wait()
		PushUpdate(Player, nil)
	end)
end

-- Subscribe to EventBus for session lifecycle signals.
local function SubscribeEventBus()
	local EventBus = require(script.Parent.Parent.Parent.Core.Events.EventBus)
	EventBus.Subscribe("PlayerSessionCreated", function(Player: Player)
		OnSessionCreated(Player)
	end)
	EventBus.Subscribe("BiggerChanged", function(Player: Player)
		PushUpdate(Player, nil)
	end)
end

--// Service \\--
local RebirthService = {}

function RebirthService:Init()
	-- Ensure remotes (idempotent)
	RequestRebirthRemote = EnsureRemote("RequestRebirth")
	RequestSkipRebirthRemote = EnsureRemote("RequestSkipRebirth")
	UpdateRebirthRemote = EnsureRemote("UpdateRebirth")

	RequestRebirthRemote.OnServerEvent:Connect(function(Client: Player, Action: any)
		OnRequestRebirth(Client, Action)
	end)

	RequestSkipRebirthRemote.OnServerEvent:Connect(function(Client: Player)
		OnRequestSkipRebirth(Client)
	end)

	Players.PlayerAdded:Connect(OnPlayerAdded)
	Players.PlayerRemoving:Connect(OnPlayerRemoving)

	SubscribeEventBus()

	-- Wire existing players (e.g. if service inits after some players joined)
	for _, Player in Players:GetPlayers() do
		task.spawn(OnPlayerAdded, Player)
	end

	Logger.Info("Rebirth", "RebirthService initialized")
end

function RebirthService:Start()
	-- Push initial updates for already-loaded players
	for _, Player in Players:GetPlayers() do
		if Sessions.Get(Player) then
			task.spawn(PushUpdate, Player, nil)
		end
	end
end

-- Called by RewardDispatcher [SkipRebirth] handler.
-- Bypasses Size requirement but goes through the same ApplyRebirth path.
function RebirthService:ApplySkipRebirth(Player: Player): boolean
	-- Cooldown check
	if RebirthCooldowns[Player] and os.clock() < RebirthCooldowns[Player] then
		PushUpdate(Player, RebirthError.OnCooldown)
		return false
	end
	return ApplyRebirth(Player, true)
end

function RebirthService:Destroy()
	for Player in PlayerRegistries do
		DestroyPlayerRegistry(Player)
	end
	table.clear(RebirthCooldowns)
	table.clear(PlayerRegistries)
end

return RebirthService
