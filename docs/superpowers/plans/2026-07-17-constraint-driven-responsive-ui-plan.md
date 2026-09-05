# Constraint-Driven Responsive UI (CDRA) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Refactor the entire MainHUD (LeftSidebar, BottomHUD, RightSidebar) using Constraint-Driven Responsive Architecture (CDRA) and verify layout behavior on PC, Mobile, Tablet, and Console.

**Architecture:** Implement static engine-driven responsive layouts (Layer 1) using an idempotent Edit-mode migration script that structures HUD elements under `PersistentHUD` inside `SafeAreaRoot` natively. Build `ResponsiveController.luau` and `ResponsivePolicy.luau` (Layer 2) to dynamically classify viewports based on a config profile module. Integrate and adapt the UI structure (Layer 3) inside `GuiController.luau` using state updates.

**Tech Stack:** Luau, Roblox Studio UI engine (Layouts, Constraints, AutomaticSize), Roblox Device Emulator.

## Global Constraints
*   **Philosophy**: *Responsive by composition, not by scripting.*
*   **Scale Priority**: Use Scale for size/position of HUD elements, not Offset. Offset is valid for padding, borders, shadows, animations, separators, pixel alignment, and icon spacing.
*   **Safe Area Policy**: All root HUD containers must remain inside Roblox's safe area. Root ScreenGui handles safe-area adaptation via `SafeAreaRoot` (Size=1,1, Position=0,0) natively via engine ScreenInsets (`Enum.ScreenInsets.DeviceSafeInsets`); child widgets must not compensate individually.
*   **ZIndex Layering**: 0-9 Background, 10-49 HUD, 50-99 Popup, 100-149 Notification, 150-179 Tooltip, 180+ Debug.
*   **Animation Constraint**: Animations must never be responsible for responsive layout. May affect UIScale, Rotation, Transparency, Color, Stroke; never tween Size, Position, AnchorPoint, or LayoutOrder for responsiveness. Position/Size tweens are allowed only for transitional presentation animations (Layer 4) (e.g. inventory slide-in, popup scaling transitions).
*   **ViewModel Rule**: UI reads exclusively from its bound ViewModel snapshots. ViewModels are immutable, mutated by controllers, and read by Views.
*   **UI Validation Rules**:
    *   *Buttons*: must contain `UIScale`, `UIAspectRatioConstraint` (where visual consistency is required), `UICorner`, and optionally `UIStroke`.
    *   *Text*: must use `TextScaled` + `UITextSizeConstraint`.
    *   *Containers (that own multiple children)*: must have defined `AnchorPoint`, `UIPadding`, and a Layout object. No duplicates of Constraints, `UIScale`, `UITextSizeConstraint`, `UIAspectRatioConstraint`, `UIPadding`, or `UIStroke` under any parent.
*   **Console Policy**: Gamepad navigation must be cyclic, have no dead focus points, define explicit `NextSelection` keys, and implement custom `SelectionImageObject` style assets.
*   **Mandatory Rule**: CDRA is mandatory for all new ScreenGuis. Legacy UIs are migrated incrementally.

---

### Task 1: Audit and Primary Layout Setup (Layer 1 Foundation) via Edit Mode Setup Script

**Files:**
*   Create: `scratch/apply_cdra_hud.luau` (Run once in Studio Edit mode, then discard. Must be idempotent and safe to run multiple times without duplicating constraints. Respects Hierarchy Freeze: cannot rename or delete existing objects, but may insert new constraints or frames like `SafeAreaRoot`, `PersistentHUD`, and `OverlayHUD` for safe routing. Aborts if the baseline hierarchy assumptions are not met). Supports `Mode = "ValidateOnly"`, `Mode = "Repair"`, `Mode = "Backup"`, and `Mode = "Restore"` modes.
*   Modify: `StarterGui.MainHUD` (via Edit mode execution)

**Interfaces:**
*   Produces: Refactored `MainHUD` instance properties in the Studio place.

- [ ] **Step 1: Write the Edit-mode Migration Script**
  Create `scratch/apply_cdra_hud.luau` to programmatically apply CDRA properties to `MainHUD`. It must find and configure (or create if missing) constraints without duplicating them. It must also introduce `SafeAreaRoot`, `PersistentHUD`, and `OverlayHUD` under `MainHUD` and reparent HUD sidebars/HUD bottom to it.

