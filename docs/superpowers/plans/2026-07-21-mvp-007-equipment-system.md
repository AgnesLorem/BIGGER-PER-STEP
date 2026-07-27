# MVP-007: Equipment System Implementation Plan

**Goal:** Build a server-authoritative Growth Upgrades equipment system enabling players to sequentially unlock linear upgrades and equip a single active growth multiplier buff.

**Architecture:** A shared upgrade config (`UpgradesConfig.luau`), a server-authoritative `EquipmentService.luau` registered in `GameBootstrap.luau`, formula integration in `GrowthFormula.luau`, client state synchronization via `EquipmentController.luau`, immediate profile saving via `SaveService:QueueProfileSave`, and unit test coverage in `tests/unit/equipment_system.luau`.

**Tech Stack:** Luau, Roblox Server/Client Services, EventBus session lifecycle events, RemoteEvents/RemoteFunctions, per-UserId FIFO persistence worker, unit tests with `assert`.

## Global Constraints & Approved Decisions

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
- **Immediate Save Behavior**: A successful mutation keeps its authoritative result even if presentation sync or `SaveService:QueueProfileSave(Player)` fails. Presentation and queue failures are isolated and logged; autosave/final save remain the durability fallback.
- **Deep Freezing**: Deep-freeze `Sequence`, every `UpgradeDefinition`, `Upgrades`, and `UpgradesConfig`.
- **Client State Boundary**: Accept only complete, well-formed authoritative snapshots, copy incoming arrays, and give callbacks defensive copies.
- **Remote Boundary**: Reject malformed or oversized IDs, allow one in-flight mutation per player, rate-limit rapid requests, and always release locks after exceptions.

---

## Exact Repository Scope

The exact scope of created and modified files for MVP-007:

- `tasks/MVP-007.md`
- `docs/superpowers/plans/2026-07-21-mvp-007-equipment-system.md`
- `src/shared/Game/Config/UpgradesConfig.luau`
- `src/shared/Game/Progression/LevelFormula.luau`
- `src/server/Game/Services/EquipmentService.luau`
- `src/server/Game/Formula/GrowthFormula.luau`
- `src/server/Game/GameBootstrap.luau`
- `src/server/Core/Services/SaveService.luau`
- `src/client/controllers/EquipmentController.luau`
- `src/client/BiggerClientMain.client.luau`
- `tests/unit/equipment_system.luau`

---

## Verification Results

- `lune run tests/unit/equipment_system.luau`: PASS (configuration, formula, service, client, lifecycle, persistence-boundary, and remote-security coverage)
- `lune run tests/unit/movement_validation.luau`: PASS
- `lune run tests/unit/stomp_validation.luau`: PASS
- `stylua --check src tests`: PASS
- Scoped MVP-007 Selene command: PASS (0 errors, 0 warnings)
- `selene src tests`: repository-wide pre-existing Lune/test incompatibilities remain outside MVP-007 scope; no global rules or unrelated files were changed.
- `rojo build default.project.json -o "$env:TEMP\bigger-mvp007-review.rbxl"`: PASS
- `git diff --check`: PASS
- Focused Studio QA in a temporary Rojo-built place: PASS for equipment authority, multipliers, rate limiting, loaded-state repair, client synchronization, malformed-state rejection, and defensive copies.
- Full DataStore-backed rejoin QA: unavailable in the unpublished temporary place; production persistence semantics are covered by unit tests and require confirmation in a published MVP-007-mapped place.
