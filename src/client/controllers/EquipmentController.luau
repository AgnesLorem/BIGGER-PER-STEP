--!strict
-- src/client/controllers/EquipmentController.luau
-- Client controller managing Growth Upgrades equipment state and RPC calls.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

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

function EquipmentController.Init()
	local EventsFolder = ReplicatedStorage:WaitForChild("BiggerEvents", 5) :: Folder?
	if EventsFolder then
		local EquipmentFolder = EventsFolder:WaitForChild("Equipment", 5) :: Folder?
		if EquipmentFolder then
			UnlockRemote = EquipmentFolder:WaitForChild("UnlockUpgrade", 5) :: RemoteFunction?
			EquipRemote = EquipmentFolder:WaitForChild("EquipUpgrade", 5) :: RemoteFunction?
			GetStateRemote = EquipmentFolder:WaitForChild("GetEquipmentState", 5) :: RemoteFunction?
			StateChangedRemote = EquipmentFolder:WaitForChild("EquipmentStateChanged", 5) :: RemoteEvent?
		end
	end

	if StateChangedRemote then
		StateChangedRemote.OnClientEvent:Connect(function(NewState: unknown)
			if type(NewState) == "table" then
				local TypedState = NewState :: EquipmentState
				LocalState = {
					EquippedUpgradeId = TypedState.EquippedUpgradeId or "None",
					UnlockedUpgradeIds = TypedState.UnlockedUpgradeIds or {},
				}
				for _, Callback in StateChangedCallbacks do
					task.spawn(Callback, LocalState)
				end
			end
		end)
	end
end

function EquipmentController.Start()
	if GetStateRemote then
		task.spawn(function()
			local Success, ServerState = pcall(function()
				return GetStateRemote:InvokeServer()
			end)
			if Success and type(ServerState) == "table" then
				local TypedState = ServerState :: EquipmentState
				LocalState = {
					EquippedUpgradeId = TypedState.EquippedUpgradeId or "None",
					UnlockedUpgradeIds = TypedState.UnlockedUpgradeIds or {},
				}
				for _, Callback in StateChangedCallbacks do
					task.spawn(Callback, LocalState)
				end
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
