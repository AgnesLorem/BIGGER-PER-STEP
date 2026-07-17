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
	DoubleMultiplier = {
		ProductId = 999991, -- Placeholder ID (user will replace with actual ID)
		Display = "2X Multiplier",
		Description = "Double your size gains permanently!",
		Gradient = { Color3.fromRGB(255, 220, 0), Color3.fromRGB(255, 120, 0) },
		Icon = "rbxassetid://122745440429816",
		SortOrder = 4,
	},
	Vip = {
		ProductId = 999992, -- Placeholder ID (user will replace with actual ID)
		Display = "VIP Pass",
		Description = "Gain permanent 2X multiplier & a special VIP tag!",
		Gradient = { Color3.fromRGB(255, 0, 0), Color3.fromRGB(0, 0, 255) }, -- Color handles rainbow gradient
		Icon = "rbxassetid://122745440429816",
		SortOrder = 5,
	},
}

return table.freeze(ShopUIConfig)
