# AGENTS.md - AI Coding Contract

This document establishes the mandatory contract and rules for all AI coding assistants (such as Antigravity, Claude, Codex, etc.) contributing to the **Bigger** repository. 

AI agents must read and adhere to this file before analyzing the codebase or writing code.

---

## 🚨 THE GOLDEN RULE (MANDATORY REQUIREMENT)

> [!CAUTION]
> **YOU MUST ALWAYS READ [`Jarvis.md`](.DaoGang/Jarvis.md) BEFORE WRITING ANY CODE.**
> - There are **NO exceptions** to this rule.
> - Before you change, create, or delete a single line of code in the repository, you must load and read the detailed style guides, Rojo layout requirements, and architecture constraints defined in [Jarvis.md](file:///f:/BIGGER/Jarvis/.DaoGang/Jarvis.md).
> - Skipping the loading or reading of `Jarvis.md` is considered a **critical contract breach**.

---

## The AI Precedence Chain

When analyzing requirements or implementing features, AI agents must strictly follow the workflow chain below:

```text
User Request
     ↓
Read AGENTS.md (Entry Contract)
     ↓
Read .DaoGang/Jarvis.md (Project Standard Rules)
     ↓
Read WORKFLOW.md (Pipeline & Checks)
     ↓
Read SYSTEM_PROMPT.md (Core Rules & Constraints)
     ↓
Read docs/GAME.md & Child Docs
     ↓
Read Active Task (tasks/MVP-xxx.md)
     ↓
Execution & Verification
```

---

## Architectural Documentation Reading Order

To build a consistent mental model before performing any task, AI agents must read the documentation files in the following exact order:
1. **[GAME.md](file:///f:/BIGGER/docs/GAME.md)** (Gameplay rules & core invariants)
2. **[ARCHITECTURE.md](file:///f:/BIGGER/docs/ARCHITECTURE.md)** (System layer separation & boundaries)
3. **[RUNTIME.md](file:///f:/BIGGER/docs/RUNTIME.md)** (State machines, lifecycles, and core framework services)
4. **[RULES.md](file:///f:/BIGGER/docs/RULES.md)** (Code constraints & the Architecture Freeze rule)
5. **[NAMING.md](file:///f:/BIGGER/docs/NAMING.md)** (Luau asset, variable, and class naming guidelines)
6. **[GLOSSARY.md](file:///f:/BIGGER/docs/GLOSSARY.md)** (Unified gameplay terminology dictionary)
7. **[ADRs (Architectural Decision Records)](file:///f:/BIGGER/docs/ARCHITECTURE.md#architectural-decision-records-adrs)** (Design justifications and trade-offs)
8. **Active Task File** (e.g. `tasks/MVP-xxx.md`)

---


## Core Gating Rules

1. **Strict Task Scoping**: AI agents are only allowed to modify files explicitly listed under the target task file in `tasks/MVP-xxx.md`. Unrelated refactoring, re-formatting, or modifying configurations is strictly prohibited.
2. **Commit & Push Boundaries**: AI agents must **never** perform direct git pushes to remote GitHub repositories without explicit, interactive review and approval from the user.
3. **No Placeholders**: Never insert placeholder comments (e.g., `-- TODO`, `// implement later`) or write incomplete functions. All code generated must be fully implemented, clean, and compilable.
4. **Offline & Studio Smoke Tests**: Every task execution requires verification. Offline checks (formatting/linting) must pass first, followed by Play Solo smoke tests in Roblox Studio before a task is declared ready.
