# World Progression & Multi-Map System - Bigger

This document outlines the architecture, world categories, and portal progression specifications for Project Bigger.

---

## 1. World Categories (Themes)

World zones are grouped into 3 distinct atmospheric and thematic categories:

| Category ID | Category Name | Description | Maps Included |
| :--- | :--- | :--- | :--- |
| `Forest` | **Khu Rừng (Forest)** | Khu rừng nguyên sinh rậm rạp với các sinh vật tự nhiên khổng lồ. | MAP1, MAP2, MAP3 |
| `Residential` | **Khu Dân Cư (Residential)** | Khu đô thị ngoại ô với các công trình nhà ở và chướng ngại vật cơ khí. | MAP4, MAP5, MAP6 |
| `Metropolis` | **Siêu Đô Thị (Metropolis)** | Đại đô thị tương lai với các tòa nhà chọc trời và robot khổng lồ. | MAP7, MAP8, MAP9, MAP10 |

---

## 2. Maps 1-10 Specifications

The configuration is authoritatively defined in [`MapsConfig.luau`](file:///f:/BIGGER/src/server/Game/Config/MapsConfig.luau).

| Map ID | Category | Map Name | Req. Level | Req. Size | Objective Target | Free Reward | Paid 3x Reward | Status |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `MAP1` | Forest | Nhện Rừng (Forest Spider) | Lv 5 | 50 | Stomp Spider (`Spider`) | +1 Destruction | 3 Destruction (29 R$) | **Active** |
| `MAP2` | Forest | Heo Rừng Gai (Wild Boar) | Lv 15 | 500 | Stomp Wild Boar (`WildBoar`) | +5 Destruction | 15 Destruction (29 R$) | **Active** |
| `MAP3` | Forest | Gấu Chúa Cổ Đại (Ancient Bear) | Lv 35 | 5,000 | Stomp Ancient Bear (`AncientBear`) | +20 Destruction | 60 Destruction (29 R$) | **Active** |
| `MAP4` | Residential | Xe Tải Hỏng (Crashed Truck) | Lv 60 | 25,000 | Crush Truck (`CrashedTruck`) | +50 Destruction | 150 Destruction (29 R$) | *Coming Soon* |
| `MAP5` | Residential | Biệt Thự Bỏ Hoang (Abandoned Villa) | Lv 100 | 100,000 | Demolish Villa (`AbandonedVilla`) | +120 Destruction | 360 Destruction (29 R$) | *Coming Soon* |
| `MAP6` | Residential | Cần Cẩu Công Trình (Construction Crane) | Lv 150 | 500,000 | Topple Crane (`ConstructionCrane`) | +300 Destruction | 900 Destruction (29 R$) | *Coming Soon* |
| `MAP7` | Metropolis | Trạm Điện Giao Lộ (Power Substation) | Lv 220 | 2,500,000 | Overload Substation (`PowerSubstation`) | +800 Destruction | 2,400 Destruction (29 R$) | *Coming Soon* |
| `MAP8` | Metropolis | Tháp Ngân Hàng (Bank Tower) | Lv 300 | 10,000,000 | Flatten Tower (`BankTower`) | +2,000 Destruction | 6,000 Destruction (29 R$) | *Coming Soon* |
| `MAP9` | Metropolis | Chiến Hạm Bay (Hover Cruiser) | Lv 400 | 50,000,000 | Smash Cruiser (`HoverCruiser`) | +5,000 Destruction | 15,000 Destruction (29 R$) | *Coming Soon* |
| `MAP10` | Metropolis | Robot Titan (Titan Mecha) | Lv 500 | 250,000,000 | Destroy Titan (`TitanMecha`) | +15,000 Destruction | 45,000 Destruction (29 R$) | *Coming Soon* |

---

## 3. Teleporter Arch & Gating Architecture

### Central Lobby Teleporter
- The central Teleporter in the Lobby features an ancient stone & gold runic arch with an animated vortex.
- Touching the `TeleporterTouchZone` or activating its `ProximityPrompt` invokes the 3-tab **Map Selector UI** (`MapSelectorController`).
- Players can browse zones by theme (`Forest`, `Residential`, `Metropolis`) and select their unlocked stage.

### Authoritative Server Gating
- Gating checks are strictly validated on the server in `PortalService:SelectMap`:
  1. `Session.State == "InLobby"` and profile mutations not frozen.
  2. `PlayerLevel >= MapDef.RequiredLevel`.
  3. `MapDef.IsComingSoon == false`.
- Any unearned access attempt fails closed and drops the player back into the Lobby with debounces restored.

---

## 4. Isolated World Instances & Dynamic Stomp

### Instance Isolation
- Each player enters their own cloned world space under `Workspace/RuntimeWorlds/<MapId>_<UserId>_<Index>`.
- Clones are staggered along `MapsConfig.RuntimeOffset` (`(0, 0, 450)`) to isolate collisions and visuals.
- Dedicated `ReturnSpawn` and `EntrySpawn` markers guarantee leak-free teleports.

### Scale-Aware Stomp Mechanics
- Destroying an objective requires a downward velocity stomp onto its `ObjectiveHitbox`.
- Because player avatar size scales exponentially (up to 10x visual scale), `DestructionService` dynamically scales the horizontal padding and maximum root height:
  ```luau
  local ScaledMaxHeight = BaseMaxHeight * VisualScale
  local ScaledHorizontalPadding = BaseHorizontalPadding * VisualScale
  ```
- This prevents giant characters from clipping or failing stomp registration due to high bounding box centers.

---

## 5. Dual Reward Gate & Settle Invariants

Upon defeating the objective:
1. `DestructionService` explodes the target into physical debris fragments via `DebrisService`.
2. `RewardPortalService` activates two exit portals (`FreeRewardPortal` and `PaidRewardPortal`) and fires `ShowRewardPopup` to client GUI.
3. Choosing **Free** awards standard Destruction (`+1`, `+5`, `+20`), transitions session to `Returning`, teleports back to `ReturnSpawn`, and settles runtime.
4. Choosing **Paid 3x** opens Roblox Developer Product purchase prompt (29 R$). Upon receipt commit, awards 3x Destruction (`+3`, `+15`, `+60`) and safely returns the player to the Lobby.
