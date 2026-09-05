--!strict
export type ZoneConfig = {
	TickRate: number,
	BaseGain: number,
	ZoneMultiplier: number,
	MinRebirth: number?,
	PassKey: string?,
}

local Table1: ZoneConfig = table.freeze({
	TickRate = 1,
	BaseGain = 1,
	ZoneMultiplier = 50,
	MinRebirth = 0,
})

local Table2: ZoneConfig = table.freeze({
	TickRate = 1,
	BaseGain = 1,
	ZoneMultiplier = 100,
	MinRebirth = 5,
})

local Table3: ZoneConfig = table.freeze({
	TickRate = 1,
	BaseGain = 1,
	ZoneMultiplier = 150,
	MinRebirth = 10,
})

local Table4: ZoneConfig = table.freeze({
	TickRate = 1,
	BaseGain = 1,
	ZoneMultiplier = 200,
	MinRebirth = 15,
})

local Table5: ZoneConfig = table.freeze({
	TickRate = 1,
	BaseGain = 1,
	ZoneMultiplier = 250,
	MinRebirth = 20,
})

local VipTable1: ZoneConfig = table.freeze({
	TickRate = 1,
	BaseGain = 1,
	ZoneMultiplier = 300,
	MinRebirth = 0,
	PassKey = "Vip",
})

local VipTable2: ZoneConfig = table.freeze({
	TickRate = 1,
	BaseGain = 1,
	ZoneMultiplier = 400,
	MinRebirth = 0,
	PassKey = "Vip",
})

return table.freeze({
	Table1 = Table1,
	Table2 = Table2,
	Table3 = Table3,
	Table4 = Table4,
	Table5 = Table5,
	VipTable1 = VipTable1,
	VipTable2 = VipTable2,

	-- Backward compatibility aliases
	AFKZone1 = Table1,
	AFKZone2 = Table2,
	AFKZone3 = Table3,
	AFKZone4 = Table4,
	AFKZone5 = Table5,
	AFKZone6 = VipTable1,
	AFKZone7 = VipTable2,
})
