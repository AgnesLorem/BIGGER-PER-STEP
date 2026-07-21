--!strict
-- src/server/Game/Services/EquipmentService.luau
-- Server-authoritative Growth Upgrades equipment service.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sessions = require(script.Parent.Parent.Parent.Core.Registry.RuntimeRegistry.Sessions)
local ServiceRegistry = require(script.Parent.Parent.Parent.Core.Registry.ServiceRegistry)
local Logger = require(script.Parent.Parent.Parent.Core.Utilities.Logger)
local EventBus = require(script.Parent.Parent.Parent.Core.Events.EventBus)

local UpgradesConfig = require(
	ReplicatedStorage:WaitForChild("BiggerShared")
		:WaitForChild("Game")
		:WaitForChild("Config")
		:WaitForChild("UpgradesConfig")
)
local LevelFormula = require(
	ReplicatedStorage:WaitForChild("BiggerShared")
		:WaitForChild("Game")
		:WaitForChild("Progression")
		:WaitForChild("LevelFormula")
)

export type EquipmentState = {
	EquippedUpgradeId: string,
	UnlockedUpgradeIds: { string },
}

local ResultCodes = table.freeze({
	Success = "Success",
	NoSession = "NoSession",
	Frozen = "Frozen",
	InvalidUpgrade = "InvalidUpgrade",
	AlreadyUnlocked = "AlreadyUnlocked",
	PreviousUpgradeLocked = "PreviousUpgradeLocked",
	RequirementsNotMet = "RequirementsNotMet",
	NotUnlocked = "NotUnlocked",
	RateLimited = "RateLimited",
	RequestInFlight = "RequestInFlight",
	PlayerDisconnected = "PlayerDisconnected",
	MutationFailed = "MutationFailed",
})

local EquipmentService = {}
EquipmentService.ResultCodes = ResultCodes

local InFlightRequests: { [Player]: boolean } = {}
local LastRequestTimestamp: { [Player]: number } = {}

local EquipmentFolder: Folder
local UnlockRemote: RemoteFunction
local EquipRemote: RemoteFunction
local GetStateRemote: RemoteFunction
local StateChangedRemote: RemoteEvent

local function BuildEquipmentState(Session: Sessions.Session): EquipmentState
	local UnlockedList: { string } = {}
	for _, Id in UpgradesConfig.Sequence do
		if Id ~= "None" and Session.UnlockedGrowthUpgrades[Id] == true then
			table.insert(UnlockedList, Id)
		end
	end
	return {
		EquippedUpgradeId = Session.EquippedGrowthUpgrade or "None",
		UnlockedUpgradeIds = UnlockedList,
	}
end

function EquipmentService:Init()
	local EventsFolder = ReplicatedStorage:FindFirstChild("BiggerEvents") :: Folder?
	if not EventsFolder then
		EventsFolder = Instance.new("Folder")
		EventsFolder.Name = "BiggerEvents"
		EventsFolder.Parent = ReplicatedStorage
	end

	EquipmentFolder = EventsFolder:FindFirstChild("Equipment") :: Folder?
	if not EquipmentFolder then
		EquipmentFolder = Instance.new("Folder")
		EquipmentFolder.Name = "Equipment"
		EquipmentFolder.Parent = EventsFolder
	end

	UnlockRemote = EquipmentFolder:FindFirstChild("UnlockUpgrade") :: RemoteFunction?
	if not UnlockRemote then
		UnlockRemote = Instance.new("RemoteFunction")
		UnlockRemote.Name = "UnlockUpgrade"
		UnlockRemote.Parent = EquipmentFolder
	end

	EquipRemote = EquipmentFolder:FindFirstChild("EquipUpgrade") :: RemoteFunction?
	if not EquipRemote then
		EquipRemote = Instance.new("RemoteFunction")
		EquipRemote.Name = "EquipUpgrade"
		EquipRemote.Parent = EquipmentFolder
	end

	GetStateRemote = EquipmentFolder:FindFirstChild("GetEquipmentState") :: RemoteFunction?
	if not GetStateRemote then
		GetStateRemote = Instance.new("RemoteFunction")
		GetStateRemote.Name = "GetEquipmentState"
		GetStateRemote.Parent = EquipmentFolder
	end

	StateChangedRemote = EquipmentFolder:FindFirstChild("EquipmentStateChanged") :: RemoteEvent?
	if not StateChangedRemote then
		StateChangedRemote = Instance.new("RemoteEvent")
		StateChangedRemote.Name = "EquipmentStateChanged"
		StateChangedRemote.Parent = EquipmentFolder
	end

	UnlockRemote.OnServerInvoke = function(Player: Player, UpgradeId: unknown)
		return self:InvokeUnlockSafe(Player, UpgradeId)
	end

	EquipRemote.OnServerInvoke = function(Player: Player, UpgradeId: unknown)
		return self:InvokeEquipSafe(Player, UpgradeId)
	end

	GetStateRemote.OnServerInvoke = function(Player: Player)
		return self:GetEquipmentState(Player)
	end
