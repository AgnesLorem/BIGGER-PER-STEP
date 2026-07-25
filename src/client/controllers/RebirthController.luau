--!strict
-- RebirthController.luau
-- Client controller for the Rebirth panel: wires buttons, listens for UpdateRebirth, renders UI.
-- Does NOT calculate gameplay values. Only binds gameplay logic to the existing UI.

--// Raw Requirings \\--
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

--// Requirings \\--
local FormatNumber = require(
	ReplicatedStorage:WaitForChild("BiggerShared")
		:WaitForChild("Core")
		:WaitForChild("Utilities")
		:WaitForChild("FormatNumber")
)

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
	GrowthMultiplier: number,
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
local Panel: Frame
local CloseButton: TextButton
local BarBG: Frame
local BarFill: Frame
local CurrentSizeLabel: TextLabel
local RequiredSizeLabel: TextLabel
local MultiplierPreviewLabel: TextLabel
local RebirthCountLabel: TextLabel
local RebirthButton: TextButton
local SkipRebirthButton: TextButton
local LeftArrow: GuiButton
local RightArrow: GuiButton

-- Remote References
local RequestRebirthRemote: RemoteEvent
local RequestSkipRebirthRemote: RemoteEvent
local UpdateRebirthRemote: RemoteEvent

-- State
local PreviewIndex: number = 0
local IsOpen = false
local CachedState: RebirthUpdate?
local PanelRegistry: {
	Connections: { RBXScriptConnection },
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
		Connection:Disconnect()
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

local TWEEN_INFO = TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local function RenderTier(Tier: RebirthTierSnapshot?)
	if not CurrentSizeLabel or not RequiredSizeLabel or not MultiplierPreviewLabel then
		return
	end
	if not Tier then
		if CachedState then
			CurrentSizeLabel.Text = FormatNumber(CachedState.CurrentSize)
			RequiredSizeLabel.Text = FormatNumber(CachedState.RequiredSize)
			MultiplierPreviewLabel.Text = "Current: " .. tostring(CachedState.GrowthMultiplier) .. "X"
		end
		return
	end
	if CachedState then
		CurrentSizeLabel.Text = "→ " .. FormatNumber(CachedState.CurrentSize)
	end
	RequiredSizeLabel.Text = "Next: " .. FormatNumber(Tier.RequiredSize)
	MultiplierPreviewLabel.Text = tostring(Tier.GrowthMultiplier) .. "X"
end

local function Render(State: RebirthUpdate)
	CachedState = State
	PreviewIndex = 0

	if not Panel then
		return
	end

	-- Rebirth count
	if RebirthCountLabel then
		RebirthCountLabel.Text = "Rebirths: " .. tostring(State.Rebirths)
	end

	-- Multiplier bar fill
	if BarFill and BarBG then
		local Ratio: number
		if State.CanRebirth then
			Ratio = 1
		else
			Ratio = math.clamp(if State.RequiredSize > 0 then State.CurrentSize / State.RequiredSize else 0, 0, 1)
		end
		TweenService:Create(BarFill, TWEEN_INFO, {
			Size = UDim2.fromScale(Ratio, 1),
		}):Play()
	end

	-- Button state
	if RebirthButton then
		RebirthButton.Active = State.CanRebirth
	end

	-- Render current tier (no preview offset)
	RenderTier(nil)
end

local function Open()
	if not Panel or IsOpen then
		return
	end
	IsOpen = true
	Panel.Visible = true
	Panel.Size = UDim2.fromOffset(0, 0)
	TweenService:Create(Panel, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.fromScale(0.55, 0.55),
	}):Play()

	if CachedState then
		Render(CachedState)
	end
end

local function Close()
	if not Panel or not IsOpen then
		return
	end
	IsOpen = false

	local CloseTween = TweenService:Create(
		Panel,
		TweenInfo.new(0.15, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Size = UDim2.new(0, 0, 0, 0) }
	)
	CloseTween:Play()
	CloseTween.Completed:Connect(function()
		if not IsOpen then
			Panel.Visible = false
		end
	end)
end

