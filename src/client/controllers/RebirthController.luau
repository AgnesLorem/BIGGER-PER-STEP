--!strict
-- RebirthController.luau
-- Client controller for the Rebirth panel (Pure Renderer).
-- Displays authoritative Server Rebirth state sent via UpdateRebirth remote.
-- Does NOT calculate gameplay values. Only binds gameplay logic to the approved UI freeze layout.

--// Raw Requirings \\--
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

--// Requirings \\--
local UIEventBus = require(script.Parent:WaitForChild("UIEventBus"))
local ResponsiveController = require(script.Parent:WaitForChild("ResponsiveController"))
local ResponsiveConfig = require(
	ReplicatedStorage:WaitForChild("BiggerShared")
		:WaitForChild("Core")
		:WaitForChild("Config")
		:WaitForChild("ResponsiveConfig")
)
local RebirthTypes = require(
	ReplicatedStorage:WaitForChild("BiggerShared")
		:WaitForChild("Core")
		:WaitForChild("Types")
		:WaitForChild("RebirthTypes")
)

--// Types \\--
type RebirthTierSnapshot = RebirthTypes.RebirthTierSnapshot
type RebirthUpdate = RebirthTypes.RebirthUpdate

--// Variables \\--
local LocalPlayer = Players.LocalPlayer

local RebirthController = {}

-- GUI References
local ScreenGui: ScreenGui
local OverlayHUD: Frame
local Panel: Frame
local CloseButton: GuiButton?
local RequirementLabel: TextLabel?
local ProgressLabel: TextLabel?
local BarFill: Frame?
local CurrentStat: TextLabel?
local NextStat: TextLabel?
local RebirthButton: GuiButton?
local RebirthButtonText: TextLabel?
local SkipRebirthButton: GuiButton?
local SkipRebirthButtonText: TextLabel?

-- Remote References
local RequestRebirthRemote: RemoteEvent? = nil
local RequestSkipRebirthRemote: RemoteEvent? = nil
local UpdateRebirthRemote: RemoteEvent? = nil

-- State
local IsOpen = false
local CachedState: RebirthUpdate?
local Connections: { RBXScriptConnection | { Disconnect: () -> () } } = {}

--// Helpers \\--

local function EnsureRemote(name: string): RemoteEvent?
	local remotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if not remotesFolder then
		return nil
	end
	local remote = remotesFolder:FindFirstChild(name)
	if remote and remote:IsA("RemoteEvent") then
		return remote
	end
	return nil
end

local function AttachBounce(button: GuiButton?)
	if not button then
		return
	end
	local uiScale = button:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Parent = button
	end

	local pressTween = TweenService:Create(
		uiScale,
		TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Scale = 0.95 }
	)
	local releaseTween = TweenService:Create(
		uiScale,
		TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1.0 }
	)

	table.insert(
		Connections,
		button.InputBegan:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				pressTween:Play()
			end
		end)
	)
	table.insert(
		Connections,
		button.InputEnded:Connect(function(input)
			if
				input.UserInputType == Enum.UserInputType.MouseButton1
				or input.UserInputType == Enum.UserInputType.Touch
			then
				releaseTween:Play()
			end
		end)
	)
end

local function Render(State: RebirthUpdate)
	CachedState = State

	if not Panel then
		return
	end

	-- Requirement / Warning label
	if RequirementLabel then
		RequirementLabel.Text = "Rebirth resets your LEVEL!"
	end

	-- Progress bar text and fill
	if ProgressLabel then
		ProgressLabel.Text = "Lv" .. tostring(State.CurrentLevel) .. " / " .. tostring(State.RequiredLevel)
	end

	if BarFill then
		local ratio = if State.RequiredLevel > 0 then math.clamp(State.CurrentLevel / State.RequiredLevel, 0, 1) else 0
		BarFill.Size = UDim2.fromScale(math.max(ratio, 0.03), 1)
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
		RebirthButton.Active = true
		if RebirthButtonText then
			RebirthButtonText.Text = "Rebirth"
			RebirthButtonText.TextColor3 = if State.CanRebirth
				then Color3.fromRGB(255, 255, 255)
				else Color3.fromRGB(180, 180, 180)
		end
		local btnImg = RebirthButton:FindFirstChild("BtnImg") :: ImageLabel?
		if btnImg then
			btnImg.ImageColor3 = if State.CanRebirth then Color3.new(1, 1, 1) else Color3.fromRGB(150, 150, 150)
		elseif RebirthButton:IsA("ImageButton") then
			(RebirthButton :: ImageButton).ImageColor3 = if State.CanRebirth
				then Color3.new(1, 1, 1)
				else Color3.fromRGB(150, 150, 150)
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
	if not RequestRebirthRemote then
		RequestRebirthRemote = EnsureRemote("RequestRebirth")
	end
	if RequestRebirthRemote then
		pcall(function()
			RequestRebirthRemote:FireServer("Refresh")
		end)
	end

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
			if child:IsA("GuiObject") and child.Name ~= "ModalBackdrop" and child.Visible then
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
	ScreenGui = PlayerGui:WaitForChild("MainHUD", 10) :: ScreenGui

	-- Remotes
	local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes", 5)
	if RemotesFolder then
		RequestRebirthRemote = EnsureRemote("RequestRebirth")
		RequestSkipRebirthRemote = EnsureRemote("RequestSkipRebirth")
		UpdateRebirthRemote = EnsureRemote("UpdateRebirth")
	end

	-- Panel references under OverlayHUD
	local SafeAreaRoot = ScreenGui:WaitForChild("SafeAreaRoot")
	OverlayHUD = SafeAreaRoot:WaitForChild("OverlayHUD", 5) :: Frame
	if OverlayHUD then
		OverlayHUD.Visible = false
		Panel = OverlayHUD:WaitForChild("RebirthPanel", 5) :: Frame
		if Panel then
			Panel.Visible = false
			CloseButton = Panel:FindFirstChild("CloseButton", true) :: GuiButton?
			RequirementLabel = Panel:FindFirstChild("RequirementLabel", true) :: TextLabel?

			ProgressLabel = Panel:FindFirstChild("ProgressLabel", true) :: TextLabel?
			BarFill = Panel:FindFirstChild("BarFill", true) :: Frame?

			local CurrentCard = Panel:FindFirstChild("CurrentCard", true) :: Instance?
			CurrentStat = CurrentCard and CurrentCard:FindFirstChild("Stat", true) :: TextLabel?

			local NextCard = Panel:FindFirstChild("NextCard", true) :: Instance?
			NextStat = NextCard and NextCard:FindFirstChild("Stat", true) :: TextLabel?

			RebirthButton = Panel:FindFirstChild("RebirthButton", true) :: GuiButton?
			RebirthButtonText = RebirthButton and RebirthButton:FindFirstChild("ButtonText", true) :: TextLabel?

			SkipRebirthButton = Panel:FindFirstChild("SkipRebirthButton", true) :: GuiButton?
			SkipRebirthButtonText = SkipRebirthButton
				and SkipRebirthButton:FindFirstChild("ButtonText", true) :: TextLabel?
		end
	end
