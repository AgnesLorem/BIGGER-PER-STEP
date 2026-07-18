# MVP-004 Native DataStore Save System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist authoritative Bigger player sessions safely with native Roblox DataStores, serialized per-player writes, atomic offline growth, and durable receipt idempotency.

**Architecture:** `PlayerProfileSchema` owns pure validation and transforms; `RuntimeRegistry.Profiles` owns one FIFO worker per UserId; `SaveService` is the only DataStore caller and snapshots authoritative sessions. Game Pass monetization is outside this milestone.

**Tech Stack:** Roblox DataStoreService, UpdateAsync, typed Luau, Lune 0.10.5, Rojo 7.4.4, StyLua 2.0.2, Selene 0.27.1, Git.

## Global Constraints

```text
MVP004_SAVE_SYSTEM: READY FOR REVIEW
GAME_PASS_MONETIZATION: DEFERRED TO A FUTURE MVP
```

- Work only on `feat/mvp-004-data-store`, created from verified `origin/main` after MVP-003 merge commit `5367ecd`.
- Preserve the three existing public `SaveService` signatures.
- Use native Roblox services; add no persistence dependency, HTTP access, remote, client authority, or production publication.
- Keep `Sessions` as the only mutable gameplay source of truth.
- Store at most 5,000 processed IDs; admit receipts only while durable plus runtime-pending is at most 5,000.
- Never store `PendingPurchaseIds` as a profile field.
- Keep forward-compatible entitlement booleans, but do not create Game Pass config or implementation with fake external values.
- Use TDD: write and run a failing test before each production behavior.
- Stop before editing any path outside the approved scope.
- Push only `feat/mvp-004-data-store`; never force-push or push directly to `main`.

Exact persistence limits:

```text
Maximum unlocked Growth Upgrades: 64
Maximum completed portals: 256
Maximum stored processed receipts: 5,000
Maximum durable-plus-pending receipts at runtime: 5,000
Maximum content ID length: 64
Maximum PurchaseId length: 128
Maximum safe integer: 9007199254740991
```

The store is `BiggerPlayerProfiles_v1`, the key is `Player_<UserId>`, Production/Studio scopes are `Production`/`Studio`, production PlaceId is `104031194350622`, and the `Staging` mapping remains absent until its real PlaceId exists.

---

### Task 1: Pure Profile Schema and Environment Resolution

**Files:**
- Create: `tests/unit/save_system.luau`
- Create: `src/server/Core/Utilities/PlayerProfileSchema.luau`
- Create: `src/server/Core/Config/SaveConfig.luau`

**Interfaces:**
- Produces pure schema defaults, normalization, validation, acquire/save/release transforms, offline calculation, and scope/key resolution.
- Produces `SaveConfig.ResolveScope(IsStudio:boolean, PlaceId:number): string`.
- Produces `SaveConfig.ProfileKey(UserId:number): string`.

- [ ] **Step 1: Write failing schema and environment tests**

Add assertions for defaults, unversioned migration, invalid scalar/table, future schema, NaN, infinity, unsafe integer, exact 64/65 upgrade keys, exact 256/257 portal keys, 64/65-character content IDs, 128/129-character PurchaseIds, 5,000/5,001 stored IDs, equipped-not-unlocked rejection, unknown field removal, production/Studio scope, unknown live PlaceId rejection, and `Player_<UserId>`.

- [ ] **Step 2: Verify RED**

Run: `lune run tests/unit/save_system.luau`

Expected: FAIL because `PlayerProfileSchema` and `SaveConfig` do not exist.

- [ ] **Step 3: Implement the pure modules**

Implement exactly the schema, limits, ID patterns, safe-number rules, environment rules, timestamps, and new/timestamp-less zero-offline behavior from the design. Leave the staging mapping absent rather than inserting a temporary value.

- [ ] **Step 4: Verify GREEN and task gates**

