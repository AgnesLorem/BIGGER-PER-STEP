# Project Roadmap - Bigger

This document outlines the development path for Bigger, dividing progression into the initial Minimum Viable Product (MVP) and future feature expansions.

---

## Milestone 1: Minimum Viable Product (MVP - v0.1.0)

The goal of the MVP is to establish the core gameplay loop and progression loop in their simplest functional forms.

### Core Deliverables
- **Movement & Scaling**: Base character controller enabling players to walk and automatically gain Size over time. Visual growth feedback mapping player model scale to Size.
- **Portals & Objectives**: A functional Lobby hub with multiple Portals. Stepping into a portal loads the player into an isolated area containing exactly one Main Destroyable Object.
- **Destruction Loop**: Interacting with and destroying the Main Object grants the player a Destruction reward, followed by an immediate teleport back to the Lobby.
- **Growth Upgrades Shop**: An upgrade shop enabling players to permanently unlock and equip linear themed Growth Upgrades. Equipped upgrades boost Size accumulation rate.
- **Rebirth System**: A Rebirth option that resets temporary progress (Size) in exchange for permanent multipliers.
- **Persistence**: Stable saving and loading of player profiles, along with basic timestamp-based offline size generation.

---

## Milestone 2: Post-MVP & Future Expansions

Features in this milestone aim to increase player retention, add visual polish, and expand content depth once the core loop is proven.

### Target Areas
- **Expanded World Zones**: Introduction of progressive zones beyond the initial Lobby, requiring higher Destruction or Rebirth counts to unlock.
- **Destruction Visual Polish**: Physics-based object shattering, advanced particle debris, and dynamic screen-shake effects when destroying Main Objects.
- **Enhanced Configuration Tools**: Visual tools or schemas to easily author and modify portal requirements, upgrade lists, and rebirth thresholds.
- **Progression Sink Mechanics**: Unlocking late-game world zones or portals that consume Destruction or require specific rebirth milestones.
