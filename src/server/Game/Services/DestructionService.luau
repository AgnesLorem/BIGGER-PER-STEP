--!strict
--// Raw Requirings \\--

local Players = game:GetService("Players")

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

local function PlayPlaceholderEffect(Hitbox: BasePart)
	local OriginalTransparency = Hitbox.Transparency
	Hitbox.Transparency = 0.7
	task.delay(0.25, function()
		if Hitbox.Parent then
			Hitbox.Transparency = OriginalTransparency
		end
	end)
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

	return pcall(SyncDestruction, Player, NewValue)
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

	Hitbox.CanTouch = true
	table.insert(
		WorldInstance.Connections,
		Hitbox.Touched:Connect(function(Hit)
			self:TryCompleteObjective(WorldInstance, Hitbox, Hit, WorldInstanceService)
		end)
	)
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
	if not WorldInstance.ObjectiveActive or WorldInstance.ObjectiveCompleted then
		return
	end
	if not IsValidStomp(Player, Hitbox) then
		return
	end

	local SessionServiceFound, SessionService = pcall(function()
		return ServiceRegistry.Get("SessionService")
	end)
	if not SessionServiceFound or not SessionService then
		WorldInstanceService:RecoverPlayer(Player, "MissingSessionServiceAtCompletion", false)
		return
	end

	WorldInstance.ObjectiveCompleted = true
	WorldInstance.ObjectiveActive = false
	Hitbox.CanTouch = false
	local TransitionCalled, Transitioned = pcall(function()
		return SessionService:TransitionState(Player, "InWorld", "Returning")
	end)
	if not TransitionCalled or not Transitioned then
		WorldInstanceService:RecoverPlayer(Player, "ObjectiveTransitionFailed", false)
		return
	end

	local Rewarded = self:GrantDestruction(Player, World1Config.Objective.DestructionReward)
	if not Rewarded then
		WorldInstanceService:RecoverPlayer(Player, "ProfileMutationsFrozen", false)
		return
	end

	local EffectSuccess = pcall(function()
		PlayPlaceholderEffect(Hitbox)
	end)
	if not EffectSuccess then
		Logger.Warn(
			"Destruction",
			"Destruction effect failed for PlayerUserId=%d WorldInstanceId=%s",
			Player.UserId,
			WorldInstance.WorldInstanceId
		)
	end

	local Debounced = pcall(function()
		local PortalService = ServiceRegistry.Get("PortalService")
		PortalService:HoldDebounce(Player, World1Config.ReturnPortalDebounceSeconds)
	end)
	if not Debounced then
		Logger.Warn("Destruction", "Return portal debounce failed for PlayerUserId=%d", Player.UserId)
	end

	local ReturnCalled, ReturnSuccess = pcall(function()
		return WorldInstanceService:ReturnPlayerToLobby(Player)
	end)
	if not ReturnCalled or not ReturnSuccess then
		Logger.Warn(
			"Destruction",
			"Return teleport failed for PlayerUserId=%d WorldInstanceId=%s",
			Player.UserId,
			WorldInstance.WorldInstanceId
		)
		WorldInstanceService:RecoverPlayer(Player, "ReturnSpawnUnavailableAtCompletion", true)
		return
	end

	WorldInstanceService:RecoverPlayer(Player, "ObjectiveCompleted", false)
end

return DestructionService
