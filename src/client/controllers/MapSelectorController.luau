--!strict
-- MapSelectorController.luau
-- Client controller managing the 3-tab responsive map selection UI and firing RequestSelectMap.

--// Raw Requirings \\--
local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local WorkspaceFound, Workspace = pcall(function()
	return game:GetService("Workspace")
end)

--// Requirings \\--
local UIEventBus = require(script.Parent:WaitForChild("UIEventBus"))

--// Types \\--
export type MapCardData = {
	MapId: string,
	CategoryId: string,
	Name: string,
	RequiredLevel: number,
	RequiredSize: number,
	RewardText: string,
	IsComingSoon: boolean,
}

--// Variables \\--
local LocalPlayer = Players.LocalPlayer
local RequestSelectMapRemote: RemoteEvent? = nil

local IsOpen = false
local Initialized = false
local Started = false
local CurrentTab: string = "Forest"
local SelectedMapId: string = "MAP1"

-- GUI References
local ScreenGui: ScreenGui? = nil
local OverlayHUD: Frame? = nil
local Panel: Frame? = nil
local CloseButton: GuiButton? = nil
local TeleportButton: GuiButton? = nil
local CardsContainer: Frame? = nil
local TabButtons: { [string]: GuiButton } = {}

local ACTION_TELEPORT = "MapSelector_TeleportAction"
local ACTION_CLOSE = "MapSelector_CloseAction"

local Connections: { any } = {}
local CardConnections: { any } = {}

-- Static Map Definitions for Client Presentation
local MapRegistry: { [string]: { MapCardData } } = {
	Forest = {
		{
			MapId = "MAP1",
			CategoryId = "Forest",
			Name = "Nhện Rừng (Forest Spider)",
			RequiredLevel = 5,
			RequiredSize = 50,
			RewardText = "+1 Destruction",
			IsComingSoon = false,
		},
		{
			MapId = "MAP2",
			CategoryId = "Forest",
			Name = "Heo Rừng Gai (Wild Boar)",
			RequiredLevel = 15,
			RequiredSize = 500,
			RewardText = "+5 Destruction",
			IsComingSoon = false,
		},
		{
			MapId = "MAP3",
			CategoryId = "Forest",
			Name = "Gấu Chúa Cổ Đại (Ancient Bear)",
			RequiredLevel = 35,
			RequiredSize = 5000,
			RewardText = "+20 Destruction",
			IsComingSoon = false,
		},
	},
	Residential = {
		{
			MapId = "MAP4",
			CategoryId = "Residential",
			Name = "Xe Tải Hỏng",
			RequiredLevel = 60,
			RequiredSize = 25000,
			RewardText = "+50 Destruction",
			IsComingSoon = true,
		},
		{
			MapId = "MAP5",
			CategoryId = "Residential",
			Name = "Biệt Thự Bỏ Hoang",
			RequiredLevel = 100,
			RequiredSize = 100000,
			RewardText = "+120 Destruction",
			IsComingSoon = true,
		},
		{
			MapId = "MAP6",
			CategoryId = "Residential",
			Name = "Cần Cẩu Công Trình",
			RequiredLevel = 150,
			RequiredSize = 500000,
			RewardText = "+300 Destruction",
			IsComingSoon = true,
		},
	},
	Metropolis = {
		{
			MapId = "MAP7",
			CategoryId = "Metropolis",
			Name = "Trạm Điện Giao Lộ",
			RequiredLevel = 220,
			RequiredSize = 2500000,
			RewardText = "+800 Destruction",
			IsComingSoon = true,
		},
		{
			MapId = "MAP8",
			CategoryId = "Metropolis",
			Name = "Tháp Ngân Hàng",
			RequiredLevel = 300,
			RequiredSize = 10000000,
			RewardText = "+2,000 Destruction",
			IsComingSoon = true,
		},
		{
			MapId = "MAP9",
			CategoryId = "Metropolis",
			Name = "Chiến Hạm Bay",
			RequiredLevel = 400,
			RequiredSize = 50000000,
			RewardText = "+5,000 Destruction",
			IsComingSoon = true,
		},
		{
			MapId = "MAP10",
			CategoryId = "Metropolis",
			Name = "Robot Titan",
			RequiredLevel = 500,
			RequiredSize = 250000000,
			RewardText = "+15,000 Destruction",
			IsComingSoon = true,
		},
	},
}

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

