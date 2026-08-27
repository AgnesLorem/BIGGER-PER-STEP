# Spec: MVP-09 Game Feel, VFX/SFX Engine & Multi-Tier Aura System

**Date:** 2026-08-25
**Topic:** MVP-09 Game Feel & Aura System
**Goal:** Transform every player action into satisfying audiovisual feedback (adaptive SFX, Camera Shake, Floating Numbers, Impact VFX) and implement a multi-tier Super Saiyan Aura progression system with server-authoritative unlock, cosmetic selection, and permanent Growth buffs.

---

## 1. Game Feel & Audio/Visual Engine

### 1.1. SoundController (Adaptive SFX Engine)
- **Philosophy:** Scale-based pitch. All SFX pitch decreases from 1.0 → 0.4 as `VisualScale` grows (bigger character = deeper, heavier sounds).
- **Pitch Formula:** `Pitch = math.clamp(1.0 - (VisualScale - 1) * 0.004, 0.4, 1.0)`
- **Sound Categories:**
  | Category | Trigger | Behavior |
  |----------|---------|----------|
  | **Footstep** | `Humanoid.Running` signal, periodic (every ~0.4s at WalkSpeed) | Adaptive pitch; volume scales with `VisualScale` (0.3 → 0.8) |
  | **Stomp Impact** | `ObjectiveActive` attribute → `false` (Destruction completed) | Heavy bass thud; pitch based on scale; `PlaybackSpeed` = `Pitch * 0.8` |
  | **Level Up** | `Level` attribute changed | Ascending chime; fixed pitch 1.0 |
  | **Rebirth** | `Rebirth` attribute changed | Epic whoosh/explosion; fixed pitch 1.0 |
  | **Portal Enter** | `State` attribute → `"InWorld"` (or custom signal) | Mystical reverb whoosh |
  | **Aura Activate** | `EquippedAura` attribute changed to non-"None" | Ki charge-up hum |
- **Config Pattern:** `SoundConfig.luau` stores Roblox Asset IDs per category. Code accepts any valid ID. If ID = 0, sound is silently skipped (fail-close).
- **Architecture:** Client-only controller (`SoundController.luau`). Creates `Sound` objects parented to `HumanoidRootPart` or `SoundService`. Uses Object Pooling for footsteps (pool of 3-4 pre-created Sound instances cycled).

### 1.2. CameraShakeController (Scale-Adaptive Shake)
- **Philosophy:** Camera shake magnitude is proportional to `VisualScale`. Bigger character = stronger visual impact.
- **Shake Types:**
  | Event | Magnitude Formula | Duration | Frequency |
  |-------|-------------------|----------|-----------|
  | **Stomp** | `min(VisualScale * 0.15, 3.0)` studs offset | 0.35s | 20 Hz decay |
  | **Rebirth** | `2.0` studs offset (fixed, dramatic) | 0.6s | 15 Hz decay |
  | **Level Up** | `0.3` studs offset (subtle) | 0.2s | 25 Hz |
- **Implementation:** Modify `CurrentCamera.CFrame` with decaying sinusoidal offset per-frame via `RunService.RenderStepped`. Uses a shake queue (latest shake overrides or stacks additively up to a cap).
- **Architecture:** Client-only controller (`CameraShakeController.luau`).

### 1.3. FloatingFeedbackController (Pop-up Numbers)
- **Types:**
  | Event | Text Format | Color | Animation |
  |-------|-------------|-------|-----------|
  | **Bigger Gain** | `+{amount} Bigger` | White/Gold | Float up 2s, fade out |
  | **Destruction** | `CRUSH! +{amount}` | Red/Orange | Scale pop 1.5x → 1.0x, float up |
  | **Level Up** | `LEVEL UP! Lv{n}` | Yellow glow | Scale pop 2.0x → 1.0x, persist 1.5s |
  | **Rebirth** | `REBIRTH! R{n}` | Purple/Gold | Scale pop 2.5x → 1.0x, screen-wide, persist 2.0s |
- **Object Pooling:** Pre-allocate pool of 8-12 `BillboardGui` + `TextLabel` instances. Recycle oldest when pool is exhausted.
- **Attachment:** BillboardGui attached to `HumanoidRootPart` with `StudsOffset = Vector3.new(0, VisualScale * 0.5, 0)` so text appears above the scaled character's head.
- **Throttling for Bigger Gain:** Batch small `+Bigger` increments into a single display every 1.0s to avoid spam (show accumulated delta).
- **Architecture:** Client-only controller (`FloatingFeedbackController.luau`).

