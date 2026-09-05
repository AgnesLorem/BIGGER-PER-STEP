# Task MVP-007: Multi-Map Teleporter System & Forest Zone (Maps 1-3)

Implement the generalized **Multi-Map Architecture**, central **Teleporter Master Portal**, responsive **3-Tab Map Selector GUI**, and complete content implementation for **Maps 1, 2, and 3 (Forest Theme)** in Project BIGGER.

---

## 3D Asset & Map Pipeline Specification

Per the `/grill-me` architectural alignment:
1. **Hybrid Industry Pipeline**:
   - **Blender**: Generates stylized organic 3D models (`Spider`, `WildBoar`, `AncientBear`, `TeleporterArch`, and pre-fractured debris pieces) with clean pivots at $Z=0$ (ground level) and exported to `blender/exports/`.
   - **Roblox Studio**: Assembles room templates (`ServerStorage.WorldTemplates.MAP1`, `MAP2`, `MAP3`), boundary walls, `EntrySpawn`, `ObjectiveHitbox`, `FreeRewardPortal`, and `PaidRewardPortal`.
2. **Stylized Low-Poly Art Style**:
   - Clean, vibrant low-poly simulator aesthetics (1,500 - 3,500 tris per model), smooth normals, color palette textures optimized for 60 FPS mobile gameplay.
3. **Physical Pre-Fractured Destruction FX**:
   - Objectives include pre-fractured stylized debris chunks (4-8 pieces). When stomped, the intact model hides, physical chunks scatter outward with impulse and fade out, paired with cartoon particle pop and stomp audio.
4. **Automated Agentic Scripting**:
   - Automated via Blender Python script (`blender/scripts/generate_forest_objectives.py`) and Studio Luau assembler.

---

## Scoped Files

AI agents implementing this task are **STRICTLY RESTRICTED** to modifying only the following files:
- `tasks/MVP-007_multimap_forest.md` (Official task file in repo)
- `src/server/Game/Config/MapsConfig.luau` (Generalized map registry replacing single World1Config)
- `src/server/Game/Services/WorldInstanceService.luau` (Decouple from hardcoded World1Config to dynamic MapsConfig)
- `src/server/Game/Services/PortalService.luau` (Handle RequestSelectMap remote & validate Level/Scale per map)
- `src/server/Game/Services/DestructionService.luau` (Support dynamic objective models: Spider, WildBoar, AncientBear + fractured chunks FX)
- `src/server/Game/Services/RewardPortalService.luau` (Support dynamic Destruction reward amounts per map)
- `src/client/controllers/MapSelectorController.luau` (3-Tab visual cards GUI & central Teleporter proximity prompt binding)
- `blender/scripts/generate_forest_objectives.py` (Blender procedural generator script)
- `tests/unit/mvp007_multimap_contracts.luau` (Automated contract test suite)
- `docs/WORLDS.md` (Update world and map progression specifications)

---

## Integration Boundary

Modules that this task interacts with but must **NOT** rewrite or refactor:
- `src/server/Core/Services/CharacterScaleService.luau` (Authoritative scaling remains unchanged)
- `src/server/Core/Services/SaveService.luau` (Profile persistence remains intact)
- `src/server/Core/Registry/RuntimeRegistry/Sessions.luau` (Session schema types preserved)
- `src/server/Game/Services/UpgradeService.luau` (Growth upgrade mechanics preserved)
- `src/server/Game/Services/RebirthService.luau` (Rebirth mechanics preserved)

---

## Out of Scope

To eliminate scope creep and preserve stability, this task must **NOT**:
- Implement Maps 4 through 10 (Residential & Metropolis themes remain marked as 'Coming Soon' in UI).
- Un-quarantine or modify `DailyRewardService`, `SpinWheelService`, `CosmeticsService`, or `AutoWinsService`.
- Introduce new gameplay mechanics (Pets, Guilds, PvP, Crafting, Trading).
- Modify existing Growth Upgrades or Rebirth formulas.

---

## Formal Invariants & State Machine Rules

1. **INV-01 (Multi-Map Generalization)**: Map requirements, objective models, and reward tiers are retrieved dynamically from `MapsConfig.luau` by `MapId`; no hardcoded world assumptions.
2. **INV-02 (Entrance Gating Invariant)**: A player cannot enter or teleport to any map unless authoritative `Session.Bigger >= Map.RequiredSize` (or `DerivedLevel >= Map.RequiredLevel`).
3. **INV-03 (Single Objective Isolation)**: Every private map instance contains exactly one designated destroyable objective (`Spider`, `WildBoar`, `AncientBear`).
4. **INV-04 (Scale-Safe Stomp & Physical Shatter)**: Stomp hitbox calculations scale with `VisualScale` so giant players crush objectives without vertical clipping. Destruction triggers pre-fractured debris scatter and particle pop.
5. **INV-05 (Deterministic Two-Portal Reward)**: Stomp completion activates exactly 1 Free and 1 Paid Triple reward portal. Stepping through settles the reward and teleports the player back to Lobby `ReturnSpawn`.

