--!strict

---/// Content \\\---

-- Purpose: Read-only balance constants for the Rebirth progression reset system.
-- Use when:
-- - RebirthService needs BaseSizeRequirement, CostMultiplier, cooldown, or reset values.
-- - RebirthController needs MaxPreviewTiers for UI cycling.
-- - RewardDispatcher or DeveloperProductConfig references SkipRebirthProductId.
-- Avoid when:
-- - Computing derived GrowthMultiplier; use GrowthFormula instead.
-- Public API:
-- - RebirthConfig.BaseSizeRequirement
-- - RebirthConfig.CostMultiplier
-- - RebirthConfig.SkipRebirthProductId
-- - RebirthConfig.CooldownSeconds
-- - RebirthConfig.MaxPreviewTiers
-- - RebirthConfig.RebirthResetSize
-- Related:
-- - ReplicatedStorage.BiggerShared.Game.Progression.LevelFormula
-- - ReplicatedStorage.BiggerShared.Core.Types.RebirthTypes

return table.freeze({
	BaseSizeRequirement = 1000,
	CostMultiplier = 1.5,
	SkipRebirthProductId = 0,
	CooldownSeconds = 1,
	MaxPreviewTiers = 5,
	RebirthResetSize = 1,
})
