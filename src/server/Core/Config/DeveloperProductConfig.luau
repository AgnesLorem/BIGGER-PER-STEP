--!strict
-- DeveloperProductConfig.luau
-- Server-only gameplay configuration for Developer Products.

local RewardType = require(game:GetService("ReplicatedStorage"):WaitForChild("BiggerShared"):WaitForChild("Core"):WaitForChild("Enums"):WaitForChild("RewardType"))

export type Reward = {
	Type: string,
	Amount: number?,
	[string]: any,
}

export type ProductConfig = {
	ProductId: number,
	Rewards: {Reward},
	AnalyticsKey: string,
}

local DeveloperProductConfig: { [string]: ProductConfig } = {
	Bigger150K = {
		ProductId = 88087258,
		Rewards = {
			{
				Type = RewardType.Bigger,
				Amount = 150000,
			},
		},
		AnalyticsKey = "Bigger_150K",
	},
	Bigger1M = {
		ProductId = 88201938,
		Rewards = {
			{
				Type = RewardType.Bigger,
				Amount = 1000000,
			},
		},
		AnalyticsKey = "Bigger_1M",
	},
	Bigger10M = {
		ProductId = 88201939,
		Rewards = {
			{
				Type = RewardType.Bigger,
				Amount = 10000000,
			},
		},
		AnalyticsKey = "Bigger_10M",
	},
}

return table.freeze(DeveloperProductConfig)
