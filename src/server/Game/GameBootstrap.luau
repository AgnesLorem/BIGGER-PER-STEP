--!strict
--// Raw Requirings \\--

--// Requirings \\--
local ServiceRegistry = require(script.Parent.Parent.Core.Registry.ServiceRegistry)
local GrowthFormula = require(script.Parent.Formula.GrowthFormula)
local MovementGrowthSystem = require(script.Parent.Systems.MovementGrowthSystem)
local AFKZoneSystem = require(script.Parent.Systems.AFKZoneSystem)
local WorldInstanceService = require(script.Parent.Services.WorldInstanceService)
local PortalService = require(script.Parent.Services.PortalService)
local DestructionService = require(script.Parent.Services.DestructionService)
local RewardPortalService = require(script.Parent.Services.RewardPortalService)
local RebirthService = require(script.Parent.Services.RebirthService)
local UpgradeService = require(script.Parent.Services.UpgradeService)
-- local AutoWinsService = require(script.Parent.Services.AutoWinsService) -- Quarantined for MVP-006: Non-MVP peripheral service
local VIPDoorSystem = require(script.Parent.Systems.VIPDoorSystem)
-- local DailyRewardService = require(script.Parent.Services.DailyRewardService) -- Quarantined for MVP-006: Non-MVP peripheral service
-- local SpinWheelService = require(script.Parent.Services.SpinWheelService) -- Quarantined for MVP-006: Non-MVP peripheral service
-- local CosmeticsService = require(script.Parent.Services.CosmeticsService) -- Quarantined for MVP-006: Non-MVP peripheral service

--// Service \\--
local GameBootstrap = {}

function GameBootstrap.Init()
	ServiceRegistry.Register("GrowthFormula", GrowthFormula)
	ServiceRegistry.Register("WorldInstanceService", WorldInstanceService)
	ServiceRegistry.Register("PortalService", PortalService)
	ServiceRegistry.Register("DestructionService", DestructionService)
	ServiceRegistry.Register("RewardPortalService", RewardPortalService)
	ServiceRegistry.Register("RebirthService", RebirthService)
	ServiceRegistry.Register("UpgradeService", UpgradeService)
	-- ServiceRegistry.Register("AutoWinsService", AutoWinsService) -- Quarantined for MVP-006: Non-MVP peripheral service
	ServiceRegistry.Register("VIPDoorSystem", VIPDoorSystem)
	-- ServiceRegistry.Register("DailyRewardService", DailyRewardService) -- Quarantined for MVP-006: Non-MVP peripheral service
	-- ServiceRegistry.Register("SpinWheelService", SpinWheelService) -- Quarantined for MVP-006: Non-MVP peripheral service
	-- ServiceRegistry.Register("CosmeticsService", CosmeticsService) -- Quarantined for MVP-006: Non-MVP peripheral service
	MovementGrowthSystem.Init()
	AFKZoneSystem.Init()
	VIPDoorSystem.Init()
	WorldInstanceService:Init()
	DestructionService:Init()
	RewardPortalService:Init()
	PortalService:Init()
	RebirthService:Init()
	UpgradeService:Init()
	-- AutoWinsService:Init() -- Quarantined for MVP-006: Non-MVP peripheral service
	-- DailyRewardService:Init() -- Quarantined for MVP-006: Non-MVP peripheral service
	-- SpinWheelService:Init() -- Quarantined for MVP-006: Non-MVP peripheral service
	-- CosmeticsService:Init() -- Quarantined for MVP-006: Non-MVP peripheral service
end

function GameBootstrap.Start()
	MovementGrowthSystem.Start()
	AFKZoneSystem.Start()
	VIPDoorSystem.Start()
	WorldInstanceService:Start()
	DestructionService:Start()
	RewardPortalService:Start()
	PortalService:Start()
	RebirthService:Start()
	UpgradeService:Start()
	-- AutoWinsService:Start() -- Quarantined for MVP-006: Non-MVP peripheral service
	-- DailyRewardService:Start() -- Quarantined for MVP-006: Non-MVP peripheral service
	-- SpinWheelService:Start() -- Quarantined for MVP-006: Non-MVP peripheral service
	-- CosmeticsService:Start() -- Quarantined for MVP-006: Non-MVP peripheral service
end

return GameBootstrap
