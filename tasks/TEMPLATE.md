# Task MVP-XXX: [Task Title]

[Brief description of the task requirements and target objective.]

---

## Scoped Files

AI agents are only allowed to modify the following files:
- `[file path 1]`
- `[file path 2]`

---

## Integration Boundary

[Describe files or modules that this task interacts with but must NOT modify directly, e.g. bootstrappers, integrations, or remote events.]

---

## Out of Scope

To prevent feature drift and preserve codebase stability, this task must **NOT**:
- Refactor unrelated systems or modify formatting in adjacent files.
- Rename public APIs, methods, or network events.
- Modify balancing, costs, requirements, or configuration parameters directly (these must remain in data configuration files).
- Introduce new gameplay features, subsystems, or logic paths not specified in this document.
- Touch or create any files outside the defined Scoped Files list.

---

## Requirements

### 1. [Requirement Group 1]
- [Detail 1]
- [Detail 2]

### 2. [Requirement Group 2]
- [Detail 1]

---

## Execution Steps

- [ ] **Step 1**: [Setup and research]
- [ ] **Step 2**: [Surgical implementation of Requirement 1]
- [ ] **Step 3**: [Surgical implementation of Requirement 2]
- [ ] **Step 4**: [Local linting and formatting verification]
- [ ] **Step 5**: [Roblox Studio Play Solo validation]

---

## QA & Verification Checklist

Before reporting completion, the agent must check and log the following:

- [ ] **Syntax & Format**:styLua formatting and Selene lint checks completed and passed.
- [ ] **Roblox Studio Play Solo**: Verified target logic runs correctly in the Roblox engine environment.
- [ ] **F9 Console Clean**: Studio output and runtime F9 console show no errors, warnings, or memory leaks.
- [ ] **Regression Testing**:
  - Run regression checks 2x for UI/gameplay modifications.
  - Run regression checks 5x for modifications affecting DataStores, network messages, or state replication.
- [ ] **Status**: Transition state to `READY` and present the walkthrough summary to the user for review.
