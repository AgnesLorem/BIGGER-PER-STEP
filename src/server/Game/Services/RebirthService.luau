--!strict
-- src/server/Game/Services/RebirthService.luau
-- Server-authoritative Rebirth service.
-- Validates requirements, executes progression reset, updates multipliers and persistence.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sessions = require(script.Parent.Parent.Parent.Core.Registry.RuntimeRegistry.Sessions)
local ServiceRegistry = require(script.Parent.Parent.Parent.Core.Registry.ServiceRegistry)
local Logger = require(script.Parent.Parent.Parent.Core.Utilities.Logger)
local EventBus = require(script.Parent.Parent.Parent.Core.Events.EventBus)

local RebirthConfig = require(
	ReplicatedStorage:WaitForChild("BiggerShared")
		:WaitForChild("Game")
		:WaitForChild("Config")
		:WaitForChild("RebirthConfig")
)
local RebirthFormula = require(
	ReplicatedStorage:WaitForChild("BiggerShared")
		:WaitForChild("Game")
		:WaitForChild("Progression")
		:WaitForChild("RebirthFormula")
)
local LevelFormula = require(
	ReplicatedStorage:WaitForChild("BiggerShared")
		:WaitForChild("Game")
		:WaitForChild("Progression")
		:WaitForChild("LevelFormula")
)
local GrowthFormula = require(script.Parent.Parent.Formula.GrowthFormula)

local ResultCodes = table.freeze({
	Success = "Success",
	NoSession = "NoSession",
	Frozen = "Frozen",
	RequirementsNotMet = "RequirementsNotMet",
	RateLimited = "RateLimited",
	PlayerDisconnected = "PlayerDisconnected",
	MutationFailed = "MutationFailed",
	InvalidRequest = "InvalidRequest",
})

local RebirthService = {}
RebirthService.ResultCodes = ResultCodes

local RebirthFolder: Folder
local RequestRemote: RemoteEvent
local ResponseRemote: RemoteEvent
local Initialized = false
local Started = false
local Connections: { RBXScriptConnection } = {}
local LastRebirthTimestamps: { [Player]: number } = {}

local function QueueImmediateSave(Player: Player, NewRebirthCount: number)
	local SaveServiceOk, SaveService = pcall(function()
		return ServiceRegistry.Get("SaveService")
	end)
	if SaveServiceOk and SaveService then
		local SaveQueued = SaveService:QueueProfileSave(Player)
		if not SaveQueued then
			Logger.Warn("Rebirth", "Immediate save queue failed for %s after Rebirth %d", Player.Name, NewRebirthCount)
		end
	else
		Logger.Warn(
			"Rebirth",
			"SaveService unavailable to queue save for %s after Rebirth %d",
			Player.Name,
			NewRebirthCount
		)
	end
end

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

local function HandleRequest(Player: Player, _Value: unknown)
	if Player.Parent ~= Players then
		return
	end

	local Success, Code, NewCount, TotalMult, RebirthMult = RebirthService:RequestRebirth(Player)
	if ResponseRemote then
		if Success then
			ResponseRemote:FireClient(Player, {
				Success = true,
				ErrorCode = Code,
				Rebirth = NewCount,
				Level = 1,
				Bigger = 0,
				Multiplier = TotalMult,
				RebirthMultiplier = RebirthMult,
			})
		else
			local Session = Sessions.Get(Player)
			local CurrentRebirth = if Session then Session.Rebirth else (NewCount or 0)
			ResponseRemote:FireClient(Player, {
				Success = false,
				ErrorCode = Code,
				Rebirth = CurrentRebirth,
				RequiredLevel = RebirthFormula.GetRequiredLevel(CurrentRebirth),
			})
		end
	end
end

function RebirthService:Init()
	if Initialized then
		return
	end

	local EventsFolder = ReplicatedStorage:FindFirstChild("BiggerEvents") :: Folder?
	if not EventsFolder then
		EventsFolder = GetOrCreate(ReplicatedStorage, "BiggerEvents", "Folder") :: Folder
	elseif not EventsFolder:IsA("Folder") then
		error("BiggerEvents must be a Folder")
	end

	RebirthFolder = GetOrCreate(EventsFolder, "Rebirth", "Folder") :: Folder
	RequestRemote = GetOrCreate(RebirthFolder, "Request", "RemoteEvent") :: RemoteEvent
	ResponseRemote = GetOrCreate(RebirthFolder, "Response", "RemoteEvent") :: RemoteEvent
	table.insert(Connections, RequestRemote.OnServerEvent:Connect(HandleRequest))
	Initialized = true