local function GetPlayerLevel(): number
	local SizeAttr = LocalPlayer:GetAttribute("Size") or LocalPlayer:GetAttribute("Bigger")
	if type(SizeAttr) == "number" then
		return math.floor(math.max(1, math.log(math.max(1, SizeAttr)) / math.log(1.5)))
	end
	local Leaderstats = LocalPlayer:FindFirstChild("leaderstats")
	local SizeStat = Leaderstats and Leaderstats:FindFirstChild("Size")
	if SizeStat and SizeStat:IsA("NumberValue") then
		return math.floor(math.max(1, math.log(math.max(1, SizeStat.Value)) / math.log(1.5)))
	end
	return 1
end

local function AttachBounce(Button: GuiButton)
	local UIScale = Button:FindFirstChildOfClass("UIScale")
	if not UIScale then
		UIScale = Instance.new("UIScale")
		UIScale.Parent = Button
	end

	local TweenIn = TweenService:Create(
		UIScale :: UIScale,
		TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ Scale = 0.95 }
	)
	local TweenOut = TweenService:Create(
		UIScale :: UIScale,
		TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = 1.0 }
	)

	Button.InputBegan:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			TweenIn:Play()
		end
	end)

	Button.InputEnded:Connect(function(input)
		if
			input.UserInputType == Enum.UserInputType.MouseButton1
			or input.UserInputType == Enum.UserInputType.Touch
		then
			TweenOut:Play()
		end
	end)
end

local function CreateMockupPanel(Parent: Instance): Frame
	local MockPanel = Instance.new("Frame")
	MockPanel.Name = "MapSelectorPanel"
	MockPanel.AnchorPoint = Vector2.new(0.5, 0.5)
	MockPanel.Position = UDim2.fromScale(0.5, 0.5)
	MockPanel.Size = UDim2.fromScale(0.7, 0.65)
	MockPanel.BackgroundColor3 = Color3.fromRGB(20, 24, 38)
	MockPanel.BorderSizePixel = 0
	MockPanel.Visible = false
	MockPanel.Parent = Parent

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 16)
	Corner.Parent = MockPanel

	local Stroke = Instance.new("UIStroke")
	Stroke.Color = Color3.fromRGB(60, 80, 120)
	Stroke.Thickness = 3
	Stroke.Parent = MockPanel

	local Aspect = Instance.new("UIAspectRatioConstraint")
	Aspect.AspectRatio = 1.35
	Aspect.Parent = MockPanel

	-- TopBar
	local TopBar = Instance.new("Frame")
	TopBar.Name = "TopBar"
	TopBar.Size = UDim2.fromScale(1, 0.12)
	TopBar.BackgroundTransparency = 1
	TopBar.Parent = MockPanel

	local Title = Instance.new("TextLabel")
	Title.Name = "TitleText"
	Title.Size = UDim2.fromScale(0.6, 1)
	Title.Position = UDim2.fromScale(0.05, 0)
	Title.BackgroundTransparency = 1
	Title.Font = Enum.Font.FredokaOne
	Title.Text = "CHỌN BẢN ĐỒ"
	Title.TextColor3 = Color3.fromRGB(255, 255, 255)
	Title.TextScaled = true
	Title.TextXAlignment = Enum.TextXAlignment.Left
	Title.Parent = TopBar

	local Close = Instance.new("TextButton")
	Close.Name = "CloseButton"
	Close.Size = UDim2.fromScale(0.08, 0.7)
	Close.Position = UDim2.fromScale(0.9, 0.15)
	Close.BackgroundColor3 = Color3.fromRGB(200, 50, 50)
	Close.Font = Enum.Font.FredokaOne
	Close.Text = "X"
	Close.TextColor3 = Color3.fromRGB(255, 255, 255)
	Close.TextScaled = true
	Close.Parent = TopBar
	local CloseCorner = Instance.new("UICorner")
	CloseCorner.CornerRadius = UDim.new(0, 8)
	CloseCorner.Parent = Close

	-- TabsContainer
	local Tabs = Instance.new("Frame")
	Tabs.Name = "TabsContainer"
	Tabs.Size = UDim2.fromScale(0.9, 0.1)
	Tabs.Position = UDim2.fromScale(0.05, 0.14)
	Tabs.BackgroundTransparency = 1
	Tabs.Parent = MockPanel

	local TabsLayout = Instance.new("UIListLayout")
	TabsLayout.FillDirection = Enum.FillDirection.Horizontal
	TabsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	TabsLayout.Padding = UDim.new(0, 10)
	TabsLayout.Parent = Tabs

	local tabDefs = {
		{ Name = "TabForest", Text = "Khu Rừng" },
		{ Name = "TabResidential", Text = "Khu Dân Cư" },
		{ Name = "TabMetropolis", Text = "Siêu Đô Thị" },
	}
	for _, td in tabDefs do
		local TabBtn = Instance.new("TextButton")
		TabBtn.Name = td.Name
		TabBtn.Size = UDim2.fromScale(0.3, 1)
		TabBtn.BackgroundColor3 = Color3.fromRGB(25, 55, 95)
		TabBtn.Font = Enum.Font.FredokaOne
		TabBtn.Text = td.Text
		TabBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		TabBtn.TextScaled = true
		TabBtn.Parent = Tabs
		local TabCorner = Instance.new("UICorner")
		TabCorner.CornerRadius = UDim.new(0, 8)
		TabCorner.Parent = TabBtn
	end

	-- CardsContainer
	local Cards = Instance.new("Frame")
	Cards.Name = "CardsContainer"
	Cards.Size = UDim2.fromScale(0.9, 0.54)
	Cards.Position = UDim2.fromScale(0.05, 0.27)
	Cards.BackgroundTransparency = 1
	Cards.Parent = MockPanel

	local CardsLayout = Instance.new("UIListLayout")
	CardsLayout.FillDirection = Enum.FillDirection.Horizontal
	CardsLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	CardsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	CardsLayout.Padding = UDim.new(0, 12)
	CardsLayout.Parent = Cards

	-- TeleportButton
	local Teleport = Instance.new("TextButton")
	Teleport.Name = "TeleportButton"
	Teleport.Size = UDim2.fromScale(0.4, 0.12)
	Teleport.Position = UDim2.fromScale(0.3, 0.84)
	Teleport.BackgroundColor3 = Color3.fromRGB(32, 255, 64)
	Teleport.Font = Enum.Font.FredokaOne
	Teleport.Text = "DỊCH CHUYỂN"
	Teleport.TextColor3 = Color3.fromRGB(10, 20, 30)
	Teleport.TextScaled = true
	Teleport.Parent = MockPanel
	local TeleportCorner = Instance.new("UICorner")
	TeleportCorner.CornerRadius = UDim.new(0, 10)
	TeleportCorner.Parent = Teleport

	return MockPanel
