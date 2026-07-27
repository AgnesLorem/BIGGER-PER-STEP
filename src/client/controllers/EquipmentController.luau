--!strict
-- src/client/controllers/EquipmentController.luau
-- Client controller managing Growth Upgrades equipment state and RPC calls.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MAX_UPGRADE_ID_LENGTH = 64

export type EquipmentState = {
	EquippedUpgradeId: string,
	UnlockedUpgradeIds: { string },
}

local LocalState: EquipmentState = {
	EquippedUpgradeId = "None",
	UnlockedUpgradeIds = {},
}

local StateChangedCallbacks: { (EquipmentState) -> () } = {}

local EquipmentController = {}

local UnlockRemote: RemoteFunction?
local EquipRemote: RemoteFunction?
local GetStateRemote: RemoteFunction?
local StateChangedRemote: RemoteEvent?

local function ResolveChildOfClass(Parent: Instance?, Name: string, ClassName: string): Instance?
	if not Parent then
		return nil
	end
	local Child = Parent:FindFirstChild(Name) or Parent:WaitForChild(Name, 5)
	if not Child or not Child:IsA(ClassName) then
		return nil
	end
	return Child
end

local function CopyValidState(Value: unknown): EquipmentState?
	if type(Value) ~= "table" then
		return nil
	end
	local Raw = Value :: { [any]: any }
	if
		type(Raw.EquippedUpgradeId) ~= "string"
		or Raw.EquippedUpgradeId == ""
		or #Raw.EquippedUpgradeId > MAX_UPGRADE_ID_LENGTH
		or type(Raw.UnlockedUpgradeIds) ~= "table"
	then
		return nil
	end

	local UnlockedIds = Raw.UnlockedUpgradeIds :: { [any]: any }
	local Copy: { string } = {}
	local Seen: { [string]: boolean } = {}
	local EntryCount = 0
	for Key, Id in UnlockedIds do
		if
			type(Key) ~= "number"
			or Key < 1
			or Key % 1 ~= 0
			or type(Id) ~= "string"
			or Id == ""
			or #Id > MAX_UPGRADE_ID_LENGTH
			or Seen[Id]
		then
			return nil
		end
		Seen[Id] = true
		EntryCount += 1
	end
	if EntryCount ~= #UnlockedIds then
		return nil
	end
	for Index = 1, #UnlockedIds do
		table.insert(Copy, UnlockedIds[Index])
	end

	return {
		EquippedUpgradeId = Raw.EquippedUpgradeId,
		UnlockedUpgradeIds = Copy,
	}
end

local function ApplyState(Value: unknown)
	local NewState = CopyValidState(Value)
	if not NewState then
		return
	end
	LocalState = NewState
	for _, Callback in StateChangedCallbacks do
		task.spawn(Callback, EquipmentController.GetState())
	end
end

function EquipmentController.Init()
	local EventsFolder = ResolveChildOfClass(ReplicatedStorage, "BiggerEvents", "Folder") :: Folder?
	local EquipmentFolder = ResolveChildOfClass(EventsFolder, "Equipment", "Folder") :: Folder?
	if EquipmentFolder then
		UnlockRemote = ResolveChildOfClass(EquipmentFolder, "UnlockUpgrade", "RemoteFunction") :: RemoteFunction?
		EquipRemote = ResolveChildOfClass(EquipmentFolder, "EquipUpgrade", "RemoteFunction") :: RemoteFunction?
		GetStateRemote = ResolveChildOfClass(EquipmentFolder, "GetEquipmentState", "RemoteFunction") :: RemoteFunction?
		StateChangedRemote =
			ResolveChildOfClass(EquipmentFolder, "EquipmentStateChanged", "RemoteEvent") :: RemoteEvent?
	end

	if StateChangedRemote then
		StateChangedRemote.OnClientEvent:Connect(function(NewState: unknown)
			ApplyState(NewState)
		end)
	end
end

function EquipmentController.Start()
	if GetStateRemote then
		task.spawn(function()
			local Success, ServerState = pcall(function()
				return GetStateRemote:InvokeServer()
			end)
			if Success then
				ApplyState(ServerState)
			end
		end)
	end
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

function EquipmentController.RequestUnlock(UpgradeId: string): (boolean, string)
	if not UnlockRemote then
		return false, "RemoteNotReady"
	end
	local Success, Ok, Msg = pcall(function()
		return UnlockRemote:InvokeServer(UpgradeId)
	end)
	if not Success then
		return false, "RemoteException"
	end
	return Ok == true, tostring(Msg)
end

function EquipmentController.RequestEquip(UpgradeId: string): (boolean, string)
	if not EquipRemote then
		return false, "RemoteNotReady"
	end
	local Success, Ok, Msg = pcall(function()
		return EquipRemote:InvokeServer(UpgradeId)
	end)
	if not Success then
		return false, "RemoteException"
	end
	return Ok == true, tostring(Msg)
end

return EquipmentController
