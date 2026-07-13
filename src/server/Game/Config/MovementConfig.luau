--!strict
--// config \\--
return table.freeze({
	TickRate = 0.2, -- Position polling rate
	MinimumRewardInterval = 0.5, -- Minimum delay between rewards
	DistanceThreshold = 3, -- Minimum studs moved to qualify
	BaseGain = 1, -- Base Bigger gain
})
