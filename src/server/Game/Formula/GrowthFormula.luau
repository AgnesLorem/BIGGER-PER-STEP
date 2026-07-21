--!strict
--// Raw Requirings \\--

local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Requirings \\--
local UpgradesConfig
if typeof(ReplicatedStorage) == "table" and (ReplicatedStorage :: any).UpgradesConfig then
	UpgradesConfig = (ReplicatedStorage :: any).UpgradesConfig
else
	UpgradesConfig = require(
		ReplicatedStorage:WaitForChild("BiggerShared")
			:WaitForChild("Game")
			:WaitForChild("Config")
			:WaitForChild("UpgradesConfig")
	)
end

local GrowthTypes
if typeof(ReplicatedStorage) == "table" and (ReplicatedStorage :: any).GrowthTypes then
	GrowthTypes = (ReplicatedStorage :: any).GrowthTypes
else
	GrowthTypes = require(
		ReplicatedStorage:WaitForChild("BiggerShared")
			:WaitForChild("Core")
			:WaitForChild("Types")
			:WaitForChild("GrowthTypes")
	)
end

local Sessions
if typeof(script) == "Instance" and script.Parent then
	Sessions = require(script.Parent.Parent.Parent.Core.Registry.RuntimeRegistry.Sessions)
else
	Sessions = require("../../Core/Registry/RuntimeRegistry/Sessions")
end

--// Types \\--
type GrowthContext = any
type Session = Sessions.Session

--// Service \\--
local GrowthFormula = {}

function GrowthFormula.GetMultiplier(Session: Session): number
	local EquipmentMult = UpgradesConfig.GetMultiplier(Session.EquippedGrowthUpgrade)
	local Multiplier = EquipmentMult
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

	return FinalGain
end

return table.freeze(GrowthFormula)
