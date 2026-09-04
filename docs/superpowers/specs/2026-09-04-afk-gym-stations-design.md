# Design Specification: AFK Gym Training Stations (Tiers 1–7)

**Date**: 2026-09-04  
**Milestone**: MVP-AFK-GYM  
**Status**: APPROVED IN GRILL-ME INTERVIEW  
**Authors**: Senior Roblox Technical Artist (Fable Mode & System 2 Engine)

---

## 1. Executive Summary & Vision

In **Project BIGGER**, players walk around the Lobby, grow in physical scale (`Size`), destroy objects in isolated portals, earn permanent `Destruction` milestones, and rebirth to boost future growth.

To support AFK progression in the Lobby, the game features **7 AFK Zones** (`Table1`–`Table5`, `VipTable1`, `VipTable2`). Rather than a generic dining/food theme, the AFK Zone is designed as a **Stylized Outdoor Gym & Calisthenics Training Ground ("BIGGER GYM")**, reinforcing the game's core fantasy of building muscle, lifting heavy weights, and becoming massive.

This document specifies the complete 3D modeling, material, scale, and export pipeline for the 7 specialized workout stations created in Blender and prepared for Roblox Studio.

---

## 2. Core Architectural Invariants

| Invariant ID | Name | Formal Contract | Rationale & Proof |
| :--- | :--- | :--- | :--- |
| **`INV-01`** | Ground Pivot & Scale Invariant | $\forall m \in \text{Stations}: \text{Origin}_Z(m) = 0 \land 1\text{ stud} = 0.28\text{m}$ | Models snap flush to the Lobby floor without floating or ground-clipping. |
| **`INV-02`** | Progressive Hitbox Ergonomics | $\text{Size}(T_{1..3}) = 12\times 12\text{ studs}, \text{Size}(T_{4..5}) = 14\times 14\text{ studs}, \text{Size}(\text{VIP}_{1..2}) = 16\times 16\text{ studs}$ | Provides ample standing room for enlarged player avatars so `IsInsideZone` continuously detects players without clipping out of bounds. |
| **`INV-03`** | Zero-Regression BasePart Hierarchy | $\forall s \in \text{Stations}: \exists \text{BasePart } b \subset s \text{ s.t. } b.\text{Name} = \text{CandidateName}$ | The Rubber Gym Floor Mat acts as the primary BasePart named `Table1`..`Table5`, `VipTable1`, `VipTable2`. Directly satisfies `AFKZoneSystem.luau` line 80 without touching backend code. |
| **`INV-04`** | Hybrid PBR & Emissive Channels | $\text{Slots}(s) \supset \{\text{Steel}, \text{Rubber}, \text{Chrome}, \text{Gold}, \text{Neon}\}$ | Allows Roblox Studio to render physical bloom on neon signs/energy rings and mirror reflections on chrome/gold. |
| **`INV-05`** | Modular Isolation Pipeline | $\text{MasterScene} \to 7 \times \text{FBX} \in \text{blender/exports/}$ | A single `.blend` scene maintains consistent relative scale and palette, while separate FBX exports allow flexible level design in Studio. |

---

## 3. Station Specification Matrix (7 Tiers)

```mermaid
graph TD
    subgraph Public Tier (Free / Rebirth-Gated)
        T1["Table1: Dumbbell Rack<br/>(50x Gain | Rebirth 0 | 12x12 studs)"]
        T2["Table2: Calisthenics Pull-up Bar<br/>(100x Gain | Rebirth 5 | 12x12 studs)"]
        T3["Table3: Olympic Bench Press<br/>(150x Gain | Rebirth 10 | 12x12 studs)"]
        T4["Table4: Squat Power Rack<br/>(200x Gain | Rebirth 15 | 14x14 studs)"]
        T5["Table5: Monster Tire Deadlift<br/>(250x Gain | Rebirth 20 | 14x14 studs)"]
    end
    
    subgraph VIP Tier (Gamepass Gated)
        V1["VipTable1: Royal Gold Barbell & Trophy<br/>(300x Gain | VIP Pass | 16x16 studs)"]
        V2["VipTable2: Cyber Neon Station & Belt<br/>(400x Gain | VIP Pass | 16x16 studs)"]
    end
```

