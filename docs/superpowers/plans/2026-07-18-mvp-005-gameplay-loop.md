# MVP-005 Gameplay Loop Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Complete WORLD1 reward selection, durable paid delivery, race-safe Game Pass ownership, seven AFK zones, and fractional growth.

**Architecture:** Existing services retain their current authority. New `RewardPortalService` owns only reward-choice lifecycle/correlation, while `GamePassService` owns only Game Pass queries/prompts. The receipt path grants and commits before publishing a lifecycle notification; runtime prompt matching can return a world but never grant paid rewards.

**Tech Stack:** Roblox Luau, MarketplaceService, native DataStore pipeline, Lune, StyLua, Selene, Rojo, Roblox Studio MCP.

## Global Constraints

- One paid product only: `World1TripleReward`, 29 Robux, exactly 3 Destruction, `PortalOnly`.
- No VIP-discount Developer Product or dynamic paid-portal price. Explicit `0`
  placeholders are accepted as unconfigured; fake positive IDs are prohibited.
- Game Passes are exactly `Vip` and `PremiumZone`; no 2X Game Pass.
- Custom monetization thumbnails are user-approved for deferral to a future visual-polish milestone. MVP-005 uses Roblox default asset imagery; missing custom thumbnails do not block implementation, verification, review, or completion.
- Server memory is authoritative; presentation attributes are write-only projections.
- New source objects must exist and match in Studio before local implementation is written.
- No push, merge, production publish, or real-purchase claim without explicit user approval.

---

### Task 1: Planning Contract and Preflight

**Files:** task, ADR, design, plan, audit, and approved core docs listed in Exact Scope.

- [ ] Record the exact repository and Studio scope before source edits.
- [ ] Record the two Game Pass and one Developer Product contracts with final
  prices/settings while keeping explicit `0` placeholders until production configuration.
- [ ] Reject fake positive and duplicate configured IDs; treat `0` as unavailable.
- [ ] Update frozen gameplay/runtime docs under ADR-005 authority.
- [ ] Commit the verified planning/preflight unit locally.

### Task 2: Failing MVP-005 Tests

**Files:** create `tests/unit/mvp005_gameplay.luau`; modify `tests/unit/save_system.luau`; create `tests/studio/mvp005_gameplay.luau`.

- [ ] Add failing tests for profile default/normalize/snapshot, pass query generation, stale queries, post-prompt re-query, and save coalescing.
- [ ] Add failing tests for product surface validation, one 29 Robux product, reward amount 3, and committed-event durability/duplication.
- [ ] Add failing tests for Destruction validation/sync, objective activation, reward state transitions, prompt correlation, delayed/mismatched receipts, and free/paid isolation.
- [ ] Add failing tests for descending zone priority, locked-zone no-fallback, once-per-entry prompts, and fractional sequences/bounds/freeze.
- [ ] Run both unit suites and confirm failures are caused by missing MVP-005 behavior.

### Task 3: Profile, Fractional Growth, and Destruction Authority

**Interfaces:**

```luau
DestructionService:GrantDestruction(Player: Player, Amount: number): boolean
```

- [ ] Add persistent `HasPremiumZonePass` and runtime-only remainder/zone/prompt/query state.
- [ ] Snapshot and restore the new entitlement without changing schema version 1.
- [ ] Return unfloored game gain; apply whole Bigger before committing remainder.
- [ ] Centralize all Destruction mutations and presentation sync in `GrantDestruction`.
- [ ] Run focused tests to green, then save/movement/stomp regressions.
- [ ] Commit locally.

### Task 4: Race-Safe Game Pass Service

**Interfaces:**

```luau
GamePassService:IsOwned(Player: Player, PassKey: "Vip" | "PremiumZone"): boolean
GamePassService:Prompt(Player: Player, PassKey: "Vip" | "PremiumZone"): boolean
```

- [ ] Create Studio ModuleScript mirrors for `GamePassConfig` and `GamePassService`.
- [ ] Add the two real pass IDs and strict config validation.
- [ ] Subscribe before sessions are accepted and reconcile both passes with generation tokens.
- [ ] Apply only current, writable-session results; preserve saved values on API error.
- [ ] Re-query after prompt completion and queue one save for changed initial results where practical.
- [ ] Route the existing VIP HUD button to `PromptGamePassPurchase` using its exact Studio path.
- [ ] Run focused and save regressions; commit locally.

