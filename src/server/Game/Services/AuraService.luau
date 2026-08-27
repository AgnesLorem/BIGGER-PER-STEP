--!strict
-- src/server/Game/Services/AuraService.luau
-- Server-authoritative Aura service.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sessions = require(script.Parent.Parent.Parent.Core.Registry.RuntimeRegistry.Sessions)

local AuraConfig = require(
	ReplicatedStorage:WaitForChild("BiggerShared")
		:WaitForChild("Game")
		:WaitForChild("Config")
		:WaitForChild("AuraConfig")
)
local AuraFormula = require(
	ReplicatedStorage:WaitForChild("BiggerShared")
		:WaitForChild("Game")
		:WaitForChild("Progression")
		:WaitForChild("AuraFormula")
)

local function FindTierById(AuraId: string): any
	for _, Tier in AuraConfig.Tiers do
		if Tier.Id == AuraId then
			return Tier
		end
	end
	return nil
end

local AuraService = {}

local AuraFolder: Folder
local RequestRemote: RemoteEvent
local ResponseRemote: RemoteEvent
local StateChangedRemote: RemoteEvent
local Initialized = false
local Started = false
local Connections: { RBXScriptConnection } = {}

local function GetOrCreate(Parent: Instance, Name: string, ClassName: string): Instance
	local Existing = Parent:FindFirstChild(Name)
	if Existing then
		assert(Existing:IsA(ClassName), string.format("%s.%s must be a %s", Parent.Name, Name, ClassName))
		return Existing
	end
	local Created = Instance.new(ClassName)
	Created.Name = Name
	Created.Parent = Parent
	return Created
end

local function HandleRequest(Player: Player, Action: string, Payload: any)
	if Player.Parent ~= Players then
		return
	end
	local Session = Sessions.Get(Player)
	if not Session then
		return
	end

	if Action == "GetState" then
		ResponseRemote:FireClient(Player, {
			Action = "GetState",
			UnlockedAuras = Session.UnlockedAuras or {},
			EquippedAura = Session.EquippedAura or "None",
			AuraVFXEnabled = if Session.AuraVFXEnabled == nil then true else Session.AuraVFXEnabled,
			HighestMultiplier = AuraFormula.GetMultiplier(Session.UnlockedAuras or {}),
		})
	elseif Action == "Equip" then
		local AuraId = Payload
		if typeof(AuraId) == "string" and AuraFormula.CanEquip(Session.UnlockedAuras or {}, AuraId) then
			Sessions.Mutate(Player, function(S)
				S.EquippedAura = AuraId
			end)
			Player:SetAttribute("EquippedAura", AuraId)
			AuraService:AttachAuraVFX(Player, Player.Character, AuraId)
			StateChangedRemote:FireClient(Player, { EquippedAura = AuraId })
		end
	elseif Action == "ToggleVFX" then
		local Enabled = Payload
		if typeof(Enabled) == "boolean" then
			Sessions.Mutate(Player, function(S)
				S.AuraVFXEnabled = Enabled
			end)
			Player:SetAttribute("AuraVFXEnabled", Enabled)
			if Player.Character then
				local AuraContainer = Player.Character:FindFirstChild("AuraContainer")
				if AuraContainer then
					for _, Child in AuraContainer:GetChildren() do
						if Child:IsA("ParticleEmitter") then
							Child.Enabled = Enabled
						end
					end
				end
			end
			StateChangedRemote:FireClient(Player, { AuraVFXEnabled = Enabled })
		end
	end
end

