# Animation and Tweening Rules

This document defines the strict separation of concerns between layout calculation and visual animations under CDRA.

---

## 📐 Layout Position vs. Presentation Position

### Layout Position (Static Sizing)
*   **Definition**: The coordinates and size bounds of widgets required to align them within the active viewport.
*   **Rule**: Layout Position and Layout Size must be defined strictly by the layout engine using Scale and Constraints.
*   **Forbidden**: Never tween `Position`, `Size`, `AnchorPoint`, or `LayoutOrder` to adapt layouts to screen sizes or switch between desktop/mobile structures.

### Presentation Position (Visual Transitions)
*   **Definition**: The temporal visual changes used to animate transitions (opening, closing, hovering, clicking).
*   **Rule**: Tweening `Position` or `Size` is permitted solely for transitional visual effects, provided the final resting state of the element is resolved by the layout engine.
*   **Allowed Transitional Tweens**:
    *   An Inventory panel sliding in from off-screen (`Position` offset transitions).
    *   A Toast notification sliding down (`Position` offset transitions).
    *   A popup card scaling up from zero size on open (`Size` or `UIScale` transitions).
*   **Allowed Property Tweens**:
    *   `UIScale.Scale` (the preferred method for click and hover scaling effects).
    *   `Rotation`
    *   `Transparency`
    *   `Color`
    *   `UIStroke` (color/width)
    *   `UICorner.CornerRadius`

---

## ⏱️ Execution Timeline Rule
*   **Layout Stabilization**: Animations must only execute after the layout has stabilized.
*   **Order**:
    1.  Viewport changes.
    2.  `ResponsiveController` reclassifies category and publishes profile.
    3.  `GuiController` and list/grid engines align container structures.
    4.  Layout engine resolves positions.
    5.  Presentation Layer tweens run.
