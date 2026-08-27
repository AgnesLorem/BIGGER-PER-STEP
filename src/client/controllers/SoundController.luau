--!strict
---/// Content \\\---
-- SoundController.luau

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local SoundConfig = require(
	ReplicatedStorage:WaitForChild("BiggerShared")
		:WaitForChild("Core")
		:WaitForChild("Config")
		:WaitForChild("SoundConfig")
)
local LocalPlayer = Players.LocalPlayer

local SoundController = {}
local Initialized = false
local Started = false
local Connections: { RBXScriptConnection } = {}
local Sounds: { [string]: Sound } = {}

local function GetVisualScale(): number
	local bigger = LocalPlayer:GetAttribute("Bigger")
	local b = if type(bigger) == "number" then bigger else 0
	local level = math.floor(math.sqrt(b / 1.66205)) + 1
	return 1 + 0.080739 * math.max(0, level - 1) ^ 0.8299
end

local function PlaySound(name: string, dynamicPitch: boolean?)
	local sound = Sounds[name]
	if not sound then
		return
	end

	if dynamicPitch then
		local visualScale = GetVisualScale()
		sound.PlaybackSpeed = math.clamp(1.0 - (visualScale - 1) * 0.004, 0.4, 1.0)
	end

	sound:Play()
end

function SoundController.Init()
	if Initialized then
		return
	end
	Initialized = true

	for name, config in pairs(SoundConfig :: any) do
		if config.AssetId ~= 0 then
			local sound = Instance.new("Sound")
			sound.Name = name
			sound.SoundId = "rbxassetid://" .. tostring(config.AssetId)
			sound.Volume = config.Volume or 0.5
			sound.Parent = SoundService
			Sounds[name] = sound
		end
	end
end

function SoundController.Start()
	if Started then
		return
	end
	Started = true

	-- StompImpact
	local wasActive = LocalPlayer:GetAttribute("ObjectiveActive")
	local activeState = if type(wasActive) == "boolean" then wasActive else false
	table.insert(
		Connections,
		LocalPlayer:GetAttributeChangedSignal("ObjectiveActive"):Connect(function()
			local active = LocalPlayer:GetAttribute("ObjectiveActive")
			local newActiveState = if type(active) == "boolean" then active else false
			if activeState and not newActiveState then
				PlaySound("StompImpact", true)
			end
			activeState = newActiveState
		end)
	)

	-- LevelUp
	table.insert(
		Connections,
		LocalPlayer:GetAttributeChangedSignal("Level"):Connect(function()
			PlaySound("LevelUp")
		end)
	)

	-- Rebirth
	table.insert(
		Connections,
		LocalPlayer:GetAttributeChangedSignal("Rebirth"):Connect(function()
			PlaySound("Rebirth")
		end)
	)

	-- AuraActivate
	table.insert(
		Connections,
		LocalPlayer:GetAttributeChangedSignal("EquippedAura"):Connect(function()
			local aura = LocalPlayer:GetAttribute("EquippedAura")
			if type(aura) == "string" and aura ~= "None" then
				PlaySound("AuraActivate")
			end
		end)
	)
end

function SoundController.Destroy()
	for _, conn in Connections do
		conn:Disconnect()
	end
	table.clear(Connections)

	for _, sound in pairs(Sounds) do
		sound:Destroy()
	end
	table.clear(Sounds)

	Initialized = false
	Started = false
end

return SoundController