```powershell
lune run tests/unit/save_system.luau
stylua --check src/server/Core/Config/SaveConfig.luau src/server/Core/Utilities/PlayerProfileSchema.luau tests/unit/save_system.luau
selene src/server/Core/Config/SaveConfig.luau src/server/Core/Utilities/PlayerProfileSchema.luau
rojo build default.project.json -o "$env:TEMP\bigger-mvp004-task.rbxl"
git diff --check
```

Expected: test prints `save_system: PASS`; all commands exit 0.

- [ ] **Step 5: Commit and push**

```powershell
git add src/server/Core/Config/SaveConfig.luau src/server/Core/Utilities/PlayerProfileSchema.luau tests/unit/save_system.luau
git commit -m "feat(mvp-004): define player profile schema"
git push origin feat/mvp-004-data-store
```

---

### Task 2: UserId-Keyed FIFO Runtime

**Files:**
- Modify: `tests/unit/save_system.luau`
- Create: `src/server/Core/Registry/RuntimeRegistry/Profiles.luau`

**Interfaces:**
- Produces UserId-keyed entries with `Phase`, `OwnerToken`, `LeaseExpiresAt`, `EntitlementProbe`, `WriteQueue`, `Worker`, `PendingPurchaseIds`, `Released`, and `LastError`.
- Produces queue operations that serialize callbacks and expose completion without Signal or BindableEvent.

- [ ] **Step 1: Write failing FIFO tests**

Cover load as first request, no overlapping work for one UserId, concurrent work for two UserIds, autosave coalescing, receipt non-coalescing, final ordering, failure completion, release termination, and same-UserId duplicate-entry rejection.

- [ ] **Step 2: Verify RED**

Run: `lune run tests/unit/save_system.luau`

Expected: FAIL because `Profiles` does not exist.

- [ ] **Step 3: Implement the minimal registry worker**

Use one queue table and worker coroutine per UserId. Use callbacks/coroutine resumption for completion. Keep DataStore calls out of this module; queued callbacks are supplied by `SaveService`.

- [ ] **Step 4: Verify GREEN and gates**

Run the unit test, scoped StyLua/Selene, Rojo build, and `git diff --check`; all must exit 0.

- [ ] **Step 5: Commit and push**

```powershell
git add src/server/Core/Registry/RuntimeRegistry/Profiles.luau tests/unit/save_system.luau
git commit -m "feat(mvp-004): serialize datastore writes"
git push origin feat/mvp-004-data-store
```

---

### Task 3: Authoritative Load and Save Lifecycle

**Files:**
- Modify: `tests/unit/save_system.luau`
- Modify: `src/server/Core/Services/SaveService.luau`
- Modify: `src/server/Core/Services/SessionService.luau`
- Modify: `src/server/Core/Registry/RuntimeRegistry/Sessions.luau`
- Modify: `src/server/Core/Bootstrap/CoreBootstrap.luau`

**Interfaces:**
- Preserves `LoadProfile`, `SaveProfile`, and `CommitTransaction` signatures.
- Adds `IsProfileWritable`, `FreezeMutations`, and `ReleaseProfile`.

- [ ] **Step 1: Write failing lifecycle tests**

Cover store identity, UpdateAsync-only writes, load/acquire first, lock acquire/renew/release, active/expired foreign locks, wrong-owner save/release, `1, 2, 4, 8` load delays, `1, 2, 4` write delays, controlled load error, failed-load worker cleanup, synchronous save completion, final release ordering, and idempotent release.

- [ ] **Step 2: Verify RED**

Run the unit test and confirm failure because the SaveService remains a RAM stub.

- [ ] **Step 3: Implement DataStore lifecycle**

Make `SaveService` the only DataStore caller. Resolve the environment before `SessionService:Init`, queue load/acquire through `Profiles`, snapshot sessions at worker execution, and use `pcall` in `SessionService`. On load failure remove temporary runtime state and remove the player without a session. On PlayerRemoving freeze first, queue final release, wait, and remove `Sessions` only after normal final handling.

- [ ] **Step 4: Verify GREEN and gates**

