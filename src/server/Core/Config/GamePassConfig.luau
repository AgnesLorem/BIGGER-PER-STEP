--!strict
-- GamePassConfig.luau
-- Server-only Game Pass metadata. AssetId is required before server boot.

export type PassConfig = {
	AssetId: number?,
	Price: number,
	ProfileKey: "HasVip" | "HasPremiumZonePass",
}
export type PassKey = "Vip" | "PremiumZone"

local GamePassConfig: { [PassKey]: PassConfig } = {
	Vip = table.freeze({
		Price = 199,
		ProfileKey = "HasVip",
	}),
	PremiumZone = table.freeze({
		Price = 99,
		ProfileKey = "HasPremiumZonePass",
	}),
}

return table.freeze(GamePassConfig)
