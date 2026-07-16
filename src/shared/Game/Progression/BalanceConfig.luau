--!strict

---/// Content \\\---

-- Purpose: Milestone-based progression stage definitions and base requirement constants.
-- Use when:
-- - Need stage boundary data (MinLevel/MaxLevel) for progression math or UI.
-- - LevelFormula needs per-stage CalculateRequirement functions.
-- Avoid when:
-- - Need derived level/progress values; use LevelFormula instead.
-- Public API:
-- - BalanceConfig.Stages: { StageConfig }

--// Types \\--

export type StageConfig = {
	Name: string,
	MinLevel: number,
	MaxLevel: number,
	BaseRequirement: number,
	CalculateRequirement: (Level: number, BaseRequirement: number) -> number,
}

--// Variables \\--

local Stages: { StageConfig } = {
	{
		Name = "Tutorial",
		MinLevel = 1,
		MaxLevel = 20,
		BaseRequirement = 0,
		CalculateRequirement = function(Level: number, BaseRequirement: number): number
			if Level <= 1 then return 0 end
			return 5 + (Level - 2) -- Linear: 5, 6, 7, 8, 9...
		end,
	},
	{
		Name = "Early",
		MinLevel = 21,
		MaxLevel = 75,
		BaseRequirement = 0,
		CalculateRequirement = function(Level: number, BaseRequirement: number): number
			local DeltaL = Level - 20
			return BaseRequirement + 1.5 * DeltaL + 0.1 * (DeltaL ^ 2)
		end,
	},
	{
		Name = "Mid",
		MinLevel = 76,
		MaxLevel = 150,
		BaseRequirement = 0,
		CalculateRequirement = function(Level: number, BaseRequirement: number): number
			local DeltaL = Level - 75
			return BaseRequirement + 10 * DeltaL + 0.5 * (DeltaL ^ 2.5)
		end,
	},
	{
		Name = "Late",
		MinLevel = 151,
		MaxLevel = math.huge,
		BaseRequirement = 0,
		CalculateRequirement = function(Level: number, BaseRequirement: number): number
			local DeltaL = Level - 150
			return BaseRequirement + 100 * DeltaL + 2 * (DeltaL ^ 3)
		end,
	},
}

-- Resolve BaseRequirements dynamically at initialization
for i = 2, #Stages do
	local PrevStage = Stages[i - 1]
	local PrevBase = PrevStage.BaseRequirement
	local EndReq = math.floor(PrevStage.CalculateRequirement(PrevStage.MaxLevel, PrevBase))
	Stages[i].BaseRequirement = EndReq
end

return table.freeze({
	Stages = table.freeze(Stages),
})
