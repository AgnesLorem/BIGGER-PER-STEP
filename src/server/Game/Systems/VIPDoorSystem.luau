--!strict
-- VIPDoorSystem.luau
-- Server system managing VIP Door triggers, ownership checks, and purchase prompts.

--// Raw Requirings \\--
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

--// Requirings \\--
local ServiceRegistry = require(script.Parent.Parent.Parent.Core.Registry.ServiceRegistry)
local Logger = require(script.Parent.Parent.Parent.Core.Utilities.Logger)

--// Constants \\--
local DEBOUNCE_SECONDS = 2.5

--// Variables \\--
local Initialized = false
local Started = false
local Debounces: { [Player]: number } = {}
local BoundTriggers: { [Instance]: boolean } = {}
local BoundDoors: { [Instance]: boolean } = {}
local Connections: { RBXScriptConnection | { Disconnect: () -> () } } = {}

--// Helpers \\--
local function FindTriggerPart(DoorInstance: Instance): BasePart?
	if DoorInstance:IsA("BasePart") then
		if DoorInstance.Name == "Trigger" then
			return DoorInstance :: BasePart
		end
	end

	local TriggerChild = DoorInstance:FindFirstChild("Trigger", true)
		or DoorInstance:FindFirstChild("Trigger")
		or DoorInstance:FindFirstChild("DoorTrigger", true)
		or DoorInstance:FindFirstChild("VIPDoorTrigger", true)
		or DoorInstance:FindFirstChild("PromptTrigger", true)

	if TriggerChild and TriggerChild:IsA("BasePart") then
		return TriggerChild :: BasePart
	end

	if DoorInstance:IsA("BasePart") then
		return DoorInstance :: BasePart
	end

	return nil
end

local function BindTrigger(TriggerPart: BasePart)
	if BoundTriggers[TriggerPart] then
		return
	end
	BoundTriggers[TriggerPart] = true

	local TouchConn = TriggerPart.Touched:Connect(function(HitPart: any)
		if not HitPart or not HitPart.Parent then
			return
		end

		local Character = HitPart.Parent
		local Player = Players:GetPlayerFromCharacter(Character)
		if not Player and Character.Parent then
			Player = Players:GetPlayerFromCharacter(Character.Parent)
		end
		if not Player then
			return
		end

		local Success, GamePassService = pcall(function()
			return ServiceRegistry.Get("GamePassService")
		end)
		if not Success or not GamePassService then
			return
		end

		if GamePassService:IsOwned(Player, "Vip") then
			return
		end

		local Now = os.clock()
		local LastPrompt = Debounces[Player]
		if LastPrompt and Now - LastPrompt < DEBOUNCE_SECONDS then
			return
		end

		Debounces[Player] = Now
		GamePassService:Prompt(Player, "Vip")
	end)

	table.insert(Connections, TouchConn)
end

local function BindDoor(DoorInstance: Instance)
	if BoundDoors[DoorInstance] then
		return
	end
	BoundDoors[DoorInstance] = true

	local Trigger = FindTriggerPart(DoorInstance)
	if Trigger then
		BindTrigger(Trigger)
	end
end

local function FindAndBindDoors()
	local DirectDoor = Workspace:FindFirstChild("VIPDoor")
	if DirectDoor then
		BindDoor(DirectDoor)
	end

	local VIPRoom = Workspace:FindFirstChild("VIPRoom")
	if VIPRoom then
		local RoomDoor = VIPRoom:FindFirstChild("VIPDoor")
		if RoomDoor then
			BindDoor(RoomDoor)
		end
	end

	if Workspace.GetDescendants then
		for _, Descendant in Workspace:GetDescendants() do
			if Descendant.Name == "VIPDoor" then
				BindDoor(Descendant)
			end
		end
	end
end

--// Service \\--
local VIPDoorSystem = {}

function VIPDoorSystem.Init()
	if Initialized then
		return
	end
	Initialized = true

	if Workspace.DescendantAdded then
		local Conn = Workspace.DescendantAdded:Connect(function(Descendant: Instance)
			if Descendant.Name == "VIPDoor" then
				BindDoor(Descendant)
			elseif Descendant.Name == "Trigger" and Descendant.Parent and Descendant.Parent.Name == "VIPDoor" then
				BindDoor(Descendant.Parent)
			end
		end)
		table.insert(Connections, Conn)
	end

	if Players.PlayerRemoving then
		local Conn = Players.PlayerRemoving:Connect(function(Player: Player)
			Debounces[Player] = nil
		end)
		table.insert(Connections, Conn)
	end

	FindAndBindDoors()
	Logger.Info("Runtime", "VIPDoorSystem initialized")
end

function VIPDoorSystem.Start()
	if Started then
		return
	end
	Started = true
	FindAndBindDoors()
	Logger.Info("Runtime", "VIPDoorSystem started")
end

function VIPDoorSystem.Destroy()
	for _, Conn in Connections do
		if type(Conn) == "table" and Conn.Disconnect then
			Conn.Disconnect()
		end
	end
	table.clear(Connections)
	table.clear(Debounces)
	table.clear(BoundTriggers)
	table.clear(BoundDoors)
	Initialized = false
	Started = false
end

return VIPDoorSystem