Run focused unit tests, scoped StyLua/Selene, Rojo build, and `git diff --check`; all must exit 0.

- [ ] **Step 5: Commit and push**

```powershell
git add src/server/Core/Services/SaveService.luau src/server/Core/Services/SessionService.luau src/server/Core/Registry/RuntimeRegistry/Sessions.luau src/server/Core/Bootstrap/CoreBootstrap.luau tests/unit/save_system.luau
git commit -m "feat(mvp-004): load authoritative player profiles"
git push origin feat/mvp-004-data-store
```

---

### Task 4: Mutation Freeze and Shutdown

**Files:**
- Modify: `tests/unit/save_system.luau`
- Modify: `src/server/Core/Services/GrowthService.luau`
- Modify: `src/server/Core/Services/RewardService.luau`
- Modify: `src/server/Game/Services/DestructionService.luau`
- Modify: `src/server/Core/Services/SaveService.luau`
- Modify: `src/server/Core/Services/SessionService.luau`

- [ ] **Step 1: Write failing freeze/shutdown tests**

Freeze a complete session, attempt Bigger, Destruction, Rebirth, upgrades, portals, settings, entitlement, and purchase-history mutations, and assert the full persistent snapshot remains identical. Test concurrent cross-player shutdown, one blocked worker, the 25-second deadline, unresolved diagnostics, no direct write, and repeated release.

- [ ] **Step 2: Verify RED**

Run the unit test and confirm existing mutation paths still change frozen state.

- [ ] **Step 3: Implement fail-closed boundaries**

Set `ProfileMutationsFrozen` before final capture and guard every scoped direct mutation. Implement one global shutdown deadline while preserving each player's FIFO.

- [ ] **Step 4: Verify GREEN and gates**

Run focused tests and the standard per-task quality commands; all must exit 0.

- [ ] **Step 5: Commit and push**

```powershell
git add src/server/Core/Services/GrowthService.luau src/server/Core/Services/RewardService.luau src/server/Game/Services/DestructionService.luau src/server/Core/Services/SaveService.luau src/server/Core/Services/SessionService.luau tests/unit/save_system.luau
git commit -m "fix(mvp-004): freeze profile mutations during release"
git push origin feat/mvp-004-data-store
```

---

### Task 5: Atomic Offline Progression

**Files:**
- Modify: `tests/unit/save_system.luau`
- Modify: `src/server/Core/Utilities/PlayerProfileSchema.luau`
- Modify: `src/server/Core/Services/SaveService.luau`

- [ ] **Step 1: Write failing offline tests**

Cover new profile zero, timestamp-less legacy zero, 1x/2x/4x, future time, negative duration, fractional-minute flooring, eight-hour cap, maximum rewards 14,400 and 57,600, overflow rejection, atomic timestamps, crash/reconnect claim once, and no logout mutation during normal writes.

- [ ] **Step 2: Verify RED**

Run the unit test and confirm offline rewards are not yet applied atomically.

- [ ] **Step 3: Implement the acquire transform**

Use `os.time()`, calculate and validate the reward inside the load/acquire transform, and persist the claim with the lease and timestamps in the same `UpdateAsync`.

- [ ] **Step 4: Verify GREEN and gates**

Run focused tests and standard per-task gates; all must exit 0.

- [ ] **Step 5: Commit and push**

```powershell
git add src/server/Core/Utilities/PlayerProfileSchema.luau src/server/Core/Services/SaveService.luau tests/unit/save_system.luau
git commit -m "feat(mvp-004): add atomic offline progression"
git push origin feat/mvp-004-data-store
```

---

### Task 6: Durable Developer Product Receipts

**Files:**
- Modify: `tests/unit/save_system.luau`
- Modify: `src/server/Core/Services/ReceiptProcessingService.luau`
- Modify: `src/server/Core/Services/RewardService.luau`
- Modify: `src/server/Core/Services/SaveService.luau`

- [ ] **Step 1: Write failing receipt tests**

