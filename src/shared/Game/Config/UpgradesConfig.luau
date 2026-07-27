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

local MAX_SAFE_INTEGER = 9007199254740991

local Sequence: { string } = {
	"None",
	"Protein",
	"SilverProtein",
	"GoldProtein",
	"DiamondProtein",
	"GrowthSerum",
	"AdvancedSerum",
	"TitanSerum",
}

local NoneDefinition: UpgradeDefinition = {
	Id = "None",
	Name = "None",
	Multiplier = 1.0,
	RequiredDestruction = 0,
	RequiredLevel = 1,
}

local ProteinDefinition: UpgradeDefinition = {
	Id = "Protein",
	Name = "Protein",
	Multiplier = 1.5,
	RequiredDestruction = 1,
	RequiredLevel = 5,
}

local SilverProteinDefinition: UpgradeDefinition = {
	Id = "SilverProtein",
	Name = "Silver Protein",
	Multiplier = 2.0,
	RequiredDestruction = 5,
	RequiredLevel = 10,
}

local GoldProteinDefinition: UpgradeDefinition = {
	Id = "GoldProtein",
	Name = "Gold Protein",
	Multiplier = 3.0,
	RequiredDestruction = 15,
	RequiredLevel = 25,
}

local DiamondProteinDefinition: UpgradeDefinition = {
	Id = "DiamondProtein",
	Name = "Diamond Protein",
	Multiplier = 5.0,
	RequiredDestruction = 30,
	RequiredLevel = 50,
}

local GrowthSerumDefinition: UpgradeDefinition = {
	Id = "GrowthSerum",
	Name = "Growth Serum",
	Multiplier = 10.0,
	RequiredDestruction = 60,
	RequiredLevel = 100,
}

local AdvancedSerumDefinition: UpgradeDefinition = {
	Id = "AdvancedSerum",
	Name = "Advanced Serum",
	Multiplier = 25.0,
	RequiredDestruction = 120,
	RequiredLevel = 200,
}

local TitanSerumDefinition: UpgradeDefinition = {
	Id = "TitanSerum",
	Name = "Titan Serum",
	Multiplier = 50.0,
	RequiredDestruction = 250,
	RequiredLevel = 500,
}

local Upgrades: { [string]: UpgradeDefinition } = {
	None = NoneDefinition,
	Protein = ProteinDefinition,
	SilverProtein = SilverProteinDefinition,
	GoldProtein = GoldProteinDefinition,
	DiamondProtein = DiamondProteinDefinition,
	GrowthSerum = GrowthSerumDefinition,
	AdvancedSerum = AdvancedSerumDefinition,
	TitanSerum = TitanSerumDefinition,
}

local PreviousUpgradeMap: { [string]: string } = {
	SilverProtein = "Protein",
	GoldProtein = "SilverProtein",
	DiamondProtein = "GoldProtein",
	GrowthSerum = "DiamondProtein",
	AdvancedSerum = "GrowthSerum",
	TitanSerum = "AdvancedSerum",
}

-- Deep validation before freezing
assert(type(Sequence) == "table" and #Sequence == 8, "Sequence must contain exactly 8 elements")
local SeenSequenceIds: { [string]: boolean } = {}
for _, Id in Sequence do
	assert(type(Id) == "string" and Id ~= "", "Sequence element must be non-empty string")
	assert(not SeenSequenceIds[Id], "Sequence element must be unique: " .. tostring(Id))
	assert(Upgrades[Id] ~= nil, "Sequence element must have a definition: " .. tostring(Id))
	SeenSequenceIds[Id] = true
end

for Key, Def in Upgrades do
	assert(SeenSequenceIds[Key] == true, "No definition may exist outside Sequence: " .. tostring(Key))
	assert(type(Def) == "table", "UpgradeDefinition must be a table")
	assert(Def.Id == Key, "Definition Id must match table key: " .. tostring(Key))
	assert(type(Def.Name) == "string" and Def.Name ~= "", "Definition Name must be non-empty string")
	assert(
		type(Def.Multiplier) == "number"
			and Def.Multiplier > 0
			and Def.Multiplier == Def.Multiplier
			and Def.Multiplier < math.huge,
		"Multiplier must be finite positive number"
	)
	assert(
		type(Def.RequiredDestruction) == "number"
			and Def.RequiredDestruction >= 0
			and Def.RequiredDestruction % 1 == 0
			and Def.RequiredDestruction <= MAX_SAFE_INTEGER,
		"RequiredDestruction must be non-negative safe integer"
	)
	assert(
		type(Def.RequiredLevel) == "number"
			and Def.RequiredLevel >= 1
			and Def.RequiredLevel % 1 == 0
			and Def.RequiredLevel <= MAX_SAFE_INTEGER,
		"RequiredLevel must be positive safe integer"
	)
end

assert(Upgrades.None.Multiplier == 1.0, "None multiplier must be 1.0")
assert(PreviousUpgradeMap["Protein"] == nil, "Protein must have no predecessor")

local PredecessorCount = 0
for Id in PreviousUpgradeMap do
	assert(SeenSequenceIds[Id] == true, "Predecessor entry must reference a Sequence element: " .. tostring(Id))
	PredecessorCount += 1
end
assert(PredecessorCount == #Sequence - 2, "Predecessor map must contain exactly the real upgrades after Protein")

for i = 2, #Sequence do
	local CurrentId = Sequence[i]
	local ExpectedPrevId = Sequence[i - 1]
	local ActualPrevId = if CurrentId == "Protein" then nil else PreviousUpgradeMap[CurrentId]
	if CurrentId ~= "Protein" then
		assert(
			ActualPrevId == ExpectedPrevId,
			string.format(
				"Upgrade %s must have predecessor %s, got %s",
				CurrentId,
				ExpectedPrevId,
				tostring(ActualPrevId)
			)
		)
	end
end

-- Deep freezing
table.freeze(NoneDefinition)
table.freeze(ProteinDefinition)
table.freeze(SilverProteinDefinition)
table.freeze(GoldProteinDefinition)
table.freeze(DiamondProteinDefinition)
table.freeze(GrowthSerumDefinition)
table.freeze(AdvancedSerumDefinition)
table.freeze(TitanSerumDefinition)

local FrozenSequence = table.freeze(Sequence)
local FrozenUpgrades = table.freeze(Upgrades)
local FrozenPreviousMap = table.freeze(PreviousUpgradeMap)

local UpgradesConfig = {}
UpgradesConfig.Sequence = FrozenSequence
UpgradesConfig.Upgrades = FrozenUpgrades

function UpgradesConfig.GetDefinition(UpgradeId: string?): UpgradeDefinition?
	if not UpgradeId or UpgradeId == "" then
		return NoneDefinition
	end
	return FrozenUpgrades[UpgradeId]
end

function UpgradesConfig.GetMultiplier(UpgradeId: string?): number
	if not UpgradeId or UpgradeId == "" then
		return 1.0
	end
	local Def = FrozenUpgrades[UpgradeId]
	if not Def then
		return 1.0
	end
	return Def.Multiplier
end

function UpgradesConfig.GetPreviousUpgradeId(UpgradeId: string): string?
	return FrozenPreviousMap[UpgradeId]
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
	local TargetDef = FrozenUpgrades[UpgradeId]
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

	local RequiredPrev = FrozenPreviousMap[UpgradeId]
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
	local TargetDef = FrozenUpgrades[UpgradeId]
	if not TargetDef then
		return false -- Unknown upgrade ID
	end

	local Unlocked = UnlockedMap or {}
	return Unlocked[UpgradeId] == true
end

return table.freeze(UpgradesConfig)
