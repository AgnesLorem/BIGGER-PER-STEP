local StompValidation = require("../../src/shared/Core/Utilities/StompValidation")

local function IsValid(
	X: number,
	Y: number,
	Z: number,
	Velocity: number,
	HalfX: number?,
	HalfY: number?,
	HalfZ: number?,
	Padding: number?,
	MaxHeight: number?
): boolean
	local ResolvedHalfX = if HalfX == nil then 4 else HalfX
	local ResolvedHalfY = if HalfY == nil then 1 else HalfY
	local ResolvedHalfZ = if HalfZ == nil then 4 else HalfZ
	local ResolvedPadding = if Padding == nil then 0.5 else Padding
	local ResolvedMaxHeight = if MaxHeight == nil then 6 else MaxHeight

	return StompValidation.IsValid(
		X,
		Y,
		Z,
		ResolvedHalfX,
		ResolvedHalfY,
		ResolvedHalfZ,
		ResolvedPadding,
		ResolvedMaxHeight,
		Velocity,
		-2
	)
end

assert(IsValid(0, 2, 0, -10) == true)
assert(IsValid(5, 2, 0, -10) == false)
assert(IsValid(0, 8, 0, -10) == false)
assert(IsValid(0 / 0, 2, 0, -10) == false)
assert(IsValid(math.huge, 2, 0, -10) == false)
assert(IsValid(0, 2, 0, 0 / 0) == false)
assert(IsValid(0, 2, 0, -10, 0, 1, 4) == false)
assert(IsValid(0, 2, 0, -10, 4, -1, 4) == false)
assert(IsValid(0, 2, 0, -10, 4, 1, 4, -0.5) == false)
assert(IsValid(0, 2, 0, -10, 4, 1, 4, 0.5, 0) == false)
assert(IsValid(0, 2, 0, 1) == false)

print("stomp_validation: PASS")
