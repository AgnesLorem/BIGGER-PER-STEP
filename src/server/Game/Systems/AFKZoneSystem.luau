--!strict
--// Raw Requirings \\--
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

--// Requirings \\--
local AFKZones = require(script.Parent.Parent.Config.AFKZones)
local GrowthSource = require(
	game:GetService("ReplicatedStorage")
		:WaitForChild("BiggerShared")
		:WaitForChild("Core")
		:WaitForChild("Enums")
		:WaitForChild("GrowthSource")
)
local Sessions = require(script.Parent.Parent.Parent.Core.Registry.RuntimeRegistry.Sessions)
local Scheduler = require(script.Parent.Parent.Parent.Core.Scheduler.Scheduler)
local ServiceRegistry = require(script.Parent.Parent.Parent.Core.Registry.ServiceRegistry)
local Logger = require(script.Parent.Parent.Parent.Core.Utilities.Logger)

--// Types \\--
type ZoneConfig = {
	TickRate: number,
	BaseGain: number,
	ZoneMultiplier: number,
	PassKey: string?,
}

--// Helpers \\--
local function IsInsideZone(RootPart: BasePart, ZonePart: BasePart): boolean
	local LocalPosition = ZonePart.CFrame:PointToObjectSpace(RootPart.Position)
	local HalfSize = ZonePart.Size / 2
	return math.abs(LocalPosition.X) <= HalfSize.X
		and LocalPosition.Y >= -HalfSize.Y - 5
		and math.abs(LocalPosition.Z) <= HalfSize.Z
end

local function ProcessZones()
	local Success, GrowthService, GamePassService = pcall(function()
		return ServiceRegistry.Get("GrowthService"), ServiceRegistry.Get("GamePassService")
	end)
	if not Success or not GrowthService or not GamePassService then
		return
	end

	local AFKZoneFolder = Workspace:FindFirstChild("AFKZones")
	if not AFKZoneFolder then
		return
	end

	for _, Player in Players:GetPlayers() do
		local Session = Sessions.Get(Player)
		if not Session then
			continue
		end
		local Character = Player.Character
		local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
		if not RootPart or not RootPart:IsA("BasePart") then
			Session.CurrentAFKZone = nil
			Session.PremiumZonePromptedThisEntry = false
			continue
		end

		local ZoneName: string? = nil
		local ZoneConfig: ZoneConfig? = nil
		for ZoneIndex = 7, 1, -1 do
			local CandidateName = "AFKZone" .. ZoneIndex
			local CandidateConfig = AFKZones[CandidateName]
			local ZonePart = AFKZoneFolder:FindFirstChild(CandidateName)
			if CandidateConfig and ZonePart and ZonePart:IsA("BasePart") and IsInsideZone(RootPart, ZonePart) then
				ZoneName = CandidateName
				ZoneConfig = CandidateConfig
				break
			end
		end

		Session.CurrentAFKZone = ZoneName
		if not ZoneName or not ZoneConfig then
			Session.PremiumZonePromptedThisEntry = false
			continue
		end

		if not ZoneConfig.PassKey then
			Session.PremiumZonePromptedThisEntry = false
		elseif not GamePassService:IsOwned(Player, ZoneConfig.PassKey) then
			if not Session.PremiumZonePromptedThisEntry then
				Session.PremiumZonePromptedThisEntry = true
				GamePassService:Prompt(Player, ZoneConfig.PassKey)
			end
			continue
		end

		GrowthService:AddBigger(Player, {
			BaseGain = ZoneConfig.BaseGain,
			ZoneMultiplier = ZoneConfig.ZoneMultiplier,
			Source = GrowthSource.AFKZone,
			SourceId = ZoneName,
		})
	end
end

--// Service \\--
local AFKZoneSystem = {}

function AFKZoneSystem.Init()
	-- No-op for initialization
end

function AFKZoneSystem.Start()
	-- 1 second tick rate for zone checks
	Scheduler.AddJob({
		Name = "AFKZoneCheck",
		IntervalSeconds = 1,
		Callback = ProcessZones,
		Priority = 5,
	})
	Logger.Info("Runtime", "AFKZoneSystem job added to Scheduler")
end

return AFKZoneSystem
