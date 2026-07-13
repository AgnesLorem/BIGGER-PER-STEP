# ADR-001: Private World Instances

## Context
Multiplayer incremental games often face challenges when players share the same gameplay zone:
- **Resource Contention**: Players steal objects from each other, leading to frustration and poor pacing.
- **State Synchronization Overhead**: Synchronizing the destruction physics, mesh deformation, and replication of hundreds of objects across multiple players degrades server performance.
- **Progression Balancing Complexity**: Pacing rewards and scaling object health becomes highly complex when multiple players of vastly different levels interact with the same assets.

## Decision
We will partition the server such that every portal transfer allocates a private, player-isolated `WorldInstance` from a pre-allocated instance pool within the *same* Roblox server session.
- No `TeleportService` or Reserved Servers will be used (avoiding loading screens and matchmaking delays).
- Players remain in the same Roblox server instance, but their physical gameplay environments are offset or placed in isolated spaces.
- The Lobby remains a shared social space, while active gameplay zones are strictly private.

## Consequences
- **No resource contention**: Every player has access to all destroyable assets within their private world.
- **Simplified synchronization**: Destruction state is entirely local to the player's world instance. The server only replicates state changes to that specific player.
- **Efficient memory reuse**: Instead of cloning and destroying maps (which causes memory fragmentation), world models are recycled via an `InstancePool` (Acquire → Reset → Reuse → Release).
- **Smooth social-to-gameplay transition**: Seamless transition from social interaction in the Lobby to focused individual gameplay in active zones.
