--!strict

---/// Content \\\---

-- Purpose: Shared progression math for Rebirth requirements and multipliers.
-- Use when:
-- - Server validates whether a player can Rebirth.
-- - Server/Client computes the RebirthMultiplier for growth calculations.
-- - Client displays next Rebirth requirement or current multiplier.
-- Avoid when:
-- - Performing the actual Rebirth mutation; use RebirthService instead.
-- Public API:
-- - RebirthFormula.GetRequiredLevel(RebirthCount): number
-- - RebirthFormula.GetMultiplier(RebirthCount): number
-- - RebirthFormula.CanRebirth(CurrentLevel, RebirthCount): boolean

--// Variables \\--

local RebirthConfig = require(script.Parent.Parent.Config.RebirthConfig)

--// Helpers \\--

local function AssertNonNegativeInteger(Value: unknown, Name: string): number
	assert(type(Value) == "number", Name .. " must be a number")
	assert(Value >= 0 and Value % 1 == 0, Name .. " must be a non-negative integer")
	assert(Value == Value and Value < math.huge, Name .. " must be finite")
	return Value
end

--// Service \\--

local RebirthFormula = {}

--- Returns the Level required to perform the NEXT Rebirth.
--- RebirthCount is the player's CURRENT number of completed Rebirths (0 = never rebirthed).
--- ReqLevel(R) = BaseLevelRequirement + R × LevelIncrementPerRebirth
--- R=0: Level 20, R=1: Level 70, R=2: Level 120, ...
function RebirthFormula.GetRequiredLevel(RebirthCount: number): number
	local ValidCount = AssertNonNegativeInteger(RebirthCount, "RebirthCount")
	return RebirthConfig.BaseLevelRequirement + ValidCount * RebirthConfig.LevelIncrementPerRebirth
end

--- Returns the permanent growth multiplier granted by the given Rebirth count.
--- Linear formula: Mult(R) = BaseMultiplier + R × MultiplierPerRebirth
--- R=0: 1.00x, R=1: 1.75x, R=2: 2.50x, R=5: 4.75x, R=10: 8.50x
function RebirthFormula.GetMultiplier(RebirthCount: number): number
	local ValidCount = AssertNonNegativeInteger(RebirthCount, "RebirthCount")
	return RebirthConfig.BaseMultiplier + ValidCount * RebirthConfig.MultiplierPerRebirth
end

--- Returns true if the player's current Level meets the requirement for their next Rebirth.
function RebirthFormula.CanRebirth(CurrentLevel: number, RebirthCount: number): boolean
	if type(CurrentLevel) ~= "number" or CurrentLevel ~= CurrentLevel or CurrentLevel < 1 then
		return false
	end
	if type(RebirthCount) ~= "number" or RebirthCount ~= RebirthCount or RebirthCount < 0 then
		return false
	end
	local RequiredLevel = RebirthFormula.GetRequiredLevel(RebirthCount)
	return CurrentLevel >= RequiredLevel
end

return table.freeze(RebirthFormula)
