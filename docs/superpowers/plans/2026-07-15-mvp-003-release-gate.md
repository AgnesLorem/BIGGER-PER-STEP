# MVP-003 — Whole-Project Quality, Security & Bug Gate

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Establish MVP-003 as the permanent whole-project quality gate and fix confirmed defects in descending order: Critical, High, Medium, then Low.

**Architecture:** The release gate is split into independently reviewable severity tiers. Pure validation rules live in focused shared utilities and receive Lune unit coverage; Roblox lifecycle and ownership behavior remains in the existing services and is verified in Studio. Every later MVP extends the task's exact-path scope before its audit cycle begins.

**Tech Stack:** Roblox Studio, typed Luau, Rojo 7.4.4, StyLua 2.0.2, Selene 0.27.1, Lune 0.10.5, Git.

## Global Constraints

- Process findings strictly in this order: `Critical → High → Medium → Low`.
- Do not begin a lower tier while a confirmed higher-tier finding remains open unless the report marks it blocked with evidence.
- MVP-002 is committed and pushed at `19a6af5`; do not rewrite that baseline.
- Never use reset, checkout, clean, force-push, or bulk overwrite.
- Source of truth remains server memory; client Attributes and leaderstats are presentation only.
- Local files under `src/` are the Git source of truth. Write final source locally, mirror identical source into the original Studio place through MCP, and stop if normalized parity differs.
- Never open a generated place or create fake Player objects.
- Label user-executed multiplayer tests as manual; never claim they were MCP-verified.
- Do not create `MVP-X.5` bug-fix milestones; add a future audit cycle to `tasks/MVP-003.md`.
- All offline checks must pass before Play Solo.
- Gameplay/state changes require two Play Solo runs; persistence or network-sync changes require five runs.
- Do not push until the user reviews the implementation and QA evidence.
- If a confirmed defect requires editing a file outside the exact initial scope, record the path and reason in `tasks/MVP-003.md`, extend the exact scope, and stop for Tech Lead approval before editing it.
- Preserve audit history: `docs/superpowers/reports/mvp-003/README.md` is the mutable index; each dated audit report is immutable after its release decision is recorded.
- The Tech Lead conditionally approved this plan on 2026-07-15. After the four final execution amendments are committed, proceed without another architecture review unless an actual Roblox Engine limitation or an out-of-scope source defect is discovered.

## Pre-Task 1 Execution Gate

Before changing any source or test file:

1. Run and record the required non-mutating preflight: `stylua --check src tests`, `selene src`, `rojo build default.project.json -o "$env:TEMP\bigger-mvp003-preflight.rbxl"`, and `git diff --check`.
2. Commit only `tasks/MVP-003.md`, this plan, `docs/superpowers/reports/mvp-003/README.md`, and `docs/superpowers/reports/mvp-003/2026-07-15-initial-audit.md` with `docs(mvp-003): define permanent quality gate`.
3. Confirm `git status --short` is empty before Task 1.
4. Do not push.

---

## File Map

- `tasks/MVP-003.md`: permanent policy, current baseline, exact scoped files, audit cycles, and release decisions.
- `src/shared/Core/Utilities/MovementValidation.luau`: pure finite-number and plausible-displacement validation.
- `src/shared/Core/Utilities/StompValidation.luau`: pure local-space hitbox-footprint and descent validation.
- `tests/unit/movement_validation.luau`: Lune regression cases for teleport-driven movement samples.
- `tests/unit/stomp_validation.luau`: Lune regression cases for side touch, excessive height, and valid stomp.
- `src/server/Game/Systems/MovementGrowthSystem.luau`: samples authoritative session movement and rejects implausible displacement.
- `src/server/Game/Services/WorldInstanceService.luau`: validates world prerequisites and owns world creation/cleanup.
- `src/server/Game/Services/DestructionService.luau`: locks and rewards only a validated owner stomp.
- `src/server/Core/Services/SessionService.luau`: sole validated session-state transition API.
- `src/server/Core/Scheduler/Scheduler.luau`: isolates callback failures so repeating jobs survive.
- `src/server/Core/Events/EventBus.luau`: isolates subscriber failures.
- `src/server/Core/Registry/RuntimeRegistry/*.luau`: removes unused mutable enumeration APIs.
- `src/server/Core/Services/GrowthService.luau`: finite, non-negative, safe-integer Size mutation boundary.
- `docs/superpowers/reports/mvp-003/README.md`: permanent audit-cycle index.
- `docs/superpowers/reports/mvp-003/2026-07-15-initial-audit.md`: immutable initial-cycle evidence, severity status, commands, Studio runs, and remaining risks.

---

### Task 0: Completed MVP-002 Git Gate

**Result:**

- [x] Reviewed branch, remotes, staged/unstaged diffs, untracked files, and exact MVP-002 scope.
- [x] Committed MVP-002 as `feat(mvp-002): implement private WORLD1 portal objective loop`.
- [x] Pulled `origin/main` with rebase through upstream `208f62e`.
- [x] Resolved conflicts without discarding upstream HUD/purchase work or MVP-002 portal work.
- [x] Scoped StyLua passed.
- [x] Selene passed with `0 errors`, `0 warnings`, `0 parse errors`.
- [x] `git diff --check` passed.
- [x] Rojo build passed to a temporary file.
- [x] Pushed `19a6af5` to `origin/main`.
- [x] Verified clean `main` and created `feat/mvp-003-quality-gate`.

---

### Task 1: Add Executable Validation Tests and Pin Lune

**Files:**
- Modify: `aftman.toml`
- Create: `src/shared/Core/Utilities/MovementValidation.luau`
- Create: `src/shared/Core/Utilities/StompValidation.luau`
- Create: `tests/unit/movement_validation.luau`
- Create: `tests/unit/stomp_validation.luau`

**Interfaces:**
- Produces: `MovementValidation.IsPlausible(HorizontalDistance:number, DeltaSeconds:number, MaximumRewardSpeed:number, DistanceSlack:number): boolean`.
- Produces: `StompValidation.IsValid(LocalX:number, LocalY:number, LocalZ:number, HalfX:number, HalfY:number, HalfZ:number, HorizontalPadding:number, MaxHeight:number, VerticalVelocity:number, MinimumDownwardVelocity:number): boolean`.

- [ ] **Step 1: Verify the original Studio place and target parent**