end

local function ApplyResponsiveProfile(profile: any)
	if not Panel then
		return
	end
	local category = if profile and profile.Category then profile.Category else "Desktop"
	local policy = ResponsiveConfig.Policies[category] or ResponsiveConfig.Policies.Desktop
	local widthScale = policy.PopupWidthScale or 0.54
	Panel.Size = UDim2.fromScale(widthScale, 0.72)
end

function RebirthController.Start()
	-- Remotes ensure
	if not UpdateRebirthRemote then
		local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes", 5)
		if RemotesFolder then
			UpdateRebirthRemote = RemotesFolder:WaitForChild("UpdateRebirth", 5) :: RemoteEvent?
			RequestRebirthRemote = RemotesFolder:WaitForChild("RequestRebirth", 5) :: RemoteEvent?
			RequestSkipRebirthRemote = RemotesFolder:WaitForChild("RequestSkipRebirth", 5) :: RemoteEvent?
		end
	end

	-- Listen for server-pushed state updates
	if UpdateRebirthRemote then
		table.insert(
			Connections,
			UpdateRebirthRemote.OnClientEvent:Connect(function(State: RebirthUpdate)
				CachedState = State
				if IsOpen then
					Render(State)
				end
			end)
		)
	end

	-- Subscribe to UIEventBus for sidebar button clicks
	local eventConn = UIEventBus.Subscribe("SidebarButtonClicked", function(buttonName: any)
		if buttonName == "Rebirth" then
			RebirthController.Toggle()
		end
	end)
	table.insert(Connections, eventConn)

	-- Attach bounce micro-interactions
	AttachBounce(RebirthButton)
	AttachBounce(SkipRebirthButton)
	AttachBounce(CloseButton)

	-- RebirthButton click
	if RebirthButton then
		table.insert(
			Connections,
			RebirthButton.Activated:Connect(function()
				if not RequestRebirthRemote then
					RequestRebirthRemote = EnsureRemote("RequestRebirth")
				end
				if RequestRebirthRemote then
					pcall(function()
						RequestRebirthRemote:FireServer()
					end)
				end
			end)
		)
	end

	-- SkipRebirthButton click
	if SkipRebirthButton then
		table.insert(
			Connections,
			SkipRebirthButton.Activated:Connect(function()
				if not RequestSkipRebirthRemote then
					RequestSkipRebirthRemote = EnsureRemote("RequestSkipRebirth")
				end
				if RequestSkipRebirthRemote then
					pcall(function()
						RequestSkipRebirthRemote:FireServer()
					end)
				end
			end)
		)
	end

	-- CloseButton click
	if CloseButton then
		table.insert(
			Connections,
			CloseButton.Activated:Connect(function()
				RebirthController.Close()
			end)
		)
		if CloseButton:IsA("ImageButton") or CloseButton:IsA("TextButton") then
			table.insert(
				Connections,
				CloseButton.MouseButton1Click:Connect(function()
					RebirthController.Close()
				end)
			)
		end
	end

	-- Connect to responsive profile changes
	table.insert(
		Connections,
		ResponsiveController.ProfileChanged:Connect(function(profile)
			ApplyResponsiveProfile(profile)
		end)
	)
	ApplyResponsiveProfile(ResponsiveController:GetProfile())

	-- Initial render if we already have state
	if CachedState and IsOpen then
		Render(CachedState)
	end
	-- Request fresh update from the server
	if RequestRebirthRemote then
		pcall(function()
			RequestRebirthRemote:FireServer("Refresh")
		end)
	end
end

function RebirthController.Destroy()
	for _, Connection in Connections do
		if typeof(Connection) == "RBXScriptConnection" then
			(Connection :: RBXScriptConnection):Disconnect()
		elseif typeof(Connection) == "table" and typeof(Connection.Disconnect) == "function" then
			Connection.Disconnect()
		end
	end
	table.clear(Connections)
end

return RebirthController
