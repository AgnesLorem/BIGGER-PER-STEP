# MVP-005 Optional-Monetization Runtime Unblock Audit — 2026-07-22

#### Scope

This follow-up audits the targeted prerequisite that lets non-monetized MVP-005/MVP-007 runtime systems boot when optional production monetization identifiers are absent. It covers the core bootstrap chain, Game Pass and Developer Product validation severity, receipt fail-closed behavior, paid/free reward-portal separation, `MainHUD` resolution, bounded GUI controller lifecycle, focused regression tests, Studio parity, and repeated Play Solo evidence. It is not a monetization redesign.

#### Findings

| Severity | Finding | Disposition |
| --- | --- | --- |
| HIGH | `GamePassService:Init()` threw on `PremiumZone.AssetId = 0` after `SaveService` disabled automatic character loading, aborting `SessionService`, `GameBootstrap`, character creation, HUD cloning, and equipment registration. | Fixed. Missing `Vip`/`PremiumZone` IDs now create structured feature-blocking statuses and one warning per key; unrelated boot continues. |
| HIGH | `ConfigValidationService` would next have thrown on `World1TripleReward.ProductId = 0`. | Fixed. A missing `PortalOnly` product ID is feature-blocking; invalid shop/reward/metadata integrity remains fatal. |
| HIGH | An unconfigured receipt or paid portal must never grant rewards or prompt with ID `0`. | Fixed and covered by service tests; the receipt remains `NotProcessedYet`, and the paid portal is unavailable/touch-disabled. |
| MEDIUM | `GuiController` and `ObjectiveController` used unbounded UI assumptions and did not tolerate `PlayerGui` replacement. | Fixed with bounded waits, stable statuses, late bind/rebind, idempotent connections, and teardown. |
| VERIFIED | `StarterGui.MainHUD` was present and correct in the active place. Its earlier runtime absence was downstream of the aborted server boot, which prevented character spawn and normal GUI cloning. | Confirmed in both Play Solo cycles; no placeholder HUD or Rojo mapping change was made. |

#### Severity

All runtime-isolation defects in this audit are resolved. MVP-005 remains **BLOCKED** because approved production IDs and production-like purchase/receipt evidence are still absent.

#### Fixes

- Added structured `IsConfigured`/`ErrorCode` results for optional Game Passes and the portal-only Developer Product.
- Kept malformed metadata, duplicate valid IDs, unsupported rewards, shop product IDs, and other integrity failures fatal.
- Skipped ownership queries and purchase prompts for unconfigured passes; did not synthesize ownership.
- Excluded product ID `0` from receipt dispatch and disabled the paid portal while preserving the free reward flow.
- Replaced unbounded HUD assumptions with one canonical `PlayerGui.MainHUD` resolver and bounded lifecycle handling.

#### Files Changed

The exact extension, reason, affected callers, compatibility impact, and required tests are recorded before implementation in `tasks/MVP-005.md`, `tasks/MVP-007.md`, and the two implementation plans. The implementation is limited to the relevant monetization services, reward portal, GUI controllers, and their unit harnesses.

#### Verification

- RED tests reproduced the Game Pass fatal error, Developer Product fatal error, paid-portal availability error, and missing-HUD lifecycle failures before implementation.
- GREEN tests prove warning-once behavior, fail-closed ownership/prompt/receipt behavior, free portal continuity, late HUD bind, `PlayerGui` reset/rebind, and cleanup.
- Movement, stomp, save, and equipment suites pass. The MVP-005 suite fails only its two explicit approved-production-ID assertions.
- StyLua, Selene, Rojo build, and `git diff --check` pass.
- All 22 modified local source files match the active `Bigger Per Step` Studio place by normalized UTF-8 length and checksum.
- Two Play Solo cycles reached `Server boot complete`, created a session and exactly one equipment remote set, cloned the canonical HUD, and emitted exactly one warning for each missing identifier with no runtime error or infinite yield.

#### Remaining Risks

- `Vip`, `PremiumZone`, and `World1TripleReward` still have ID `0`; real ownership, prompting, purchase cancellation, receipt commitment, and paid portal UX cannot be approved in production.
- The free portal is covered offline but was not entered interactively during these Play Solo probes.
- Automated two-player Studio execution is unavailable; multiplayer isolation remains `MANUAL REQUIRED`.

#### Release Decision

**BLOCKED** — optional configuration no longer blocks unrelated runtime QA, but MVP-005 cannot release until approved production IDs and production-like purchase/receipt plus required multiplayer evidence pass.
