# MainHUD Responsive Audit

This document records the initial responsive property audit of the existing `MainHUD` in Roblox Studio, outlining the layout violations identified before the CDRA refactor.

---

## 🔍 MainHUD Audit Findings & Target Fixes

1.  **LeftSidebar**:
    *   *Violation*: Lacks `UIAspectRatioConstraint` on cells or the grid itself. Aspect ratio changes cause buttons to warp or drift.
    *   *Fix*: Configure `UIGridLayout` to support responsive scale, and enforce correct cell aspect ratios.
2.  **BottomHUD**:
    *   *Violation*: `Position.Y` scale is `0.819999993` with `AnchorPoint` at `0.5, 0.5`. This places the center of the HUD at 82% height, causing variable margins on different vertical screen resolutions.
    *   *Fix*: Set `AnchorPoint` to `0.5, 1` (bottom-center) and `Position` to `{0.5, 0}, {1, -10}`.
    *   *Violation*: `ProgressBG` has a Y Scale of `2.88197708` and `Position.Y` Scale of `1.4928813`, which are arbitrary values from manual editor drags.
    *   *Fix*: Correct Y Scale to fit inside its parent `ProgressBarFrame` and zero out offsets/unnecessary offsets.
    *   *Violation*: `LevelLabel` and `ProgressTextLabel` have `TextScaled = false` and `TextSize = 38`. On mobile, they overlap and clip.
    *   *Fix*: Turn on `TextScaled = true` and add a `UITextSizeConstraint` (e.g. Min 12, Max 38).
    *   *Violation*: `ProgressFill` has a hardcoded position offset of `{0, 39}, {0, 81}` which shifts it out of its `BarContainer`.
    *   *Fix*: Align `ProgressFill` position to `{0, 0}, {0.5, 0}` with `AnchorPoint` of `0, 0.5` inside the container.
3.  **RightSidebar**:
    *   *Violation*: `DoubleMultiplier` and `Vip` buttons contain static text sizes (`TextSize = 38`) without scaling.
    *   *Fix*: Enable `TextScaled` on their `TextLabel` children and configure `UIAspectRatioConstraint` for uniform sizes.
