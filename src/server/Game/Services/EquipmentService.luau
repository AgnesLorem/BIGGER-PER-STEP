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

export type EquipmentState = {
	EquippedUpgradeId: string,
	UnlockedUpgradeIds: { string },
}

type EquipmentRequest = {
	RequestId: string,
	Operation: string,
	Payload: unknown,
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
	InvalidRequest = "InvalidRequest",
})

local EquipmentService = {}
EquipmentService.ResultCodes = ResultCodes

local EquipmentFolder: Folder
local RequestRemote: RemoteEvent
local ResponseRemote: RemoteEvent
local StateChangedRemote: RemoteEvent
local Initialized = false
local Started = false
local Connections: { RBXScriptConnection } = {}
local SessionCreatedCallback: ((Player, Sessions.Session) -> ())? = nil
local SessionDestroyedCallback: ((Player) -> ())? = nil
local HandleRequest: (Player, unknown) -> ()

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

local function QueueImmediateSave(Player: Player, ActionName: string, UpgradeId: string)
	local SaveServiceOk, SaveService = pcall(function()
		return ServiceRegistry.Get("SaveService")
	end)
	if SaveServiceOk and SaveService then
		local SaveQueued = SaveService:QueueProfileSave(Player)
		if not SaveQueued then
			Logger.Warn(
				"Equipment",
				"Immediate save queue failed for %s during %s %s",
				Player.Name,
				ActionName,
				UpgradeId
			)
		end
	else
		Logger.Warn(
			"Equipment",
			"SaveService unavailable to queue save for %s during %s %s",
			Player.Name,
			ActionName,
			UpgradeId
		)
	end
end

local function GetOrCreate(Parent: Instance, Name: string, ClassName: string): Instance
	local Existing = Parent:FindFirstChild(Name)
	if Existing then
		assert(Existing:IsA(ClassName), string.format("Equipment.%s must be a %s", Name, ClassName))
		return Existing
	end
	local Created = Instance.new(ClassName)
	Created.Name = Name
	Created.Parent = Parent
	return Created
end

function EquipmentService:Init()
	if Initialized then
		return
	end

	local EventsFolder = ReplicatedStorage:FindFirstChild("BiggerEvents") :: Folder?
	if not EventsFolder then
		EventsFolder = GetOrCreate(ReplicatedStorage, "BiggerEvents", "Folder") :: Folder
	elseif not EventsFolder:IsA("Folder") then
		error("BiggerEvents must be a Folder")
	end

	EquipmentFolder = GetOrCreate(EventsFolder, "Equipment", "Folder") :: Folder
	RequestRemote = GetOrCreate(EquipmentFolder, "Request", "RemoteEvent") :: RemoteEvent
	ResponseRemote = GetOrCreate(EquipmentFolder, "Response", "RemoteEvent") :: RemoteEvent
	StateChangedRemote = GetOrCreate(EquipmentFolder, "StateChanged", "RemoteEvent") :: RemoteEvent
	table.insert(Connections, RequestRemote.OnServerEvent:Connect(HandleRequest))
	Initialized = true
end

function EquipmentService:Start()
	if Started then
		return
	end
	Started = true

	SessionCreatedCallback = function(Player: Player, Session: Sessions.Session)
		self:OnSessionCreated(Player, Session)
	end
	SessionDestroyedCallback = function(Player: Player)
		self:OnSessionDestroyed(Player)
	end
	EventBus.Subscribe("PlayerSessionCreated", SessionCreatedCallback)
	EventBus.Subscribe("PlayerSessionDestroyed", SessionDestroyedCallback)

	table.insert(
		Connections,
		Players.PlayerRemoving:Connect(function(Player: Player)
			self:OnSessionDestroyed(Player)
		end)
	)
end

function EquipmentService:OnSessionCreated(Player: Player, Session: Sessions.Session)
	-- Validate equipped upgrade against unlocked map on load
	if Session.EquippedGrowthUpgrade ~= nil then
		if not UpgradesConfig.CanEquip(Session.UnlockedGrowthUpgrades, Session.EquippedGrowthUpgrade) then
			local InvalidUpgrade = tostring(Session.EquippedGrowthUpgrade)
			local Mutated = Sessions.Mutate(Player, function(S)
				S.EquippedGrowthUpgrade = nil
			end)
			if Mutated then
				Logger.Warn(
					"Equipment",
					"Repaired invalid equipped upgrade %s for %s, reset to None",
					InvalidUpgrade,
					Player.Name
				)
				QueueImmediateSave(Player, "SessionLoadRepair", InvalidUpgrade)
			else
				Logger.Warn(
					"Equipment",
					"Failed to mutate session for invalid equipped upgrade %s for %s",
					InvalidUpgrade,
					Player.Name
				)
			end
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
	local Session = Sessions.Get(Player)
	if Session then
		Session.EquipmentRequestInFlight = false
		Session.EquipmentLastRequestTimestamp = 0
	end
