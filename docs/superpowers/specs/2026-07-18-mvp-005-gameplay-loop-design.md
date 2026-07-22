# MVP-005 Gameplay Loop Design

## Status

```text
MVP005_PLANNING: APPROVED
PAID_PORTAL_PRODUCT: ONE PRODUCT AT 29 ROBUX
VIP_DISCOUNTED_PRODUCT: REMOVED
GAMEPASS_QUERY_RACE_PROTECTION: REQUIRED
RECEIPT_WORLD_CORRELATION: REQUIRED
SOURCE_IMPLEMENTATION: AUTHORIZED AFTER EXACT PATH SCOPE IS RECORDED
PLACEHOLDER_MONETIZATION_IDS: APPROVED_DEFERRED_CONFIGURATION
LIVE_MONETIZATION_QA: DEFERRED
```

## Design Summary

WORLD1 retains its Level 5 server-authoritative entry and Spider stomp. Entry
shows `STOMP THE SPIDER` for three seconds. A valid stomp completes only the
objective and activates two native reward portals while the player remains
`InWorld`. Free grants one Destruction and returns. Paid prompts one 29 Robux
portal-only Developer Product; only its durable receipt grants three Destruction,
after which a matching runtime prompt may return the same world.

`RewardPortalService` owns reward-choice lifecycle and correlation.
`GamePassService` owns race-safe VIP and Premium Zone ownership. Existing services
remain responsible for stomp validation, Destruction mutation, reward dispatch,
receipt durability, save serialization, world cleanup, and session transitions.

## Monetization and Authority

Custom monetization thumbnails are user-approved for deferral to a future
visual-polish milestone. MVP-005 uses Roblox default asset imagery temporarily;
missing custom thumbnails do not block implementation, Studio verification, code
review, or completion. The current MVP keeps explicit `0` placeholders for VIP,
Premium Zone, and `World1TripleReward`; these mark their monetization features
unavailable. No VIP-discount product or dynamic price exists. When production
configuration is supplied, the Developer Product is unlisted, repeatable, has
managed pricing disabled, and uses
`Surface = "PortalOnly"`; normal Bigger products use `Surface = "Shop"`.

Placeholder IDs are valid deferred configuration, not purchasable IDs. Services
must not query ownership, prompt, simulate ownership, dispatch receipts, or grant
rewards for ID `0`. Replacing placeholders later is config-only and requires no
service rewrite or data migration. Live purchase QA is outside this MVP gate.

Paid authority is strictly `ProcessReceipt → RewardService → RewardDispatcher →
DestructionService:GrantDestruction → SaveService:CommitTransaction →
DeveloperProductCommitted`. The lifecycle event is emitted once, only after
durability, and carries `(Player, ProductKey, PurchaseId)`. It never grants.

The reward state machine and prompt context are exactly those defined in
`tasks/MVP-005.md`. A delayed receipt always grants and saves once, but settles a
world only when every current runtime identity and token check succeeds.

## Game Passes and Profile

Schema v1 gains additive `HasPremiumZonePass = false`. VIP retains tag and global
growth x2. Premium Zone only opens AFKZone7. `GamePassService` uses independent
generation tokens for `Vip` and `PremiumZone`; stale or failed queries never
overwrite a newer authoritative result. Changed results are combined into one
session mutation and save when practical. Prompt-finished events only re-query.

## WORLD1 Presentation

Objective popup timing is full opacity at 0.0 seconds, fade beginning at 2.5, and
hidden at 3.0. A local generation token supersedes older timers/tweens without
changing server objective attributes.

WORLD1 contains exact, non-recursive portal paths:

```text
FreeRewardPortal/{Visual,Trigger,LabelPart/SurfaceGui/TextLabel}
PaidRewardPortal/{Visual,Trigger,LabelPart/SurfaceGui/TextLabel}
```

Free is green with `FREE • 1 DESTRUCTION`; paid is gold/purple with
`3 DESTRUCTION • 29 R$`. Both begin hidden and non-interactive.

## AFK Zones and Growth

Seven invisible, non-colliding triggers use descending deterministic priority.
AFKZone1–6 are free at `1, 2, 2.5, 3, 3.5, 4`; AFKZone7 is Premium-only at 4.5.
A locked highest-priority zone awards zero without fallback. Premium prompts once
per physical entry and verified ownership applies next tick.

Growth calculation remains unfloored until `GrowthService` combines it with the
runtime-only session remainder. Bigger mutation succeeds before remainder is
consumed. The remainder is not persisted.

## Failure and Verification Design

Missing placeholder product/pass IDs disable only their monetization feature and
warn once; invalid configured metadata and integrity violations remain fatal.
Missing exact portal children fail WORLD1 preparation and recover safely. Wrong players, wrong worlds,
duplicate touches, stale prompts, stale pass queries, frozen profiles, overflow,
and mismatched receipts fail closed.

Unit and synthetic Studio coverage, exact repository scope, commands, asset limits,
and the final three-line release status are authoritative in `tasks/MVP-005.md`
and duplicated in the implementation plan.
