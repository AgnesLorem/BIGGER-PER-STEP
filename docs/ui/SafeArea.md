# Safe Area Policy

This document defines the safe area adaptation rules for user interfaces in the **Bigger** repository.

---

## 🔒 Safe Area Rules
*   All persistent HUD elements and gameplay-critical UI must remain strictly inside the safe area.
*   **Zero Manual Padding Calculation**: Scripts are strictly prohibited from calculating safe-area offsets, padding, or margins programmatically.
*   **Native Delegation**: Safe area bounds are delegated entirely to the Roblox engine via the root `ScreenGui` properties:
    *   `ScreenInsets` = `Enum.ScreenInsets.DeviceSafeInsets` or `Enum.ScreenInsets.CoreUISafeInsets`
    *   `ClipToDeviceSafeArea` = `true`
    *   `SafeAreaCompatibility` = `Enum.SafeAreaCompatibility.None` (or remains at default)

---

## 🌳 SafeAreaRoot Container Properties
Every `ScreenGui` utilizing CDRA must nest its components under a `SafeAreaRoot` frame configured as follows:

```
HUDRoot (ScreenGui) [DisplayOrder: 10]
└── SafeAreaRoot (Frame)
    ├── PersistentHUD (Frame)
    └── OverlayHUD (Frame)
```

### SafeAreaRoot Specifications
*   **Size**: `UDim2.new(1, 0, 1, 0)` (Fills ScreenGui completely)
*   **Position**: `UDim2.new(0, 0, 0, 0)`
*   **BackgroundTransparency**: `1` (Invisible container)
*   **ScreenInsets / Safe Area Handling**: Because ScreenGui natively clips insets, `SafeAreaRoot` automatically scales to the safe screen bounds.

---

## 📡 Observability Chain
1.  Roblox Engine detects hardware safe area changes (Notch, Dynamic Island, console safe zone adjustments).
2.  `ResponsiveController` listens to native inset changes via `screenGui:GetPropertyChangedSignal("AbsoluteSize")` and `TopbarInset` updates.
3.  `ResponsiveController` recomputes and publishes the updated `ViewportProfile` snapshot containing the current safe area bounds.
4.  `GuiController` and other layout managers react to the profile changes. No individual widget may subscribe to engine safe area signals directly.
