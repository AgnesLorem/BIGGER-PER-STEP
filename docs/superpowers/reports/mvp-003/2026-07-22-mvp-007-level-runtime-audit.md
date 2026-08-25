# MVP-007 Level Runtime Follow-up Audit — 2026-07-22

#### Scope

This follow-up verifies the targeted MVP-007 Level-unification prerequisite after removing the optional-monetization boot blocker. It covers canonical Player attributes, HUD presentation derivation, avatar scaling input, growth mutation, exact equipment requirements, source parity, and two Play Solo restart cycles. It does not change the approved progression curve or economy.

#### Findings

| Severity | Finding | Disposition |
| --- | --- | --- |
| HIGH | Prior Studio evidence could not observe live Level consumers because boot stopped before session creation. | Resolved; two clean Play Solo cycles now expose Player attributes, HUD, avatar scales, and equipment runtime. |
| VERIFIED | At `Bigger = 51307`, canonical formula, Player `Level`, and HUD-derived Level all resolved to `4`; ScaleCurve expected `1.6` and R15 `BodyHeightScale` was `1.6`. | Passed. |
| VERIFIED | Movement growth changed `Bigger` from `51307` to `51309`; Player Level and HUD progress immediately remained consistent with `LevelFormula`. | Passed. |
| VERIFIED | The second restart again resolved `Bigger = 51314` to Level `4` and scale `1.6`. | Passed without duplicate runtime objects or errors. |
| MEDIUM | Required automated two-player isolation evidence is unavailable through the connected Studio tool. | `MANUAL REQUIRED`; covered offline but not claimed as Studio-verified. |

#### Severity

No Critical or High Level-unification defect remains in the executed scope. The unexecuted multiplayer gate keeps the milestone at **READY_FOR_STUDIO_QA**.

#### Fixes

- The canonical fourth-root curve remains `floor((Bigger / 236) ^ 0.25) + 1`, with exact inverse boundary correction.
- Session creation, growth updates, HUD progress, avatar scaling, portal validation, and equipment unlock validation all derive from the shared `LevelFormula` boundary.
- `Session.Bigger` remains the server authority; no client-provided Level is accepted and no data migration is required.

#### Files Changed

The exact Level files, callers, compatibility impact, no-migration rationale, and tests are listed in `tasks/MVP-005.md`, `tasks/MVP-007.md`, the Level design specification, and the implementation plans. This audit adds evidence only; it does not broaden progression scope.

#### Verification

- Unit tests cover requirements immediately below, exactly at, and immediately above Levels 5, 10, 25, 50, 100, 200, and 500.
- Consumer tests exercise `SessionService`, `GrowthService`, `GuiController`, `ScaleCurve`, `EquipmentService`, and `PortalService` rather than only calling the formula repeatedly.
- Both Play Solo cycles showed `HasBigger = true`, `HasLevel = true`, Player Level equal to canonical Level, HUD progress equal to canonical progress, and body scale equal to canonical Level scale.
- The active Studio place is `Bigger Per Step` (`PlaceId 104031194350622`), and all 22 modified source files have normalized parity.
- No `Bigger / 10` path is used by the unified consumers.

#### Remaining Risks

- Two-player live isolation and independent growth/Level updates remain `MANUAL REQUIRED`.
- Exact Level 5/10/25/50/100/200/500 transitions are exhaustively covered offline but were not forced into the persisted Studio test profile.

#### Release Decision

**READY_FOR_STUDIO_QA** — offline boundary coverage, source parity, growth mutation, and two Play Solo runtime cycles pass. Do not promote to `READY` until required multiplayer evidence is recorded.
