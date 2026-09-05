# Rebirth Menu Pixel-Perfect UI, Multiplier Formula Fix & Test Simulator Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Fix the critical Rebirth Multiplier formula bug in `GrowthFormula.luau`, reconstruct the Rebirth Menu UI in Roblox Studio to achieve 100% pixel-perfect fidelity with reference assets (`GUI/UI_ImageReference/RebirthMenu.png`), bind client controller interactions with button bounce tweens, and execute an automated step-by-step Studio Test Simulator with screen captures and state analysis at each step.

**Architecture:** 
- Fix `GrowthFormula.GetMultiplier` from `math.max(1, Session.Rebirth)` to `(Session.Rebirth + 1)` ensuring mathematical progression (0 -> 1X, 1 -> 2X, 2 -> 3X).
- Rebuild `RebirthPanel` in Studio Edit Mode using official image assets (`Background`, `Header`, `CloseButton`, `CurrentCard`, `Arrows`, `RebirthButton`, `SkipRebirthButton`) and Constraint-Driven Responsive Architecture.
- Update `RebirthController.luau` to handle dynamic bindings and button bounce tweens.
- Run a multi-step Studio Test Simulator capturing screenshots and inspecting console output at each state transition.

**Tech Stack:** Luau, Roblox Studio DataModel, ScreenGui, TweenService, Selene, StyLua.

## Global Constraints
- All physical avatar scaling must remain on the Server.
- Server Authority is absolute: Multiplier is calculated in `GrowthFormula.luau`.
- Pure responsive UI composition using `UIAspectRatioConstraint`, `UISizeConstraint`, and Scale positioning.
- Font: `rbxasset://fonts/families/FredokaOne.json` with black `UIStroke` (Thickness 2.5–3px).
- Every test step must include a screen capture and visual/output inspection against prompt requirements.

---

### Task 1: Fix Rebirth Multiplier Formula in `GrowthFormula.luau`

**Files:**
- Modify: `src/server/Game/Formula/GrowthFormula.luau:25-36`

**Interfaces:**
- Produces: `GrowthFormula.GetMultiplier(Session)` returning `BaseMult * (Session.Rebirth + 1)`

- [ ] **Step 1: Fix `GrowthFormula.GetMultiplier` formula**
Replace line 33 in `src/server/Game/Formula/GrowthFormula.luau` so that `Multiplier *= (Session.Rebirth + 1)` instead of `Multiplier *= math.max(1, Session.Rebirth)`.

- [ ] **Step 2: Lint and format `GrowthFormula.luau`**
Run `bin/stylua.exe src/server/Game/Formula/GrowthFormula.luau` and `bin/selene.exe src/server/Game/Formula/GrowthFormula.luau`.

---

### Task 2: Reconstruct Pixel-Perfect Rebirth Menu Hierarchy in Roblox Studio

**Files:**
- Modify in Studio DataModel: `StarterGui.MainHUD.SafeAreaRoot.OverlayHUD.RebirthPanel`

**Interfaces:**
- Asset IDs:
  - Background: `rbxassetid://95986709043474`
  - Header: `rbxassetid://90679201316084`
  - CloseButton: `rbxassetid://134336270097566`
  - CurrentCard / NextCard: `rbxassetid://106720087949362`
  - Arrows: `rbxassetid://98387557126752`
  - RebirthButton: `rbxassetid://113090370581687`
  - SkipRebirthButton: `rbxassetid://100734169905146`

- [ ] **Step 1: Execute Luau script in Roblox Studio Edit Mode to reconstruct `RebirthPanel`**
Run Luau script via `execute_luau` in Edit Mode to clear existing `RebirthPanel` children and construct the complete, pixel-perfect hierarchy matching `GUI/UI_ImageReference/RebirthMenu.png`.

- [ ] **Step 2: Capture screen in Studio Edit Mode**
Run `screen_capture` with `capture_id: "ScreenCapture_RebirthPanel_Rebuilt"`.

- [ ] **Step 3: Analyze screenshot against Reference Image**
Use `view_file` to inspect the captured image, verifying exact asset alignment, colors, typography, and aspect ratio.

---

### Task 3: Update Client Controller & Micro-interactions

**Files:**
- Modify: `src/client/controllers/RebirthController.luau`

**Interfaces:**
- Consumes: `UpdateRebirth` (RemoteEvent), `RequestRebirth` (RemoteEvent), `RequestSkipRebirth` (RemoteEvent), `UIEventBus`
- Produces: `RebirthController.Open()`, `RebirthController.Close()`, `RebirthController.Toggle()`, button bounce animations

- [ ] **Step 1: Update RebirthController.luau with new element paths and bounce animations**
Update element queries to point to `TopBarContainer`, `RequirementContainer`, `MultiplierSection`, `ActionButtonsContainer`, and attach button press bounce tweens using `TweenService`.

- [ ] **Step 2: Format and lint RebirthController.luau**
Run `bin/stylua.exe src/client/controllers/RebirthController.luau` and `bin/selene.exe src/client/controllers/RebirthController.luau`.

---

### Task 4: Build & Execute the Automated Gameplay / GUI Test Simulator

**Files:**
- Execute via Studio: Multi-step Luau Test Runner script

**Test Steps:**
- [ ] **Step 1 (Open Menu Test):** Programmatically open Rebirth Menu -> Screen capture -> Analyze visual visibility & positioning.
- [ ] **Step 2 (Level 1/20 State Test):** Fire simulated state (`CurrentLevel=1, RequiredLevel=20, GrowthMultiplier=1, NextGrowthMultiplier=2`) -> Screen capture -> Verify progress bar ratio (~5%), labels ("Lv1 / 20", "1X Strength", "2X Strength").
- [ ] **Step 3 (Level 10/20 State Test):** Fire simulated state (`CurrentLevel=10, RequiredLevel=20`) -> Screen capture -> Verify progress bar ratio (50%), label ("Lv10 / 20").
- [ ] **Step 4 (Level 20/20 Ready State Test):** Fire simulated state (`CurrentLevel=20, RequiredLevel=20, CanRebirth=true`) -> Screen capture -> Verify progress bar ratio (100%), label ("Lv20 / 20"), Rebirth button full bright state.
- [ ] **Step 5 (Rebirth Click Interaction Test):** Simulate clicking `RebirthButton` -> Verify `RequestRebirth` invocation and tween animation -> Screen capture.
- [ ] **Step 6 (Post-Rebirth 1 State Test):** Verify formula calculation produces `GrowthMultiplier = 2X` and `NextGrowthMultiplier = 3X` -> Screen capture.
- [ ] **Step 7 (Skip Rebirth Click Interaction Test):** Simulate clicking `SkipRebirthButton` -> Verify `RequestSkipRebirth` invocation and tween animation -> Screen capture.
- [ ] **Step 8 (Close Menu Interaction Test):** Simulate clicking `CloseButton` -> Verify menu closes and `OverlayHUD` hides -> Screen capture.
