# MVP-007: Equipment System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use
> `superpowers:subagent-driven-development` or `superpowers:executing-plans` to
> implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for
> tracking. This run uses inline execution and does not commit or push.

**Goal:** Build a server-authoritative Growth Upgrades equipment system enabling players to sequentially unlock linear upgrades and equip a single active growth multiplier buff.

**Architecture:** `LevelFormula` is the one pure Level calculation consumed by
server attributes, HUD presentation, avatar scaling, portals, and equipment
authorization. Equipment uses correlated RemoteEvent requests, bounded runtime
state in Sessions, server mutations, state snapshots, and the existing
non-blocking save queue.

**Tech Stack:** strict Luau, Roblox services, Rojo, Lune assertion harnesses,
RemoteEvents, EventBus lifecycle events, and the existing per-UserId FIFO save
worker.

## Global Constraints & Approved Decisions

- Preserve `Level = floor((Bigger / 236) ^ 0.25) + 1`; do not use `Bigger / 10`
  or import the unmerged `BalanceConfig`.
- `Bigger` remains authoritative and persisted; no Level migration.
- Client Level and payloads are never authorization inputs.
- Use RemoteEvents only for equipment request/response/state synchronization.
- Preserve MVP-005 fractional growth ordering and unrelated economy behavior.
- Create Studio source objects in Edit Mode before mirroring new local sources.
- Run offline gates before Studio parity, Play Solo, and multiplayer checks.
- Do not invent production monetization IDs; missing IDs fail closed and remain
  an explicit release blocker.
- Do not commit or push. Record suggested commit messages only.

- **Sequence & Multipliers**:
  - `None` (1x, virtual default state)
  - `Protein` (1.5x, 1 Destruction, Level 5)
  - `SilverProtein` (2x, 5 Destruction, Level 10)
  - `GoldProtein` (3x, 15 Destruction, Level 25)
  - `DiamondProtein` (5x, 30 Destruction, Level 50)
  - `GrowthSerum` (10x, 60 Destruction, Level 100)
  - `AdvancedSerum` (25x, 120 Destruction, Level 200)
  - `TitanSerum` (50x, 250 Destruction, Level 500)
- **`None` Semantics**: Virtual state. Not stored in `UnlockedGrowthUpgrades` (`None=true` is not stored). `EquippedGrowthUpgrade = nil` represents `None`. `None` is always available. `Protein` has no persistent predecessor. Persist `nil` when unequipped, never `"None"`.
- **Authoritative Level**: Unlock validation calculates Level from `Session.Bigger` using `LevelFormula.GetLevelFromBigger(Session.Bigger)`. Never trust client attributes (`Player:GetAttribute("Level")`).
- **Offline Progression**: Equipment multipliers apply ONLY to active gameplay growth. Offline progression uses existing entitlement rules (`SaveService`). `UpgradesConfig` is NOT a dependency of `SaveService`.
- **Formula Multiplier Composition**: `equipment multiplier × HasDoubleMultiplier × HasVip`. Preserve fractional growth in `GrowthFormula.Calculate`.
- **Immediate Save Behavior**: Mutation succeeds → presentation sync succeeds → `SaveService:QueueProfileSave(Player)` queues non-blocking save via FIFO worker → remote returns.
- **Deep Freezing**: Deep-freeze `Sequence`, every `UpgradeDefinition`, `Upgrades`, and `UpgradesConfig`.

---

## Exact Repository Scope

The exact scope of created and modified files for MVP-007:

- `tasks/MVP-007.md`
- `docs/superpowers/specs/2026-07-22-mvp-007-level-unification-design.md`
- `docs/superpowers/reports/mvp-003/2026-07-22-mvp-007-level-unification-audit.md`
- `docs/superpowers/reports/mvp-003/2026-07-22-mvp-007-equipment-rework-audit.md`
- `docs/superpowers/plans/2026-07-21-mvp-007-equipment-system.md`
- `src/shared/Game/Config/UpgradesConfig.luau`
- `src/shared/Game/Progression/LevelFormula.luau`
- `src/server/Game/Services/EquipmentService.luau`
- `src/server/Game/Services/PortalService.luau`
- `src/server/Game/Formula/GrowthFormula.luau`
- `src/server/Game/GameBootstrap.luau`
- `src/server/Core/Services/SaveService.luau`
- `src/server/Core/Services/SessionService.luau`
- `src/server/Core/Services/GrowthService.luau`
- `src/server/Core/Registry/RuntimeRegistry/Sessions.luau`
- `src/shared/Core/Utilities/ScaleCurve.luau`
- `src/client/controllers/GuiController.luau`
- `src/client/controllers/EquipmentController.luau`
- `src/client/BiggerClientMain.client.luau`
- `tests/unit/equipment_system.luau`
- `tests/unit/mvp005_gameplay.luau`

