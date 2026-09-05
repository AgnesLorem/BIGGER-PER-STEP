--!strict
-- UpgradeConfig.luau
-- Authoritative configuration for Growth Upgrades (15 tiers).

export type Upgrade = {
	Order: number,
	Name: string,
	Id: string,
	AdditiveGrowth: number,
	Cost: number,
	-- Lifetime Destruction milestone required to unlock this upgrade (not spent or deducted)
	DestructionRequirement: number,
}

local List: { Upgrade } = {
	{ Order = 1, Name = "Protein", Id = "Protein", AdditiveGrowth = 5, Cost = 1, DestructionRequirement = 1 },
	{
		Order = 2,
		Name = "Silver Protein",
		Id = "Silver_Protein",
		AdditiveGrowth = 20,
		Cost = 5,
		DestructionRequirement = 5,
	},
	{
		Order = 3,
		Name = "Gold Protein",
		Id = "Gold_Protein",
		AdditiveGrowth = 60,
		Cost = 20,
		DestructionRequirement = 20,
	},
	{
		Order = 4,
		Name = "Diamond Protein",
		Id = "Diamond_Protein",
		AdditiveGrowth = 200,
		Cost = 50,
		DestructionRequirement = 50,
	},
	{
		Order = 5,
		Name = "Emerald Protein",
		Id = "Emerald_Protein",
		AdditiveGrowth = 650,
		Cost = 150,
		DestructionRequirement = 150,
	},
	{
		Order = 6,
		Name = "Ruby Protein",
		Id = "Ruby_Protein",
		AdditiveGrowth = 2000,
		Cost = 500,
		DestructionRequirement = 500,
	},
	{
		Order = 7,
		Name = "Obsidian Protein",
		Id = "Obsidian_Protein",
		AdditiveGrowth = 6500,
		Cost = 1000000,
		DestructionRequirement = 1000000,
	},
	{
		Order = 8,
		Name = "Growth Serum",
		Id = "Growth_Serum",
		AdditiveGrowth = 20000,
		Cost = 5000000,
		DestructionRequirement = 5000000,
	},
	{
		Order = 9,
		Name = "Silver Serum",
		Id = "Silver_Serum",
		AdditiveGrowth = 65000,
		Cost = 25000000,
		DestructionRequirement = 25000000,
	},
	{
		Order = 10,
		Name = "Gold Serum",
		Id = "Gold_Serum",
		AdditiveGrowth = 200000,
		Cost = 100000000,
		DestructionRequirement = 100000000,
	},
	{
		Order = 11,
		Name = "Diamond Serum",
		Id = "Diamond_Serum",
		AdditiveGrowth = 650000,
		Cost = 500000000,
		DestructionRequirement = 500000000,
	},
	{
		Order = 12,
		Name = "Advanced Serum",
		Id = "Advanced_Serum",
		AdditiveGrowth = 2000000,
		Cost = 2500000000,
		DestructionRequirement = 2500000000,
	},
	{
		Order = 13,
		Name = "Titan Serum",
		Id = "Titan_Serum",
		AdditiveGrowth = 6500000,
		Cost = 10000000000,
		DestructionRequirement = 10000000000,
	},
	{
		Order = 14,
		Name = "Cosmic Serum",
		Id = "Cosmic_Serum",
		AdditiveGrowth = 20000000,
		Cost = 50000000000,
		DestructionRequirement = 50000000000,
	},
	{
		Order = 15,
		Name = "Infinity Serum",
		Id = "Infinity_Serum",
		AdditiveGrowth = 65000000,
		Cost = 250000000000,
		DestructionRequirement = 250000000000,
	},
}

local ByNameOrId: { [string]: Upgrade } = {}
local ByOrder: { [number]: Upgrade } = {}

for _, item in List do
	ByNameOrId[item.Name] = item
	ByNameOrId[item.Id] = item
	ByNameOrId[string.gsub(item.Name, " ", "")] = item
	ByNameOrId[string.gsub(item.Name, " ", "_")] = item
	ByOrder[item.Order] = item
end

local UpgradeConfig = {}

UpgradeConfig.List = table.freeze(List)

function UpgradeConfig.Get(Key: any): Upgrade?
	if type(Key) == "table" and Key.Order ~= nil then
		return ByOrder[Key.Order]
	elseif type(Key) == "number" then
		return ByOrder[Key]
	elseif type(Key) == "string" then
		return ByNameOrId[Key]
	end
	return nil
end

function UpgradeConfig.GetPrevious(Key: any): Upgrade?
	local Current = UpgradeConfig.Get(Key)
	if not Current or Current.Order <= 1 then
		return nil
	end
	return ByOrder[Current.Order - 1]
end

return table.freeze(UpgradeConfig)
