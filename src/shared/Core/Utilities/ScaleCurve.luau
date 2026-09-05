--!strict

---/// Content \\\---

-- Purpose: Pure math utility for converting a raw Bigger value into a visual scale factor.
-- Use when:
-- - Computing character visual scale from the player's current Bigger value.
-- - Need a configurable curve formula (sqrt, log, linear, level, power) without clamping.
-- Avoid when:
-- - Need clamped output; clamping is the caller's responsibility.
-- - Need side effects, state, or instance references.
-- Public API:
-- - ScaleCurve.GetVisualScale(Bigger, Formula?, CurveParameter?, Exponent?): number

--// Requirings \\--

local LevelFormula = require(script.Parent.Parent.Parent.Game.Progression.LevelFormula)

--// Variables \\--

local DEFAULT_FORMULA = "sqrt"
local DEFAULT_CURVE_PARAMETER = 0.5
local DEFAULT_EXPONENT = 0.8299

--// Types \\--

type FormulaFunction = (Bigger: number, CurveParameter: number, Exponent: number?) -> number

--// Helpers \\--

local ScaleCurve = {}

local Formulas: { [string]: FormulaFunction } = table.freeze({
	sqrt = function(Bigger: number, CurveParameter: number, _Exponent: number?): number
		return 1 + math.max(0, Bigger - 1) ^ CurveParameter
	end,
	log = function(Bigger: number, CurveParameter: number, _Exponent: number?): number
		return 1 + math.log(Bigger) * CurveParameter
	end,
	linear = function(Bigger: number, CurveParameter: number, _Exponent: number?): number
		return Bigger * CurveParameter
	end,
	level = function(Bigger: number, CurveParameter: number, _Exponent: number?): number
		local Level = LevelFormula.GetLevel(Bigger)
		return 1 + (Level - 1) * CurveParameter
	end,
	power = function(Bigger: number, Coefficient: number, Exponent: number?): number
		local Level = LevelFormula.GetLevel(Bigger)
		local Exp = Exponent or DEFAULT_EXPONENT
		return 1 + Coefficient * math.max(0, Level - 1) ^ Exp
	end,
})

--// Service \\--

function ScaleCurve.GetVisualScale(Bigger: number, Formula: string?, CurveParameter: number?, Exponent: number?): number
	local ResolvedFormula = Formula or DEFAULT_FORMULA
	local ResolvedParameter = CurveParameter or DEFAULT_CURVE_PARAMETER
	local Fn = Formulas[ResolvedFormula] or Formulas[DEFAULT_FORMULA]
	return Fn(Bigger, ResolvedParameter, Exponent)
end

return ScaleCurve
