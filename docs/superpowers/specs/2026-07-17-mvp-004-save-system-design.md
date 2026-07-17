# MVP-004 Native DataStore Save System Design

## Status and Boundaries

```text
PLANNING: APPROVED
SOURCE: APPROVED WITHIN EXACT SCOPE
MONETIZATION: BLOCKED PENDING PRIVATE STAGING PLACE,
AUTHORIZED THUMBNAILS, AND REAL GAME PASS ASSET IDS
```

MVP-004 uses Roblox native `DataStoreService` and `UpdateAsync`. It adds no dependency, HTTP capability, remote, client authority, or production publication. Server sessions remain the sole mutable gameplay source of truth.

MVP-003 was merged through PR #1 as merge commit `5367ecd`. Future merge gates accept normal ancestry or equivalent squash/rebase evidence proven through PR history, changed paths, tests, documentation, and audit records.

## Components

- `SaveConfig`: pure constants and environment resolution. Studio resolves first; production PlaceId `104031194350622` resolves to `Production`; unknown live places fail boot. The staging mapping is absent until a real approved PlaceId exists.
- `PlayerProfileSchema`: pure defaults, legacy normalization, validation, lock/save/release transforms, timestamp rules, and offline reward math. It performs no DataStore call and owns no Roblox lifecycle.
- `RuntimeRegistry.Profiles`: UserId-keyed runtime entries and one FIFO worker per profile key. It owns queue order, pending receipt IDs, request completion, and release state.
- `SaveService`: the only DataStore caller. It converts sessions into normalized snapshots and preserves its existing public signatures.
- `SessionService`: coordinates load failure, session creation, PlayerRemoving freeze/release, and removal after final handling.
- `ReceiptProcessingService`: validates receipts, controls pending/durable admission, dispatches each new reward once, and returns `PurchaseGranted` only after durability.
- Existing mutation services: reject changes after freeze.
- Game Pass config, prompting, ownership queries, and staging QA remain externally blocked and receive no placeholder implementation.

## Data Identity and Schema

The store is `BiggerPlayerProfiles_v1`, scoped to `Production`, `Staging`, or `Studio`, with key `Player_<UserId>`. Studio cannot resolve production. Production PlaceId is `104031194350622`; the staging mapping is added only with the real staging PlaceId.

Schema v1 fields and defaults are:

```luau
{
	SchemaVersion = 1,
	Bigger = 1,
	Destruction = 0,
	Rebirth = 0,
	UnlockedGrowthUpgrades = {},
	EquippedGrowthUpgrade = nil,
	CompletedPortals = {},
	Settings = { SoundEnabled = true, MusicEnabled = true },
	HasDoubleMultiplier = false,
	HasVip = false,
	ProcessedPurchaseIds = {},
	LastActiveTimestamp = 0,
	LastLogoutTimestamp = 0,
	LastSaveTimestamp = 0,
	LeaseOwner = nil,
	LeaseExpiresAt = nil,
}
```

Optional nil fields are omitted. `Bigger` remains the compatibility name. Collections are dictionaries of validated ID to `true`.

Validation limits are 64 unlocked Growth Upgrades, 256 completed portals, 5,000 stored processed receipts, 5,000 combined durable-plus-runtime-pending receipts, 64 characters per content ID, 128 characters per PurchaseId, and `9007199254740991` as the maximum safe integer.

Stored profile validation counts only `ProcessedPurchaseIds`. Runtime receipt admission separately counts durable plus `PendingPurchaseIds`. Pending IDs never enter the schema as their own field; they become stored only when promoted into `ProcessedPurchaseIds` by a successful write.

Content IDs match `[A-Za-z0-9_-]+`; Purchase IDs match `[A-Za-z0-9_.:-]+`. `Bigger` is an integer from 1 through the safe maximum; Destruction, Rebirth, and timestamps are integers from 0 through it. An equipped upgrade must be unlocked. Settings accept only the two schema-v1 boolean keys.

Known invalid stored fields abort the transform so the record is not overwritten. Missing valid fields receive defaults. Unknown legacy fields are discarded. New profiles and timestamp-less legacy profiles receive zero initial offline reward.

## Load and Write Flow

1. Resolve the environment before player listeners are registered.
2. Create a temporary UserId-keyed profile entry in `Loading` and start its worker.
3. Queue load/acquire as request one.
4. Call `UpdateAsync` through the worker, normalize the stored record, reject future or malformed data, reject an unexpired foreign lock, calculate offline reward, acquire the lease, and persist claimed timestamps atomically.
5. Change phase to `Active` and return the normalized profile.
6. `SessionService` copies it into a session and exposes only presentation attributes.
7. On load failure, terminate the worker, delete the temporary entry, remove temporary runtime state, and remove the player without creating a session.

