--!strict
--// Raw Requirings \\--

local Players = game:GetService("Players")
local Debris = game:GetService("Debris")

--// Requirings \\--

local Sessions = require(script.Parent.Parent.Parent.Core.Registry.RuntimeRegistry.Sessions)
local ServiceRegistry = require(script.Parent.Parent.Parent.Core.Registry.ServiceRegistry)
local Logger = require(script.Parent.Parent.Parent.Core.Utilities.Logger)
local World1Config = require(script.Parent.Parent.Config.World1Config)
local StompValidation = require(game:GetService("ReplicatedStorage").BiggerShared.Core.Utilities.StompValidation)

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

local function GetHitbox(WorldModel: Instance): BasePart?
	local Spider = WorldModel:FindFirstChild(World1Config.Objective.ModelName, true)
	if not Spider then
		return nil
	end

	local Hitbox = Spider:FindFirstChild(World1Config.Objective.HitboxName)
	if Hitbox and Hitbox:IsA("BasePart") then
		return Hitbox
	end

	return nil
end

local function IsValidStomp(Player: Player, Hitbox: BasePart): boolean
	local RootPart = GetRootPart(Player)
	if not RootPart then
		return false
	end

	local LocalPosition = Hitbox.CFrame:PointToObjectSpace(RootPart.Position)
	local HalfSize = Hitbox.Size / 2
	return StompValidation.IsValid(
		LocalPosition.X,
		LocalPosition.Y,
		LocalPosition.Z,
		HalfSize.X,
		HalfSize.Y,
		HalfSize.Z,
		World1Config.Objective.HorizontalPadding,
		World1Config.Objective.MaximumRootHeight,
		RootPart.AssemblyLinearVelocity.Y,
		World1Config.Objective.MinimumDownwardVelocity
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

local function BreakSpider(WorldModel: Instance, Hitbox: BasePart)
	local Spider = WorldModel:FindFirstChild(World1Config.Objective.ModelName, true)
	if not Spider then
		return
	end

	local FragmentIndex = 0
	for _, Descendant in Spider:GetDescendants() do
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
			Descendant.AssemblyLinearVelocity = Vector3.new(OffsetX / Magnitude * 10, 8, OffsetZ / Magnitude * 10)
			Descendant.AssemblyAngularVelocity =
				Vector3.new((FragmentIndex % 3 - 1) * 1.5, 2, (FragmentIndex % 2 * 2 - 1) * 1.5)
			Debris:AddItem(Descendant, 2)
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

function DestructionService:BindWorld(WorldInstance, WorldInstanceService)
	local Hitbox = GetHitbox(WorldInstance.Model)
	if not Hitbox then
		Logger.Warn(
			"Destruction",
			"Spider.ObjectiveHitbox missing for PlayerUserId=%d WorldInstanceId=%s",
			WorldInstance.OwnerUserId,
			WorldInstance.WorldInstanceId
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
	local Hitbox = GetHitbox(WorldInstance.Model)
	if not Hitbox then
		return false
	end
	WorldInstance.ObjectiveInitialized = true
	WorldInstance.ObjectiveActive = true
	Hitbox.CanTouch = true
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
	if not IsValidStomp(Player, Hitbox) then
		return
	end

	WorldInstance.ObjectiveCompleted = true
	WorldInstance.ObjectiveActive = false
	Hitbox.CanTouch = false
	Hitbox.CanCollide = false
	Hitbox.CanQuery = false
	Player:SetAttribute("ObjectiveActive", false)
	local EffectSuccess = pcall(function()
		BreakSpider(WorldInstance.Model, Hitbox)
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
		return
	end
end

return DestructionService
