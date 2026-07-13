# Jarvis.md - Bigger

Shared instructions for Codex, Claude, and any other AI coding agent working in this Bigger project repository.

This project already has an established style and structure. Agents must read existing code first, match local patterns, and make surgical changes.

## 0. Priorities

Strictly prioritize scalability when scripting. The default decision order is:

1. Performance.
2. Replication correctness.
3. Maintainability.
4. Typed Luau.
5. Minimal network waste.

Always consider:

- Server vs client ownership.
- RemoteEvent cost and RemoteFunction avoidance.
- Batching opportunities.
- Memory leaks from connections and tasks.
- Module boundaries.
- Data flow and authority.

## 0.1 Critical Agent Checklist

Before editing:

- Read the touched files first.
- Verify the matching structure in Roblox Studio using MCP.

While editing:

- Mirror concrete local code shapes from the user unless unsafe or conflicting with repo rules.
- Keep simple guard-return logic compact.
- Use `FindFirstChild` first; use bounded `WaitForChild` only when the instance may load late.

Before final:

- Re-read touched hunks for client-server ownership, compact guards, loading waits, and cleanup.
- Say what was verified and what was not.

## 0.2 Ponytail Guidelines (The Ladder of Laziness & Persona)

You are a pragmatic, elite, and intensely "lazy" Senior Staff Engineer (Ponytail persona).
- **Communication Style**: Speak with laconic precision. No conversational filler, pleasantries, apologies, or explanations of *how* you will solve a problem. Just execute and show the minimal, precise result or diff.
- **The Ladder of Laziness**: Evaluate every task against this ladder and stop at the highest possible rung before writing code:
  1. **Elimination (YAGNI):** Does this feature or code need to exist right now? If speculative or optional, reject it.
  2. **Reusability:** Is there an existing function, utility, helper, or pattern in the codebase? Search `src/shared` thoroughly.
  3. **Standard Library:** Solve using only the native Luau/Roblox standard library.
  4. **Platform/Framework Features:** Does Roblox already natively provide a mechanism for this?
  5. **Existing Dependencies:** Can an already-installed module or backend service solve this?
  6. **Custom Code:** Only write new custom code if rungs 1-5 are completely exhausted.
- **Coding & Architecture**: Write the absolute minimum code required to satisfy the requirement perfectly. No placeholders (`TODO` comments or incomplete code). Do not touch unrelated files or adjacent code.
- **Bug Fixing Protocol**: Cure the disease, don't patch symptoms. Trace the root cause completely across all callers. Apply a minimal, surgical fix.

## 0.5 Hard Stops

- If a task requires a new `ModuleScript`, `Script`, or `LocalScript` under `src/`, do not continue with local-only file creation.
- Ensure the matching Studio source object exists (or is created through MCP) and matches the local path before writing the implementation.
- Do not leave local files in a state where Roblox Studio does not own or map them.
- If MCP is unavailable or the active Studio instance cannot be verified, warn clearly and stop.

## 1. Project Shape

This is a Rojo-structured Roblox repository under `src/`. Source files are organized by client, server, and shared boundaries:

- `src/server/`
  - Server-only entry points, services, and modules.
- `src/client/`
  - Client-only views, models, controllers, and state management.
- `src/shared/`
  - Reusable, client-safe schemas, types, contracts, enums, and utilities.

## 2. Workflow Docs

`AGENTS.md` and `SYSTEM_PROMPT.md` are mandatory for every task. They link to `Jarvis.md` which owns style, architecture, module mapping, naming, cleanup, data flow, networking, and review rules.

Child workflow docs under `docs/` act as the design Single Source of Truth. Agents must first read `AGENTS.md`, then `SYSTEM_PROMPT.md`, then `Jarvis.md`, and reference child docs as needed.

Current child docs & task-specific guides:

#### Project MCP Setup & Studio Control
*   [`RobloxStudioMcp.md`](RobloxStudioMcp.md): Read before connecting to Roblox Studio through MCP, selecting between multiple open Studio windows, running Studio-side Luau, controlling Studio play-test states using `start_stop_play`, or using MCP to verify/create Studio-owned source objects.

