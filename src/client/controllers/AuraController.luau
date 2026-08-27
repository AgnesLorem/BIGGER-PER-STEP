--!strict
-- src/client/controllers/AuraController.luau
-- Client controller managing Aura progression and cosmetic state.

local ReplicatedStorage = game:GetService("ReplicatedStorage")

export type AuraState = {
	UnlockedAuras: { [string]: boolean },
	EquippedAura: string,
	AuraVFXEnabled: boolean,
	HighestMultiplier: number,
}

local LocalState: AuraState = {
	UnlockedAuras = {},
	EquippedAura = "None",
	AuraVFXEnabled = true,
	HighestMultiplier = 1.0,
}

local StateChangedCallbacks: { (AuraState) -> () } = {}
local AuraController = {}

local RequestRemote: RemoteEvent?
local ResponseRemote: RemoteEvent?
local StateChangedRemote: RemoteEvent?
local ResponseConnection: RBXScriptConnection?
local StateConnection: RBXScriptConnection?
local Initialized = false
local Started = false

local function NotifyStateChanged()
	local Snapshot = AuraController.GetState()
	for _, Callback in StateChangedCallbacks do
		task.spawn(Callback, Snapshot)
	end
end

local function ApplyState(Value: unknown)
	if type(Value) ~= "table" then
		return
	end
	local State = Value :: any

	if State.UnlockedAuras ~= nil then
		LocalState.UnlockedAuras = State.UnlockedAuras
	end
	if State.EquippedAura ~= nil then
		LocalState.EquippedAura = State.EquippedAura
	end
	if State.AuraVFXEnabled ~= nil then
		LocalState.AuraVFXEnabled = State.AuraVFXEnabled
	end
	if State.HighestMultiplier ~= nil then
		LocalState.HighestMultiplier = State.HighestMultiplier
	end

	NotifyStateChanged()
end

local function OnResponse(Value: unknown)
	if type(Value) ~= "table" then
		return
	end
	local Response = Value :: any
	if Response.Action == "GetState" then
		ApplyState(Response)
	end
end

function AuraController.Init()
	if Initialized then
		return
	end

	local EventsFolder = ReplicatedStorage:WaitForChild("BiggerEvents", 5) :: Folder?
	if EventsFolder then
		local AuraFolder = EventsFolder:WaitForChild("Aura", 5) :: Folder?
		if AuraFolder then
			local Request = AuraFolder:WaitForChild("Request", 5)
			local Response = AuraFolder:WaitForChild("Response", 5)
			local StateChanged = AuraFolder:WaitForChild("StateChanged", 5)
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

function AuraController.Start()
	if Started then
		return
	end
	Started = true
	AuraController.RequestState()
end

function AuraController.GetState(): AuraState
	local UnlockedAurasCopy = table.clone(LocalState.UnlockedAuras)

	return {
		UnlockedAuras = UnlockedAurasCopy,
		EquippedAura = LocalState.EquippedAura,
		AuraVFXEnabled = LocalState.AuraVFXEnabled,
		HighestMultiplier = LocalState.HighestMultiplier,
	}
end

function AuraController.OnStateChanged(Callback: (AuraState) -> ()): () -> ()
	table.insert(StateChangedCallbacks, Callback)
	Callback(AuraController.GetState())

	return function()
		local Index = table.find(StateChangedCallbacks, Callback)
		if Index then
			table.remove(StateChangedCallbacks, Index)
		end
	end
end

function AuraController.RequestState()
	if RequestRemote then
		RequestRemote:FireServer("GetState")
	end
end

function AuraController.RequestEquip(AuraId: string)
	if RequestRemote then
		RequestRemote:FireServer("Equip", AuraId)
	end
end

function AuraController.RequestToggleVFX(Enabled: boolean)
	if RequestRemote then
		RequestRemote:FireServer("ToggleVFX", Enabled)
	end
end

function AuraController.Destroy()
	if ResponseConnection then
		ResponseConnection:Disconnect()
		ResponseConnection = nil
	end
	if StateConnection then
		StateConnection:Disconnect()
		StateConnection = nil
	end
	table.clear(StateChangedCallbacks)
	Initialized = false
	Started = false
end

return AuraController