Using the Roblox Studio MCP sequence from `Jarvis/.DaoGang/RobloxStudioMcp.md`:

1. List Studio instances.
2. Select the instance matching `BiggerShared.Core.Utilities.ScaleCurve`.
3. Verify `ReplicatedStorage.BiggerShared.Core.Utilities` is the target parent.
4. Before writing local implementations, create or verify empty mapped ModuleScripts named `MovementValidation` and `StompValidation` under that exact Studio parent.
5. Do not open a generated place and do not create fake Player objects.

Expected: the original Studio place and exact target parent are proven before local implementation begins.

- [ ] **Step 2: Pin the test runtime**

Add this exact entry under `[tools]` in `aftman.toml`:

```toml
lune = "lune-org/lune@0.10.5"
```

Run:

```powershell
aftman install
lune --version
```

Expected: Lune reports `0.10.5`.

- [ ] **Step 3: Write the failing movement validation test**

Create `tests/unit/movement_validation.luau`:

```luau
local MovementValidation = require("../../src/shared/Core/Utilities/MovementValidation")

assert(MovementValidation.IsPlausible(3.2, 0.2, 24, 1.5) == true)
assert(MovementValidation.IsPlausible(8.5, 0.3, 24, 1.5) == true)
assert(MovementValidation.IsPlausible(100, 0.2, 24, 1.5) == false)
assert(MovementValidation.IsPlausible(1, 0, 24, 1.5) == false)
assert(MovementValidation.IsPlausible(1, -0.1, 24, 1.5) == false)
assert(MovementValidation.IsPlausible(0 / 0, 0.2, 24, 1.5) == false)
assert(MovementValidation.IsPlausible(1, 0 / 0, 24, 1.5) == false)
assert(MovementValidation.IsPlausible(math.huge, 0.2, 24, 1.5) == false)
assert(MovementValidation.IsPlausible(1, math.huge, 24, 1.5) == false)

print("movement_validation: PASS")
```

- [ ] **Step 4: Run the movement test and verify it fails**

Run:

```powershell
lune run tests/unit/movement_validation.luau
```

Expected: FAIL because `MovementValidation.luau` has not been created locally.

- [ ] **Step 5: Implement movement validation**

Create `src/shared/Core/Utilities/MovementValidation.luau`:

```luau
--!strict

---/// Content \\\---

-- Purpose: Validates one server-observed horizontal movement sample.
-- Use when:
-- - A server growth or interaction system must reject non-finite or implausible displacement.
-- Avoid when:
-- - Correcting character position or implementing a full anti-cheat system.
-- Public API:
-- - MovementValidation.IsPlausible(HorizontalDistance, DeltaSeconds, MaximumRewardSpeed, DistanceSlack)

local MovementValidation = {}

local function IsFinite(Value:number): boolean
	return Value == Value and Value > -math.huge and Value < math.huge
end

function MovementValidation.IsPlausible(
	HorizontalDistance:number,
	DeltaSeconds:number,
	MaximumRewardSpeed:number,
	DistanceSlack:number
): boolean
	if not IsFinite(HorizontalDistance) or HorizontalDistance < 0 then return false end
	if not IsFinite(DeltaSeconds) or DeltaSeconds <= 0 then return false end
	if not IsFinite(MaximumRewardSpeed) or MaximumRewardSpeed <= 0 then return false end
	if not IsFinite(DistanceSlack) or DistanceSlack < 0 then return false end
	return HorizontalDistance <= MaximumRewardSpeed * DeltaSeconds + DistanceSlack
end

return table.freeze(MovementValidation)
```

- [ ] **Step 6: Run the movement test and verify it passes**

Run: `lune run tests/unit/movement_validation.luau`

Expected: `movement_validation: PASS`.

- [ ] **Step 6a: Mirror movement validation and prove parity**

Create or update `ReplicatedStorage.BiggerShared.Core.Utilities.MovementValidation` in the original Studio place through MCP with the exact local source. Read Studio Source back, normalize line endings, and compare it with `src/shared/Core/Utilities/MovementValidation.luau`.

Expected: normalized Studio Source equals normalized local source byte-for-byte. Stop if parity differs.

- [ ] **Step 7: Write the failing stomp validation test**

Create `tests/unit/stomp_validation.luau`:

```luau
local StompValidation = require("../../src/shared/Core/Utilities/StompValidation")

local function IsValid(
	X:number,
	Y:number,
	Z:number,
	Velocity:number,
	HalfX:number?,
	HalfY:number?,
	HalfZ:number?,
	Padding:number?,
	MaxHeight:number?
): boolean
	local ResolvedHalfX = if HalfX == nil then 4 else HalfX
	local ResolvedHalfY = if HalfY == nil then 1 else HalfY
	local ResolvedHalfZ = if HalfZ == nil then 4 else HalfZ
	local ResolvedPadding = if Padding == nil then 0.5 else Padding
	local ResolvedMaxHeight = if MaxHeight == nil then 6 else MaxHeight

	return StompValidation.IsValid(
		X,
		Y,
		Z,
		ResolvedHalfX,
		ResolvedHalfY,
		ResolvedHalfZ,
		ResolvedPadding,
		ResolvedMaxHeight,
		Velocity,
		-2
	)
end

assert(IsValid(0, 2, 0, -10) == true)
assert(IsValid(5, 2, 0, -10) == false)
assert(IsValid(0, 8, 0, -10) == false)
assert(IsValid(0 / 0, 2, 0, -10) == false)
assert(IsValid(math.huge, 2, 0, -10) == false)
assert(IsValid(0, 2, 0, 0 / 0) == false)
assert(IsValid(0, 2, 0, -10, 0, 1, 4) == false)
assert(IsValid(0, 2, 0, -10, 4, -1, 4) == false)
assert(IsValid(0, 2, 0, -10, 4, 1, 4, -0.5) == false)
assert(IsValid(0, 2, 0, -10, 4, 1, 4, 0.5, 0) == false)
assert(IsValid(0, 2, 0, 1) == false)

print("stomp_validation: PASS")
```

- [ ] **Step 8: Run the stomp test and verify it fails**

Run: `lune run tests/unit/stomp_validation.luau`

Expected: FAIL because `StompValidation.luau` has not been created locally.

- [ ] **Step 9: Implement stomp validation**

