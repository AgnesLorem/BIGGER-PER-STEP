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
-- - LevelFormula.GetProgress(Bigger): LevelProgress
-- - LevelFormula.GetLevel(Bigger): number
-- - LevelFormula.GetRequirement(Level): number
-- - LevelFormula.GetCurrentRange(Level): (number, number)
-- - LevelFormula.GetNextRequirement(Level): number

--// Variables \\--

local BASE_REQUIREMENT = 600 / (19 * 19) -- 1.6620... derived from: Level 20 = 600 Bigger (5 min walking)
local MAX_SAFE_INTEGER = 9007199254740991

--// Types \\--

export type LevelProgress = {
	Level: number,
	CurrentRequirement: number,
	NextRequirement: number,
	BiggerIntoLevel: number,
	BiggerRequiredForNextLevel: number,
	Progress: number,
}

--// Helpers \\--

local function AssertFiniteNumber(Value: unknown, Name: string): number
	assert(type(Value) == "number", Name .. " must be a number")
	assert(Value == Value and Value > -math.huge and Value < math.huge, Name .. " must be finite")
	return Value
end

local function CalculateRequirement(Level: number): number
	return BASE_REQUIREMENT * (Level - 1) ^ 2
end

--// Service \\--

local LevelFormula = {}

function LevelFormula.GetLevelFromBigger(Bigger: number): number
	local ValidBigger = AssertFiniteNumber(Bigger, "Bigger")
	assert(ValidBigger >= 0, "Bigger must be non-negative")
	assert(ValidBigger <= MAX_SAFE_INTEGER, "Bigger exceeds the supported safe integer range")

	local Level = math.floor((ValidBigger / BASE_REQUIREMENT) ^ 0.5) + 1
	while Level > 1 and CalculateRequirement(Level) > ValidBigger do
		Level -= 1
	end
	while CalculateRequirement(Level + 1) <= ValidBigger do
		Level += 1
	end
	return Level
end

function LevelFormula.GetRequirementForLevel(Level: number): number
	local ValidLevel = AssertFiniteNumber(Level, "Level")
	assert(ValidLevel >= 1 and ValidLevel % 1 == 0, "Level must be a positive integer")

	local Requirement = CalculateRequirement(ValidLevel)
	assert(Requirement <= MAX_SAFE_INTEGER, "Level requirement exceeds the supported safe integer range")
	return Requirement
end

function LevelFormula.GetProgress(Bigger: number): LevelProgress
	local Level = LevelFormula.GetLevelFromBigger(Bigger)
	local CurrentRequirement = LevelFormula.GetRequirementForLevel(Level)
	local NextRequirement = LevelFormula.GetRequirementForLevel(Level + 1)
	local BiggerIntoLevel = Bigger - CurrentRequirement
	local BiggerRequiredForNextLevel = NextRequirement - CurrentRequirement

	return {
		Level = Level,
		CurrentRequirement = CurrentRequirement,
		NextRequirement = NextRequirement,
		BiggerIntoLevel = BiggerIntoLevel,
		BiggerRequiredForNextLevel = BiggerRequiredForNextLevel,
		Progress = math.clamp(BiggerIntoLevel / BiggerRequiredForNextLevel, 0, 1),
	}
end

-- Backward compatibility aliases
function LevelFormula.GetLevel(Bigger: number): number
	return LevelFormula.GetLevelFromBigger(Bigger)
end

function LevelFormula.GetRequirement(Level: number): number
	return LevelFormula.GetRequirementForLevel(Level)
end

function LevelFormula.GetCurrentRange(Level: number): (number, number)
	return LevelFormula.GetRequirementForLevel(Level), LevelFormula.GetRequirementForLevel(Level + 1)
end

function LevelFormula.GetNextRequirement(Level: number): number
	return LevelFormula.GetRequirementForLevel(Level + 1)
end

return table.freeze(LevelFormula)