### 1.4. VFXController (Impact & Celebration Particles)
- **Effects:**
  | Event | VFX Description | Scale Behavior |
  |-------|-----------------|----------------|
  | **Stomp Shockwave** | Radial dust ring expanding outward from feet | Ring radius = `VisualScale * 3` studs; particle count proportional to scale (capped at 50) |
  | **Stomp Debris** | Small rock/debris chunks flying upward | 8-12 parts, velocity = 10-15 studs/s, lifetime 1.5s, `Debris:AddItem` cleanup |
  | **Rebirth Burst** | Golden energy column + lightning sparks | Fixed dramatic scale, 2s duration |
  | **Level Up Sparkle** | Brief upward sparkle ring around character | Subtle, 0.5s duration |
- **Particle Budget:** Maximum 50 particles per effect; maximum 2 concurrent VFX instances (newest replaces oldest if exceeded).
- **Architecture:** Client-only controller (`VFXController.luau`). Creates temporary `Part` + `ParticleEmitter` or `Beam` instances, cleans up via `Debris:AddItem`.

---

## 2. Multi-Tier Aura System (Super Saiyan Progression)

### 2.1. Aura Tiers & Destruction Milestones
| Tier | Name | Destruction Required | Growth Multiplier | Visual Description |
|------|------|---------------------|-------------------|--------------------|
| 0 | None | 0 | 1.00x | No aura |
| 1 | Green Ki | 10 | 1.15x | Soft green flame wisps |
| 2 | Blue Ki | 30 | 1.30x | Intense blue energy flame |
| 3 | Golden Ki | 60 | 1.50x | Golden Super Saiyan flame + small lightning sparks |
| 4 | God Ki | 100 | 1.75x | Deep crimson/magenta divine flame + prominent lightning arcs |

### 2.2. Buff Behavior (Cosmetic-Buff Decoupled)
- **Growth Buff:** Always applies the **highest unlocked tier** multiplier, regardless of which Aura is cosmetically equipped.
  - Example: Player has unlocked God Ki (100 Destruction). They equip Green Ki for aesthetics. Growth buff = **x1.75** (God Ki, highest unlocked).
- **Cosmetic Selection:** Player can equip any unlocked Aura tier or "None" via an Aura Wardrobe GUI.
- **Toggle VFX:** A toggle in the Wardrobe to disable the visual particle effect (VFX Off) while keeping the cosmetic selection for the overhead color tint. For performance optimization on low-end devices.
- **Persistence:** Both `UnlockedAuras` (list) and `EquippedAura` (string) are saved in the player profile. Survive Rebirth.
- **Multiplier Chain:** $\text{TotalMult} = \text{EquipmentMult} \times \text{RebirthMult} \times \text{AuraMult} \times \text{GamePasses}$

### 2.3. Auto-Unlock Mechanism
- **Passive unlock:** When `Session.Destruction >= Tier.RequiredDestruction`, the Aura tier is automatically unlocked server-side. No button press or currency cost required.
- **Server checks on:** Every `GrantDestruction()` call, and on session load (to catch offline milestones or data migration).
- **Client notification:** Server fires `BiggerEvents/Aura/StateChanged` RemoteEvent with the updated unlock state.

### 2.4. Server Architecture (`AuraService.luau`)
- **Pattern:** Mirrors `EquipmentService.luau` architecture.
- **RemoteEvents:** `BiggerEvents/Aura/Request`, `Response`, `StateChanged`.
- **RPC Actions:** `GetState`, `Equip` (cosmetic selection), `ToggleVFX`.
- **Auto-unlock hook:** Subscribe to `EventBus("DestructionGranted")` or call check in `GrantDestruction` flow.
- **Attributes set on Player:**
  - `EquippedAura` (string): Current cosmetic Aura name (e.g. "GreenKi", "GoldKi", "None").
  - `AuraMultiplier` (number): Highest unlocked tier multiplier.
  - `AuraVFXEnabled` (boolean): Whether to render particles.