Every later write uses the same worker. At most one write runs per UserId. Autosaves may coalesce; receipt and release requests may not. A request captures its authoritative snapshot and exact included pending IDs immediately before its first DataStore call.

Autosave occurs every 60 seconds. Lease duration is 180 seconds. Foreign-lock load delays are `1, 2, 4, 8`; write retry delays are `1, 2, 4`. An unexpired foreign lock is never stolen. Wrong ownership freezes mutations and removes the player.

## Public SaveService Contract

Preserve exactly:

```luau
function SaveService:LoadProfile(Player: Player): Profile
function SaveService:SaveProfile(Player: Player)
function SaveService:CommitTransaction(
	Player: Player,
	TransactionData: { PurchaseId: string, Rewards: { [any]: any } }
): boolean
```

Add only `IsProfileWritable`, `FreezeMutations`, and `ReleaseProfile`. `LoadProfile` raises a controlled error after exhausted retries, `SaveProfile` synchronously waits while preserving no return value, and `CommitTransaction` validates but never reapplies rewards and returns true only after durability.

## Timestamps and Offline Reward

Use server `os.time()` integer timestamps. Atomic acquire calculates:

```text
OfflineSeconds = clamp(Now - max(LastActiveTimestamp, LastLogoutTimestamp), 0, 28800)
OfflineReward = floor(OfflineSeconds / 60 × 30 × GrowthMultiplier)
```

New records and legacy records lacking both timestamps use `Now` as their baseline and receive zero. Load writes the reward, lease, `LastActiveTimestamp = Now`, and `LastSaveTimestamp = Now` together. Normal writes do not change logout. Final release writes all three timestamps as `Now` and clears the lease. Numeric validation rejects overflow before any transform returns data.

## Mutation and Release Safety

`Session.ProfileMutationsFrozen` is set before final snapshot capture, shutdown, permanent release, or ownership-loss handling and never clears. Growth, Destruction, reward, receipt, entitlement, and any other direct profile mutation fail closed while frozen.

Successful release is ordered after earlier requests, atomically clears the lease, marks the runtime entry `Released`, resolves the caller, and terminates the worker. A failed final release stays frozen in `Releasing`; a same-UserId join is rejected while it remains unreleased. Shutdown freezes all profiles, starts one final request per player concurrently across players, preserves each FIFO, and waits no more than 25 seconds. Timeout diagnostics contain UserId, phase, queue length, and last error; no direct replacement write is allowed.

## Receipt Safety

`Session.PurchaseHistory` contains durable IDs only. `Profiles.PendingPurchaseIds` contains runtime-only IDs dispatched but not yet confirmed durable.

Receipt processing validates player, product, writable state, PurchaseId, and combined capacity. Durable duplicates return success. Pending duplicates retry persistence only. A new ID is marked pending before the single in-memory dispatch. Dispatch failure removes pending. `CommitTransaction` validates its unchanged arguments, does not apply `Rewards`, and queues the current session snapshot plus exact included pending IDs.

After success, only included IDs are promoted and all included waiting receipt calls resolve. Ambiguous DataStore errors retain the pending in-memory reward and return `NotProcessedYet`; retry does not redispatch. A new server either sees the durable ID or legitimately dispatches the uncommitted receipt once. Receipt IDs are never pruned, expired, evicted, or reused in schema v1.

Stored validation permits at most 5,000 `ProcessedPurchaseIds`. Runtime admission separately permits at most 5,000 durable plus pending IDs. A receipt at capacity is not dispatched and returns `NotProcessedYet`, while a durable duplicate still returns success.

## Monetization Boundary

The current entitlement prototypes remain unchanged until external prerequisites exist. Non-monetization persistence may store and restore existing boolean entitlement values, but no Game Pass ID, staging mapping, purchase prompt, ownership query, or Game Pass configuration is added prematurely.

When the gate clears, the approved design converts DoubleMultiplier and VIP to Game Passes, verifies ownership on join, treats verified false as revocation and lookup failure as preserve-stored, re-queries after a successful prompt immediately and after `1, 2, 4` seconds, and grants only verified ownership. Both entitlements stack to 4x.

## Verification

Pure schema, environment resolution, queue behavior, leases, freeze, offline reward, receipt state, and shutdown coordination receive Lune tests. Every task passes focused tests, scoped StyLua, scoped Selene, Rojo build, and `git diff --check`. The final gate adds existing validation tests, full-tree format/lint, five Play Solo persistence runs through a parity-checked temporary `ServerStorage.MVP004Tests.SaveSystem` harness, and private staging purchase QA only after external monetization prerequisites exist.
