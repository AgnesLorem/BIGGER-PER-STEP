# Game Design Document - Bigger

Bigger is an incremental Roblox game where players grow in size and destroy objects to progress. It is inspired by Shrink per Step, but shifts the core fantasy from becoming smaller to becoming bigger and destroying everything.

---

## Core Gameplay Loop

Every gameplay system must support and reinforce the core gameplay loop:

1. **Walk**: The player moves around the lobby/zones.
2. **Gain Size**: The player's size grows over time or through movement.
3. **Reach Portal Requirement**: The player grows large enough to meet a portal's entrance requirements.
4. **Enter Portal**: The player steps into a portal to enter an objective area.
5. **Destroy Main Object**: The player interacts with and destroys the single main object inside the portal.
6. **Choose Portal Reward**: Completing the objective activates one free and one optional paid reward portal while the player remains inside the private world.
7. **Earn Destruction**: The selected reward path grants one authoritative Destruction reward; paid rewards are delivered only by the durable receipt path.
8. **Teleport Back to Lobby**: Settling the reward choice returns the player to the central lobby.
9. **Unlock New Growth Upgrade**: The player unlocks advanced Growth Upgrades based on progression.
10. **Equip Growth Upgrade**: The player equips the unlocked Growth Upgrade.
11. **Grow Faster**: The equipped Growth Upgrade increases the speed at which the player gains size.
12. **Reach Next Portal**: The player goes after portals with higher size requirements.
13. **Rebirth**: The player resets temporary progression to permanently boost future growth.
14. **Repeat**.

---

## Core Resources

- **Size**
  - Represents the player's physical scale.
  - Serves as the player's Level.
  - Resets to default on Rebirth.
- **Destruction**
  - A permanent progression milestone resource earned by completing Portal objectives.
  - Aligned with "Wins" in other incremental games. Not Coins, Cash, or Gold.
  - Cannot be spent in the MVP.
- **Growth Upgrade**
  - Permanent unlocks that boost the player's GrowthMultiplier.
  - Only one Growth Upgrade can be active/equipped at any given time.
- **Rebirth**
  - A progression reset action.
  - Resets temporary resources (Size) in exchange for permanent growth boosts.

---

## Portal Rules

- **One Portal = One Objective**: Every Portal contains exactly one Main Destroyable Object.
- **No Side Content**: No combat, no dungeon exploration, and no multiple objectives inside a portal.
- **Reward Selection**: Completing an objective activates exactly one free and one optional paid reward path. Objective completion itself grants nothing.
- **Teleportation**: Settling the selected reward path automatically teleports the player back to the Lobby. The Lobby serves as the central hub of progression.

---

## Growth Upgrade Philosophy

- Growth Upgrades are progression milestones, not consumable items.
- Upgrades follow a strictly linear progression pathway.
- Upgrades do not have levels, enhancements, or duplicates.
- Upgrades have three states: Locked, Unlocked, Equipped.

---

## MVP Design Invariants

All systems, configurations, and future code must adhere to these invariants:

- **One Portal = One Objective**
- **One Objective = One Main Destroyable Object**
- **One Completion = One Settled Destruction Reward Choice**
- **One Growth Upgrade = One Permanent Unlock**
- **One Equipped Growth Upgrade per Player**
- **Rebirth = Reset Temporary Progress + Increase Permanent Progression**

---

## Non-Goals (MVP)

The MVP intentionally excludes the following features to maintain simplicity:
- Pets
- Trading
- Leaderboards
- PvP
- Crafting
- Guilds
- Skills
- Quests
- Daily rewards
- Timed events