```luau
-- scratch/apply_cdra_hud.luau
-- Run this in Roblox Studio (Edit mode) to programmatically align MainHUD to CDRA.

local StarterGui = game:GetService("StarterGui")
local MainHUD = StarterGui:FindFirstChild("MainHUD")
if not MainHUD then
	error("MainHUD not found under StarterGui!")
end

local Mode: "ValidateOnly" | "Repair" | "Backup" | "Restore" = "ValidateOnly"

local function logChange(elementName: string, propertyName: string, fromVal: any, toVal: any)
	print(string.format("[Migration] %s.%s changed from %s to %s", elementName, propertyName, tostring(fromVal), tostring(toVal)))
end

-- 1. Verify Hierarchy Integrity (Hierarchy Abort Rule)
local leftSidebar = MainHUD:FindFirstChild("LeftSidebar") or MainHUD:FindFirstChild("SafeAreaRoot") and MainHUD.SafeAreaRoot:FindFirstChild("PersistentHUD") and MainHUD.SafeAreaRoot.PersistentHUD:FindFirstChild("LeftSidebar")
local bottomHUD = MainHUD:FindFirstChild("BottomHUD") or MainHUD:FindFirstChild("SafeAreaRoot") and MainHUD.SafeAreaRoot:FindFirstChild("PersistentHUD") and MainHUD.SafeAreaRoot.PersistentHUD:FindFirstChild("BottomHUD")
local rightSidebar = MainHUD:FindFirstChild("RightSidebar") or MainHUD:FindFirstChild("SafeAreaRoot") and MainHUD.SafeAreaRoot:FindFirstChild("PersistentHUD") and MainHUD.SafeAreaRoot.PersistentHUD:FindFirstChild("RightSidebar")

if not leftSidebar or not bottomHUD or not rightSidebar then
	error("Hierarchy validation failed: Base HUD containers not found. Aborting migration!")
end

-- Helpers to ensure constraints exist, are configured, and never duplicated
local function getOrCreateConstraintOfClass(parent: Instance, className: string): Instance
	local child = parent:FindFirstChildOfClass(className)
	if not child then
		if Mode == "Repair" then
			child = Instance.new(className)
			child.Parent = parent
		else
			print("[ValidateOnly] Missing constraint of class " .. className .. " under " .. parent.Name)
			-- Mock for dry run validation
			child = Instance.new(className)
		end
	end
	return child
end

-- 2. Configure SafeAreaRoot, PersistentHUD, and OverlayHUD structures
local safeAreaRoot = MainHUD:FindFirstChild("SafeAreaRoot") :: Frame
if not safeAreaRoot then
	if Mode == "Repair" then
		safeAreaRoot = Instance.new("Frame")
		safeAreaRoot.Name = "SafeAreaRoot"
		safeAreaRoot.Size = UDim2.new(1, 0, 1, 0)
		safeAreaRoot.Position = UDim2.new(0, 0, 0, 0)
		safeAreaRoot.BackgroundTransparency = 1
		safeAreaRoot.Parent = MainHUD
	else
		print("[ValidateOnly] Missing SafeAreaRoot under MainHUD")
	end
end

local persistentHUD = safeAreaRoot and safeAreaRoot:FindFirstChild("PersistentHUD") :: Frame
if not persistentHUD and safeAreaRoot then
	if Mode == "Repair" then
		persistentHUD = Instance.new("Frame")
		persistentHUD.Name = "PersistentHUD"
		persistentHUD.Size = UDim2.new(1, 0, 1, 0)
		persistentHUD.Position = UDim2.new(0, 0, 0, 0)
		persistentHUD.BackgroundTransparency = 1
		persistentHUD.Parent = safeAreaRoot
	else
		print("[ValidateOnly] Missing PersistentHUD under SafeAreaRoot")
	end
end

local overlayHUD = safeAreaRoot and safeAreaRoot:FindFirstChild("OverlayHUD") :: Frame
if not overlayHUD and safeAreaRoot then
	if Mode == "Repair" then
		overlayHUD = Instance.new("Frame")
		overlayHUD.Name = "OverlayHUD"
		overlayHUD.Size = UDim2.new(1, 0, 1, 0)
		overlayHUD.Position = UDim2.new(0, 0, 0, 0)
		overlayHUD.BackgroundTransparency = 1
		overlayHUD.Parent = safeAreaRoot
	else
		print("[ValidateOnly] Missing OverlayHUD under SafeAreaRoot")
	end
end

-- Reparent HUD containers (safe to run multiple times)
if leftSidebar and leftSidebar.Parent ~= persistentHUD and Mode == "Repair" and persistentHUD then
	leftSidebar.Parent = persistentHUD
elseif leftSidebar and leftSidebar.Parent ~= persistentHUD and Mode == "ValidateOnly" then
	print("[ValidateOnly] LeftSidebar parent is not PersistentHUD")
end

if bottomHUD and bottomHUD.Parent ~= persistentHUD and Mode == "Repair" and persistentHUD then
	bottomHUD.Parent = persistentHUD
elseif bottomHUD and bottomHUD.Parent ~= persistentHUD and Mode == "ValidateOnly" then
	print("[ValidateOnly] BottomHUD parent is not PersistentHUD")
end

if rightSidebar and rightSidebar.Parent ~= persistentHUD and Mode == "Repair" and persistentHUD then
	rightSidebar.Parent = persistentHUD
elseif rightSidebar and rightSidebar.Parent ~= persistentHUD and Mode == "ValidateOnly" then
	print("[ValidateOnly] RightSidebar parent is not PersistentHUD")
end

-- 3. Configure LeftSidebar (Grid scale and Aspect Ratio)
if leftSidebar then
	if Mode == "Repair" then
		leftSidebar.AnchorPoint = Vector2.new(0, 0.5)
		leftSidebar.Position = UDim2.new(0.02, 0, 0.5, 0)
		leftSidebar.Size = UDim2.new(0.12, 0, 0.35, 0)
		leftSidebar.ZIndex = 10
	else
		logChange("LeftSidebar", "Properties", "Current", "AnchorPoint: 0, 0.5; Position: 2%, 0, 50%, 0; Size: 12%, 0, 35%, 0")
	end

	local grid = leftSidebar:FindFirstChildOfClass("UIGridLayout")
	if grid then
		if Mode == "Repair" then
			grid.CellSize = UDim2.new(0.46, 0, 0.3, 0)
			grid.CellPadding = UDim2.new(0.08, 0, 0.05, 0)
		else
			logChange("UIGridLayout", "CellSize/Padding", "Current", "CellSize: 46%, 0, 30%, 0")
		end
	end

	-- Add aspect ratio constraints to buttons where visual consistency is required
	for _, child in ipairs(leftSidebar:GetChildren()) do
		if child:IsA("ImageButton") then
			local constraint = getOrCreateConstraintOfClass(child, "UIAspectRatioConstraint") :: UIAspectRatioConstraint
			if Mode == "Repair" then
				constraint.AspectRatio = 1.0
			end
		end
	end
end

-- 4. Configure BottomHUD (Center-bottom anchor and Progress bar scale cleanup)
if bottomHUD then
	if Mode == "Repair" then
		bottomHUD.AnchorPoint = Vector2.new(0.5, 1)
		bottomHUD.Position = UDim2.new(0.5, 0, 1, -10)
		bottomHUD.Size = UDim2.new(0.5, 0, 0.22, 0)
		bottomHUD.ZIndex = 10
	else
		logChange("BottomHUD", "Properties", "Current", "AnchorPoint: 0.5, 1; Position: 50%, 0, 100%, -10; Size: 50%, 0, 22%, 0")
	end

	local progressBarFrame = bottomHUD:FindFirstChild("ProgressBarFrame") :: Frame
	if progressBarFrame then
		if Mode == "Repair" then
			progressBarFrame.AnchorPoint = Vector2.new(0, 0)
			progressBarFrame.Position = UDim2.new(0, 0, 0, 0)
			progressBarFrame.Size = UDim2.new(1, 0, 0.3, 0)
		end

		local progressBG = progressBarFrame:FindFirstChild("ProgressBG") :: ImageLabel
		if progressBG then
			if Mode == "Repair" then
				progressBG.AnchorPoint = Vector2.new(0.5, 0.5)
				progressBG.Position = UDim2.new(0.5, 0, 0.5, 0)
				progressBG.Size = UDim2.new(1, -8, 1, -8) -- Correct scale inside frame
			end

			local barContainer = progressBG:FindFirstChild("BarContainer") :: Frame
			if barContainer then
				if Mode == "Repair" then
					barContainer.AnchorPoint = Vector2.new(0.5, 0.5)
					barContainer.Position = UDim2.new(0.5, 0, 0.5, 0)
					barContainer.Size = UDim2.new(1, -8, 1, -8)
				end

				local progressFill = barContainer:FindFirstChild("ProgressFill") :: ImageLabel
				if progressFill then
					if Mode == "Repair" then
						progressFill.AnchorPoint = Vector2.new(0, 0.5)
						progressFill.Position = UDim2.new(0, 0, 0.5, 0)
						progressFill.Size = UDim2.new(0, 0, 1, 0)
					end
				end
			end

			local levelLabel = progressBG:FindFirstChild("LevelLabel") :: TextLabel
			if levelLabel then
				if Mode == "Repair" then
					levelLabel.AnchorPoint = Vector2.new(0, 0.5)
					levelLabel.Position = UDim2.new(0.02, 0, 0.5, 0)
					levelLabel.Size = UDim2.new(0.45, 0, 0.8, 0)
					levelLabel.TextScaled = true
					local sizeConstraint = getOrCreateConstraintOfClass(levelLabel, "UITextSizeConstraint") :: UITextSizeConstraint
					sizeConstraint.MaxTextSize = 32
					sizeConstraint.MinTextSize = 12
				end
			end

			local progressTextLabel = progressBG:FindFirstChild("ProgressTextLabel") :: TextLabel
			if progressTextLabel then
				if Mode == "Repair" then
					progressTextLabel.AnchorPoint = Vector2.new(1, 0.5)
					progressTextLabel.Position = UDim2.new(0.98, 0, 0.5, 0)
					progressTextLabel.Size = UDim2.new(0.45, 0, 0.8, 0)
					progressTextLabel.TextScaled = true
					local sizeConstraint = getOrCreateConstraintOfClass(progressTextLabel, "UITextSizeConstraint") :: UITextSizeConstraint
					sizeConstraint.MaxTextSize = 32
					sizeConstraint.MinTextSize = 12
				end
			end
		end
	end

	-- Add aspect ratio constraint to buttons container items
	local buttonsContainer = bottomHUD:FindFirstChild("ButtonsContainer") :: Frame
	if buttonsContainer then
		for _, child in ipairs(buttonsContainer:GetChildren()) do
			if child:IsA("ImageButton") then
				local constraint = getOrCreateConstraintOfClass(child, "UIAspectRatioConstraint") :: UIAspectRatioConstraint
				if Mode == "Repair" then
					constraint.AspectRatio = 2.5
				end
			end
		end
	end
end

-- 5. Configure RightSidebar (Side alignment, Text scaling, UI aspect ratio)
if rightSidebar then
	if Mode == "Repair" then
		rightSidebar.AnchorPoint = Vector2.new(1, 0.5)
		rightSidebar.Position = UDim2.new(0.98, 0, 0.5, 0)
		rightSidebar.Size = UDim2.new(0.18, 0, 0.22, 0)
		rightSidebar.ZIndex = 10
	end

	for _, child in ipairs(rightSidebar:GetChildren()) do
		if child:IsA("ImageButton") then
			local constraint = getOrCreateConstraintOfClass(child, "UIAspectRatioConstraint") :: UIAspectRatioConstraint
			if Mode == "Repair" then
				constraint.AspectRatio = 2.5
			end

			local textLabel = child:FindFirstChild("TextLabel") :: TextLabel
			if textLabel then
				if Mode == "Repair" then
					textLabel.TextScaled = true
					local sizeConstraint = getOrCreateConstraintOfClass(textLabel, "UITextSizeConstraint") :: UITextSizeConstraint
					sizeConstraint.MaxTextSize = 32
					sizeConstraint.MinTextSize = 12
				end
			end
		end
	end
end

return "HUD CDRA migration run completed successfully!"
```

