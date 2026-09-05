--!strict
-- src/client/controllers/EquipmentController.luau
-- Client controller managing Growth Upgrades equipment state and RPC calls.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HttpService = game:GetService("HttpService")
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
export type ResponseCallback = (boolean, string, EquipmentState?) -> ()

type PendingRequest = {
	Callback: ResponseCallback,
}

local LocalState: EquipmentState = {
	EquippedUpgradeId = "None",
	UnlockedUpgradeIds = {},
}

local StateChangedCallbacks: { (EquipmentState) -> () } = {}
local PendingRequests: { [string]: PendingRequest } = {}
local PendingCount = 0

local EquipmentController = {}

local RequestRemote: RemoteEvent?
local ResponseRemote: RemoteEvent?
local StateChangedRemote: RemoteEvent?
local ResponseConnection: RBXScriptConnection?
local StateConnection: RBXScriptConnection?
local Initialized = false
local Started = false
local MAX_PENDING_REQUESTS = 32
local REQUEST_TIMEOUT_SECONDS = 5

local function IsValidState(Value: unknown): boolean
	if type(Value) ~= "table" then
		return false
	end
	local State = Value :: any
	if type(State.EquippedUpgradeId) ~= "string" or not UpgradesConfig.Upgrades[State.EquippedUpgradeId] then
		return false
	end
	if type(State.UnlockedUpgradeIds) ~= "table" then
		return false
	end
	local Seen: { [string]: boolean } = {}
	for _, UpgradeId in State.UnlockedUpgradeIds do
		if
			type(UpgradeId) ~= "string"
			or UpgradeId == "None"
			or not UpgradesConfig.Upgrades[UpgradeId]
			or Seen[UpgradeId]
		then
			return false
		end
		Seen[UpgradeId] = true
	end
	return State.EquippedUpgradeId == "None" or Seen[State.EquippedUpgradeId] == true
end

local function NotifyStateChanged()
	local Snapshot = EquipmentController.GetState()
	for _, Callback in StateChangedCallbacks do
		task.spawn(Callback, Snapshot)
	end
end

local function ApplyState(Value: unknown): boolean
	if not IsValidState(Value) then
		return false
	end
	local State = Value :: EquipmentState
	LocalState = {
		EquippedUpgradeId = State.EquippedUpgradeId,
		UnlockedUpgradeIds = table.clone(State.UnlockedUpgradeIds),
	}
	NotifyStateChanged()
	return true
end

local function OnResponse(Value: unknown)
	if type(Value) ~= "table" then
		return
	end
	local Response = Value :: any
	if
		type(Response.RequestId) ~= "string"
		or type(Response.Success) ~= "boolean"
		or type(Response.ErrorCode) ~= "string"
	then
		return
	end
	local Pending = PendingRequests[Response.RequestId]
	if not Pending then
		return
	end
	PendingRequests[Response.RequestId] = nil
	PendingCount -= 1

	local State = if IsValidState(Response.StateSnapshot) then Response.StateSnapshot :: EquipmentState else nil
	if State then
		ApplyState(State)
	end
	local Called, Message = pcall(Pending.Callback, Response.Success, Response.ErrorCode, State)
	if not Called then
		warn("Equipment response callback failed: " .. tostring(Message))
	end
end

function EquipmentController.Init()
	if Initialized then
		return
	end

	local EventsFolder = ReplicatedStorage:WaitForChild("BiggerEvents", 5) :: Folder?
	if EventsFolder then
		local EquipmentFolder = EventsFolder:WaitForChild("Equipment", 5) :: Folder?
		if EquipmentFolder then
			local Request = EquipmentFolder:WaitForChild("Request", 5)
			local Response = EquipmentFolder:WaitForChild("Response", 5)
			local StateChanged = EquipmentFolder:WaitForChild("StateChanged", 5)
			if Request and Request:IsA("RemoteEvent") then
				RequestRemote = Request
			end
			if Response and Response:IsA("RemoteEvent") then
				ResponseRemote = Response
			end
			if StateChanged and StateChanged:IsA("RemoteEvent") then
				StateChangedRemote = StateChanged
			end
		end
	end

	if ResponseRemote then
		ResponseConnection = ResponseRemote.OnClientEvent:Connect(OnResponse)
	end
	if StateChangedRemote then
		StateConnection = StateChangedRemote.OnClientEvent:Connect(ApplyState)
	end
	Initialized = true
end

function EquipmentController.Start()
	if Started then
		return
	end
	Started = true
	EquipmentController.RequestState(function() end)
end

function EquipmentController.GetState(): EquipmentState
	return {
		EquippedUpgradeId = LocalState.EquippedUpgradeId,
		UnlockedUpgradeIds = table.clone(LocalState.UnlockedUpgradeIds),
	}
end

function EquipmentController.OnStateChanged(Callback: (EquipmentState) -> ()): () -> ()
	table.insert(StateChangedCallbacks, Callback)
	Callback(EquipmentController.GetState())

	return function()
		local Index = table.find(StateChangedCallbacks, Callback)
		if Index then
			table.remove(StateChangedCallbacks, Index)
		end
	end
end

local function SendRequest(Operation: string, Payload: unknown, Callback: ResponseCallback): (string?, string?)
	if not RequestRemote or not ResponseRemote then
		return nil, "RemoteNotReady"
	end
	if PendingCount >= MAX_PENDING_REQUESTS then
		return nil, "TooManyPendingRequests"
	end

	local RequestId = HttpService:GenerateGUID(false)
	if #RequestId > 64 or PendingRequests[RequestId] then
		return nil, "RequestIdUnavailable"
	end
	PendingRequests[RequestId] = { Callback = Callback }
	PendingCount += 1
	task.delay(REQUEST_TIMEOUT_SECONDS, function()
		local Pending = PendingRequests[RequestId]
		if not Pending then
			return
		end
		PendingRequests[RequestId] = nil
		PendingCount -= 1
		Pending.Callback(false, "Timeout", nil)
	end)
	RequestRemote:FireServer({
		RequestId = RequestId,
		Operation = Operation,
		Payload = Payload,
	})
	return RequestId, nil
end

function EquipmentController.RequestState(Callback: ResponseCallback): (string?, string?)
	return SendRequest("GetState", {}, Callback)
end

function EquipmentController.RequestUnlock(UpgradeId: string, Callback: ResponseCallback): (string?, string?)
	return SendRequest("Unlock", { UpgradeId = UpgradeId }, Callback)
end

function EquipmentController.RequestEquip(UpgradeId: string?, Callback: ResponseCallback): (string?, string?)
	return SendRequest("Equip", { UpgradeId = UpgradeId }, Callback)
end

function EquipmentController.Destroy()
	if ResponseConnection then
		ResponseConnection:Disconnect()
		ResponseConnection = nil
	end
	if StateConnection then
		StateConnection:Disconnect()
		StateConnection = nil
	end
	for RequestId, Pending in PendingRequests do
		PendingRequests[RequestId] = nil
		Pending.Callback(false, "ControllerDestroyed", nil)
	end
	PendingCount = 0
	Initialized = false
	Started = false
end

return EquipmentController
