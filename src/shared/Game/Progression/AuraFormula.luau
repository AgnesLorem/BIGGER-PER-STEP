--!strict

---/// Content \\\---

-- Purpose: Shared progression math for Aura unlocks and multipliers.
-- Public API:
-- - AuraFormula.GetHighestUnlockedTier(UnlockedAuras)
-- - AuraFormula.GetMultiplier(UnlockedAuras)
-- - AuraFormula.GetUnlockableAuras(Destruction)
-- - AuraFormula.CanEquip(UnlockedAuras, AuraId)

--// Variables \\--

local AuraConfig = require(script.Parent.Parent.Config.AuraConfig)

--// Service \\--

local AuraFormula = {}

function AuraFormula.GetHighestUnlockedTier(UnlockedAuras: { [string]: boolean }): AuraConfig.AuraTier?
	for i = #AuraConfig.Tiers, 1, -1 do
		local Tier = AuraConfig.Tiers[i]
		if UnlockedAuras[Tier.Id] == true then
			return Tier
		end
	end
	return nil
end

function AuraFormula.GetMultiplier(UnlockedAuras: { [string]: boolean }): number
	local HighestTier = AuraFormula.GetHighestUnlockedTier(UnlockedAuras)
	if HighestTier then
		return HighestTier.Multiplier
	end
	return 1.0
end

function AuraFormula.GetUnlockableAuras(Destruction: number): { string }
	local Unlockable = {}
	for _, Tier in ipairs(AuraConfig.Tiers) do
		if Destruction >= Tier.RequiredDestruction then
			table.insert(Unlockable, Tier.Id)
		end
	end
	return Unlockable
end

function AuraFormula.CanEquip(UnlockedAuras: { [string]: boolean }, AuraId: string): boolean
	if AuraId == AuraConfig.NoneId then
		return true
	end
	return UnlockedAuras[AuraId] == true
end

return table.freeze(AuraFormula)