---

## Targeted MVP-007 prerequisite: Level unification

- **Reason:** authoritative unlock validation must match Player Level, HUD, and
  avatar scaling already visible to players.
- **Affected callers:** `SessionService`, `GrowthService`, `GuiController`,
  `ScaleCurve`, `EquipmentService`, and Level-gated portals.
- **Compatibility impact:** retain the fourth-root visible curve and remove only
  the conflicting `Bigger / 10` path. `Bigger`, fractional growth, and unrelated
  economy behavior do not change.
- **Tests required:** verify actual consumer boundaries at `requirement - 1`,
  `requirement`, and `requirement + 1` for Levels 5, 10, 25, 50, 100, 200, and
  500, including spoofed client attributes and Player isolation.
- **Persistence and scope:** no migration is required; authoritative
  `Session.Bigger` remains the source. This is a targeted prerequisite for
  MVP-007 equipment correctness, not a new economy redesign.
- **Runtime dependency:** bounded per-Player request lock/timestamp fields live
  in `RuntimeRegistry/Sessions.luau`; they are removed with the session and are
  never persisted.
- **Audit evidence:** add immutable dated Level-unification and equipment-rework
  reports; do not edit older audit reports.
- **Portal dependency:** include the existing LevelFormula caller solely to make
  invalid/frozen authoritative sessions fail closed. No public portal contract,
  Level requirement, reward, or economy value changes.

---

## Task 1: Lock canonical Level boundaries with failing tests

**Files:**
- Modify: `tests/unit/equipment_system.luau`
- Test: `tests/unit/equipment_system.luau`

**Interfaces:**
- Consumes: current `LevelFormula.GetLevelFromBigger(number): number` and
  `GetRequirementForLevel(number): number`.
- Produces: executable boundary contract for Tasks 2-11.

- [ ] Add the exact threshold table and assert inverse/boundary behavior:

```luau
local Thresholds = {
    [5] = 60416,
    [10] = 1548396,
    [25] = 78299136,
    [50] = 1360493036,
    [100] = 22670065836,
    [200] = 370104451436,
    [500] = 14632353528236,
}

for Level, Requirement in Thresholds do
    assert(LevelFormula.GetRequirementForLevel(Level) == Requirement)
    assert(LevelFormula.GetLevelFromBigger(Requirement - 1) == Level - 1)
    assert(LevelFormula.GetLevelFromBigger(Requirement) == Level)
    assert(LevelFormula.GetLevelFromBigger(Requirement + 1) == Level)
end
```

- [ ] Add Level 1, Bigger 0, monotonicity, inverse, invalid numeric input, large
  supported Bigger, progress reset, and progress clamp assertions.
- [ ] Run `lune run tests/unit/equipment_system.luau`.
  Expected: FAIL on the current linear formula or missing `GetProgress`.
- [ ] Suggested checkpoint: `test(mvp-007): lock canonical level boundaries`.

## Task 2: Implement the canonical LevelFormula

**Files:**
- Modify: `src/shared/Game/Progression/LevelFormula.luau`
- Test: `tests/unit/equipment_system.luau`

**Interfaces:**
- Produces: `GetLevelFromBigger(Bigger: number): number`,
  `GetRequirementForLevel(Level: number): number`, and
  `GetProgress(Bigger: number): LevelProgress`.

- [ ] Add strict finite/range validation and the approved constants:

```luau
local BASE_REQUIREMENT = 236
local MAX_SAFE_INTEGER = 9007199254740991

local function IsFinite(Number: number): boolean
    return Number == Number and Number > -math.huge and Number < math.huge
end
```

