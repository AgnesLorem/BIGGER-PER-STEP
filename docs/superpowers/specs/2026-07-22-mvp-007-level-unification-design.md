# MVP-007 Level Unification Design

**Status:** Approved design  
**Date:** 2026-07-22  
**Milestone:** Targeted prerequisite for MVP-007 equipment unlock correctness

This is a targeted prerequisite for MVP-007 equipment unlock correctness.
It restores consistency with existing player-visible progression and is not a
new economy redesign.

## 1. Problem statement

The repository currently derives Level in two incompatible ways. Player Level,
HUD progress, and avatar scaling use the established fourth-root curve, while
`LevelFormula` uses `Bigger / 10`. Equipment and portal authorization call
`LevelFormula`, so a player can see one Level while the server validates another.

`Bigger` is the authoritative persisted value. Level is derived state. Every
producer and consumer must derive from the same pure calculation, and no server
authorization path may trust a client attribute or payload.

## 2. Existing conflicting formulas

The existing player-visible path is:

```luau
math.floor((Bigger / 236) ^ 0.25) + 1
```

It is duplicated in `SessionService`, `GrowthService`, `GuiController`, and
`ScaleCurve`.

The conflicting shared formula is:

```luau
math.floor(Bigger / 10) + 1
```

`EquipmentService` and Level-gated portals consume that linear result. Task and
progression specifications define Level-gated behavior but do not approve the
linear rebalance.

## 3. Chosen canonical formula

`src/shared/Game/Progression/LevelFormula.luau` becomes the only module that
converts Bigger to Level or Level to a Bigger requirement.

```text
Level = floor((Bigger / 236) ^ 0.25) + 1
Requirement(Level) = 236 * (Level - 1) ^ 4
```

Required exact values:

| Level | Bigger requirement |
| ----: | -----------------: |
| 1 | 0 |
| 5 | 60,416 |
| 10 | 1,548,396 |
| 25 | 78,299,136 |
| 50 | 1,360,493,036 |
| 100 | 22,670,065,836 |
| 200 | 370,104,451,436 |
| 500 | 14,632,353,528,236 |

This preserves the Level curve already visible through Player attributes, HUD,
and avatar size.

## 4. Rejected alternatives

### Keep `Bigger / 10`

Rejected because it silently rebalances progression and contradicts current
player-visible Level behavior.

### Import the unmerged milestone `BalanceConfig`

Rejected because it introduces a separate staged progression design that is not
approved by MVP-005 or MVP-007.

### Preserve formulas in each consumer

Rejected because duplicated math caused the mismatch and cannot guarantee future
boundary consistency.

## 5. Authoritative data flow

```text
Persisted profile Bigger
        |
        v
RuntimeRegistry Session.Bigger
        |
        +--> LevelFormula --> SessionService/GrowthService --> Player Level attribute
        +--> LevelFormula --> EquipmentService/PortalService authorization
        +--> LevelFormula.GetProgress --> GuiController presentation
        +--> ScaleCurve --> CharacterScaleService server-side R15 scaling
```

The server owns `Session.Bigger`, derives Player Level, validates unlocks and
rewards, and applies avatar scaling. The client may use the shared progress helper
for presentation only.

## 6. Module APIs

### `GetLevelFromBigger(Bigger): number`

- Accepts a finite, non-negative number whose magnitude does not exceed Luau's
  maximum safe integer (`9,007,199,254,740,991`).
- Fractional Bigger is allowed for deterministic presentation, although persisted
  Bigger remains integral and MVP-005 stores fractional growth separately.
- Rejects invalid type, NaN, infinity, negative, and unsupported overflow values.
- Returns Level 1 for Bigger 0.
- Corrects the fourth-root estimate against exact requirements before returning.

### `GetRequirementForLevel(Level): number`

- Accepts a finite positive integer Level.
- Rejects invalid type, NaN, infinity, zero, negative, fractional, or overflowing
  inputs.
