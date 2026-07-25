--!strict
-- ShopUIConfig.luau
-- Client-facing presentation configurations for Developer Products in the Shop.

export type ShopItem = {
	ProductId: number,
	Display: string,
	Description: string,
	Gradient: { Color3 },
	Icon: string,
	SortOrder: number,
}

local ShopUIConfig: { [string]: ShopItem } = {
	Bigger150K = {
		ProductId = 88087258,
		Display = "+150K BIGGER",
		Description = "Instantly gain 150,000 size!",
		Gradient = { Color3.fromRGB(0, 170, 255), Color3.fromRGB(0, 85, 255) },
		Icon = "rbxassetid://88201938796604",
		SortOrder = 1,
	},
	Bigger1M = {
		ProductId = 88201938,
		Display = "+1M BIGGER",
		Description = "Instantly gain 1,000,000 size!",
		Gradient = { Color3.fromRGB(0, 255, 127), Color3.fromRGB(0, 170, 85) },
		Icon = "rbxassetid://88201938796604",
		SortOrder = 2,
	},
	Bigger10M = {
		ProductId = 88201939,
		Display = "+10M BIGGER",
		Description = "Instantly gain 10,000,000 size!",
		Gradient = { Color3.fromRGB(255, 85, 85), Color3.fromRGB(170, 0, 0) },
		Icon = "rbxassetid://88201938796604",
		SortOrder = 3,
	},
	SkipRebirth = {
		ProductId = 0,
		Display = "SKIP REBIRTH",
		Description = "Instantly rebirth without reaching the size requirement!",
		Gradient = { Color3.fromRGB(255, 170, 0), Color3.fromRGB(255, 85, 0) },
		Icon = "rbxassetid://88201938796604",
		SortOrder = 4,
	},
}

return table.freeze(ShopUIConfig)
