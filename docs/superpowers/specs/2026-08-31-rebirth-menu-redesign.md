# Design Specification: Rebirth Menu UI Redesign & Multiplier Formula Fix

**Date:** 2026-08-31  
**Status:** Approved via Brainstorming & Bug Audit  
**Scope:** 
1. `src/server/Game/Formula/GrowthFormula.luau` (Multiplier Formula Bug Fix)
2. `StarterGui.MainHUD.SafeAreaRoot.OverlayHUD.RebirthPanel` (Roblox Studio UI Redesign)
3. `src/client/controllers/RebirthController.luau` (Client Controller & Micro-interactions)
4. Studio Automated Test Suite (Step-by-step Simulator with Screen Captures)

---

## 1. Overview & Bug Analysis

### Root Cause of the Multiplier Bug
In `src/server/Game/Formula/GrowthFormula.luau`:
```luau
-- BEFORE (BUGGY):
function GrowthFormula.GetMultiplier(Session: Session): number
    local Multiplier = 1
    if Session.HasDoubleMultiplier then Multiplier *= 2 end
    if Session.HasVip then Multiplier *= 2 end
    Multiplier *= math.max(1, Session.Rebirth) -- BUG: For Rebirth 0 -> 1, math.max(1,0)=1; For Rebirth 1 -> 1, math.max(1,1)=1!
    return Multiplier
end
```
- **Rebirth 0 (New player):** `Rebirth = 0` -> `math.max(1, 0) = 1` (1X). GUI shows `1X -> 2X`.
- **Rebirth 1 (1st Rebirth):** `Rebirth = 1` -> `math.max(1, 1) = 1` (**1X, DID NOT INCREASE!**). GUI shows `1X -> 3X`.
- **Rebirth 2 (2nd Rebirth):** `Rebirth = 2` -> `math.max(1, 2) = 2` (**Only 2X, but GUI predicted 3X!**).

### Correct Formula Fix
```luau
-- AFTER (FIXED):
function GrowthFormula.GetMultiplier(Session: Session): number
    local Multiplier = 1
    if Session.HasDoubleMultiplier then Multiplier *= 2 end
    if Session.HasVip then Multiplier *= 2 end
    Multiplier *= (Session.Rebirth + 1)
    return Multiplier
end
```
- **Rebirth 0:** `0 + 1 = 1X` (Next: 2X)
- **Rebirth 1:** `1 + 1 = 2X` (Next: 3X)
- **Rebirth 2:** `2 + 1 = 3X` (Next: 4X)
- **Rebirth N:** `N + 1` (Next: N + 2)

---

## 2. Asset Mapping (Roblox Studio)

| Asset Role | File in Workspace | Roblox Asset URI |
| :--- | :--- | :--- |
| **Panel Background** | `GUI/UI_Assets/Background.png` | `rbxassetid://95986709043474` |
| **Top Header Bar** | `GUI/UI_Assets/Header.png` | `rbxassetid://90679201316084` |
| **Close Button** | `GUI/UI_Assets/CloseButton.png` | `rbxassetid://134336270097566` |
| **Multiplier Cards** (Current & Next) | `GUI/UI_Assets/Current.png` | `rbxassetid://106720087949362` |
| **Center Arrow** | Reference arrows | `rbxassetid://98387557126752` |
| **Rebirth Action Button** | UI Assets | `rbxassetid://113090370581687` |
| **Skip Rebirth Button** | UI Assets | `rbxassetid://100734169905146` |

---

## 3. UI Hierarchy & Layout Specifications

