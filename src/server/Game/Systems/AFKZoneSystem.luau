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

--// Helpers \\--
local function ProcessZones()
	local Success, GrowthService = pcall(function()
		return ServiceRegistry.Get("GrowthService")
	end)
	if not Success or not GrowthService then
		return
	end

	local AFKZoneFolder = Workspace:FindFirstChild("AFKZones")
	if not AFKZoneFolder then
		return
	end

	for ZoneName, ZoneConfig in AFKZones do
		local ZonePart = AFKZoneFolder:FindFirstChild(ZoneName)
		if not ZonePart or not ZonePart:IsA("BasePart") then
			continue
		end

		local PartCFrame = ZonePart.CFrame
		local PartSize = ZonePart.Size
		local HalfSize = PartSize / 2

		for _, Player in Players:GetPlayers() do
			local Session = Sessions.Get(Player)
			if not Session then
				continue
			end

			if Session.Rebirth < ZoneConfig.RequiredRebirth then
				continue
			end

			local Character = Player.Character
			local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
			if not RootPart or not RootPart:IsA("BasePart") then
				continue
			end

			local LocalPos = PartCFrame:PointToObjectSpace(RootPart.Position)
			local Inside = math.abs(LocalPos.X) <= HalfSize.X
				and LocalPos.Y >= -HalfSize.Y - 5
				and math.abs(LocalPos.Z) <= HalfSize.Z

			if Inside then
				GrowthService:AddBigger(Player, {
					BaseGain = ZoneConfig.BaseGain,
					ZoneMultiplier = ZoneConfig.ZoneMultiplier,
					Source = GrowthSource.AFKZone,
					SourceId = ZoneName,
				})
			end
		end
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
