--!strict
-- SpinWheelController.luau
-- Client controller managing the Lucky Spin Wheel modal UI, rotation animation, and spin requests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIEventBus = require(script.Parent:WaitForChild("UIEventBus"))

export type SectorResult = {
	Index: number,
	Name: string,
	Reward: {
		Type: string,
		Amount: number?,
		Id: string?,
		[string]: any,
	},
}

export type SpinResultPayload = {
	Sector: SectorResult,
	RemainingTokens: number,
}

--// Variables \\--
local LocalPlayer = Players.LocalPlayer
local RequestSpinWheelRemote: RemoteEvent? = nil
local SpinCompletedRemote: RemoteEvent? = nil

local CachedTokens = 0
local IsModalOpen = false
local IsSpinning = false
local Initialized = false
local Started = false

local Connections: { RBXScriptConnection | { Disconnect: () -> () } } = {}
local DynamicGui: ScreenGui? = nil
local ModalFrame: Frame? = nil
local WheelImage: ImageLabel? = nil
local SpinButton: GuiButton? = nil
local TokensLabel: TextLabel? = nil

--// Helpers \\--
local function EnsureRemote(Name: string): RemoteEvent?
	local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if not RemotesFolder then
		return nil
	end

	local Remote = RemotesFolder:FindFirstChild(Name)
	if Remote and (not Remote.IsA or Remote:IsA("RemoteEvent")) then
		return Remote :: RemoteEvent
	end
	return nil
end

local function UpdateUI()
	if TokensLabel and ((TokensLabel.IsA and TokensLabel:IsA("TextLabel")) or type(TokensLabel) == "table") then
		TokensLabel.Text = string.format("Tokens: %d", CachedTokens)
	end

	if SpinButton and ((SpinButton.IsA and SpinButton:IsA("GuiButton")) or type(SpinButton) == "table") then
		local ButtonLabel = SpinButton:FindFirstChild("TextLabel", true)
			or (SpinButton.FindFirstChildWhichIsA and SpinButton:FindFirstChildWhichIsA("TextLabel"))
		if ButtonLabel and type(ButtonLabel) == "table" and ButtonLabel.Text ~= nil then
			if IsSpinning then
				ButtonLabel.Text = "SPINNING..."
			elseif CachedTokens > 0 then
				ButtonLabel.Text = "SPIN! (1 Token)"
			else
				ButtonLabel.Text = "NO TOKENS"
			end
		end
	end
end

--// Controller \\--
local SpinWheelController = {}

function SpinWheelController.Init()
	if Initialized then
		return
	end
	Initialized = true

	local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if RemotesFolder then
		RequestSpinWheelRemote = EnsureRemote("RequestSpinWheel")
		SpinCompletedRemote = EnsureRemote("SpinCompleted")
	end

	local PlayerGui = LocalPlayer and LocalPlayer.FindFirstChild and LocalPlayer:FindFirstChild("PlayerGui")
	if PlayerGui then
		local ScreenGui = PlayerGui:FindFirstChild("MainHUD") :: ScreenGui?
		if ScreenGui then
			local Modal = ScreenGui:FindFirstChild("SpinWheelModal", true) :: Frame?
			if Modal and ((Modal.IsA and Modal:IsA("Frame")) or type(Modal) == "table") then
				ModalFrame = Modal
				WheelImage = Modal:FindFirstChild("WheelImage", true) :: ImageLabel?
				SpinButton = Modal:FindFirstChild("SpinButton", true) :: GuiButton?
				TokensLabel = Modal:FindFirstChild("TokensLabel", true) :: TextLabel?
			end
		end
	end
end