- [ ] Implement the fourth-root candidate plus exact inverse correction; reject
  invalid Bigger and non-positive/fractional/overflowing Levels.
- [ ] Implement `GetProgress` from the two public canonical functions and clamp
  only the final ratio.
- [ ] Run `lune run tests/unit/equipment_system.luau`.
  Expected: LevelFormula group PASS; later integration groups may still fail.
- [ ] Run `stylua --check src/shared/Game/Progression/LevelFormula.luau tests/unit/equipment_system.luau`.
  Expected: exit 0.
- [ ] Suggested checkpoint: `fix(mvp-007): unify canonical level formula`.

## Task 3: Add avatar ScaleCurve regression coverage

**Files:**
- Modify: `tests/unit/mvp005_gameplay.luau`
- Test: `tests/unit/mvp005_gameplay.luau`

**Interfaces:**
- Consumes: `ScaleCurve.GetVisualScale(Bigger, "level", 0.2): number`.
- Produces: proof that scale uses the same corrected boundary Level.

- [ ] Load the actual `ScaleCurve` module with the actual canonical
  `LevelFormula` dependency in the Lune module tree.
- [ ] For every threshold, assert:

```luau
assert(ScaleCurve.GetVisualScale(Requirement - 1, "level", 0.2) == 1 + (Level - 2) * 0.2)
assert(ScaleCurve.GetVisualScale(Requirement, "level", 0.2) == 1 + (Level - 1) * 0.2)
assert(ScaleCurve.GetVisualScale(Requirement + 1, "level", 0.2) == 1 + (Level - 1) * 0.2)
```

- [ ] Run `lune run tests/unit/mvp005_gameplay.luau`.
  Expected: FAIL because ScaleCurve still duplicates the old inline curve module
  boundary rather than consuming `LevelFormula`.
- [ ] Suggested checkpoint: `test(mvp-007): cover avatar level scaling boundaries`.

## Task 4: Route ScaleCurve through LevelFormula

**Files:**
- Modify: `src/shared/Core/Utilities/ScaleCurve.luau`
- Test: `tests/unit/mvp005_gameplay.luau`

**Interfaces:**
- Consumes: `LevelFormula.GetLevelFromBigger(number): number`.
- Preserves: `ScaleCurve.GetVisualScale(Bigger, Formula?, CurveParameter?): number`.

- [ ] Require `BiggerShared.Game.Progression.LevelFormula` once at module load.
- [ ] Replace only the `level` branch body with:

```luau
level = function(Bigger: number, CurveParameter: number): number
    local Level = LevelFormula.GetLevelFromBigger(Bigger)
    return 1 + (Level - 1) * CurveParameter
end,
```

- [ ] Run `lune run tests/unit/mvp005_gameplay.luau`.
  Expected: ScaleCurve group PASS; unrelated known MVP-005 failures remain named.
- [ ] Suggested checkpoint: `fix(mvp-007): route avatar scale through level formula`.

## Task 5: Add actual SessionService and GrowthService Level tests

**Files:**
- Modify: `tests/unit/mvp005_gameplay.luau`
- Test: `tests/unit/mvp005_gameplay.luau`

**Interfaces:**
- Consumes: `SessionService` session creation and `GrowthService` authoritative
  Bigger mutation path.
- Produces: two-Player attribute isolation and fractional-growth compatibility.

- [ ] Extend the existing mock module tree with `Game.Progression.LevelFormula`
  and `Game.Config.UpgradesConfig`; do not stub the Level result.
- [ ] Load two sessions at different Bigger thresholds and assert each Player's
  `Level` attribute equals `LevelFormula.GetLevelFromBigger(Session.Bigger)`.
- [ ] Mutate Bigger through GrowthService and assert Level updates only after the
  successful mutation, while 2.5x and 4.5x remainder sequences stay unchanged.
- [ ] Run `lune run tests/unit/mvp005_gameplay.luau`.
  Expected: FAIL on duplicated SessionService/GrowthService formulas.
- [ ] Suggested checkpoint: `test(mvp-007): cover authoritative level attributes`.

## Task 6: Integrate server Level attributes

