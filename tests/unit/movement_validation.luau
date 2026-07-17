local MovementValidation = require("../../src/shared/Core/Utilities/MovementValidation")

assert(MovementValidation.IsPlausible(3.2, 0.2, 24, 1.5) == true)
assert(MovementValidation.IsPlausible(8.5, 0.3, 24, 1.5) == true)
assert(MovementValidation.IsPlausible(100, 0.2, 24, 1.5) == false)
assert(MovementValidation.IsPlausible(1, 0, 24, 1.5) == false)
assert(MovementValidation.IsPlausible(1, -0.1, 24, 1.5) == false)
assert(MovementValidation.IsPlausible(0 / 0, 0.2, 24, 1.5) == false)
assert(MovementValidation.IsPlausible(1, 0 / 0, 24, 1.5) == false)
assert(MovementValidation.IsPlausible(math.huge, 0.2, 24, 1.5) == false)
assert(MovementValidation.IsPlausible(1, math.huge, 24, 1.5) == false)

print("movement_validation: PASS")