Create `src/shared/Core/Utilities/StompValidation.luau`:

```luau
--!strict

---/// Content \\\---

-- Purpose: Validates a stomp root position in objective-hitbox local space.
-- Use when:
-- - A server objective must reject side touches and non-descending contacts.
-- Avoid when:
-- - Resolving character ownership or applying rewards.
-- Public API:
-- - StompValidation.IsValid(LocalX, LocalY, LocalZ, HalfX, HalfY, HalfZ, HorizontalPadding, MaxHeight, VerticalVelocity, MinimumDownwardVelocity)

local StompValidation = {}

local function IsFinite(Value:number): boolean
	return Value == Value and Value > -math.huge and Value < math.huge
end

local function AreFinite(...:number): boolean
	for Index = 1, select("#", ...) do
		if not IsFinite(select(Index, ...)) then return false end
	end
	return true
end

function StompValidation.IsValid(
	LocalX:number,
	LocalY:number,
	LocalZ:number,
	HalfX:number,
	HalfY:number,
	HalfZ:number,
	HorizontalPadding:number,
	MaxHeight:number,
	VerticalVelocity:number,
	MinimumDownwardVelocity:number
): boolean
	if not AreFinite(
		LocalX,
		LocalY,
		LocalZ,
		HalfX,
		HalfY,
		HalfZ,
		HorizontalPadding,
		MaxHeight,
		VerticalVelocity,
		MinimumDownwardVelocity
	) then return false end
	if HalfX <= 0 or HalfY <= 0 or HalfZ <= 0 then return false end
	if HorizontalPadding < 0 or MaxHeight <= 0 then return false end
	if LocalY <= HalfY or LocalY > HalfY + MaxHeight then return false end
	if math.abs(LocalX) > HalfX + HorizontalPadding then return false end
	if math.abs(LocalZ) > HalfZ + HorizontalPadding then return false end
	return VerticalVelocity <= MinimumDownwardVelocity
end

return table.freeze(StompValidation)
```

- [ ] **Step 10: Run both tests and commit**

Before running the tests, create or update `ReplicatedStorage.BiggerShared.Core.Utilities.StompValidation` in the original Studio place through MCP with the exact local source. Read Studio Source back, normalize line endings, and stop if it differs from `src/shared/Core/Utilities/StompValidation.luau`.

Run:

```powershell
lune run tests/unit/movement_validation.luau
lune run tests/unit/stomp_validation.luau
```

Expected: both print `PASS`.

Commit:

```powershell
git add aftman.toml src/shared/Core/Utilities/MovementValidation.luau src/shared/Core/Utilities/StompValidation.luau tests/unit
git commit -m "test(mvp-003): add validation coverage"
```

---

### Task 2: Fix Critical Teleport-Driven Size Gain

**Files:**
- Modify: `src/server/Game/Config/MovementConfig.luau`
- Modify: `src/server/Game/Systems/MovementGrowthSystem.luau`

**Interfaces:**
- Consumes: `MovementValidation.IsPlausible` from Task 1.
- Produces: movement rewards only while `Session.State == "InLobby"` and only from plausible horizontal samples.

- [ ] **Step 1: Extend the movement config**

Replace `MovementConfig.luau` with:

```luau
--!strict
--// Config \\\--

return table.freeze({
	TickRate = 0.2,
	MinimumRewardInterval = 0.5,
	DistanceThreshold = 3,
	MaximumRewardSpeed = 24,
	DistanceSlack = 1.5,
	MaximumSampleGap = 1,
	BaseGain = 1,
})
```

- [ ] **Step 2: Replace movement sampling with stateful plausible-distance accumulation**

In `MovementGrowthSystem.luau`, replace `LastPositions` and `LastRewardTimes` with:

```luau
type MovementState = {
	LastPosition:Vector3,
	LastSampleTime:number,
	LastRewardTime:number,
	AccumulatedDistance:number,
}

local MovementStates:{[Player]: MovementState} = {}
```

Require the canonical modules:

```luau
local Sessions = require(script.Parent.Parent.Parent.Core.Registry.RuntimeRegistry.Sessions)
local MovementValidation = require(
	game:GetService("ReplicatedStorage").BiggerShared.Core.Utilities.MovementValidation
)
```

Replace `ProcessMovement` with:

```luau
local function ProcessMovement()
	local Success, GrowthService = pcall(function()
		return ServiceRegistry.Get("GrowthService")
	end)
	if not Success or not GrowthService then return end

	local CurrentTime = time()
	for _, Player in Players:GetPlayers() do
		local Session = Sessions.Get(Player)
		local Character = Player.Character
		local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
		if not Session or Session.State ~= "InLobby" or not RootPart or not RootPart:IsA("BasePart") then
			MovementStates[Player] = nil
			continue
		end

		local CurrentPosition = RootPart.Position
		local State = MovementStates[Player]
		if not State then
			MovementStates[Player] = {
				LastPosition = CurrentPosition,
				LastSampleTime = CurrentTime,
				LastRewardTime = CurrentTime,
				AccumulatedDistance = 0,
			}
			continue
		end

		local DeltaSeconds = CurrentTime - State.LastSampleTime
		local Delta = CurrentPosition - State.LastPosition
		local HorizontalDistance = Vector3.new(Delta.X, 0, Delta.Z).Magnitude
		State.LastPosition = CurrentPosition
		State.LastSampleTime = CurrentTime

		if DeltaSeconds > MovementConfig.MaximumSampleGap
			or not MovementValidation.IsPlausible(
				HorizontalDistance,
				DeltaSeconds,
				MovementConfig.MaximumRewardSpeed,
				MovementConfig.DistanceSlack
			)
		then
			State.AccumulatedDistance = 0
			continue
		end

		State.AccumulatedDistance += HorizontalDistance
		if State.AccumulatedDistance < MovementConfig.DistanceThreshold then continue end
		if CurrentTime - State.LastRewardTime < MovementConfig.MinimumRewardInterval then continue end

		State.AccumulatedDistance = 0
		State.LastRewardTime = CurrentTime
		GrowthService:AddBigger(Player, {
			BaseGain = MovementConfig.BaseGain,
			Source = GrowthSource.Movement,
		})
	end
end
```

Replace `CleanupPlayer` with:

```luau
local function CleanupPlayer(Player:Player)
	MovementStates[Player] = nil
end
```