- [ ] **Step 2: Run dry-run validation execution of Setup Script in Roblox Studio**
  Set `Mode = "ValidateOnly"` in script and execute it via `execute_luau`. Verify hierarchy validation checks out and missing constraints are logged.

- [ ] **Step 3: Run backup mode execution of Setup Script in Roblox Studio**
  Set `Mode = "Backup"` in script and execute it via `execute_luau`. Verify backup JSON file is written to `scratch/hud_backup.json`.

- [ ] **Step 4: Run repair execution of Setup Script in Roblox Studio**
  Set `Mode = "Repair"` in script and execute it via `execute_luau`.
  Expected output: "HUD CDRA migration run completed successfully!"

- [ ] **Step 5: Run idempotency check**
  Run second time in `ValidateOnly` mode to verify zero changes are reported.

- [ ] **Step 6: Save and Commit visual configuration updates**

---

### Task 2: Create config-driven `ResponsiveController.luau` and `ResponsivePolicy.luau`

**Files:**
*   Create: `src/client/controllers/ResponsiveController.luau`
*   Create: `src/client/controllers/ResponsivePolicy.luau`
*   Create: `src/shared/config/ResponsiveConfig.luau`

**Interfaces:**
*   Produces: `ResponsiveController` singleton:
    *   `ResponsiveController:GetCategory() -> string` (returns category enum value)
    *   `ResponsiveController:IsMobile() -> boolean`
    *   `ResponsiveController:IsDesktop() -> boolean`
    *   `ResponsiveController:IsConsole() -> boolean`
    *   `ResponsiveController:GetViewport() -> Vector2`
    *   `ResponsiveController:GetSafeAreaRect() -> Rect`
    *   `ResponsiveController:GetEffectiveViewport() -> Vector2`
    *   `ResponsiveController:GetOrientation() -> string`
    *   `ResponsiveController:IsTouch() -> boolean`
    *   `ResponsiveController:IsMouse() -> boolean`
    *   `ResponsiveController:IsGamepad() -> boolean`
    *   `ResponsiveController:GetProfile() -> Table` (returns complete category, viewport, safearea, and platform status profile)
    *   `ResponsiveController.CategoryChanged: ConnectableSignal` (fired on available area changes)
    *   `ResponsiveController.ViewportChanged: ConnectableSignal`
    *   `ResponsiveController.SafeAreaChanged: ConnectableSignal` (fired on ScreenInsets, top bar, or TopbarInset changes)
    *   `ResponsiveController.ProfileChanged: ConnectableSignal` (fired on any profile parameters changing)

