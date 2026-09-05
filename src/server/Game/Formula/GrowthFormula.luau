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
local UpgradeConfig: any = nil
pcall(function()
	UpgradeConfig = require(script.Parent.Parent.Config.UpgradeConfig)
end)

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
	Multiplier *= (Session.Rebirth + 1)

	return Multiplier
end

function GrowthFormula.Calculate(Session: Session, Context: GrowthContext): number
	local Multiplier = GrowthFormula.GetMultiplier(Session)
	local BaseGain = Context.BaseGain
	local AdditiveGrowth = 0
	if Session.EquippedGrowthUpgrade and UpgradeConfig and UpgradeConfig.Get then
		local Upgrade = UpgradeConfig.Get(Session.EquippedGrowthUpgrade)
		if Upgrade then
			AdditiveGrowth = Upgrade.AdditiveGrowth
		end
	end
	local ZoneMultiplier = Context.ZoneMultiplier or 1
	local FinalGain = (BaseGain + AdditiveGrowth) * ZoneMultiplier * Multiplier

	return FinalGain
end

return table.freeze(GrowthFormula)
