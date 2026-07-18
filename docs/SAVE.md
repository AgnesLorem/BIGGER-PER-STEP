# Data Persistence & Profiles - Bigger

MVP-004 implements native, server-authoritative persistence with Roblox `DataStoreService` and `UpdateAsync`.

---

## Player Profile Definition

Each player's persistent data is stored within a conceptual `PlayerProfile` structure. The server maintains absolute ownership of this profile throughout the gameplay session. 

A player profile tracks the following data categories:

- **Bigger**: The integer gameplay growth value used by the current runtime.
- **Destruction**: The lifetime count of completed portal objectives.
- **Rebirth**: The number of permanent resets performed.
- **Growth Upgrades**: A record of all unlocked upgrades.
- **Equipped Growth Upgrade**: The upgrade currently active and boosting size generation.
- **Portal Progress**: Portals that have been successfully completed or unlocked.
- **Player Settings**: Local preferences and options (e.g., sound toggles).
- **Entitlements**: Forward-compatible 2X Multiplier and VIP booleans, normalized and persisted with defaults of `false`; MVP-004 has no Game Pass lookup or purchase flow.
- **Receipt History**: Up to 5,000 durable Developer Product Purchase IDs.
- **Offline Metadata**: Active, logout, and save timestamps used for atomic offline rewards.

---

## Session Lifecycle

### 1. Load Lifecycle (Player Joining)
1. The server creates one temporary runtime entry keyed by numeric UserId.
2. A per-UserId FIFO worker acquires the profile through `UpdateAsync`.
3. Stored data is normalized to schema v1; malformed known data fails closed.
4. The same transform claims offline progression and acquires a 180-second lease.
5. `SessionService` creates the authoritative session only after load succeeds.
6. The server projects attributes and leaderstats, then explicitly loads the character.

The store is `BiggerPlayerProfiles_v1`, with key `Player_<UserId>`. Studio always uses the isolated `Studio` scope. The production PlaceId uses `Production`; unknown live PlaceIds fail boot. A future approved milestone may add a private `Staging` mapping using a real PlaceId.

### 2. Gameplay Phase (In-Memory Access)
- `RuntimeRegistry.Sessions` is the sole mutable gameplay source of truth.
- All persistent-field mutation paths fail closed after `ProfileMutationsFrozen` is set.
- The client receives projected state but has no write access to the authoritative profile.

### 3. Autosave Philosophy (Periodic Saving)
- One global scheduler queues autosaves every 60 seconds.
- Autosaves, receipts, and final releases share the player's FIFO worker; only duplicate autosaves coalesce.
- Writes retry after 1, 2, and 4 seconds and atomically renew the lease.

### 4. Save Lifecycle (Player Unload)
- Player removal freezes mutations before the final snapshot, writes logout metadata, clears the lease, and removes the session only after success.
- Shutdown freezes every active profile first, starts final requests concurrently across UserIds, preserves each FIFO, and waits at most 25 seconds globally.
- Timeout diagnostics include UserId, phase, queue length, and the last DataStore error. Shutdown never bypasses workers with a replacement write.

---

## Offline Progression Lifecycle

Players accrue size gains during offline periods. This mechanic runs conceptually, without simulating actual walking or physics when the player is offline:

```text
Player Leaves Server
        ↓
Server records 'LastLogoutTime' timestamp
        ↓
[Player remains offline. No simulation runs.]
        ↓
Player Rejoins Server
        ↓
Server calculates 'OfflineDuration' (CurrentTime - LastLogoutTime)
        ↓
Server applies the capped time reward using stored entitlement booleans
        ↓
Server applies the offline size reward directly to the player's profile in memory
```

The atomic acquire transform uses:

```text
OfflineSeconds = clamp(Now - max(LastActiveTimestamp, LastLogoutTimestamp), 0, 28800)
OfflineReward = floor(OfflineSeconds / 60 × 30 × GrowthMultiplier)
```

New and timestamp-less legacy profiles receive zero. The claim timestamp, reward, and lease are persisted together, preventing the same interval from being claimed twice.

## Developer Product Receipts

Durable Purchase IDs live in `Session.PurchaseHistory`; dispatched but unconfirmed IDs live only in `Profiles.PendingPurchaseIds`. Pending retries never redispatch rewards. `PurchaseGranted` is returned only after the Purchase ID and complete authoritative snapshot are durable. At the 5,000-ID combined ceiling, existing duplicates still succeed and new receipts fail closed without dispatch.

## Deferred Game Pass Monetization

MVP-004 completion scope is the native server-authoritative DataStore save system, including durable Developer Product receipts. Game Pass creation, ownership reconciliation, purchase prompting, private-staging setup, and real purchase QA are deferred to a separate future approved milestone. Placeholder entitlement IDs are not active release configuration.
