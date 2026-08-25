# MVP-007 Equipment Runtime Follow-up Audit — 2026-07-22

#### Scope

This follow-up verifies the reworked MVP-007 equipment RemoteEvent contract after core boot was unblocked. It covers service registration, singleton remotes, initial state, response correlation, malformed request rejection, restart idempotence, HUD coexistence, source parity, and remaining persistence/multiplayer gates.

#### Findings

| Severity | Finding | Disposition |
| --- | --- | --- |
| HIGH | Prior Studio evidence could not reach `EquipmentService:Init()` because optional Game Pass validation aborted bootstrap. | Resolved; equipment registered in both Play Solo cycles despite all three optional monetization IDs being absent. |
| VERIFIED | `BiggerEvents.Equipment` contained exactly one `Request`, one `Response`, and one `StateChanged` RemoteEvent in each cycle. | Passed. |
| VERIFIED | Initial persisted equipment state returned `EquippedUpgrade = None`. | Passed in both cycles. |
| VERIFIED | An `Unlock` request with a missing `UpgradeId` returned one correlated response with `Success = false` and `ErrorCode = InvalidRequest`. | Passed in both cycles. |
| VERIFIED | Restart did not duplicate handlers: each state and invalid request produced exactly one matching response. | Passed. |
| MEDIUM | Live unlock/equip persistence, leave/rejoin restore, and cross-player response isolation were not automated by the connected Studio tool. | `MANUAL REQUIRED`; offline service/lifecycle coverage passes. |

#### Severity

No Critical or High equipment boot/correlation defect remains. Required persistence and multiplayer evidence keeps the milestone at **READY_FOR_STUDIO_QA**.

#### Fixes

- Equipment startup is now independent of optional monetization configuration.
- The server retains authoritative unlock validation from `Session.Bigger` through `LevelFormula`.
- The RemoteEvent contract remains bounded and correlated, with idempotent initialization, rate/lock state in the runtime session, save queue integration, and client timeout/cleanup.

#### Files Changed

The authoritative exact scope, callers, compatibility impact, and tests are recorded in `tasks/MVP-007.md` and `docs/superpowers/plans/2026-07-21-mvp-007-equipment-system.md`. This report is a new immutable evidence cycle.

#### Verification

- Equipment unit tests pass for all seven Level boundaries, spoofed Player Level, invalid/malformed requests, one-response correlation, duplicate/unknown response handling, rate limit, pending cap, timeout, save queue behavior, PlayerRemoving cleanup, and duplicate lifecycle calls.
- Both Play Solo cycles returned a successful `GetState` response and a single correlated `InvalidRequest` response.
- Remote counts remained 1/1/1 after restart; the canonical `MainHUD` and `ObjectiveGui` coexisted without blocking equipment startup.
- Missing monetization IDs produced warnings only and did not affect equipment runtime.
- All modified source files match the active Studio source by normalized checksum.

#### Remaining Risks

- A live successful unlock/equip/unequip plus save/rejoin round trip remains `MANUAL REQUIRED`.
- Two-player cross-correlation, Player A/B mutation isolation, independent save queues, and PlayerRemoving cleanup remain `MANUAL REQUIRED` in Studio.
- Production IDs are not an equipment blocker, but they still block MVP-005 release.

#### Release Decision

**READY_FOR_STUDIO_QA** — boot, singleton remotes, state read, invalid-request rejection, response correlation, and restart idempotence pass in Play Solo. Do not promote to `READY` until persistence and multiplayer evidence pass.