Cover new, pending, durable duplicate, dispatch failure, DataStore failure, ambiguous commit result, reconnect, multiple pending IDs in one snapshot, pending ID added after capture, all included waiters, unchanged `CommitTransaction` argument shape, no reward reapply, exact 5,000 stored validation, 4,999 durable plus one pending admission, capacity rejection, and no pruning.

- [ ] **Step 2: Verify RED**

Run the unit test and confirm current receipt flow marks IDs durable before a real write.

- [ ] **Step 3: Implement pending/durable flow**

Keep runtime pending IDs in `Profiles` only. Make `ReceiptProcessingService` own new-receipt dispatch and `CommitTransaction` own only validation and durability. Promote exact included IDs after success and resolve every included waiter.

- [ ] **Step 4: Verify GREEN and gates**

Run focused tests and standard per-task gates; all must exit 0.

- [ ] **Step 5: Commit and push**

```powershell
git add src/server/Core/Services/ReceiptProcessingService.luau src/server/Core/Services/RewardService.luau src/server/Core/Services/SaveService.luau tests/unit/save_system.luau
git commit -m "fix(mvp-004): make receipts durably idempotent"
git push origin feat/mvp-004-data-store
```

---

### Task 7: Studio Harness and Documentation

**Files:**
- Create: `tests/studio/save_system.luau`
- Modify: `docs/SAVE.md`
- Modify: `docs/TASKS.md`
- Modify: `docs/CHANGELOG.md`
- Modify: `docs/examples/PlayerProfileExample.md`
- Modify: `docs/superpowers/reports/mvp-003/README.md`
- Modify: `docs/superpowers/reports/mvp-003/2026-07-17-mvp-004-audit.md`

- [ ] **Step 1: Write the Studio verification harness**

Use only real Players and the Studio DataStore scope. Cover defaults, autosave, final save, restoration, offline claim once, mutation freeze, and clean Output. The harness is temporary runtime test code and is never registered in production.

- [ ] **Step 2: Run the final offline gate**

```powershell
lune run tests/unit/movement_validation.luau
lune run tests/unit/stomp_validation.luau
lune run tests/unit/save_system.luau
stylua --check src tests
selene src
rojo build default.project.json -o "$env:TEMP\bigger-mvp004-final.rbxl"
git diff --check
git status --short
```

Expected: all commands exit 0; status contains only intended Task 7 paths before commit.

- [ ] **Step 3: Mirror and verify Studio source**

In Edit mode, mirror every changed local source into its original Studio object, normalize and compare byte-for-byte, and stop on parity difference. Mirror the harness to temporary `ServerStorage.MVP004Tests.SaveSystem`, verify parity, run five Play Solo sessions with a real Player, record Output, stop play, and remove the temporary object.

- [ ] **Step 4: Record evidence and commit**

Record exact commands, results, commits, parity evidence, Studio runs, deferred future work, and the save-system release decision.

```powershell
git add tests/studio/save_system.luau docs/SAVE.md docs/TASKS.md docs/CHANGELOG.md docs/examples/PlayerProfileExample.md docs/superpowers/reports/mvp-003/README.md docs/superpowers/reports/mvp-003/2026-07-17-mvp-004-audit.md
git commit -m "docs(mvp-004): record persistence verification"
git push origin feat/mvp-004-data-store
```

---

### Deferred Future MVP: Game Pass Monetization

This is not an MVP-004 task or completion gate. A separate approved milestone may begin only after the real private staging PlaceId, authorized thumbnail source, 2X Game Pass Asset ID, and VIP Game Pass Asset ID are recorded. No file or section may be created with a temporary value.

After the gate clears, use TDD for ownership true/false/error, successful-false revocation, post-prompt immediate plus `1, 2, 4` re-query, verified-only grant, 2x/4x, VIP presentation, configuration mismatches, and forced durable save. Commit as:

```text
feat(monetization): persist verified game pass ownership
```

Publish and test only the private staging place. Never publish the original production place.
