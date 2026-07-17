# Gameplay Changelog - Bigger

This changelog tracks gameplay-facing changes, features, balancing iterations, and bug fixes. It serves as a high-level progression log for developers and AI agents, independent of Git commit history.

---

## [v0.0.3] - 2026-07-16

### Security
- Removed two Studio-only free-model `Material` scripts that created the fake `Error 501` legacy `Message` overlay and cloned malicious command TextBoxes into `StarterGui`.
- Removed the remaining external loader chains associated with asset IDs `114706280708394`, `140312253726156`, `128320524036560`, and `90983637061475` without loading those assets or enabling additional capabilities.
- Published the remediated original cloud place as version 172 and verified two clean Play Solo runs with zero runtime security findings and zero Output errors or warnings.

### Fixed
- Removed the Studio-only custom `StarterCharacterScripts.Animate` subtree whose bare numeric walk ID produced `unknown AssetId protocol`; Roblox now supplies the default Animate system.
- Preserved `Big Island`, `ReturnSpawn`, `Portal_World1`, the WORLD1 template, `RuntimeWorlds`, and `MainHUD`; production portal entry still creates an owned WORLD1 objective.

---

## [v0.0.1] - 2026-07-13

### Added
- **MVP Specification**: Initial blueprint setup of 10 documentation files defining the conceptual architecture, gameplay loop, database schema rules, shop milestones, and terminology.
- **Progression Base**: Defined the primary size accumulation loop and rebirth reset mechanics.
- **Destruction Currency**: Replaced traditional "Wins" progression with the new authoritative "Destruction" theme.
- **Growth Upgrade Progression**: Configured a linear progression path of 8 permanent growth-themed upgrade tiers (None $\rightarrow$ Titan Serum).
