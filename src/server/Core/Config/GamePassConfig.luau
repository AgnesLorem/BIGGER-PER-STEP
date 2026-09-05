--!strict
-- GamePassConfig.luau
-- Server-only Game Pass metadata. AssetId is required before server boot.

export type PassConfig = {
	AssetId: number?,
	Price: number,
	ProfileKey: "HasVip" | "HasPremiumZonePass" | "HasAutoWins",
}
export type PassKey = "Vip" | "PremiumZone" | "AutoWins"

local GamePassConfig: { [PassKey]: PassConfig } = {
	Vip = table.freeze({
		AssetId = 0,
		Price = 199,
		ProfileKey = "HasVip",
	}),
	PremiumZone = table.freeze({
		AssetId = 0,
		Price = 99,
		ProfileKey = "HasPremiumZonePass",
	}),
	AutoWins = table.freeze({
		AssetId = 0,
		Price = 149,
		ProfileKey = "HasAutoWins",
	}),
}

return table.freeze(GamePassConfig)