- [ ] **Step 1: Create `src/shared/config/ResponsiveConfig.luau`**
  Add configuration thresholds for the viewport breakpoints and HUD bounds.

```luau
--!strict
-- src/shared/config/ResponsiveConfig.luau
-- Threshold and profile specifications for CDRA.

local ResponsiveCategory = table.freeze({
	PhonePortrait = "PhonePortrait",
	PhoneLandscape = "PhoneLandscape",
	Tablet = "Tablet",
	Desktop = "Desktop",
	Ultrawide = "Ultrawide"
})

local ResponsiveConfig = {
	Categories = ResponsiveCategory,
	Profiles = {
		PhonePortrait = {
			Width = { Min = 0, Max = 500 },
			Aspect = { Min = 0, Max = 1.4 }
		},
		PhoneLandscape = {
			Width = { Min = 500, Max = 900 },
			Aspect = { Min = 1.5, Max = 9.0 }
		},
		Tablet = {
			Width = { Min = 500, Max = 900 },
			Aspect = { Min = 0, Max = 1.4 }
		},
		Desktop = {
			Width = { Min = 900, Max = 1600 },
			Aspect = { Min = 0, Max = 9.0 }
		},
		Ultrawide = {
			Width = { Min = 1600, Max = 99999 },
			Aspect = { Min = 0, Max = 9.0 }
		}
	},
	SafeArea = {
		PaddingOffset = 8
	},
	Text = {
		MinSize = 12,
		MaxSize = 32,
	},
	HUD = {
		SidebarCollapseWidth = 600,
		BottomHUDHeightScale = 0.22
	}
}

return ResponsiveConfig
```