- [ ] **Step 3: Run offline checks for the Critical fix**

Run:

```powershell
lune run tests/unit/movement_validation.luau
stylua --check src/server/Game/Config/MovementConfig.luau src/server/Game/Systems/MovementGrowthSystem.luau
selene src/server/Game/Systems/MovementGrowthSystem.luau
rojo build default.project.json -o "$env:TEMP\bigger-mvp003-critical.rbxl"
```

Expected: unit test passes; formatting, lint, and build exit 0.

- [ ] **Step 4: Verify the Critical fix twice in Studio**

Run Play Solo twice:

1. Walk normally in Lobby for at least six studs: Size increases.
2. Teleport the character more than 100 studs between scheduler samples: Size does not increase from that sample.
3. Enter/return from WORLD1: portal teleports do not grant movement Size.
4. Inspect Output: no runtime errors or recurring warnings.

- [ ] **Step 5: Commit the Critical fix**

```powershell
git add src/server/Game/Config/MovementConfig.luau src/server/Game/Systems/MovementGrowthSystem.luau
git commit -m "fix: reject implausible movement growth"
```

---

### Task 3: Add Idempotent Lobby Recovery and WORLD1 Integrity

**Files:**
- Modify: `src/server/Core/Services/SessionService.luau`
- Modify: `src/server/Game/Services/PortalService.luau`
- Modify: `src/server/Game/Services/WorldInstanceService.luau`
- Modify: `src/server/Game/Services/DestructionService.luau`
- Create: `tests/studio/session_recovery.luau`

**Interfaces:**
- Produces: `SessionService:TransitionState(Player:Player, ExpectedState:string, NextState:string): boolean`.
- Produces: `SessionService:RecoverToLobby(Player:Player, Reason:string): boolean`.
- Produces: `WorldInstanceService:RecoverPlayer(Player:Player, Reason:string, Respawn:boolean): ()`.
- Guarantees: every entry, completion, teleport, and cleanup failure clears runtime ownership, objective presentation, portal debounce, and authoritative session state.

- [ ] **Step 1: Add legal transitions and idempotent recovery**

Add to `SessionService.luau`:

```luau
local AllowedTransitions:{[string]: {[string]: boolean}} = table.freeze({
	InLobby = table.freeze({EnteringWorld = true}),
	EnteringWorld = table.freeze({InWorld = true}),
	InWorld = table.freeze({Returning = true}),
	Returning = table.freeze({}),
})

function SessionService:TransitionState(
	Player:Player,
	ExpectedState:string,
	NextState:string
): boolean
	local Session = Sessions.Get(Player)
	if not Session or Session.State ~= ExpectedState then return false end
	local NextStates = AllowedTransitions[ExpectedState]
	if not NextStates or not NextStates[NextState] then return false end
	Session.State = NextState
	return true
end

function SessionService:RecoverToLobby(Player:Player, Reason:string): boolean
	local Session = Sessions.Get(Player)
	if not Session then
		Logger.Warn("Session", "Lobby recovery skipped without session for %s (%s)", Player.Name, Reason)
		return false
	end

	Session.State = "InLobby"
	Session.CurrentWorldInstanceId = nil
	ClearObjectiveAttributes(Player)
	Logger.Warn("Session", "Recovered %s to lobby state (%s)", Player.Name, Reason)
	return true
end
```

`RecoverToLobby` must not inspect or require an expected current state. Repeated calls must leave the same state and presentation.
`TransitionState` is only for forward lifecycle progress. Every rollback or failure recovery must bypass the transition graph and use `RecoverToLobby` through the cross-service recovery coordinator.

- [ ] **Step 2: Add the cross-service recovery coordinator**

Add to `WorldInstanceService.luau`:

```luau
function WorldInstanceService:RecoverPlayer(Player:Player, Reason:string, Respawn:boolean)
	local WorldInstance = WorldInstances.Get(Player)
	if WorldInstance then
		local Disconnected, DisconnectMessage = pcall(function()
			DisconnectWorld(WorldInstance)
		end)
		if not Disconnected then
			Logger.Warn("WorldInstance", "Runtime disconnect failed for %s: %s", Player.Name, tostring(DisconnectMessage))
		end

		local Destroyed, DestroyMessage = pcall(function()
			WorldInstance.Model:Destroy()
		end)
		if not Destroyed then
			Logger.Warn("WorldInstance", "Runtime destroy failed for %s: %s", Player.Name, tostring(DestroyMessage))
		end
	end
	local Removed, RemoveMessage = pcall(function()
		WorldInstances.Remove(Player)
	end)
	if not Removed then
		Logger.Warn("WorldInstance", "Runtime registry cleanup failed for %s: %s", Player.Name, tostring(RemoveMessage))
	end

	local PortalSuccess, PortalService = pcall(function()
		return ServiceRegistry.Get("PortalService")
	end)
	if PortalSuccess and PortalService then
		pcall(function()
			PortalService:ClearDebounce(Player)
		end)
	end

	local Recovered, RecoveryMessage = pcall(function()
		local SessionService = ServiceRegistry.Get("SessionService")
		SessionService:RecoverToLobby(Player, Reason)
	end)
	if not Recovered then
		Logger.Warn("WorldInstance", "Authoritative lobby recovery failed for %s: %s", Player.Name, tostring(RecoveryMessage))
	end

	if not Respawn or not Player.Parent then return end
	local Respawned, RespawnMessage = pcall(function()
		Player:LoadCharacter()
	end)
	if not Respawned then
		Logger.Warn("WorldInstance", "Lobby respawn failed for %s: %s", Player.Name, tostring(RespawnMessage))
	end
end
```

Every step before authoritative state restoration is isolated so it cannot prevent the protected `RecoverToLobby` attempt. The exact order is disconnect, destroy, registry removal, portal debounce cleanup, protected lobby recovery, then optional native character reload. The native character reload is the only fallback when a required Lobby marker disappears. Do not use an arbitrary CFrame.

- [ ] **Step 3: Make entry fail closed**

At the start of `CreateWorldForPlayer`, distinguish a valid duplicate request from stale or inconsistent ownership:

