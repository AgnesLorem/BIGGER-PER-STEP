# Task MVP-006: Quality Update & Spec-Driven Development (SDD) Core Stabilization

Execute the comprehensive **Quality Update** for Project BIGGER. Restore strict **Spec-Driven Development (SDD)** discipline, resolve architectural contradictions between `GAME.md` and runtime services, eliminate character scaling animation glitches, quarantine un-specced peripheral systems, and establish a rock-solid, bug-free Core Loop foundation.

---

## Scoped Files

AI agents implementing this task are **STRICTLY RESTRICTED** to modifying only the following files:
- `tasks/MVP-006_quality_update.md` (Official task file in repo)
- `docs/GAME.md` (Update Destruction & Growth Upgrade milestone definitions)
- `src/server/Game/GameBootstrap.luau` (Quarantine unapproved non-MVP services)
- `src/server/Game/Services/UpgradeService.luau` (Remove Destruction deduction; enforce milestone check)
- `src/server/Game/Services/DestructionService.luau` (Remove DeductDestruction; scale-normalize stomp checks)
- `src/server/Game/Config/UpgradeConfig.luau` (Document DestructionRequirement aliases)
- `src/server/Core/Services/CharacterScaleService.luau` (Server physical scaling + dynamic WalkSpeed calculation)
- `src/client/controllers/CharacterScaleController.luau` (Client dynamic camera zoom & footstep scaling)
- `src/client/controllers/GuiController.luau` (Conditionally hide quarantined menu buttons)
- `tests/unit/quality_update_contracts.luau` (Automated contract test suite)

---

## Integration Boundary

Modules that this task interacts with but must **NOT** rewrite or refactor:
- `src/server/Core/Services/SaveService.luau` (Profile persistence remains intact; backward-compatible schema preserved)
- `src/server/Core/Registry/RuntimeRegistry/Sessions.luau` (Session schema types preserved)
- `src/server/Game/Services/RebirthService.luau` (Rebirth reset pipeline verified against new scale rules)
- `src/server/Game/Services/PortalService.luau` (Entrance validation checks)

---

## Out of Scope

To eliminate scope creep and preserve stability, this task must **NOT**:
- Refactor or add features to `DailyRewardService`, `SpinWheelService`, `CosmeticsService`, or `AutoWinsService` (these are quarantined).
- Create new 2D GUI scroll menus for Growth Upgrades (interaction is 100% via 3D World Pedestals in Lobby).
- Introduce new gameplay mechanics (Pets, Guilds, PvP, Crafting, Trading).
- Add new Robux developer products or gamepasses.
- Touch unrelated core utilities or networking layers.

---

## Formal Invariants & State Machine Rules

1. **INV-01 (Authority)**: Server Memory is the absolute Source of Truth. Client attributes, GUI, and leaderstats are non-authoritative visual reflections.
2. **INV-02 (Destruction Milestone)**: Destruction is a permanent progression milestone and **CANNOT BE SPENT OR DEDUCTED**. Upgrades unlock when `Session.Destruction >= Upgrade.DestructionRequirement`.
3. **INV-03 (Scale Ergonomics)**: Character `WalkSpeed` scales via $16 \times \sqrt{\text{VisualScale}}$ to maintain natural stride physics and prevent Roblox Animate A-pose / sliding.
4. **INV-04 (Portal & Stomp Safety)**: Portal entrance requirements guarantee $\text{PlayerScale} \ge \text{ObjectScale}$. Hitbox stomp calculations must be normalized by `VisualScale`.
5. **INV-05 (Rebirth Preservation)**: Rebirth resets `Size` to 1 and increments `Rebirth` count. `Destruction` milestones and unlocked/equipped `Growth Upgrades` are retained permanently.

---

## Execution Steps

- [x] **Step 1: Quarantine Unspecced Non-MVP Services**
  - In `src/server/Game/GameBootstrap.luau`, comment out/unregister `DailyRewardService`, `SpinWheelService`, `CosmeticsService`, and `AutoWinsService`.
  - In `src/client/controllers/GuiController.luau`, disable/hide the LeftSidebar buttons corresponding to quarantined services.

- [x] **Step 2: Reconcile Destruction Milestone & Growth Upgrades**
  - In `src/server/Game/Services/UpgradeService.luau`, remove the call to `DestructionService:DeductDestruction`.
  - Validate unlock condition using `Session.Destruction >= Upgrade.Cost` (Milestone check).
  - In `src/server/Game/Services/DestructionService.luau`, remove or deprecate `DeductDestruction`.
  - Update `docs/GAME.md` to formally state Growth Upgrades unlock based on lifetime Destruction milestones without spending.

- [x] **Step 3: Character Scale Ergonomics & Animation Preservation**
  - In `src/server/Core/Services/CharacterScaleService.luau`, compute dynamic `WalkSpeed = 16 * math.sqrt(VisualScale)` and apply to `Humanoid.WalkSpeed`.
  - Stabilize `Humanoid.HipHeight` so the character remains firmly in `Running` state without triggering freefall or A-pose gliding.
  - In `src/client/controllers/CharacterScaleController.luau`, observe scale changes and dynamically update `LocalPlayer.CameraMaxZoomDistance` and `LocalPlayer.CameraMinZoomDistance`.

- [x] **Step 4: Scale-Normalized Stomp Validation**
  - In `src/server/Game/Services/DestructionService.luau`, normalize `MaximumRootHeight` by `VisualScale` so giant players' stomps register accurately.
  - Verify that Portal entrance checks ensure player size is sufficient before entry.

- [x] **Step 5: Automated Contract Test Suite**
  - Create `tests/unit/quality_update_contracts.luau` to programmatically verify:
    1. Size accumulation $\to$ VisualScale calculation $\to$ WalkSpeed scaling.
    2. Upgrade unlocking without Destruction deduction.
    3. Rebirth state transition preserving Destruction and Upgrades.
    4. Quarantined services remain inert.

- [x] **Step 6: Two-Stage Verification Gate**
  - Stage 1 (Offline): Run `selene src/` and `stylua --check src/`. Run automated unit test suite.
  - Stage 2 (Studio Play Solo): Run Play Solo session via MCP (`start_stop_play`), simulate a full player loop (Size 1 $\to$ Grow $\to$ Enter Portal $\to$ Stomp Spider $\to$ Settle Reward $\to$ Return to Lobby $\to$ Equip Upgrade $\to$ Rebirth), verify 0 console errors/warnings in F9.

---

## QA & Verification Checklist

- [x] **StyLua**: `stylua --check src/` passed (0 formatting discrepancies).
- [x] **Selene**: `selene src/` passed (0 errors, 0 warnings).
- [x] **Contract Tests**: `tests/unit/quality_update_contracts.luau` 100% green.
- [x] **Roblox Studio Play Solo**: Full loop tested in engine with clean F9 console.
- [x] **Walkthrough Created**: Evidence logs and screenshots documented.
- [ ] **User Review Approval**: Presented to user and approved before any git push.
