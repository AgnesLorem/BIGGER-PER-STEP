--!strict
-- DailyRewardController.luau
-- Client controller managing the Daily Login Rewards modal UI, status synchronization, and claim requests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIEventBus = require(script.Parent:WaitForChild("UIEventBus"))

export type DailyRewardInfo = {
	Day: number,
	Name: string,
	Reward: {
		Type: string,
		Amount: number?,
		Id: string?,
		[string]: any,
	},
}

export type DailyStatus = {
	Day: number,
	CanClaim: boolean,
	TimeUntilNext: number,
	CurrentReward: DailyRewardInfo?,
	NextReward: DailyRewardInfo?,
	LastClaimTimestamp: number,
}

--// Variables \\--
local LocalPlayer = Players.LocalPlayer
local RequestClaimDailyRemote: RemoteEvent? = nil
local DailyStatusUpdatedRemote: RemoteEvent? = nil

local CachedStatus: DailyStatus? = nil
local IsModalOpen = false
local Initialized = false
local Started = false

local Connections: { RBXScriptConnection | { Disconnect: () -> () } } = {}
local DynamicGui: ScreenGui? = nil
local ModalFrame: Frame? = nil
local ClaimButton: GuiButton? = nil
local StatusLabel: TextLabel? = nil

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

local function FormatTime(Seconds: number): string
	if Seconds <= 0 then
		return "Ready to Claim!"
	end
	local Hours = math.floor(Seconds / 3600)
	local Minutes = math.floor((Seconds % 3600) / 60)
	local Secs = Seconds % 60
	return string.format("%02d:%02d:%02d", Hours, Minutes, Secs)
end

local function UpdateUI()
	if not CachedStatus then
		return
	end

	if StatusLabel and ((StatusLabel.IsA and StatusLabel:IsA("TextLabel")) or type(StatusLabel) == "table") then
		if CachedStatus.CanClaim then
			StatusLabel.Text = string.format("Day %d Reward Available!", CachedStatus.Day)
		else
			StatusLabel.Text = string.format("Next reward in %s", FormatTime(CachedStatus.TimeUntilNext))
		end
	end

	if ClaimButton and ((ClaimButton.IsA and ClaimButton:IsA("GuiButton")) or type(ClaimButton) == "table") then
		local ButtonLabel = ClaimButton:FindFirstChild("TextLabel", true)
			or (ClaimButton.FindFirstChildWhichIsA and ClaimButton:FindFirstChildWhichIsA("TextLabel"))
		if ButtonLabel and type(ButtonLabel) == "table" and ButtonLabel.Text ~= nil then
			ButtonLabel.Text = if CachedStatus.CanClaim then "CLAIM REWARD" else "COME BACK LATER"
		end
	end
end

--// Controller \\--
local DailyRewardController = {}

function DailyRewardController.Init()
	if Initialized then
		return
	end
	Initialized = true

	local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if RemotesFolder then
		RequestClaimDailyRemote = EnsureRemote("RequestClaimDaily")
		DailyStatusUpdatedRemote = EnsureRemote("DailyStatusUpdated")
	end

	local PlayerGui = LocalPlayer and LocalPlayer.FindFirstChild and LocalPlayer:FindFirstChild("PlayerGui")
	if PlayerGui then
		local ScreenGui = PlayerGui:FindFirstChild("MainHUD") :: ScreenGui?
		if ScreenGui then
			local Modal = ScreenGui:FindFirstChild("DailyRewardModal", true) :: Frame?
			if Modal and ((Modal.IsA and Modal:IsA("Frame")) or type(Modal) == "table") then
				ModalFrame = Modal
				ClaimButton = Modal:FindFirstChild("ClaimButton", true) :: GuiButton?
				StatusLabel = Modal:FindFirstChild("StatusLabel", true) :: TextLabel?
			end
		end
	end
end

function DailyRewardController.Start()
	if Started then
		return
	end
	DailyRewardController.Init()
	Started = true

	if not RequestClaimDailyRemote or not DailyStatusUpdatedRemote then
		local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes", 5)
		if RemotesFolder then
			RequestClaimDailyRemote = RemotesFolder:WaitForChild("RequestClaimDaily", 5) :: RemoteEvent?
			DailyStatusUpdatedRemote = RemotesFolder:WaitForChild("DailyStatusUpdated", 5) :: RemoteEvent?
		end
	end

	if DailyStatusUpdatedRemote then
		local RemoteConn = DailyStatusUpdatedRemote.OnClientEvent:Connect(function(Status: DailyStatus)
			CachedStatus = Status
			UpdateUI()
			UIEventBus.Publish("DailyStatusUpdated", Status)
		end)
		table.insert(Connections, RemoteConn)
	end

	-- UIEventBus Subscriptions
	local BusOpenConn = UIEventBus.Subscribe("OpenDailyReward", function()
		DailyRewardController.Open()
	end)
	table.insert(Connections, BusOpenConn)

	local BusCloseConn = UIEventBus.Subscribe("CloseDailyReward", function()
		DailyRewardController.Close()
	end)
	table.insert(Connections, BusCloseConn)

	local BusToggleConn = UIEventBus.Subscribe("ToggleDailyReward", function()
		DailyRewardController.Toggle()
	end)
	table.insert(Connections, BusToggleConn)

	local BusClaimConn = UIEventBus.Subscribe("ClaimDailyReward", function()
		DailyRewardController.Claim()
	end)
	table.insert(Connections, BusClaimConn)

	local BusSidebarConn = UIEventBus.Subscribe("SidebarButtonClicked", function(buttonName: any)
		if buttonName == "Daily" or buttonName == "DailyReward" or buttonName == "DailyRewards" then
			DailyRewardController.Toggle()
		end
	end)
	table.insert(Connections, BusSidebarConn)
end

function DailyRewardController.Open()
	IsModalOpen = true
	if ModalFrame then
		ModalFrame.Visible = true
	end
	UpdateUI()
	UIEventBus.Publish("DailyRewardModalOpened")
end

function DailyRewardController.Close()
	IsModalOpen = false
	if ModalFrame then
		ModalFrame.Visible = false
	end
	UIEventBus.Publish("DailyRewardModalClosed")
end

function DailyRewardController.Toggle()
	if IsModalOpen then
		DailyRewardController.Close()
	else
		DailyRewardController.Open()
	end
end

function DailyRewardController.IsOpen(): boolean
	return IsModalOpen
end

function DailyRewardController.GetStatus(): DailyStatus?
	return CachedStatus
end

function DailyRewardController.Claim()
	if not RequestClaimDailyRemote then
		RequestClaimDailyRemote = EnsureRemote("RequestClaimDaily")
	end

	if RequestClaimDailyRemote then
		pcall(function()
			RequestClaimDailyRemote:FireServer()
		end)
	end
end

function DailyRewardController.Destroy()
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

	CachedStatus = nil
	IsModalOpen = false
	Initialized = false
	Started = false
	RequestClaimDailyRemote = nil
	DailyStatusUpdatedRemote = nil
	ModalFrame = nil
	ClaimButton = nil
	StatusLabel = nil
end

return DailyRewardController