**Files:**
- Modify: `src/server/Core/Services/SessionService.luau`
- Modify: `src/server/Core/Services/GrowthService.luau`
- Test: `tests/unit/mvp005_gameplay.luau`

**Interfaces:**
- Consumes: `LevelFormula.GetLevelFromBigger(Session.Bigger)`.
- Produces: replicated Player `Level` presentation attribute.

- [ ] Require `LevelFormula` using the existing ReplicatedStorage shared-module
  pattern in both services.
- [ ] Replace both fourth-root expressions with the canonical call after session
  load and successful Bigger mutation; do not move remainder updates.
- [ ] Run `lune run tests/unit/mvp005_gameplay.luau`.
  Expected: session/growth Level and fractional growth groups PASS.
- [ ] Suggested checkpoint: `fix(mvp-007): unify server level attributes`.

## Task 7: Add actual HUD presentation tests

**Files:**
- Modify: `tests/unit/mvp005_gameplay.luau`
- Test: `tests/unit/mvp005_gameplay.luau`

**Interfaces:**
- Consumes: `GuiController.Init()`, `GuiController.Start()`, Player attributes,
  and `LevelFormula.GetProgress`.
- Produces: HUD boundary/missing-attribute regression evidence.

- [ ] Extend the existing Roblox mock with the minimum MainHUD label/fill tree,
  TweenService recorder, and attribute change signals.
- [ ] Assert exact requirement uses the replicated target Level and resets fill to
  zero; `requirement + 1` advances using canonical progress.
- [ ] Assert absent Bigger/Level/Multiplier attributes do not throw and repeated
  `Start` does not duplicate the three attribute listeners.
- [ ] Assert the controller source no longer contains `236`, `math.pow`, or the
  fourth-root expression after Task 8.
- [ ] Run `lune run tests/unit/mvp005_gameplay.luau`.
  Expected: FAIL on duplicated HUD math and duplicate connections.
- [ ] Suggested checkpoint: `test(mvp-007): cover canonical hud level progress`.

## Task 8: Remove duplicated HUD Level math

**Files:**
- Modify: `src/client/controllers/GuiController.luau`
- Test: `tests/unit/mvp005_gameplay.luau`

**Interfaces:**
- Consumes: replicated `Level` and `LevelFormula.GetProgress(Bigger)`.
- Preserves: existing public `Init`/`Start` controller API and UI object names.

- [ ] Require `BiggerShared.Game.Progression.LevelFormula`.
- [ ] Delete `CalculateLevelProgress`; use `GetProgress(bigger).Progress` only
  after confirming Bigger is a finite non-negative number.
- [ ] Keep replicated Level as display state, safe defaults for unavailable
  attributes, and a single retained connection set for idempotent `Start`.
- [ ] Run `lune run tests/unit/mvp005_gameplay.luau`.
  Expected: HUD group PASS with no duplicated formula.
- [ ] Suggested checkpoint: `fix(mvp-007): consume canonical hud progress`.

## Task 9: Add real EquipmentService unlock boundary tests

**Files:**
- Modify: `tests/unit/equipment_system.luau`
- Test: `tests/unit/equipment_system.luau`

**Interfaces:**
- Consumes: actual `EquipmentService` request/mutation boundary, Sessions,
  UpgradesConfig, and SaveService queue spy.
- Produces: seven-upgrade authority and save contract.

- [ ] For every real upgrade, seed predecessors and Destruction, then assert
  `requirement - 1` rejects, exact requirement succeeds, and requirement + 1
  succeeds in an isolated session.
- [ ] Set a spoofed high Player Level with low Bigger and assert rejection; set a
  spoofed low attribute with sufficient Bigger and assert success.
- [ ] Assert success unlocks without equipping and queues exactly one save; every
  failed operation queues zero saves.
- [ ] Run `lune run tests/unit/equipment_system.luau`.
  Expected: FAIL until canonical formula and real service boundary agree.
- [ ] Suggested checkpoint: `test(mvp-007): cover authoritative equipment gates`.

## Task 10: Harden authoritative equipment Level validation

**Files:**
- Modify: `src/server/Game/Services/EquipmentService.luau`
- Modify: `src/shared/Game/Config/UpgradesConfig.luau`
- Test: `tests/unit/equipment_system.luau`

