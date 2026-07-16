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

local GuiController = {}

--// Referencing \\--
local ScreenGui: ScreenGui
local LevelLabel: TextLabel
local ProgressFill: ImageLabel
local ProgressTextLabel: TextLabel

--// Helpers \\--
local function CalculateLevelProgress(bigger: number, level: number): (number, number, number)
	local startBigger = math.floor(236 * math.pow(level - 1, 4))
	local targetBigger = math.floor(236 * math.pow(level, 4))

	local currentProgress = math.max(0, bigger - startBigger)
	local totalRequired = math.max(1, targetBigger - startBigger)
	local ratio = math.clamp(currentProgress / totalRequired, 0, 1)

	return ratio, currentProgress, totalRequired
end

local function UpdateHUD()
	local bigger = LocalPlayer:GetAttribute("Bigger") or 1
	local level = LocalPlayer:GetAttribute("Level") or 1
	local multiplier = LocalPlayer:GetAttribute("Multiplier") or 1

	LevelLabel.Text = FormatNumber(bigger) .. " BIGGER"

	local ratio, currentProgress, totalRequired = CalculateLevelProgress(bigger, level)

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
		TweenService:Create(uiScale, TweenInfo.new(0.1, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			Scale = 1.1,
		}):Play()
	end)
end

--// Initialization \\--
function GuiController.Init()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui")
	ScreenGui = playerGui:WaitForChild("MainHUD") :: ScreenGui

	-- Reference LeftSidebar
	local leftSidebar = ScreenGui:WaitForChild("LeftSidebar") :: Frame
	for _, child in ipairs(leftSidebar:GetChildren()) do
		if child:IsA("ImageButton") then
			ApplyHoverAnimation(child)
			child.MouseButton1Click:Connect(function()
				print(child.Name .. " button clicked (stub)")
			end)
		end
	end

	-- Reference BottomHUD
	local bottomHUD = ScreenGui:WaitForChild("BottomHUD") :: Frame

	-- Reference Progress Bar components
	local progressBarFrame = bottomHUD:WaitForChild("ProgressBarFrame") :: Frame
	local progressBG = progressBarFrame:WaitForChild("ProgressBG") :: ImageLabel

	LevelLabel = progressBG:WaitForChild("LevelLabel") :: TextLabel
	local barContainer = progressBG:WaitForChild("BarContainer") :: Frame
	ProgressFill = barContainer:WaitForChild("ProgressFill") :: ImageLabel
	ProgressTextLabel = progressBG:WaitForChild("ProgressTextLabel") :: TextLabel

	-- Reference Bottom Buttons (Developer Products)
	local buttonsContainer = bottomHUD:WaitForChild("ButtonsContainer") :: Frame
	for _, child in ipairs(buttonsContainer:GetChildren()) do
		if child:IsA("ImageButton") then
			ApplyHoverAnimation(child)
			local config = ShopUIConfig[child.Name]
			if config then
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
	local rightSidebar = ScreenGui:WaitForChild("RightSidebar", 5) :: Frame?
	if rightSidebar then
		for _, child in ipairs(rightSidebar:GetChildren()) do
			if child:IsA("ImageButton") then
				ApplyHoverAnimation(child)
				local config = ShopUIConfig[child.Name]
				if config then
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
	end
end

function GuiController.Start()
	-- Connect attribute changed signals to update HUD
	LocalPlayer:GetAttributeChangedSignal("Bigger"):Connect(UpdateHUD)
	LocalPlayer:GetAttributeChangedSignal("Level"):Connect(UpdateHUD)
	LocalPlayer:GetAttributeChangedSignal("Multiplier"):Connect(UpdateHUD)

	-- Initial HUD update
	UpdateHUD()
end

return GuiController
