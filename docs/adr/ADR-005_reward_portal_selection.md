# ADR-005: Reward Selection Before Lobby Return

## Context

The original WORLD1 loop granted one Destruction and returned the player to the
Lobby immediately when the Spider objective completed. MVP-005 adds a deliberate
post-objective choice between a free reward and one repeatable paid reward. Paid
delivery must remain idempotent and durable even when Roblox delivers a receipt
after the original private world no longer exists.

## Decision

Completing the objective keeps the authoritative session `InWorld`, marks the
objective complete, disables further stomp processing, and activates two
server-owned reward portals. The free portal grants one Destruction and returns
immediately. The paid portal opens the single `World1TripleReward` Developer
Product at 29 Robux; only `ProcessReceipt` grants its three Destruction.

Each world owns the state machine `Inactive → Choosing → PromptOpen →
AwaitingReceipt → Settled` and an explicit prompt token/context. A durable
`DeveloperProductCommitted` notification may settle and return only the same
still-current world. Receipt granting remains independent of runtime world
correlation, so delayed receipts cannot lose a paid reward and cannot mutate a
newer world.

## Consequences

- `One Objective = One Main Destroyable Object` remains unchanged.
- One completion settles exactly one official reward-portal choice.
- The paid Developer Product is repeatable across separate WORLD1 runs.
- Runtime prompt correlation is best-effort and intentionally not a durable
  historical purchase-intent system.
- The player remains `InWorld` while choosing; `Returning` begins only after free
  settlement or a matching durable paid commit.
- Real purchase verification and production publication require a separately
  authorized private staging gate.