```luau
local RegisteredWorld = WorldInstances.Get(Player)
local SessionWorldInstanceId = Session.CurrentWorldInstanceId
local HasConsistentActiveWorld = RegisteredWorld
	and RegisteredWorld.OwnerPlayer == Player
	and RegisteredWorld.OwnerUserId == Player.UserId
	and RegisteredWorld.WorldInstanceId == SessionWorldInstanceId
	and RegisteredWorld.Model.Parent ~= nil

if HasConsistentActiveWorld then
	LogFailure(Player, RegisteredWorld.WorldInstanceId, "Duplicate world allocation rejected")
	return nil
end

if RegisteredWorld or SessionWorldInstanceId then
	self:RecoverPlayer(Player, "InconsistentWorldOwnership", false)
	return nil
end
```

A consistent registry/session pair is already authoritative and valid: reject the duplicate allocation without destroying or recovering that world. Use `RecoverPlayer` only when one side is missing, identifiers disagree, ownership disagrees, or the registered model is no longer active.

Preflight `ReturnSpawn` before cloning:

```luau
if not GetReturnMarker() then
	self:RecoverPlayer(Player, "MissingReturnSpawnBeforeEntry", false)
	return nil
end
```

Replace the hardcoded `EntrySpawn` Part fallback with:

```luau
local EntryMarker = GetMarker(RuntimeWorld, World1Config.EntryMarkerName)
if not EntryMarker then
	RuntimeWorld:Destroy()
	self:RecoverPlayer(Player, "MissingEntrySpawn", false)
	return nil
end
```

Every remaining entry creation, objective binding, or entry teleport failure must call `RecoverPlayer` instead of writing session fields directly.

- [ ] **Step 4: Revalidate ReturnSpawn at completion**

Keep the preflight from Step 3. `ReturnPlayerToLobby` must call `GetReturnMarker()` on every invocation so it resolves `ReturnSpawn` again immediately before teleport:

```luau
local Returned = WorldInstanceService:ReturnPlayerToLobby(Player)
if not Returned then
	WorldInstanceService:RecoverPlayer(Player, "ReturnSpawnUnavailableAtCompletion", true)
	return
end

WorldInstanceService:RecoverPlayer(Player, "ObjectiveCompleted", false)
```

Keep teleport math private to `WorldInstanceService`; do not duplicate it in `DestructionService`.

The objective lock and `+1 Destruction` mutation remain before this return attempt. The lock prevents a second reward; recovery completes even if the marker vanished after entry.

- [ ] **Step 5: Route every failure through recovery**

Search all lifecycle exits:

```powershell
rg -n "FailEntry|CleanupPlayer|ReturnPlayerToLobby|CreateWorldForPlayer|TryCompleteObjective|Session\.State\s*=|ClearDebounce" src/server/Game src/server/Core/Services/SessionService.luau
```

For each entry, completion, teleport, and cleanup failure, verify the path ends in `RecoverPlayer` or `RecoverToLobby`. Direct state rollback is prohibited outside `SessionService`.

- [ ] **Step 6: Add recovery regression tests with a real Studio player**

Create `tests/studio/session_recovery.luau`:

```luau
return function(Player:Player, SessionService:any, Sessions:any)
	for _, State in {"EnteringWorld", "InWorld", "Returning"} do
		local Session = Sessions.Get(Player)
		assert(Session, "test player session missing")
		Session.State = State
		Session.CurrentWorldInstanceId = "RECOVERY_TEST"
		Player:SetAttribute("CurrentWorldId", "WORLD1")
		Player:SetAttribute("ObjectiveActive", true)
		Player:SetAttribute("ObjectiveText", "test")
		Player:SetAttribute("ObjectiveReward", "test")

		assert(SessionService:RecoverToLobby(Player, `Test_{State}`) == true)
		assert(Session.State == "InLobby")
		assert(Session.CurrentWorldInstanceId == nil)
		assert(Player:GetAttribute("CurrentWorldId") == nil)
		assert(Player:GetAttribute("ObjectiveActive") == false)
		assert(Player:GetAttribute("ObjectiveText") == nil)
		assert(Player:GetAttribute("ObjectiveReward") == nil)
		assert(SessionService:RecoverToLobby(Player, `Repeat_{State}`) == true)
	end
end
```

Studio recovery-test harness:

1. Mirror the exact local `tests/studio/session_recovery.luau` source into a temporary `ModuleScript` at `ServerStorage.MVP003Tests.SessionRecovery`.
2. Read the temporary ModuleScript source back and compare normalized line endings with the local test file. Stop if parity differs.
3. Start Play Solo, obtain a real connected `Player`, require the temporary ModuleScript, and pass the live `SessionService` and `Sessions` registry.
4. Record the assertions and Studio Output.
5. Stop Play Solo and remove `ServerStorage.MVP003Tests`, including on a failed test attempt.

Never construct a fake Player. Never require, register, or ship the temporary harness from production runtime code.

- [ ] **Step 7: Run fail-closed Studio scenarios**

1. Missing `WORLD1.EntrySpawn`: no fallback Part, no runtime clone, Lobby state restored.
2. Missing `Big Island.ReturnSpawn` before entry: entry rejected and cleanup complete.
3. Remove `ReturnSpawn` after the player enters WORLD1, then complete the objective: reward is exactly once, runtime and objective cleanup complete, portal debounce clears, native respawn occurs, and state is `InLobby` rather than `Returning`.
4. Repeated portal touches create at most one runtime world.
5. Inject cleanup failure and verify registry removal plus lobby recovery still occur.

- [ ] **Step 8: Run offline checks and commit**

```powershell
stylua --check src/server/Core/Services/SessionService.luau src/server/Game/Services/PortalService.luau src/server/Game/Services/WorldInstanceService.luau src/server/Game/Services/DestructionService.luau tests/studio/session_recovery.luau
selene src/server/Core/Services/SessionService.luau src/server/Game/Services/PortalService.luau src/server/Game/Services/WorldInstanceService.luau src/server/Game/Services/DestructionService.luau
rojo build default.project.json -o "$env:TEMP\bigger-mvp003-world.rbxl"
```

Expected: all exit 0. Mirror changed `src` files into the original Studio place, compare normalized parity, then commit:

```powershell
git add src/server/Core/Services/SessionService.luau src/server/Game/Services/PortalService.luau src/server/Game/Services/WorldInstanceService.luau src/server/Game/Services/DestructionService.luau tests/studio/session_recovery.luau
git commit -m "fix(mvp-003): add idempotent lobby recovery"
```

