# Terminology & Naming Dictionary - Bigger

To maintain strict codebase consistency and avoid naming drift across modules (especially in AI-generated code), all code symbols, network interfaces, configuration keys, and variables must adhere to this naming dictionary.

---

## Core Progression Terms

| Concept / Resource | Standard Name | Forbidden Synonyms |
| :--- | :--- | :--- |
| Primary scale resource | **`Size`** | `Scale`, `Weight`, `Growth` |
| Primary progression currency | **`Destruction`** | `Coins`, `Cash`, `Money`, `Gold`, `Wins` |
| Secondary progression reset | **`Rebirth`** | `Reset`, `Ascension`, `Prestige` |
| Scale increase multiplier | **`GrowthMultiplier`** | `Multiplier`, `SizeMultiplier`, `Boost` |
| Permanent upgrade item | **`GrowthUpgrade`** | `GrowthCore`, `Upgrade`, `GrowthItem` |
| World partitions / areas | **`WorldZone`** | `World`, `Zone`, `Map`, `Area` |
| Interactive map elements | **`DestroyableObject`** | `Object`, `Destructible`, `Prop`, `Target` |
| Player database container | **`PlayerProfile`** | `PlayerData`, `UserData`, `SaveData`, `Profile` |

---

## Network Remote Names

Communication contracts must follow this exact naming standard:

- **`RequestDestroy`**
  - Fired by client to notify the server that the visual sequence of destroying a Main Object was completed.
- **`RequestRebirth`**
  - Fired by client to request a Rebirth progression reset.
- **`UnlockUpgrade`**
  - Fired by client to request unlocking a new Growth Upgrade.
- **`EquipUpgrade`**
  - Fired by client to request equipping/activating an unlocked Growth Upgrade.
