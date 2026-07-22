--!strict
--// Raw Requirings \\--

local Players = game:GetService("Players")

--// Variables \\--

local LocalPlayer = Players.LocalPlayer
local Gui: ScreenGui? = nil
local Frame: Frame? = nil
local TextLabel: TextLabel? = nil
local RewardLabel: TextLabel? = nil
local CurrentPlayerGui: PlayerGui? = nil
local Connections: { RBXScriptConnection } = {}
local Status: "Ready" | "PlayerGuiUnavailable" = "PlayerGuiUnavailable"
local WarningEmitted = false
local Initialized = false
local Started = false
local PopupGeneration = 0

--// Helpers \\--

local function CreateGui()
	if Gui then
		return
	end
	if not CurrentPlayerGui then
		Status = "PlayerGuiUnavailable"
		if not WarningEmitted then
			WarningEmitted = true
			warn("[ObjectiveController] PlayerGui is unavailable; objective presentation is disabled.")
		end
		return
	end

	Gui = Instance.new("ScreenGui")
	Gui.Name = "ObjectiveGui"
	Gui.ResetOnSpawn = false
	Gui.Enabled = false
	Gui.Parent = CurrentPlayerGui

	Frame = Instance.new("Frame")
	Frame.Name = "ObjectiveFrame"
	Frame.AnchorPoint = Vector2.new(1, 1)
	Frame.Position = UDim2.fromScale(0.98, 0.92)
	Frame.Size = UDim2.fromOffset(260, 86)
	Frame.BackgroundColor3 = Color3.fromRGB(18, 22, 28)
	Frame.BackgroundTransparency = 0.08
	Frame.BorderSizePixel = 0
	Frame.Parent = Gui

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 8)
	Corner.Parent = Frame

	TextLabel = Instance.new("TextLabel")
	TextLabel.Name = "ObjectiveText"
	TextLabel.Position = UDim2.fromOffset(14, 10)
	TextLabel.Size = UDim2.new(1, -28, 0, 42)
	TextLabel.BackgroundTransparency = 1
	TextLabel.Font = Enum.Font.GothamBold
	TextLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	TextLabel.TextSize = 17
	TextLabel.TextWrapped = true
	TextLabel.TextXAlignment = Enum.TextXAlignment.Left
	TextLabel.TextYAlignment = Enum.TextYAlignment.Top
	TextLabel.Parent = Frame

	RewardLabel = Instance.new("TextLabel")
	RewardLabel.Name = "ObjectiveReward"
	RewardLabel.Position = UDim2.fromOffset(14, 56)
	RewardLabel.Size = UDim2.new(1, -28, 0, 20)
	RewardLabel.BackgroundTransparency = 1
	RewardLabel.Font = Enum.Font.Gotham
	RewardLabel.TextColor3 = Color3.fromRGB(105, 220, 130)
	RewardLabel.TextSize = 14
	RewardLabel.TextXAlignment = Enum.TextXAlignment.Left
	RewardLabel.Parent = Frame
	Status = "Ready"
end

local function UpdateText()
	CreateGui()
	if not Gui or not TextLabel or not RewardLabel then
		return
	end

	TextLabel.Text = LocalPlayer:GetAttribute("ObjectiveText") or ""
	RewardLabel.Text = LocalPlayer:GetAttribute("ObjectiveReward") or ""
end

local function UpdateActive()
	CreateGui()
	if not Gui then
		return
	end

	PopupGeneration += 1
	local Generation = PopupGeneration
	local Active = LocalPlayer:GetAttribute("ObjectiveActive") == true
	Gui.Enabled = Active
	if Active then
		task.delay(3, function()
			if Gui and PopupGeneration == Generation then
				Gui.Enabled = false
			end
		end)
	end
end

--// Service \\--

local ObjectiveController = {}

local function DetachPlayerGui()
	CurrentPlayerGui = nil
	Gui = nil
	Frame = nil
	TextLabel = nil
	RewardLabel = nil
	PopupGeneration += 1
	Status = "PlayerGuiUnavailable"
end

local function AttachPlayerGui(PlayerGuiInstance: Instance)
	if CurrentPlayerGui == PlayerGuiInstance then
		return
	end
	DetachPlayerGui()
	CurrentPlayerGui = PlayerGuiInstance :: PlayerGui
	CreateGui()
	if Started then
		UpdateText()
		UpdateActive()
	end
end

function ObjectiveController.Init()
	if Initialized then
		return
	end
	Initialized = true
	table.insert(
		Connections,
		LocalPlayer.ChildAdded:Connect(function(Child)
			if Child.Name == "PlayerGui" then
				AttachPlayerGui(Child)
			end
		end)
	)
	table.insert(
		Connections,
		LocalPlayer.ChildRemoved:Connect(function(Child)
			if Child == CurrentPlayerGui then
				DetachPlayerGui()
			end
		end)
	)

	local PlayerGuiInstance = LocalPlayer:FindFirstChild("PlayerGui")
	if not PlayerGuiInstance then
		PlayerGuiInstance = LocalPlayer:WaitForChild("PlayerGui", 5)
	end
	if PlayerGuiInstance then
		AttachPlayerGui(PlayerGuiInstance)
	else
		CreateGui()
	end
end

function ObjectiveController.Start()
	if Started then
		return
	end
	ObjectiveController.Init()
	Started = true

	CreateGui()
	table.insert(Connections, LocalPlayer:GetAttributeChangedSignal("ObjectiveActive"):Connect(UpdateActive))
	table.insert(Connections, LocalPlayer:GetAttributeChangedSignal("ObjectiveText"):Connect(UpdateText))
	table.insert(Connections, LocalPlayer:GetAttributeChangedSignal("ObjectiveReward"):Connect(UpdateText))
	UpdateText()
	UpdateActive()
end

function ObjectiveController.GetStatus(): "Ready" | "PlayerGuiUnavailable"
	return Status
end

function ObjectiveController.Destroy()
	for _, Connection in Connections do
		Connection:Disconnect()
	end
	table.clear(Connections)
	DetachPlayerGui()
	Initialized = false
	Started = false
	WarningEmitted = false
end

return ObjectiveController