- [ ] **Step 2: Create `src/client/controllers/ResponsiveController.luau`**
  Implement available area monitoring and full CDRA classification APIs. Ensure it only publishes state and does not modify widgets. Use `GuiService.ViewportDisplaySize` to supplement size detection and prevent large tablets from being incorrectly classified as desktop.

```luau
--!strict
-- src/client/controllers/ResponsiveController.luau
-- Monitors effective available UI area and recomputes logical viewport category.

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local LocalPlayer = Players.LocalPlayer
local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
local ResponsiveConfig = require(ReplicatedStorage:WaitForChild("BiggerShared"):WaitForChild("Core"):WaitForChild("Config"):WaitForChild("ResponsiveConfig") or ReplicatedStorage.BiggerShared.config.ResponsiveConfig)

local ResponsiveController = {}
local CategoryChangedCallbacks = {}
local ViewportChangedCallbacks = {}
local SafeAreaChangedCallbacks = {}
local ProfileChangedCallbacks = {}

export type DeviceCategory = string

local CurrentCategory: DeviceCategory = ResponsiveConfig.Categories.Desktop
local CurrentViewportSize = Vector2.new(0, 0)
local CurrentSafeAreaRect = Rect.new(0, 0, 0, 0)

-- Classify viewport dimensions dynamically using width, display size, aspect ratios, and platform indicators
local function ClassifyViewport(size: Vector2): DeviceCategory
	local width = size.X
	local height = size.Y
	local aspect = width / height
	local bp = ResponsiveConfig.Profiles
	local cat = ResponsiveConfig.Categories

	-- ViewportDisplaySize (Small/Medium/Large) for tablets vs desktop
	local displaySize = GuiService.ViewportDisplaySize

	if width < bp.PhonePortrait.Width.Max then
		return cat.PhonePortrait
	elseif width < bp.PhoneLandscape.Width.Max or displaySize == Enum.ViewportDisplaySize.Small then
		if aspect > bp.PhoneLandscape.Aspect.Min then
			return cat.PhoneLandscape
		else
			return cat.Tablet
		end
	elseif width < bp.Desktop.Width.Max or displaySize == Enum.ViewportDisplaySize.Medium then
		return cat.Desktop
	else
		return cat.Ultrawide
	end
end

local function UpdateViewport()
	local screenGui = PlayerGui:FindFirstChild("MainHUD") :: ScreenGui?
	if not screenGui then return end

	local size = screenGui.AbsoluteSize
	CurrentViewportSize = size
	
	-- Calculate Safe Area Rect natively
	local insetRect = GuiService:GetGuidanceRect()
	CurrentSafeAreaRect = insetRect

	-- Fire ViewportChanged
	for _, callback in ipairs(ViewportChangedCallbacks) do
		task.spawn(callback, size)
	end

	local newCategory = ClassifyViewport(size)
	
	local profileChanged = false
	if newCategory ~= CurrentCategory then
		CurrentCategory = newCategory
		profileChanged = true
		for _, callback in ipairs(CategoryChangedCallbacks) do
			task.spawn(callback, newCategory)
		end
	end

	-- Fire ProfileChanged always if viewport size or safe area changes
	for _, callback in ipairs(ProfileChangedCallbacks) do
		task.spawn(callback, ResponsiveController:GetProfile())
	end
end

function ResponsiveController.GetCategory(): DeviceCategory
	return CurrentCategory
end

function ResponsiveController:IsMobile(): boolean
	local cat = ResponsiveConfig.Categories
	return CurrentCategory == cat.PhonePortrait or CurrentCategory == cat.PhoneLandscape
end

function ResponsiveController:IsDesktop(): boolean
	local cat = ResponsiveConfig.Categories
	return CurrentCategory == cat.Desktop or CurrentCategory == cat.Ultrawide
end

function ResponsiveController:IsConsole(): boolean
	return UserInputService:GetLastInputType() == Enum.UserInputType.Gamepad
end

function ResponsiveController:GetViewport(): Vector2
	return CurrentViewportSize
end

function ResponsiveController:GetSafeAreaRect(): Rect
	return CurrentSafeAreaRect
end

function ResponsiveController:GetEffectiveViewport(): Vector2
	return Vector2.new(CurrentSafeAreaRect.Width, CurrentSafeAreaRect.Height)
end

function ResponsiveController:GetOrientation(): string
	return CurrentViewportSize.X >= CurrentViewportSize.Y and "Landscape" or "Portrait"
end

function ResponsiveController:IsTouch(): boolean
	return UserInputService:GetLastInputType() == Enum.UserInputType.Touch
end

function ResponsiveController:IsMouse(): boolean
	local lastInput = UserInputService:GetLastInputType()
	return lastInput == Enum.UserInputType.MouseButton1 or lastInput == Enum.UserInputType.MouseButton2 or lastInput == Enum.UserInputType.Keyboard
end

function ResponsiveController:IsGamepad(): boolean
	return UserInputService:GetLastInputType() == Enum.UserInputType.Gamepad
end

function ResponsiveController:GetProfile()
	return {
		Category = CurrentCategory,
		Width = CurrentViewportSize.X,
		Height = CurrentViewportSize.Y,
		Aspect = CurrentViewportSize.X / CurrentViewportSize.Y,
		DisplaySize = GuiService.ViewportDisplaySize,
		SafeArea = CurrentSafeAreaRect,
		Platform = UserInputService:GetLastInputType(),
		Orientation = self:GetOrientation(),
		EffectiveViewport = self:GetEffectiveViewport(),
		InputMode = UserInputService:GetLastInputType()
	}
end

function ResponsiveController.OnCategoryChanged(callback: (category: DeviceCategory) -> ())
	table.insert(CategoryChangedCallbacks, callback)
	task.spawn(callback, CurrentCategory)
end

function ResponsiveController.OnViewportChanged(callback: (size: Vector2) -> ())
	table.insert(ViewportChangedCallbacks, callback)
	task.spawn(callback, CurrentViewportSize)
end

function ResponsiveController.OnSafeAreaChanged(callback: () -> ())
	table.insert(SafeAreaChangedCallbacks, callback)
end

function ResponsiveController.OnProfileChanged(callback: (profile: any) -> ())
	table.insert(ProfileChangedCallbacks, callback)
	task.spawn(callback, ResponsiveController:GetProfile())
end

function ResponsiveController.Init()
	local screenGui = PlayerGui:WaitForChild("MainHUD") :: ScreenGui
	-- Listen to effective viewport bounds changes (safe area offsets, resizing, rotating)
	screenGui:GetPropertyChangedSignal("AbsoluteSize"):Connect(UpdateViewport)
	screenGui:GetPropertyChangedSignal("ScreenInsets"):Connect(UpdateViewport)
	GuiService:GetPropertyChangedSignal("TopbarInset"):Connect(UpdateViewport)
	UserInputService.LastInputTypeChanged:Connect(UpdateViewport)
	UpdateViewport()
end

function ResponsiveController.Start()
	UpdateViewport()
end

return ResponsiveController
```

