--!strict

---/// Content \\\---

-- Purpose: Shared progression math for converting Bigger into derived level gates.
-- Use when:
-- - Server systems need to validate a level requirement from authoritative session Bigger.
-- - Client presentation needs to display level requirements or progress ratios.
-- - Any system needs to replace inline hardcoded level formulas.
-- Avoid when:
-- - Computing avatar visual scale; use Core.Utilities.ScaleCurve instead.
-- Public API:
-- - LevelFormula.GetLevel(Bigger): number
-- - LevelFormula.GetRequirement(Level): number
-- - LevelFormula.GetCurrentRange(Level): (number, number)
-- - LevelFormula.GetProgress(Bigger): (number, number, number)
-- - LevelFormula.GetNextRequirement(Level): number
-- Related:
-- - ReplicatedStorage.BiggerShared.Game.Progression.BalanceConfig

--// Requirings \\--

local BalanceConfig = require(script.Parent.BalanceConfig)

--// Service \\--

local LevelFormula = {}

function LevelFormula.GetRequirement(Level: number): number
	local TargetLevel = math.floor(math.max(1, Level))
	for _, Stage in BalanceConfig.Stages do
		if TargetLevel >= Stage.MinLevel and TargetLevel <= Stage.MaxLevel then
			return math.floor(Stage.CalculateRequirement(TargetLevel, Stage.BaseRequirement))
		end
	end
	return 0
end

function LevelFormula.GetLevel(Bigger: number): number
	if Bigger < 5 then return 1 end

	-- Dynamic doubling to find search upper bound
	local Low = 2
	local High = 4
	while LevelFormula.GetRequirement(High) <= Bigger do
		Low = High
		High *= 2
	end

	-- Binary search
	local BestLevel = Low
	while Low <= High do
		local Mid = math.floor((Low + High) / 2)
		if LevelFormula.GetRequirement(Mid) <= Bigger then
			BestLevel = Mid
			Low = Mid + 1
		else
			High = Mid - 1
		end
	end
	return BestLevel
end

function LevelFormula.GetCurrentRange(Level: number): (number, number)
	return LevelFormula.GetRequirement(Level), LevelFormula.GetRequirement(Level + 1)
end

function LevelFormula.GetProgress(Bigger: number): (number, number, number)
	local Level = LevelFormula.GetLevel(Bigger)
	local StartBigger, TargetBigger = LevelFormula.GetCurrentRange(Level)
	local CurrentProgress = math.max(0, Bigger - StartBigger)
	local TotalRequired = math.max(1, TargetBigger - StartBigger)
	local Ratio = math.clamp(CurrentProgress / TotalRequired, 0, 1)
	return Ratio, CurrentProgress, TotalRequired
end

function LevelFormula.GetNextRequirement(Level: number): number
	return LevelFormula.GetRequirement(Level + 1)
end

-- Backward compatibility aliases
function LevelFormula.GetLevelFromBigger(Bigger: number): number
	return LevelFormula.GetLevel(Bigger)
end
function LevelFormula.GetRequirementForLevel(Level: number): number
	return LevelFormula.GetRequirement(Level)
end

return table.freeze(LevelFormula)
