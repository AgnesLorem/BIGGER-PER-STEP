# Constraint-Driven Responsive Architecture (CDRA)

This document establishes the core layers of the **Constraint-Driven Responsive Architecture (CDRA)** in the **Bigger** repository. CDRA is the mandatory UI standard for all newly introduced ScreenGuis. Existing legacy UIs may be migrated incrementally.

---

## 🚨 Core Philosophy & AI Rule
> **Responsive by composition, not by scripting.**
>
> Always prefer Roblox Layouts, Constraints, AutomaticSize, and Scale. Introduce runtime scripts only when the interface requires different platform-specific layouts or interaction models.

---

## 📐 Architecture Layers

```
Layer 0 — Semantic UI (Role Definition)
   ↓
Layer 1 — Primary Layout Layer (Physical constraints & scales)
   ↓
Layer 2 — Adaptive Layout (Layout profile switches via ResponsivePolicy)
   ↓
Layer 3 — Platform Behaviour (Gamepad, Mouse, Touch inputs)
   ↓
Layer 4 — Presentation Layer (Theme, color, accessibility, visual animations)
```

### Layer 0 — Semantic UI (Role Definition)
Before writing code or layout constraints, all UI elements must map to a clear semantic role representing their screen lifecycle and interaction boundaries:
*   **Persistent**: HUD elements that remain visible on screen (Sidebars, health bar, progression displays).
*   **Overlay**: Panels that open on top of gameplay but do not halt controls globally (Inventory, Shop, Quest panels, Maps).
*   **Popup**: Short-lived windows prompting confirmation or player choices.
*   **Notification**: Non-interactive status toast banners or unlock alerts.
*   **Modal**: Heavy interface panels that block underlying controls completely.
*   **Debug**: Performance statistics, developer console overlays.

### Layer 1 — Primary Layout Layer
Static, engine-driven layout foundation containing zero Luau scripting.
*   Uses Scale for size and position, except for allowed offset exceptions (padding, border lines, drop shadows, separators).
*   Correct `AnchorPoint` values matching screen alignment.
*   Roblox layout objects (`UIListLayout`, `UIGridLayout`, `UIFlex`).
*   `UIAspectRatioConstraint` and `UISizeConstraint` bounds.

### Layer 2 — Adaptive Layout
Scripting is used strictly to handle structural changes in the layout based on viewport profiles.
*   **Allowed Script Mutations**: `Visible` (toggling sub-containers), `Layout.FillDirection`, `Layout.HorizontalAlignment` / `VerticalAlignment`, `Padding` (adjusting `UIPadding` offset properties), `UIGridLayout.CellSize` (modified strictly via `ResponsivePolicy` profiles).
*   **Forbidden Script Mutations**: `AbsolutePosition`, `AbsoluteSize`, `AnchorPoint`, `TextSize` (handled natively by text scaling constraints).

### Layer 3 — Platform Behaviour
Implements platform-specific interaction models (Touch targets, hover tooltips, Console selection groups, and explicit custom `SelectionImageObject` selection graphics).

### Layer 4 — Presentation Layer (Visuals & FX)
Separates visual theme, transitions, and effects from layout calculations. Includes: animations, color/theme palettes, VFX (particle emitters, gradient tweens), and accessibility parameters.