**Interfaces:**
- Consumes: `Session.Bigger` and canonical LevelFormula.
- Produces: fail-closed validation with no client Level input.

- [ ] Validate `Session.Bigger` through the canonical API before
  `UpgradesConfig.CanUnlock`; convert numeric validation failures to
  `RequirementsNotMet` without mutation.
- [ ] Keep `CanUnlock` limited to config/predecessor/currency/Level comparison;
  reject non-finite or fractional numeric inputs at that helper boundary.
- [ ] Run `lune run tests/unit/equipment_system.luau`.
  Expected: all Level and unlock boundary groups PASS.
- [ ] Suggested checkpoint: `fix(mvp-007): fail closed on invalid level authority`.

## Task 11: Verify Level-gated portal authority

**Files:**
- Modify: `src/server/Game/Services/PortalService.luau`
- Modify: `tests/unit/equipment_system.luau`
- Test: `tests/unit/equipment_system.luau`

**Interfaces:**
- Consumes: actual `PortalService` Level validation from `Session.Bigger`.
- Produces: portal spoof/session/frozen boundary evidence without production API
  changes unless the test exposes a defect.

- [ ] Load the actual PortalService in the existing harness and assert a spoofed
  Player Level cannot pass, authoritative Bigger can pass, and missing/frozen
  sessions fail closed at the configured Level requirement.
- [ ] Run `lune run tests/unit/equipment_system.luau`.
  Expected: PASS if the current canonical call is correct; otherwise fix only the
  in-scope caller after recording the exact new scope requirement.
- [ ] Suggested checkpoint: `test(mvp-007): verify portal level authority`.

## Task 12: Re-establish the MVP-005 focused baseline

**Files:**
- Test: `tests/unit/save_system.luau`
- Test: `tests/unit/mvp005_gameplay.luau`

- [ ] Run `lune run tests/unit/save_system.luau` and record each named failure.
- [ ] Run `lune run tests/unit/mvp005_gameplay.luau` and record each named
  failure separately.
- [ ] Confirm the GrowthFormula harness now provides `UpgradesConfig`; do not
  bypass the real dependency.
- [ ] Expected remaining failures: only unimplemented MVP-005 contracts and
  missing real production IDs, not Level/module-tree errors.

## Task 13: Complete MVP-005 product and reward contracts

**Files:**
- Modify: `src/server/Core/Config/GamePassConfig.luau`
- Modify: `src/server/Core/Config/DeveloperProductConfig.luau`
- Modify: `src/shared/Core/Config/ShopUIConfig.luau`
- Modify: `src/shared/Core/Enums/RewardType.luau`
- Modify: `src/server/Core/Services/ConfigValidationService.luau`
- Modify: `src/server/Core/Utilities/RewardDispatcher.luau`
- Modify: `tests/unit/save_system.luau`
- Modify: `tests/unit/mvp005_gameplay.luau`

- [ ] Add failing assertions for `RewardType.Destruction`, portal-only surface
  validation, 29 Robux/amount 3 contract, and Destruction profile mutation.
- [ ] Add `World1TripleReward` with an explicit configuration-required ProductId
  when no real repository ID exists; never invent a positive ID.
- [ ] Dispatch Destruction through the existing Sessions mutation/presentation
  path and preserve Shop-only product validation.
- [ ] Run both focused suites. Expected: reward/config logic PASS; real-ID checks
  remain an explicit blocker if IDs are unavailable.
- [ ] Suggested checkpoint: `fix(mvp-005): complete product reward contracts`.

## Task 14: Complete durable receipt publication and paid portal correlation

**Files:**
- Modify: `src/server/Core/Services/ReceiptProcessingService.luau`
- Modify: `src/server/Game/Services/RewardPortalService.luau`
- Modify: `src/server/Core/Registry/RuntimeRegistry/WorldInstances.luau`
- Modify: `src/server/Game/Services/WorldInstanceService.luau`
- Modify: `src/server/Game/Config/World1Config.luau`
- Modify: `tests/unit/mvp005_gameplay.luau`
- Modify: `tests/studio/mvp005_gameplay.luau`

