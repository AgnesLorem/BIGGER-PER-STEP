--!strict
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sessions = require(script.Parent.Parent.Registry.RuntimeRegistry.Sessions)
local EventBus = require(script.Parent.Parent.Events.EventBus)
local Logger = require(script.Parent.Parent.Utilities.Logger)
local ScaleCurve = require(ReplicatedStorage.BiggerShared.Core.Utilities.ScaleCurve)
local ScaleConfig = require(ReplicatedStorage.BiggerShared.Core.Config.ScaleConfig)

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

local function OnCharacterAdded(Player: Player, Character: Model)
	local Session = Sessions.Get(Player)
	local Bigger = Session and Session.Bigger or 1
	ApplyScale(Player, Character, Bigger)
end

local function OnPlayerAdded(Player: Player)
	Player.CharacterAdded:Connect(function(Character)
		OnCharacterAdded(Player, Character)
	end)
	if Player.Character then
		task.spawn(OnCharacterAdded, Player, Player.Character)
	end
end

--// Service \\--
local CharacterScaleService = {}

function CharacterScaleService:Init()
	EventBus.Subscribe("BiggerChanged", OnBiggerChanged)
	Players.PlayerAdded:Connect(OnPlayerAdded)
end

function CharacterScaleService:Start()
	for _, Player in Players:GetPlayers() do
		task.spawn(OnPlayerAdded, Player)
	end
end

return CharacterScaleService
