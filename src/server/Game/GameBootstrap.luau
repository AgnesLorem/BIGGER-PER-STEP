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

--// Service \\--
local GameBootstrap = {}

function GameBootstrap.Init()
	ServiceRegistry.Register("GrowthFormula", GrowthFormula)
	ServiceRegistry.Register("WorldInstanceService", WorldInstanceService)
	ServiceRegistry.Register("PortalService", PortalService)
	ServiceRegistry.Register("DestructionService", DestructionService)
	ServiceRegistry.Register("RewardPortalService", RewardPortalService)
	MovementGrowthSystem.Init()
	AFKZoneSystem.Init()
	WorldInstanceService:Init()
	DestructionService:Init()
	RewardPortalService:Init()
	PortalService:Init()
end

function GameBootstrap.Start()
	MovementGrowthSystem.Start()
	AFKZoneSystem.Start()
	WorldInstanceService:Start()
	DestructionService:Start()
	RewardPortalService:Start()
	PortalService:Start()
end

return GameBootstrap
