--!strict
-- CosmeticsController.luau
-- Client controller managing Cosmetics (Trails & Overhead Titles) modal UI, status synchronization, and equip requests.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local UIEventBus = require(script.Parent:WaitForChild("UIEventBus"))

export type TrailInfo = {
	Id: string,
	Name: string,
	Lifetime: number,
	LightEmission: number,
	DefaultUnlocked: boolean,
	[string]: any,
}

export type TitleInfo = {
	Id: string,
	DisplayName: string,
	DefaultUnlocked: boolean,
	[string]: any,
}

export type CosmeticsStatus = {
	UnlockedTrails: { [string]: boolean },
	EquippedTrail: string?,
	UnlockedTitles: { [string]: boolean },
	EquippedTitle: string?,
	Trails: { TrailInfo }?,
	Titles: { TitleInfo }?,
}

--// Variables \\--
local LocalPlayer = Players.LocalPlayer
local RequestEquipTrailRemote: RemoteEvent? = nil
local RequestUnequipTrailRemote: RemoteEvent? = nil
local RequestEquipTitleRemote: RemoteEvent? = nil
local RequestUnequipTitleRemote: RemoteEvent? = nil
local CosmeticsStatusUpdatedRemote: RemoteEvent? = nil

local CachedStatus: CosmeticsStatus? = nil
local IsModalOpen = false
local ActiveTab = "Trails"
local Initialized = false
local Started = false

local Connections: { RBXScriptConnection | { Disconnect: () -> () } } = {}
local DynamicGui: ScreenGui? = nil
local ModalFrame: Frame? = nil
local TrailsTabButton: GuiButton? = nil
local TitlesTabButton: GuiButton? = nil
local CloseButton: GuiButton? = nil

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
	if not CachedStatus or not ModalFrame then
		return
	end
	-- Visual elements update if present in ModalFrame
end

--// Controller \\--
local CosmeticsController = {}

function CosmeticsController.Init()
	if Initialized then
		return
	end
	Initialized = true

	local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if RemotesFolder then
		RequestEquipTrailRemote = EnsureRemote("RequestEquipTrail")
		RequestUnequipTrailRemote = EnsureRemote("RequestUnequipTrail")
		RequestEquipTitleRemote = EnsureRemote("RequestEquipTitle")
		RequestUnequipTitleRemote = EnsureRemote("RequestUnequipTitle")
		CosmeticsStatusUpdatedRemote = EnsureRemote("CosmeticsStatusUpdated")
	end

	local PlayerGui = LocalPlayer and LocalPlayer.FindFirstChild and LocalPlayer:FindFirstChild("PlayerGui")
	if PlayerGui then
		local ScreenGui = PlayerGui:FindFirstChild("MainHUD") :: ScreenGui?
		if ScreenGui then
			local Modal = ScreenGui:FindFirstChild("CosmeticsModal", true) :: Frame?
			if Modal and ((Modal.IsA and Modal:IsA("Frame")) or type(Modal) == "table") then
				ModalFrame = Modal
				TrailsTabButton = Modal:FindFirstChild("TrailsTabButton", true) :: GuiButton?
				TitlesTabButton = Modal:FindFirstChild("TitlesTabButton", true) :: GuiButton?
				CloseButton = Modal:FindFirstChild("CloseButton", true) :: GuiButton?
			end
		end
	end
end