end

local MapSelectorController = {}

local function ClearCardConnections()
	for _, conn in CardConnections do
		if typeof(conn) == "RBXScriptConnection" then
			(conn :: RBXScriptConnection):Disconnect()
		end
	end
	table.clear(CardConnections)
end

local function RenderCards()
	if not CardsContainer then
		return
	end
	ClearCardConnections()

	local CurrentList = MapRegistry[CurrentTab] or {}

	-- Check existing cards or create missing ones
	for _, item in CurrentList do
		local CardName = "Card_" .. item.MapId
		local CardFrame = CardsContainer:FindFirstChild(CardName) :: Frame?
		if not CardFrame then
			CardFrame = Instance.new("Frame")
			CardFrame.Name = CardName
			CardFrame.Size = UDim2.fromScale(0.3, 0.9)
			CardFrame.BackgroundColor3 = Color3.fromRGB(30, 38, 56)
			CardFrame.BorderSizePixel = 0
			CardFrame.Parent = CardsContainer

			local Corner = Instance.new("UICorner")
			Corner.CornerRadius = UDim.new(0, 10)
			Corner.Parent = CardFrame

			local Stroke = Instance.new("UIStroke")
			Stroke.Thickness = 1
			Stroke.Color = Color3.fromRGB(60, 80, 120)
			Stroke.Parent = CardFrame

			local TitleLabel = Instance.new("TextLabel")
			TitleLabel.Name = "CardTitle"
			TitleLabel.Size = UDim2.fromScale(0.9, 0.25)
			TitleLabel.Position = UDim2.fromScale(0.05, 0.08)
			TitleLabel.BackgroundTransparency = 1
			TitleLabel.Font = Enum.Font.FredokaOne
			TitleLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
			TitleLabel.TextScaled = true
			TitleLabel.Parent = CardFrame

			local LevelLabel = Instance.new("TextLabel")
			LevelLabel.Name = "LevelLabel"
			LevelLabel.Size = UDim2.fromScale(0.9, 0.2)
			LevelLabel.Position = UDim2.fromScale(0.05, 0.4)
			LevelLabel.BackgroundTransparency = 1
			LevelLabel.Font = Enum.Font.FredokaOne
			LevelLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
			LevelLabel.TextScaled = true
			LevelLabel.Parent = CardFrame

			local RewardLabel = Instance.new("TextLabel")
			RewardLabel.Name = "RewardLabel"
			RewardLabel.Size = UDim2.fromScale(0.9, 0.2)
			RewardLabel.Position = UDim2.fromScale(0.05, 0.65)
			RewardLabel.BackgroundTransparency = 1
			RewardLabel.Font = Enum.Font.FredokaOne
			RewardLabel.TextColor3 = Color3.fromRGB(32, 255, 64)
			RewardLabel.TextScaled = true
			RewardLabel.Parent = CardFrame
		end

		-- Populate texts
		CardFrame.Visible = true
		local TitleLabel = CardFrame:FindFirstChild("CardTitle") :: TextLabel?
		if TitleLabel then
			TitleLabel.Text = item.Name
		end

		local LevelLabel = CardFrame:FindFirstChild("LevelLabel") :: TextLabel?
		if LevelLabel then
			if item.IsComingSoon then
				LevelLabel.Text = "Sắp ra mắt"
				LevelLabel.TextColor3 = Color3.fromRGB(160, 160, 160)
			else
				LevelLabel.Text = string.format("Cấp %d", item.RequiredLevel)
				LevelLabel.TextColor3 = Color3.fromRGB(255, 220, 80)
			end
		end

		local RewardLabel = CardFrame:FindFirstChild("RewardLabel") :: TextLabel?
		if RewardLabel then
			RewardLabel.Text = item.RewardText
		end

		-- Selection stroke styling
		local Stroke = CardFrame:FindFirstChildOfClass("UIStroke")
		if Stroke then
			if item.MapId == SelectedMapId then
				Stroke.Color = Color3.fromRGB(255, 220, 80)
				Stroke.Thickness = 3
				CardFrame.BackgroundTransparency = 0.1
			else
				Stroke.Color = Color3.fromRGB(60, 80, 120)
				Stroke.Thickness = 1
				CardFrame.BackgroundTransparency = 0.3
			end
		end

		-- Click / Tap to select map
		local ClickBtn = CardFrame:FindFirstChild("ClickButton") :: TextButton?
		if not ClickBtn then
			ClickBtn = Instance.new("TextButton")
			ClickBtn.Name = "ClickButton"
			ClickBtn.Size = UDim2.fromScale(1, 1)
			ClickBtn.BackgroundTransparency = 1
			ClickBtn.Text = ""
			ClickBtn.Parent = CardFrame
		end

		local targetMapId = item.MapId
		local clickConn = ClickBtn.Activated:Connect(function()
			MapSelectorController.SetSelectedMap(targetMapId)
		end)
		table.insert(CardConnections, clickConn)
	end

	-- Hide any cards not in current tab
	for _, child in CardsContainer:GetChildren() do
		if child:IsA("Frame") and string.sub(child.Name, 1, 5) == "Card_" then
			local mapId = string.sub(child.Name, 6)
			local inTab = false
			for _, item in CurrentList do
				if item.MapId == mapId then
					inTab = true
					break
				end
			end
			if not inTab then
				child.Visible = false
			end
		end
	end
