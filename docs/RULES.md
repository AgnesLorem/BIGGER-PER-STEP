# Development Rules - Bigger

This document defines the core constraints, coding principles, and guidelines that all developers and AI agents must follow when writing code for Bigger.

---

## 1. Server Authority
- The server owns all game state, calculation formulas, transaction checks, and reward disbursements.
- The client must never make decisions regarding progression (e.g., adding Size, granting Destruction, unlocking or equipping upgrades).
- The client may only request actions, which the server must thoroughly validate before executing.

## 2. Data-Driven Balancing
- **No Hardcoded Values**: All balancing thresholds, upgrade costs, multipliers, size requirements, and reward amounts must be retrieved from configuration files.
- Modifying game balance must only require editing data files, never changing implementation logic.
- **Read-Only Configuration**: Configuration data is strictly read-only during runtime unless explicitly owned and managed by a dedicated runtime system (e.g., dynamic event scaling). Code must never mutate configuration tables directly.

## 3. State Ownership
- **Single Source of State**: Every gameplay state (e.g., player size, equipped upgrade, portal completion status) has exactly **one** owner.
- **No Duplicated State**: Do not cache or duplicate gameplay state on both the client and server. The client should query the server's authoritative state or listen for server-broadcasted updates to update its visual presentation.

## 4. Remote Validation
- Every incoming network request from the client must be validated at the server boundary:
  - **Type & Range Checking**: Validate that arguments match expected types and are within normal ranges.
  - **Ownership Checking**: Confirm the player requesting the action owns or meets the requirements for the target object or upgrade.
  - **Rate Limiting & Cooldowns**: Enforce server-side rate limits on remote requests to prevent spam or packet exploitation.

## 5. Memory Cleanup
- Developers must define a clear ownership and teardown lifecycle for all created resources.
- Disconnect all connections, cancel tasks, destroy temporary instances, and flush cached player data when a player leaves or when an instance is removed.
- All helpers or scripts running background loops must expose an idempotent `Destroy` method for safe teardown.

## 6. Consistent Naming
- All variable, module, class, remote event, and database field names must strictly follow the terminology dictionary in `NAMING.md`.
- Never mix synonyms (e.g., do not use `Cash`, `Coins`, or `Money` for `Destruction`).

## 7. Single Responsibility
- Every ModuleScript, class, and service must own exactly **one** distinct responsibility.
- If a service or script grows to handle multiple responsibilities or exceeds reasonable size limits, split it into separate, focused modules.

## 8. Documentation First
- **Docs Lead Code**: If a feature modifies the system's architecture, the documentation must be updated before or alongside the implementation.
- Implementation must never become the primary source of truth. Code must follow the documentation, not define the architecture.

## 9. Core Documentation Stability (Prevent Sprawl)
- To avoid overlap, fragmentation, and contradictions, developers and AI agents must not create new high-level documentation files (e.g., `GAMEPLAY.md`, `FEATURES.md`, `SYSTEM.md`, `DESIGN.md`, `FRAMEWORK.md`).
- All architectural designs must remain integrated within the core four documents:
  - [GAME.md](file:///f:/BIGGER/docs/GAME.md) (Gameplay principles & design invariants)
  - [ARCHITECTURE.md](file:///f:/BIGGER/docs/ARCHITECTURE.md) (High-level system layers & persistence)
  - [RUNTIME.md](file:///f:/BIGGER/docs/RUNTIME.md) (Execution lifecycles, states, and frameworks)
  - [RULES.md](file:///f:/BIGGER/docs/RULES.md) (Development constraints & coding rules)

## 10. Architecture Freeze
- **Architecture Stability**: Core architecture documents (e.g. `GAME.md`, `ARCHITECTURE.md`, `RUNTIME.md`) are considered frozen and stable.
- **Change Control**: Modifying these foundational documents requires:
  - Explicable, reusable architectural justification.
  - Creating or updating an Architectural Decision Record (ADR) file.
  - Review and approval from the user before implementation.
- This prevents AI agents and developers from modifying foundational specifications to fit minor, feature-specific code changes.

## 11. Core Stability Rule
- Once a capability exists in Core, future gameplay features must extend it rather than bypass it.
- If a feature cannot be built through extension, the Core must be improved to support extensibility before the feature is built.

## 12. No Singleton State
- Local or global module variables tracking runtime states are banned.
- All mutable runtime state must reside in `RuntimeRegistry` partitions (e.g., `Sessions`, `Timers`).
- Configuration tables loaded at boot are read-only and do not count as mutable state.

## 13. Core is Stable, Game is Replaceable
- The Core framework remains stable, versioned, and backward compatible.
- The Game layer (configs, definitions, formulas, systems) is swappable without modifying Core.
- Core must never reference game-specific content concepts directly.

## 14. Feature Test Rule
- Before writing code for a new feature, developers and AI agents must answer four questions in order:
  1. **Config**: Can this be done by changing a configuration value?
  2. **Definition**: Can this be done by adding a new definition entry?
  3. **Component**: Can this be done by creating a reusable component?
  4. **Core**: Does this require modifying a Core service? If so, justify with an ADR.
- If the problem is ambiguous or complex, ask the user before proceeding.

## 15. No Hidden Magic
- Every service registration, bootstrap stage, and factory must be explicitly declared.
- No auto-discovery of modules, no implicit registration, and no magic string-based lookups without a clear manifest.
- Boot order and service dependencies must be traceable from the bootstrap entry point.