- Returns 0 for Level 1.
- Returns only requirements that remain exactly representable for supported game
  values.

### `GetProgress(Bigger): LevelProgress`

Returns:

```luau
{
    Level = number,
    CurrentRequirement = number,
    NextRequirement = number,
    BiggerIntoLevel = number,
    BiggerRequiredForNextLevel = number,
    Progress = number,
}
```

`Level` comes from `GetLevelFromBigger`. Requirements come from
`GetRequirementForLevel`. `Progress` is clamped to `[0, 1]`. At an exact new
Level requirement, `BiggerIntoLevel` and `Progress` are both zero.

The module remains `--!strict`, stateless, and frozen.

## 7. Consumer integration

### Session and growth

`SessionService` derives the initial Player `Level` attribute from
`Session.Bigger`. `GrowthService` repeats that derivation after a successful
authoritative Bigger mutation. Neither retains progression math. Existing
fractional growth ordering and remainder behavior remain unchanged.

### HUD

`GuiController` reads the replicated Player Level for display state and calls
`LevelFormula.GetProgress` with replicated Bigger for presentation progress. It
does not derive an authoritative Level, send Level to the server, or retain the
fourth-power requirement formula. Missing attributes use safe presentation
defaults and do not crash. Existing connection lifecycle is preserved and made
idempotent where the touched behavior requires it.

### Avatar scaling

`ScaleCurve` routes its existing `level` formula through `LevelFormula` and keeps
the current public `GetVisualScale(Bigger, Formula?, CurveParameter?)` contract.
`CharacterScaleService` remains the server-side caller and does not require an
interface change.

### Equipment and portals

`EquipmentService` and Level-gated portal validation derive Level directly from
authoritative `Session.Bigger`. Player attributes and client payloads never grant
authority. Missing, frozen, or invalid sessions fail closed.

## 8. Floating-point boundary strategy

The fourth root is used only to obtain an initial Level candidate. The canonical
implementation then compares Bigger with exact integer requirements:

1. Decrement while the candidate's requirement is greater than Bigger.
2. Increment while the next Level requirement is less than or equal to Bigger.
3. Return the corrected candidate.

This makes `requirement - 1`, `requirement`, and `requirement + 1` exact without a
broad tolerance. Inputs and calculated requirements are bounded by Luau's safe
integer range before arithmetic that could overflow.

## 9. Dependency direction

`LevelFormula` is a leaf shared module and depends only on Luau math/table
functions. Server and client consumers depend on it; it never imports a service,
controller, config, or mutable registry.

`ScaleCurve` has a one-way dependency on `LevelFormula`. `LevelFormula` does not
depend on `ScaleCurve`, so no cycle is introduced. Server authority remains above
both pure shared modules.

## 10. Compatibility impact

- Player-visible Level progression remains unchanged.
- Existing persisted Bigger values derive the same Level previously shown by the
  Player attribute, HUD, and avatar.
- Equipment and portal gates that previously used `Bigger / 10` move to the
  visible fourth-root thresholds.
- No currency values, reward amounts, prices, growth multipliers, or offline
  progression formulas change.
- `ScaleCurve.GetVisualScale` keeps its public signature and output for an
  equivalent canonical Level.
- MVP-005 fractional growth remains separate from integral `Session.Bigger`.

## 11. No-migration rationale

Level is not the persisted source of truth. Existing profiles persist Bigger,
and sessions already rebuild a derived Level attribute. Deploying the unified
formula only changes derivation and authorization; it does not rewrite profile
data or require a migration marker.

## 12. Security and authority constraints

- The server derives Level from `Session.Bigger` for every unlock or reward gate.
- `Player:GetAttribute("Level")` is presentation state, never authorization.
- Equipment requests contain operation data, not trusted Level.
- Spoofed high attributes cannot bypass a low authoritative Bigger value.
- A stale low attribute cannot block a valid unlock when authoritative Bigger is
  sufficient.
