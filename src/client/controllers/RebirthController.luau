--!strict
-- RebirthController.luau
-- Client controller for the Rebirth panel (Pure Renderer).
-- Displays authoritative Server Rebirth state sent via UpdateRebirth remote.
-- Does NOT calculate gameplay values. Only binds gameplay logic to the approved UI freeze layout.

--// Raw Requirings \\--
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Requirings \\--
local UIEventBus = require(script.Parent:WaitForChild("UIEventBus"))

--// Types \\--
type RebirthTierSnapshot = {
	RequiredSize: number,
	GrowthMultiplier: number,
}
type RebirthUpdate = {
	Version: number,
	Timestamp: number,
	CurrentSize: number,
	RequiredSize: number,
	CurrentLevel: number,
	RequiredLevel: number,
	GrowthMultiplier: number,
	NextGrowthMultiplier: number,
	Rebirths: number,
	CanRebirth: boolean,
	PreviewTiers: { RebirthTierSnapshot },
	Error: string,
}

--// Variables \\--
local LocalPlayer = Players.LocalPlayer

local RebirthController = {}

-- GUI References
local ScreenGui: ScreenGui
local OverlayHUD: Frame
local Panel: Frame
local CloseButton: TextButton
local RequirementLabel: TextLabel
local ProgressLabel: TextLabel
local BarFill: Frame
local CurrentStat: TextLabel
local NextStat: TextLabel
local RebirthButton: TextButton
local RebirthButtonText: TextLabel
local SkipRebirthButton: TextButton
local SkipRebirthButtonText: TextLabel

-- Remote References
local RequestRebirthRemote: RemoteEvent
local RequestSkipRebirthRemote: RemoteEvent
local UpdateRebirthRemote: RemoteEvent

-- State
local IsOpen = false
local CachedState: RebirthUpdate?
local PanelRegistry: {
	Connections: { RBXScriptConnection | { Disconnect: () -> () } },
	Tasks: { thread },
	Destroyed: boolean,
}

--// Helpers \\--

local function PanelRegistryDestroy()
	if PanelRegistry.Destroyed then
		return
	end
	PanelRegistry.Destroyed = true

	for _, Connection in PanelRegistry.Connections do
		if typeof(Connection) == "RBXScriptConnection" then
			(Connection :: RBXScriptConnection):Disconnect()
		elseif typeof(Connection) == "table" and typeof(Connection.Disconnect) == "function" then
			Connection.Disconnect()
		end
	end
	table.clear(PanelRegistry.Connections)

	for _, Thread in PanelRegistry.Tasks do
		task.cancel(Thread)
	end
	table.clear(PanelRegistry.Tasks)

	table.clear(PanelRegistry)
end

local function NewPanelRegistry()
	if PanelRegistry and not PanelRegistry.Destroyed then
		PanelRegistryDestroy()
	end
	PanelRegistry = {
		Connections = {},
		Tasks = {},
		Destroyed = false,
	}
end



local function Render(State: RebirthUpdate)
	CachedState = State

	if not Panel then
		return
	end

	-- Requirement label
	if RequirementLabel then
		RequirementLabel.Text = "Reach Level " .. tostring(State.RequiredLevel) .. "\nto Rebirth"
	end

	-- Progress bar text and fill
	if ProgressLabel then
		ProgressLabel.Text = "Lv" .. tostring(State.CurrentLevel) .. " / " .. tostring(State.RequiredLevel)
	end

	if BarFill then
		local ratio = if State.RequiredLevel > 0 then math.clamp(State.CurrentLevel / State.RequiredLevel, 0, 1) else 0
		BarFill.Size = UDim2.fromScale(math.max(ratio, 0.02), 1)
	end

	-- Current multiplier card
	if CurrentStat then
		CurrentStat.Text = tostring(State.GrowthMultiplier) .. "X Strength"
	end

	-- Next multiplier card
	if NextStat then
		NextStat.Text = tostring(State.NextGrowthMultiplier) .. "X Strength"
	end

	-- Rebirth button state driven by server CanRebirth
	if RebirthButton then
		RebirthButton.Active = State.CanRebirth
		if RebirthButtonText then
			RebirthButtonText.Text = "Rebirth"
		end
		local btnImg = RebirthButton:FindFirstChild("BtnImg") :: ImageLabel?
		if btnImg then
			btnImg.ImageColor3 = if State.CanRebirth then Color3.new(1, 1, 1) else Color3.fromRGB(150, 150, 150)
		end
	end

	if SkipRebirthButton then
		SkipRebirthButton.Active = true
		if SkipRebirthButtonText then
			SkipRebirthButtonText.Text = "Skip Rebirth"
		end
	end
end

function RebirthController.Open()
	if not Panel then
		return
	end
	IsOpen = true
	if OverlayHUD then
		OverlayHUD.Visible = true
	end
	Panel.Visible = true

	-- Request fresh update from the server
	pcall(function()
		RequestRebirthRemote:FireServer("Refresh")
	end)

	if CachedState then
		Render(CachedState)
	end
end

function RebirthController.Close()
	if not Panel then
		return
	end
	IsOpen = false
	Panel.Visible = false
	if OverlayHUD then
		local anyOtherOpen = false
		for _, child in ipairs(OverlayHUD:GetChildren()) do
			if child:IsA("GuiObject") and child.Visible then
				anyOtherOpen = true
				break
			end
		end
		if not anyOtherOpen then
			OverlayHUD.Visible = false
		end
	end
