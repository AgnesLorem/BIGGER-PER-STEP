--!strict
--// Raw Requirings \\--

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Requirings \\--

local Sessions = require(script.Parent.Parent.Parent.Core.Registry.RuntimeRegistry.Sessions)
local ServiceRegistry = require(script.Parent.Parent.Parent.Core.Registry.ServiceRegistry)
local Logger = require(script.Parent.Parent.Parent.Core.Utilities.Logger)
local MapsConfig = require(script.Parent.Parent.Config.MapsConfig)
local StompValidation = require(ReplicatedStorage.BiggerShared.Core.Utilities.StompValidation)
local ScaleCurve = require(ReplicatedStorage.BiggerShared.Core.Utilities.ScaleCurve)
local ScaleConfig = require(ReplicatedStorage.BiggerShared.Core.Config.ScaleConfig)

--// Variables \\--

local MAX_SAFE_INTEGER = 9007199254740991

--// Helpers \\--

local function IsSafeInteger(Value: number, Minimum: number): boolean
	return Value == Value and Value >= Minimum and Value <= MAX_SAFE_INTEGER and Value % 1 == 0
end

local function GetPlayerFromHit(Hit: BasePart): Player?
	local Character = Hit:FindFirstAncestorOfClass("Model")
	if not Character then
		return nil
	end
	return Players:GetPlayerFromCharacter(Character)
end

local function GetRootPart(Player: Player): BasePart?
	local Character = Player.Character
	local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
	if RootPart and RootPart:IsA("BasePart") then
		return RootPart
	end
	return nil
end

local function GetHitbox(WorldModel: Instance, TargetModelName: string?): (BasePart?, Model?)
	if TargetModelName and TargetModelName ~= "" then
		local TargetModel = WorldModel:FindFirstChild(TargetModelName, true)
		if TargetModel then
			local Hitbox = TargetModel:FindFirstChild("ObjectiveHitbox", true)
			if Hitbox and Hitbox:IsA("BasePart") then
				return Hitbox, if TargetModel:IsA("Model") then TargetModel else nil
			end
		end
	end

	-- Generic discovery: find any ObjectiveHitbox part in the instance
	local GenericHitbox = WorldModel:FindFirstChild("ObjectiveHitbox", true)
	if GenericHitbox and GenericHitbox:IsA("BasePart") then
		local OwningModel = GenericHitbox:FindFirstAncestorOfClass("Model")
		return GenericHitbox, OwningModel
	end

	return nil, nil
end

local function GetMapConfigForInstance(WorldInstance: any): MapsConfig.MapDefinition?
	local MapId = WorldInstance.MapId
	if not MapId and WorldInstance.Model then
		MapId = WorldInstance.Model:GetAttribute("MapId")
	end
	return MapsConfig.GetMap(MapId or "MAP1")
end

local function IsValidStomp(Player: Player, Hitbox: BasePart, ObjectiveConfig: MapsConfig.ObjectiveConfig?): boolean
	local RootPart = GetRootPart(Player)
	if not RootPart then
		return false
	end

	local Session = Sessions.Get(Player)
	local Bigger = if Session then Session.Bigger else 1
	local RawVisualScale = ScaleCurve.GetVisualScale(Bigger, ScaleConfig.Formula, ScaleConfig.CurveParameter)
	local VisualScale = math.clamp(RawVisualScale, ScaleConfig.MinVisualScale, ScaleConfig.MaxVisualScale)

	local MaxHeight = if ObjectiveConfig then ObjectiveConfig.MaximumRootHeight else 8
	local Padding = if ObjectiveConfig then ObjectiveConfig.HorizontalPadding else 1
	local MinVelocity = if ObjectiveConfig then ObjectiveConfig.MinimumDownwardVelocity else -2

	local ScaledMaxHeight = MaxHeight * VisualScale
	local ScaledHorizontalPadding = Padding * VisualScale

	local LocalPosition = Hitbox.CFrame:PointToObjectSpace(RootPart.Position)
	local HalfSize = Hitbox.Size / 2
	return StompValidation.IsValid(
		LocalPosition.X,
		LocalPosition.Y,
		LocalPosition.Z,
		HalfSize.X,
		HalfSize.Y,
		HalfSize.Z,
		ScaledHorizontalPadding,
		ScaledMaxHeight,
		RootPart.AssemblyLinearVelocity.Y,
		MinVelocity
	)
