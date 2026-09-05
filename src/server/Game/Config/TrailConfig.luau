--!strict
-- TrailConfig.luau
-- Authoritative configuration for Cosmetic Trails.

export type Trail = {
	Id: string,
	Name: string,
	Color: ColorSequence | Color3,
	Lifetime: number,
	LightEmission: number,
	DefaultUnlocked: boolean,
	Texture: string?,
}

local List: { Trail } = {
	{
		Id = "Default",
		Name = "Classic Trail",
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(220, 240, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 200, 255)),
		}),
		Lifetime = 1.0,
		LightEmission = 0.5,
		DefaultUnlocked = true,
	},
	{
		Id = "FireTrail",
		Name = "Inferno Trail",
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 0)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 200, 0)),
		}),
		Lifetime = 1.2,
		LightEmission = 0.8,
		DefaultUnlocked = false,
	},
	{
		Id = "RainbowTrail",
		Name = "Rainbow Trail",
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 0, 0)),
			ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 165, 0)),
			ColorSequenceKeypoint.new(0.4, Color3.fromRGB(255, 255, 0)),
			ColorSequenceKeypoint.new(0.6, Color3.fromRGB(0, 255, 0)),
			ColorSequenceKeypoint.new(0.8, Color3.fromRGB(0, 150, 255)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(180, 0, 255)),
		}),
		Lifetime = 1.5,
		LightEmission = 0.7,
		DefaultUnlocked = false,
	},
	{
		Id = "VoidTrail",
		Name = "Void Trail",
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 0, 200)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 0, 80)),
		}),
		Lifetime = 1.0,
		LightEmission = 0.9,
		DefaultUnlocked = false,
	},
	{
		Id = "GoldenTrail",
		Name = "Golden Radiance",
		Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 220, 50)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 170, 0)),
		}),
		Lifetime = 1.3,
		LightEmission = 1.0,
		DefaultUnlocked = false,
	},
}

local ById: { [string]: Trail } = {}

for _, item in List do
	ById[item.Id] = item
end

local TrailConfig = {}

TrailConfig.List = table.freeze(List)

function TrailConfig.Get(TrailId: string): Trail?
	return ById[TrailId]
end

function TrailConfig.GetTrail(TrailId: string): Trail?
	return ById[TrailId]
end

return table.freeze(TrailConfig)
