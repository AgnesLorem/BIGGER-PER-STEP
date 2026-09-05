--!strict
-- CharacterScaleController.luau
-- Client controller observing character visual scale and dynamically lerping camera zoom limits.

--// Raw Requirings \\--
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

--// Requirings \\--
local ScaleCurve = require(
	ReplicatedStorage:WaitForChild("BiggerShared")
		:WaitForChild("Core")
		:WaitForChild("Utilities")
		:WaitForChild("ScaleCurve")
)
local ScaleConfig = require(
	ReplicatedStorage:WaitForChild("BiggerShared")
		:WaitForChild("Core")
		:WaitForChild("Config")
		:WaitForChild("ScaleConfig")
)

--// Constants \\--
local BASE_MIN_ZOOM = 0.5
local BASE_MAX_ZOOM = 128
local LERP_SPEED = 10

--// Variables \\--
local LocalPlayer = Players.LocalPlayer
local CharacterScaleController = {}

local currentMinZoom = BASE_MIN_ZOOM
local currentMaxZoom = BASE_MAX_ZOOM
local targetMinZoom = BASE_MIN_ZOOM
local targetMaxZoom = BASE_MAX_ZOOM
local renderConnection: RBXScriptConnection? = nil
local charAttrConnection: RBXScriptConnection? = nil
local currentHumanoid: Humanoid? = nil
local currentAnimator: Animator? = nil
local animPlayedConnection: RBXScriptConnection? = nil
local humanoidChildConnection: RBXScriptConnection? = nil
local charChildConnection: RBXScriptConnection? = nil

--// Helpers \\--
local function CalculateVisualScale(): number
	local attrScale = LocalPlayer:GetAttribute("VisualScale")
	if typeof(attrScale) == "number" and attrScale > 0 then
		return attrScale
	end

	local char = LocalPlayer.Character
	if char then
		local charScale = char:GetAttribute("VisualScale")
		if typeof(charScale) == "number" and charScale > 0 then
			return charScale
		end
	end

	local bigger = LocalPlayer:GetAttribute("Bigger") or 1
	local rawScale = ScaleCurve.GetVisualScale(bigger, ScaleConfig.Formula, ScaleConfig.CurveParameter)
	return math.clamp(rawScale, ScaleConfig.MinVisualScale, ScaleConfig.MaxVisualScale)
end

local function IsLocomotionTrack(track: AnimationTrack): boolean
	local trackName = track.Name:lower()
	if string.find(trackName, "walk") or string.find(trackName, "run") or string.find(trackName, "stride") then
		return true
	end
	local anim = track.Animation
	if anim then
		local animName = anim.Name:lower()
		if string.find(animName, "walk") or string.find(animName, "run") or string.find(animName, "stride") then
			return true
		end
	end
	return false
end

local function UpdateStrideCadence()
	if not currentHumanoid or not currentAnimator then
		return
	end
	local visualScale = CalculateVisualScale()
	if visualScale <= 0 then
		return
	end
	local walkSpeed = currentHumanoid.WalkSpeed
	local targetAnimSpeed = walkSpeed / (16 * visualScale)

	for _, track in currentAnimator:GetPlayingAnimationTracks() do
		if IsLocomotionTrack(track) then
			if math.abs(track.Speed - targetAnimSpeed) > 0.02 then
				track:AdjustSpeed(targetAnimSpeed)
			end
		end
	end
end

local function HookAnimator(animator: Animator)
	currentAnimator = animator
	if animPlayedConnection then
		animPlayedConnection:Disconnect()
		animPlayedConnection = nil
	end
	animPlayedConnection = animator.AnimationPlayed:Connect(function(track)
		if IsLocomotionTrack(track) and currentHumanoid then
			local visualScale = CalculateVisualScale()
			if visualScale > 0 then
				local targetAnimSpeed = currentHumanoid.WalkSpeed / (16 * visualScale)
				track:AdjustSpeed(targetAnimSpeed)
			end
		end
	end)
end