end

local function Render()
	if not Panel then
		return
	end
	Panel.Visible = IsOpen
	if OverlayHUD and IsOpen then
		OverlayHUD.Visible = true
	end

	if not IsOpen then
		return
	end

	-- Update active tab button visuals
	for tabName, btn in TabButtons do
		if tabName == CurrentTab then
			btn.BackgroundTransparency = 0.2
		else
			btn.BackgroundTransparency = 0.7
		end
	end

	-- Check selected map validity
	local CurrentList = MapRegistry[CurrentTab] or {}
	local SelectedData: MapCardData? = nil
	for _, item in CurrentList do
		if item.MapId == SelectedMapId then
			SelectedData = item
			break
		end
	end

	if not SelectedData and #CurrentList > 0 then
		SelectedData = CurrentList[1]
		SelectedMapId = SelectedData.MapId
	end

	RenderCards()

	if TeleportButton and SelectedData then
		local PlayerLvl = GetPlayerLevel()
		local CanEnter = not SelectedData.IsComingSoon and PlayerLvl >= SelectedData.RequiredLevel
		if CanEnter then
			TeleportButton.Text = "DỊCH CHUYỂN"
			TeleportButton.BackgroundColor3 = Color3.fromRGB(32, 255, 64)
			TeleportButton.TextColor3 = Color3.fromRGB(10, 20, 30)
			TeleportButton.AutoButtonColor = true
		elseif SelectedData.IsComingSoon then
			TeleportButton.Text = "SẮP RA MẮT"
			TeleportButton.BackgroundColor3 = Color3.fromRGB(30, 35, 50)
			TeleportButton.TextColor3 = Color3.fromRGB(140, 150, 170)
			TeleportButton.AutoButtonColor = false
		else
			TeleportButton.Text = string.format("YÊU CẦU CẤP %d", SelectedData.RequiredLevel)
			TeleportButton.BackgroundColor3 = Color3.fromRGB(40, 50, 70)
			TeleportButton.TextColor3 = Color3.fromRGB(255, 220, 80)
			TeleportButton.AutoButtonColor = false
		end
	end