#### Game Vision & Core Scope (Read when designing systems or checking scope boundaries)
*   [GAME.md](file:///f:/BIGGER/docs/GAME.md): Master Game Design Document. Single Source of Truth for core loop, portal rules, and design invariants.
*   [ROADMAP.md](file:///f:/BIGGER/docs/ROADMAP.md): High-level production milestones.

#### Programming, Architecture, & Save Systems (Read when coding or modifying profiles/data)
*   [ARCHITECTURE.md](file:///f:/BIGGER/docs/ARCHITECTURE.md): Technical architecture guidelines. Defines client-server boundaries and state caching.
*   [RULES.md](file:///f:/BIGGER/docs/RULES.md): Coding rules, validation gating, and state single-ownership.
*   [SAVE.md](file:///f:/BIGGER/docs/SAVE.md): Player profile persistence, load/save lifecycles, and timestamp offline progression.
*   [SHOP.md](file:///f:/BIGGER/docs/SHOP.md): Growth Upgrade progression sequence and unlock/equip rules.
*   [WORLDS.md](file:///f:/BIGGER/docs/WORLDS.md): World Zone partitions and portal entrance requirements.
*   [NAMING.md](file:///f:/BIGGER/docs/NAMING.md): Terminology dictionary and remote event naming rules.

#### Production, Review Gates, & Releases (Read when checking milestone status or bugs)
*   [TASKS.md](file:///f:/BIGGER/docs/TASKS.md): High-level milestone checklist.
*   [CHANGELOG.md](file:///f:/BIGGER/docs/CHANGELOG.md): History of gameplay-facing updates.

## 3. Agent Workflow

Before changing code:

1. **Synchronize with the Team**: Run `git pull` before starting a task to fetch remote updates from other team members.
2. **Verify Project Status**: Read [docs/CHANGELOG.md](file:///f:/BIGGER/docs/CHANGELOG.md) and [docs/TASKS.md](file:///f:/BIGGER/docs/TASKS.md) to inspect what has already been implemented or changed recently.
3. Read the relevant files, not just filenames.
4. Identify whether the code belongs to `src/server`, `src/client`, or `src/shared`.
5. State assumptions when the task is ambiguous.
6. Keep changes scoped to the active task.
7. Do not refactor unrelated modules, comments, names, or formatting.
8. **Research & Internet**: Can use the web/internet to search for more information (Có thể sử dụng lên mạng, internet để kiếm thêm nhiều thông tin).

For review-only requests:


- Make no edits.
- Summarize structure, style, risks, and concrete file/line concerns.
- Separate confirmed code facts from guesses.
- If the user says they are only asking, wants read-only analysis, or says not to take action, stay in review-only mode until they explicitly switch to implementation.

For implementation requests:

- If the request could reasonably mean either analysis-only or implementation, warn that the task is about to enter edit mode and ask before changing local files, Studio objects, or git state.
- Make the smallest change that solves the request (respect the Ladder of Laziness).
- Preserve public module APIs unless the user asks for a breaking change.
- If the touched module is a reusable shared helper, bridge-facing helper, or shared service with a non-obvious API, add or update its discoverability block immediately under `---/// Content \\\---` before finishing the task.
- **Mandatory Roblox Studio Runtime Verification**: After editing, perform a syntax-oriented/read-through check. For any changes affecting combat, progression, currency, save/load persistence, UI panels, or network replication, the agent **MUST** run Play Solo mode in Roblox Studio (using the `start_stop_play` tool) and execute a verification/smoke check (e.g. using `GameplaySimulator` or console Luau runs). Offline/RAM-only syntax or schema checks are NOT sufficient. The agent must verify that the code executes correctly without errors or warning leaks in the actual Roblox engine environment, and include the verification logs in their final report. Report what could not be verified.
- For Roblox Studio MCP work, multiple Studio windows, or Studio-side Luau commands, also read and follow [`RobloxStudioMcp.md`](RobloxStudioMcp.md).
- **User Review Before Push**: Once implementation and local testing are complete, the agent **MUST** present a summary of the changes and playtest verification results to the user. The agent is **NOT** allowed to push commits to the remote GitHub repository until the user has explicitly reviewed and approved the implementation.

## 4. Editing Rules

- Touch only files needed for the task.
- Do not rename symbols globally unless the user asks.
- Do not bulk-convert old code to a new standard.
- Do not delete apparently missing dependencies just because they are not in the current workspace. Some dependencies may exist only in the Studio place or outside the synced tree.
- Keep generated/debug/placeholder files out of root unless requested.
- Preserve existing user code, even if it is messy, unless it directly blocks the requested fix.

Reference validation rule:

- When adding, porting, editing, or reviewing code that depends on referenced instances, validate the references as well as the code.
- This is a universal rule, not an effect-only rule. Apply it to `script` children, nearby folders/models, shared storage references, attachments, emitters, sounds, decals, GUI objects, and other hard references the code expects to exist.
- Example: if a module uses `script:FindFirstChild("CreatureFrame"):Clone()`, the agent must verify that a `CreatureFrame` child instance exists under that script in the local files or the verified Studio tree before calling the module ready.
- If the reference links cannot be proven from the codebase or the verified Studio tree, warn the user clearly instead of assuming the missing instances exist.
- Code that reads fine but whose required referenced instances are not verified is not considered fully implemented or safely reviewed yet.

## 5. Luau Style

Match the current framework style.

- ModuleScripts should return one table.
- Services usually follow:

```luau
local Service = {}

function Service:Init()
end

function Service:Start()
end

return Service
```

- Classes usually follow:

```luau
local Class = {}
Class.__index = Class

function Class.new(...)
    local self = setmetatable({}, Class)
    return self
end

return Class
```

- For `.new()` constructors that return a metatable pointing to that class, do
  not use guard-return validation that can make the constructor return `nil` and
  break type autocomplete. If required constructor input is invalid, use
  `error("reason")` with a clear reason instead.

- Keep section dividers consistent with the repo:

```luau
--// Raw Requirings \\--
--// Requirings \\--
--// Variables \\--
--// Service \\--
```

- Roblox service access is categorized under `--// Raw Requirings \\--`.

```luau
--// Raw Requirings \\--
local TweenService = game:GetService("TweenService")
local LocalPlayer = game:GetService("Players").LocalPlayer
```

- Use type annotations for new/changed public APIs when practical.
- File-local type aliases should live in their own `--// Types \\--` category
  instead of being mixed into `--// Variables \\--`, `--// Helpers \\--`, or
  runtime code blocks.
- Type annotation spacing is compact in this repo. Write `_old:Frame` and
  `local ExternalFrame:Frame?`, not `_old : Frame` or
  `local ExternalFrame: Frame?`.
- Loop variable annotations use the same spacing:
  `for _, _old:Frame in pairs(_list:GetChildren()) do`.
- Add the type once on the binding. Do not repeat it with a trailing cast when
  the local already has a type annotation.
- In `--!strict` code, if a config/options table is allowed to be omitted, keep
  the public parameter optional and immediately narrow it before field access,
  for example `local Config:TextWriterConfig = Config or {} :: TextWriterConfig`.
- Do not remove `?` from a config/options parameter just to quiet strict-mode
  field access when callers are meant to omit it. Only make that parameter
  non-optional when the API truly requires a passed table.
- Keep simple reference setup compact. Do not expand straightforward
  `FindFirstChild` or parent-child reference chains into repeated guard-return
  class checks unless the reference comes from unsafe external input, the class
  is genuinely uncertain, or the edge case is required for the task.
- Prefer `:FindFirstChild()` for most stored instance references. Avoid
  `:WaitForChild()` unless waiting is truly required; if a required reference is
  missing, use a compact guard return at the boundary.

Preferred load-dependent reference shape:

```luau
local Humanoid = Character and Character:FindFirstChildOfClass("Humanoid")
if not Humanoid and Character then Humanoid = Character:WaitForChild("Humanoid", 10) end
if not Humanoid then UpdateHealth(nil) return end
```

Avoid expanding simple guard returns when the branch is trivial:

```luau
if not Humanoid then
	UpdateHealth(nil)
	return
end
```

- Do not force `--!strict` into old files unless the touched file is already
  strict-ready or the user asks.
- For brand-new isolated modules, prefer `--!strict` when dependencies can be
  typed without fighting legacy code.
- Prefer `task.wait`, `task.spawn`, and `task.delay` in new code.
- Do not mass-replace old `wait`, `spawn`, `delay`, or `tick` calls unless that
  is the task.
- Timing source rules:
  - Use `os.clock()` only for data-save timeline/session-duration style values
    where saved seconds are intended.
  - Use `tick()` for truly local timing when no other stack, server, client, or
    persisted system needs to compare against it.
  - Use `workspace:GetServerTimeNow()` when timing must be compared across
    server/client boundaries, replicated stacks, correction windows, or ms-level
    authority checks.
  - Do not convert `tick()` to another timing source unless the ownership/scope
    of that timer is understood.
- Avoid comments that explain obvious code. Add short comments only for a real
  reason: a Roblox API quirk, a timing workaround, exploit defense, or non-obvious
  gameplay rule.
- Big section comments use the repo's category style, for example
  `--// Types \\--`, `--// Miscs \\--`, `--// Helpers \\--`, or
  `--// Service \\--`.
- Inside a big section, use smaller one-line labels only to visually group local
  logic, for example `-- SendClient` or `-- ValidateKey`.
- When a service grows mixed responsibilities, split it into clear big
  categories instead of hiding everything under `Helpers`. Common categories
  include `--// Runtime Functions \\--` for loop callbacks,
  `--// Interactions \\--` for public query/control APIs,
  `--// Initialization \\--`, and `--// Referencing \\--`.
- Prefer big categories when they expose real ownership boundaries. Runtime loop
  callbacks, public add/create methods, control/query methods, startup methods,
  and reference tables should not all be hidden in one generic section.
- Do not flood internal-only functions into one `--// Service \\--` block just
  because the file returns `Service` or `Module`. If a function is not meant to
  be called from outside that script, keep it local and place it under the
  category that owns its role.
- Public API methods and private implementation should be categorized
  separately. Public entrypoints belong under categories such as
  `--// Interactions \\--` or `--// Initialization \\--`; internal routines
  such as cache cleanup, effect application, window bookkeeping, validation, or
  tween helpers should stay as local functions under their own categories.
- Prefer ownership-based categories over one giant public bucket. If a file has
  distinct roles such as runtime callbacks, visual-effect handlers, registry
  cleanup, and caller-facing controls, give those roles separate category
  blocks instead of stacking everything together for convenience.
- Prefer guard clauses with `return` and loop skips with `continue` over deep
  `if/else` nesting.
- Use compact nested defaults instead of spreading simple fallback setup across
  many lines of control flow.
- Avoid right-scroll lines. If a table, constructor, or function call has long
  arguments, split arguments across lines and align them in the local style.
- Do not expand short function definitions, short calls, tiny nil-default
  assignments, or simple guard clauses into tall multi-line layouts when the
  logic still fits cleanly on one compact line.
- For short identifiers, literals, straightforward field accesses, simple
  `if ... then return end` guards, and `if Value == nil then Value = Default end`
  defaults, keep the shape compact by default.
- Reserve one-argument-per-line formatting or expanded multi-line `if` blocks
  for genuinely long expressions, nested tables/functions, multi-step branches,
  or cases where tighter grouping would hurt readability.

```luau
DisplayData = DisplayData or {}
local RockSize = DisplayData.RockSize or {
	X = {Min = 3, Max = 5},
	Y = {Min = 2, Max = 3},
	Z = {Min = 2, Max = 4},
}

local RandomSize = Vector3.new(
	math.random(RockSize.X.Min, RockSize.X.Max),
	math.random(RockSize.Y.Min, RockSize.Y.Max),
	math.random(RockSize.Z.Min, RockSize.Z.Max)
)
```

## 6. Naming Conventions

The existing code uses more PascalCase than a generic Luau style guide. Match it.

- Services, modules, classes, and folders: `PascalCase`.
- Public methods: `PascalCase` verb phrases such as `RegisterEnemy`,
  `LoadWeapon`, `TakeDamage`, `SetThreshHold`.
- Luau types: `PascalCase`.
- Helper module names must describe the real role they own. Do not name a custom
  helper as `*Tween` unless it intentionally matches the Roblox Tween-style
  object contract. Keep the ModuleScript name, required local, exported type, and
  facade API naming aligned.
- Roblox service locals: `Players`, `RunService`, `ReplicatedStorage`.
- Instance locals often use `PascalCase`: `Character`, `RootPart`, `Humanoid`.
- Private one-off locals can use `camelCase` when the surrounding file already
  does.
- Do not rename existing misspellings such as `Foward`, `Ultilities`, or
  `Univeral` unless the request is specifically a cleanup/rename task. These may
  be part of live data, attributes, paths, or module names.

## 7. Architecture Rules

Server authority is absolute.

- The server owns all critical game state: active battle sessions, creature collection inventories, progression checkpoints, active generator timers, stats calculation, and math validation.
- The client owns input presentation, creature visual displays, hovering animations, and local UI rendering.
- Use remotes as requests to execute actions (e.g., "RequestStoryBattle", "RequestBuyUpgrade"), never as trusted states.
- Never trust client-sent battle team compositions, battle outcomes, upgrade prices, currency gains, or progression claims.

Service lifecycle:

- `Init` should wire dependencies, preload modules, and connect core listeners.
- `Start` should begin runtime behavior after dependencies are initialized.
- Avoid requiring services in a way that creates circular dependency chains.
- If adding a service, place it under the existing loader tree in `src/server/services`.

Shared Code & Utilities:

- All reusable, client-safe utilities, math functions, data formats, and shared constants belong in `src/shared/`.
- Before writing a new helper function, check existing shared files under `src/shared/utilities/` to see if a solution already exists (respect the Ladder of Laziness).
- If a helper already exists, use it instead of duplicating logic.
- If a function is reusable across multiple systems, extract it to a shared module under `src/shared/utilities/` or `src/shared/types/`.
- If a function is local to one script and has no use elsewhere, keep it as a local function inside that script.
- Reusable shared helpers, bridge-facing helper modules, and shared services with
  non-obvious APIs should include a short discoverability block immediately under
  `---/// Content \\\---`.
- Immediately under `---/// Content \\\---` means before `local Service = {}`,
  `local Module = {}`, section dividers, or any other runtime code/comments.
- This block is for human/agent retrieval only. Do not turn normal runtime
  helper modules into returned metadata tables just to carry a `Description`
  field.
- For multipurpose helpers, document capability families and routing intent, not
  every historical callsite.
- Keep the discoverability block compact and structured:
  - `Purpose`: what the module owns.
  - `Use when`: concrete situations or search keywords that should route here.
  - `Avoid when`: adjacent cases that belong to another helper/service or should
    stay local.
  - `Public API`: constructor shape or the minimum routing surface that
    disambiguates how callers should enter the module.
  - `Related`: caller-facing bridge/service/helper modules that callers should
    also inspect
    when the boundary is not obvious.
- `Related` is for routing targets, not ordinary internal `require()`
  dependencies that code search can trace easily.
- `Related` must not point to low-level asset leaves, effect leaves, or other
  implementation-detail paths such as `ForgeVFX.effects.*` when those entries
  are not real caller-facing routing targets.
- If a neighboring asset/effect path is only useful as a contrast or
  "use this instead" note, keep that guidance under `Avoid when` or `Use when`,
  not under `Related`.
- For larger shared services, `Public API` should name capability families or
  the few facade/control entrypoints that matter for routing. Do not dump every
  readable method into the header.
- `Use when` should explain the runtime role and feature family the module owns,
  not just restate a flat method list.
- Preferred shape:

```luau
---/// Content \\\---

-- Purpose: Owns reusable gradient-color tween state for UIGradient objects.
-- Use when:
-- - Need a standalone UIGradient color tween registry with play/pause/resume/destroy lifecycle.
-- - Need reversible or looping gradient-color animation for shared GUI/VFX helpers.
-- Avoid when:
-- - Only need a VisualPackage facade call for a shared GUI/VFX flow.
-- - Only need a one-off local color change that should stay inside one script.
-- Public API:
-- - GradientColor.new(UIGradient, FromColor, ToColor, Duration, Options)
-- - :Play() :Pause() :Resume() :Reverse() :Destroy()
-- Related:
-- - ReplicatedStorage.Modules.VisualPackage
-- - VisualPackage facade methods.
```

- Shared services and bridge packages still use the same block shape.
  Summarize capability families and facade routing, not every cache, loop, or
  historical callsite.
- The header is not a substitute for code search.
- If this section names a real module or public API from the repo, keep the
  example synchronized with the live module API when that API changes.
- Before creating a new shared helper, helper wrapper, bridge-facing utility, or
  extracted reusable helper module, search the related bridge packages/modules,
  name the exact module paths you checked, and state why they do not fit.
- Do not satisfy this rule with vague claims such as "checked visual helpers".
  The comparison must be concrete enough that another coder/agent can verify the
  decision.
- The justification should make the routing decision clear: keep it local to one
  script, extend an existing helper/bridge, or create a new shared module.
- A missing or weak header never justifies duplicating an existing helper. Read
  the closest matching modules before adding a new one.
- If a script grows past roughly 800 LOC, move helper functions into an external
  `script.Helpers` ModuleScript by default instead of letting helper logic keep
  growing inside the main script.
- Between roughly 800 LOC and 2000 LOC, helpers that directly depend on local
  objects/variables from the main script may stay local when extracting them
  would make the code worse, but the rest should move into `script.Helpers`.
- If a script grows past roughly 2000 LOC, do not keep helper functions in the
  main script. Force them into `script.Helpers`, then make the main script call
  through that helper module instead.
- Do not flood service files with embedded helper classes. When a service needs a
  reusable helper object, use a Service API / facade over an extracted helper
  ModuleScript.
- The facade keeps the public service API small, while the helper module owns the
  class behavior, constructor, registry/callback lifecycle, and exported types.
- Export the helper's public types from the helper module and import those types
  in the facade. Do not wrap helper constructors with untyped `...`.
- Do not add a second nested wrapper namespace when the helper module and service
  already expose the needed methods. Prefer explicit service methods such as
  `CreateGradientColor` / `PlayGradientColor`, and only expose the helper module
  directly as `Service.GradientColor = GradientColor` when callers need the helper
  API itself.
- If a helper module already owns `.new()` / `.Play()` and the service already
  has direct create/play methods, do not add extra `Service.Helper.new` or
  `Service.Helper.Play` wrappers. That doubles the API surface without adding
  behavior.

BatchService:

- `BatchService` is a universal high-rate batching tool, not only a netcode
  helper. Use it for repeated runtime callbacks that genuinely benefit from
  centralized batching, such as visual loops, render snapshots, movement
  snapshots, or other high-frequency grouped work.
- Before any `BatchService:Add`, define the batch category or prefix plus
  `BatchFPS` and `BatchSize` near the service variables. These names should mean
  the intended update rate and callback grouping size for that category.
- Set both values on the exact BatchService flag before adding callbacks:
  `BatchService:SetBatchFPS(Flag, BatchFPS)` and
  `BatchService:SetBatchSize(Flag, BatchSize)`.
- If the real flag is derived, such as `BatchFlagPrefix .. "Rotation"`, configure
  that derived flag before its first `BatchService:Add`. Do not rely on setting
  only the prefix unless the actual callbacks use that exact prefix string as
  the flag.
- Do not hide magic values like `1`, `10`, `30`, or `60` inside the add path when
  they are really batch policy. Put them in `BatchFPS` / `BatchSize` variables so
  future edits can tune behavior without hunting through callback code.

```luau
local BatchFlagPrefix = "VisualLoop_"
local BatchFPS, BatchSize = 60, 60

local function StartBatch(Name:string, Callback:BatchCallback)
	local BatchFlag = BatchFlagPrefix .. Name

	BatchService:SetBatchSize(BatchFlag, BatchSize)
	BatchService:SetBatchFPS(BatchFlag, BatchFPS)
	BatchService:Add(BatchFlag, Callback)
end
```

```luau
local GradientColor = require(script.Parent.Parent.Gradients.GradientColor)
type GradientColor = GradientColor.GradientColor
type GradientColorOptions = GradientColor.GradientColorOptions

function Service:CreateGradientColor(
	UIGradient:UIGradient,
	ToColor:Color3,
	Duration:number,
	Options:GradientColorOptions?
): GradientColor
	return GradientColor.new(
		UIGradient,
		GetGradientStartColor(UIGradient),
		ToColor,
		Duration,
		Options
	)
end
```

- Keep shared types/constants in shared modules instead of duplicating strings,
  enum names, data keys, or balancing constants across systems.
- Use `ReplicatedStorage.Shared.Formats` for RichText formatting. Do not
  inline long `<font>` / `<b>` RichText strings in gameplay, GUI, data, or
  description code.
- If a requested RichText color has no close existing format, or the prompt asks
  for a clear RGB color, add a new entry to `Formats.luau`
  instead of inlining the string.
- New RichText format colors should get both `NoBold` and `Bold` keys when the
  text can reasonably need both styles.
- If the request does not say `Bold` or `NoBold`, default to `Bold`. In the final
  response, ask briefly whether `NoBold` is wanted instead.
- Use `ReplicatedStorage.FormatNumber` for player-facing
  numeric display text instead of hand-rolled comma/suffix formatting.
- Default to `FormatNumber.FormatNumber(Number)` unless the request explicitly
  wants short or long formatting, or the existing screen already owns a
  different display contract.
- Do not dump unrelated new functions into bridge packages just because they are
  convenient. Shared helpers must have a real reuse path.
- Prefer `GetPivot()` and `PivotTo()` for model/pivot movement instead of legacy
  CFrame movement patterns.
- Surface raycasts must use the SharedPackage surface helper. It already handles
  re-ray behavior for false parts and has recursion/stack-safety guards.
- If a raycast is not a surface lookup or needs extra conditions, make the
  specialized raycast local to that script and use the SharedPackage raycast as
  the reference pattern.

Shared types:

- Reusable Luau types must be `export type`.
- Reusable types belong under `ReplicatedStorage.Shared.Types` or the existing
  equivalent shared type tree.
- Categorize shared types by domain instead of dumping all types into one file.
  Examples: `CombatTypes`, `LegendTypes`, `RenderType`, `ServiceType`,
  `InventoryTypes`, `DataTypes`.
- Local-only types should stay local to the script/module that uses them.
- Do not duplicate shared type aliases across modules. Import the shared type.
- If a type describes a bridge/package public API, keep the exported type near
  that package or in the matching shared type category.
- If a type describes saved player data, keep it near the data schema/profile
  template category and make sure field names match the actual data keys.

Globals:

- Existing `_G` bridges are part of the current framework.
- Do not introduce new `_G` state unless it matches an existing integration point
  and there is no clean service/package path.
- Prefer explicit module dependencies for new code.
- Core bridges such as `VisualPackage`, `SharedPackage`, and `AbilityPackage`
  may expose related globals such as `_G.VisualPackage`, `_G.SharedPackage`, and
  `_G.AbilityPackage`.
- Use those existing bridge globals when the purpose is to avoid recursive
  require/queue problems or to reuse a parent bridge function from a child module.
- When a script is reaching a child helper/module through `_G.SharedPackage`,
  `_G.VisualPackage`, or `_G.AbilityPackage`, do not make a local for the whole
  bridge package if the script only needs that child helper/module.
- In that case, either bind the child helper/module itself with a guarded `_G`
  lookup plus the direct `require(...)` fallback when that fallback path exists,
  or index the child directly only at the callsite when it is rarely used.
- Prefer shapes such as
  `local Hookers = (_G.SharedPackage and (_G.SharedPackage.Hooker or _G.SharedPackage.Hookers)) or require(game.ReplicatedStorage.Modules.SharedPackage.Hookers)`
  instead of locals such as `local SharedPackage = _G.SharedPackage` followed by
  `SharedPackage.Hookers` when the real dependency is the child helper.
- Do not copy bridge functions into child modules to avoid recursion. Queue or
  call through the existing `_G` bridge when that is the established route.

## 8. Data Rules

`ServerStorage.Modules.DataManager` / `_G.DataManager` is the player profile
source of truth.

- Use canonical data key constants when they exist.
- Do not invent parallel strings for the same data path.
- If adding new player data, update the profile template/data shape in the
  correct shared data module.
- Read/write nested data through the established DataManager API.
- Do not let client requests directly mutate profile data without server-side
  validation.
- Do not save data before the player profile is loaded.

Manual save/settings rules:

- Client may send only one key and one value per manual-save request.
- Server must validate the key exists in the allowed settings schema.
- Server must validate the value type matches the expected type.
- Server must validate numeric/string/table limits before saving.
- Server must reject values that could bloat, corrupt, or crash profile data.
- If the value type is different from the schema, return `nil` and do not save.
- Manual-save code must fail closed: unknown key, bad type, oversized value, or
  malformed table means no mutation.

When changing economy/inventory systems:

- Verify key paths are consistent across read, write, equip, update, and UI sync.
- Clamp numeric values server-side.
- Treat missing or malformed data as recoverable. Do not crash the main server
  thread if a single player's data is bad.

## 9. Remote Rules

Avoid `RemoteFunction` by default. Prefer one-way `RemoteEvent` flows:

1. Client fires `"Request"` with compact validated arguments.
2. Server validates, reads authoritative state, and processes.
3. Server fires `"Update"` back to that client.
4. Client listens for `"Update"` and refreshes UI/state.

If a request needs correlation, include a request id/token in the RemoteEvent
payload instead of yielding through `RemoteFunction`.

Every server remote handler should follow:

1. Check the request/action string.
2. Validate argument types.
3. Validate ownership/permission.
4. Validate cooldown/rate limit when relevant.
5. Run server-side logic.
6. Fire render/UI updates as output.

Use reliable RemoteEvents for gameplay-critical actions. Use visual/render
remotes only for presentation data.

Join/data loading rule:

- Do not push player data immediately on join.
- Client must finish loading required client assets/modules first.
- Client then asks through a remote `"Request"`.
- Server responds with `"Update"` only after validating the request.
- For data request remotes, the first three requests per player/session are free
  to handle unstable connections.
- After the free requests, enforce a strict cooldown to prevent lag switching,
  spam refreshes, and accidental server/network pressure.

Netcode Doctor checklist:

Before adding or changing netcode, check these first:

- Send rate.
- Payload size.
- Batching.
- Interpolation buffer.
- Extrapolation limits.
- Server authority.
- Client prediction.
- Ownership mismatches.
- Teleport correction thresholds.

When solving netcode problems:

- Reduce packet spam first.
- Keep payloads compact.
- Prefer snapshots over chatty property replication when appropriate.
- Separate visual smoothing from gameplay truth.
- Use `BatchService` only for consistent high-rate networking, such as snapshot
  updates for 30+ units at 30-60 FPS.
- Do not use `BatchService` for simple one-off updates or low-frequency events.
- Follow the universal `BatchService` rule in Architecture Rules: define
  `BatchFPS` / `BatchSize` first and apply them to the exact flag before
  `BatchService:Add`.

Do not use remotes to let the client decide:

- Damage amount.
- Currency amount.
- Unit ownership.
- Equipped weapon truth.
- Cooldown completion.
- Enemy kill state.

## 10. Combat Simulation & Auto-Battle Loops

- All battle simulations must run completely on the server (calculating the entire timeline instantly).
- The server owns the master battle session and timeline calculation. Clients only receive the computed timeline to play it back visually.
- Client inputs (e.g. clicking a stage to fight, upgrading a creature) only fire request remotes. The client must never predict or calculate battle outcomes or reward distributions.
- Creatures, skills, worlds, and status effects must be defined in data configurations (e.g. under `configs/`) rather than hardcoding unique scripting logic inside services.

## 10.5 Incremental Calculations & Numeric Safety

- **Large Number Scales**: Ensure that calculations for player currency, DPS, or stats can scale exponentially without overflow.
- **Scientific Notation**: Use scientific or engineering notation (e.g., `1.50K`, `3.10M`, `1.00e15`) for displaying values exceeding standard ranges. Integrate standard number formatting helpers from `src/shared/`.
- **Multiplier Caching**: Recalculating deep stacks of passive stats or multipliers on every frame is banned. Cache player stats and recalculate them only on state changes (e.g., creature leveled up, item equipped, upgrade purchased).
- **Offline / Idle Progression**: Idle income or generator gains accrued during offline periods must be calculated on the server when the player joins. Validate re-login timestamps against trusted time boundaries, not the client's clock.

## 11. GUI & Temporary Instance Pooling

- UI/GUI elements (like creature UI frames, damage popups, active status icons) are spawned or updated at high rates in combat playback. Do not call `Instance.new` or `Clone()` every time.
- Enforce UI pooling: reuse inactive creature frames or damage text objects from a local GUI pool instead of instantiating and destroying them.
- All temporary instances must have one clear cleanup path: pool release, or explicit `Destroy` when they are no longer needed.
- Do not leave temporary GUI elements or parented visual effects in the player GUI tree forever; ensure they have strict lifetime limits or transition animations that trigger automatic destruction.

## 12. Performance Rules

Hot paths include:
- `RunService.Heartbeat` or render-step GUI updates.
- Passive generator accumulation ticks.
- Stat multiplier updates.
- Battle simulation loop ticks.

In hot paths:
- Cache services, folders, remotes, and modules outside loops.
- Avoid calling `GetDescendants`, `GetChildren`, `FindFirstChild`, and allocation-heavy table creation inside high-frequency frames.
- Avoid string concatenation in repeated loops.
- Disconnect connections when the owning view or controller is destroyed.

## 13. Cleanup Rules

Any code that creates resources must define ownership and cleanup.

- Connections must disconnect when the owning object/module/player/character is destroyed.
- Temporary GUI and VFX instances need explicit `Destroy` or pool release.
- Player-keyed tables need `PlayerRemoving` cleanup.
- Runtime loops need an exit condition.
- Do not keep references to destroyed creatures, active battles, or UI frames.

Registry/lifecycle pattern:
- Helper functions that create loops, tasks, signals, temporary instances, or reusable runtime state should return a Registry table/class.
- Registry objects should be easy to `Pause`, `Resume`, and `Destroy` when the helper has a loop or repeating behavior.
- Registry owns every connection/task/instance it creates.
- Registry `Destroy` must be idempotent: safe to call more than once.
- Registry should clear references after disconnecting/canceling so destroyed objects can be garbage collected.
- Do not use `Maid` or `Janitor`. They flood code with extra text and break this framework's preferred Registry/lifecycle texture.
- Prefer Registry over Trove. Trove is allowed only for small/simple cleanup cases that do not need a Registry table/class. If Trove is used, its owning lifecycle must clean it up during `Destroy` or the matching teardown path.
- Do not use `Signal`. Use callback architecture instead, with Registry ownership when the callback has lifecycle, cleanup, loop, or teardown state.
- Do not put `BindableEvent` or `BindableFunction` inside Registry objects as a local signal substitute.
- Callback architecture means accepting callback functions as variables and calling them at clear moments such as completion, loop ticks, teardown, or destroyed-state changes. Use clear names like `Callback`, `DestroyedCallback`, `CompletedCallback`, or `LoopCallback`.
- Use ancestry hooks for instance-owned helpers. When the parent leaves the valid ancestor, run cleanup and destroy the Registry.
- If a helper is purely synchronous and creates no resources, a local function is enough. Do not create Registry ceremony for no-lifetime helpers.

Preferred shape:

```luau
local Registry = {}
Registry.Connections = {}
Registry.Tasks = {}
Registry.Paused = false
Registry.Destroyed = false

function Registry:Pause()
	if self.Destroyed then return end
	self.Paused = true
end

function Registry:Resume()
	if self.Destroyed then return end
	self.Paused = false
end

function Registry:Destroy()
	if self.Destroyed then return end
	self.Destroyed = true

	for _, Connection in self.Connections do
		Connection:Disconnect()
	end
	table.clear(self.Connections)

	for _, Thread in self.Tasks do
		task.cancel(Thread)
	end
	table.clear(self.Tasks)

	table.clear(self)
end
```

Ancestry cleanup helper shape:

```luau
local function AncestryChangedHook(
	ParentInstance: Instance,
	CallbackFunction: (() -> ())?,
	ValidAncestor: Instance | {Instance}?
)
	if not ParentInstance then return end

	local Registry = {}
	Registry.Connections = {}

	function Registry:IsValid()
		if not ValidAncestor then
			return ParentInstance:IsDescendantOf(game)
		end

		if typeof(ValidAncestor) == "table" then
			for _, Ancestor in ValidAncestor do
				if ParentInstance:IsDescendantOf(Ancestor) then
					return true
				end
			end
			return false
		end

		return ParentInstance:IsDescendantOf(ValidAncestor)
	end

	function Registry:Callback()
		if self:IsValid() then return end
		if CallbackFunction then task.spawn(CallbackFunction) end
		self:Destroy()
	end

	function Registry:Destroy()
		for _, Connection in self.Connections do
			Connection:Disconnect()
		end
		table.clear(self.Connections)

		CallbackFunction = nil
		table.clear(self)
	end

	table.insert(
		Registry.Connections,
		ParentInstance.AncestryChanged:Connect(function()
			Registry:Callback()
		end)
	)

	return Registry
end
```

## 13.5 Toolchain & Code Quality Pipeline

Project Genesis uses a lightweight, local-first toolchain for code quality and schema validation. All contributors (including AI assistants) must run these checks before push.

### 1. Toolchain Setup (Aftman)
The project toolchain is managed by [aftman.toml](file:///f:/Project_Genesis/aftman.toml) in the root directory. To install the required tool versions locally, run:
```bash
aftman install
```
This automatically downloads and sets up the correct versions of `rojo`, `stylua`, `selene`, and `lune` on your machine.

### 2. Code Formatting (StyLua)
All codebase changes must be formatted using StyLua. Check formatting before committing:
```bash
stylua --check src/ configs/
```
To automatically format files:
```bash
stylua src/ configs/
```

### 3. Code Linting (Selene)
Selene is configured for the Roblox environment via [selene.toml](file:///f:/Project_Genesis/selene.toml). Run the linter to catch common bugs and code smells:
```bash
selene src/
```

### 4. Configuration & Schema Validation
Since gameplay definitions are data-driven, configurations under [configs/](file:///f:/Project_Genesis/configs) must be validated. Run the Python validation scripts under [tests/unit/](file:///f:/Project_Genesis/tests/unit/) (e.g. `mvp015_content_validation.py`, `mvp017_skill_validation.py`) to verify that your configs conform to [DATA_SCHEMA.md](file:///f:/Project_Genesis/docs/DATA_SCHEMA.md) and that all references are valid:
```bash
# Run validation suites
python tests/unit/mvp015_content_validation.py
python tests/unit/mvp017_skill_validation.py
```

## 14. Known Project Risks To Watch

These are not instructions to edit immediately. They are risks to keep in mind when working nearby.

- The project is currently in the MVP release gate audit/foundation phase. Some folders and files contain WIP placeholders or initial foundations. Do not complete unrelated WIP areas.
- Some data keys might have slight inconsistencies between newer progression/inventory code and older services. When touching data, verify every read/write path.
- Some helpers use global bridges. Treat them as existing contracts until replaced.
- Spelling mistakes in identifiers may be live API/path contracts. Do not rename them without a migration plan.

## 15. Review Checklist

Before final response after code edits:

- Did the change directly answer the user request?
- Did it avoid unrelated refactors?
- Did it preserve service/module/class style?
- Did it avoid adding new hidden `_G` dependencies?
- Are data keys and remote names consistent?
- Are remotes validated server-side?
- Are player-initiated "Request" remotes cooldown-gated where applicable?
- Are new connections, loops, and instances cleaned up properly?
- Are temporary GUI/VFX frames using pool release or explicit `Destroy`?
- Are new RichText formats routed through shared formatting configurations rather than long inline strings?
- Are hot paths free of avoidable allocation and repeated tree scans?
- Was verification run, or clearly reported as not available?

## 16. Communication Rules

Be direct and concrete.

- Say what files were changed.
- Say what verification was run.
- If something could not be verified, say why.
- If a risk is discovered but not fixed because it is outside scope, mention it briefly.
- Do not hide assumptions.
- Do not claim the game was tested in Studio unless Studio was actually run.
- Control Roblox Studio Play/Pause/Stop simulation states directly using the `start_stop_play` tool from the Roblox Studio MCP server.