end

function RebirthService:Start()
	if Started then
		return
	end
	Started = true

	table.insert(
		Connections,
		Players.PlayerRemoving:Connect(function(Player: Player)
			LastRebirthTimestamps[Player] = nil
		end)
	)
end

function RebirthService:RequestRebirth(Player: Player): (boolean, string, number?, number?, number?)
	if Player.Parent ~= Players then
		return false, ResultCodes.PlayerDisconnected, nil, nil, nil
	end

	local Session = Sessions.Get(Player)
	if not Session then
		return false, ResultCodes.NoSession, nil, nil, nil
	end
	if Session.ProfileMutationsFrozen then
		return false, ResultCodes.Frozen, nil, nil, nil
	end

	local Now = os.clock()
	local LastRebirth = LastRebirthTimestamps[Player] or 0
	if Now - LastRebirth < RebirthConfig.MinimumRebirthCooldownSeconds then
		return false, ResultCodes.RateLimited, Session.Rebirth, nil, nil
	end

	local CurrentLevel = LevelFormula.GetLevelFromBigger(Session.Bigger)
	if not RebirthFormula.CanRebirth(CurrentLevel, Session.Rebirth) then
		return false, ResultCodes.RequirementsNotMet, Session.Rebirth, nil, nil
	end

	local NewRebirthCount = Session.Rebirth + 1
	local Mutated = Sessions.Mutate(Player, function(S)
		S.Bigger = 0
		S.GrowthRemainder = 0
		S.Rebirth = NewRebirthCount
	end)

	if not Mutated then
		return false, ResultCodes.MutationFailed, Session.Rebirth, nil, nil
	end

	LastRebirthTimestamps[Player] = Now

	local NewRebirthMultiplier = RebirthFormula.GetMultiplier(NewRebirthCount)
	local NewTotalMultiplier = GrowthFormula.GetMultiplier(Session)

	-- Authoritative state sync to player attributes
	Player:SetAttribute("Bigger", 0)
	Player:SetAttribute("Level", 1)
	Player:SetAttribute("Rebirth", NewRebirthCount)
	Player:SetAttribute("RebirthMultiplier", NewRebirthMultiplier)
	Player:SetAttribute("Multiplier", NewTotalMultiplier)

	-- Update leaderstats
	local Leaderstats = Player:FindFirstChild("leaderstats")
	if Leaderstats then
		local BiggerStat = Leaderstats:FindFirstChild("Bigger")
		if BiggerStat and BiggerStat:IsA("IntValue") then
			BiggerStat.Value = 0
		end
		local RebirthStat = Leaderstats:FindFirstChild("Rebirth")
		if RebirthStat and RebirthStat:IsA("IntValue") then
			RebirthStat.Value = NewRebirthCount
		end
	end

	-- Update multiplier attribute on player
	local GrowthServiceOk, GrowthService = pcall(function()
		return ServiceRegistry.Get("GrowthService")
	end)
	if GrowthServiceOk and GrowthService then
		GrowthService:UpdateMultiplierAttribute(Player)
	end

	-- Publish lifecycle events
	EventBus.Publish("RebirthCompleted", Player, NewRebirthCount)
	EventBus.Publish("BiggerChanged", Player, 0)

	QueueImmediateSave(Player, NewRebirthCount)
	Logger.Info("Rebirth", "Player %s completed Rebirth %d", Player.Name, NewRebirthCount)

	return true, ResultCodes.Success, NewRebirthCount, NewTotalMultiplier, NewRebirthMultiplier
end

function RebirthService:Destroy()
	for _, Connection in Connections do
		Connection:Disconnect()
	end
	table.clear(Connections)
	table.clear(LastRebirthTimestamps)
	Initialized = false
	Started = false
end

return RebirthService
