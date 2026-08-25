--!strict
-- GuiController.luau
-- References and manages the main HUD, responsiveness, and shop purchases.

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local LocalPlayer = Players.LocalPlayer
local FormatNumber = require(
	ReplicatedStorage:WaitForChild("BiggerShared")
		:WaitForChild("Core")
		:WaitForChild("Utilities")
		:WaitForChild("FormatNumber")
)
local ShopUIConfig = require(
	ReplicatedStorage:WaitForChild("BiggerShared")
		:WaitForChild("Core")
		:WaitForChild("Config")
		:WaitForChild("ShopUIConfig")
)
local LevelFormula = require(
	ReplicatedStorage:WaitForChild("BiggerShared")
		:WaitForChild("Game")
		:WaitForChild("Progression")
		:WaitForChild("LevelFormula")
)

local GuiController = {}

--// Referencing \\--
local ScreenGui: ScreenGui? = nil
local LevelLabel: TextLabel? = nil
local ProgressFill: ImageLabel? = nil
local ProgressTextLabel: TextLabel? = nil
local CurrentPlayerGui: PlayerGui? = nil
local HUDConnections: { RBXScriptConnection } = {}
local PlayerGuiConnections: { RBXScriptConnection } = {}
local ControllerConnections: { RBXScriptConnection } = {}
local Status: "Ready" | "HUDUnavailable" = "HUDUnavailable"
local HUDWarningEmitted = false
local Initialized = false
local Started = false

--// Helpers \\--
local function UpdateHUD()
	if not LevelLabel or not ProgressFill or not ProgressTextLabel then
		return
	end
	local biggerAttribute = LocalPlayer:GetAttribute("Bigger")
	local bigger = if type(biggerAttribute) == "number" and biggerAttribute >= 0 then biggerAttribute else 0
	local levelAttribute = LocalPlayer:GetAttribute("Level")
	local _level = if type(levelAttribute) == "number" then levelAttribute else 1
	local multiplier = LocalPlayer:GetAttribute("Multiplier") or 1
	local progress = LevelFormula.GetProgress(bigger)

	LevelLabel.Text = FormatNumber(bigger) .. " BIGGER"
	local ratio = progress.Progress

	-- Hide progress fill if player has no size points yet (starting state)
	if bigger <= 1 then
		ProgressFill.Visible = false
		ProgressFill.Size = UDim2.new(0, 0, 1, 0)
	else
		ProgressFill.Visible = true
		-- Animate progress fill size inside the BarContainer
		TweenService:Create(ProgressFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.new(ratio, 0, 1, 0),
		}):Play()
	end

	ProgressTextLabel.Text = tostring(multiplier) .. "X Multiplier"
end

local function TrackHUDConnection(Connection: RBXScriptConnection)
	table.insert(HUDConnections, Connection)
end

-- Hook up hover scaling animations to a button
local function ApplyHoverAnimation(button: ImageButton)
	local uiScale = button:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Parent = button
	end

	TrackHUDConnection(button.MouseEnter:Connect(function()
		TweenService:Create(uiScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 1.1,
		}):Play()
	end))

	TrackHUDConnection(button.MouseLeave:Connect(function()
		TweenService:Create(uiScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 1.0,
		}):Play()
	end))

	TrackHUDConnection(button.MouseButton1Down:Connect(function()
		TweenService:Create(uiScale, TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 0.95,
		}):Play()
	end))

	TrackHUDConnection(button.MouseButton1Up:Connect(function()
		TweenService:Create(uiScale, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 1.1,
		}):Play()
	end))
end

local function DisconnectConnections(Connections: { RBXScriptConnection })
	for _, Connection in Connections do
		Connection:Disconnect()
	end
	table.clear(Connections)
end

local function SetHUDUnavailable()
	Status = "HUDUnavailable"
	if HUDWarningEmitted then
		return
	end
	HUDWarningEmitted = true
	warn("[GuiController] PlayerGui.MainHUD is unavailable; HUD presentation is disabled.")
end

local function ClearHUD()
	DisconnectConnections(HUDConnections)
	ScreenGui = nil
	LevelLabel = nil
	ProgressFill = nil
	ProgressTextLabel = nil
	Status = "HUDUnavailable"
end

