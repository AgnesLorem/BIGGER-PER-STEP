--!strict
-- GuiController.luau
-- References and manages the main HUD, responsiveness, and shop purchases.

--// Raw Requirings \\--
local GuiService = game:GetService("GuiService")
local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

--// Requirings \\--
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
local ResponsiveController = require(script.Parent:WaitForChild("ResponsiveController"))
local ResponsivePolicy = require(script.Parent:WaitForChild("ResponsivePolicy"))
local UIEventBus = require(script.Parent:WaitForChild("UIEventBus"))

--// Types \\--
type ViewportProfile = ResponsiveController.ViewportProfile

--// Variables \\--
local LocalPlayer = Players.LocalPlayer
local GuiController = {}

local QUARANTINED_BUTTONS: { [string]: boolean } = {
	Daily = true,
	DailyReward = true,
	DailyRewards = true,
	Spin = true,
	SpinWheel = true,
	LuckySpin = true,
	Cosmetics = true,
	Trails = true,
	Titles = true,
	CosmeticShop = true,
	AutoWins = true,
	AutoWin = true,
	Auto = true,
}

--// Referencing \\--
local ScreenGui: ScreenGui? = nil
local LevelLabel: TextLabel? = nil
local ProgressFill: ImageLabel? = nil
local ProgressTextLabel: TextLabel? = nil
local ProgressStatsLabel: TextLabel? = nil

local LeftSidebar: Frame? = nil
local BottomHUD: Frame? = nil
local ProgressBarFrame: Frame? = nil
local ButtonsContainer: Frame? = nil
local RightSidebar: Frame? = nil
local SelectionOutline: Frame? = nil

local CurrentPlayerGui: PlayerGui? = nil
local HUDConnections: { RBXScriptConnection } = {}
local PlayerGuiConnections: { RBXScriptConnection } = {}
local ControllerConnections: { RBXScriptConnection } = {}
local Status: "Ready" | "HUDUnavailable" = "HUDUnavailable"
local HUDWarningEmitted = false
local Initialized = false
local Started = false

--// Helpers \\--
local function CalculateLevelProgress(bigger: number): (number, number)
	local derivedLevel = LevelFormula.GetLevel(bigger)
	local progressData = LevelFormula.GetProgress(bigger)
	local ratio = if type(progressData) == "table" then progressData.Progress else (progressData or 0)
	local _, nextLevelReq = LevelFormula.GetCurrentRange(derivedLevel)
	return ratio, nextLevelReq
end

