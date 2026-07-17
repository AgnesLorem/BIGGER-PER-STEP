# Platform Guidelines

This document specifies the interaction design and platform-specific behaviors required for cross-platform compatibility on PC, Mobile, and Console devices.

---

## 💻 PC / Desktop (Mouse & Keyboard)
*   **Hover States**: Custom cursor changes, subtle color offsets, or scaling cues.
*   **Tooltips**: Detailed descriptive labels on hover. Tooltips must be layered within ZIndex `150 - 179`.
*   **Keyboard Shortcuts**: Fast navigation loops mapped to keycodes (e.g. Enter to confirm, Escape to close).

---

## 📱 Mobile (Touch Screen)
*   **Touch Targets**: All interactive buttons, tabs, and checklist elements must have a minimum touch target size of **44 x 44 pixels** to prevent miss-touches.
*   **Long Press**: Contextual options displayed upon long press.
*   **Thumb Zones**: Navigation buttons and critical shortcuts must reside within standard comfortable thumb reach areas (lower corners/sides).

---

## 🎮 Console (Gamepad Controller)
To ensure gamepad players never encounter focus locks or unreachable elements, automatic navigation is disabled in favor of explicit configuration.

*   **Explicit Directional Navigation**: All interactive GUI elements in a layout must explicitly define their directional navigation pathways:
    *   `NextSelectionUp`
    *   `NextSelectionDown`
    *   `NextSelectionLeft`
    *   `NextSelectionRight`
*   **SelectionImageObject**: Every ScreenGui must declare a custom `SelectionImageObject` style stylesheet/image to provide clear selection outlines. Relying on default Roblox selection boxes is banned.
*   **SelectionGroup**: Group UI frames into distinct SelectionGroups. Toggling active popups must lock gamepad focus to that popup's `SelectionGroup` to prevent focus escaping to background HUD items.
*   **Cyclic Focus**: Ensure gamepad selection cycles completely. Moving past the last element in a sidebar must cycle back to the first element rather than dropping selection.
