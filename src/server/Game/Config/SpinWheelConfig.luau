--!strict
-- SpinWheelConfig.luau
-- Authoritative configuration and weighted probabilities for the Lucky Spin Wheel.

local RewardType = {
	Bigger = "Bigger",
	Destruction = "Destruction",
	SpinTokens = "SpinTokens",
	Trail = "Trail",
	Title = "Title",
}

export type Sector = {
	Index: number,
	Name: string,
	Weight: number,
	Reward: {
		Type: string,
		Amount: number?,
		Id: string?,
		[string]: any,
	},
}

local SpinWheelConfig = {}

SpinWheelConfig.Sectors = {
	{
		Index = 1,
		Name = "100 Bigger",
		Weight = 30,
		Reward = { Type = RewardType.Bigger, Amount = 100 },
	},
	{
		Index = 2,
		Name = "500 Bigger",
		Weight = 25,
		Reward = { Type = RewardType.Bigger, Amount = 500 },
	},
	{
		Index = 3,
		Name = "25 Destruction",
		Weight = 20,
		Reward = { Type = RewardType.Destruction, Amount = 25 },
	},
	{
		Index = 4,
		Name = "1 Spin Token",
		Weight = 10,
		Reward = { Type = RewardType.SpinTokens, Amount = 1 },
	},
	{
		Index = 5,
		Name = "2,000 Bigger",
		Weight = 8,
		Reward = { Type = RewardType.Bigger, Amount = 2000 },
	},
	{
		Index = 6,
		Name = "100 Destruction",
		Weight = 4,
		Reward = { Type = RewardType.Destruction, Amount = 100 },
	},
	{
		Index = 7,
		Name = "3 Spin Tokens",
		Weight = 2,
		Reward = { Type = RewardType.SpinTokens, Amount = 3 },
	},
	{
		Index = 8,
		Name = "10,000 Bigger Jackpot",
		Weight = 1,
		Reward = { Type = RewardType.Bigger, Amount = 10000 },
	},
}

function SpinWheelConfig.GetSector(Index: number): Sector?
	return SpinWheelConfig.Sectors[Index]
end

function SpinWheelConfig.GetTotalWeight(): number
	local Total = 0
	for _, Sector in SpinWheelConfig.Sectors do
		Total += Sector.Weight
	end
	return Total
end

function SpinWheelConfig.SelectRandom(Rng: Random?): Sector
	local TotalWeight = SpinWheelConfig.GetTotalWeight()
	local Roll: number
	if Rng then
		Roll = Rng:NextNumber(0, TotalWeight)
	else
		Roll = math.random() * TotalWeight
	end

	local Running = 0
	for _, Sector in SpinWheelConfig.Sectors do
		Running += Sector.Weight
		if Roll <= Running then
			return Sector
		end
	end
	return SpinWheelConfig.Sectors[#SpinWheelConfig.Sectors]
end

return table.freeze(SpinWheelConfig)
