--!strict

---/// Content \\\---

-- Purpose: Validates a stomp root position in objective-hitbox local space.
-- Use when:
-- - A server objective must reject side touches and non-descending contacts.
-- Avoid when:
-- - Resolving character ownership or applying rewards.
-- Public API:
-- - StompValidation.IsValid(LocalX, LocalY, LocalZ, HalfX, HalfY, HalfZ, HorizontalPadding, MaxHeight, VerticalVelocity, MinimumDownwardVelocity)

local StompValidation = {}

local function IsFinite(Value: number): boolean
	return Value == Value and Value > -math.huge and Value < math.huge
end

local function AreFinite(...: number): boolean
	for Index = 1, select("#", ...) do
		if not IsFinite(select(Index, ...)) then
			return false
		end
	end
	return true
end

function StompValidation.IsValid(
	LocalX: number,
	LocalY: number,
	LocalZ: number,
	HalfX: number,
	HalfY: number,
	HalfZ: number,
	HorizontalPadding: number,
	MaxHeight: number,
	VerticalVelocity: number,
	MinimumDownwardVelocity: number
): boolean
	if
		not AreFinite(
			LocalX,
			LocalY,
			LocalZ,
			HalfX,
			HalfY,
			HalfZ,
			HorizontalPadding,
			MaxHeight,
			VerticalVelocity,
			MinimumDownwardVelocity
		)
	then
		return false
	end
	if HalfX <= 0 or HalfY <= 0 or HalfZ <= 0 then
		return false
	end
	if HorizontalPadding < 0 or MaxHeight <= 0 then
		return false
	end
	if LocalY <= HalfY or LocalY > HalfY + MaxHeight then
		return false
	end
	if math.abs(LocalX) > HalfX + HorizontalPadding then
		return false
	end
	if math.abs(LocalZ) > HalfZ + HorizontalPadding then
		return false
	end
	return VerticalVelocity <= MinimumDownwardVelocity
end

return table.freeze(StompValidation)
