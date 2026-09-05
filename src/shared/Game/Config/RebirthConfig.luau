--!strict
-- src/shared/Game/Config/RebirthConfig.luau
-- Authoritative configuration for the Rebirth progression system.
-- MVP-08: Rebirth resets Bigger/Level/Scale, keeps Upgrades/Destruction/Portal.
-- Linear Multiplier model: Mult(R) = BaseMultiplier + R * MultiplierPerRebirth

return table.freeze({
	BaseLevelRequirement = 20,
	LevelIncrementPerRebirth = 50,
	BaseMultiplier = 1.0,
	MultiplierPerRebirth = 0.75,
	MinimumRebirthCooldownSeconds = 2,
})