**Interfaces:**
- Produces: `DeveloperProductCommitted(Player, ProductKey, PurchaseId)` only after
  durable receipt commit and a per-Player paid portal prompt context.

- [ ] Add failing tests for success publication, duplicate receipt suppression,
  mismatched/delayed receipt isolation, prompt cancel/error reset, and free/paid
  portal isolation.
- [ ] Publish the committed event only after reward mutation and durable purchase
  history commit succeed.
- [ ] Store bounded paid-portal prompt context in the owning world/session runtime
  object; clear it on completion, cancellation, leave, and world teardown.
- [ ] Run `lune run tests/unit/mvp005_gameplay.luau`.
  Expected: receipt and portal-state groups PASS except real Marketplace purchase
  evidence.
- [ ] Suggested checkpoint: `fix(mvp-005): correlate paid portal receipts`.

## Task 15: Replace the persistent objective with the three-second popup

**Files:**
- Modify: `src/client/controllers/ObjectiveController.luau`
- Modify: `tests/unit/mvp005_gameplay.luau`
- Modify: `tests/studio/mvp005_gameplay.luau`

- [ ] Add a controller test that records hidden state at 0 seconds, visible state
  through 2.5 seconds, hidden state at 3.0 seconds, and no duplicate timer or
  listener after repeated lifecycle calls.
- [ ] Reuse the existing objective GUI and task scheduler; show once for exactly
  three seconds after the approved trigger, then hide it.
- [ ] Run `lune run tests/unit/mvp005_gameplay.luau`.
  Expected: objective lifecycle group PASS.
- [ ] Suggested checkpoint: `fix(mvp-005): show timed objective popup`.

## Task 16: Add RemoteEvent/lifecycle Equipment tests first

**Files:**
- Modify: `tests/unit/equipment_system.luau`
- Modify: `src/server/Core/Registry/RuntimeRegistry/Sessions.luau`

**Interfaces:**
- Request: `{ RequestId: string, Operation: "GetState" | "Unlock" | "Equip", Payload: unknown }`.
- Response: `{ RequestId: string, Success: boolean, ErrorCode: string, StateSnapshot: EquipmentState? }`.
- Update: validated `EquipmentState` snapshot.
- Client callback: `(Success: boolean, ErrorCode: string, StateSnapshot: EquipmentState?) -> ()`.

- [ ] Add runtime-only Session fields:

```luau
EquipmentRequestInFlight: boolean,
EquipmentLastRequestTimestamp: number,
```

- [ ] Add failing tests for exactly three RemoteEvents (`Request`, `Response`,
  `StateChanged`), request ID/type/length validation, per-Player correlation,
  rate limit/lock release, PlayerRemoving cleanup, duplicate Init/Start, and
  actual SaveService queue calls.
- [ ] Run `lune run tests/unit/equipment_system.luau`.
  Expected: FAIL while RemoteFunctions and module-level request maps remain.
- [ ] Suggested checkpoint: `test(mvp-007): cover equipment event lifecycle`.

## Task 17: Rework EquipmentService to RemoteEvents and lifecycle state

**Files:**
- Modify: `src/server/Game/Services/EquipmentService.luau`
- Modify: `src/server/Game/GameBootstrap.luau`
- Modify: `src/server/Core/Services/SessionService.luau`
- Modify: `src/server/Core/Services/SaveService.luau`
- Test: `tests/unit/equipment_system.luau`
- Test: `tests/unit/save_system.luau`

- [ ] Initialize the two runtime-only Session fields to false/zero.
- [ ] Replace RemoteFunctions with class-validated RemoteEvents named `Request`,
  `Response`, and `StateChanged`; reject conflicting existing instance classes.
- [ ] Validate request tables and bounded RequestIds, dispatch the three
  operations, always release the session lock, and return one correlated response
  to the requesting Player only.
- [ ] Make Init/Start idempotent, retain/disconnect lifecycle connections in the
  service lifecycle boundary, and clear runtime state on session destruction.
- [ ] Keep successful unlock/equip ordering: mutate, sync presentation, queue
  `SaveService:QueueProfileSave(Player)`, respond. Failed/no-op operations do not
  queue redundant saves.
