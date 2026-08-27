--!strict
-- VFXController: Impact and celebration particle effects.
-- Stomp shockwave, Rebirth burst, Level Up sparkle.

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

local LocalPlayer = Players.LocalPlayer
local Connections: { RBXScriptConnection } = {}
local ActiveEffects: { Instance } = {}
local MaxConcurrentEffects = 2
local Initialized = false
local Started = false

local VFXController = {}

local function GetVisualScale(): number
	local bigger = LocalPlayer:GetAttribute("Bigger") or 0
	if type(bigger) ~= "number" or bigger <= 0 then
		return 1
	end
	local level = math.floor(math.sqrt(bigger / 1.66205)) + 1
	return 1 + 0.080739 * math.max(0, level - 1) ^ 0.8299
end

local function GetCharacterRoot(): BasePart?
	local char = LocalPlayer.Character
	if not char then
		return nil
	end
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function CleanupOldest()
	while #ActiveEffects >= MaxConcurrentEffects do
		local oldest = table.remove(ActiveEffects, 1)
		if oldest and oldest.Parent then
			oldest:Destroy()
		end
	end
end

local function CreateStompShockwave()
	local root = GetCharacterRoot()
	if not root then
		return
	end

	CleanupOldest()

	local scale = GetVisualScale()
	local part = Instance.new("Part")
	part.Name = "StompVFX"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.CFrame = CFrame.new(root.Position.X, root.Position.Y - (root.Size.Y / 2), root.Position.Z)

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(180, 150, 100))
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, scale * 2),
		NumberSequenceKeypoint.new(1, scale * 6),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.4, 0.8)
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(math.min(scale * 3, 15))
	emitter.SpreadAngle = Vector2.new(180, 0)
	emitter.Parent = part

	part.Parent = workspace
	emitter:Emit(math.min(math.floor(scale * 8), 50))

	table.insert(ActiveEffects, part)
	Debris:AddItem(part, 1.5)
end

local function CreateRebirthBurst()
	local root = GetCharacterRoot()
	if not root then
		return
	end

	CleanupOldest()

	local part = Instance.new("Part")
	part.Name = "RebirthVFX"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.CFrame = root.CFrame

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 215, 0), Color3.fromRGB(255, 100, 0))
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 4),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.8, 1.5)
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(15, 25)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = part

	part.Parent = workspace
	emitter:Emit(40)

	table.insert(ActiveEffects, part)
	Debris:AddItem(part, 2.5)
end

local function CreateLevelUpSparkle()
	local root = GetCharacterRoot()
	if not root then
		return
	end

	CleanupOldest()

	local part = Instance.new("Part")
	part.Name = "LevelUpVFX"
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.CFrame = root.CFrame

	local emitter = Instance.new("ParticleEmitter")
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 255, 100))
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Lifetime = NumberRange.new(0.3, 0.6)
	emitter.Rate = 0
	emitter.Speed = NumberRange.new(5, 10)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = part

	part.Parent = workspace
	emitter:Emit(15)

	table.insert(ActiveEffects, part)
	Debris:AddItem(part, 1.0)
end

function VFXController.Init()
	if Initialized then
		return
	end
	Initialized = true
end

function VFXController.Start()
	if Started then
		return
	end
	Started = true

	local wasActive = LocalPlayer:GetAttribute("ObjectiveActive")
	local activeState = if type(wasActive) == "boolean" then wasActive else false
	table.insert(
		Connections,
		LocalPlayer:GetAttributeChangedSignal("ObjectiveActive"):Connect(function()
			local active = LocalPlayer:GetAttribute("ObjectiveActive")
			local newActiveState = if type(active) == "boolean" then active else false
			if activeState and not newActiveState then
				CreateStompShockwave()
			end
			activeState = newActiveState
		end)
	)

	table.insert(
		Connections,
		LocalPlayer:GetAttributeChangedSignal("Rebirth"):Connect(function()
			CreateRebirthBurst()
		end)
	)

	table.insert(
		Connections,
		LocalPlayer:GetAttributeChangedSignal("Level"):Connect(function()
			CreateLevelUpSparkle()
		end)
	)
end

function VFXController.Destroy()
	for _, conn in Connections do
		conn:Disconnect()
	end
	table.clear(Connections)
	for _, effect in ActiveEffects do
		if effect.Parent then
			effect:Destroy()
		end
	end
	table.clear(ActiveEffects)
	Initialized = false
	Started = false
end

return VFXController
