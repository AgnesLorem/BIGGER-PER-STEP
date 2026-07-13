# Data Persistence & Profiles - Bigger

This document outlines the conceptual data schema, lifecycle, ownership, and saving mechanisms for player data. It does not contain code or language-specific implementation types.

---

## Player Profile Definition

Each player's persistent data is stored within a conceptual `PlayerProfile` structure. The server maintains absolute ownership of this profile throughout the gameplay session. 

A player profile tracks the following data categories:

- **Size**: The player's current physical scale and level.
- **Destruction**: The lifetime count of completed portal objectives.
- **Rebirth**: The number of permanent resets performed.
- **Growth Upgrades**: A record of all unlocked upgrades.
- **Equipped Growth Upgrade**: The upgrade currently active and boosting size generation.
- **Portal Progress**: Portals that have been successfully completed or unlocked.
- **Player Settings**: Local preferences and options (e.g., sound toggles).
- **Offline Metadata**: System timestamps tracked for calculating offline rewards.

---

## Session Lifecycle

### 1. Load Lifecycle (Player Joining)
1. The player enters the server.
2. The server requests the player's saved state from the persistent database.
3. If no record is found, the server initializes a default profile with base values.
4. The profile is loaded into server memory.
5. The server calculates and applies offline rewards (see below).
6. The server transmits a read-only copy of the profile to the client to update visual components and UI.

### 2. Gameplay Phase (In-Memory Access)
- While the player is active in the game, their profile remains cached in the server's memory.
- All modifications (e.g., adding Size, equipping upgrades, unlocking portals) are applied directly to the in-memory cache on the server.
- The client receives state updates but has no write-access to this memory.

### 3. Autosave Philosophy (Periodic Saving)
- To prevent data loss in the event of client disconnections or server instability, the server periodically writes the in-memory profile of all active players back to the persistent database.
- The write interval should balance safety against network throughput constraints.

### 4. Save Lifecycle (Player Unload)
- The player exits the server or the server initiates a shutdown.
- The server captures the final in-memory state of the player profile.
- The server records the logout timestamp to the profile's offline metadata.
- The server performs a final write to the database and clears the profile from memory.

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
Server determines size reward based on duration & equipped Growth Upgrade multipliers
        ↓
Server applies the offline size reward directly to the player's profile in memory
```