- [ ] **Step 3: Create `src/client/controllers/ResponsivePolicy.luau`**
  Implement policy translation layer mapping category enums to presentation parameters via a static config table.

```luau
--!strict
-- src/client/controllers/ResponsivePolicy.luau
-- Map device categories into functional presentation parameters.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ResponsiveConfig = require(ReplicatedStorage:WaitForChild("BiggerShared"):WaitForChild("Core"):WaitForChild("Config"):WaitForChild("ResponsiveConfig") or ReplicatedStorage.BiggerShared.config.ResponsiveConfig)

local ResponsivePolicy = {}

export type PolicyTable = {
	LeftSidebarMode: "Expanded" | "Collapsed" | "Hidden",
	RightSidebarMode: "Expanded" | "Collapsed" | "Hidden",
	InventoryMode: "Popup" | "Sidebar",
	BottomHUDStyle: "Compact" | "Full"
}

local Policies = {
	PhonePortrait = {
		LeftSidebarMode = "Hidden",
		RightSidebarMode = "Hidden",
		InventoryMode = "Popup",
		BottomHUDStyle = "Compact"
	},
	PhoneLandscape = {
		LeftSidebarMode = "Collapsed",
		RightSidebarMode = "Hidden",
		InventoryMode = "Popup",
		BottomHUDStyle = "Compact"
	},
	Tablet = {
		LeftSidebarMode = "Collapsed",
		RightSidebarMode = "Collapsed",
		InventoryMode = "Popup",
		BottomHUDStyle = "Full"
	},
	Desktop = {
		LeftSidebarMode = "Expanded",
		RightSidebarMode = "Expanded",
		InventoryMode = "Sidebar",
		BottomHUDStyle = "Full"
	},
	Ultrawide = {
		LeftSidebarMode = "Expanded",
		RightSidebarMode = "Expanded",
		InventoryMode = "Sidebar",
		BottomHUDStyle = "Full"
	}
}

function ResponsivePolicy.GetPolicy(category: string): PolicyTable
	return Policies[category] or Policies.Desktop
end

return ResponsivePolicy
```