function CosmeticsController.Start()
	if Started then
		return
	end
	CosmeticsController.Init()
	Started = true

	if not CosmeticsStatusUpdatedRemote then
		local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes", 5)
		if RemotesFolder then
			RequestEquipTrailRemote = RemotesFolder:WaitForChild("RequestEquipTrail", 5) :: RemoteEvent?
			RequestUnequipTrailRemote = RemotesFolder:WaitForChild("RequestUnequipTrail", 5) :: RemoteEvent?
			RequestEquipTitleRemote = RemotesFolder:WaitForChild("RequestEquipTitle", 5) :: RemoteEvent?
			RequestUnequipTitleRemote = RemotesFolder:WaitForChild("RequestUnequipTitle", 5) :: RemoteEvent?
			CosmeticsStatusUpdatedRemote = RemotesFolder:WaitForChild("CosmeticsStatusUpdated", 5) :: RemoteEvent?
		end
	end

	if CosmeticsStatusUpdatedRemote then
		local RemoteConn = CosmeticsStatusUpdatedRemote.OnClientEvent:Connect(function(Status: CosmeticsStatus)
			CachedStatus = Status
			UpdateUI()
			UIEventBus.Publish("CosmeticsStatusUpdated", Status)
		end)
		table.insert(Connections, RemoteConn)
	end

	if TrailsTabButton and (TrailsTabButton :: any).Activated then
		local Conn = (TrailsTabButton :: any).Activated:Connect(function()
			CosmeticsController.SetTab("Trails")
		end)
		table.insert(Connections, Conn)
	end
	if TitlesTabButton and (TitlesTabButton :: any).Activated then
		local Conn = (TitlesTabButton :: any).Activated:Connect(function()
			CosmeticsController.SetTab("Titles")
		end)
		table.insert(Connections, Conn)
	end
	if CloseButton and (CloseButton :: any).Activated then
		local Conn = (CloseButton :: any).Activated:Connect(function()
			CosmeticsController.Close()
		end)
		table.insert(Connections, Conn)
	end

	-- UIEventBus Subscriptions
	local BusOpenConn = UIEventBus.Subscribe("OpenCosmetics", function()
		CosmeticsController.Open()
	end)
	table.insert(Connections, BusOpenConn)

	local BusCloseConn = UIEventBus.Subscribe("CloseCosmetics", function()
		CosmeticsController.Close()
	end)
	table.insert(Connections, BusCloseConn)

	local BusToggleConn = UIEventBus.Subscribe("ToggleCosmetics", function()
		CosmeticsController.Toggle()
	end)
	table.insert(Connections, BusToggleConn)

	local BusEquipTrailConn = UIEventBus.Subscribe("EquipTrail", function(trailId: any)
		if type(trailId) == "string" then
			CosmeticsController.EquipTrail(trailId)
		end
	end)
	table.insert(Connections, BusEquipTrailConn)

	local BusUnequipTrailConn = UIEventBus.Subscribe("UnequipTrail", function()
		CosmeticsController.UnequipTrail()
	end)
	table.insert(Connections, BusUnequipTrailConn)

	local BusEquipTitleConn = UIEventBus.Subscribe("EquipTitle", function(titleId: any)
		if type(titleId) == "string" then
			CosmeticsController.EquipTitle(titleId)
		end
	end)
	table.insert(Connections, BusEquipTitleConn)

	local BusUnequipTitleConn = UIEventBus.Subscribe("UnequipTitle", function()
		CosmeticsController.UnequipTitle()
	end)
	table.insert(Connections, BusUnequipTitleConn)

	local BusSidebarConn = UIEventBus.Subscribe("SidebarButtonClicked", function(buttonName: any)
		if
			buttonName == "Cosmetics"
			or buttonName == "Trails"
			or buttonName == "Titles"
			or buttonName == "CosmeticShop"
		then
			if buttonName == "Titles" then
				CosmeticsController.SetTab("Titles")
			elseif buttonName == "Trails" then
				CosmeticsController.SetTab("Trails")
			end
			CosmeticsController.Toggle()
		end
	end)
	table.insert(Connections, BusSidebarConn)
end

function CosmeticsController.Open()
	IsModalOpen = true
	if ModalFrame then
		ModalFrame.Visible = true
	end
	UpdateUI()
	UIEventBus.Publish("CosmeticsModalOpened")
end

function CosmeticsController.Close()
	IsModalOpen = false
	if ModalFrame then
		ModalFrame.Visible = false
	end
	UIEventBus.Publish("CosmeticsModalClosed")
end

function CosmeticsController.Toggle()
	if IsModalOpen then
		CosmeticsController.Close()
	else
		CosmeticsController.Open()
	end
end

function CosmeticsController.IsOpen(): boolean
	return IsModalOpen
end

function CosmeticsController.GetStatus(): CosmeticsStatus?
	return CachedStatus
end

function CosmeticsController.SetTab(TabName: string)
	ActiveTab = TabName
	UpdateUI()
	UIEventBus.Publish("CosmeticsTabChanged", TabName)
end

function CosmeticsController.GetActiveTab(): string
	return ActiveTab
end

function CosmeticsController.EquipTrail(TrailId: string)
	if not RequestEquipTrailRemote then
		RequestEquipTrailRemote = EnsureRemote("RequestEquipTrail")
	end

	if RequestEquipTrailRemote then
		pcall(function()
			RequestEquipTrailRemote:FireServer(TrailId)
		end)
	end
end

function CosmeticsController.UnequipTrail()
	if not RequestUnequipTrailRemote then
		RequestUnequipTrailRemote = EnsureRemote("RequestUnequipTrail")
	end

	if RequestUnequipTrailRemote then
		pcall(function()
			RequestUnequipTrailRemote:FireServer()
		end)
	end
end

function CosmeticsController.EquipTitle(TitleId: string)
	if not RequestEquipTitleRemote then
		RequestEquipTitleRemote = EnsureRemote("RequestEquipTitle")
	end

	if RequestEquipTitleRemote then
		pcall(function()
			RequestEquipTitleRemote:FireServer(TitleId)
		end)
	end
end

function CosmeticsController.UnequipTitle()
	if not RequestUnequipTitleRemote then
		RequestUnequipTitleRemote = EnsureRemote("RequestUnequipTitle")
	end

	if RequestUnequipTitleRemote then
		pcall(function()
			RequestUnequipTitleRemote:FireServer()
		end)
	end
end

function CosmeticsController.Destroy()
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
	ActiveTab = "Trails"
	Initialized = false
	Started = false
	RequestEquipTrailRemote = nil
	RequestUnequipTrailRemote = nil
	RequestEquipTitleRemote = nil
	RequestUnequipTitleRemote = nil
	CosmeticsStatusUpdatedRemote = nil
	ModalFrame = nil
	TrailsTabButton = nil
	TitlesTabButton = nil
	CloseButton = nil
end

return CosmeticsController
