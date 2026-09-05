--!strict
-- RewardPopupController.luau
-- Client controller managing the post-objective Reward Choice Modal Popup.
-- Displays Free (+1 Destruction) and Paid (+3 Destruction, 29 R$) reward options.

--// Raw Requirings \\--
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Types \\--
export type RewardOption = {
	Type: string,
	Amount: number,
	Price: number?,
	Label: string?,
	ProductKey: string?,
	IsConfigured: boolean?,
}

export type RewardPopupPayload = {
	WorldId: string,
	FreeReward: RewardOption,
	PaidReward: RewardOption,
}

--// Variables \\--
local LocalPlayer = Players.LocalPlayer
local ShowRewardPopupRemote: RemoteEvent? = nil
local RequestClaimRewardRemote: RemoteEvent? = nil

local CachedPayload: RewardPopupPayload? = nil
local IsOpen = false
local Initialized = false
local Started = false
local isSettling = false

-- GUI References
local DynamicGui: ScreenGui? = nil
local ScreenGui: ScreenGui? = nil
local OverlayHUD: Frame? = nil
local Panel: Frame? = nil
local FreeButton: GuiButton? = nil
local PaidButton: GuiButton? = nil
local CloseButton: GuiButton? = nil
local FreeLabel: TextLabel? = nil
local PaidLabel: TextLabel? = nil

local Connections: { RBXScriptConnection } = {}

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