function AuraService:Init()
	if Initialized then
		return
	end

	local EventsFolder = ReplicatedStorage:FindFirstChild("BiggerEvents") :: Folder?
	if not EventsFolder then
		EventsFolder = GetOrCreate(ReplicatedStorage, "BiggerEvents", "Folder") :: Folder
	end

	AuraFolder = GetOrCreate(EventsFolder, "Aura", "Folder") :: Folder
	RequestRemote = GetOrCreate(AuraFolder, "Request", "RemoteEvent") :: RemoteEvent
	ResponseRemote = GetOrCreate(AuraFolder, "Response", "RemoteEvent") :: RemoteEvent
	StateChangedRemote = GetOrCreate(AuraFolder, "StateChanged", "RemoteEvent") :: RemoteEvent

	table.insert(Connections, RequestRemote.OnServerEvent:Connect(HandleRequest))

	-- Re-attach VFX on respawn
	table.insert(
		Connections,
		Players.PlayerAdded:Connect(function(Player)
			table.insert(
				Connections,
				Player.CharacterAdded:Connect(function(Character)
					local Session = Sessions.Get(Player)
					if Session and Session.EquippedAura and Session.EquippedAura ~= "None" then
						self:AttachAuraVFX(Player, Character, Session.EquippedAura)
					end
				end)
			)
		end)
	)

	Initialized = true
end

function AuraService:Start()
	if Started then
		return
	end
	Started = true
end

function AuraService:CheckAndUnlockAuras(Player: Player)
	local Session = Sessions.Get(Player)
	if not Session then
		return
	end

	local Destruction = Session.Destruction or 0
	local NewlyUnlocked = false

	Sessions.Mutate(Player, function(S)
		S.UnlockedAuras = S.UnlockedAuras or {}
		for _, TierData in AuraConfig.Tiers do
			if Destruction >= TierData.RequiredDestruction and not S.UnlockedAuras[TierData.Id] then
				S.UnlockedAuras[TierData.Id] = true
				NewlyUnlocked = true
			end
		end
	end)

	if NewlyUnlocked then
		local Multiplier = AuraFormula.GetMultiplier(Session.UnlockedAuras)
		Player:SetAttribute("AuraMultiplier", Multiplier)
		StateChangedRemote:FireClient(Player, { UnlockedAuras = Session.UnlockedAuras })
	end
end

function AuraService:AttachAuraVFX(Player: Player, Character: Model?, AuraId: string)
	if not Character then
		return
	end
	local Root = Character:FindFirstChild("HumanoidRootPart")
	if not Root then
		return
	end

	local Existing = Character:FindFirstChild("AuraContainer")
	if Existing then
		Existing:Destroy()
	end

	if AuraId == "None" then
		return
	end

	local TierData = FindTierById(AuraId)
	if not TierData then
		return
	end

	local AuraContainer = Instance.new("Part")
	AuraContainer.Name = "AuraContainer"
	AuraContainer.Transparency = 1
	AuraContainer.CanCollide = false
	AuraContainer.Massless = true
	AuraContainer.Size = Vector3.new(1, 1, 1)
	AuraContainer.CFrame = (Root :: BasePart).CFrame
	AuraContainer.Parent = Character

	local Weld = Instance.new("WeldConstraint")
	Weld.Part0 = Root :: BasePart
	Weld.Part1 = AuraContainer
	Weld.Parent = AuraContainer

	local Emitter = Instance.new("ParticleEmitter")
	Emitter.Color = ColorSequence.new(Color3.fromRGB(TierData.Color.R, TierData.Color.G, TierData.Color.B))
	Emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 5),
		NumberSequenceKeypoint.new(1, 0),
	})
	Emitter.Texture = "rbxassetid://13837775586"
	Emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.5, 0.5),
		NumberSequenceKeypoint.new(1, 1),
	})
	Emitter.Lifetime = NumberRange.new(1, 2)
	Emitter.Rate = 20
	Emitter.Speed = NumberRange.new(0)
	local Session = Sessions.Get(Player)
	Emitter.Enabled = if Session and Session.AuraVFXEnabled ~= nil then Session.AuraVFXEnabled else true
	Emitter.Parent = AuraContainer
end

function AuraService:Destroy()
	for _, Connection in Connections do
		Connection:Disconnect()
	end
	table.clear(Connections)
	Initialized = false
	Started = false
end

return AuraService
