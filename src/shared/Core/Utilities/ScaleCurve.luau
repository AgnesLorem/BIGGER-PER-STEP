--!strict

---/// Content \\\---

-- Purpose: Pure math utility for converting a raw Bigger value into a visual scale factor.
-- Use when:
-- - Computing character visual scale from the player's current Bigger value.
-- - Need a configurable curve formula (sqrt, log, linear) without clamping.
-- Avoid when:
-- - Need clamped output; clamping is the caller's responsibility.
-- - Need side effects, state, or instance references.
-- Public API:
-- - ScaleCurve.GetVisualScale(Bigger, Formula?, CurveParameter?): number

--// Variables \\--

local DEFAULT_FORMULA = "sqrt"
local DEFAULT_CURVE_PARAMETER = 0.5

--// Types \\--

type FormulaFunction = (Bigger: number, CurveParameter: number) -> number

--// Helpers \\--

local ScaleCurve = {}

local Formulas: { [string]: FormulaFunction } = table.freeze({
	sqrt = function(Bigger: number, CurveParameter: number): number
		return 1 + math.max(0, Bigger - 1) ^ CurveParameter
	end,
	log = function(Bigger: number, CurveParameter: number): number
		return 1 + math.log(Bigger) * CurveParameter
	end,
	linear = function(Bigger: number, CurveParameter: number): number
		return Bigger * CurveParameter
	end,
	level = function(Bigger: number, CurveParameter: number): number
		local Level = math.floor((math.max(0, Bigger) / 236) ^ 0.25) + 1
		return 1 + (Level - 1) * CurveParameter
	end,
})

--// Service \\--

function ScaleCurve.GetVisualScale(Bigger: number, Formula: string?, CurveParameter: number?): number
	local ResolvedFormula = Formula or DEFAULT_FORMULA
	local ResolvedParameter = CurveParameter or DEFAULT_CURVE_PARAMETER
	local Fn = Formulas[ResolvedFormula] or Formulas[DEFAULT_FORMULA]
	return Fn(Bigger, ResolvedParameter)
end

return ScaleCurve
