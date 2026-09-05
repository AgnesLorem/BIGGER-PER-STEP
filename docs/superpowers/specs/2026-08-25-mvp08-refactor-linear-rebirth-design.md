# Spec: Refactor MVP-08 Progression Balance & Linear Rebirth

**Date:** 2026-08-25  
**Topic:** MVP-08 Progression Balance Refactor  
**Goal:** Replace the exponential rebirth multiplier with a linear multiplier formula ($\text{Mult}(R) = 1 + R \times 0.75$) to prevent hyper-inflation/snowball, confirm level-only Rebirth gating ($\text{ReqLevel}(R) = 20 + R \times 50$), and keep Destruction strictly dedicated to Equipment tier progression.

---

## 1. Core Mechanics & Mathematical Specifications

### 1.1. Level Progression Curve (Unchanged)
- **Formula:** $\text{Bigger}(L) = \left\lfloor 1.66204986 \times (L - 1)^2 \right\rfloor$
- **Base Constant:** $\text{BASE\_REQUIREMENT} = 600 / (19 \times 19) \approx 1.66205$
- **Baseline Target:** Level 20 = 600 Bigger (5 minutes walking at base 2 Bigger/sec)
- **Inverse:** $\text{Level} = \left\lfloor \sqrt{\text{Bigger} / \text{BASE\_REQUIREMENT}} \right\rfloor + 1$ with monotonic step verification

### 1.2. Visual Scale Curve (Unchanged)
- **Formula:** $\text{Scale}(L) = 1 + 0.080739 \times \max(0, L - 1)^{0.8299}$
- **Config:** `Formula = "power"`, `Coefficient = 0.080739`, `Exponent = 0.8299`, `MinVisualScale = 1`, `MaxVisualScale = 200`
- **Milestones:** Lv 1 = 1.00x, Lv 10 = 1.50x, Lv 50 = 3.04x, Lv 100 = 4.66x, Lv 500 = 15.00x

### 1.3. Rebirth System (Refactored to Linear)
- **Level Requirement Only:**
  $$\text{ReqLevel}(R) = 20 + R \times 50$$
  where $R$ is the player's current completed Rebirth count ($R = 0, 1, 2, \dots$).
  - **R0 $\rightarrow$ R1:** Level 20
  - **R1 $\rightarrow$ R2:** Level 70
  - **R2 $\rightarrow$ R3:** Level 120
  - **R3 $\rightarrow$ R4:** Level 170
  - **R4 $\rightarrow$ R5:** Level 220
  - **R9 $\rightarrow$ R10:** Level 470
- **No Destruction Gate for Rebirth:** Rebirth checks only `CurrentLevel >= ReqLevel(R)`.
- **Linear Multiplier Formula:**
  $$\text{Mult}(R) = 1 + R \times 0.75$$
  - **R0 (No Rebirth):** 1.00x
  - **R1:** 1.75x
  - **R2:** 2.50x
  - **R3:** 3.25x
  - **R4:** 4.00x
  - **R5:** 4.75x
  - **R10:** 8.50x
  - **R20:** 16.00x
- **Reset Behavior on Rebirth:**
  - **Reset:** `Bigger = 0`, `Level = 1`, `VisualScale = 1.0x`, `GrowthRemainder = 0`.
  - **Retain:** `Destruction`, `UnlockedGrowthUpgrades`, `EquippedGrowthUpgrade`, `CompletedPortals`, GamePasses/VIP.

### 1.4. Growth Multiplier Interaction Chain
$$\text{TotalMultiplier} = \text{EquipmentMult} \times \text{RebirthMult} \times (\text{DoublePass ? } 2 : 1) \times (\text{VipPass ? } 2 : 1)$$
- Applied authoritatively in:
  1. `GrowthFormula.luau` (Active walking & AFK zones)
  2. `SaveService.luau` / `PlayerProfileSchema.luau` (Offline progress reward calculation)

### 1.5. Equipment Gates (Unchanged)
- Destruction milestones only (no Level requirement):
  - Protein: 1 Destruction (1.5x)
  - Silver Protein: 3 Destruction (2.0x)
  - Gold Protein: 8 Destruction (3.0x)
  - Diamond Protein: 15 Destruction (5.0x)
  - Growth Serum: 30 Destruction (10.0x)
  - Advanced Serum: 60 Destruction (25.0x)
  - Titan Serum: 100 Destruction (50.0x)

---

## 2. Component Modification Plan

1. **`src/shared/Game/Config/RebirthConfig.luau`**:
   - Update `BaseLevelRequirement = 20`, `LevelIncrementPerRebirth = 50`.
   - Replace `MultiplierExponent` with `MultiplierPerRebirth = 0.75`, `BaseMultiplier = 1.0`.
   - `MinimumRebirthCooldownSeconds = 2`.

2. **`src/shared/Game/Progression/RebirthFormula.luau`**:
   - `GetMultiplier(RebirthCount)`: Returns `RebirthConfig.BaseMultiplier + RebirthCount * RebirthConfig.MultiplierPerRebirth`.
   - `GetRequiredLevel(RebirthCount)`: Returns `RebirthConfig.BaseLevelRequirement + RebirthCount * RebirthConfig.LevelIncrementPerRebirth`.
   - `CanRebirth(CurrentLevel, RebirthCount)`: Returns `CurrentLevel >= GetRequiredLevel(RebirthCount)`.

3. **`src/server/Game/Services/RebirthService.luau`**:
   - Validate level against `RebirthFormula.CanRebirth(CurrentLevel, Session.Rebirth)`.
   - Ensure Destruction, Equipment, Portals are preserved.
   - Update `Player:SetAttribute("RebirthMultiplier", RebirthFormula.GetMultiplier(NewRebirthCount))`.

4. **`tasks/MVP-008.md`**:
   - Update documentation to reflect linear multiplier and level-only gate.

5. **`tests/unit/progression_balance.luau` & test suite**:
   - Update assertions for linear multiplier (R1 = 1.75x, R2 = 2.50x, R5 = 4.75x, R10 = 8.50x).
   - Ensure all 6 unit test suites pass 100%.

---

## 3. Verification Criteria

- Selene: 0 errors, 0 warnings
- StyLua: 0 diffs
- Lune unit tests: 100% PASS across all 6 test files.