- Invalid or unavailable sessions fail closed and do not mutate, reward, or queue
  a save.

## 13. Test matrix

For Levels 5, 10, 25, 50, 100, 200, and 500, tests use each exact requirement at
three Bigger values: `requirement - 1`, `requirement`, and `requirement + 1`.

| Boundary | Formula | Session/attribute | HUD | Scale | Equipment | Portal |
| --- | --- | --- | --- | --- | --- | --- |
| requirement - 1 | previous Level | previous Level | previous Level/progress | previous scale Level | reject | reject if gated |
| requirement | target Level | target Level | target Level/progress 0 | target scale Level | allow when other rules pass | allow if gated |
| requirement + 1 | target Level | target Level | target Level/progress > 0 | target scale Level | allow when other rules pass | allow if gated |

Additional coverage:

- Level 1, Bigger 0, invalid types, NaN, infinity, negative values, large supported
  Bigger, monotonicity, inverse consistency, and progress clamping.
- Actual `SessionService` load and `GrowthService` mutation behavior for two
  isolated Players.
- HUD behavior with replicated attributes, exact boundary reset, and missing
  attributes.
- Actual `ScaleCurve` output at Level boundaries.
- Equipment spoofing, predecessor/currency rules, no auto-equip, and save queue
  only after successful mutation.
- Portal spoofing, authoritative boundary behavior, and closed failure when the
  session is unavailable or frozen.

Consumer tests must exercise their actual boundary; repeatedly calling
`LevelFormula` alone is not evidence of integration.

## 14. Rollback considerations

The code rollback is limited to the shared formula and its consumer routing.
Because no profile data is migrated, rollback does not require data repair.

Rollback would restore the known authorization mismatch, so it is acceptable only
as an emergency code rollback. Any profile mutations produced by normal unlocks
remain valid profile data and are not automatically reversed.

## 15. Scope boundaries

In scope:

- Canonical Level math, inverse, progress, and numeric validation.
- Session/Growth Player Level integration.
- HUD progress and avatar scale integration.
- Equipment and Level-gated portal authority tests and routing.
- Exact MVP-005/MVP-007 task and plan scope amendments.

Out of scope:

- New progression curves or milestone tables.
- Economy, price, reward, multiplier, or offline progression rebalance.
- Persisting Level or migrating Bigger.
- Broad HUD/controller or character-scaling rewrites.
- Client authority for Level, unlocks, portals, or rewards.
- Importing the unmerged `BalanceConfig` work.

The implementation uses the fewest existing modules needed: one canonical math
module and direct consumer routing, with no new abstraction layer or dependency.

## 16. Specification self-review

- **Formula and inverse:** all seven required thresholds were recalculated from
  `236 * (Level - 1) ^ 4` and match the approved values.
- **Floating-point boundaries:** the design requires exact requirement correction,
  not tolerance-based assertions.
- **Authority:** every mutation gate derives from server-owned `Session.Bigger`;
  replicated Level remains presentation-only.
- **Dependencies:** `LevelFormula` is a leaf; the one-way `ScaleCurve` dependency
  does not form a cycle.
- **Responsibilities:** the server owns Level authority and R15 scaling; the
  client owns presentation only.
- **Persistence and compatibility:** no schema or Bigger migration is needed;
  fractional growth and public `ScaleCurve` arguments remain unchanged.
- **MVP integration:** MVP-005 growth semantics are preserved and MVP-007 unlocks
  move to the same Level players see.
- **Testability:** each real consumer boundary has explicit assertions, including
  two-Player isolation and all required equipment thresholds.
- **Scope:** the task and both implementation plans name every additional path
  before source edits. No unrelated progression or economy work is included.
- **Placeholder/ambiguity scan:** no unresolved placeholders remain; invalid
  numeric inputs are rejected and the supported numeric bound is explicit.
