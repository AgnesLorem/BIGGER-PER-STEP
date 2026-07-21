--!strict
-- src/shared/Game/Config/UpgradesConfig.luau
-- Authoritative configuration and validation helper for Growth Upgrades.

export type UpgradeDefinition = {
	Id: string,
	Name: string,
	Multiplier: number,
	RequiredDestruction: number,
	RequiredLevel: number,
}

local Sequence: { string } = table.freeze({
	"None",
	"Protein",
	"SilverProtein",
	"GoldProtein",
	"DiamondProtein",
	"GrowthSerum",
	"AdvancedSerum",
	"TitanSerum",
})

local NoneDefinition: UpgradeDefinition = table.freeze({
	Id = "None",
	Name = "None",
	Multiplier = 1.0,
	RequiredDestruction = 0,
	RequiredLevel = 1,
})

local ProteinDefinition: UpgradeDefinition = table.freeze({
	Id = "Protein",
	Name = "Protein",
	Multiplier = 1.5,
	RequiredDestruction = 1,
	RequiredLevel = 5,
})

local SilverProteinDefinition: UpgradeDefinition = table.freeze({
	Id = "SilverProtein",
	Name = "Silver Protein",
	Multiplier = 2.0,
	RequiredDestruction = 5,
	RequiredLevel = 10,
})

local GoldProteinDefinition: UpgradeDefinition = table.freeze({
	Id = "GoldProtein",
	Name = "Gold Protein",
	Multiplier = 3.0,
	RequiredDestruction = 15,
	RequiredLevel = 25,
})

local DiamondProteinDefinition: UpgradeDefinition = table.freeze({
	Id = "DiamondProtein",
	Name = "Diamond Protein",
	Multiplier = 5.0,
	RequiredDestruction = 30,
	RequiredLevel = 50,
})

local GrowthSerumDefinition: UpgradeDefinition = table.freeze({
	Id = "GrowthSerum",
	Name = "Growth Serum",
	Multiplier = 10.0,
	RequiredDestruction = 60,
	RequiredLevel = 100,
})

local AdvancedSerumDefinition: UpgradeDefinition = table.freeze({
	Id = "AdvancedSerum",
	Name = "Advanced Serum",
	Multiplier = 25.0,
	RequiredDestruction = 120,
	RequiredLevel = 200,
})

local TitanSerumDefinition: UpgradeDefinition = table.freeze({
	Id = "TitanSerum",
	Name = "Titan Serum",
	Multiplier = 50.0,
	RequiredDestruction = 250,
	RequiredLevel = 500,
})

local Upgrades: { [string]: UpgradeDefinition } = table.freeze({
	None = NoneDefinition,
	Protein = ProteinDefinition,
	SilverProtein = SilverProteinDefinition,
	GoldProtein = GoldProteinDefinition,
	DiamondProtein = DiamondProteinDefinition,
	GrowthSerum = GrowthSerumDefinition,
	AdvancedSerum = AdvancedSerumDefinition,
	TitanSerum = TitanSerumDefinition,
})

local PreviousUpgradeMap: { [string]: string } = table.freeze({
	SilverProtein = "Protein",
	GoldProtein = "SilverProtein",
	DiamondProtein = "GoldProtein",
	GrowthSerum = "DiamondProtein",
	AdvancedSerum = "GrowthSerum",
	TitanSerum = "AdvancedSerum",
})

local UpgradesConfig = {}

UpgradesConfig.Sequence = Sequence
UpgradesConfig.Upgrades = Upgrades

function UpgradesConfig.GetDefinition(UpgradeId: string?): UpgradeDefinition?
	if not UpgradeId or UpgradeId == "" then
		return NoneDefinition
	end
	return Upgrades[UpgradeId]
end

function UpgradesConfig.GetMultiplier(UpgradeId: string?): number
	if not UpgradeId or UpgradeId == "" then
		return 1.0
	end
	local Def = Upgrades[UpgradeId]
	if not Def then
		return 1.0
	end
	return Def.Multiplier
end

function UpgradesConfig.GetPreviousUpgradeId(UpgradeId: string): string?
	return PreviousUpgradeMap[UpgradeId]
end

function UpgradesConfig.CanUnlock(
	UnlockedMap: { [string]: boolean }?,
	Destruction: number,
	Level: number,
	UpgradeId: string
): boolean
	if type(UpgradeId) ~= "string" or UpgradeId == "None" or UpgradeId == "" then
		return false
	end
	local TargetDef = Upgrades[UpgradeId]
	if not TargetDef then
		return false
	end
	if type(Destruction) ~= "number" or Destruction ~= Destruction or Destruction < 0 or Destruction % 1 ~= 0 then
		return false
	end
	if type(Level) ~= "number" or Level ~= Level or Level < 1 or Level % 1 ~= 0 then
		return false
	end

	local Unlocked = UnlockedMap or {}
	if Unlocked[UpgradeId] == true then
		return false -- Already unlocked
	end

	local RequiredPrev = PreviousUpgradeMap[UpgradeId]
	if RequiredPrev and Unlocked[RequiredPrev] ~= true then
		return false -- Previous upgrade in sequence is locked
	end

	if Destruction < TargetDef.RequiredDestruction or Level < TargetDef.RequiredLevel then
		return false
	end

	return true
end

function UpgradesConfig.CanEquip(UnlockedMap: { [string]: boolean }?, UpgradeId: string?): boolean
	if not UpgradeId or UpgradeId == "" or UpgradeId == "None" then
		return true -- Virtual default state always available
	end
	local TargetDef = Upgrades[UpgradeId]
	if not TargetDef then
		return false -- Unknown upgrade ID
	end

	local Unlocked = UnlockedMap or {}
	return Unlocked[UpgradeId] == true
end

return table.freeze(UpgradesConfig)