end

local function CheckRateLimitAndLock(Player: Player): (boolean, string)
	if Player.Parent ~= Players then
		return false, ResultCodes.PlayerDisconnected
	end
	local Session = Sessions.Get(Player)
	if not Session then
		return false, ResultCodes.NoSession
	end
	if Session.EquipmentRequestInFlight then
		return false, ResultCodes.RequestInFlight
	end

	local Now = os.clock()
	local Last = Session.EquipmentLastRequestTimestamp or 0
	if Now - Last < 0.1 then
		return false, ResultCodes.RateLimited
	end

	Session.EquipmentRequestInFlight = true
	Session.EquipmentLastRequestTimestamp = Now
	return true, ResultCodes.Success
end

local function ReleaseLock(Player: Player)
	local Session = Sessions.Get(Player)
	if Session then
		Session.EquipmentRequestInFlight = false
	end
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

	if not UpgradesConfig.CanUnlock(Session.UnlockedGrowthUpgrades, Session.Destruction, UpgradeId) then
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

	QueueImmediateSave(Player, "UnlockUpgrade", UpgradeId)

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

	QueueImmediateSave(Player, "EquipUpgrade", TargetId)

	Logger.Info("Equipment", "Player %s equipped upgrade %s", Player.Name, TargetId)
	return true, ResultCodes.Success
end

local function SendResponse(Player: Player, RequestId: string, Success: boolean, ErrorCode: string)
	ResponseRemote:FireClient(Player, {
		RequestId = RequestId,
		Success = Success,
		ErrorCode = ErrorCode,
		StateSnapshot = EquipmentService:GetEquipmentState(Player),
	})
end

local function ParseRequest(Value: unknown): EquipmentRequest?
	if type(Value) ~= "table" then
		return nil
	end
	local Request = Value :: any
	if
		type(Request.RequestId) ~= "string"
		or #Request.RequestId < 1
		or #Request.RequestId > 64
		or (Request.Operation ~= "GetState" and Request.Operation ~= "Unlock" and Request.Operation ~= "Equip")
	then
		return nil
	end
	return Request :: EquipmentRequest
end

HandleRequest = function(Player: Player, Value: unknown)
	local Request = ParseRequest(Value)
	if not Request then
		return
	end

	if Request.Operation == "Unlock" then
		local Payload = Request.Payload
		if type(Payload) ~= "table" or type((Payload :: any).UpgradeId) ~= "string" then
			SendResponse(Player, Request.RequestId, false, ResultCodes.InvalidRequest)
			return
		end
		local Success, Code = EquipmentService:InvokeUnlockSafe(Player, (Payload :: any).UpgradeId)
		SendResponse(Player, Request.RequestId, Success, Code)
		return
	end

	if Request.Operation == "Equip" then
		local Payload = Request.Payload
		if type(Payload) ~= "table" then
			SendResponse(Player, Request.RequestId, false, ResultCodes.InvalidRequest)
			return
		end
		local UpgradeId = (Payload :: any).UpgradeId
		if UpgradeId ~= nil and type(UpgradeId) ~= "string" then
			SendResponse(Player, Request.RequestId, false, ResultCodes.InvalidRequest)
			return
		end
		local Success, Code = EquipmentService:InvokeEquipSafe(Player, UpgradeId)
		SendResponse(Player, Request.RequestId, Success, Code)
		return
	end

	local Allowed, Code = CheckRateLimitAndLock(Player)
	if not Allowed then
		SendResponse(Player, Request.RequestId, false, Code)
		return
	end
	ReleaseLock(Player)
	SendResponse(Player, Request.RequestId, true, ResultCodes.Success)
end

function EquipmentService:Destroy()
	for _, Connection in Connections do
		Connection:Disconnect()
	end
	table.clear(Connections)
	if SessionCreatedCallback then
		EventBus.Unsubscribe("PlayerSessionCreated", SessionCreatedCallback)
	end
	if SessionDestroyedCallback then
		EventBus.Unsubscribe("PlayerSessionDestroyed", SessionDestroyedCallback)
	end
	SessionCreatedCallback = nil
	SessionDestroyedCallback = nil
	Initialized = false
	Started = false
end

return EquipmentService
