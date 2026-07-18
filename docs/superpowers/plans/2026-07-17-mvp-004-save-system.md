# MVP-004 Native DataStore Save System Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Persist authoritative Bigger player sessions safely with native Roblox DataStores, serialized per-player writes, atomic offline growth, and durable receipt idempotency.

**Architecture:** `PlayerProfileSchema` owns pure validation and transforms; `RuntimeRegistry.Profiles` owns one FIFO worker per UserId; `SaveService` is the only DataStore caller and snapshots authoritative sessions. Game Pass monetization is outside this milestone.

**Tech Stack:** Roblox DataStoreService, UpdateAsync, typed Luau, Lune 0.10.5, Rojo 7.4.4, StyLua 2.0.2, Selene 0.27.1, Git.

## Global Constraints

```text
MVP004_SAVE_SYSTEM: READY
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

---

## 2026-07-18 Review Fix Addendum

**Goal:** Close the actionable PR #2 review findings without expanding MVP-004 beyond the native save system.

**Architecture:** Startup validation enforces one reward per Developer Product, so receipt processing never needs multi-reward rollback. Existing `Profiles` entry identity is the load-generation boundary; `SaveService` verifies its exact entry/token and `SessionService` adds one tokenized in-flight join guard before installing a session or spawning.

**Tech Stack:** Typed Luau, Lune, Roblox native services, StyLua, Selene, Rojo, GitHub review threads.

### Global Constraints

- Preserve the three public `SaveService` signatures.
- Do not add multi-reward transaction orchestration, Game Pass work, dependencies, remotes, or production publication.
- Use the existing `Profiles.Remove(UserId, ExpectedEntry)` identity guard for cleanup.
- Write and observe focused failing tests before production edits.
- Keep all changes within the existing MVP-004 exact path list.

### Task 8: Enforce One Reward Per Developer Product

**Files:**
- Modify: `tests/unit/save_system.luau`
- Modify: `src/server/Core/Services/ConfigValidationService.luau`
- Modify: `src/server/Core/Services/GrowthService.luau`
- Modify: `src/server/Core/Utilities/RewardDispatcher.luau`

**Interfaces:**
- `ConfigValidationService:Init()` accepts only `#serverConfig.Rewards == 1`.
- `GrowthService:AddBiggerAbsolute(Player, Amount): boolean` reports whether the persistent value was applied, even if later presentation work raises.
- `RewardDispatcher.Dispatch(Player, Rewards)` relies on one validated reward and never reports failure after that reward's persistent mutation succeeds.

- [ ] **Step 1: Add failing configuration tests**

Add a `loadConfigValidationService(Rewards)` Lune harness with injected `DeveloperProductConfig`, matching `ShopUIConfig`, `RewardType`, and a no-op logger. Assert:

```luau
assert(pcall(function()
	loadConfigValidationService({ { Type = "Bigger", Amount = 10 } }):Init()
end) == true)

expectError(function()
	loadConfigValidationService({}):Init()
end)
expectError(function()
	loadConfigValidationService({
		{ Type = "Bigger", Amount = 10 },
		{ Type = "Bigger", Amount = 20 },
	}):Init()
end)
```

Model boot fail-closed by incrementing a receipt-registration counter only after `ConfigValidationService:Init()` returns; assert the counter remains zero for zero and two rewards. Also assert `CoreBootstrap` orders `ConfigValidationService` before `ReceiptProcessingService`.

- [ ] **Step 2: Verify RED**

Run: `lune run tests/unit/save_system.luau`

Expected: FAIL because two rewards currently pass configuration validation.

- [ ] **Step 3: Enforce exact cardinality**

Replace the non-empty check with:

```luau
local rewards = serverConfig.Rewards
if typeof(rewards) ~= "table" or #rewards ~= 1 then
	error(
		"ConfigValidation: ProductKey "
			.. productKey
			.. " must contain exactly one reward. Got: "
			.. tostring(if typeof(rewards) == "table" then #rewards else nil)
	)
end
```

