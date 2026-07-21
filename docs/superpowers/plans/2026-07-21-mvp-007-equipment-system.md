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
- **Immediate Save Behavior**: Mutation succeeds → presentation sync succeeds → `SaveService:QueueProfileSave(Player)` queues non-blocking save via FIFO worker → remote returns.
- **Deep Freezing**: Deep-freeze `Sequence`, every `UpgradeDefinition`, `Upgrades`, and `UpgradesConfig`.

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
- `tests/unit/save_system.luau`

---

## Detailed Implementation Tasks

### Task 1: Shared Upgrade Configuration (`UpgradesConfig.luau`) & Unit Tests

**Files:**
- Create: `src/shared/Game/Config/UpgradesConfig.luau`
- Create: `tests/unit/equipment_system.luau`

**Interfaces:**
- Consumes: `UnlockedGrowthUpgrades` (`{ [string]: boolean }`), `Destruction` (`number`), `Level` (`number`)
- Produces: `UpgradesConfig` module with:
  - `Sequence`: `{ string }`
  - `Upgrades`: `{ [string]: UpgradeDefinition }`
  - `GetDefinition(upgradeId: string?): UpgradeDefinition?`
  - `GetMultiplier(upgradeId: string?): number`
  - `GetPreviousUpgradeId(upgradeId: string): string?`
  - `CanUnlock(unlockedMap: { [string]: boolean }, destruction: number, level: number, upgradeId: string): boolean`
  - `CanEquip(unlockedMap: { [string]: boolean }, upgradeId: string?): boolean`

- [ ] **Step 1: Write failing configuration unit tests in `tests/unit/equipment_system.luau`**
- [ ] **Step 2: Implement `UpgradesConfig.luau` with deep freezing**
- [ ] **Step 3: Run unit tests to verify PASS**

---

### Task 2: Update `GrowthFormula.luau` for Equipment Multipliers

**Files:**
- Modify: `src/server/Game/Formula/GrowthFormula.luau`

**Interfaces:**
- Consumes: `UpgradesConfig.GetMultiplier(Session.EquippedGrowthUpgrade)`
- Produces: Updated `GrowthFormula.GetMultiplier(Session)` computing `equipment × HasDoubleMultiplier × HasVip` while preserving fractional gain.

- [ ] **Step 1: Add formula tests to `tests/unit/equipment_system.luau`**
- [ ] **Step 2: Update `GrowthFormula.GetMultiplier`**
- [ ] **Step 3: Run tests to verify PASS**

---

### Task 3: Non-Blocking Save Queue API in `SaveService.luau`

**Files:**
- Modify: `src/server/Core/Services/SaveService.luau`
- Modify: `tests/unit/save_system.luau`

**Interfaces:**
- Produces: `SaveService:QueueProfileSave(Player: Player): boolean` using existing per-UserId FIFO `QueueSave(Player, "Autosave")`.

- [ ] **Step 1: Add unit test in `tests/unit/save_system.luau` for `QueueProfileSave`**
- [ ] **Step 2: Implement `SaveService:QueueProfileSave` in `SaveService.luau`**
- [ ] **Step 3: Run `save_system.luau` unit tests**

---

### Task 4: Server `EquipmentService.luau` & Bootstrap Integration

**Files:**
- Create: `src/server/Game/Services/EquipmentService.luau`
- Modify: `src/server/Game/GameBootstrap.luau`

**Interfaces:**
- Consumes: `Sessions`, `GrowthService`, `UpgradesConfig`, `LevelFormula`, `SaveService`, `EventBus`
- Produces: `EquipmentService` with `UnlockUpgrade`, `EquipUpgrade`, `GetEquipmentState`, handling remotes `UnlockUpgrade`, `EquipUpgrade`, `GetEquipmentState`, `EquipmentStateChanged`, subscribing to `PlayerSessionCreated` / `PlayerSessionDestroyed`.

- [ ] **Step 1: Add Service unit tests in `tests/unit/equipment_system.luau`**
- [ ] **Step 2: Implement `EquipmentService.luau` with structured result codes & rate limiting**
- [ ] **Step 3: Register `EquipmentService` in `GameBootstrap.luau`**
- [ ] **Step 4: Run unit tests to verify PASS**

---

### Task 5: Client `EquipmentController.luau` & Initialization

**Files:**
- Create: `src/client/controllers/EquipmentController.luau`
- Modify: `src/client/BiggerClientMain.client.luau`

**Interfaces:**
- Consumes: Remotes `GetEquipmentState`, `UnlockUpgrade`, `EquipUpgrade`, event `EquipmentStateChanged`
- Produces: `EquipmentController` client state manager keeping local `EquipmentState = { EquippedUpgradeId = string, UnlockedUpgradeIds = { string } }`.

- [ ] **Step 1: Implement `EquipmentController.luau`**
- [ ] **Step 2: Register in `BiggerClientMain.client.luau`**
- [ ] **Step 3: Verify client compilation and state update handlers**

---

### Task 6: Full Verification & QA Checklist

- [ ] Run `lune run tests/unit/movement_validation.luau`
- [ ] Run `lune run tests/unit/stomp_validation.luau`
- [ ] Run `lune run tests/unit/equipment_system.luau`
- [ ] Run `stylua --check src tests`
- [ ] Run `selene src tests`
- [ ] Run `rojo build default.project.json -o "$env:TEMP\bigger-mvp007.rbxl"`
- [ ] Run `git diff --check`
