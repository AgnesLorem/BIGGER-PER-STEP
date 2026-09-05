# UI Validation Rules

This document specifies the validation checklists and constraint duplication policies required for all user interfaces under CDRA.

---

## 📐 Structural Composition Checklist
Every UI component added or modified in the repository must satisfy these composition rules:

### Buttons
*   [ ] **UIScale**: Must exist as a child of the button to handle hover/click scaling animations.
*   [ ] **UIAspectRatioConstraint**: Explicitly defined where visual consistency is required (e.g. square sidebar buttons).
*   [ ] **UICorner**: Must exist to enforce standard rounded styling.
*   [ ] **UIStroke**: Optional border stroke configuration.

### Text (Labels, buttons, text inputs)
*   [ ] **TextScaled**: Must be set to `true`.
*   [ ] **UITextSizeConstraint**: Must exist, specifying a clear `MinTextSize` (minimum 12) and `MaxTextSize` (maximum 32) to prevent layout overflows or text expanding too large.

### Containers (Frames/ScrollingFrames that own multiple children)
*   [ ] **AnchorPoint**: Explicitly defined to manage alignment.
*   [ ] **UIPadding**: Must exist to govern inner margins (using scale/offsets).
*   [ ] **Layout Object**: Must contain a layout engine (`UIListLayout`, `UIGridLayout`, or `UIFlex`).

---

## 🚫 Zero Constraint Duplication Policy
To prevent property inflation and visual glitches, duplicate helper objects under the same parent are strictly banned.

*   **Rule**: Under any single parent instance, there must be **exactly zero or one** instance of the following classes:
    *   `UIAspectRatioConstraint`
    *   `UITextSizeConstraint`
    *   `UISizeConstraint`
    *   `UIScale`
    *   `UIPadding`
    *   `UIStroke`
    *   `UICorner`
    *   `UIListLayout` / `UIGridLayout` / `UIFlex`
*   **Action**: If a duplicate is found, validation scripts must report an error, and migration scripts must reuse the first found instance.