---

### Task 4: Fix High-Severity Stomp Boundary Validation

**Files:**
- Modify: `src/server/Game/Config/World1Config.luau`
- Modify: `src/server/Game/Services/DestructionService.luau`

**Interfaces:**
- Consumes: `StompValidation.IsValid` from Task 1.
- Produces: objective completion only when the owner root is descending inside the hitbox footprint and permitted height window.

- [ ] **Step 1: Add explicit stomp geometry limits**

Add to `World1Config.Objective`:

```luau
HorizontalPadding = 1,
MaximumRootHeight = 8,
```

Remove `AboveHitboxPadding`; it is replaced by local-space bounds.

- [ ] **Step 2: Replace IsValidStomp**

Require the validator:

```luau
local StompValidation = require(
	game:GetService("ReplicatedStorage").BiggerShared.Core.Utilities.StompValidation
)
```

Replace `IsValidStomp` with:

```luau
local function IsValidStomp(Player:Player, Hitbox:BasePart): boolean
	local RootPart = GetRootPart(Player)
	if not RootPart then return false end

	local LocalPosition = Hitbox.CFrame:PointToObjectSpace(RootPart.Position)
	local HalfSize = Hitbox.Size / 2
	return StompValidation.IsValid(
		LocalPosition.X,
		LocalPosition.Y,
		LocalPosition.Z,
		HalfSize.X,
		HalfSize.Y,
		HalfSize.Z,
		World1Config.Objective.HorizontalPadding,
		World1Config.Objective.MaximumRootHeight,
		RootPart.AssemblyLinearVelocity.Y,
		World1Config.Objective.MinimumDownwardVelocity
	)
end
```

- [ ] **Step 3: Run unit and offline checks**

Run:

```powershell
lune run tests/unit/stomp_validation.luau
stylua --check src/server/Game/Config/World1Config.luau src/server/Game/Services/DestructionService.luau
selene src/server/Game/Services/DestructionService.luau
rojo build default.project.json -o "$env:TEMP\bigger-mvp003-stomp.rbxl"
```

Expected: all exit 0.

- [ ] **Step 4: Verify stomp behavior in Studio**

Run Play Solo twice and verify:

1. A downward center stomp grants exactly `+1 Destruction` once.
2. A side touch does not complete.
3. An accessory/limb touch while the root is outside X/Z bounds does not complete.
4. A root above `MaximumRootHeight` does not complete.
5. A second contact after completion grants nothing.

- [ ] **Step 5: Run two-player ownership isolation**

Start a two-player Studio session. Each player enters a distinct clone; player A cannot complete player B's objective; each valid owner completion grants only that owner.

- [ ] **Step 6: Commit the stomp fix**

```powershell
git add src/server/Game/Config/World1Config.luau src/server/Game/Services/DestructionService.luau
git commit -m "fix: validate stomp inside objective bounds"
```

---

### Task 5: Run the Recovery and ReturnSpawn Regression Gate

**Files:**
- Test: `tests/studio/session_recovery.luau`
- Review: `src/server/Core/Services/SessionService.luau`
- Review: `src/server/Game/Services/PortalService.luau`
- Review: `src/server/Game/Services/WorldInstanceService.luau`
- Review: `src/server/Game/Services/DestructionService.luau`

**Interfaces:**
- Consumes: `SessionService:RecoverToLobby(Player:Player, Reason:string): boolean`.
- Consumes: `WorldInstanceService:RecoverPlayer(Player:Player, Reason:string, Respawn:boolean): ()`.

- [ ] **Step 1: Verify recovery is independent of the current state**

Using the temporary `ServerStorage.MVP003Tests.SessionRecovery` harness defined in Task 3, run `tests/studio/session_recovery.luau` in Play Solo with the real connected player. Start from each unexpected state—`EnteringWorld`, `InWorld`, and `Returning`—and invoke recovery twice. Verify normalized source parity before execution and remove the temporary Studio folder after the run.

Expected after every call: authoritative state is `InLobby`, `CurrentWorldInstanceId` is `nil`, and objective presentation attributes are cleared. No assertion may depend on an expected source state.

- [ ] **Step 2: Verify all failure exits converge on idempotent recovery**

Run:

```powershell
rg -n "FailEntry|CleanupPlayer|ReturnPlayerToLobby|CreateWorldForPlayer|TryCompleteObjective|Session\.State\s*=|ClearDebounce" src/server/Game src/server/Core/Services/SessionService.luau
```

For every entry, completion, teleport, and cleanup failure, trace evidence that runtime cleanup, objective cleanup, portal debounce cleanup, and lobby state recovery all execute even when an earlier cleanup action fails. A cleanup error must be isolated so later guarantees still run.

- [ ] **Step 3: Verify ReturnSpawn disappearance during WORLD1**

In Play Solo:

1. Enter WORLD1 with a valid `ReturnSpawn` preflight.
2. Remove `ReturnSpawn` while the player is inside.
3. Complete the objective once, then trigger the completion contact again.
4. Record that Destruction increased by exactly one.
5. Record that the runtime model and registry entry are gone, `CurrentWorldInstanceId` is `nil`, objective presentation is cleared, portal debounce is cleared, and state is `InLobby`.
6. Record that the player was recovered with native character reload and is not left in `Returning` or inside a destroyed world.
7. Restore the original marker and verify the portal can be entered again.

Do not use or accept an arbitrary CFrame fallback. Label this test manual if MCP cannot execute or inspect it.

- [ ] **Step 4: Record regression evidence**

Add the state-by-state results, repeated-call results, disappearing-marker scenario, Output logs, and local-to-Studio parity evidence to the immutable initial audit report before its release decision is finalized.


---

### Task 6: Harden Runtime Resilience and Numeric Boundaries

**Files:**
- Modify: `src/server/Core/Scheduler/Scheduler.luau`
- Modify: `src/server/Core/Events/EventBus.luau`
- Modify: `src/server/Core/Registry/RuntimeRegistry/Sessions.luau`
- Modify: `src/server/Core/Registry/RuntimeRegistry/WorldInstances.luau`
- Modify: `src/server/Core/Services/GrowthService.luau`

**Interfaces:**
- Produces: isolated callback execution, no unused mutable registry enumeration, and safe-integer Size mutation.