### Task 5: Seven AFK Zones

- [ ] In Edit Mode remove only the approved orphan Spawn trigger.
- [ ] Rename the three lobby triggers by ascending Z and duplicate through AFKZone7 at +53-stud spacing.
- [ ] Make all triggers anchored, invisible, and non-colliding/non-touching/non-querying.
- [ ] Audit and remove `Workspace.Starter place`, `Workspace.Forest`, and
  `Workspace.Pirate ship` only after proving they have no live references or
  required gameplay/runtime descendants.
- [ ] Relocate the same seven trigger parts near `Workspace.Portal_World1` in a
  compact 3+3+1 layout using whole-instance CFrames; preserve all gameplay and
  collision contracts and keep the portal/spawn approach clear.
- [ ] Verify grounding, bounding-box separation, exact object counts, two Play
  Solo runs, AFK multiplier transitions, portal behavior, and clean Output.
- [ ] Replace AFK config with the exact seven-zone ordered data.
- [ ] Select only the highest containing zone; locked AFKZone7 grants zero without fallback.
- [ ] Prompt Premium Zone once per entry and apply verified ownership next tick.
- [ ] Run priority, gate, prompt, and fractional tests; commit locally.

### Task 6: WORLD1 Portal Assets and Free Flow

**Interfaces:**

```luau
RewardPortalService:BindWorld(WorldInstance, WorldInstanceService): boolean
RewardPortalService:ActivateChoices(WorldInstance, WorldInstanceService): boolean
WorldInstanceService:ActivateWorld(Player): boolean
```

- [ ] Create the Studio ModuleScript mirror for `RewardPortalService`.
- [ ] Stabilize the existing Spider visual parts and build exact Exit/Free/Paid
  portal hierarchies under the WORLD1 template at approved coordinates.
- [ ] Validate exact children without recursive ambiguous lookup; bind owner-only triggers.
- [ ] Bind stomp fail-closed, teleport the Player, transition to `InWorld`, then
  arm objective damage through one explicit initialization gate.
- [ ] Change Spider completion to disable stomp and activate choices without grant/return.
- [ ] Clear Player objective presentation exactly once and allow ExitGate to
  return without granting or blocking either reward portal.
- [ ] Implement free `Choosing → Settled → Returning → InLobby` using `GrantDestruction(1)`.
- [ ] Run free-flow, duplicate, wrong-player, wrong-world, and objective tests; commit locally.

### Task 7: Paid Receipt Correlation

- [ ] Add `Surface` validation without weakening existing Shop product validation.
- [ ] Add only the real `World1TripleReward` Product ID and `Destruction = 3` reward.
- [ ] Add exact reward states and `PendingRewardPrompt` token/context.
- [ ] Drive `PromptOpen` from the portal and use purchase-finished only for state transition/cancel.
- [ ] Dispatch paid reward only through `ProcessReceipt` and publish `DeveloperProductCommitted` only after durable commit.
- [ ] On the event, settle/return only a fully matching `AwaitingReceipt` context; never grant.
- [ ] Run normal, duplicate, delayed, wrong-product, cleanup, disconnect, and old-world/new-world tests; commit locally.

### Task 8: Popup and Studio Synthetic Harness

- [ ] Replace the persistent objective panel with the exact 0.0/2.5/3.0 timeline and generation-token protection.
- [ ] Create the Studio synthetic receipt harness for every required receipt/correlation case.
- [ ] Mirror all changed source into Edit Mode and verify normalized local/Studio parity.
- [ ] Run two Play Solo gameplay/zone sessions and capture clean Output.
- [ ] Run multiplayer ownership/isolation evidence when available; label manual evidence accurately.
- [ ] Commit locally.

### Task 9: Release Gate and Audit

- [ ] Run the full commands in Verification below with fresh output.
- [ ] Update audit report, report index, task status, TASKS, CHANGELOG, and evidence.
- [ ] Review every requirement against implementation and tests.
- [ ] Finish with exactly:

