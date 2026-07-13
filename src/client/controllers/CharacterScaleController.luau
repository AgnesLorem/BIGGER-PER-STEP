--!strict

--// Raw Requirings \\--
local TweenService = game:GetService("TweenService")
local Players = game:GetService("Players")
local LocalPlayer = Players.LocalPlayer

--// Requirings \\--
local ScaleConfig = require(script.Parent.Parent.config.ScaleConfig)
local ScaleCurve = require(
	game:GetService("ReplicatedStorage")
		:WaitForChild("BiggerShared")
		:WaitForChild("Core")
		:WaitForChild("Utilities")
		:WaitForChild("ScaleCurve")
)

--// Variables \\--
local ActiveTween: Tween? = nil
local AttributeConnection: RBXScriptConnection? = nil
local CharacterConnection: RBXScriptConnection? = nil

--// Helpers \\--
local function ApplyScale(Character: Model)
	if not Character or not Character.Parent then
		return
	end

	local Bigger: number = LocalPlayer:GetAttribute("Bigger") or 1
	local VisualScale: number = ScaleCurve.GetVisualScale(Bigger, ScaleConfig.Formula, ScaleConfig.CurveParameter)
	VisualScale = math.clamp(VisualScale, ScaleConfig.MinVisualScale, ScaleConfig.MaxVisualScale)

	local Humanoid = Character:FindFirstChildOfClass("Humanoid")
	if not Humanoid then
		return
	end

	if ActiveTween then
		ActiveTween:Cancel()
	end

	local BodyHeight = Humanoid:FindFirstChild("BodyHeightScale") :: NumberValue?
	local BodyWidth = Humanoid:FindFirstChild("BodyWidthScale") :: NumberValue?
	local BodyDepth = Humanoid:FindFirstChild("BodyDepthScale") :: NumberValue?
	local HeadScale = Humanoid:FindFirstChild("HeadScale") :: NumberValue?
	if not BodyHeight or not BodyWidth or not BodyDepth or not HeadScale then
		return
	end

	local Info = TweenInfo.new(ScaleConfig.TweenTime, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
	local Goal = { Value = VisualScale }

	local TweenHeight = TweenService:Create(BodyHeight, Info, Goal)
	local TweenWidth = TweenService:Create(BodyWidth, Info, Goal)
	local TweenDepth = TweenService:Create(BodyDepth, Info, Goal)
	local TweenHead = TweenService:Create(HeadScale, Info, Goal)

	ActiveTween = TweenHeight

	TweenHeight:Play()
	TweenWidth:Play()
	TweenDepth:Play()
	TweenHead:Play()
end

local function OnCharacterAdded(Character: Model)
	if AttributeConnection then
		AttributeConnection:Disconnect()
	end

	AttributeConnection = LocalPlayer:GetAttributeChangedSignal("Bigger"):Connect(function()
		ApplyScale(Character)
	end)

	ApplyScale(Character)
end

local function SetupPlayer()
	if CharacterConnection then
		CharacterConnection:Disconnect()
	end

	CharacterConnection = LocalPlayer.CharacterAdded:Connect(OnCharacterAdded)

	local ExistingCharacter = LocalPlayer.Character
	if ExistingCharacter then
		OnCharacterAdded(ExistingCharacter)
	end
end

--// Service \\--
local CharacterScaleController = {}

function CharacterScaleController.Init() end

function CharacterScaleController.Start()
	SetupPlayer()
end

return CharacterScaleController
