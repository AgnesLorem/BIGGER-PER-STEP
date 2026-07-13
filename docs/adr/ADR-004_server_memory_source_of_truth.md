# ADR-004: Server Memory Source of Truth

## Context
Roblox games frequently store or query player progress (e.g., Size, Cash, Wins) directly from client-visible folders (such as `leaderstats`), player `Attributes`, or UI elements (`PlayerGui`). This structure has major drawbacks:
- **Security Vulnerabilities**: Clients can easily spoof or manipulate local attributes or folder structures, leading to exploit vectors.
- **Sync Delays**: Relying on replication channels to read data on the server introduces latency and consistency errors.
- **Tightly Coupled Presentation**: Logic becomes dependent on the physical hierarchy of instances, making UI redesigns or database schema updates highly prone to breaking core code.

## Decision
Server Memory (specifically cache profiles managed in memory by `SessionService`) is the absolute, unidirectional source of truth for all game states.
- Client-facing objects (`PlayerGui`, `leaderstats`, Roblox instance `Attributes`) are strictly presentation layers.
- The server writes state updates *down* to these presentation structures, but never reads from them to run validations or calculations.
- Data persistence flows exclusively from Server Memory down to the Database (`Persistent Data`) and back up to Server Memory upon session load.

## Consequences
- **Robust Security**: Exploiters can modify their local UI, leaderstats, or attributes, but it will have zero impact on the authoritative server-side state.
- **Decoupled Development**: The presentation layer (UI/VFX) can be entirely rebuilt or modified without affecting backend mechanics.
- **Clear Data flow**: Establishes a predictable data tier hierarchy: `Persistent Data → Server Memory → Runtime State → Presentation`.