end

local function SyncDestruction(Player: Player, Destruction: number)
	Player:SetAttribute("Destruction", Destruction)

	local Leaderstats = Player:FindFirstChild("leaderstats")
	local DestructionStat = Leaderstats and Leaderstats:FindFirstChild("Destruction")
	if DestructionStat and DestructionStat:IsA("IntValue") then
		DestructionStat.Value = Destruction
	end
end

local function BreakObjective(WorldModel: Instance, Hitbox: BasePart, ModelName: string?)
	local TargetModel = if ModelName then WorldModel:FindFirstChild(ModelName, true) else nil
	if not TargetModel then
		TargetModel = Hitbox:FindFirstAncestorOfClass("Model")
	end
	if not TargetModel then
		return
	end

	local FragmentIndex = 0
	for _, Descendant in TargetModel:GetDescendants() do
		if Descendant:IsA("BasePart") and Descendant ~= Hitbox then
			FragmentIndex += 1
			local OffsetX = Descendant.Position.X - Hitbox.Position.X
			local OffsetZ = Descendant.Position.Z - Hitbox.Position.Z
			local Magnitude = math.sqrt(OffsetX * OffsetX + OffsetZ * OffsetZ)
			if Magnitude < 0.001 then
				local Angle = FragmentIndex * math.pi * 0.75
				OffsetX = math.cos(Angle)
				OffsetZ = math.sin(Angle)
				Magnitude = 1
			end

			Descendant.CanCollide = false
			Descendant.CanTouch = false
			Descendant.CanQuery = false
			Descendant.Anchored = false
			Descendant.AssemblyLinearVelocity = Vector3.new(OffsetX / Magnitude * 12, 10, OffsetZ / Magnitude * 12)
			Descendant.AssemblyAngularVelocity =
				Vector3.new((FragmentIndex % 3 - 1) * 2.5, 3, (FragmentIndex % 2 * 2 - 1) * 2.5)
			Debris:AddItem(Descendant, 2.5)
		end
	end
end

--// Service \\--

local DestructionService = {}

function DestructionService:Init() end

function DestructionService:Start() end

function DestructionService:GrantDestruction(Player: Player, Amount: number): boolean
	if type(Amount) ~= "number" or not IsSafeInteger(Amount, 1) then
		return false
	end

	local NewValue: number? = nil
	local Mutated = Sessions.Mutate(Player, function(Session)
		local Current = Session.Destruction
		if not IsSafeInteger(Current, 0) or Current > MAX_SAFE_INTEGER - Amount then
			return
		end
		NewValue = Current + Amount
		Session.Destruction = NewValue
	end)
	if not Mutated or not NewValue then
		return false
	end

	local Synced, SyncError = pcall(SyncDestruction, Player, NewValue)
	if not Synced then
		Logger.Warn(
			"Destruction",
			"Presentation sync failed for PlayerUserId=%d: %s",
			Player.UserId,
			tostring(SyncError)
		)
	end
	return true
end

function DestructionService:DeductDestruction(_Player: Player, _Amount: number): boolean
	Logger.Warn("Destruction", "DeductDestruction is deprecated; Destruction cannot be spent or deducted.")
	return false
end

function DestructionService:BindWorld(WorldInstance, WorldInstanceService)
	local MapConfig = GetMapConfigForInstance(WorldInstance)
	local TargetModelName = MapConfig and MapConfig.Objective.ModelName or nil
	local Hitbox = GetHitbox(WorldInstance.Model, TargetModelName)
	if not Hitbox then
		Logger.Warn(
			"Destruction",
			"ObjectiveHitbox missing for PlayerUserId=%d WorldInstanceId=%s TargetModel=%s",
			WorldInstance.OwnerUserId,
			WorldInstance.WorldInstanceId,
			TargetModelName or "Generic"
		)
		return false
	end

	WorldInstance.ObjectiveInitialized = false
	WorldInstance.ObjectiveActive = false
	Hitbox.CanTouch = false
	table.insert(
		WorldInstance.Connections,
		Hitbox.Touched:Connect(function(Hit)
			self:TryCompleteObjective(WorldInstance, Hitbox, Hit, WorldInstanceService)
		end)
	)
	return true