function SpinWheelController.Start()
	if Started then
		return
	end
	SpinWheelController.Init()
	Started = true

	if not RequestSpinWheelRemote or not SpinCompletedRemote then
		local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes", 5)
		if RemotesFolder then
			RequestSpinWheelRemote = RemotesFolder:WaitForChild("RequestSpinWheel", 5) :: RemoteEvent?
			SpinCompletedRemote = RemotesFolder:WaitForChild("SpinCompleted", 5) :: RemoteEvent?
		end
	end

	if SpinCompletedRemote then
		local RemoteConn = SpinCompletedRemote.OnClientEvent:Connect(function(Payload: SpinResultPayload)
			if type(Payload) == "table" then
				if Payload.RemainingTokens ~= nil then
					CachedTokens = Payload.RemainingTokens
				end
				SpinWheelController.HandleSpinResult(Payload.Sector)
			end
		end)
		table.insert(Connections, RemoteConn)
	end

	-- UIEventBus Subscriptions
	local BusOpenConn = UIEventBus.Subscribe("OpenSpinWheel", function()
		SpinWheelController.Open()
	end)
	table.insert(Connections, BusOpenConn)

	local BusCloseConn = UIEventBus.Subscribe("CloseSpinWheel", function()
		SpinWheelController.Close()
	end)
	table.insert(Connections, BusCloseConn)

	local BusToggleConn = UIEventBus.Subscribe("ToggleSpinWheel", function()
		SpinWheelController.Toggle()
	end)
	table.insert(Connections, BusToggleConn)

	local BusSpinConn = UIEventBus.Subscribe("SpinWheel", function()
		SpinWheelController.Spin()
	end)
	table.insert(Connections, BusSpinConn)

	local BusSidebarConn = UIEventBus.Subscribe("SidebarButtonClicked", function(buttonName: any)
		if buttonName == "Spin" or buttonName == "SpinWheel" or buttonName == "LuckySpin" then
			SpinWheelController.Toggle()
		end
	end)
	table.insert(Connections, BusSidebarConn)
end

function SpinWheelController.HandleSpinResult(Sector: SectorResult)
	IsSpinning = true
	UpdateUI()
	UIEventBus.Publish("SpinStarted")

	-- Animate wheel rotation if WheelImage is present
	local TargetSectorIndex = if Sector and Sector.Index then Sector.Index else 1
	-- 8 sectors = 45 degrees per sector
	local SectorAngle = (TargetSectorIndex - 1) * 45
	local TotalRotation = 360 * 5 + (360 - SectorAngle)

	if WheelImage and WheelImage.IsA and WheelImage:IsA("ImageLabel") then
		pcall(function()
			WheelImage.Rotation = TotalRotation % 360
		end)
	end

	IsSpinning = false
	UpdateUI()
	UIEventBus.Publish("SpinCompleted", Sector)
end

function SpinWheelController.Open()
	IsModalOpen = true
	if ModalFrame then
		ModalFrame.Visible = true
	end
	UpdateUI()
	UIEventBus.Publish("SpinWheelModalOpened")
end

function SpinWheelController.Close()
	IsModalOpen = false
	if ModalFrame then
		ModalFrame.Visible = false
	end
	UIEventBus.Publish("SpinWheelModalClosed")
end

function SpinWheelController.Toggle()
	if IsModalOpen then
		SpinWheelController.Close()
	else
		SpinWheelController.Open()
	end
end

function SpinWheelController.IsOpen(): boolean
	return IsModalOpen
end

function SpinWheelController.IsSpinning(): boolean
	return IsSpinning
end

function SpinWheelController.GetTokens(): number
	return CachedTokens
end

function SpinWheelController.Spin()
	if IsSpinning then
		return
	end

	if not RequestSpinWheelRemote then
		RequestSpinWheelRemote = EnsureRemote("RequestSpinWheel")
	end

	if RequestSpinWheelRemote then
		pcall(function()
			RequestSpinWheelRemote:FireServer()
		end)
	end
end

function SpinWheelController.Destroy()
	for _, Connection in Connections do
		if typeof(Connection) == "RBXScriptConnection" then
			(Connection :: RBXScriptConnection):Disconnect()
		elseif typeof(Connection) == "table" and typeof(Connection.Disconnect) == "function" then
			Connection.Disconnect()
		end
	end
	table.clear(Connections)

	if DynamicGui then
		DynamicGui:Destroy()
		DynamicGui = nil
	end

	CachedTokens = 0
	IsModalOpen = false
	IsSpinning = false
	Initialized = false
	Started = false
	RequestSpinWheelRemote = nil
	SpinCompletedRemote = nil
	ModalFrame = nil
	WheelImage = nil
	SpinButton = nil
	TokensLabel = nil
end

return SpinWheelController
