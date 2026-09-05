# Responsive Architecture

This document defines the constraints, lifecycle, and API of `ResponsiveController.luau`, the centralized client-side service responsible for tracking effective viewport boundaries and device categories.

---

## 🔒 Decoupled Observability Rule
*   **Zero UI References**: `ResponsiveController` is strictly forbidden from referencing `ScreenGui`, `PlayerGui`, or any other GUI widget instance.
*   **Observability Sources**: It must calculate the viewport solely from the following engine sources:
    1.  `Workspace.CurrentCamera.ViewportSize` (for raw window resolution)
    2.  `GuiService:GetGuidanceRect()` (for guidance-based safe area bounds)
    3.  `GuiService.ViewportDisplaySize` (for Small / Medium / Large hints)
    4.  `UserInputService:GetLastInputType()` (for platform mode checking)
*   **Responsibility**: It is a state-only publisher. It recomputes layout profile parameters and notifies subscribers without altering UI layout directly.

---

## 📱 Viewport Breakpoint Precedence
When classifying the viewport, the controller must evaluate properties in this exact order to prevent tablet vs desktop misclassifications:
1.  **Viewport Size** (Width and Height bounds)
2.  **DisplaySize** (`GuiService.ViewportDisplaySize`)
3.  **Aspect Ratio** (Width / Height)
4.  **Platform Hint** (Last input category)

---

## ⚙️ Public API

### Typed Category Enums
Logical device categories are defined strictly as a frozen table in `ResponsiveConfig.luau`:
```luau
export type Category = "PhonePortrait" | "PhoneLandscape" | "Tablet" | "Desktop" | "Ultrawide"
```

### Profile Snapshot structure
The controller caches a frozen table representing the current viewport snapshot. Subscriptions read this immutable table directly:
```luau
export type ViewportProfile = {
	Category: Category,
	Width: number,
	Height: number,
	Aspect: number,
	DisplaySize: Enum.ViewportDisplaySize,
	SafeArea: Rect,
	Platform: Enum.UserInputType,
	Orientation: "Portrait" | "Landscape",
	EffectiveViewport: Vector2,
	InputMode: Enum.UserInputType,
	Accessibility: {
		ReducedMotion: boolean,
		HighContrast: boolean,
		LargeText: boolean,
		ScreenReader: boolean,
		PreferredTransparency: number
	}
}
```

### Methods
*   `ResponsiveController.Init()`: Initializes observers.
*   `ResponsiveController.Start()`: Begins publishing.
*   `ResponsiveController.Destroy()`: Disconnects all signal listeners, clears callbacks, and releases cached profiles.
*   `ResponsiveController:GetCategory() -> Category`
*   `ResponsiveController:IsMobile() -> boolean` (returns true for PhonePortrait or PhoneLandscape)
*   `ResponsiveController:IsDesktop() -> boolean` (returns true for Desktop or Ultrawide)
*   `ResponsiveController:IsConsole() -> boolean` (returns true for Gamepad mode)
*   `ResponsiveController:GetViewport() -> Vector2`
*   `ResponsiveController:GetSafeAreaRect() -> Rect`
*   `ResponsiveController:GetEffectiveViewport() -> Vector2`
*   `ResponsiveController:GetOrientation() -> "Portrait" | "Landscape"`
*   `ResponsiveController:IsTouch() -> boolean`
*   `ResponsiveController:IsMouse() -> boolean`
*   `ResponsiveController:IsGamepad() -> boolean`
*   `ResponsiveController:GetProfile() -> ViewportProfile` (returns the cached, frozen ViewportProfile table)

### Signals / Callbacks
*   `ResponsiveController.CategoryChanged`: Fires when the logical category changes.
*   `ResponsiveController.ViewportChanged`: Fires when absolute camera viewport dimensions change.
*   `ResponsiveController.SafeAreaChanged`: Fires when native ScreenInsets, guidance rect, or top bar dimensions shift.
*   `ResponsiveController.ProfileChanged`: Fires when *any* property inside the `ViewportProfile` changes (e.g. aspect ratio, TopbarInset, or accessibility preferences), even if the category does not. Passes the frozen `ViewportProfile` snapshot.
