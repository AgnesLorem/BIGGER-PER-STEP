--!strict
---/// Content \\\---

-- Purpose: central client controller managing viewport, safe area, and input mode state.
-- Use when:
-- - Querying screen dimensions, logical categories (e.g. Desktop, PhonePortrait), or safe area boundaries.
-- - Subscribing to layout or safe area changes.
-- Avoid when:
-- - Setting up static UI breakpoints or layout profile data (use ResponsiveConfig/ResponsivePolicy instead).
-- Public API:
-- - ResponsiveController.Init()
-- - ResponsiveController.Start()
-- - ResponsiveController.Destroy()
-- - :GetCategory() -> Category
-- - :GetProfile() -> ViewportProfile
-- - :GetSafeAreaRect() -> Rect
-- - :GetEffectiveViewport() -> Vector2
-- Related:
-- - src/shared/Core/Config/ResponsiveConfig.luau
-- - src/client/controllers/ResponsivePolicy.luau

--// Raw Requirings \\--
local GuiService = game:GetService("GuiService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

--// Requirings \\--
local ResponsiveConfig = require(ReplicatedStorage:WaitForChild("BiggerShared"):WaitForChild("Core"):WaitForChild("Config"):WaitForChild("ResponsiveConfig"))

--// Types \\--
type Category = ResponsiveConfig.Category

export type ViewportProfile = {
	Category: Category,
	Width: number,
	Height: number,
	Aspect: number,
	DisplaySize: Enum.DisplaySize,
	SafeArea: Rect,
	Platform: Enum.UserInputType,
	Orientation: "Portrait" | "Landscape",
	EffectiveViewport: Vector2,
	InputMode: Enum.UserInputType,
	Accessibility: {
		ReducedMotion: boolean,
		HighContrast: boolean,
		LargeText: boolean,
		ScreenReader: boolean,
		PreferredTransparency: number,
	},
}

type Callback = (...any) -> ()
export type SignalConnection = {
	Disconnect: (self: SignalConnection) -> ()
}

type Signal = {
	Connect: (self: Signal, callback: Callback) -> SignalConnection,
	Fire: (self: Signal, ...any) -> (),
	Clear: (self: Signal) -> (),
}

--// Variables \\--
local ResponsiveController = {}
local CachedProfile: ViewportProfile? = nil

-- Connections
local CameraConnection: RBXScriptConnection? = nil
local CurrentCamera: Camera? = nil
local InputConnection: RBXScriptConnection? = nil
local GuiConnections: { RBXScriptConnection } = {}

--// Helpers \\--
local function CreateSignal(): Signal
	local callbacks: { Callback } = {}
	local signalObj = {} :: Signal

	function signalObj:Connect(callback: Callback): SignalConnection
		table.insert(callbacks, callback)
		local conn = {} :: SignalConnection
		function conn:Disconnect()
			local idx = table.find(callbacks, callback)
			if idx then
				table.remove(callbacks, idx)
			end
		end
		return conn
	end

	function signalObj:Fire(...: any)
		local args = { ... }
		for _, callback in ipairs(callbacks) do
			task.spawn(function()
				callback(unpack(args))
			end)
		end
	end

	function signalObj:Clear()
		table.clear(callbacks)
	end

	return signalObj
end

-- Define signals
ResponsiveController.CategoryChanged = CreateSignal()
ResponsiveController.ViewportChanged = CreateSignal()
ResponsiveController.SafeAreaChanged = CreateSignal()
ResponsiveController.ProfileChanged = CreateSignal()

local function Classify(viewport: Vector2, displaySize: Enum.ViewportDisplaySize, inputMode: Enum.UserInputType): Category
	local width = viewport.X
	local height = viewport.Y
	local aspect = width / height
	local isPortrait = height > width

	if isPortrait then
		if width <= ResponsiveConfig.Breakpoints.PhonePortraitMaxWidth then
			return "PhonePortrait"
		else
			return "Tablet"
		end
	else
		-- Landscape
		if width >= ResponsiveConfig.Breakpoints.UltrawideMinWidth then
			return "Ultrawide"
		elseif width >= ResponsiveConfig.Breakpoints.DesktopMinWidth then
			return "Desktop"
		elseif width <= ResponsiveConfig.Breakpoints.TabletMaxWidth then
			-- It's phone landscape or tablet
			if width <= 650 or aspect > 1.8 then
				return "PhoneLandscape"
			else
				return "Tablet"
			end
		else
			-- Between 900 and 1200
			if displaySize == Enum.ViewportDisplaySize.Large then
				return "Desktop"
			elseif UserInputService.TouchEnabled then
				return "Tablet"
			else
				return "Desktop"
			end
		end
	end
end

local function GetAccessibilitySettings()
	local reducedMotion = false
	local preferredTransparency = 0.0

	pcall(function()
		reducedMotion = GuiService.ReducedMotionEnabled
	end)
	pcall(function()
		preferredTransparency = GuiService.PreferredTransparency
	end)

	return {
		ReducedMotion = reducedMotion,
		HighContrast = false,
		LargeText = false,
		ScreenReader = false,
		PreferredTransparency = preferredTransparency,
	}
end

-- Recomputes and updates the profile snapshot. Fires changed signals.
local function UpdateProfile()
	local camera = CurrentCamera or Workspace.CurrentCamera
	if not camera then return end

	local viewport = camera.ViewportSize
	if viewport.X <= 1 or viewport.Y <= 1 then return end

	local displaySize = Enum.DisplaySize.Large
	pcall(function()
		displaySize = GuiService.ViewportDisplaySize
	end)

	local lastInput = UserInputService:GetLastInputType()

	local category = Classify(viewport, displaySize, lastInput)
	local orientation = (viewport.Y > viewport.X) and "Portrait" or "Landscape"

	-- Get Inset Safe Area
	local ok, safeArea = pcall(function()
		return GuiService:GetInsetArea()
	end)
	if not ok or not safeArea then
		safeArea = Rect.new(0, 0, viewport.X, viewport.Y)
	end

	local effectiveViewport = safeArea.Max - safeArea.Min
	local accessibility = GetAccessibilitySettings()

	local newProfile: ViewportProfile = {
		Category = category,
		Width = viewport.X,
		Height = viewport.Y,
		Aspect = viewport.X / viewport.Y,
		DisplaySize = displaySize,
		SafeArea = safeArea,
		Platform = lastInput,
		Orientation = orientation :: any,
		EffectiveViewport = effectiveViewport,
		InputMode = lastInput,
		Accessibility = accessibility,
	}

	local oldProfile = CachedProfile
	CachedProfile = table.freeze(newProfile)

	-- Fire signals based on what changed
	if oldProfile then
		local viewportChanged = oldProfile.Width ~= newProfile.Width or oldProfile.Height ~= newProfile.Height
		local safeAreaChanged = oldProfile.SafeArea.Min ~= newProfile.SafeArea.Min or oldProfile.SafeArea.Max ~= newProfile.SafeArea.Max
		local categoryChanged = oldProfile.Category ~= newProfile.Category

		if categoryChanged then
			ResponsiveController.CategoryChanged:Fire(category)
		end
		if viewportChanged then
			ResponsiveController.ViewportChanged:Fire(viewport)
		end
		if safeAreaChanged then
			ResponsiveController.SafeAreaChanged:Fire(safeArea)
		end

		-- ProfileChanged fires if ANY profile field changed
		if categoryChanged or viewportChanged or safeAreaChanged or
			oldProfile.InputMode ~= newProfile.InputMode or
			oldProfile.Accessibility.ReducedMotion ~= newProfile.Accessibility.ReducedMotion or
			oldProfile.Accessibility.PreferredTransparency ~= newProfile.Accessibility.PreferredTransparency then
			ResponsiveController.ProfileChanged:Fire(CachedProfile)
		end
	else
		-- First time initialization fires all signals
		ResponsiveController.CategoryChanged:Fire(category)
		ResponsiveController.ViewportChanged:Fire(viewport)
		ResponsiveController.SafeAreaChanged:Fire(safeArea)
		ResponsiveController.ProfileChanged:Fire(CachedProfile)
	end
end

local function ConnectCamera(camera: Camera)
	if CameraConnection then
		CameraConnection:Disconnect()
		CameraConnection = nil
	end
	CurrentCamera = camera
	CameraConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(UpdateProfile)
	UpdateProfile()
end

--// Service \\--
function ResponsiveController.Init()
	-- Connect to Workspace camera changes
	Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(function()
		if Workspace.CurrentCamera then
			ConnectCamera(Workspace.CurrentCamera)
		end
	end)

	if Workspace.CurrentCamera then
		ConnectCamera(Workspace.CurrentCamera)
	end

	-- Connect input observers
	InputConnection = UserInputService.LastInputTypeChanged:Connect(function(_lastInputType)
		UpdateProfile()
	end)

	-- Connect safe area related settings in GuiService
	local ok1, sig1 = pcall(function() return GuiService:GetPropertyChangedSignal("TopbarInset") end)
	if ok1 and sig1 then
		table.insert(GuiConnections, sig1:Connect(UpdateProfile))
	end

	local ok2, sig2 = pcall(function() return GuiService:GetPropertyChangedSignal("ReducedMotionEnabled") end)
	if ok2 and sig2 then
		table.insert(GuiConnections, sig2:Connect(UpdateProfile))
	end
end

function ResponsiveController.Start()
	UpdateProfile()
end

function ResponsiveController.Destroy()
	if CameraConnection then
		CameraConnection:Disconnect()
		CameraConnection = nil
	end
	if InputConnection then
		InputConnection:Disconnect()
		InputConnection = nil
	end
	for _, conn in ipairs(GuiConnections) do
		conn:Disconnect()
	end
	table.clear(GuiConnections)

	ResponsiveController.CategoryChanged:Clear()
	ResponsiveController.ViewportChanged:Clear()
	ResponsiveController.SafeAreaChanged:Clear()
	ResponsiveController.ProfileChanged:Clear()

	CachedProfile = nil
end

function ResponsiveController:GetCategory(): Category
	return CachedProfile and CachedProfile.Category or "Desktop"
end

function ResponsiveController:IsMobile(): boolean
	local cat = self:GetCategory()
	return cat == "PhonePortrait" or cat == "PhoneLandscape"
end

function ResponsiveController:IsDesktop(): boolean
	local cat = self:GetCategory()
	return cat == "Desktop" or cat == "Ultrawide"
end

function ResponsiveController:IsConsole(): boolean
	local profile = self:GetProfile()
	return profile.InputMode == Enum.UserInputType.Gamepad1 or
		profile.InputMode == Enum.UserInputType.Gamepad2 or
		profile.InputMode == Enum.UserInputType.Gamepad3 or
		profile.InputMode == Enum.UserInputType.Gamepad4
end

function ResponsiveController:GetViewport(): Vector2
	return CachedProfile and Vector2.new(CachedProfile.Width, CachedProfile.Height) or Vector2.new(1920, 1080)
end

function ResponsiveController:GetSafeAreaRect(): Rect
	return CachedProfile and CachedProfile.SafeArea or Rect.new(0, 0, 1920, 1080)
end

function ResponsiveController:GetEffectiveViewport(): Vector2
	return CachedProfile and CachedProfile.EffectiveViewport or Vector2.new(1920, 1080)
end

function ResponsiveController:GetOrientation(): "Portrait" | "Landscape"
	return CachedProfile and CachedProfile.Orientation or "Landscape"
end

function ResponsiveController:IsTouch(): boolean
	local profile = self:GetProfile()
	return profile.InputMode == Enum.UserInputType.Touch
end

function ResponsiveController:IsMouse(): boolean
	local profile = self:GetProfile()
	return profile.InputMode == Enum.UserInputType.MouseButton1 or
		profile.InputMode == Enum.UserInputType.MouseButton2 or
		profile.InputMode == Enum.UserInputType.MouseMovement
end

function ResponsiveController:IsGamepad(): boolean
	return self:IsConsole()
end

function ResponsiveController:GetProfile(): ViewportProfile
	if not CachedProfile then
		-- Fallback profile for early reads before Init/Start
		local fallback: ViewportProfile = {
			Category = "Desktop",
			Width = 1920,
			Height = 1080,
			Aspect = 1920 / 1080,
			DisplaySize = Enum.DisplaySize.Large,
			SafeArea = Rect.new(0, 0, 1920, 1080),
			Platform = Enum.UserInputType.None,
			Orientation = "Landscape",
			EffectiveViewport = Vector2.new(1920, 1080),
			InputMode = Enum.UserInputType.None,
			Accessibility = {
				ReducedMotion = false,
				HighContrast = false,
				LargeText = false,
				ScreenReader = false,
				PreferredTransparency = 0.0,
			},
		}
		return table.freeze(fallback)
	end
	return CachedProfile
end

return table.freeze(ResponsiveController)
