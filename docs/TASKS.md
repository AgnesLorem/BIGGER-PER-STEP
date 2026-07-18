# High-Level Project Tasks - Bigger

This document tracks the high-level milestones for the Bigger project MVP. 

> [!NOTE]
> TASKS.md tracks high-level project milestones only. Implementation task breakdown belongs outside the documentation if a dedicated task workflow is introduced later.

---

## MVP Milestones Checklist

- [ ] **Infrastructure & Setup**
  - Establish directory structures for client, server, and shared directories.
  - Setup and validate the shared configuration loader.

- [x] **Data & Save System (MVP-004)**
  - Implement native `DataStoreService` persistence with per-UserId FIFO workers and leases.
  - Build the server-authoritative player profile lifecycle, autosave, final save, and bounded shutdown.
  - Add atomic timestamp-based offline progression and durable Developer Product receipts.

- [ ] **Game Pass Monetization (Future MVP)**
  - Create approved 2X Multiplier and VIP passes and private staging resources.
  - Add ownership reconciliation, purchase prompting, and real-purchase QA.

- [ ] **Size & Growth Mechanics**
  - Implement walk-based and movement-based size accumulation.
  - Bind client-side character scaling visual systems to size changes.

- [ ] **Portals & World Zones**
  - Implement portal entrance requirement checks on the server.
  - Set up lobby zone loading and teleportation gateways.
  - Create isolated portal instances containing single Main Destroyable Objects.

- [ ] **Destruction Logic**
  - Implement interaction logic for destroying Main Objects.
  - Connect Destruction rewards and trigger lobby teleports upon objective completion.

- [ ] **Growth Upgrades Shop**
  - Build the Upgrade Shop service to handle unlock and equip events.
  - Implement the linear progression sequence.

- [ ] **Rebirth System**
  - Create the rebirth reset mechanic on the server.

- [ ] **Player Interface (UI)**
  - Design simple visual indicators for Size, Destruction, and Rebirths.
  - Create Shop interfaces for unlocking and equipping Growth Upgrades.