local function UpdateHUD()
	if not LevelLabel or not ProgressFill or not ProgressTextLabel then
		return
	end
	local biggerAttribute = LocalPlayer:GetAttribute("Bigger")
	local bigger = if type(biggerAttribute) == "number" and biggerAttribute >= 0 then biggerAttribute else 0
	local levelAttribute = LocalPlayer:GetAttribute("Level")
	local _level = if type(levelAttribute) == "number" then levelAttribute else 1
	local multiplier = LocalPlayer:GetAttribute("Multiplier") or 1

	LevelLabel.Text = FormatNumber(bigger) .. " BIGGER"

	local ratio, nextLevelReq = CalculateLevelProgress(bigger)
	if ProgressStatsLabel then
		ProgressStatsLabel.Text = FormatNumber(bigger) .. " / " .. FormatNumber(nextLevelReq)
	end

	if bigger <= 1 then
		ProgressFill.Visible = false
		ProgressFill.Size = UDim2.fromScale(0, 1)
	else
		ProgressFill.Visible = true
		TweenService:Create(ProgressFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Size = UDim2.fromScale(ratio, 1),
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
	local FoundLeftSidebar = PersistentHUD and PersistentHUD:FindFirstChild("LeftSidebar") :: Frame?
	local FoundBottomHUD = PersistentHUD and PersistentHUD:FindFirstChild("BottomHUD") :: Frame?
	local FoundProgressBarFrame = FoundBottomHUD and FoundBottomHUD:FindFirstChild("ProgressBarFrame") :: Frame?
	local ProgressBG = FoundProgressBarFrame and FoundProgressBarFrame:FindFirstChild("ProgressBG") :: ImageLabel?
	local BarContainer = ProgressBG and ProgressBG:FindFirstChild("BarContainer") :: Frame?
	local FoundButtonsContainer = FoundBottomHUD and FoundBottomHUD:FindFirstChild("ButtonsContainer") :: Frame?
	local FoundLevelLabel = ProgressBG and ProgressBG:FindFirstChild("LevelLabel") :: TextLabel?
	local FoundProgressFill = BarContainer and BarContainer:FindFirstChild("ProgressFill") :: ImageLabel?
	local FoundProgressTextLabel = ProgressBG and ProgressBG:FindFirstChild("ProgressTextLabel") :: TextLabel?
	if
		not FoundLeftSidebar
		or not FoundBottomHUD
		or not FoundButtonsContainer
		or not FoundLevelLabel
		or not FoundProgressFill
		or not FoundProgressTextLabel
	then
		SetHUDUnavailable()
		return false
	end

	ScreenGui = Candidate :: ScreenGui
	LevelLabel = FoundLevelLabel
	ProgressFill = FoundProgressFill
	ProgressTextLabel = FoundProgressTextLabel
	LeftSidebar = FoundLeftSidebar
	BottomHUD = FoundBottomHUD
	ProgressBarFrame = FoundProgressBarFrame
	ButtonsContainer = FoundButtonsContainer
	ProgressStatsLabel = ProgressBG:FindFirstChild("ProgressStatsLabel") :: TextLabel?

	for _, Child in FoundLeftSidebar:GetChildren() do
		if Child:IsA("GuiObject") and QUARANTINED_BUTTONS[Child.Name] then
			Child.Visible = false
			Child.Active = false
			continue
		end
		if Child:IsA("ImageButton") then
			ApplyHoverAnimation(Child)
			TrackHUDConnection(Child.MouseButton1Click:Connect(function()
				if UIEventBus and UIEventBus.Publish then
					UIEventBus.Publish("SidebarButtonClicked", Child.Name)
				end
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

	for _, Child in FoundButtonsContainer:GetChildren() do
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

	local FoundRightSidebar = PersistentHUD and PersistentHUD:FindFirstChild("RightSidebar") :: Frame?
	RightSidebar = FoundRightSidebar
	if FoundRightSidebar then
		for _, Child in FoundRightSidebar:GetChildren() do
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
		local VipButton = FoundRightSidebar:FindFirstChild("Vip")
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

local function getSortedButtons(container: GuiObject): { ImageButton }
	local buttons = {}
	for _, child in ipairs(container:GetChildren()) do
		if child:IsA("ImageButton") and child.Visible then
			table.insert(buttons, child)
		end
	end
	table.sort(buttons, function(a, b)
		if a.LayoutOrder == b.LayoutOrder then
			return a.Name < b.Name
		else
			return a.LayoutOrder < b.LayoutOrder
		end
	end)
	return buttons
end

local function ConfigureGamepadNavigation()
	local leftButtons = getSortedButtons(LeftSidebar)
	local rightButtons = RightSidebar and getSortedButtons(RightSidebar) or {}
	local bottomButtons = getSortedButtons(ButtonsContainer)

	-- 1. LeftSidebar (Grid / List)
	local numLeft = #leftButtons
	if numLeft > 0 then
		for i, btn in ipairs(leftButtons) do
			btn.SelectionImageObject = SelectionOutline
			btn.SelectionGroup = true

			if numLeft <= 2 then
				local prev = leftButtons[i - 1] or leftButtons[numLeft]
				local next = leftButtons[i + 1] or leftButtons[1]
				btn.NextSelectionUp = prev
				btn.NextSelectionDown = next
				btn.NextSelectionLeft = btn
				btn.NextSelectionRight = (#bottomButtons > 0) and bottomButtons[1] or btn
			else
				local isLeftCol = (i % 2 == 1)
				local partnerIdx = isLeftCol and (i + 1) or (i - 1)
				local partner = leftButtons[partnerIdx] or btn

				btn.NextSelectionLeft = isLeftCol and partner or btn
				btn.NextSelectionRight = isLeftCol and partner or ((#bottomButtons > 0) and bottomButtons[1] or btn)

				local upIdx = i - 2
				if upIdx < 1 then
					upIdx = (numLeft % 2 == 0) and (numLeft - (2 - i)) or (numLeft - (1 - i % 2))
					if upIdx > numLeft then
						upIdx = numLeft
					end
				end
				local downIdx = i + 2
				if downIdx > numLeft then
					downIdx = i % 2 == 1 and 1 or 2
				end
				btn.NextSelectionUp = leftButtons[upIdx] or btn
				btn.NextSelectionDown = leftButtons[downIdx] or btn
			end
		end
	end

	-- 2. RightSidebar (Vertical List)
	local numRight = #rightButtons
	if numRight > 0 then
		for i, btn in ipairs(rightButtons) do
			btn.SelectionImageObject = SelectionOutline
			btn.SelectionGroup = true

			local prev = rightButtons[i - 1] or rightButtons[numRight]
			local next = rightButtons[i + 1] or rightButtons[1]
			btn.NextSelectionUp = prev
			btn.NextSelectionDown = next
			btn.NextSelectionRight = btn
			btn.NextSelectionLeft = (#bottomButtons > 0) and bottomButtons[#bottomButtons] or btn
		end
	end

	-- 3. BottomHUD ButtonsContainer (Horizontal List)
	local numBottom = #bottomButtons
	if numBottom > 0 then
		for i, btn in ipairs(bottomButtons) do
			btn.SelectionImageObject = SelectionOutline
			btn.SelectionGroup = true

			local prev = bottomButtons[i - 1] or bottomButtons[numBottom]
			local next = bottomButtons[i + 1] or bottomButtons[1]
			btn.NextSelectionLeft = prev
			btn.NextSelectionRight = next
			btn.NextSelectionUp = (numLeft > 0) and leftButtons[1] or btn
			btn.NextSelectionDown = btn
		end
	end
end

local function ApplyProfile(profile: ViewportProfile)
	local category = profile.Category
	local layout = ResponsivePolicy.GetPolicy(category)

	-- 1. Apply sidebars visibility and sizes
	LeftSidebar.Visible = (layout.LeftSidebarMode ~= "Hidden")
	if LeftSidebar.Visible then
		LeftSidebar.Size = UDim2.new(layout.SidebarWidthScale, 0, LeftSidebar.Size.Y.Scale, LeftSidebar.Size.Y.Offset)
		local grid = LeftSidebar:FindFirstChildOfClass("UIGridLayout")
		if grid then
			grid.CellSize = layout.GridCellSize
		end
		if layout.LeftSidebarMode == "Collapsed" then
			UIEventBus.Publish("SidebarCollapsed", "LeftSidebar")
		end
	end

	if RightSidebar then
		RightSidebar.Visible = (layout.RightSidebarMode ~= "Hidden")
		if RightSidebar.Visible then
			RightSidebar.Size =
				UDim2.new(layout.SidebarWidthScale, 0, RightSidebar.Size.Y.Scale, RightSidebar.Size.Y.Offset)
			if layout.RightSidebarMode == "Collapsed" then
				UIEventBus.Publish("SidebarCollapsed", "RightSidebar")
			end
		end
	end

	-- 2. Apply BottomHUD layout (Centered horizontally)
	BottomHUD.Size = UDim2.new(BottomHUD.Size.X.Scale, BottomHUD.Size.X.Offset, layout.HUDHeightScale, 0)
	BottomHUD.Position = UDim2.new(0.5, 0, 1, -10)
	BottomHUD.AnchorPoint = Vector2.new(0.5, 1)

	ProgressBarFrame.Visible = (layout.BottomHUDStyle == "Full")
	ButtonsContainer.AnchorPoint = Vector2.new(0.5, 0)
	if layout.BottomHUDStyle == "Compact" then
		ButtonsContainer.Position = UDim2.fromScale(0.5, 0)
		ButtonsContainer.Size = UDim2.fromScale(1, 1)
	else
		ButtonsContainer.Position = UDim2.fromScale(0.5, 0.58)
		ButtonsContainer.Size = UDim2.fromScale(1, 0.42)
	end

	-- 3. Configure Gamepad Navigation
	ConfigureGamepadNavigation()

	-- 4. Publish LayoutChanged event
	UIEventBus.Publish("LayoutChanged", layout)
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

	-- Focus first button on gamepad input
	table.insert(
		ControllerConnections,
		UserInputService.LastInputTypeChanged:Connect(function(lastInputType)
			if lastInputType == Enum.UserInputType.Gamepad1 then
				if ButtonsContainer and LeftSidebar then
					local bottomButtons = getSortedButtons(ButtonsContainer)
					if #bottomButtons > 0 then
						GuiService.SelectedObject = bottomButtons[1]
					else
						local leftButtons = getSortedButtons(LeftSidebar)
						if #leftButtons > 0 then
							GuiService.SelectedObject = leftButtons[1]
						end
					end
				end
			end
		end)
	)

	UpdateHUD()
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

	if ResponsiveController and ResponsiveController.ProfileChanged then
		table.insert(
			ControllerConnections,
			ResponsiveController.ProfileChanged:Connect(function(profile)
				ApplyProfile(profile)
			end)
		)
		ApplyProfile(ResponsiveController:GetProfile())
	end
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