--// Initialization \\--
function RebirthController.Init()
	local PlayerGui = LocalPlayer:WaitForChild("PlayerGui")
	ScreenGui = PlayerGui:WaitForChild("MainHUD") :: ScreenGui

	-- Remotes (idempotent — reference existing ones)
	local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes")
	RequestRebirthRemote = RemotesFolder:WaitForChild("RequestRebirth") :: RemoteEvent
	RequestSkipRebirthRemote = RemotesFolder:WaitForChild("RequestSkipRebirth") :: RemoteEvent
	UpdateRebirthRemote = RemotesFolder:WaitForChild("UpdateRebirth") :: RemoteEvent

	-- Panel references under OverlayHUD
	local OverlayHUD = ScreenGui:WaitForChild("SafeAreaRoot"):WaitForChild("OverlayHUD")
	Panel = OverlayHUD:WaitForChild("RebirthPanel") :: Frame
	Panel.Visible = false

	CloseButton = Panel:FindFirstChild("CloseButton") :: TextButton

	local MultiplierBar = Panel:FindFirstChild("MultiplierBar") :: Frame
	BarBG = MultiplierBar and MultiplierBar:FindFirstChild("BarBG") :: Frame
	BarFill = BarBG and BarBG:FindFirstChild("BarFill") :: Frame

	CurrentSizeLabel = Panel:FindFirstChild("CurrentSizeLabel") :: TextLabel
	RequiredSizeLabel = Panel:FindFirstChild("RequiredSizeLabel") :: TextLabel
	MultiplierPreviewLabel = Panel:FindFirstChild("MultiplierPreviewLabel") :: TextLabel
	RebirthCountLabel = Panel:FindFirstChild("RebirthCountLabel") :: TextLabel

	RebirthButton = Panel:FindFirstChild("RebirthButton") :: TextButton
	SkipRebirthButton = Panel:FindFirstChild("SkipRebirthButton") :: TextButton

	local Arrows = Panel:FindFirstChild("Arrows") :: Frame
	LeftArrow = Arrows and Arrows:FindFirstChild("LeftArrow") :: GuiButton
	RightArrow = Arrows and Arrows:FindFirstChild("RightArrow") :: GuiButton

	-- Wire launcher button (persists for session, like GuiController sidebar buttons)
	local SafeAreaRoot = ScreenGui:WaitForChild("SafeAreaRoot")
	local PersistentHUD = SafeAreaRoot:WaitForChild("PersistentHUD")
	local LeftSidebar = PersistentHUD:WaitForChild("LeftSidebar")
	local Launcher = LeftSidebar:FindFirstChild("Rebirth") :: ImageButton
	if Launcher then
		-- Persists for the session (mirrors GuiController sidebar wiring).
		Launcher.Activated:Connect(function()
			Open()
		end)
	end
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

	-- Wire panel button callbacks — these are re-bound on each Open() via the registry
	-- but the Activated connections are bound once here and read IsOpen state.
	-- We bind them once and they fire regardless of panel visibility (server validates).
	-- Launcher connection lives for session (already wired in Init).

	-- RebirthButton
	if RebirthButton then
		table.insert(
			PanelRegistry.Connections,
			RebirthButton.Activated:Connect(function()
				RequestRebirthRemote:FireServer()
			end)
		)
	end

	-- SkipRebirthButton
	if SkipRebirthButton then
		table.insert(
			PanelRegistry.Connections,
			SkipRebirthButton.Activated:Connect(function()
				RequestSkipRebirthRemote:FireServer()
			end)
		)
	end

	-- CloseButton
	if CloseButton then
		table.insert(
			PanelRegistry.Connections,
			CloseButton.Activated:Connect(function()
				Close()
			end)
		)
	end

	-- Arrow buttons (preview-only — no server calls)
	if LeftArrow then
		table.insert(
			PanelRegistry.Connections,
			LeftArrow.Activated:Connect(function()
				if PreviewIndex > 0 then
					PreviewIndex -= 1
					if CachedState then
						RenderTier(CachedState.PreviewTiers[PreviewIndex + 1])
					end
				else
					RenderTier(nil)
				end
			end)
		)
	end
	if RightArrow then
		table.insert(
			PanelRegistry.Connections,
			RightArrow.Activated:Connect(function()
				if CachedState and PreviewIndex < #CachedState.PreviewTiers then
					PreviewIndex += 1
					RenderTier(CachedState.PreviewTiers[PreviewIndex])
				end
			end)
		)
	end

	-- Initial render if we already have state (e.g. panel was open before)
	if CachedState and IsOpen then
		Render(CachedState)
	end
end

return RebirthController