---

## Map Specifications (Theme: Khu Rừng - Forest Zone)

| Map Id | Name | Required Level | Destroyable Objective | Free Reward | Paid Reward (x3) |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **`MAP1`** | Nhện Rừng (Forest Spider) | Level 5 (Size 50) | `Spider` | +1 Destruction | +3 Destruction (29 R$) |
| **`MAP2`** | Heo Rừng Gai (Wild Boar) | Level 15 (Size 500) | `WildBoar` | +5 Destruction | +15 Destruction (29 R$) |
| **`MAP3`** | Gấu Chúa Cổ Đại (Ancient Bear) | Level 35 (Size 5,000) | `AncientBear` | +20 Destruction | +60 Destruction (29 R$) |

---

## Execution Steps

- [x] **Step 1: 3D Asset Generation (Blender Python Pipeline)**
  - Execute `blender/scripts/generate_forest_objectives.py` via Blender MCP to generate stylized low-poly models for `Spider`, `WildBoar`, `AncientBear`, `TeleporterArch`, and fracture chunk models.
  - Export models to `blender/exports/`.

- [x] **Step 2: Generalized Maps Configuration (`MapsConfig.luau`)**
  - Create `src/server/Game/Config/MapsConfig.luau` containing all 10 map definitions grouped into 3 categories (`Forest`, `Residential`, `Metropolis`).
  - Configure Maps 1-3 with exact requirements, objective parameters, and reward definitions.
  - Mark Maps 4-10 with placeholder data and `IsComingSoon = true`.

- [x] **Step 3: Service Generalization**
  - Update `WorldInstanceService.luau` to load templates dynamically by `MapId` from `ServerStorage.WorldTemplates`.
  - Update `PortalService.luau` to validate `RequestSelectMap(Player, MapId)` against authoritative Level/Scale requirements before triggering instance creation.
  - Update `DestructionService.luau` and `RewardPortalService.luau` to dynamically bind to the specific objective model, spawn physical shatter chunks, and reward amounts specified in `MapsConfig`.

- [x] **Step 4: Central Teleporter & Responsive 3-Tab GUI**
  - In Roblox Studio Lobby, set up the central `Teleporter` arch with a ProximityPrompt (`[E] Choose Map`) and floor touch zone.
  - Update `MapSelectorController.luau` with 3 category tabs: `Khu Rừng (1-3)`, `Khu Dân Cư (4-6)`, `Siêu Đô Thị (7-10)`.
  - Render visual cards for Maps 1-3 with target preview, level requirement, destruction reward, and dynamic `[DỊCH CHUYỂN]` button. Display `Coming Soon` badge on future tabs.

- [x] **Step 5: Map Templates Setup in ServerStorage**
  - Assemble templates for `MAP1` (Spider), `MAP2` (WildBoar), and `MAP3` (AncientBear) with proper `EntrySpawn`, `ObjectiveHitbox`, `FreeRewardPortal`, and `PaidRewardPortal` in `ServerStorage.WorldTemplates`.

- [x] **Step 6: Automated Contract Test Suite**
  - Create `tests/unit/mvp007_multimap_contracts.luau` to verify:
    1. MapsConfig schema validity across all 10 maps.
    2. Gated teleport validation (reject under-leveled players, allow qualified players).
    3. Stomp and reward settlement calculations for Maps 1, 2, and 3.
    4. Private instance lifecycle and cleanup.

- [x] **Step 7: Two-Stage Verification Gate**
  - Stage 1 (Offline): `selene src/` and `stylua --check src/` passed (0 errors, 0 warnings). Lune contract tests 100% green.
  - Stage 2 (Studio Play Solo): Run Play Solo session, walk to Teleporter, select Map 1, Map 2, and Map 3, destroy objectives, verify physical shatter FX, verify rewards, and confirm return to Lobby with clean console output.

---

## QA & Verification Checklist

- [x] **StyLua**: `stylua --check src/` passed (0 formatting discrepancies).
- [x] **Selene**: `selene src/` passed (0 errors, 0 warnings).
- [x] **Contract Tests**: `tests/unit/mvp007_multimap_contracts.luau` 100% green (7/7 assertions).
- [x] **Roblox Studio Play Solo**: Full multi-map loop tested in engine with clean F9 console (`SUCCESS: All GameplaySimulator tests passed cleanly!`).
- [x] **Walkthrough Created**: Evidence logs and screenshots documented.
- [x] **User Review Approval**: Presented to user and approved before any git push.
