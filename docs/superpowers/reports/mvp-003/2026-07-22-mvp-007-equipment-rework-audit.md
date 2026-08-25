# MVP-007 Equipment Rework Audit — 2026-07-22

#### Scope

This audit covers the MVP-007 equipment server/client contract, authoritative Level-gated unlocks, equip state, persistence queue integration, RemoteEvent request correlation, request lifecycle controls, bootstrap registration, controller lifecycle, exact boundary tests, and the minimum runtime-session fields required by those callers.

#### Findings

| Severity | Finding | Disposition |
| --- | --- | --- |
| HIGH | Unlock checks previously depended on inconsistent Level math. | Fixed by deriving solely from authoritative `Session.Bigger` through `LevelFormula`. |
| HIGH | The previous synchronous remote contract did not provide bounded correlation or robust lifecycle cleanup. | Reworked to request/response/state RemoteEvents with request IDs, timeout, pending cap, rate limit, and teardown. |
| HIGH | Required Studio persistence and multiplayer evidence cannot run because core boot stops on missing production IDs; client startup also waits for missing `MainHUD`. | Manual rerun required after blockers are resolved. |
| MEDIUM | Invalid persisted equipment state must not crash or silently unlock content. | Repaired/fails closed with regression coverage. |
| VERIFIED | Client-supplied Level is never accepted. | Server derives every unlock decision from `Session.Bigger`. |

#### Severity

All scoped offline code findings are resolved. Runtime release confidence remains **HIGH risk** until persistence and multiplayer scenarios run in a bootable Studio place.

#### Fixes

- Added server-owned request locking, timestamps, rate limiting, cleanup, and save queue calls for successful mutations.
- Added correlated client callbacks, malformed-state rejection, duplicate/unknown-response rejection, timeout, pending limit, and idempotent lifecycle.
- Preserved no-op/failed mutation behavior and avoided broad controller or progression redesign.
- Added exact Level boundary coverage for all equipment requirements.

#### Files Changed

The authoritative file list and exact-scope extensions are recorded in `tasks/MVP-007.md` and `docs/superpowers/plans/2026-07-21-mvp-007-equipment-system.md`, including reasons, affected callers, compatibility impact, and tests.

#### Verification

- Equipment unit suite passes, including actual RemoteEvent objects, handler idempotence, response correlation, malformed requests/state, rate limit, timeout, PlayerRemoving cleanup, save queue behavior, spoofed Player Level, and all seven requirement boundaries.
- Movement, stomp, and save regression suites pass.
- StyLua, Selene, Rojo build, `git diff --check`, and source/Studio script parity pass.
- Play Solo confirms the equipment remotes are not created because server bootstrap never reaches game-service registration after the Game Pass validation blocker.
- Persistence and multiplayer gameplay verification: **MANUAL REQUIRED** after Studio blockers are resolved.

#### Remaining Risks

- Live DataStore queue/flush behavior for unlock and equip mutations has not been exercised in Studio.
- Concurrent multi-client request isolation has offline coverage but still needs the required Studio multiplayer run.
- The active place's missing `MainHUD` prevents interactive client equipment QA.

#### Release Decision

**READY_FOR_STUDIO_QA** — scoped code and offline tests are ready, but release is not approved. Resolve the production configuration and UI asset blockers, then run persistence, reconnect, and multiplayer validation before changing this decision to `READY`.