end

local function BindControllerInput()
	pcall(function()
		ContextActionService:BindAction(ACTION_TELEPORT, function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				MapSelectorController.TeleportToSelected()
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end, false, Enum.KeyCode.Return, Enum.KeyCode.KeypadEnter, Enum.KeyCode.ButtonA)

		ContextActionService:BindAction(ACTION_CLOSE, function(_, inputState)
			if inputState == Enum.UserInputState.Begin then
				MapSelectorController.Close()
				return Enum.ContextActionResult.Sink
			end
			return Enum.ContextActionResult.Pass
		end, false, Enum.KeyCode.Escape, Enum.KeyCode.ButtonB)
	end)

	if TeleportButton then
		pcall(function()
			GuiService.SelectedObject = TeleportButton
		end)
	end
end

local function UnbindControllerInput()
	pcall(function()
		ContextActionService:UnbindAction(ACTION_TELEPORT)
		ContextActionService:UnbindAction(ACTION_CLOSE)
		if GuiService.SelectedObject and Panel and GuiService.SelectedObject:IsDescendantOf(Panel) then
			GuiService.SelectedObject = nil
		end
	end)
end

local function SetupTeleporterArch()
	if not WorkspaceFound or not Workspace then
		return
	end

	local Teleporter = Workspace:FindFirstChild("Teleporter")
	if not Teleporter then
		return
	end

	local Prompt = Teleporter:FindFirstChildWhichIsA("ProximityPrompt", true)
	if Prompt then
		local Conn = Prompt.Triggered:Connect(function(TriggerPlayer)
			if TriggerPlayer == LocalPlayer then
				MapSelectorController.Open()
			end
		end)
		table.insert(Connections, Conn)
	end

	local TouchZone = Teleporter:FindFirstChild("TeleporterTouchZone", true)
	if TouchZone and TouchZone:IsA("BasePart") then
		local Conn = TouchZone.Touched:Connect(function(Hit)
			local Char = LocalPlayer.Character
			if Char and Hit:IsDescendantOf(Char) then
				MapSelectorController.Open()
			end
		end)
		table.insert(Connections, Conn)
	end
end

--// Controller \\--

function MapSelectorController.Init()
	if Initialized then
		return
	end
	Initialized = true

	local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if RemotesFolder then
		RequestSelectMapRemote = EnsureRemote("RequestSelectMap")
	end

	local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if PlayerGui then
		ScreenGui = PlayerGui:FindFirstChild("MainHUD") :: ScreenGui?
		if ScreenGui then
			local SafeAreaRoot = ScreenGui:FindFirstChild("SafeAreaRoot")
			if SafeAreaRoot then
				OverlayHUD = SafeAreaRoot:FindFirstChild("OverlayHUD") :: Frame?
				if OverlayHUD then
					Panel = OverlayHUD:FindFirstChild("MapSelectorPanel") :: Frame?
						or OverlayHUD:FindFirstChild("WorldSelectorPanel") :: Frame?

					-- Fallback: If no panel imported yet, generate clean CDRA mockup
					if not Panel then
						Panel = CreateMockupPanel(OverlayHUD)
					end

					if Panel then
						Panel.Visible = false
						CloseButton = Panel:FindFirstChild("CloseButton", true) :: GuiButton?
						TeleportButton = Panel:FindFirstChild("TeleportButton", true) :: GuiButton?
							or Panel:FindFirstChild("World1Button", true) :: GuiButton?
						CardsContainer = Panel:FindFirstChild("CardsContainer", true) :: Frame?

						-- Tab buttons
						local TabForest = Panel:FindFirstChild("TabForest", true) :: GuiButton?
						local TabResidential = Panel:FindFirstChild("TabResidential", true) :: GuiButton?
						local TabMetropolis = Panel:FindFirstChild("TabMetropolis", true) :: GuiButton?
						if TabForest then
							TabButtons["Forest"] = TabForest
						end
						if TabResidential then
							TabButtons["Residential"] = TabResidential
						end
						if TabMetropolis then
							TabButtons["Metropolis"] = TabMetropolis
						end

						if CloseButton then
							AttachBounce(CloseButton)
						end
						if TeleportButton then
							AttachBounce(TeleportButton)
						end
						for _, btn in TabButtons do
							AttachBounce(btn)
						end
					end
				end
			end
		end
	end