### Detailed Breakdown

| Tier | Config Name | Multiplier | Gating | Footprint | Primary Equipment & Visual Accents |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Tier 1** | `Table1` | **50x** | Rebirth 0 | $12\times 12\text{ studs}$ ($3.36\text{m}$) | **Dual-Tier Dumbbell Rack**: Crimson red steel frame, 4 pairs of hex dumbbells (5kg, 10kg, 15kg, 20kg), black rubber mat with yellow edge, 3D "50X" sign. |
| **Tier 2** | `Table2` | **100x** | Rebirth 5 | $12\times 12\text{ studs}$ ($3.36\text{m}$) | **Calisthenics Pull-up & Dip Rig**: Cobalt blue steel uprights, multi-grip chin-up bar, dip bars, chalk bucket, blue/black mat, "100X" sign. |
| **Tier 3** | `Table3` | **150x** | Rebirth 10 | $12\times 12\text{ studs}$ ($3.36\text{m}$) | **Olympic Flat Bench Press**: Safety orange steel frame, black leather padded bench, chrome barbell with Olympic bumper plates, vertical weight tree, "150X" sign. |
| **Tier 4** | `Table4` | **200x** | Rebirth 15 | $14\times 14\text{ studs}$ ($3.92\text{m}$) | **Heavy Commercial Squat Power Rack**: Charcoal black and red steel cage, safety spotter bars, Olympic bar with colossal 45lb iron plates, drop mat with "200X" sign. |
| **Tier 5** | `Table5` | **250x** | Rebirth 20 | $14\times 14\text{ studs}$ ($3.92\text{m}$) | **Monster Tire Deadlift Platform**: Thick axle barbell fitted with massive tractor tires, diamond-plate steel & rubber platform with hazard caution stripes, bold "250X" sign. |
| **VIP 1** | `VipTable1` | **300x** | VIP Pass | $16\times 16\text{ studs}$ ($4.48\text{m}$) | **Royal Gold Barbell Station**: Mirror electroplated gold frame and bar, purple velvet padded bench, velvet stanchion ropes on golden posts, and a **Golden Championship Trophy on a velvet pedestal**, crown "VIP 300X" sign. |
| **VIP 2** | `VipTable2` | **400x** | VIP Pass | $16\times 16\text{ studs}$ ($4.48\text{m}$) | **Cyber Neon Power Station**: Matte obsidian carbon-fiber frame, glowing cyan/magenta emissive energy weight rings, holographic grid floor pad, and a **Glowing Holographic Championship Belt Showcase Pillar**, cyber "VIP 400X" sign. |

---

## 4. 3D Modeling & Polygon Budget

