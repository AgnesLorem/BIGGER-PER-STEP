--!strict
---/// Content \\\---
-- FloatingFeedbackController.luau

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local LocalPlayer = Players.LocalPlayer

local FloatingFeedbackController = {}
local Initialized = false
local Started = false
local Connections: { RBXScriptConnection } = {}

local Pool: { BillboardGui } = {}
local Active: { BillboardGui } = {}

local BiggerAccumulator = 0
local LastBiggerTime = 0
local LastBiggerValue = -1

local function GetCharacterPrimaryPart(): BasePart?
	local character = LocalPlayer.Character
	if not character then
		return nil
	end
	return character.PrimaryPart or character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function CreateFeedbackGui(): BillboardGui
	local bgui = Instance.new("BillboardGui")
	bgui.Size = UDim2.fromOffset(200, 50)
	bgui.AlwaysOnTop = true
	bgui.MaxDistance = 100
	bgui.Enabled = false

	local textLabel = Instance.new("TextLabel")
	textLabel.Name = "Text"
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.BackgroundTransparency = 1
	textLabel.TextScaled = true
	textLabel.Font = Enum.Font.GothamBold
	textLabel.Parent = bgui

	local uiStroke = Instance.new("UIStroke")
	uiStroke.Parent = textLabel
	uiStroke.Thickness = 2
	uiStroke.Color = Color3.new(0, 0, 0)

	return bgui
end

local function ShowFeedback(text: string, color: Color3, duration: number, popScale: number)
	local part = GetCharacterPrimaryPart()
	if not part then
		return
	end

	local bgui = table.remove(Pool)
	if not bgui then
		if #Active > 0 then
			bgui = table.remove(Active, 1)
		else
			return
		end
	end

	if not bgui then
		return
	end

	local textLabel = bgui:FindFirstChild("Text") :: TextLabel
	if not textLabel then
		return
	end

	table.insert(Active, bgui)

	textLabel.Text = text
	textLabel.TextColor3 = color
	textLabel.TextTransparency = 0
	local uiStroke = textLabel:FindFirstChildOfClass("UIStroke")
	if uiStroke then
		uiStroke.Transparency = 0
	end

	local uiScale = textLabel:FindFirstChildOfClass("UIScale")
	if not uiScale then
		uiScale = Instance.new("UIScale")
		uiScale.Parent = textLabel
	end
	uiScale.Scale = popScale

	bgui.StudsOffsetWorldSpace =
		Vector3.new((math.random() - 0.5) * 4, 2 + math.random() * 2, (math.random() - 0.5) * 4)
	bgui.Parent = part
	bgui.Enabled = true
	bgui.Adornee = part

	local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

	local yTween = TweenService:Create(bgui, tweenInfo, {
		StudsOffsetWorldSpace = bgui.StudsOffsetWorldSpace + Vector3.new(0, 3, 0),
	})

	local textTween = TweenService:Create(textLabel, tweenInfo, {
		TextTransparency = 1,
	})

	local strokeTween = nil
	if uiStroke then
		strokeTween = TweenService:Create(uiStroke, tweenInfo, {
			Transparency = 1,
		})
	end

	local scaleTween =
		TweenService:Create(uiScale, TweenInfo.new(duration * 0.3, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), {
			Scale = 1.0,
		})

	yTween:Play()
	textTween:Play()
	if strokeTween then
		strokeTween:Play()
	end
	scaleTween:Play()

	task.delay(duration, function()
		if not Started then
			return
		end
		local idx = table.find(Active, bgui)
		if idx then
			table.remove(Active, idx)
			bgui.Enabled = false
			bgui.Parent = nil
			table.insert(Pool, bgui)
		end
	end)
end

function FloatingFeedbackController.Init()
	if Initialized then
		return
	end
	Initialized = true

	for _ = 1, 8 do
		table.insert(Pool, CreateFeedbackGui())
	end
end

function FloatingFeedbackController.Start()
	if Started then
		return
	end
	Started = true

	local currentBigger = LocalPlayer:GetAttribute("Bigger")
	LastBiggerValue = if type(currentBigger) == "number" then currentBigger else 0

	table.insert(
		Connections,
		RunService.Heartbeat:Connect(function()
			if BiggerAccumulator > 0 and os.clock() - LastBiggerTime >= 1.0 then
				ShowFeedback("+" .. tostring(BiggerAccumulator) .. " BIGGER", Color3.fromRGB(255, 215, 0), 1.0, 1.2)
				BiggerAccumulator = 0
			end
		end)
	)

	table.insert(
		Connections,
		LocalPlayer:GetAttributeChangedSignal("Bigger"):Connect(function()
			local newBigger = LocalPlayer:GetAttribute("Bigger")
			local nv = if type(newBigger) == "number" then newBigger else 0
			if nv > LastBiggerValue then
				BiggerAccumulator += (nv - LastBiggerValue)
				LastBiggerTime = os.clock()
			end
			LastBiggerValue = nv
		end)
	)

	table.insert(
		Connections,
		LocalPlayer:GetAttributeChangedSignal("Level"):Connect(function()
			local level = LocalPlayer:GetAttribute("Level")
			local l = if type(level) == "number" then level else 1
			ShowFeedback("LEVEL UP! Lv" .. tostring(l), Color3.fromRGB(255, 255, 0), 1.5, 2.0)
		end)
	)

	table.insert(
		Connections,
		LocalPlayer:GetAttributeChangedSignal("Rebirth"):Connect(function()
			local rebirth = LocalPlayer:GetAttribute("Rebirth")
			local r = if type(rebirth) == "number" then rebirth else 0
			ShowFeedback("REBIRTH! R" .. tostring(r), Color3.fromRGB(200, 0, 255), 2.0, 2.5)
		end)
	)

	local wasActive = LocalPlayer:GetAttribute("ObjectiveActive")
	local activeState = if type(wasActive) == "boolean" then wasActive else false
	table.insert(
		Connections,
		LocalPlayer:GetAttributeChangedSignal("ObjectiveActive"):Connect(function()
			local active = LocalPlayer:GetAttribute("ObjectiveActive")
			local newActiveState = if type(active) == "boolean" then active else false
			if activeState and not newActiveState then
				ShowFeedback("CRUSH! +1", Color3.fromRGB(255, 100, 0), 1.0, 1.5)
			end
			activeState = newActiveState
		end)
	)
end

function FloatingFeedbackController.Destroy()
	for _, conn in Connections do
		conn:Disconnect()
	end
	table.clear(Connections)

	for _, bgui in Pool do
		bgui:Destroy()
	end
	table.clear(Pool)

	for _, bgui in Active do
		bgui:Destroy()
	end
	table.clear(Active)

	Initialized = false
	Started = false
end

function FloatingFeedbackController.Show(text: string, color: Color3?, duration: number?, popScale: number?)
	ShowFeedback(text, color or Color3.fromRGB(255, 255, 255), duration or 1.5, popScale or 1.5)
end

return FloatingFeedbackController