local function CreateDynamicPopup(Payload: RewardPopupPayload)
	if DynamicGui then
		DynamicGui:Destroy()
		DynamicGui = nil
	end

	local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if not PlayerGui then
		return
	end

	DynamicGui = Instance.new("ScreenGui")
	DynamicGui.Name = "RewardPopupGui"
	DynamicGui.ResetOnSpawn = false
	DynamicGui.DisplayOrder = 100
	DynamicGui.Parent = PlayerGui

	local Backdrop = Instance.new("Frame")
	Backdrop.Name = "ModalBackdrop"
	Backdrop.Size = UDim2.fromScale(1, 1)
	Backdrop.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	Backdrop.BackgroundTransparency = 0.5
	Backdrop.BorderSizePixel = 0
	Backdrop.Parent = DynamicGui

	local Modal = Instance.new("Frame")
	Modal.Name = "ModalFrame"
	Modal.AnchorPoint = Vector2.new(0.5, 0.5)
	Modal.Position = UDim2.fromScale(0.5, 0.5)
	Modal.Size = UDim2.fromOffset(420, 260)
	Modal.BackgroundColor3 = Color3.fromRGB(25, 30, 40)
	Modal.BorderSizePixel = 0
	Modal.Parent = DynamicGui

	local Corner = Instance.new("UICorner")
	Corner.CornerRadius = UDim.new(0, 12)
	Corner.Parent = Modal

	local Title = Instance.new("TextLabel")
	Title.Name = "Title"
	Title.Position = UDim2.fromOffset(0, 20)
	Title.Size = UDim2.new(1, 0, 0, 32)
	Title.BackgroundTransparency = 1
	Title.Font = Enum.Font.GothamBold
	Title.Text = "OBJECTIVE COMPLETED!"
	Title.TextColor3 = Color3.fromRGB(255, 215, 0)
	Title.TextSize = 22
	Title.Parent = Modal

	local Subtitle = Instance.new("TextLabel")
	Subtitle.Name = "Subtitle"
	Subtitle.Position = UDim2.fromOffset(0, 54)
	Subtitle.Size = UDim2.new(1, 0, 0, 22)
	Subtitle.BackgroundTransparency = 1
	Subtitle.Font = Enum.Font.Gotham
	Subtitle.Text = "Choose your Destruction reward:"
	Subtitle.TextColor3 = Color3.fromRGB(200, 200, 200)
	Subtitle.TextSize = 15
	Subtitle.Parent = Modal

	-- Free Button (Left)
	local FreeBtn = Instance.new("TextButton")
	FreeBtn.Name = "FreeRewardButton"
	FreeBtn.AnchorPoint = Vector2.new(0.5, 1)
	FreeBtn.Position = UDim2.new(0.3, 0, 1, -25)
	FreeBtn.Size = UDim2.fromOffset(160, 130)
	FreeBtn.BackgroundColor3 = Color3.fromRGB(35, 45, 60)
	FreeBtn.BorderSizePixel = 0
	FreeBtn.Font = Enum.Font.GothamBold
	local freeText = string.format("CLAIM 1X\n\n+%d Destruction\nFREE", Payload.FreeReward.Amount)
	FreeBtn.Text = freeText
	FreeBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
	FreeBtn.TextSize = 16
	FreeBtn.Parent = Modal

	local FreeCorner = Instance.new("UICorner")
	FreeCorner.CornerRadius = UDim.new(0, 8)
	FreeCorner.Parent = FreeBtn

	local FreeStroke = Instance.new("UIStroke")
	FreeStroke.Color = Color3.fromRGB(100, 180, 255)
	FreeStroke.Thickness = 2
	FreeStroke.Parent = FreeBtn

	-- Paid Button (Right)
	local PaidBtn = Instance.new("TextButton")
	PaidBtn.Name = "PaidRewardButton"
	PaidBtn.AnchorPoint = Vector2.new(0.5, 1)
	PaidBtn.Position = UDim2.new(0.7, 0, 1, -25)
	PaidBtn.Size = UDim2.fromOffset(160, 130)
	PaidBtn.BackgroundColor3 = Color3.fromRGB(55, 45, 20)
	PaidBtn.BorderSizePixel = 0
	PaidBtn.Font = Enum.Font.GothamBold
	local paidText = string.format("TRIPLE REWARD!\n\n+%d Destruction\n29 R$", Payload.PaidReward.Amount)
	PaidBtn.Text = paidText
	PaidBtn.TextColor3 = Color3.fromRGB(255, 230, 100)
	PaidBtn.TextSize = 16
	PaidBtn.Parent = Modal

	local PaidCorner = Instance.new("UICorner")
	PaidCorner.CornerRadius = UDim.new(0, 8)
	PaidCorner.Parent = PaidBtn

	local PaidStroke = Instance.new("UIStroke")
	PaidStroke.Color = Color3.fromRGB(255, 200, 0)
	PaidStroke.Thickness = 2
	PaidStroke.Parent = PaidBtn

	FreeBtn.Activated:Connect(function()
		local RewardPopupController = require(script.Parent.RewardPopupController)
		RewardPopupController.ClaimReward("Free")
	end)

	PaidBtn.Activated:Connect(function()
		local RewardPopupController = require(script.Parent.RewardPopupController)
		RewardPopupController.ClaimReward("PaidTriple")
	end)
end

local function Render(Payload: RewardPopupPayload)
	CachedPayload = Payload

	-- 1. Try to render with approved OverlayHUD panel if present
	if Panel then
		Panel.Visible = true
		if OverlayHUD then
			OverlayHUD.Visible = true
		end
		if FreeLabel then
			FreeLabel.Text = Payload.FreeReward.Label
				or string.format("+%d Destruction (Free)", Payload.FreeReward.Amount)
		end
		if PaidLabel then
			PaidLabel.Text = Payload.PaidReward.Label
				or string.format("+%d Destruction (29 R$)", Payload.PaidReward.Amount)
		end
		return
	end

	-- 2. Fallback to clean dynamic popup modal
	CreateDynamicPopup(Payload)
end

--// Controller \\--
local RewardPopupController = {}

