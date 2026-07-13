# Upgrade Shop - Bigger

This document describes the design, progression steps, and unlock rules for Growth Upgrades. It does not define UI implementation details or hardcode balancing statistics.

---

## Shop Philosophy

- **Progression Milestones**: Growth Upgrades are permanent progression milestones, not consumable items. Players never lose or spend their unlocked upgrades.
- **Linear Upgrading**: Growth Upgrades follow a strictly linear progression pathway. A player must unlock the upgrades in order.
- **Single Active Buff**: Although a player can unlock multiple upgrades, only **one** Growth Upgrade may be active and equipped at any given time.

---

## Upgrade Progression Sequence

Players unlock upgrades sequentially starting from their baseline state:

1. **None** (Default baseline)
2. **Protein**
3. **Silver Protein**
4. **Gold Protein**
5. **Diamond Protein**
6. **Growth Serum**
7. **Advanced Serum**
8. **Titan Serum**

---

## Shop Rules

### 1. State Transitions
Every Growth Upgrade exists in exactly one of three states for a player:
- **Locked**: The player cannot equip this upgrade. They must unlock it.
- **Unlocked**: The player has unlocked the upgrade. It is now permanently in their inventory.
- **Equipped**: The upgrade is active, and its corresponding size multiplier is applied to the player.

### 2. Unlock Rules
- To unlock an upgrade, the player must:
  - Meet the required progression milestones (e.g., reaching a specific world zone or completing a portal requirement).
  - Have met or unlocked the immediately preceding upgrade in the progression sequence.
- Unlocking an upgrade is permanent. It does not consume resources or currency in the MVP.

### 3. Equip Rules
- The player can equip any unlocked upgrade at any time.
- Equipping a new upgrade automatically un-equips the previously active upgrade.
- The server authoritatively calculates the new multiplier whenever the equipped state changes.
