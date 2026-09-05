--!strict
-- AutoWinsService.luau
-- Authoritative server service managing the AutoWins loop cycle.

--// Raw Requirings \\--

local Players = game:GetService("Players")
local ReplicatedStorageFound, ReplicatedStorage = pcall(function()
	return game:GetService("ReplicatedStorage")
end)

--// Requirings \\--

local Sessions = require(script.Parent.Parent.Parent.Core.Registry.RuntimeRegistry.Sessions)
local WorldInstances = require(script.Parent.Parent.Parent.Core.Registry.RuntimeRegistry.WorldInstances)
local Scheduler = require(script.Parent.Parent.Parent.Core.Scheduler.Scheduler)
local ServiceRegistry = require(script.Parent.Parent.Parent.Core.Registry.ServiceRegistry)
local Logger = require(script.Parent.Parent.Parent.Core.Utilities.Logger)

--// Variables \\--

local ToggleAutoWinsRemote: RemoteEvent? = nil
local Initialized = false

--// Helpers \\--

local function EnsureRemote(Name: string): RemoteEvent?
	if not ReplicatedStorageFound or not ReplicatedStorage then
		return nil
	end

	local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if not RemotesFolder then
		RemotesFolder = Instance.new("Folder")
		RemotesFolder.Name = "Remotes"
		RemotesFolder.Parent = ReplicatedStorage
	end

	local Existing = RemotesFolder:FindFirstChild(Name)
	if Existing and (not Existing.IsA or Existing:IsA("RemoteEvent")) then
		return Existing :: RemoteEvent
	end

	local Remote = Instance.new("RemoteEvent")
	Remote.Name = Name
	Remote.Parent = RemotesFolder
	return Remote
end

local function SyncPlayerAttribute(Player: Player, Enabled: boolean)
	pcall(function()
		Player:SetAttribute("AutoWinsActive", Enabled)
	end)
end

--// Service \\--

local AutoWinsService = {}

function AutoWinsService:Init()
	if Initialized then
		return
	end
	Initialized = true

	ToggleAutoWinsRemote = EnsureRemote("ToggleAutoWins")
	if ToggleAutoWinsRemote and ToggleAutoWinsRemote.OnServerEvent then
		ToggleAutoWinsRemote.OnServerEvent:Connect(function(Client: Player, Enabled: any)
			self:Toggle(Client, Enabled == true)
		end)
	end
end

function AutoWinsService:Start()
	Scheduler.AddJob({
		Name = "AutoWinsLoop",
		IntervalSeconds = 1,
		Callback = function()
			self:ProcessLoop()
		end,
		Priority = 6,
	})
	Logger.Info("AutoWins", "AutoWinsLoop scheduled at 1s cadence")
end

function AutoWinsService:Toggle(Player: Player, Enabled: boolean): boolean
	if not Player or (Player.IsA and not Player:IsA("Player")) then
		return false
	end

	local Session = Sessions.Get(Player)
	if not Session or Session.ProfileMutationsFrozen then
		return false
	end

	if not Session.HasAutoWins then
		local GamePassServiceFound, GamePassService = pcall(function()
			return ServiceRegistry.Get("GamePassService")
		end)
		if GamePassServiceFound and GamePassService then
			GamePassService:Prompt(Player, "AutoWins")
		end

		Sessions.Mutate(Player, function(CurrentSession)
			CurrentSession.AutoWinsEnabled = false
		end)
		SyncPlayerAttribute(Player, false)
		return false
	end

	local TargetState = (Enabled == true)
	Sessions.Mutate(Player, function(CurrentSession)
		CurrentSession.AutoWinsEnabled = TargetState
	end)
	SyncPlayerAttribute(Player, TargetState)
	return true
end

function AutoWinsService:ProcessLoop()
	for _, Player in Players:GetPlayers() do
		local Session = Sessions.Get(Player)
		if not Session or Session.ProfileMutationsFrozen then
			continue
		end

		if not Session.HasAutoWins then
			if Session.AutoWinsEnabled then
				Sessions.Mutate(Player, function(CurrentSession)
					CurrentSession.AutoWinsEnabled = false
				end)
				SyncPlayerAttribute(Player, false)
			end
			continue
		end

		if not Session.AutoWinsEnabled then
			continue
		end

		if Session.State == "InLobby" then
			local ServicesFound, PortalService = pcall(function()
				return ServiceRegistry.Get("PortalService")
			end)
			if ServicesFound and PortalService then
				PortalService:SelectMap(Player, "WORLD1")
			end
		elseif Session.State == "InWorld" then
			local WorldInstance = WorldInstances.Get(Player)
			if WorldInstance then
				local ServicesFound, DestructionService, WorldInstanceService, RewardPortalService = pcall(function()
					return ServiceRegistry.Get("DestructionService"),
						ServiceRegistry.Get("WorldInstanceService"),
						ServiceRegistry.Get("RewardPortalService")
				end)

				if ServicesFound and DestructionService and not WorldInstance.ObjectiveCompleted then
					if DestructionService.CompleteObjective then
						DestructionService:CompleteObjective(WorldInstance, WorldInstanceService)
					end
				end

				if ServicesFound and RewardPortalService and WorldInstance.RewardState == "Choosing" then
					RewardPortalService:RequestClaimReward(Player, "Free")
				end
			end
		end
	end
end

return AutoWinsService