end

function EquipmentService:Start()
	EventBus.Subscribe("PlayerSessionCreated", function(Player: Player, Session: Sessions.Session)
		self:OnSessionCreated(Player, Session)
	end)

	EventBus.Subscribe("PlayerSessionDestroyed", function(Player: Player)
		self:OnSessionDestroyed(Player)
	end)
end

function EquipmentService:OnSessionCreated(Player: Player, Session: Sessions.Session)
	-- Validate equipped upgrade against unlocked map on load
	if Session.EquippedGrowthUpgrade ~= nil then
		if not UpgradesConfig.CanEquip(Session.UnlockedGrowthUpgrades, Session.EquippedGrowthUpgrade) then
			Logger.Warn(
				"Equipment",
				"Invalid or locked equipped upgrade %s for %s, resetting to None",
				tostring(Session.EquippedGrowthUpgrade),
				Player.Name
			)
			Session.EquippedGrowthUpgrade = nil
		end
	end

	Player:SetAttribute("EquippedGrowthUpgrade", Session.EquippedGrowthUpgrade or "None")

	local Success, GrowthService = pcall(function()
		return ServiceRegistry.Get("GrowthService")
	end)
	if Success and GrowthService then
		GrowthService:UpdateMultiplierAttribute(Player)
	end

	if StateChangedRemote then
		StateChangedRemote:FireClient(Player, BuildEquipmentState(Session))
	end
end

function EquipmentService:OnSessionDestroyed(Player: Player)
	InFlightRequests[Player] = nil
	LastRequestTimestamp[Player] = nil
end

local function CheckRateLimitAndLock(Player: Player): (boolean, string)
	if Player.Parent ~= Players then
		return false, ResultCodes.PlayerDisconnected
	end
	if InFlightRequests[Player] then
		return false, ResultCodes.RequestInFlight
	end

	local Now = os.clock()
	local Last = LastRequestTimestamp[Player] or 0
	if Now - Last < 0.1 then
		return false, ResultCodes.RateLimited
	end

	InFlightRequests[Player] = true
	LastRequestTimestamp[Player] = Now
	return true, ResultCodes.Success
end

local function ReleaseLock(Player: Player)
	InFlightRequests[Player] = nil
end

function EquipmentService:InvokeUnlockSafe(Player: Player, UpgradeId: unknown): (boolean, string)
	local Allowed, Code = CheckRateLimitAndLock(Player)
	if not Allowed then
		return false, Code
	end

	local Success, Ok, Msg = pcall(function()
		if type(UpgradeId) ~= "string" then
			return false, ResultCodes.InvalidUpgrade
		end
		return self:UnlockUpgrade(Player, UpgradeId)
	end)

	ReleaseLock(Player)
	if not Success then
		Logger.Warn("Equipment", "UnlockUpgrade exception for %s: %s", Player.Name, tostring(Ok))
		return false, ResultCodes.MutationFailed
	end
	return Ok == true, tostring(Msg)
end

function EquipmentService:InvokeEquipSafe(Player: Player, UpgradeId: unknown): (boolean, string)
	local Allowed, Code = CheckRateLimitAndLock(Player)
	if not Allowed then
		return false, Code
	end

	local Success, Ok, Msg = pcall(function()
		if UpgradeId ~= nil and type(UpgradeId) ~= "string" then
			return false, ResultCodes.InvalidUpgrade
		end
		return self:EquipUpgrade(Player, UpgradeId :: string?)
	end)

	ReleaseLock(Player)
	if not Success then
		Logger.Warn("Equipment", "EquipUpgrade exception for %s: %s", Player.Name, tostring(Ok))
		return false, ResultCodes.MutationFailed
	end
	return Ok == true, tostring(Msg)
end

function EquipmentService:GetEquipmentState(Player: Player): EquipmentState?
	local Session = Sessions.Get(Player)
	if not Session then
		return nil
	end
	return BuildEquipmentState(Session)