local function BindHUD(Candidate: Instance?): boolean
	ClearHUD()
	if not Candidate then
		SetHUDUnavailable()
		return false
	end

	local SafeAreaRoot = Candidate:FindFirstChild("SafeAreaRoot")
	local PersistentHUD = SafeAreaRoot and SafeAreaRoot:FindFirstChild("PersistentHUD")
	local LeftSidebar = PersistentHUD and PersistentHUD:FindFirstChild("LeftSidebar")
	local BottomHUD = PersistentHUD and PersistentHUD:FindFirstChild("BottomHUD")
	local ProgressBarFrame = BottomHUD and BottomHUD:FindFirstChild("ProgressBarFrame")
	local ProgressBG = ProgressBarFrame and ProgressBarFrame:FindFirstChild("ProgressBG")
	local BarContainer = ProgressBG and ProgressBG:FindFirstChild("BarContainer")
	local ButtonsContainer = BottomHUD and BottomHUD:FindFirstChild("ButtonsContainer")
	local FoundLevelLabel = ProgressBG and ProgressBG:FindFirstChild("LevelLabel")
	local FoundProgressFill = BarContainer and BarContainer:FindFirstChild("ProgressFill")
	local FoundProgressTextLabel = ProgressBG and ProgressBG:FindFirstChild("ProgressTextLabel")
	if
		not LeftSidebar
		or not BottomHUD
		or not ButtonsContainer
		or not FoundLevelLabel
		or not FoundProgressFill
		or not FoundProgressTextLabel
	then
		SetHUDUnavailable()
		return false
	end

	ScreenGui = Candidate :: ScreenGui
	LevelLabel = FoundLevelLabel :: TextLabel
	ProgressFill = FoundProgressFill :: ImageLabel
	ProgressTextLabel = FoundProgressTextLabel :: TextLabel

	for _, Child in LeftSidebar:GetChildren() do
		if Child:IsA("ImageButton") then
			ApplyHoverAnimation(Child)
			TrackHUDConnection(Child.MouseButton1Click:Connect(function()
				if Child.Name == "Rebirth" then
					local EventsFolder = ReplicatedStorage:FindFirstChild("BiggerEvents")
					local RebirthFolder = EventsFolder and EventsFolder:FindFirstChild("Rebirth")
					local RequestRemote = RebirthFolder and RebirthFolder:FindFirstChild("Request")
					if RequestRemote and RequestRemote:IsA("RemoteEvent") then
						RequestRemote:FireServer()
					end
				else
					print(Child.Name .. " button clicked (stub)")
				end
			end))
		end
	end

	for _, Child in ButtonsContainer:GetChildren() do
		if Child:IsA("ImageButton") then
			ApplyHoverAnimation(Child)
			local Config = ShopUIConfig[Child.Name]
			if Config then
				TrackHUDConnection(Child.MouseButton1Click:Connect(function()
					MarketplaceService:PromptProductPurchase(LocalPlayer, Config.ProductId)
				end))
			end
		end
	end

	local RightSidebar = PersistentHUD and PersistentHUD:FindFirstChild("RightSidebar")
	if RightSidebar then
		for _, Child in RightSidebar:GetChildren() do
			if Child:IsA("ImageButton") then
				ApplyHoverAnimation(Child)
				local Config = ShopUIConfig[Child.Name]
				if Config then
					TrackHUDConnection(Child.MouseButton1Click:Connect(function()
						MarketplaceService:PromptProductPurchase(LocalPlayer, Config.ProductId)
					end))
				end
			end
		end
		local VipButton = RightSidebar:FindFirstChild("Vip")
		if VipButton and VipButton:IsA("ImageButton") then
			TrackHUDConnection(VipButton.MouseButton1Click:Connect(function()
				local AssetId = LocalPlayer:GetAttribute("VipGamePassAssetId")
				if type(AssetId) == "number" and AssetId > 0 and AssetId % 1 == 0 then
					MarketplaceService:PromptGamePassPurchase(LocalPlayer, AssetId)
				end
			end))
		end
	end

	Status = "Ready"
	if Started then
		UpdateHUD()
	end
	return true
end

local function DetachPlayerGui()
	DisconnectConnections(PlayerGuiConnections)
	CurrentPlayerGui = nil
	ClearHUD()
end

local function AttachPlayerGui(PlayerGuiInstance: Instance)
	if CurrentPlayerGui == PlayerGuiInstance then
		return
	end
	DetachPlayerGui()
	CurrentPlayerGui = PlayerGuiInstance :: PlayerGui
	table.insert(
		PlayerGuiConnections,
		PlayerGuiInstance.ChildAdded:Connect(function(Child)
			if Child.Name == "MainHUD" then
				BindHUD(Child)
			end
		end)
	)
	table.insert(
		PlayerGuiConnections,
		PlayerGuiInstance.ChildRemoved:Connect(function(Child)
			if Child == ScreenGui then
				ClearHUD()
			end
		end)
	)

	local MainHUD = PlayerGuiInstance:FindFirstChild("MainHUD")
	if not MainHUD then
		MainHUD = PlayerGuiInstance:WaitForChild("MainHUD", 5)
	end
	if CurrentPlayerGui == PlayerGuiInstance then
		BindHUD(MainHUD)
	end
end

--// Initialization \\--
function GuiController.Init()
	if Initialized then
		return
	end
	Initialized = true

	table.insert(
		ControllerConnections,
		LocalPlayer.ChildAdded:Connect(function(Child)
			if Child.Name == "PlayerGui" then
				AttachPlayerGui(Child)
			end
		end)
	)
	table.insert(
		ControllerConnections,
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
		SetHUDUnavailable()
	end
end

function GuiController.Start()
	if Started then
		return
	end
	Started = true
	table.insert(ControllerConnections, LocalPlayer:GetAttributeChangedSignal("Bigger"):Connect(UpdateHUD))
	table.insert(ControllerConnections, LocalPlayer:GetAttributeChangedSignal("Level"):Connect(UpdateHUD))
	table.insert(ControllerConnections, LocalPlayer:GetAttributeChangedSignal("Multiplier"):Connect(UpdateHUD))
	table.insert(ControllerConnections, LocalPlayer:GetAttributeChangedSignal("Rebirth"):Connect(UpdateHUD))
	table.insert(ControllerConnections, LocalPlayer:GetAttributeChangedSignal("RebirthMultiplier"):Connect(UpdateHUD))
	UpdateHUD()
end

function GuiController.GetStatus(): "Ready" | "HUDUnavailable"
	return Status
end

function GuiController.Destroy()
	DisconnectConnections(ControllerConnections)
	DetachPlayerGui()
	Initialized = false
	Started = false
	HUDWarningEmitted = false
end

return GuiController