### 2.5. Server Aura VFX Attachment (Multiplayer Visible)
- **Replication:** Server creates a `Part` (named "AuraContainer", non-collidable, fully transparent, welded to `HumanoidRootPart`) with `ParticleEmitter` children inside it. Since the Part is server-created and parented to the character model, all clients automatically see it via Roblox replication.
- **Scale sync:** When `BiggerChanged` fires, server updates `ParticleEmitter.Size` NumberSequence to match current `VisualScale`.
- **Equip change:** When `EquippedAura` changes, server destroys old AuraContainer and creates new one with appropriate particle colors/textures.
- **VFX Toggle:** When `AuraVFXEnabled = false`, server sets `ParticleEmitter.Enabled = false` (keeps Part for quick re-enable).

### 2.6. Client Architecture (`AuraController.luau`)
- **Pattern:** Mirrors `EquipmentController.luau`.
- **Responsibilities:**
  - Cache local Aura state (unlocked tiers, equipped Aura, VFX toggle).
  - Expose `OnStateChanged` callbacks for GUI binding.
  - Send RPC requests (`Equip`, `ToggleVFX`) to server.
  - **Does NOT create particles** (server handles replication).

### 2.7. Aura Wardrobe GUI
- **Location:** New section in the existing Shop/Equipment GUI, or a dedicated "Aura" tab on the LeftSidebar.
- **Layout:** Grid of 4 Aura tier cards. Each card shows:
  - Aura name & color preview
  - "🔒 Requires X Destruction" or "✅ Unlocked"
  - "Equipped" badge if currently selected
  - Tap to equip
- **Toggle:** A checkbox/switch at the top: "Show Aura VFX: ON/OFF".

---

## 3. Data Persistence & Profile Schema

### New Profile Fields
```luau
-- In PlayerProfileSchema.Defaults()
UnlockedAuras = {},       -- { GreenKi = true, BlueKi = true, ... }
EquippedAura = "None",    -- string: tier name or "None"
AuraVFXEnabled = true,    -- boolean: visual toggle
```

### Rebirth Behavior
- `UnlockedAuras`, `EquippedAura`, `AuraVFXEnabled` are **NOT reset** on Rebirth.

---

## 4. File Map

### New Files
| File | Layer | Purpose |
|------|-------|---------|
| `src/shared/Game/Config/AuraConfig.luau` | Shared | Tier definitions (name, destruction req, multiplier, particle config) |
| `src/shared/Game/Progression/AuraFormula.luau` | Shared | `GetMultiplier(UnlockedAuras)`, `GetUnlockableAuras(Destruction)`, `CanEquip(UnlockedAuras, AuraId)` |
| `src/server/Game/Services/AuraService.luau` | Server | Server-authoritative unlock, equip, VFX toggle, particle attachment |
| `src/client/controllers/AuraController.luau` | Client | State cache, RPC, GUI binding |
| `src/client/controllers/CameraShakeController.luau` | Client | Scale-adaptive camera shake |
| `src/client/controllers/FloatingFeedbackController.luau` | Client | Pop-up number display with pooling |
| `src/client/controllers/VFXController.luau` | Client | Impact particles (Stomp shockwave, Rebirth burst) |
| `src/client/controllers/SoundController.luau` | Client | Adaptive SFX engine |
| `src/shared/Core/Config/SoundConfig.luau` | Shared | Sound Asset ID registry |
| `tests/unit/aura_system.luau` | Test | Aura formula, config, service tests |
| `tests/unit/game_feel.luau` | Test | Sound/VFX config validation |
| `tasks/MVP-009.md` | Task | Official task specification |

### Modified Files
| File | Change |
|------|--------|
| `src/server/Game/Formula/GrowthFormula.luau` | Add `AuraMultiplier` to multiplier chain |
| `src/server/Core/Services/SaveService.luau` | Add `AuraMultiplier` to offline reward calculation |
| `src/server/Core/Services/SessionService.luau` | Set `AuraMultiplier`, `EquippedAura`, `AuraVFXEnabled` attributes |
| `src/server/Core/Utilities/PlayerProfileSchema.luau` | Add `UnlockedAuras`, `EquippedAura`, `AuraVFXEnabled` defaults |
| `src/server/Game/GameBootstrap.luau` | Register `AuraService` |
| `src/client/BiggerClientMain.client.luau` | Register new controllers (CameraShake, FloatingFeedback, VFX, Sound, Aura) |
| `src/client/controllers/GuiController.luau` | Add Aura wardrobe GUI bindings |

---

## 5. Verification Criteria

- Selene: 0 errors, 0 warnings
- StyLua: 0 diffs
- All existing unit tests (6 suites) remain 100% PASS
- New `aura_system.luau` and `game_feel.luau` tests: 100% PASS
