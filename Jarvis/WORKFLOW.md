# AI Operational Workflow - Bigger

This document outlines the step-by-step pipeline that every AI assistant must execute sequentially when handling user requests. Skipping steps is prohibited.

---

## The AI Pipeline

```text
[User Request]
       ↓
1. Read AGENTS.md
       ↓
2. Read .DaoGang/Jarvis.md
       ↓
3. Read WORKFLOW.md (Current Step)
       ↓
4. Read SYSTEM_PROMPT.md
       ↓
5. Read docs/GAME.md & Child Docs
       ↓
6. Read tasks/MVP-xxx.md
       ↓
7. Implement (Surgical & Scoped)
       ↓
8. Self-Review & Linting
       ↓
8. Playtest & Smoke Test (Roblox Studio)
       ↓
[Done]
```

---

## Detailed Step Description

### Step 1 to 5: Context Alignment
- **AGENTS.md**: Understand your boundaries and restrictions.
- **SYSTEM_PROMPT.md**: Load system role, coding rules, and conflict priorities.
- **docs/**: Verify design intent, invariants, naming constraints, and save schemas.
- **tasks/**: Check what files you are allowed to modify and what lies out of scope.

### Step 6: Surgical Implementation
- Implement the requested change with minimal footprint.
- Respect the **Ladder of Laziness (YAGNI)**: eliminate before writing, reuse before custom scripting.
- Do not write placeholder code or leave open items.

### Step 7: Self-Review & Linting
- Verify that variable names conform exactly to `NAMING.md`.
- Ensure type safety rules and stylistic spacing are followed.
- Check formatting and run code linters locally.

### Step 8: Playtest & Smoke Test
- Run a Play Solo session in Roblox Studio.
- Trigger the code path (using automated commands or manual simulator runs).
- Confirm the Roblox engine console (F9) is clean and free of warnings or runtime exceptions.
- Run regression tests for systems affecting player data, networking, or persistence.
