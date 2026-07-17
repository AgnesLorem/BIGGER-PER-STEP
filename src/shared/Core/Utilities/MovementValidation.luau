--!strict

---/// Content \\\---

-- Purpose: Validates one server-observed horizontal movement sample.
-- Use when:
-- - A server growth or interaction system must reject non-finite or implausible displacement.
-- Avoid when:
-- - Correcting character position or implementing a full anti-cheat system.
-- Public API:
-- - MovementValidation.IsPlausible(HorizontalDistance, DeltaSeconds, MaximumRewardSpeed, DistanceSlack)

local MovementValidation = {}

local function IsFinite(Value: number): boolean
	return Value == Value and Value > -math.huge and Value < math.huge
end

function MovementValidation.IsPlausible(
	HorizontalDistance: number,
	DeltaSeconds: number,
	MaximumRewardSpeed: number,
	DistanceSlack: number
): boolean
	if not IsFinite(HorizontalDistance) or HorizontalDistance < 0 then
		return false
	end
	if not IsFinite(DeltaSeconds) or DeltaSeconds <= 0 then
		return false
	end
	if not IsFinite(MaximumRewardSpeed) or MaximumRewardSpeed <= 0 then
		return false
	end
	if not IsFinite(DistanceSlack) or DistanceSlack < 0 then
		return false
	end
	return HorizontalDistance <= MaximumRewardSpeed * DeltaSeconds + DistanceSlack
end

return table.freeze(MovementValidation)
