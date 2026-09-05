--!strict
-- TitleConfig.luau
-- Authoritative configuration for Overhead Titles.

export type Title = {
	Id: string,
	DisplayName: string,
	Color: Color3,
	StrokeColor: Color3,
	DefaultUnlocked: boolean,
	StrokeThickness: number?,
}

local List: { Title } = {
	{
		Id = "Newbie",
		DisplayName = "🌱 Newbie",
		Color = Color3.fromRGB(150, 230, 150),
		StrokeColor = Color3.fromRGB(0, 50, 0),
		DefaultUnlocked = true,
		StrokeThickness = 2,
	},
	{
		Id = "Giant",
		DisplayName = "⚡ Giant",
		Color = Color3.fromRGB(255, 170, 0),
		StrokeColor = Color3.fromRGB(80, 40, 0),
		DefaultUnlocked = false,
		StrokeThickness = 2,
	},
	{
		Id = "Colossus",
		DisplayName = "💠 Colossus",
		Color = Color3.fromRGB(0, 210, 255),
		StrokeColor = Color3.fromRGB(0, 40, 90),
		DefaultUnlocked = false,
		StrokeThickness = 2,
	},
	{
		Id = "DailyMaster",
		DisplayName = "📅 Daily Master",
		Color = Color3.fromRGB(255, 215, 0),
		StrokeColor = Color3.fromRGB(70, 0, 100),
		DefaultUnlocked = false,
		StrokeThickness = 2.5,
	},
	{
		Id = "Titan",
		DisplayName = "🔥 Titan",
		Color = Color3.fromRGB(255, 60, 60),
		StrokeColor = Color3.fromRGB(80, 0, 0),
		DefaultUnlocked = false,
		StrokeThickness = 2.5,
	},
	{
		Id = "GodOfGrowth",
		DisplayName = "👑 God of Growth",
		Color = Color3.fromRGB(255, 230, 100),
		StrokeColor = Color3.fromRGB(100, 0, 120),
		DefaultUnlocked = false,
		StrokeThickness = 3,
	},
}

local ById: { [string]: Title } = {}

for _, item in List do
	ById[item.Id] = item
end

local TitleConfig = {}

TitleConfig.List = table.freeze(List)

function TitleConfig.Get(TitleId: string): Title?
	return ById[TitleId]
end

function TitleConfig.GetTitle(TitleId: string): Title?
	return ById[TitleId]
end

return table.freeze(TitleConfig)
