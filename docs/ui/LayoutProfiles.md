# Layout Profiles

This document specifies the data structure and profile mappings of layout parameters under CDRA. All UI responsiveness adjustments are driven by selecting a predefined profile.

---

## ⚙️ Configuration-Driven Policy
*   **Central Config**: All responsive parameters are configured in `ResponsiveConfig.luau` under the `Policies` profile table.
*   **Decoupled Selection**: `ResponsivePolicy.luau` serves as a simple mapping wrapper:
```luau
function ResponsivePolicy.GetPolicy(category: Category): LayoutProfile
	return ResponsiveConfig.Policies[category] or ResponsiveConfig.Policies.Desktop
end
```

---

## 📐 Layout Profile Schema
Each layout category maps to a concrete configuration structure specifying physical dimension policies:

```luau
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
	NavigationMode: "Gamepad" | "Touch" | "Mouse"
}
```

---

## 🎨 Profiles Definition (`ResponsiveConfig.Policies`)

### Desktop Profile
*   **LeftSidebarMode**: `"Expanded"`
*   **RightSidebarMode**: `"Expanded"`
*   **SidebarWidthScale**: `0.12`
*   **GridCellSize**: `UDim2.new(0.46, 0, 0.3, 0)`
*   **InventoryMode**: `"Sidebar"`
*   **BottomHUDStyle**: `"Full"`

### Tablet Profile
*   **LeftSidebarMode**: `"Collapsed"`
*   **RightSidebarMode**: `"Collapsed"`
*   **SidebarWidthScale**: `0.08`
*   **GridCellSize**: `UDim2.new(0.3, 0, 0.25, 0)`
*   **InventoryMode**: `"Popup"`
*   **BottomHUDStyle**: `"Full"`

### PhoneLandscape Profile
*   **LeftSidebarMode**: `"Collapsed"`
*   **RightSidebarMode**: `"Hidden"`
*   **SidebarWidthScale**: `0.06`
*   **GridCellSize**: `UDim2.new(0.2, 0, 0.2, 0)`
*   **InventoryMode**: `"Popup"`
*   **BottomHUDStyle**: `"Compact"`

### PhonePortrait Profile
*   **LeftSidebarMode**: `"Hidden"`
*   **RightSidebarMode**: `"Hidden"`
*   **SidebarWidthScale**: `0.0`
*   **GridCellSize**: `UDim2.new(0.15, 0, 0.15, 0)`
*   **InventoryMode**: `"Popup"`
*   **BottomHUDStyle**: `"Compact"`