local function CleanupCharacterHooks()
	if charAttrConnection then
		charAttrConnection:Disconnect()
		charAttrConnection = nil
	end
	if animPlayedConnection then
		animPlayedConnection:Disconnect()
		animPlayedConnection = nil
	end
	if humanoidChildConnection then
		humanoidChildConnection:Disconnect()
		humanoidChildConnection = nil
	end
	if charChildConnection then
		charChildConnection:Disconnect()
		charChildConnection = nil
	end
	currentHumanoid = nil
	currentAnimator = nil
end

local function UpdateTargetZoom()
	local visualScale = CalculateVisualScale()
	targetMinZoom = BASE_MIN_ZOOM * visualScale
	targetMaxZoom = math.max(BASE_MAX_ZOOM, BASE_MAX_ZOOM * visualScale)
end

local function OnScaleChanged()
	UpdateTargetZoom()
	UpdateStrideCadence()
end

local function OnRenderStep(dt: number)
	local t = math.clamp(dt * LERP_SPEED, 0, 1)
	local newMin = currentMinZoom + (targetMinZoom - currentMinZoom) * t
	local newMax = currentMaxZoom + (targetMaxZoom - currentMaxZoom) * t

	if math.abs(newMin - targetMinZoom) < 0.005 then
		newMin = targetMinZoom
	end
	if math.abs(newMax - targetMaxZoom) < 0.005 then
		newMax = targetMaxZoom
	end

	newMin = math.min(newMin, newMax)

	-- Ordering protection:
	-- If zooming out (expanding limits), set Max before Min.
	-- If zooming in (shrinking limits), set Min before Max.
	if newMax >= currentMaxZoom then
		LocalPlayer.CameraMaxZoomDistance = newMax
		LocalPlayer.CameraMinZoomDistance = newMin
	else
		LocalPlayer.CameraMinZoomDistance = newMin
		LocalPlayer.CameraMaxZoomDistance = math.max(newMax, newMin)
	end

	currentMinZoom = newMin
	currentMaxZoom = newMax
end

local function HookCharacter(character: Model)
	CleanupCharacterHooks()

	charAttrConnection = character:GetAttributeChangedSignal("VisualScale"):Connect(OnScaleChanged)
	OnScaleChanged()

	local function OnHumanoidFound(humanoid: Humanoid)
		currentHumanoid = humanoid
		local animator = humanoid:FindFirstChildOfClass("Animator")
		if animator then
			HookAnimator(animator)
		else
			humanoidChildConnection = humanoid.ChildAdded:Connect(function(child)
				if child:IsA("Animator") then
					if humanoidChildConnection then
						humanoidChildConnection:Disconnect()
						humanoidChildConnection = nil
					end
					HookAnimator(child)
				end
			end)
		end
		UpdateStrideCadence()
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		OnHumanoidFound(humanoid)
	else
		charChildConnection = character.ChildAdded:Connect(function(child)
			if child:IsA("Humanoid") then
				if charChildConnection then
					charChildConnection:Disconnect()
					charChildConnection = nil
				end
				OnHumanoidFound(child)
			end
		end)
	end
end

--// Service \\--
function CharacterScaleController.Init()
	UpdateTargetZoom()
	currentMinZoom = targetMinZoom
	currentMaxZoom = targetMaxZoom

	LocalPlayer.CameraMaxZoomDistance = targetMaxZoom
	LocalPlayer.CameraMinZoomDistance = math.min(targetMinZoom, targetMaxZoom)
end

function CharacterScaleController.Start()
	LocalPlayer:GetAttributeChangedSignal("VisualScale"):Connect(OnScaleChanged)
	LocalPlayer:GetAttributeChangedSignal("Bigger"):Connect(OnScaleChanged)

	LocalPlayer.CharacterAdded:Connect(HookCharacter)
	LocalPlayer.CharacterRemoving:Connect(CleanupCharacterHooks)
	if LocalPlayer.Character then
		HookCharacter(LocalPlayer.Character)
	end

	if not renderConnection then
		renderConnection = RunService.RenderStepped:Connect(OnRenderStep)
	end
end

return CharacterScaleController