- [ ] **Step 4: Add the post-mutation failure regression**

Load `RewardDispatcher` with a fake GrowthService whose `AddBiggerAbsolute` changes `Session.Bigger` and then raises during presentation. Assert dispatch succeeds once after observing the changed authoritative value. Keep entitlement presentation calls inside non-failing `pcall` blocks after `Sessions.Mutate` succeeds.

- [ ] **Step 5: Make the single Bigger handler truthful**

Change `GrowthService:AddBiggerAbsolute` to return `true` when `SetBigger` returns true or the target Bigger value is already present after a presentation error; otherwise return false. The dispatcher must resolve GrowthService before mutation and return success once the authoritative Bigger value changed.

- [ ] **Step 6: Verify GREEN**

Run separately:

```powershell
lune run tests/unit/save_system.luau
stylua --check src/server/Core/Services/ConfigValidationService.luau src/server/Core/Services/GrowthService.luau src/server/Core/Utilities/RewardDispatcher.luau tests/unit/save_system.luau
selene src/server/Core/Services/ConfigValidationService.luau src/server/Core/Services/GrowthService.luau src/server/Core/Utilities/RewardDispatcher.luau
git diff --check
```

Expected: save-system PASS and all quality commands exit 0.

### Task 9: Bind Load Completion to the Current Entry

**Files:**
- Modify: `tests/unit/save_system.luau`
- Modify: `src/server/Core/Services/SaveService.luau`
- Modify: `src/server/Core/Services/SessionService.luau`

**Interfaces:**
- `Profiles.Create` remains the single admission point and rejects every existing phase.
- `SaveService:LoadProfile(Player)` returns only when its captured entry object and captured owner token are still current.
- `SessionService` owns a per-Player opaque in-flight token; only that token may clear the guard or install a session.

- [ ] **Step 1: Add failing registry and stale-load tests**

Extend the fake DataStore with `AfterUpdate`. Cover these cases:

```luau
-- Existing Loading, Active, and Releasing entries reject replacement.
expectError(function()
	Profiles.Create(UserId, "second-owner", Probe)
end)

-- AfterUpdate replaces the old entry before LoadProfile returns.
Store.AfterUpdate = function()
	Profiles.Remove(UserId, OldEntry)
	Replacement = Profiles.Create(UserId, "replacement-owner", Probe)
end
assert(pcall(SaveService.LoadProfile, SaveService, Player) == false)
assert(Profiles.Get(UserId) == Replacement)
```

Add a failure variant where the stale request errors after replacement and assert identity-checked cleanup leaves `Replacement` registered. Add an owner-token mutation variant and assert the load cannot complete.

- [ ] **Step 2: Add failing concurrent SessionService tests**

Block the fake first `LoadProfile`, invoke the same PlayerAdded callback twice, and assert the second returns without a second load. Release the first and assert one Session and one `LoadCharacter()` call. Repeat with the player disconnected before release; assert the acquired current profile is finalized, no session-created event is published, and `LoadCharacter()` is never called.

- [ ] **Step 3: Verify RED**

Run: `lune run tests/unit/save_system.luau`

Expected: FAIL because stale success is accepted and duplicate callbacks reach `LoadProfile`.

- [ ] **Step 4: Guard SaveService load identity**

Capture `ExpectedOwnerToken = RuntimeProfile.OwnerToken`. Use one local predicate:

```luau
local function IsCurrentLoad(): boolean
	return Profiles.Get(Player.UserId) == RuntimeProfile
		and RuntimeProfile.OwnerToken == ExpectedOwnerToken
end
```

Reject before each acquire transform and after `Profiles.Await` unless the predicate is true and `RuntimeProfile.Phase == "Active"`. Do not remove a mismatched current entry.

- [ ] **Step 5: Guard SessionService join completion**

Use `LoadingPlayers: { [Player]: {} }`. Each callback stores a fresh token, duplicate callbacks return, and cleanup clears the map only when the stored token still matches. After load, capture the current runtime entry and owner token, build the Session, then recheck entry identity, token, phase, and in-flight token immediately before `Sessions.Set`.