function RewardPopupController.Init()
	if Initialized then
		return
	end
	Initialized = true

	local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if RemotesFolder then
		ShowRewardPopupRemote = EnsureRemote("ShowRewardPopup")
		RequestClaimRewardRemote = EnsureRemote("RequestClaimReward")
	end

	local PlayerGui = LocalPlayer:FindFirstChild("PlayerGui")
	if PlayerGui then
		ScreenGui = PlayerGui:FindFirstChild("MainHUD") :: ScreenGui?
		if ScreenGui then
			local SafeAreaRoot = ScreenGui:FindFirstChild("SafeAreaRoot")
			if SafeAreaRoot then
				OverlayHUD = SafeAreaRoot:FindFirstChild("OverlayHUD") :: Frame?
				if OverlayHUD then
					Panel = OverlayHUD:FindFirstChild("RewardPopupPanel") :: Frame?
						or OverlayHUD:FindFirstChild("RewardChoicePanel") :: Frame?
					if Panel then
						Panel.Visible = false
						FreeButton = (
							Panel:FindFirstChild("FreeButton", true) or Panel:FindFirstChild("FreeRewardButton", true)
						) :: GuiButton?
						PaidButton = (
							Panel:FindFirstChild("PaidButton", true) or Panel:FindFirstChild("PaidRewardButton", true)
						) :: GuiButton?
						CloseButton = Panel:FindFirstChild("CloseButton", true) :: GuiButton?
						if CloseButton then
							CloseButton.Visible = false
						end
						FreeLabel = Panel:FindFirstChild("FreeLabel", true) :: TextLabel?
						PaidLabel = Panel:FindFirstChild("PaidLabel", true) :: TextLabel?
					end
				end
			end
		end
	end
end

function RewardPopupController.Start()
	if Started then
		return
	end
	RewardPopupController.Init()
	Started = true

	if not ShowRewardPopupRemote or not RequestClaimRewardRemote then
		local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes", 5)
		if RemotesFolder then
			ShowRewardPopupRemote = RemotesFolder:WaitForChild("ShowRewardPopup", 5) :: RemoteEvent?
			RequestClaimRewardRemote = RemotesFolder:WaitForChild("RequestClaimReward", 5) :: RemoteEvent?
		end
	end

	if ShowRewardPopupRemote then
		table.insert(
			Connections,
			ShowRewardPopupRemote.OnClientEvent:Connect(function(Payload: RewardPopupPayload)
				RewardPopupController.Show(Payload)
			end)
		)
	end

	if FreeButton then
		table.insert(
			Connections,
			FreeButton.Activated:Connect(function()
				RewardPopupController.ClaimReward("Free")
			end)
		)
	end

	if PaidButton then
		table.insert(
			Connections,
			PaidButton.Activated:Connect(function()
				RewardPopupController.ClaimReward("PaidTriple")
			end)
		)
	end

	if CloseButton then
		table.insert(
			Connections,
			CloseButton.Activated:Connect(function()
				RewardPopupController.ClaimReward("Free")
			end)
		)
	end
end

function RewardPopupController.Show(Payload: RewardPopupPayload)
	IsOpen = true
	Render(Payload)
end

function RewardPopupController.ClaimReward(Choice: string)
	if isSettling then
		return
	end
	isSettling = true
	if not RequestClaimRewardRemote then
		RequestClaimRewardRemote = EnsureRemote("RequestClaimReward")
	end
	if RequestClaimRewardRemote then
		pcall(function()
			RequestClaimRewardRemote:FireServer(Choice)
		end)
	end
	RewardPopupController.Close()
	isSettling = false
end

function RewardPopupController.Close()
	if IsOpen and not isSettling then
		-- Mandatory selection loop: closing automatically defaults to Claim Free
		RewardPopupController.ClaimReward("Free")
		return
	end
	IsOpen = false
	if DynamicGui then
		DynamicGui:Destroy()
		DynamicGui = nil
	end
	if Panel then
		Panel.Visible = false
	end
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

function RewardPopupController.IsOpen(): boolean
	return IsOpen
end

function RewardPopupController.GetCachedRewardData(): RewardPopupPayload?
	return CachedPayload
end

function RewardPopupController.Destroy()
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

	IsOpen = false
	Initialized = false
	Started = false
	isSettling = false
	CachedPayload = nil
	ShowRewardPopupRemote = nil
	RequestClaimRewardRemote = nil
	ScreenGui = nil
	OverlayHUD = nil
	Panel = nil
	FreeButton = nil
	PaidButton = nil
	CloseButton = nil
	FreeLabel = nil
	PaidLabel = nil
end

return RewardPopupController
