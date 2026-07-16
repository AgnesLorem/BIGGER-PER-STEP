--!strict
--// Raw Requirings \\--

--// Requirings \\--
local GrowthTypes = require(
	game:GetService("ReplicatedStorage")
		:WaitForChild("BiggerShared")
		:WaitForChild("Core")
		:WaitForChild("Types")
		:WaitForChild("GrowthTypes")
)
local Sessions = require(script.Parent.Parent.Parent.Core.Registry.RuntimeRegistry.Sessions)

--// Types \\--
type GrowthContext = GrowthTypes.GrowthContext
type Session = Sessions.Session

--// Helpers \\--
local function GetRebirthMultiplier(Session: Session): number
	-- Stub for rebirth multiplier (1 for now)
	return 1
end

local function GetEquipmentMultiplier(Session: Session): number
	-- Stub for equipment multiplier (1 for now)
	return 1
end

local function GetAuraMultiplier(Session: Session): number
	-- Stub for aura multiplier (1 for now)
	return 1
end

local function GetPotionMultiplier(Session: Session): number
	-- Stub for potion multiplier (1 for now)
	return 1
end

local function GetEventMultiplier(Session: Session): number
	-- Stub for event multiplier (1 for now)
	return 1
end

local function GetVipMultiplier(Session: Session): number
	-- Stub for VIP multiplier (1 for now)
	return 1
end

--// Service \\--
local GrowthFormula = {}

function GrowthFormula.GetMultiplier(Session: Session): number
	local Multiplier = 1
	Multiplier *= GetRebirthMultiplier(Session)
	Multiplier *= GetEquipmentMultiplier(Session)
	Multiplier *= GetAuraMultiplier(Session)
	Multiplier *= GetPotionMultiplier(Session)
	Multiplier *= GetEventMultiplier(Session)
	Multiplier *= GetVipMultiplier(Session)

	if Session.HasDoubleMultiplier then
		Multiplier *= 2
	end
	if Session.HasVip then
		Multiplier *= 2
	end

	return Multiplier
end

function GrowthFormula.Calculate(Session: Session, Context: GrowthContext): number
	local Multiplier = GrowthFormula.GetMultiplier(Session)
	local BaseGain = Context.BaseGain
	local ZoneMultiplier = Context.ZoneMultiplier or 1
	local FinalGain = BaseGain * ZoneMultiplier * Multiplier

	return math.floor(FinalGain)
end

return table.freeze(GrowthFormula)