If the current Player is no longer parented to `Players`, install only the current authoritative Session needed by the existing release path, call `FinalizePlayer`, and return before attributes, events, leaderstats, or character spawning.

- [ ] **Step 6: Verify GREEN**

Run separately:

```powershell
lune run tests/unit/save_system.luau
stylua --check src/server/Core/Services/SaveService.luau src/server/Core/Services/SessionService.luau tests/unit/save_system.luau
selene src/server/Core/Services/SaveService.luau src/server/Core/Services/SessionService.luau
git diff --check
```

Expected: all concurrency, stale callback, owner-token, session-count, and spawn-count assertions pass.

### Task 10: Close Review Documentation and Test Stability Findings

**Files:**
- Modify: `tests/unit/save_system.luau`
- Modify: `docs/CHANGELOG.md`
- Modify: `docs/superpowers/reports/mvp-003/2026-07-17-mvp-004-audit.md`
- Modify: `tasks/MVP-003.md`

- [ ] **Step 1: Replace fixed test sleeps**

Add one bounded helper using `os.clock()` and replace the four `task.wait(0.05)` assertions identified by review:

```luau
local function waitUntil(Predicate, Message)
	local Deadline = os.clock() + 1
	while not Predicate() and os.clock() < Deadline do
		task.wait()
	end
	assert(Predicate(), Message)
end
```

- [ ] **Step 2: Align documentation**

- Change “full-tree StyLua” to “StyLua checks for `src` and `tests`”.
- Give the July 18 decision its own `## 2026-07-18 Scope Addendum` heading in the existing audit report.
- Remove Game Pass ownership, GamePass source paths, private-staging QA, and blocked monetization status from the MVP-004 audit cycle in `tasks/MVP-003.md`; replace the decision with the final two-line save-system/deferred status.

- [ ] **Step 3: Run the focused suite and inspect the complete diff**

```powershell
lune run tests/unit/save_system.luau
git diff --check
git diff 5367ecd478a3c9eaf195cc84eae2792b5ef996a7...HEAD
git status --short
```

- [ ] **Step 4: Commit focused fixes**

```powershell
git add src/server/Core/Services/ConfigValidationService.luau src/server/Core/Services/GrowthService.luau src/server/Core/Services/SaveService.luau src/server/Core/Services/SessionService.luau src/server/Core/Utilities/RewardDispatcher.luau tests/unit/save_system.luau docs/CHANGELOG.md docs/superpowers/reports/mvp-003/2026-07-17-mvp-004-audit.md tasks/MVP-003.md
git commit -m "fix(mvp-004): close save system review findings"
```

### Task 11: Verify, Push, Resolve, and Re-enter the Merge Gate

- [ ] **Step 1: Run every pre-merge command separately**

Run the exact checkout/pull, three Lune suites, StyLua, Selene, Rojo premerge build, `git diff --check`, and `git status --short` commands from the approved merge brief. Require a clean tree and unchanged reviewed head after commit.

- [ ] **Step 2: Mirror changed source and smoke in Studio**

In Edit mode, mirror only changed source modules, verify normalized parity, and run a Play Solo boot/config smoke. Do not add a temporary harness, run Game Pass QA, or publish production.

- [ ] **Step 3: Push and update review threads**

Push `feat/mvp-004-data-store`, reply with the technical resolution and verification evidence in each relevant inline thread, resolve addressed threads, and explain any rejected suggestion in its own thread.

- [ ] **Step 4: Re-read the full PR and live gate state**

Confirm the new head, changed files, patch, comments, reviews, unresolved threads, status checks, protection requirements, and mergeability. Stop if any actionable thread, check, approval, scope, or head mismatch remains.

- [ ] **Step 5: Merge and verify main only if every gate passes**

Use a normal merge commit with the verified head SHA as `expected_head_sha`. Fetch, check out `main`, fast-forward pull, verify the merge on `origin/main`, verify the reviewed head is reachable, and leave the feature branch intact.
