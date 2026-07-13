# ADR-002: Destruction Replaces Wins

## Context
Standard Roblox simulator patterns typically use "Wins" as the primary permanent milestone resource. While easily understood, generic naming conventions like "Wins" or "Coins" fail to reinforce the specific gameplay loop and fantasy of *Bigger* (which focuses on growing larger and destroying objects). 

## Decision
We will replace the conceptual "Wins" milestone resource with **Destruction** as the permanent progression tracker.
- Destruction is awarded upon successful completion of a world instance's main objective (destroying the main object).
- Destruction acts as a permanent progression milestone (similar to "Wins" in other incremental games).
- It cannot be spent as a currency in the MVP, but serves to unlock access to later portals and upgrade tiers.

## Consequences
- **Stronger Thematic Identity**: Progression naming directly reinforces the player's actions (destroying objects to gain Destruction).
- **Decoupled Mechanics**: Clearly distinguishes permanent progression milestones from potential future secondary spendable currencies.
- **Narrative Alignment**: Fits naturally with the growth and demolition theme of the game.
