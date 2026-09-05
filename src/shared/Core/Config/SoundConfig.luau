--!strict
-- src/shared/Core/Config/SoundConfig.luau
-- Sound Asset ID registry. AssetId = 0 means sound is disabled (fail-close).

return table.freeze({
	Footstep = table.freeze({ AssetId = 0, Volume = 0.4, MaxPitchShift = 0.6 }),
	StompImpact = table.freeze({ AssetId = 0, Volume = 0.8, MaxPitchShift = 0.6 }),
	LevelUp = table.freeze({ AssetId = 0, Volume = 0.6 }),
	Rebirth = table.freeze({ AssetId = 0, Volume = 1.0 }),
	PortalEnter = table.freeze({ AssetId = 0, Volume = 0.5 }),
	AuraActivate = table.freeze({ AssetId = 0, Volume = 0.5 }),
})
