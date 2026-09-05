--!strict
---/// Content \\\---

-- Purpose: Translates viewport categories into CDRA layout profiles.
-- Use when:
-- - Mapping a specific category (e.g. Tablet, Desktop) to its LayoutProfile.
-- Avoid when:
-- - Managing active controller state or calculating category boundaries.
-- Public API:
-- - ResponsivePolicy.GetPolicy(category: Category) -> LayoutProfile
-- Related:
-- - src/shared/Core/Config/ResponsiveConfig.luau
-- - src/client/controllers/ResponsiveController.luau

--// Raw Requirings \\--
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Requirings \\--
local ResponsiveConfig = require(
	ReplicatedStorage:WaitForChild("BiggerShared")
		:WaitForChild("Core")
		:WaitForChild("Config")
		:WaitForChild("ResponsiveConfig")
)

--// Types \\--
type Category = ResponsiveConfig.Category
type LayoutProfile = ResponsiveConfig.LayoutProfile

--// Service \\--
local ResponsivePolicy = {}

function ResponsivePolicy.GetPolicy(category: Category): LayoutProfile
	return ResponsiveConfig.Policies[category] or ResponsiveConfig.Policies.Desktop
end

return table.freeze(ResponsivePolicy)