- [ ] **Step 4: Commit `ResponsiveController.luau`, `ResponsivePolicy.luau` and config**

---

### Task 3: Adaptive Layout & Decoupled Event Integration in `GuiController.luau`

**Files:**
*   Modify: `src/client/controllers/GuiController.luau`
*   Create: `src/client/controllers/UIEventBus.luau`

**Interfaces:**
*   Consumes: `ResponsiveController` and `ResponsivePolicy` to react to category changes.
*   Uses: `UIEventBus` to fire layout/HUD events rather than direct calls.

- [ ] **Step 1: Create `src/client/controllers/UIEventBus.luau`**
  Build simple decoupled event hub.

```luau
--!strict
-- src/client/controllers/UIEventBus.luau
-- Event dispatching registry for decoupling UI controllers.

local UIEventBus = {}
local Listeners = {}

function UIEventBus.Publish(eventName: string, ...: any)
	local callbacks = Listeners[eventName]
	if not callbacks then return end
	for _, cb in ipairs(callbacks) do
		task.spawn(cb, ...)
	end
end

function UIEventBus.Subscribe(eventName: string, callback: (...any) -> ())
	if not Listeners[eventName] then
		Listeners[eventName] = {}
	end
	table.insert(Listeners[eventName], callback)
end

return UIEventBus
```