end

function DestructionService:ActivateWorld(WorldInstance): boolean
	if WorldInstance.ObjectiveInitialized or WorldInstance.ObjectiveCompleted then
		return false
	end
	local Player = WorldInstance.OwnerPlayer
	local Session = Sessions.Get(Player)
	if
		not Session
		or Session.ProfileMutationsFrozen
		or Session.State ~= "InWorld"
		or Session.CurrentWorldInstanceId ~= WorldInstance.WorldInstanceId
	then
		return false
	end
	local MapConfig = GetMapConfigForInstance(WorldInstance)
	local Hitbox = GetHitbox(WorldInstance.Model, MapConfig and MapConfig.Objective.ModelName)
	if not Hitbox then
		return false
	end
	WorldInstance.ObjectiveInitialized = true
	WorldInstance.ObjectiveActive = true
	Hitbox.CanTouch = true
	return true
end

function DestructionService:CompleteObjective(WorldInstance, WorldInstanceService): boolean
	local Player = WorldInstance.OwnerPlayer
	if not Player then
		return false
	end

	local Session = Sessions.Get(Player)
	if not Session or Session.ProfileMutationsFrozen or Session.State ~= "InWorld" then
		return false
	end
	if Session.CurrentWorldInstanceId ~= WorldInstance.WorldInstanceId then
		return false
	end
	if
		not WorldInstance.ObjectiveInitialized
		or not WorldInstance.ObjectiveActive
		or WorldInstance.ObjectiveCompleted
	then
		return false
	end

	WorldInstance.ObjectiveCompleted = true
	WorldInstance.ObjectiveActive = false

	local MapConfig = GetMapConfigForInstance(WorldInstance)
	local TargetModelName = MapConfig and MapConfig.Objective.ModelName
	local Hitbox = GetHitbox(WorldInstance.Model, TargetModelName)
	if Hitbox then
		Hitbox.CanTouch = false
		Hitbox.CanCollide = false
		Hitbox.CanQuery = false
	end
	Player:SetAttribute("ObjectiveActive", false)

	local EffectSuccess = pcall(function()
		if Hitbox then
			BreakObjective(WorldInstance.Model, Hitbox, TargetModelName)
		end
	end)
	if not EffectSuccess then
		Logger.Warn(
			"Destruction",
			"Destruction effect failed for PlayerUserId=%d WorldInstanceId=%s",
			Player.UserId,
			WorldInstance.WorldInstanceId
		)
	end
	local RewardServiceFound, RewardPortalService = pcall(function()
		return ServiceRegistry.Get("RewardPortalService")
	end)
	local Activated, ActivationSuccess = pcall(function()
		return RewardServiceFound
			and RewardPortalService
			and RewardPortalService:ActivateChoices(WorldInstance, WorldInstanceService)
	end)
	if not Activated or not ActivationSuccess then
		WorldInstanceService:RecoverPlayer(Player, "RewardChoiceActivationFailed", false)
		return false
	end
	return true
end

function DestructionService:TryCompleteObjective(WorldInstance, Hitbox: BasePart, Hit: BasePart, WorldInstanceService)
	local Player = GetPlayerFromHit(Hit)
	if not Player or Player.UserId ~= WorldInstance.OwnerUserId then
		return
	end

	local Session = Sessions.Get(Player)
	if not Session or Session.ProfileMutationsFrozen or Session.State ~= "InWorld" then
		return
	end
	if Session.CurrentWorldInstanceId ~= WorldInstance.WorldInstanceId then
		return
	end
	if
		not WorldInstance.ObjectiveInitialized
		or not WorldInstance.ObjectiveActive
		or WorldInstance.ObjectiveCompleted
	then
		return
	end

	local MapConfig = GetMapConfigForInstance(WorldInstance)
	if not IsValidStomp(Player, Hitbox, MapConfig and MapConfig.Objective) then
		return
	end

	self:CompleteObjective(WorldInstance, WorldInstanceService)
end

return DestructionService