end

function EquipmentService:UnlockUpgrade(Player: Player, UpgradeId: string): (boolean, string)
	if Player.Parent ~= Players then
		return false, ResultCodes.PlayerDisconnected
	end

	local Session = Sessions.Get(Player)
	if not Session then
		return false, ResultCodes.NoSession
	end
	if Session.ProfileMutationsFrozen then
		return false, ResultCodes.Frozen
	end
	if UpgradeId == "None" or UpgradeId == "" or not UpgradesConfig.Upgrades[UpgradeId] then
		return false, ResultCodes.InvalidUpgrade
	end
	if Session.UnlockedGrowthUpgrades[UpgradeId] == true then
		return false, ResultCodes.AlreadyUnlocked
	end

	local RequiredPrev = UpgradesConfig.GetPreviousUpgradeId(UpgradeId)
	if RequiredPrev and Session.UnlockedGrowthUpgrades[RequiredPrev] ~= true then
		return false, ResultCodes.PreviousUpgradeLocked
	end

	local AuthoritativeLevel = LevelFormula.GetLevelFromBigger(Session.Bigger)
	if
		not UpgradesConfig.CanUnlock(Session.UnlockedGrowthUpgrades, Session.Destruction, AuthoritativeLevel, UpgradeId)
	then
		return false, ResultCodes.RequirementsNotMet
	end

	local Mutated = Sessions.Mutate(Player, function(S)
		S.UnlockedGrowthUpgrades[UpgradeId] = true
	end)
	if not Mutated then
		return false, ResultCodes.MutationFailed
	end

	Player:SetAttribute("EquippedGrowthUpgrade", Session.EquippedGrowthUpgrade or "None")

	if StateChangedRemote then
		StateChangedRemote:FireClient(Player, BuildEquipmentState(Session))
	end

	-- Queue immediate non-blocking save
	local SaveServiceOk, SaveService = pcall(function()
		return ServiceRegistry.Get("SaveService")
	end)
	if SaveServiceOk and SaveService then
		SaveService:QueueProfileSave(Player)
	end

	Logger.Info("Equipment", "Player %s unlocked upgrade %s", Player.Name, UpgradeId)
	return true, ResultCodes.Success
end

function EquipmentService:EquipUpgrade(Player: Player, UpgradeId: string?): (boolean, string)
	if Player.Parent ~= Players then
		return false, ResultCodes.PlayerDisconnected
	end

	local Session = Sessions.Get(Player)
	if not Session then
		return false, ResultCodes.NoSession
	end
	if Session.ProfileMutationsFrozen then
		return false, ResultCodes.Frozen
	end

	local TargetId = if not UpgradeId or UpgradeId == "" or UpgradeId == "None" then "None" else UpgradeId
	if TargetId ~= "None" and not UpgradesConfig.Upgrades[TargetId] then
		return false, ResultCodes.InvalidUpgrade
	end

	if TargetId ~= "None" and Session.UnlockedGrowthUpgrades[TargetId] ~= true then
		return false, ResultCodes.NotUnlocked
	end

	local CurrentEquipped = Session.EquippedGrowthUpgrade or "None"
	if CurrentEquipped == TargetId then
		return true, ResultCodes.Success -- No-op success without creating redundant save
	end

	local Mutated = Sessions.Mutate(Player, function(S)
		S.EquippedGrowthUpgrade = if TargetId == "None" then nil else TargetId
	end)
	if not Mutated then
		return false, ResultCodes.MutationFailed
	end

	Player:SetAttribute("EquippedGrowthUpgrade", TargetId)

	local GrowthServiceOk, GrowthService = pcall(function()
		return ServiceRegistry.Get("GrowthService")
	end)
	if GrowthServiceOk and GrowthService then
		GrowthService:UpdateMultiplierAttribute(Player)
	end

	if StateChangedRemote then
		StateChangedRemote:FireClient(Player, BuildEquipmentState(Session))
	end

	-- Queue immediate non-blocking save
	local SaveServiceOk, SaveService = pcall(function()
		return ServiceRegistry.Get("SaveService")
	end)
	if SaveServiceOk and SaveService then
		SaveService:QueueProfileSave(Player)
	end

	Logger.Info("Equipment", "Player %s equipped upgrade %s", Player.Name, TargetId)
	return true, ResultCodes.Success
end

return EquipmentService
