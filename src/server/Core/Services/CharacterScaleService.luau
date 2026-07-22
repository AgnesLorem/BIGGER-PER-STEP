--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sessions = require(script.Parent.Parent.Registry.RuntimeRegistry.Sessions)
local EventBus = require(script.Parent.Parent.Events.EventBus)
local Logger = require(script.Parent.Parent.Utilities.Logger)
local ScaleCurve = require(ReplicatedStorage.BiggerShared.Core.Utilities.ScaleCurve)
local ScaleConfig = require(ReplicatedStorage.BiggerShared.Core.Config.ScaleConfig)

local PlayerConnections: { [Player]: { RBXScriptConnection } } = {}
local Initialized = false

local function ApplyScale(Player: Player, Character: Model, Bigger: number)
	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then
		return
	end

	Humanoid.AutomaticScalingEnabled = true

	local BodyHeight = Humanoid:WaitForChild("BodyHeightScale", 5) :: NumberValue?
	local BodyWidth = Humanoid:WaitForChild("BodyWidthScale", 5) :: NumberValue?
	local BodyDepth = Humanoid:WaitForChild("BodyDepthScale", 5) :: NumberValue?
	local HeadScale = Humanoid:WaitForChild("HeadScale", 5) :: NumberValue?

	if not BodyHeight or not BodyWidth or not BodyDepth or not HeadScale then
		Logger.Warn("Scale", "Scaling values missing on character for player %s", Player.Name)
		return
	end

	local VisualScale = ScaleCurve.GetVisualScale(Bigger, ScaleConfig.Formula, ScaleConfig.CurveParameter)
	VisualScale = math.clamp(VisualScale, ScaleConfig.MinVisualScale, ScaleConfig.MaxVisualScale)

	BodyHeight.Value = VisualScale
	BodyWidth.Value = VisualScale
	BodyDepth.Value = VisualScale
	HeadScale.Value = VisualScale

	Logger.Info("Scale", "Applied scale %f (Bigger = %f) to player %s on Server", VisualScale, Bigger, Player.Name)
end

local function OnBiggerChanged(Player: Player, NewValue: number)
	local Character = Player.Character
	if Character then
		ApplyScale(Player, Character, NewValue)
	end
end

local function DisconnectPlayer(Player: Player)
	local Connections = PlayerConnections[Player]
	if not Connections then
		return
	end
	for _, Connection in Connections do
		Connection:Disconnect()
	end
	PlayerConnections[Player] = nil
end

local function CreateVipTag(Player: Player, Character: Model)
	local Head = Character:WaitForChild("Head", 5) :: BasePart?
	if not Head then
		return
	end

	local existing = Head:FindFirstChild("VipTag")
	if existing then
		existing:Destroy()
	end

	local session = Sessions.Get(Player)
	if not session or not session.HasVip then
		return
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "VipTag"
	billboard.Size = UDim2.new(0, 150, 0, 50)
	billboard.StudsOffset = Vector3.new(0, 3.5, 0)
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.FredokaOne
	label.Text = "★ VIP ★"
	label.TextColor3 = Color3.fromRGB(255, 255, 255)
	label.TextSize = 24

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(0, 0, 0)
	stroke.Thickness = 2.5
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = label

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
		ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 127, 0)),
		ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 255, 0)),
		ColorSequenceKeypoint.new(0.6, Color3.fromRGB(0, 255, 0)),
		ColorSequenceKeypoint.new(0.8, Color3.fromRGB(0, 0, 255)),
		ColorSequenceKeypoint.new(1, Color3.fromRGB(139, 0, 255)),
	})
	gradient.Parent = label

	label.Parent = billboard
	billboard.Parent = Head
end

local function OnCharacterAdded(Player: Player, Character: Model)
	local Session = Sessions.Get(Player)
	local Bigger = Session and Session.Bigger or 1
	ApplyScale(Player, Character, Bigger)
	CreateVipTag(Player, Character)
end

local function OnCharacterAppearanceLoaded(Player: Player, Character: Model)
	if Player.Character ~= Character then
		return
	end
	OnCharacterAdded(Player, Character)
end

local function OnPlayerAdded(Player: Player)
	if PlayerConnections[Player] then
		return
	end
	PlayerConnections[Player] = {
		Player.CharacterAdded:Connect(function(Character)
			OnCharacterAdded(Player, Character)
		end),
		Player.CharacterAppearanceLoaded:Connect(function(Character)
			OnCharacterAppearanceLoaded(Player, Character)
		end),
	}
	if Player.Character then
		task.spawn(OnCharacterAdded, Player, Player.Character)
	end
end

--// Service \\--
local CharacterScaleService = {}

function CharacterScaleService:UpdateVipTag(Player: Player)
	local Character = Player.Character
	if Character then
		CreateVipTag(Player, Character)
	end
end

function CharacterScaleService:Init()
	if Initialized then
		return
	end
	Initialized = true
	EventBus.Subscribe("BiggerChanged", OnBiggerChanged)
	Players.PlayerAdded:Connect(OnPlayerAdded)
	Players.PlayerRemoving:Connect(DisconnectPlayer)
end

function CharacterScaleService:Start()
	for _, Player in Players:GetPlayers() do
		task.spawn(OnPlayerAdded, Player)
	end
end

return CharacterScaleService