end

function RebirthController.Toggle()
	if IsOpen then
		RebirthController.Close()
	else
		RebirthController.Open()
	end
end

--// Initialization \\--
function RebirthController.Init()
	local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
	ScreenGui = PlayerGui:WaitForChild("MainHUD") :: ScreenGui

	-- Remotes (idempotent — reference existing ones)
	local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if not RemotesFolder then
		RemotesFolder = Instance.new("Folder")
		RemotesFolder.Name = "Remotes"
		RemotesFolder.Parent = ReplicatedStorage
	end
	RequestRebirthRemote = RemotesFolder:FindFirstChild("RequestRebirth") :: RemoteEvent
	if not RequestRebirthRemote then
		RequestRebirthRemote = Instance.new("RemoteEvent")
		RequestRebirthRemote.Name = "RequestRebirth"
		RequestRebirthRemote.Parent = RemotesFolder
	end
	RequestSkipRebirthRemote = RemotesFolder:FindFirstChild("RequestSkipRebirth") :: RemoteEvent
	if not RequestSkipRebirthRemote then
		RequestSkipRebirthRemote = Instance.new("RemoteEvent")
		RequestSkipRebirthRemote.Name = "RequestSkipRebirth"
		RequestSkipRebirthRemote.Parent = RemotesFolder
	end
	UpdateRebirthRemote = RemotesFolder:FindFirstChild("UpdateRebirth") :: RemoteEvent
	if not UpdateRebirthRemote then
		UpdateRebirthRemote = Instance.new("RemoteEvent")
		UpdateRebirthRemote.Name = "UpdateRebirth"
		UpdateRebirthRemote.Parent = RemotesFolder
	end

	-- Panel references under OverlayHUD
	local SafeAreaRoot = ScreenGui:WaitForChild("SafeAreaRoot")
	OverlayHUD = SafeAreaRoot:WaitForChild("OverlayHUD") :: Frame
	Panel = OverlayHUD:WaitForChild("RebirthPanel") :: Frame
	Panel.Visible = false

	CloseButton = Panel:FindFirstChild("CloseButton") :: TextButton

	RequirementLabel = Panel:FindFirstChild("RequirementLabel") :: TextLabel

	local MultiplierBar = Panel:FindFirstChild("MultiplierBar") :: Frame
	ProgressLabel = MultiplierBar and MultiplierBar:FindFirstChild("ProgressLabel") :: TextLabel
	local BarBG = MultiplierBar and MultiplierBar:FindFirstChild("BarBG") :: Frame
	BarFill = BarBG and BarBG:FindFirstChild("BarFill") :: Frame

	local CurrentCard = Panel:FindFirstChild("CurrentCard") :: ImageLabel
	CurrentStat = CurrentCard and CurrentCard:FindFirstChild("Stat") :: TextLabel

	local NextCard = Panel:FindFirstChild("NextCard") :: ImageLabel
	NextStat = NextCard and NextCard:FindFirstChild("Stat") :: TextLabel

	RebirthButton = Panel:FindFirstChild("RebirthButton", true) :: TextButton
	RebirthButtonText = RebirthButton and RebirthButton:FindFirstChild("ButtonText") :: TextLabel

	SkipRebirthButton = Panel:FindFirstChild("SkipRebirthButton", true) :: TextButton
	SkipRebirthButtonText = SkipRebirthButton and SkipRebirthButton:FindFirstChild("ButtonText") :: TextLabel
end

function RebirthController.Start()
	-- Listen for server-pushed state updates
	NewPanelRegistry()
	table.insert(
		PanelRegistry.Connections,
		UpdateRebirthRemote.OnClientEvent:Connect(function(State: RebirthUpdate)
			CachedState = State
			if IsOpen then
				Render(State)
			end
		end)
	)

	-- Subscribe to UIEventBus for sidebar button clicks
	local eventConn = UIEventBus.Subscribe("SidebarButtonClicked", function(buttonName: any)
		if buttonName == "Rebirth" then
			RebirthController.Open()
		end
	end)
	table.insert(PanelRegistry.Connections, eventConn)

	-- RebirthButton
	if RebirthButton then
		table.insert(
			PanelRegistry.Connections,
			RebirthButton.Activated:Connect(function()
				if CachedState and CachedState.CanRebirth then
					pcall(function()
						RequestRebirthRemote:FireServer()
					end)
				end
			end)
		)
	end

	-- SkipRebirthButton
	if SkipRebirthButton then
		table.insert(
			PanelRegistry.Connections,
			SkipRebirthButton.Activated:Connect(function()
				pcall(function()
					RequestSkipRebirthRemote:FireServer()
				end)
			end)
		)
	end

	-- CloseButton
	if CloseButton then
		table.insert(
			PanelRegistry.Connections,
			CloseButton.Activated:Connect(function()
				RebirthController.Close()
			end)
		)
	end

	-- Initial render if we already have state
	if CachedState and IsOpen then
		Render(CachedState)
	end
	-- Request fresh update from the server
	pcall(function()
		RequestRebirthRemote:FireServer("Refresh")
	end)


end

return RebirthController