- [ ] **Step 1: Isolate scheduler callback failures**

Replace the direct callback call inside the scheduler loop with:

```luau
local Success, Message = xpcall(Config.Callback, debug.traceback)
if not Success then
	Logger.Warn("Scheduler", "Job %s failed: %s", Name, tostring(Message))
end
```

In `Scheduler.AddJob`, reject invalid definitions:

```luau
if Config.Name == "" then error("[Scheduler] Job name cannot be empty") end
if Config.IntervalSeconds <= 0 then error("[Scheduler] IntervalSeconds must be positive") end
if Jobs[Config.Name] then error(`[Scheduler] Job already exists: {Config.Name}`) end
Jobs[Config.Name] = Config
```

- [ ] **Step 2: Isolate EventBus subscriber failures**

Require `Logger`, then replace the publish call with:

```luau
local Arguments = table.pack(...)
for _, Entry in List do
	local Success, Message = xpcall(function()
		Entry.Callback(table.unpack(Arguments, 1, Arguments.n))
	end, debug.traceback)
	if not Success then
		Logger.Warn("EventBus", "Subscriber failed for %s: %s", EventName, tostring(Message))
	end
end
```

- [ ] **Step 3: Eliminate mutable registry enumeration**

Verify there are no callers:

```powershell
rg -n "Sessions\.GetAll|WorldInstances\.GetAll" src
```

Expected: no matches outside the two function definitions. Remove `Sessions.GetAll` and `WorldInstances.GetAll` entirely; callers retain the narrow `Get`, `Set`, and `Remove` APIs.

- [ ] **Step 4: Add the safe Size boundary**

Add to `GrowthService.luau`:

```luau
local MAX_SAFE_INTEGER = 9007199254740991

local function NormalizeBigger(Value:number): number?
	if Value ~= Value or Value <= -math.huge or Value >= math.huge then return nil end
	if Value < 1 or Value > MAX_SAFE_INTEGER then return nil end
	return math.floor(Value)
end
```

Change `SetBigger` to return `boolean`, normalize before mutation, and return false on rejection:

```luau
function GrowthService:SetBigger(Player:Player, Value:number): boolean
	local Session = Sessions.Get(Player)
	local NormalizedValue = NormalizeBigger(Value)
	if not Session or not NormalizedValue then return false end

	Session.Bigger = NormalizedValue
	Player:SetAttribute("Bigger", NormalizedValue)
	local Leaderstats = Player:FindFirstChild("leaderstats")
	local BiggerStat = Leaderstats and Leaderstats:FindFirstChild("Bigger")
	if BiggerStat and BiggerStat:IsA("IntValue") then BiggerStat.Value = NormalizedValue end
	EventBus.Publish("BiggerChanged", Player, NormalizedValue)
	return true
end
```

- [ ] **Step 5: Run offline and fault-injection checks**

Run formatting, Selene, and Rojo build. In Studio command execution, register one scheduler callback and one EventBus subscriber that error once; verify later callbacks continue and one controlled warning is emitted. Call `GrowthService:SetBigger` with `0/0`, `math.huge`, `-1`, and `MAX_SAFE_INTEGER + 1`; verify session state does not change.

- [ ] **Step 6: Commit the resilience tier**

```powershell
git add src/server/Core/Scheduler/Scheduler.luau src/server/Core/Events/EventBus.luau src/server/Core/Registry/RuntimeRegistry/Sessions.luau src/server/Core/Registry/RuntimeRegistry/WorldInstances.luau src/server/Core/Services/GrowthService.luau
git commit -m "fix: harden runtime failure boundaries"
```

---

### Task 7: Clear Low-Severity Hygiene Findings

**Files:**
- Modify: `stylua.toml`
- Create: `.gitattributes`
- Modify: `src/server/Core/Registry/ServiceRegistry.luau`
- Modify: `src/server/Game/Formula/GrowthFormula.luau`
- Modify: `src/shared/Core/Enums/GrowthSource.luau`
- Conditionally delete after full caller search: `src/shared/Types/GrowthTypes.luau`

**Interfaces:**
- Produces: a warning-free, formatted, MVP-only source tree.

- [ ] **Step 1: Add the repository formatting policy**

Change only the line-ending setting in `stylua.toml`:

```toml
line_endings = "Unix"
```

Create `.gitattributes` with the exact initial LF policy:

```gitattributes
*.lua text eol=lf
*.luau text eol=lf
*.toml text eol=lf
*.json text eol=lf
*.md text eol=lf
```

Do not run a repository-wide formatting or line-ending rewrite. The policy applies as files are intentionally changed within approved scope.

- [ ] **Step 2: Search the entire source and test tree before low-severity deletion**

Run before deleting any growth symbol or module:

```powershell
rg -n "GrowthFormula|Get[A-Za-z]+Multiplier|GrowthSource\.(Quest|NPC|Pet)|BiggerShared\.Types\.GrowthTypes|shared/Types/GrowthTypes" src tests
```

Classify every match as definition or caller and record it in the initial audit report. Do not delete a symbol with a current caller. If fixing the finding requires editing a caller outside the exact scope, record the path and reason in `tasks/MVP-003.md`, extend the exact scope, and stop for Tech Lead approval before editing.

- [ ] **Step 3: Remove speculative growth multipliers only when uncalled**

Replace `GrowthFormula.Calculate` and remove all six unused multiplier helpers:

```luau
function GrowthFormula.Calculate(_Session:Session, Context:GrowthContext): number
	local ZoneMultiplier = Context.ZoneMultiplier or 1
	return math.floor(Context.BaseGain * ZoneMultiplier)
end
```

- [ ] **Step 4: Remove unused non-MVP growth sources only when uncalled**

Replace `GrowthSource.luau` with:

```luau
--!strict

return table.freeze({
	Movement = "Movement",
	AFKZone = "AFKZone",
})
```

- [ ] **Step 5: Remove the duplicate type module only when uncalled**

Confirm no require points at `BiggerShared.Types.GrowthTypes`:

```powershell
rg -n "BiggerShared\.Types\.GrowthTypes|shared/Types/GrowthTypes" src tests
```

Expected: no caller matches. If any caller exists, do not delete the module. If none exists, delete only `src/shared/Types/GrowthTypes.luau`; retain `src/shared/Core/Types/GrowthTypes.luau` as canonical.

