# ADR-003: Extension First Framework

## Context
As Roblox codebases grow, they often accumulate technical debt due to hardcoded gameplay behaviors embedded directly inside core services. This tightly couples system logic with specific content, making refactoring difficult and leading to instability.

## Decision
The Bigger runtime framework will follow a strict **Extension-First Philosophy** and a **Content-Driven Architecture**:
- Core systems (`SessionService`, `SaveService`, `WorldInstanceService`, etc.) must remain reusable, stable, and decoupled from gameplay definitions (e.g., specific worlds, upgrades, or models).
- All new content must be introduced via configurations, definitions, and components rather than system modifications.
- Modifications to core services require an architectural, reusable justification. Single-use gameplay mechanics must be implemented strictly by extending the base systems.

## Consequences
- **High Core Stability**: Core runtime logic is written once and remains unchanged across updates.
- **Frictionless Content Pipeline**: Adding a new zone, portal, or destroyable object requires zero runtime execution code modification. Content creators only create models, set configurations, and define requirements.
- **Highly Reusable Framework**: The Core framework remains generic, allowing it to be repurposed for other simulator projects (e.g., "Mining Simulator" or "Shrink Simulator") by swapping only the gameplay definitions and assets.
- **Strict Guardrails**: Forces developers and AI systems to seek architectural solutions (e.g., designing generic objective components) rather than patching hardcoded overrides into core services.
