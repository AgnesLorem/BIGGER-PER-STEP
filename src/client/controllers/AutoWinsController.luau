--!strict
-- AutoWinsController.luau
-- Client controller managing the AutoWins UI toggle and network synchronization.

--// Raw Requirings \\--
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Requirings \\--
local UIEventBus = require(script.Parent:WaitForChild("UIEventBus"))

--// Variables \\--
local LocalPlayer = Players.LocalPlayer
local ToggleAutoWinsRemote: RemoteEvent? = nil

local Initialized = false
local Started = false
local ToggleButton: GuiButton? = nil
local Connections: { RBXScriptConnection | { Disconnect: () -> () } } = {}

--// Helpers \\--
local function EnsureRemote(Name: string): RemoteEvent?
	local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if not RemotesFolder then
		return nil
	end

	local Remote = RemotesFolder:FindFirstChild(Name)
	if Remote and (not Remote.IsA or Remote:IsA("RemoteEvent")) then
		return Remote :: RemoteEvent
	end
	return nil
end

local function UpdateButtonVisual(Active: boolean)
	if not ToggleButton then
		return
	end
	local TextLabel = ToggleButton:FindFirstChild("TextLabel", true)
	if not TextLabel and ToggleButton.FindFirstChildWhichIsA then
		TextLabel = ToggleButton:FindFirstChildWhichIsA("TextLabel")
	end
	if
		TextLabel
		and ((TextLabel.IsA and TextLabel:IsA("TextLabel")) or (type(TextLabel) == "table" and TextLabel.Text ~= nil))
	then
		TextLabel.Text = if Active then "AUTO: ON" else "AUTO: OFF"
	end
end

--// Controller \\--
local AutoWinsController = {}

function AutoWinsController.Init()
	if Initialized then
		return
	end
	Initialized = true

	local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if RemotesFolder then
		ToggleAutoWinsRemote = EnsureRemote("ToggleAutoWins")
	end

	local PlayerGui = LocalPlayer and LocalPlayer:FindFirstChild("PlayerGui")
	if PlayerGui then
		local ScreenGui = PlayerGui:FindFirstChild("MainHUD") :: ScreenGui?
		if ScreenGui then
			local SafeAreaRoot = ScreenGui:FindFirstChild("SafeAreaRoot")
			if SafeAreaRoot then
				local PersistentHUD = SafeAreaRoot:FindFirstChild("PersistentHUD")
				if PersistentHUD then
					local LeftSidebar = PersistentHUD:FindFirstChild("LeftSidebar")
					if LeftSidebar then
						ToggleButton = LeftSidebar:FindFirstChild("AutoWins", true) :: GuiButton?
					end
					if not ToggleButton then
						local RightSidebar = PersistentHUD:FindFirstChild("RightSidebar")
						if RightSidebar then
							ToggleButton = RightSidebar:FindFirstChild("AutoWins", true) :: GuiButton?
						end
					end
				end
			end
		end
	end
end

function AutoWinsController.Start()
	if Started then
		return
	end
	AutoWinsController.Init()
	Started = true

	if not ToggleAutoWinsRemote then
		local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes", 5)
		if RemotesFolder then
			ToggleAutoWinsRemote = RemotesFolder:WaitForChild("ToggleAutoWins", 5) :: RemoteEvent?
		end
	end

	if LocalPlayer then
		table.insert(
			Connections,
			LocalPlayer:GetAttributeChangedSignal("AutoWinsActive"):Connect(function()
				local Active = AutoWinsController.IsActive()
				UpdateButtonVisual(Active)
				UIEventBus.Publish("AutoWinsStateChanged", Active)
			end)
		)
		UpdateButtonVisual(AutoWinsController.IsActive())
	end

	-- Subscribe to UIEventBus for toggle events
	local busToggleConn = UIEventBus.Subscribe("ToggleAutoWins", function(targetState: any)
		if type(targetState) == "boolean" then
			AutoWinsController.Toggle(targetState)
		else
			AutoWinsController.Toggle()
		end
	end)
	table.insert(Connections, busToggleConn)

	local busSidebarConn = UIEventBus.Subscribe("SidebarButtonClicked", function(buttonName: any)
		if buttonName == "AutoWins" or buttonName == "AutoWin" or buttonName == "Auto" then
			AutoWinsController.Toggle()
		end
	end)
	table.insert(Connections, busSidebarConn)

	if ToggleButton then
		local clickConn = ToggleButton.Activated:Connect(function()
			AutoWinsController.Toggle()
		end)
		table.insert(Connections, clickConn)
	end
end

function AutoWinsController.Toggle(TargetState: boolean?)
	local CurrentActive = AutoWinsController.IsActive()
	local DesiredState = if type(TargetState) == "boolean" then TargetState else not CurrentActive

	if not ToggleAutoWinsRemote then
		ToggleAutoWinsRemote = EnsureRemote("ToggleAutoWins")
	end

	if ToggleAutoWinsRemote then
		pcall(function()
			ToggleAutoWinsRemote:FireServer(DesiredState)
		end)
	end
end

function AutoWinsController.IsActive(): boolean
	if not LocalPlayer then
		return false
	end
	return LocalPlayer:GetAttribute("AutoWinsActive") == true
end

function AutoWinsController.Destroy()
	for _, Connection in Connections do
		if typeof(Connection) == "RBXScriptConnection" then
			(Connection :: RBXScriptConnection):Disconnect()
		elseif typeof(Connection) == "table" and typeof(Connection.Disconnect) == "function" then
			Connection.Disconnect()
		end
	end
	table.clear(Connections)

	Initialized = false
	Started = false
	ToggleAutoWinsRemote = nil
	ToggleButton = nil
end

return AutoWinsController
