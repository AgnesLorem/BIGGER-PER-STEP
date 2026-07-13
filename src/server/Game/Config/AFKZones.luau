--!strict
--// config \\--
return table.freeze({
	Spawn = table.freeze({
		TickRate = 1,
		RequiredRebirth = 0,
		BaseGain = 1,
		ZoneMultiplier = 2,
	}),
	Forest = table.freeze({
		TickRate = 1,
		RequiredRebirth = 1,
		BaseGain = 1,
		ZoneMultiplier = 3,
	}),
	Volcano = table.freeze({
		TickRate = 1,
		RequiredRebirth = 3,
		BaseGain = 1,
		ZoneMultiplier = 10,
	}),
})
