--!strict
-- VIPDoorController.luau
-- Client controller managing local VIP door barrier collision based on VIP ownership.

--// Raw Requirings \\--
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

--// Variables \\--
local LocalPlayer = Players.LocalPlayer

local Initialized = false
local Started = false
local Connections: { RBXScriptConnection | { Disconnect: () -> () } } = {}

--// Helpers \\--
local function IsVipOwned(): boolean
	if not LocalPlayer then
		return false
	end

	if LocalPlayer:GetAttribute("VipOwned") == true or LocalPlayer:GetAttribute("HasVip") == true then
		return true
	end

	return false
end

local function IsTriggerPart(Part: BasePart): boolean
	local LowerName = Part.Name:lower()
	return LowerName == "trigger" or LowerName:find("trigger") ~= nil
end

local function UpdateDoorCollision(DoorInstance: Instance)
	local Owned = IsVipOwned()
	local TargetCanCollide = not Owned

	if DoorInstance:IsA("BasePart") then
		local BasePart = DoorInstance :: BasePart
		if not IsTriggerPart(BasePart) then
			BasePart.CanCollide = TargetCanCollide
		end
		return
	end

	if DoorInstance.GetDescendants then
		for _, Descendant in DoorInstance:GetDescendants() do
			if Descendant:IsA("BasePart") then
				local Part = Descendant :: BasePart
				if not IsTriggerPart(Part) then
					Part.CanCollide = TargetCanCollide
				else
					Part.CanCollide = false
				end
			end
		end
	end
end

local function UpdateAllDoors()
	local DirectDoor = Workspace:FindFirstChild("VIPDoor")
	if DirectDoor then
		UpdateDoorCollision(DirectDoor)
	end

	local VIPRoom = Workspace:FindFirstChild("VIPRoom")
	if VIPRoom then
		local RoomDoor = VIPRoom:FindFirstChild("VIPDoor")
		if RoomDoor then
			UpdateDoorCollision(RoomDoor)
		end
	end

	if Workspace.GetDescendants then
		for _, Descendant in Workspace:GetDescendants() do
			if Descendant.Name == "VIPDoor" then
				UpdateDoorCollision(Descendant)
			end
		end
	end
end

--// Controller \\--
local VIPDoorController = {}

function VIPDoorController.Init()
	if Initialized then
		return
	end
	Initialized = true

	LocalPlayer = Players.LocalPlayer
end

function VIPDoorController.Start()
	if Started then
		return
	end
	VIPDoorController.Init()
	Started = true

	if LocalPlayer then
		if LocalPlayer.GetAttributeChangedSignal then
			local HasVipSignal = LocalPlayer:GetAttributeChangedSignal("HasVip")
			if HasVipSignal then
				table.insert(
					Connections,
					HasVipSignal:Connect(function()
						UpdateAllDoors()
					end)
				)
			end

			local VipOwnedSignal = LocalPlayer:GetAttributeChangedSignal("VipOwned")
			if VipOwnedSignal then
				table.insert(
					Connections,
					VipOwnedSignal:Connect(function()
						UpdateAllDoors()
					end)
				)
			end
		end
	end

	if Workspace.DescendantAdded then
		local Conn = Workspace.DescendantAdded:Connect(function(Descendant: Instance)
			if Descendant.Name == "VIPDoor" then
				UpdateDoorCollision(Descendant)
			end
		end)
		table.insert(Connections, Conn)
	end

	UpdateAllDoors()
end

function VIPDoorController.IsVipOwned(): boolean
	return IsVipOwned()
end

function VIPDoorController.UpdateDoors()
	UpdateAllDoors()
end

function VIPDoorController.Destroy()
	for _, Conn in Connections do
		if type(Conn) == "table" and Conn.Disconnect then
			Conn.Disconnect()
		end
	end
	table.clear(Connections)
	Initialized = false
	Started = false
end

return VIPDoorController