- [ ] **Step 6: Use the native clone**

Replace `ServiceRegistry.GetAll` with:

```luau
function ServiceRegistry.GetAll():{[string]: any}
	return table.freeze(table.clone(Services))
end
```

- [ ] **Step 7: Format only scoped files, then check the full tree**

Run:

```powershell
stylua src/server/Core/Registry/ServiceRegistry.luau src/server/Game/Formula/GrowthFormula.luau src/shared/Core/Enums/GrowthSource.luau src/shared/Core/Utilities/MovementValidation.luau src/shared/Core/Utilities/StompValidation.luau tests/unit/movement_validation.luau tests/unit/stomp_validation.luau tests/studio/session_recovery.luau
stylua --check src tests
selene src
rojo build default.project.json -o "$env:TEMP\bigger-mvp003-final.rbxl"
```

Expected: `stylua`, `selene`, and `rojo` all exit 0; Selene reports `0 errors`, `0 warnings`, `0 parse errors`.

- [ ] **Step 8: Commit the hygiene tier**

```powershell
git add .gitattributes stylua.toml src/server/Core/Registry/ServiceRegistry.luau src/server/Game/Formula/GrowthFormula.luau src/shared/Core/Enums/GrowthSource.luau src/shared/Types/GrowthTypes.luau
git commit -m "chore(mvp-003): clear static findings"
```

---

### Task 8: Run the Final Release Gate and Record Evidence

**Files:**
- Modify: `docs/superpowers/reports/mvp-003/README.md`
- Finalize once: `docs/superpowers/reports/mvp-003/2026-07-15-initial-audit.md`
- Modify: `docs/TASKS.md`
- Modify: `docs/CHANGELOG.md`

**Interfaces:**
- Produces: auditable release evidence and standing MVP-003 status.

- [ ] **Step 1: Run the complete offline gate**

```powershell
lune run tests/unit/movement_validation.luau
lune run tests/unit/stomp_validation.luau
stylua --check src tests
selene src
rojo build default.project.json -o "$env:TEMP\bigger-mvp003-release.rbxl"
git diff --check
```

Expected: every command exits 0.

- [ ] **Step 2: Run the complete Studio gate**

Execute and record:

1. Invalid level cannot enter WORLD1.
2. Valid level enters exactly one private clone.
3. Normal Lobby walking grants Size; implausible displacement does not.
4. Entry and return teleport do not grant movement Size.
5. Valid stomp grants exactly one Destruction.
6. Side, remote-limb, excessive-height, and non-descending contacts grant nothing.
7. Missing EntrySpawn and ReturnSpawn fail closed.
8. ReturnSpawn disappearing after entry grants exactly one reward, completes all cleanup, and recovers the player without an arbitrary CFrame.
9. Idempotent recovery succeeds twice from unexpected EnteringWorld, InWorld, and Returning states.
10. Two players receive isolated worlds and cannot complete each other's objective.
11. PlayerRemoving cleans the runtime clone.
12. Two full runs leave Studio Output free of errors and warning leaks.

- [ ] **Step 3: Write the evidence report**

Finalize the initial dated report with these exact sections:

```markdown
# MVP-003 Initial Audit — 2026-07-15

## Baseline
## Critical Findings
## High Findings
## Medium Findings
## Low Findings
## Offline Verification
## Studio Verification Run 1
## Studio Verification Run 2
## Two-Player Verification
## Remaining Risks
## Release Decision
```

Each finding records `Status`, `Evidence`, `Files`, and `Verification`. Release Decision is `READY` only when every Critical and High finding is fixed and verified.

After the Release Decision is recorded, do not rewrite this dated report. Add its decision and link to `docs/superpowers/reports/mvp-003/README.md`. Every future audit cycle creates a new dated report file and updates only the index.

- [ ] **Step 4: Update milestone documents**

Add an MVP-003 permanent quality-gate entry to `docs/TASKS.md`. Add a dated changelog entry summarizing security, lifecycle, validation, and QA changes without claiming Studio tests that were not run.

- [ ] **Step 5: Commit documentation and present for review**

```powershell
git add tasks/MVP-003.md docs/superpowers/plans/2026-07-15-mvp-003-release-gate.md docs/superpowers/reports/mvp-003/README.md docs/superpowers/reports/mvp-003/2026-07-15-initial-audit.md docs/TASKS.md docs/CHANGELOG.md
git commit -m "docs(mvp-003): record permanent quality gate"
git status --short
git log --oneline -8
```

Expected: clean tree and a separate commit for each severity tier. Present the commit list and verification evidence to the user; do not push.

---

## Deferred Findings Requiring Separate Approval

- Renaming the existing authoritative field `Bigger` to the documented term `Size` is a saved-data and public-contract migration, not a surgical lint fix. It requires its own task and migration design.
- Full server anti-teleport correction is broader than rejecting movement rewards. MVP-003 prevents teleport-derived Size gain and tightens objective validation, but position correction/kick policy requires a separate anti-cheat design.
- Persistence feature work remains outside MVP-003 product scope; MVP-003 audits defects in persistence code delivered by its owning gameplay milestone.

---

## Permanent Future MVP Audit Workflow

Do not split this plan into MVP-003 and MVP-004. MVP-003 permanently owns the defect process while fixes remain in their actual gameplay, shared, client, or Core source files.

For every later MVP:

1. Add `Audit Cycle: MVP-XXX` to `tasks/MVP-003.md`.
2. Record exact files introduced or modified by that MVP.
3. Add shared dependencies that can propagate or receive defects.
4. Audit and fix Critical, then High, then Medium, then Low.
5. Run unit tests and offline checks.
6. Mirror final local source into the original Studio place through MCP and verify normalized parity.
7. Run Studio verification.
8. Run multiplayer verification for ownership, replication, networking, or private-instance changes.
9. Create a new immutable dated report under `docs/superpowers/reports/mvp-003/` with scope, findings, severity, fixes, files changed, verification, remaining risks, and release decision; add its link and decision to `docs/superpowers/reports/mvp-003/README.md`.
10. Refuse release readiness while a confirmed Critical or High item remains open.

Never create an `MVP-X.5` milestone for bug fixes. Use `Audit Cycle: MVP-004`, `Audit Cycle: MVP-005`, `Audit Cycle: MVP-006`, and later sections under the permanent MVP-003 gate.
