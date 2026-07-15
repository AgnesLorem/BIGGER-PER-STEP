--!strict

---/// Content \\\---

-- Purpose: Shared progression math for converting Bigger into derived level gates.
-- Use when:
-- - Server systems need to validate a level requirement from authoritative session Bigger.
-- - Client presentation needs to display level requirements.
-- Avoid when:
-- - Computing avatar visual scale; use Core.Utilities.ScaleCurve instead.
-- Public API:
-- - LevelFormula.GetLevelFromBigger(Bigger): number
-- - LevelFormula.GetRequirementForLevel(Level): number

--// Variables \\--

local BIGGER_PER_LEVEL = 10

--// Service \\--

local LevelFormula = {}

function LevelFormula.GetLevelFromBigger(Bigger: number): number
	return math.floor(math.max(0, Bigger) / BIGGER_PER_LEVEL) + 1
end

function LevelFormula.GetRequirementForLevel(Level: number): number
	return math.max(0, Level - 1) * BIGGER_PER_LEVEL
end

return table.freeze(LevelFormula)