```text
RebirthPanel (ImageLabel - Background rbxassetid://95986709043474, AnchorPoint=(0.5, 0.5), AspectRatio ~1.62)
├── UIAspectRatioConstraint (AspectRatio = 1.62, DominantAxis = Height)
├── UISizeConstraint (MinSize=(320, 200), MaxSize=(720, 445))
│
├── TopBarContainer (Frame, Transparent, Size=(1, 0, 0.165, 0))
│   ├── Header (ImageLabel - rbxassetid://90679201316084, Position=(0, 0, 0, 0), Size=(0.885, 0, 1, 0))
│   │   └── TitleText (TextLabel, "Rebirth", Font=FredokaOne, Color=White, UIStroke Black 3px, Left/Center aligned)
│   └── CloseButton (ImageButton - rbxassetid://134336270097566, Position=(0.885, 0, 0, 0), Size=(0.115, 0, 1, 0))
│
├── RequirementContainer (Frame, Recessed Dark Gray #3B3B3B, Drop Shadow, Size=(0.92, 0, 0.22, 0), Pos=(0.5, 0, 0.22, 0), Anchor=(0.5, 0))
│   ├── UICorner (CornerRadius = 0, 6)
│   ├── UIStroke (Color = #262626, Thickness = 2)
│   ├── RequirementLabel (TextLabel, "Rebirth resets your LEVEL!", Color=#E6FF00, Font=FredokaOne, UIStroke Black 2.5px)
│   └── BarBG (Frame, Dark #181818, Size=(0.94, 0, 0.38, 0), Pos=(0.5, 0, 0.56, 0), Anchor=(0.5, 0))
│       ├── UICorner (CornerRadius = 0, 4)
│       ├── UIStroke (Color = Black, Thickness = 2)
│       ├── BarFill (Frame, Neon Green #00FF33, Size=Scale(ProgressRatio, 1))
│       │   └── UICorner (CornerRadius = 0, 4)
│       └── ProgressLabel (TextLabel, "Lv1 / 20", Font=FredokaOne, Color=White, UIStroke Black 2.5px, Centered)
│
├── MultiplierSection (Frame, Transparent, Size=(0.92, 0, 0.24, 0), Pos=(0.5, 0, 0.48, 0), Anchor=(0.5, 0))
│   ├── CurrentColumn (Frame, Size=(0.42, 0, 1, 0), Pos=(0, 0, 0, 0))
│   │   ├── HeaderLabel (TextLabel, "Current", Font=FredokaOne, Color=White, UIStroke Black 3px)
│   │   └── CurrentCard (ImageLabel - rbxassetid://106720087949362, ScaleType=Fit/Stretch)
│   │       └── Stat (TextLabel, "1X Strength", Font=FredokaOne, Color=White, UIStroke Black 3px, Pos=(0.35, 0, 0.1, 0))
│   ├── ArrowIcon (ImageLabel - rbxassetid://98387557126752, Pos=(0.5, 0, 0.65, 0), Anchor=(0.5, 0.5), Size=(0.08, 0, 0.4, 0))
│   └── NextColumn (Frame, Size=(0.42, 0, 1, 0), Pos=(0.58, 0, 0, 0))
│       ├── HeaderLabel (TextLabel, "Next", Font=FredokaOne, Color=White, UIStroke Black 3px)
│       └── NextCard (ImageLabel - rbxassetid://106720087949362, ScaleType=Fit/Stretch)
│           └── Stat (TextLabel, "2X Strength", Font=FredokaOne, Color=White, UIStroke Black 3px, Pos=(0.35, 0, 0.1, 0))
│
└── ActionButtonsContainer (Frame, Transparent, Size=(0.76, 0, 0.17, 0), Pos=(0.5, 0, 0.77, 0), Anchor=(0.5, 0))
    ├── UIListLayout (FillDirection=Horizontal, HorizontalAlignment=Center, Padding=UDim(0, 18))
    ├── RebirthButton (ImageButton - rbxassetid://113090370581687, Size=(0.47, 0, 1, 0))
    │   └── ButtonText (TextLabel, "Rebirth", Font=FredokaOne, Color=White, UIStroke Black 3px, Centered)
    └── SkipRebirthButton (ImageButton - rbxassetid://100734169905146, Size=(0.47, 0, 1, 0))
        └── ButtonText (TextLabel, "Skip Rebirth", Font=FredokaOne, Color=White, UIStroke Black 3px, Centered)
```

---

## 4. Typography & Interaction Specs

1. **Font Family:** `rbxasset://fonts/families/FredokaOne.json` across all labels.
2. **Text Strokes:** `UIStroke` with `Color = Color3.fromRGB(0, 0, 0)`, `Thickness = 2.5` to `3`.
3. **Button Bounce Micro-interaction:** `UIScale` tweens to `0.95` on press, `1.0` on release.

---

## 5. Automated Test Simulator Plan

The test simulator executes directly in Studio, capturing screens and inspecting logs at each transition:
- **Test Step 1:** Open Menu -> Screen Capture -> Verify layout and centering.
- **Test Step 2:** State Lv1/20 -> Screen Capture -> Verify progress bar ratio (~5%), labels `1X Strength` -> `2X Strength`.
- **Test Step 3:** State Lv10/20 -> Screen Capture -> Verify progress bar ratio (50%).
- **Test Step 4:** State Lv20/20 -> Screen Capture -> Verify progress bar ratio (100%), Rebirth button enabled.
- **Test Step 5:** Click Rebirth -> Screen Capture -> Verify server request & multiplier increment.
- **Test Step 6:** State Post-Rebirth (Rebirth 1) -> Screen Capture -> Verify `2X Strength` -> `3X Strength`!
- **Test Step 7:** Click Skip Rebirth -> Screen Capture -> Verify skip request.
- **Test Step 8:** Click Close Button -> Screen Capture -> Verify menu dismissal.
