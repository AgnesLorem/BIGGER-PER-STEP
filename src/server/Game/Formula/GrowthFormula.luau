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

--// Service \\--
local GrowthFormula = {}

function GrowthFormula.GetMultiplier(Session: Session): number
	local Multiplier = 1
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
