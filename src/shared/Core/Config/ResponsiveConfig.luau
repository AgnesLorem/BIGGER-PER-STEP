--!strict
---/// Content \\\---

-- Purpose: Configures responsive layouts, screen breakpoints, font size ranges, and HUD configurations.
-- Use when:
-- - Reading device breakpoints or layout profile structures.
-- - Defining responsive UI policies for sidebars, grids, and safe areas.
-- Avoid when:
-- - Handling active runtime viewport state calculations (use ResponsiveController instead).
-- Public API:
-- - ResponsiveConfig.Breakpoints
-- - ResponsiveConfig.Policies
-- - ResponsiveConfig.Text
-- - ResponsiveConfig.HUD
-- Related:
-- - src/client/controllers/ResponsiveController.luau
-- - src/client/controllers/ResponsivePolicy.luau

--// Types \\--
export type Category = "PhonePortrait" | "PhoneLandscape" | "Tablet" | "Desktop" | "Ultrawide"

export type LayoutProfile = {
	LeftSidebarMode: "Expanded" | "Collapsed" | "Hidden",
	RightSidebarMode: "Expanded" | "Collapsed" | "Hidden",
	SidebarWidthScale: number,
	GridCellSize: UDim2,
	PaddingScale: number,
	GapScale: number,
	VisiblePanels: { [string]: boolean },
	InventoryMode: "Popup" | "Sidebar",
	PopupWidthScale: number,
	HUDHeightScale: number,
	NavigationMode: "Gamepad" | "Touch" | "Mouse",
	BottomHUDStyle: "Full" | "Compact",
}

--// Variables \\--
local Policies: { [Category]: LayoutProfile } = {
	Desktop = {
		LeftSidebarMode = "Expanded",
		RightSidebarMode = "Expanded",
		SidebarWidthScale = 0.12,
		GridCellSize = UDim2.new(0.46, 0, 0.3, 0),
		PaddingScale = 1.0,
		GapScale = 1.0,
		VisiblePanels = { LeftSidebar = true, RightSidebar = true, BottomHUD = true },
		InventoryMode = "Sidebar",
		PopupWidthScale = 0.5,
		HUDHeightScale = 0.22,
		NavigationMode = "Mouse",
		BottomHUDStyle = "Full",
	},
	Tablet = {
		LeftSidebarMode = "Collapsed",
		RightSidebarMode = "Collapsed",
		SidebarWidthScale = 0.08,
		GridCellSize = UDim2.new(0.3, 0, 0.25, 0),
		PaddingScale = 0.8,
		GapScale = 0.8,
		VisiblePanels = { LeftSidebar = true, RightSidebar = true, BottomHUD = true },
		InventoryMode = "Popup",
		PopupWidthScale = 0.65,
		HUDHeightScale = 0.22,
		NavigationMode = "Touch",
		BottomHUDStyle = "Full",
	},
	PhoneLandscape = {
		LeftSidebarMode = "Collapsed",
		RightSidebarMode = "Hidden",
		SidebarWidthScale = 0.06,
		GridCellSize = UDim2.new(0.2, 0, 0.2, 0),
		PaddingScale = 0.6,
		GapScale = 0.6,
		VisiblePanels = { LeftSidebar = true, RightSidebar = false, BottomHUD = true },
		InventoryMode = "Popup",
		PopupWidthScale = 0.8,
		HUDHeightScale = 0.22,
		NavigationMode = "Touch",
		BottomHUDStyle = "Compact",
	},
	PhonePortrait = {
		LeftSidebarMode = "Hidden",
		RightSidebarMode = "Hidden",
		SidebarWidthScale = 0.0,
		GridCellSize = UDim2.new(0.15, 0, 0.15, 0),
		PaddingScale = 0.5,
		GapScale = 0.5,
		VisiblePanels = { LeftSidebar = false, RightSidebar = false, BottomHUD = true },
		InventoryMode = "Popup",
		PopupWidthScale = 0.9,
		HUDHeightScale = 0.22,
		NavigationMode = "Touch",
		BottomHUDStyle = "Compact",
	},
	Ultrawide = {
		LeftSidebarMode = "Expanded",
		RightSidebarMode = "Expanded",
		SidebarWidthScale = 0.1,
		GridCellSize = UDim2.new(0.46, 0, 0.3, 0),
		PaddingScale = 1.2,
		GapScale = 1.2,
		VisiblePanels = { LeftSidebar = true, RightSidebar = true, BottomHUD = true },
		InventoryMode = "Sidebar",
		PopupWidthScale = 0.4,
		HUDHeightScale = 0.20,
		NavigationMode = "Mouse",
		BottomHUDStyle = "Full",
	},
}

local ResponsiveConfig = {
	Breakpoints = {
		PhonePortraitMaxWidth = 500,
		TabletMaxWidth = 900,
		DesktopMinWidth = 1200,
		UltrawideMinWidth = 2000,
	},
	SafeArea = {
		PaddingOffset = 8,
	},
	Text = {
		Min = 12,
		Max = 38,
	},
	HUD = {
		SidebarCollapseWidth = 768,
		BottomHUDHeight = 120,
	},
	Policies = Policies,
}

return table.freeze(ResponsiveConfig)
