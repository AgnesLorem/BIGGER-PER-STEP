--!strict
--// Raw Requirings \\--

local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Requirings \\--
local UpgradesConfig = require(
	ReplicatedStorage:WaitForChild("BiggerShared")
		:WaitForChild("Game")
		:WaitForChild("Config")
		:WaitForChild("UpgradesConfig")
)
local RebirthFormula = require(
	ReplicatedStorage:WaitForChild("BiggerShared")
		:WaitForChild("Game")
		:WaitForChild("Progression")
		:WaitForChild("RebirthFormula")
)
local Sessions = require(script.Parent.Parent.Parent.Core.Registry.RuntimeRegistry.Sessions)

--// Service \\--
local GrowthFormula = {}

function GrowthFormula.GetMultiplier(Session: Sessions.Session): number
	local EquipmentMult = UpgradesConfig.GetMultiplier(Session.EquippedGrowthUpgrade)
	local RebirthMult = RebirthFormula.GetMultiplier(Session.Rebirth or 0)
	local Multiplier = EquipmentMult * RebirthMult
	if Session.HasDoubleMultiplier then
		Multiplier *= 2
	end
	if Session.HasVip then
		Multiplier *= 2
	end

	return Multiplier
end

function GrowthFormula.Calculate(Session: Sessions.Session, Context: any): number
	local Multiplier = GrowthFormula.GetMultiplier(Session)
	local BaseGain = Context.BaseGain
	local ZoneMultiplier = Context.ZoneMultiplier or 1
	local FinalGain = BaseGain * ZoneMultiplier * Multiplier

	return FinalGain
end

return table.freeze(GrowthFormula)
