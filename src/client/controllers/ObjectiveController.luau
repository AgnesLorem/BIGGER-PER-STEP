--!strict
--// Raw Requirings \\--

local Players = game:GetService("Players")

--// Variables \\--

local LocalPlayer = Players.LocalPlayer
local Gui: ScreenGui? = nil
local Frame: Frame? = nil
local TextLabel: TextLabel? = nil
local RewardLabel: TextLabel? = nil

--// Helpers \\--

local function CreateGui()
	if Gui then
		return
	end

	local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")

	Gui = Instance.new("ScreenGui")
	Gui.Name = "ObjectiveGui"
	Gui.ResetOnSpawn = false
	Gui.Enabled = false
	Gui.Parent = PlayerGui

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
end

local function Update()
	CreateGui()
	if not Gui or not TextLabel or not RewardLabel then
		return
	end

	local ObjectiveActive = LocalPlayer:GetAttribute("ObjectiveActive") == true
	Gui.Enabled = ObjectiveActive
	TextLabel.Text = LocalPlayer:GetAttribute("ObjectiveText") or ""
	RewardLabel.Text = LocalPlayer:GetAttribute("ObjectiveReward") or ""
end

--// Service \\--

local ObjectiveController = {}

function ObjectiveController.Init() end

function ObjectiveController.Start()
	CreateGui()
	LocalPlayer:GetAttributeChangedSignal("ObjectiveActive"):Connect(Update)
	LocalPlayer:GetAttributeChangedSignal("ObjectiveText"):Connect(Update)
	LocalPlayer:GetAttributeChangedSignal("ObjectiveReward"):Connect(Update)
	Update()
end

return ObjectiveController