- [ ] Run `lune run tests/unit/equipment_system.luau` and
  `lune run tests/unit/save_system.luau`.
  Expected: lifecycle/remote/save groups PASS, aside from named MVP-005 ID blocker.
- [ ] Suggested checkpoint: `fix(mvp-007): use correlated equipment events`.

## Task 18: Rework EquipmentController request correlation

**Files:**
- Modify: `src/client/controllers/EquipmentController.luau`
- Modify: `src/client/BiggerClientMain.client.luau`
- Test: `tests/unit/equipment_system.luau`

- [ ] Validate incoming snapshots deeply: equipped ID is a known string, unlocked
  IDs are known unique strings, and no `None` entry is accepted.
- [ ] Generate bounded unique RequestIds, retain pending callbacks with a five
  second timeout, ignore duplicate/unknown responses, and clear pending requests
  on controller teardown/re-init.
- [ ] Expose the exact asynchronous APIs below; return `nil, "RemoteNotReady"`
  or `nil, "TooManyPendingRequests"` without sending when unavailable:

```luau
export type ResponseCallback = (boolean, string, EquipmentState?) -> ()

EquipmentController.RequestState(Callback: ResponseCallback): (string?, string?)
EquipmentController.RequestUnlock(UpgradeId: string, Callback: ResponseCallback): (string?, string?)
EquipmentController.RequestEquip(UpgradeId: string?, Callback: ResponseCallback): (string?, string?)
```

- [ ] Bound the pending callback map at 32 entries, cap RequestIds at 64 bytes,
  and never block with `InvokeServer`.
- [ ] Make Init/Start idempotent and keep exactly one response and one state
  connection.
- [ ] Run `lune run tests/unit/equipment_system.luau`.
  Expected: all equipment unit groups PASS.
- [ ] Suggested checkpoint: `fix(mvp-007): correlate client equipment requests`.

## Task 19: Run complete offline gates

**Files:** all changed source, tests, task, plan, and spec paths in exact scope.

- [ ] Run, record exit code/output/warnings, and fix in-scope failures:

```powershell
lune run tests/unit/movement_validation.luau
lune run tests/unit/stomp_validation.luau
lune run tests/unit/save_system.luau
lune run tests/unit/mvp005_gameplay.luau
lune run tests/unit/equipment_system.luau
stylua --check src tests
selene src
rojo build default.project.json -o "$env:TEMP\bigger-mvp005-mvp007-final.rbxl"
git diff --check
git status --short
```

- [ ] Do not report a blocked real Product/Game Pass ID assertion as PASS. Keep
  all unrelated tests running and name the exact remaining blocker.

## Task 20: Mirror local sources to the original Studio place

**Files/Studio objects:**
- Mirror all changed mapped sources.
- Create/verify `ReplicatedStorage.BiggerShared.Game.Config.UpgradesConfig`.
- Create/verify `ServerScriptService.BiggerServer.Game.Services.EquipmentService`.
- Create/verify `StarterPlayer.StarterPlayerScripts.BiggerClient.controllers.EquipmentController`.

- [ ] Confirm Edit Mode, place `Bigger Per Step`, PlaceId `104031194350622`.
- [ ] Create missing source objects before setting source; never edit during play.
- [ ] Compare normalized local/Studio sources and stop runtime QA on any mismatch.
- [ ] Leave no temporary harness or fake Player.

## Task 21: Run two Play Solo verification cycles

- [ ] Cycle 1: validate Level attribute/HUD/progress/avatar boundary behavior,
  MVP-005 fractional growth, AFK/free/paid portal state, objective timing,
  committed Destruction dispatch, and clean output.
- [ ] Cycle 2: validate exactly one equipment remote set, invalid/spoofed requests,
  exact-Level unlock, no auto-equip, equip/unequip multiplier, state sync,
  non-blocking save queue, repeated lifecycle calls, and clean output.
- [ ] Stop play between cycles and confirm Studio returns to Edit Mode.
- [ ] Record exact logs; do not claim real purchase or persistence evidence when
  Studio/API configuration cannot provide it.

## Task 22: Run multiplayer verification

- [ ] Use a real two-Player Studio server/client session if the available Studio
  automation supports it.
