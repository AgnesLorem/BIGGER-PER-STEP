# Project Glossary - Bigger

This document defines the core gameplay concepts and technical terminology used throughout the Bigger project. This glossary ensures unified language across developers, designers, and AI agents.

---

## Glossary of Terms

### 1. Size
- **Definition**: The player's current physical scale and level. 
- **Behavior**: Accumulates dynamically during gameplay. Serves as the primary stat and gateway requirement. Resets to base value upon Rebirth.

### 2. Level
- **Definition**: Synonymous with `Size`. A player's progression level is physically represented by their model scale in the game environment.

### 3. Portal
- **Definition**: A spatial transition gateway in the Lobby.
- **Behavior**: Teleports a player into a private gameplay zone. Requires meeting authoritative thresholds (combinations of Size, Destruction, and Rebirths) to pass through.

### 4. Destruction
- **Definition**: A permanent progression milestone resource.
- **Behavior**: Awarded upon successfully destroying the main object in a private World. Acts as the equivalent of "Wins" in typical incremental games. It cannot be spent or reset.

### 5. World
- **Definition**: An isolated gameplay zone containing a single main objective. 
- **Behavior**: Exists as a private instance for each player.

### 6. Lobby
- **Definition**: The shared, social central hub of the Roblox server.
- **Behavior**: The spawn point where players meet, buy growth upgrades, perform Rebirths, and access world portals.

### 7. Runtime
- **Definition**: The active state of execution while the Roblox server or client session is running.

### 8. Instance
- **Definition**: A physical Roblox Object (model, mesh, GUI element) instantiated in the workspace.
- **Behavior**: Can be dynamic and recycled via pooling.

### 9. Definition
- **Definition**: An immutable, read-only configuration blueprint.
- **Behavior**: Loaded from data tables (e.g., `WorldDefinition`), defining static properties of maps, upgrade tiers, and objects before instantiation.

### 10. Component
- **Definition**: A modular, reusable script behavior attached to a physical instance.
- **Behavior**: Exposes data configurations and interfaces with core services (e.g., a `Destroyable` component attached to a map model).

### 11. Owner
- **Definition**: The designated service or session that holds exclusive write-authority over a specific runtime object or data profile.

### 12. Pool (Instance Pool)
- **Definition**: A pre-allocated memory storage queue for inactive Roblox instances.
- **Behavior**: Instead of calling `Clone()` and `Destroy()`, objects are checked out from the pool, reset, reused, and returned.
