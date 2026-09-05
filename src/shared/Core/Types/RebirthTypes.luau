--!strict

---/// Content \\\---

-- Purpose: Shared types for the Rebirth system network payloads.
-- Use when:
-- - RebirthService constructs an UpdateRebirth payload.
-- - RebirthController reads the UpdateRebirth payload to render UI.
-- Avoid when:
-- - Needing Rebirth error codes; use RebirthError enum instead.
-- Public API:
-- - RebirthTypes.RebirthUpdate
-- - RebirthTypes.RebirthTierSnapshot
-- Related:
-- - ReplicatedStorage.BiggerShared.Core.Enums.RebirthError
-- - ReplicatedStorage.BiggerShared.Game.Progression.RebirthConfig

export type RebirthTierSnapshot = {
	RequiredSize: number,
	GrowthMultiplier: number,
}

export type RebirthUpdate = {
	Version: number,
	Timestamp: number,
	CurrentSize: number,
	RequiredSize: number,
	CurrentLevel: number,
	RequiredLevel: number,
	GrowthMultiplier: number,
	NextGrowthMultiplier: number,
	Rebirths: number,
	CanRebirth: boolean,
	PreviewTiers: { RebirthTierSnapshot },
	Error: string,
}

return {}