end

function MapSelectorController.Start()
	if Started then
		return
	end
	MapSelectorController.Init()
	Started = true

	if not RequestSelectMapRemote then
		local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes", 5)
		if RemotesFolder then
			RequestSelectMapRemote = RemotesFolder:WaitForChild("RequestSelectMap", 5) :: RemoteEvent?
		end
	end

	-- Subscribe to UIEventBus for sidebar button clicks
	local eventConn = UIEventBus.Subscribe("SidebarButtonClicked", function(buttonName: any)
		if buttonName == "MapSelector" or buttonName == "Worlds" or buttonName == "Play" then
			MapSelectorController.Open()
		end
	end)
	table.insert(Connections, eventConn)

	if CloseButton then
		table.insert(
			Connections,
			CloseButton.Activated:Connect(function()
				MapSelectorController.Close()
			end)
		)
	end

	if TeleportButton then
		table.insert(
			Connections,
			TeleportButton.Activated:Connect(function()
				MapSelectorController.TeleportToSelected()
			end)
		)
	end

	for tabName, btn in TabButtons do
		table.insert(
			Connections,
			btn.Activated:Connect(function()
				MapSelectorController.SetTab(tabName)
			end)
		)
	end

	SetupTeleporterArch()
end

function MapSelectorController.SetTab(TabName: string)
	if MapRegistry[TabName] then
		CurrentTab = TabName
		local firstMap = MapRegistry[TabName][1]
		if firstMap then
			SelectedMapId = firstMap.MapId
		end
		Render()
	end
end

function MapSelectorController.SetSelectedMap(MapId: string)
	SelectedMapId = MapId
	Render()
end

function MapSelectorController.Open()
	IsOpen = true
	Render()
	BindControllerInput()
end

function MapSelectorController.Close()
	IsOpen = false
	UnbindControllerInput()
	Render()
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

function MapSelectorController.Toggle()
	if IsOpen then
		MapSelectorController.Close()
	else
		MapSelectorController.Open()
	end
end

function MapSelectorController.IsOpen(): boolean
	return IsOpen
end

function MapSelectorController.TeleportToSelected()
	MapSelectorController.SelectMap(SelectedMapId)
	MapSelectorController.Close()
end

function MapSelectorController.SelectMap(MapId: string?)
	local TargetMapId = MapId or SelectedMapId or "MAP1"
	if not RequestSelectMapRemote then
		RequestSelectMapRemote = EnsureRemote("RequestSelectMap")
	end
	if RequestSelectMapRemote then
		pcall(function()
			RequestSelectMapRemote:FireServer(TargetMapId)
		end)
	end
end

function MapSelectorController.Destroy()
	UnbindControllerInput()
	ClearCardConnections()

	for _, Connection in Connections do
		if typeof(Connection) == "RBXScriptConnection" then
			(Connection :: RBXScriptConnection):Disconnect()
		elseif typeof(Connection) == "table" and typeof(Connection.Disconnect) == "function" then
			Connection.Disconnect()
		end
	end
	table.clear(Connections)

	IsOpen = false
	Initialized = false
	Started = false
	RequestSelectMapRemote = nil
	ScreenGui = nil
	OverlayHUD = nil
	Panel = nil
	CloseButton = nil
	TeleportButton = nil
	CardsContainer = nil
	table.clear(TabButtons)
end

return MapSelectorController
