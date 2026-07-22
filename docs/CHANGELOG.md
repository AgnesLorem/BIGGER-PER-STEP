# Gameplay Changelog - Bigger

This changelog tracks gameplay-facing changes, features, balancing iterations, and bug fixes. It serves as a high-level progression log for developers and AI agents, independent of Git commit history.

---

## [Unreleased: MVP-005] - 2026-07-18

### Approved Scope
- Approved the WORLD1 objective popup, post-stomp reward selection, one portal-only 29 Robux triple-reward Developer Product, VIP and Premium Zone Game Pass ownership, seven AFK zones, and fractional growth accumulation.
- Removed the earlier VIP-discounted 19 Robux Developer Product proposal; VIP retains its tag and global growth x2 but receives no paid-portal discount.
- User-approved custom monetization thumbnail deferral to a future visual-polish milestone; MVP-005 temporarily uses Roblox default asset imagery, and missing custom thumbnails are not an implementation, verification, review, or completion gate.

### Release Boundary
- Runtime IDs must be real and recorded after product creation; fake IDs are prohibited.
- Studio monetization evidence is synthetic unless private staging is separately authorized. Production publication is not authorized.

## [v0.0.4] - 2026-07-17

### Added
- Added schema-v1 native DataStore persistence with isolated Studio/Production scopes, validation, per-UserId FIFO workers, and 180-second leases.
- Added 60-second autosaves, atomic offline progression, durable idempotent Developer Product receipts, and concurrent final saves with a 25-second shutdown deadline.
- Added mutation freezing across authoritative profile mutation paths and a five-stage Studio persistence harness.

### Verification
- Passed movement, stomp, and save-system Lune suites, StyLua checks for `src` and `tests`, source Selene, and Rojo build.
- Passed five Studio-scope runs covering defaults, autosave, restoration, exact-once offline claims, mutation freeze, and final lease release.
- The pre-existing `GuiController` wait for `MainHUD.LeftSidebar` still warns during Play Solo and is outside the persistence change.

### Scope
- MVP-004 completion is limited to the native server-authoritative save system; durable Developer Product receipt processing remains included and verified.
- Game Pass creation, ownership reconciliation, prompting, private staging, and real-purchase QA are deferred to a future MVP. Placeholder entitlement products were removed from active runtime and shop configuration. No production place was published.

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
