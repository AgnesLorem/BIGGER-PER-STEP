--!strict
-- src/shared/Game/Config/AuraConfig.luau
-- Authoritative configuration for the multi-tier Aura progression system.
-- Tiers unlock passively at Destruction milestones. Buff = highest unlocked tier.
-- Aura cosmetic selection is decoupled from buff.

export type AuraTier = {
	Id: string,
	Name: string,
	RequiredDestruction: number,
	Multiplier: number,
	Color: { R: number, G: number, B: number },
}

return table.freeze({
	Tiers = table.freeze({
		table.freeze({
			Id = "GreenKi",
			Name = "Green Ki",
			RequiredDestruction = 10,
			Multiplier = 1.15,
			Color = table.freeze({ R = 0, G = 255, B = 100 }),
		}),
		table.freeze({
			Id = "BlueKi",
			Name = "Blue Ki",
			RequiredDestruction = 30,
			Multiplier = 1.30,
			Color = table.freeze({ R = 0, G = 120, B = 255 }),
		}),
		table.freeze({
			Id = "GoldKi",
			Name = "Golden Ki",
			RequiredDestruction = 60,
			Multiplier = 1.50,
			Color = table.freeze({ R = 255, G = 215, B = 0 }),
		}),
		table.freeze({
			Id = "GodKi",
			Name = "God Ki",
			RequiredDestruction = 100,
			Multiplier = 1.75,
			Color = table.freeze({ R = 220, G = 20, B = 80 }),
		}),
	}),
	NoneId = "None",
	MaximumUnlockedAuras = 16,
})