```text
MVP005: READY
PRODUCTION_MONETIZATION_CONFIGURATION: DEFERRED
LIVE_MONETIZATION_QA: DEFERRED
PRODUCTION_PUBLICATION: NOT_PERFORMED
```

## Exact Scope

Create:

- `tasks/MVP-005.md`
- `docs/adr/ADR-005_reward_portal_selection.md`
- `docs/superpowers/specs/2026-07-18-mvp-005-gameplay-loop-design.md`
- `docs/superpowers/plans/2026-07-18-mvp-005-gameplay-loop.md`
- `docs/superpowers/reports/mvp-003/2026-07-18-mvp-005-audit.md`
- `docs/superpowers/reports/mvp-003/2026-07-22-mvp-005-audit.md`
- `docs/superpowers/reports/mvp-003/2026-07-22-mvp-005-runtime-unblock-audit.md`
- `docs/superpowers/reports/mvp-003/2026-07-22-mvp-005-placeholder-policy-audit.md`
- `src/server/Core/Config/GamePassConfig.luau`
- `src/server/Core/Services/GamePassService.luau`
- `src/server/Game/Services/RewardPortalService.luau`
- `tests/unit/mvp005_gameplay.luau`
- `tests/studio/mvp005_gameplay.luau`

Modify:

- `tasks/MVP-003.md`
- `docs/GAME.md`
- `docs/RUNTIME.md`
- `docs/SAVE.md`
- `docs/TASKS.md`
- `docs/CHANGELOG.md`
- `docs/examples/PlayerProfileExample.md`
- `docs/superpowers/reports/mvp-003/README.md`
- `src/client/controllers/GuiController.luau`
- `src/client/controllers/ObjectiveController.luau`
- `src/server/Core/Bootstrap/CoreBootstrap.luau`
- `src/server/Core/Config/DeveloperProductConfig.luau`
- `src/server/Core/Registry/RuntimeRegistry/Sessions.luau`
- `src/server/Core/Registry/RuntimeRegistry/WorldInstances.luau`
- `src/server/Core/Services/ConfigValidationService.luau`
- `src/server/Core/Services/CharacterScaleService.luau`
- `src/server/Core/Services/GrowthService.luau`
- `src/server/Core/Services/ReceiptProcessingService.luau`
- `src/server/Core/Services/SaveService.luau`
- `src/server/Core/Services/SessionService.luau`
- `src/server/Core/Utilities/PlayerProfileSchema.luau`
- `src/server/Core/Utilities/RewardDispatcher.luau`
- `src/server/Game/Config/AFKZones.luau`
- `src/server/Game/Config/World1Config.luau`
- `src/server/Game/Formula/GrowthFormula.luau`
- `src/server/Game/GameBootstrap.luau`
- `src/server/Game/Services/DestructionService.luau`
- `src/server/Game/Services/PortalService.luau`
- `src/server/Game/Services/WorldInstanceService.luau`
- `src/server/Game/Systems/AFKZoneSystem.luau`
- `src/shared/Core/Config/ShopUIConfig.luau`
- `src/shared/Core/Enums/RewardType.luau`
- `src/shared/Core/Utilities/ScaleCurve.luau`
- `src/shared/Game/Progression/LevelFormula.luau`
- `tests/unit/save_system.luau`

No additional repository path may change before it is added here and to
`tasks/MVP-005.md` with the dependency reason reported for user review.

### Targeted WORLD1 runtime stabilization

**Files:** modify `CharacterScaleService`, `PortalService`,
`WorldInstanceService`, `DestructionService`, `RewardPortalService`,
`World1Config`, `RuntimeRegistry.WorldInstances`, and
`tests/unit/mvp005_gameplay.luau`.

- [ ] Add RED tests for actual scale application/reapplication and idempotent
  lifecycle ownership; do not duplicate ScaleCurve math in the service.
- [ ] Add RED tests proving stomp is disabled until the world reaches `InWorld`,
  an immediate valid stomp completes once, and duplicate callbacks do nothing.
- [ ] Add RED tests proving ExitGate/Free/Paid are required, ExitGate returns
  without a grant, Free grants once, and ProductId `0` leaves Paid visible with
  `UNAVAILABLE` while disabling only its trigger.