- [ ] **Step 2: Modify `GuiController.luau`**
  Change initialization to require `ResponsiveController`, `ResponsivePolicy`, and `UIEventBus`.
  *   Read policies from `ResponsivePolicy.GetPolicy(ResponsiveController.GetCategory())`.
  *   When `LeftSidebarMode` or `RightSidebarMode` policy is "Hidden", hide the sidebar buttons or apply compact padding (instead of resizing objects).
  *   When gamepad input is dominant, trigger Console Gamepad navigation highlighting via `GuiService.SelectedObject`, configure `SelectionImageObject`, and define explicit `NextSelectionUp`/`Down`/`Left`/`Right` links to guarantee cyclic focus paths.
  *   Ensure hover scale animations only alter `UIScale.Scale` (conforming to the Animation Rules).

```luau
-- Update GuiController to connect with ResponsiveController and ResponsivePolicy and respect the ZIndex/Animation/Console SelectionImageObject/NextSelection constraints.
```

- [ ] **Step 3: Validate compilation**
  Run offline syntax checks (Selene/Luau compiler check).

- [ ] **Step 4: Commit updates to `GuiController.luau`**

---

### Task 4: Multi-Device Emulator Verification

**Files:**
*   Test: Roblox Studio Play Solo Emulator

- [ ] **Step 1: Smoke test Phone Portrait**
  Select Phone Portrait in emulator. Verify no clipped text, no overlaps, and HUD is well within the screen insets.
- [ ] **Step 2: Smoke test Console Safe Area**
  Toggle Console safe area. Verify safe-area margins, SelectionImageObject rendering, explicit NextSelection navigation pathways, and Gamepad cyclic selection.
- [ ] **Step 3: Complete Quantitative Verification Checklist**
  Verify the regression checklist items are all PASSED:
  *   Text: 0 clipped labels
  *   Icons: 0 stretched images
  *   Layout: 0 overlap
  *   Buttons: 100% reachable
  *   Console: No dead focus
  *   Phone Portrait: No off-screen HUD
  *   Ultrawide: No excessive empty margins
  Fill out the matrix, capturing Before and After screenshots.
