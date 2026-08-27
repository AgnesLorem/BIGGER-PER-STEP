--!strict
-- CameraShakeController: Scale-adaptive camera shake for stomp, rebirth, level up.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer
local ShakeQueue: { { Magnitude: number, Duration: number, Frequency: number, StartTime: number } } = {}
local RenderConnection: RBXScriptConnection? = nil
local Connections: { RBXScriptConnection } = {}
local Initialized = false
local Started = false

local CameraShakeController = {}

local function GetVisualScale(): number
	local bigger = LocalPlayer:GetAttribute("Bigger") or 0
	-- Approximate visual scale from Bigger using the power curve
	local level = math.floor(math.sqrt(bigger / 1.66205)) + 1
	return 1 + 0.080739 * math.max(0, level - 1) ^ 0.8299
end

local function AddShake(Magnitude: number, Duration: number, Frequency: number)
	table.insert(ShakeQueue, {
		Magnitude = Magnitude,
		Duration = Duration,
		Frequency = Frequency,
		StartTime = os.clock(),
	})
	-- Cap at 3 concurrent shakes
	while #ShakeQueue > 3 do
		table.remove(ShakeQueue, 1)
	end
end

function CameraShakeController.Init()
	if Initialized then
		return
	end
	Initialized = true

	RenderConnection = RunService.RenderStepped:Connect(function(_dt)
		local camera = workspace.CurrentCamera
		if not camera then
			return
		end

		local now = os.clock()
		local totalOffset = Vector3.zero
		local i = 1
		while i <= #ShakeQueue do
			local shake = ShakeQueue[i]
			local elapsed = now - shake.StartTime
			if elapsed >= shake.Duration then
				table.remove(ShakeQueue, i)
			else
				local decay = 1 - (elapsed / shake.Duration)
				local offset = math.sin(elapsed * shake.Frequency * math.pi * 2) * shake.Magnitude * decay
				totalOffset = totalOffset
					+ Vector3.new(offset * (math.random() - 0.5) * 2, offset, offset * (math.random() - 0.5) * 2)
				i += 1
			end
		end

		if totalOffset.Magnitude > 0.001 then
			camera.CFrame = camera.CFrame + totalOffset
		end
	end)
end

function CameraShakeController.Start()
	if Started then
		return
	end
	Started = true

	-- Stomp shake: triggered when ObjectiveActive goes to false after being true
	local wasActive = LocalPlayer:GetAttribute("ObjectiveActive") or false
	table.insert(
		Connections,
		LocalPlayer:GetAttributeChangedSignal("ObjectiveActive"):Connect(function()
			local active = LocalPlayer:GetAttribute("ObjectiveActive")
			if wasActive and not active then
				local scale = GetVisualScale()
				AddShake(math.min(scale * 0.15, 3.0), 0.35, 20)
			end
			wasActive = active
		end)
	)

	-- Rebirth shake
	table.insert(
		Connections,
		LocalPlayer:GetAttributeChangedSignal("Rebirth"):Connect(function()
			AddShake(2.0, 0.6, 15)
		end)
	)

	-- Level up shake (subtle)
	table.insert(
		Connections,
		LocalPlayer:GetAttributeChangedSignal("Level"):Connect(function()
			AddShake(0.3, 0.2, 25)
		end)
	)
end

function CameraShakeController.Destroy()
	if RenderConnection then
		RenderConnection:Disconnect()
		RenderConnection = nil
	end
	for _, conn in Connections do
		conn:Disconnect()
	end
	table.clear(Connections)
	table.clear(ShakeQueue)
	Initialized = false
	Started = false
end

return CameraShakeController
