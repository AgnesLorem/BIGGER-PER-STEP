# World Progression - Bigger

This document outlines the conceptual structure of World Zones and Portals. It does not hardcode progression thresholds or balancing values.

---

## World Zones

The map is partitioned into distinct spatial regions called **World Zones**. 
- The central zone is the **Lobby**, which acts as the main hub where players interact, shop for upgrades, and access portals.
- Players unlock subsequent World Zones by meeting progression requirements (e.g., reaching specific Rebirth counts).

---

## Portal Entrance Requirements

Each World Zone contains portals that lead to objective areas. To pass through a portal, a player must meet its authoritative entrance requirements.

To maintain a smooth learning curve and logical progression, the complexity of requirements scales:

### 1. Early Portals
- **Requirements**: Restrict entry based strictly on **Size**.
- **Intent**: Keep the initial gameplay loop straightforward, allowing players to focus entirely on walking and growing before learning complex requirements.

### 2. Later Portals
- **Requirements**: Require combinations of:
  - **Size** (representing current growth).
  - **Destruction** (representing overall milestone progress).
  - **Rebirths** (representing lifetime resets).
- **Intent**: Create layered goals that encourage players to balance upgrading, rebirth-resets, and portal completion.

---

## Objective Mapping

- Every portal leads to a single objective containing exactly **one** Main Destroyable Object.
- The server manages portal accessibility. A player who does not meet the portal's criteria will be blocked at the portal boundary on the server.
- The relationship between World Zones, Portal requirements, and rewards is defined entirely in data configuration files.