- [ ] Apply the smallest service changes that satisfy those tests. Do not add a
  Humanoid/health combat system or change Level/progression balance.
- [ ] In Edit Mode anchor the current Spider visual geometry and create exactly
  one ExitGate from the existing portal asset shape; verify source parity before
  Play Solo.

### Targeted MVP-007 prerequisite: Level unification

- **Reason:** align MVP-005 Player Level, HUD progress, and avatar scaling with
  MVP-007's server-authoritative unlock validation.
- **Affected callers:** `SessionService`, `GrowthService`, `GuiController`,
  `ScaleCurve`, `EquipmentService`, and Level-gated portals.
- **Compatibility impact:** preserve the existing player-visible fourth-root
  curve; remove the conflicting linear calculation without changing `Bigger`,
  fractional growth, or other economy rules.
- **Tests required:** canonical boundaries and actual consumer behavior at
  `requirement - 1`, `requirement`, and `requirement + 1` for Levels 5, 10, 25,
  50, 100, 200, and 500.
- **Persistence and scope:** no migration is required; `Bigger` remains
  authoritative. This is a targeted MVP-007 prerequisite, not an economy
  redesign.
- **Audit evidence:** add the immutable dated 2026-07-22 MVP-005 audit cycle;
  retain the existing 2026-07-18 report unchanged.

### Runtime unblock: optional monetization and HUD lifecycle

**Files:** modify `GamePassService`, `ConfigValidationService`,
`ReceiptProcessingService`, `RewardPortalService`, `GuiController`,
`ObjectiveController`, and `tests/unit/mvp005_gameplay.luau`; create the
runtime-unblock audit listed in Exact Scope.

- [ ] Add RED tests proving zero Game Pass/Product IDs return structured
  `MissingAssetId`/`MissingProductId` status, warn once, reject ownership,
  prompts, paid portal, and receipts, and do not abort Core/Game bootstrap.
- [ ] Keep metadata, reward shape/type, duplicate registration, and persistence
  invariants fatal. Do not wrap the whole bootstrap in `pcall`.
- [ ] Implement the minimum per-feature status in the existing services. Valid
  configured IDs retain current query, prompt, and receipt behavior.
- [ ] Add RED controller tests for bounded missing-HUD resolution, late bind,
  removal/rebind, and duplicate connection prevention.
- [ ] Resolve `PlayerGui` with a bounded wait, find the canonical
  `PlayerGui.MainHUD` only, and expose `HUDUnavailable` without creating or
  duplicating the Studio-authored asset.
- [ ] Run `lune run tests/unit/mvp005_gameplay.luau` after each RED/GREEN
  group, then run the complete offline and Studio gates.

### Placeholder monetization policy adjustment

**Files:** modify `tasks/MVP-005.md`, the MVP-005 design and this plan,
`tests/unit/mvp005_gameplay.luau`, and the report index; create the immutable
placeholder-policy audit listed in Exact Scope.

- [ ] Replace only the two obsolete positive-production-ID assertions with
  explicit `0` placeholder assertions; retain all configured-ID behavior tests.
- [ ] Verify `MissingAssetId`/`MissingProductId`, warning-once, no ownership
  query/prompt, placeholder/unknown receipt rejection, paid portal unavailable,
  free portal continuity, and unrelated bootstrap continuity.
- [ ] Record production IDs and live purchase QA as deferred configuration, not
  as implementation blockers or production-verified evidence.
- [ ] Run the complete offline gate. Set MVP-005 to `READY` only when every
  current-scope command exits `0`; leave both MVP-007 decisions unchanged.

## Verification

```powershell
lune run tests/unit/movement_validation.luau
lune run tests/unit/stomp_validation.luau
lune run tests/unit/save_system.luau
lune run tests/unit/mvp005_gameplay.luau
stylua --check src tests
selene src
rojo build default.project.json -o "$env:TEMP\bigger-mvp005.rbxl"
git diff --check
```

Receipt and purchase flow for the current placeholder state is code verified,
unit verified, and placeholder fail-closed verified. It is not production
purchase verified. No production publication or remote push occurs in this plan.