- [ ] Verify Level independence, equipment/portal ownership isolation, response
  correlation, independent save queues, pending-request cleanup, and no runtime
  leak after PlayerRemoving.
- [ ] If automation cannot launch/observe two real Players, record
  `MANUAL REQUIRED`; do not claim verified.

## Task 23: Write immutable audit evidence and release decisions

**Files:**
- Create: `docs/superpowers/reports/mvp-003/2026-07-22-mvp-005-audit.md`
- Create: `docs/superpowers/reports/mvp-003/2026-07-22-mvp-007-level-unification-audit.md`
- Create: `docs/superpowers/reports/mvp-003/2026-07-22-mvp-007-equipment-rework-audit.md`
- Modify: `docs/superpowers/reports/mvp-003/README.md`

- [ ] Each report includes `Scope`, `Findings`, `Severity`, `Fixes`,
  `Files Changed`, `Verification`, `Remaining Risks`, and `Release Decision`.
- [ ] Use only `READY`, `READY_FOR_STUDIO_QA`, or `BLOCKED`; missing IDs,
  persistence evidence, multiplayer evidence, Critical/High findings, or parity
  failures prevent `READY`.
- [ ] Run final repository checks:

```powershell
git diff --stat
git diff --name-status
git diff --check
git status --short --branch
```

- [ ] Record suggested commits in the final report; do not stage, commit, or push.

## Task 24: Unblock non-monetization runtime systems

**Files:**
- Modify: `tasks/MVP-005.md`
- Modify: `tasks/MVP-007.md`
- Modify: `docs/superpowers/plans/2026-07-18-mvp-005-gameplay-loop.md`
- Modify: `docs/superpowers/plans/2026-07-21-mvp-007-equipment-system.md`
- Modify: `src/server/Core/Services/GamePassService.luau`
- Modify: `src/server/Core/Services/ConfigValidationService.luau`
- Modify: `src/server/Core/Services/ReceiptProcessingService.luau`
- Modify: `src/server/Game/Services/RewardPortalService.luau`
- Modify: `src/client/controllers/GuiController.luau`
- Modify: `src/client/controllers/ObjectiveController.luau`
- Modify: `tests/unit/mvp005_gameplay.luau`

**Interfaces:**
- `GamePassService:GetConfigurationStatus(PassKey): ConfigurationStatus`
- `ConfigValidationService:GetDeveloperProductStatus(ProductKey): ConfigurationStatus`
- `GuiController.GetStatus(): "Ready" | "HUDUnavailable"`
- `ObjectiveController.GetStatus(): "Ready" | "PlayerGuiUnavailable"`

- [ ] Write and run focused RED tests for missing-ID boot isolation, fail-closed
  operations, warning-once behavior, and valid-ID compatibility.
- [ ] Implement structured status inside the two existing validation owners;
  preserve fatal structural/reward validation.
- [ ] Make receipts ignore unconfigured Product IDs and make paid portal
  presentation/request remain unavailable without affecting free rewards.
- [ ] Write and run focused RED tests for missing/late/reset HUD lifecycle.
- [ ] Implement bounded canonical resolution and owned connection cleanup without
  creating a fallback HUD or changing Level authority.

## Task 25: Verify runtime unblock and write new immutable audits

**Files:**
- Create: `docs/superpowers/reports/mvp-003/2026-07-22-mvp-005-runtime-unblock-audit.md`
- Create: `docs/superpowers/reports/mvp-003/2026-07-22-mvp-007-level-runtime-audit.md`
- Create: `docs/superpowers/reports/mvp-003/2026-07-22-mvp-007-equipment-runtime-audit.md`
- Modify: `docs/superpowers/reports/mvp-003/README.md`

- [ ] Run all five Lune suites, StyLua, Selene, Rojo build, and
  `git diff --check`.
- [ ] Verify the original place and normalized parity for every changed source.
- [ ] Run two Play Solo cycles and record session attributes, canonical Level,
  one equipment remote set, HUD status, and fail-closed monetization warnings.
- [ ] Run valid two-player automation if available; otherwise record
  `MANUAL REQUIRED`.
- [ ] Preserve earlier immutable audits and record separate release decisions.
