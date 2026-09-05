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
local ScreenGui: ScreenGui
local LevelLabel: TextLabel
local ProgressFill: ImageLabel
local ProgressTextLabel: TextLabel
local ProgressStatsLabel: TextLabel?

local LeftSidebar: Frame
local BottomHUD: Frame
local ProgressBarFrame: Frame
local ButtonsContainer: Frame
local RightSidebar: Frame?
local SelectionOutline: Frame

--// Helpers \\--
local function CalculateLevelProgress(bigger: number): (number, number)
	local derivedLevel = LevelFormula.GetLevel(bigger)
	local progressData = LevelFormula.GetProgress(bigger)
	local ratio = if type(progressData) == "table" then progressData.Progress else (progressData or 0)
	local _, nextLevelReq = LevelFormula.GetCurrentRange(derivedLevel)
	return ratio, nextLevelReq
end

local function UpdateHUD()
	local bigger = LocalPlayer:GetAttribute("Bigger") or 1
	local multiplier = LocalPlayer:GetAttribute("Multiplier") or 1

	if LevelLabel then
		LevelLabel.Text = FormatNumber(bigger) .. " BIGGER"
	end

	local ratio, nextLevelReq = CalculateLevelProgress(bigger)
	if ProgressStatsLabel then
		ProgressStatsLabel.Text = FormatNumber(bigger) .. " / " .. FormatNumber(nextLevelReq)
	end

	if ProgressFill then
		if bigger <= 1 then
			ProgressFill.Visible = false
			ProgressFill.Size = UDim2.fromScale(0, 1)
		else
			ProgressFill.Visible = true
			TweenService:Create(ProgressFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
				Size = UDim2.fromScale(ratio, 1),
			}):Play()
		end
	end

	if ProgressTextLabel then
		ProgressTextLabel.Text = tostring(multiplier) .. "X Multiplier"
	end
end