- **Style**: Stylized Low-Poly Simulator (smooth normals with chamfered hard edges).
- **Tris Budget**: $1,500 - 3,500\text{ tris}$ per station (total master scene $\approx 15,000\text{ tris}$, well below Roblox's $21,000$ single mesh limit).
- **Coordinate Conventions**:
  - Forward: `-Y Forward`
  - Up: `Z Up`
  - Origin: Center base of the Rubber Floor Mat at $Z = 0.0$.
  - Transform Freeze: All rotations and scales applied (`Ctrl+A -> All Transforms`).

---

## 5. Material & Shading Architecture

| Material Name | Base Color (RGB) | Metallic | Roughness | Emission Color / Strength | Primary Usage |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `Mat_GymRubber_Dark` | `(0.10, 0.11, 0.13)` | 0.0 | 0.85 | Off | Main floor mats & footpads |
| `Mat_GymRubber_Accent` | `(0.95, 0.80, 0.10)` | 0.0 | 0.80 | Off | Mat hazard stripes & borders |
| `Mat_Steel_Crimson` | `(0.85, 0.12, 0.14)` | 0.4 | 0.35 | Off | Tier 1 & 4 frame uprights |
| `Mat_Steel_Cobalt` | `(0.12, 0.45, 0.88)` | 0.4 | 0.35 | Off | Tier 2 pull-up rig frame |
| `Mat_Steel_Orange` | `(0.95, 0.45, 0.05)` | 0.4 | 0.35 | Off | Tier 3 bench press frame |
| `Mat_Steel_Charcoal` | `(0.18, 0.20, 0.22)` | 0.5 | 0.40 | Off | Tier 4 cage & Tier 5 plates |
| `Mat_Chrome_Polished` | `(0.85, 0.87, 0.90)` | 0.9 | 0.15 | Off | Olympic barbells & dumbbell handles |
| `Mat_Gold_Luxury` | `(0.95, 0.78, 0.15)` | 0.9 | 0.20 | Subtle `(0.95, 0.78, 0.15, 0.5)` | VIP 1 frame, plates, and Trophy |
| `Mat_Velvet_Royal` | `(0.35, 0.05, 0.45)` | 0.0 | 0.90 | Off | VIP 1 bench padding & stanchions |
| `Mat_Cyber_Obsidian` | `(0.06, 0.07, 0.09)` | 0.7 | 0.30 | Off | VIP 2 carbon chassis |
| `Mat_Cyber_NeonCyan` | `(0.00, 0.95, 0.90)` | 0.0 | 0.10 | Cyan `(0.00, 0.95, 0.90, 4.0)` | VIP 2 energy rings & belt display |
| `Mat_Cyber_NeonMagenta`| `(0.95, 0.05, 0.65)` | 0.0 | 0.10 | Magenta `(0.95, 0.05, 0.65, 4.0)` | VIP 2 accent pylons & holographic belt |

---

## 6. File & Directory Layout

```text
f:/BIGGER/
├── blender/
│   ├── scripts/
│   │   └── generate_afk_gym_stations.py    # Autonomous procedural generation & export script
│   ├── props/
│   │   ├── AFK_Gym_Stations.blend          # Master Blender scene (all 7 stations)
│   │   └── AFK_Gym_Stations_preview.png    # Rendered studio lighting showcase
│   └── exports/
│       ├── Table1_DumbbellRack.fbx          # Tier 1 FBX
│       ├── Table2_PullUpBar.fbx             # Tier 2 FBX
│       ├── Table3_BenchPress.fbx            # Tier 3 FBX
│       ├── Table4_SquatRack.fbx             # Tier 4 FBX
│       ├── Table5_TireDeadlift.fbx          # Tier 5 FBX
│       ├── VipTable1_RoyalGold.fbx          # VIP 1 FBX (with Golden Trophy)
│       └── VipTable2_CyberNeon.fbx          # VIP 2 FBX (with Holographic Belt)
```

---

## 7. Roblox Studio Integration Contract

1. **Folder Placement**: In Roblox Studio, all 7 station models are placed inside `Workspace.CheeseDiningTables` (or `Workspace.AFKZones`).
2. **Hitbox Identification**: The ground mat of each station is a `BasePart` named `Table1`, `Table2`, `Table3`, `Table4`, `Table5`, `VipTable1`, `VipTable2`.
3. **Zero Backend Changes**: `src/server/Game/Systems/AFKZoneSystem.luau` immediately finds each part via `AFKZoneFolder:FindFirstChild(CandidateName)` and calculates player entry with `IsInsideZone(RootPart, ZonePart)`. All 603 lines of tests in `tests/unit/mvp006_afk_zones.luau` continue to pass with 0 modifications.

---

## 8. Verification Plan

1. **Procedural Execution**: Run `generate_afk_gym_stations.py` headlessly using Blender (`D:\Blendere\blender.exe -b -P blender/scripts/generate_afk_gym_stations.py`).
2. **Export Integrity Check**: Verify existence and file size of `.blend` and all 7 `.fbx` files in `blender/exports/`.
3. **Render Check**: Verify `AFK_Gym_Stations_preview.png` displays clean lighting, correct materials, and distinct station silhouettes.
4. **Regression Safety**: Execute Lune unit test suite `mvp006_afk_zones.luau` to confirm 100% test compatibility.
