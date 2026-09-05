# MVP-007 Targeted Level Unification Audit — 2026-07-22

#### Scope

This is the targeted prerequisite fix for MVP-007 authoritative equipment unlock validation. It traces and unifies `LevelFormula`, session and Player `Level` attributes, HUD display/progress, avatar scale input, equipment unlock checks, portal validation, tests, task documents, specifications, and existing progression configuration. It is not a separate progression feature.

#### Findings

| Severity | Finding | Disposition |
| --- | --- | --- |
| HIGH | The repository contained competing Level calculations, including a linear `Bigger / 10` path that disagreed with the player-visible curve. | Fixed by one shared server-authoritative fourth-root calculation. |
| HIGH | Equipment unlock validation could disagree with HUD, Player attributes, and avatar scaling for the same `Session.Bigger`. | Fixed; all consumers now use or derive from `LevelFormula`. |
| MEDIUM | Invalid/frozen progression input needed explicit fail-closed behavior. | Fixed in formula, equipment validation, and portal validation. |
| VERIFIED | Existing player-visible progression is preserved; no economy rebalance or data migration is required. | Exact inverse boundary tests cover Levels 5, 10, 25, 50, 100, 200, and 500. |

#### Severity

All identified implementation findings are resolved. Runtime validation remains **HIGH** until Studio can boot past the unrelated-but-blocking production configuration and UI asset failures.

#### Fixes

- Established `LevelFormula` as the single calculation and inverse source of truth.
- Delegated session attributes, HUD progress, avatar scaling input, equipment unlocks, and portal checks to the canonical formula.
- Added finite/nonnegative numeric safety, exact inverse corrections, and progress clamping.
- Removed duplicated client Level math while retaining client display derivation from authoritative `Bigger`.

#### Files Changed

The exact Level-unification extension, reason, affected callers, compatibility impact, and tests are recorded in `tasks/MVP-005.md`, `tasks/MVP-007.md`, the dated Level design specification, and both implementation plans.

#### Verification

- Offline tests prove that server unlock validation, session/Player Level, HUD Level, and avatar scaling input resolve identically for the same Bigger value.
- Boundary coverage runs immediately below, exactly at, and immediately above Level requirements 5, 10, 25, 50, 100, 200, and 500.
- Formula inverse, monotonicity, invalid values, missing attributes, fractional growth, idempotent lifecycle, and two-player isolation are covered.
- StyLua, Selene, Rojo build, `git diff --check`, and source/Studio script parity pass.
- Play Solo runtime parity: **MANUAL REQUIRED** after Studio boot blockers are resolved.

#### Remaining Risks

- The active place cannot currently expose live session attributes or avatar scale behavior because server boot stops before game services register.
- The missing `MainHUD` prevents visual HUD confirmation despite offline controller coverage.

#### Release Decision

**READY_FOR_STUDIO_QA** — offline implementation and regression evidence are complete. Final runtime approval requires resolving the Game Pass configuration and `MainHUD` blockers, then repeating Play Solo and multiplayer parity checks.