-- Hook up hover scaling animations to a button
local function ApplyHoverAnimation(button: ImageButton)
	local uiScale = button:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Parent = button
	end

	button.MouseEnter:Connect(function()
		TweenService:Create(uiScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 1.1,
		}):Play()
	end)

	button.MouseLeave:Connect(function()
		TweenService:Create(uiScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 1.0,
		}):Play()
	end)

	button.MouseButton1Down:Connect(function()
		TweenService:Create(uiScale, TweenInfo.new(0.05, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 0.95,
		}):Play()
	end)

	button.MouseButton1Up:Connect(function()
		TweenService:Create(uiScale, TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 1.1,
		}):Play()
	end)
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
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	ScreenGui = playerGui:WaitForChild("MainHUD", 10) :: ScreenGui
	local safeAreaRoot = ScreenGui:WaitForChild("SafeAreaRoot")
	local persistentHUD = safeAreaRoot:WaitForChild("PersistentHUD")

	-- Create SelectionOutline highlight
	SelectionOutline = Instance.new("Frame")
	SelectionOutline.Name = "SelectionOutline"
	SelectionOutline.BackgroundTransparency = 1
	SelectionOutline.Size = UDim2.fromScale(1, 1)
	SelectionOutline.Position = UDim2.fromScale(0, 0)
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 200, 0)
	stroke.Thickness = 3
	stroke.Parent = SelectionOutline
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = SelectionOutline
	SelectionOutline.Parent = ScreenGui

	LeftSidebar = persistentHUD:WaitForChild("LeftSidebar") :: Frame
	for _, child in ipairs(LeftSidebar:GetChildren()) do
		if child:IsA("GuiObject") and QUARANTINED_BUTTONS[child.Name] then
			child.Visible = false
			child.Active = false
			continue
		end
		if child:IsA("ImageButton") then
			ApplyHoverAnimation(child)
			child.MouseButton1Click:Connect(function()
				UIEventBus.Publish("SidebarButtonClicked", child.Name)
			end)
		end
	end

	-- Reference BottomHUD
	BottomHUD = persistentHUD:WaitForChild("BottomHUD") :: Frame
	BottomHUD.AnchorPoint = Vector2.new(0.5, 1)
	BottomHUD.Position = UDim2.new(0.5, 0, 1, -10)

	-- Reference Progress Bar components
	ProgressBarFrame = BottomHUD:WaitForChild("ProgressBarFrame") :: Frame
	LevelLabel = ProgressBarFrame:WaitForChild("LevelLabel") :: TextLabel
	ProgressTextLabel = ProgressBarFrame:WaitForChild("ProgressTextLabel") :: TextLabel

	local progressBG = ProgressBarFrame:WaitForChild("ProgressBG") :: ImageLabel
	local barContainer = progressBG:WaitForChild("BarContainer") :: Frame
	ProgressFill = barContainer:WaitForChild("ProgressFill") :: ImageLabel
	ProgressStatsLabel = progressBG:FindFirstChild("ProgressStatsLabel") :: TextLabel?

	-- Reference Bottom Buttons (Developer Products)
	ButtonsContainer = BottomHUD:WaitForChild("ButtonsContainer") :: Frame
	ButtonsContainer.AnchorPoint = Vector2.new(0.5, 0)
	ButtonsContainer.Position = UDim2.fromScale(0.5, 0.58)

	for _, child in ipairs(ButtonsContainer:GetChildren()) do
		if child:IsA("ImageButton") then
			ApplyHoverAnimation(child)
			local config = ShopUIConfig[child.Name]
			if config then
				local textLabel = child:FindFirstChildOfClass("TextLabel")
				if textLabel then
					textLabel.Text = config.Display
				end
				child.MouseButton1Click:Connect(function()
					print(
						"Prompting product purchase for key: "
							.. child.Name
							.. " (ProductId: "
							.. config.ProductId
							.. ")"
					)
					MarketplaceService:PromptProductPurchase(LocalPlayer, config.ProductId)
				end)
			end
		end
	end

	-- Reference RightSidebar (VIP and Double Multiplier)
	RightSidebar = persistentHUD:WaitForChild("RightSidebar", 5) :: Frame?
	if RightSidebar then
		for _, child in ipairs(RightSidebar:GetChildren()) do
			if child:IsA("ImageButton") then
				ApplyHoverAnimation(child)
				local config = ShopUIConfig[child.Name]
				if config then
					local textLabel = child:FindFirstChildOfClass("TextLabel")
					if textLabel then
						textLabel.Text = config.Display
					end
					child.MouseButton1Click:Connect(function()
						print(
							"Prompting product purchase for key: "
								.. child.Name
								.. " (ProductId: "
								.. config.ProductId
								.. ")"
						)
						MarketplaceService:PromptProductPurchase(LocalPlayer, config.ProductId)
					end)
				end
			end
		end
		local vipButton = RightSidebar:FindFirstChild("Vip")
		if vipButton and vipButton:IsA("ImageButton") then
			vipButton.MouseButton1Click:Connect(function()
				local assetId = LocalPlayer:GetAttribute("VipGamePassAssetId")
				if type(assetId) == "number" and assetId > 0 and assetId % 1 == 0 then
					MarketplaceService:PromptGamePassPurchase(LocalPlayer, assetId)
				end
			end)
		end
	end

	-- Focus first button on gamepad input
	UserInputService.LastInputTypeChanged:Connect(function(lastInputType)
		if lastInputType == Enum.UserInputType.Gamepad1 then
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
	end)

	-- Immediate initial HUD update on Init
	UpdateHUD()
end

function GuiController.Start()
	-- Connect attribute changed signals for real-time HUD update
	LocalPlayer:GetAttributeChangedSignal("Bigger"):Connect(UpdateHUD)
	LocalPlayer:GetAttributeChangedSignal("Level"):Connect(UpdateHUD)
	LocalPlayer:GetAttributeChangedSignal("Multiplier"):Connect(UpdateHUD)

	-- Initial HUD update
	UpdateHUD()

	-- Connect to profile changes and apply layout
	ResponsiveController.ProfileChanged:Connect(function(profile)
		ApplyProfile(profile)
	end)

	-- Apply initial profile
	ApplyProfile(ResponsiveController:GetProfile())
end

return GuiController
