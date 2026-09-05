# Blender Asset Pipeline - Project Bigger

Thư mục lưu trữ source 3D models (.blend) và quy chuẩn xuất file (.fbx) cho **Project Bigger**.

---

## 📁 Cấu trúc thư mục (Folder Structure)

```text
blender/
├── characters/     # Model nhân vật, avatar rigs, mannequin tham chiếu tỷ lệ (Scale Reference)
├── objectives/     # Các mục tiêu phá hủy (Destroyable Objects) cho từng World (Spider, Bosses, v.v.)
├── environment/    # Địa hình, đảo (Islands), World Zones, Cổng dịch chuyển (Portals)
├── props/          # Đạo cụ Lobby, bục phần thưởng (Daily Chest, Spin Wheel), VIP Door
├── upgrades/       # Phụ kiện, vật phẩm tăng trưởng (Growth Upgrades: Dumbbells, Weights, Coils)
├── textures/       # Source texture maps (PNG, TGA, UV layouts, Color Palettes)
└── exports/        # File đã export (.fbx, .obj) sẵn sàng import vào Roblox Studio
```

---

## 📐 Quy chuẩn tỷ lệ & Đơn vị (Scale & Units)

Để model khớp chuẩn xác với Roblox engine và nhân vật R15:

* **Tỷ lệ quy đổi chuẩn**:
  * $1 \text{ Roblox Stud} \approx 0.28 \text{ mét}$ ($28\text{ cm}$).
  * Chiều cao nhân vật Roblox R15 mặc định $\approx 5 \text{ studs} \approx 1.4\text{ mét}$ (Rộng $\approx 2 \text{ studs}$, Sâu $\approx 1 \text{ stud}$).
* **Cài đặt Scene trong Blender**:
  * **Unit System**: `Metric`
  * **Unit Scale**: `1.0` (hoặc `0.01` nếu làm việc theo cm)
  * **Length**: `Meters`

---

## 🎯 Điểm gốc & Trục tọa độ (Pivot & Orientation)

* **Trục tọa độ khi Export FBX**:
  * **Forward**: `-Y Forward`
  * **Up**: `Z Up`
* **Điểm gốc (Origin / Pivot)**:
  * **Vật thể đặt trên sàn (Objectives, Props, Portals)**: Đặt Origin ở **đáy tâm** ($Z = 0$) để khi đưa vào Roblox Studio có thể snap thẳng lên mặt sàn mà không bị lún hoặc lơ lửng.
  * **Vật phẩm gắn vào người (Upgrades / Accessories)**: Đặt Origin tại **điểm gắn (Attachment Point)**.
* **Freeze Transforms (BẮT BUỘC TRƯỚC KHI EXPORT)**:
  * Trong Blender, chọn Object $\rightarrow$ Nhấn `Ctrl + A` $\rightarrow$ Chọn **`All Transforms`** (Location = 0, Rotation = 0, Scale = 1.0).

---

## ⚡ Giới hạn Poly & Tối ưu hóa (Roblox Constraints)

* **Giới hạn MeshPart của Roblox**:
  * Tối đa **21,000 tris** / MeshPart (importer mới có thể hỗ trợ đến 40,000 tris).
* **Ngân sách đa giác khuyến nghị cho Bigger (Stylized / Simulator Style)**:
  * **Props / Upgrades nhỏ**: $200 - 1,500 \text{ tris}$
  * **Environment / Kiến trúc / Portals**: $1,000 - 5,000 \text{ tris}$
  * **Objective Models (Boss / Destroyable Object như Spider)**: $2,000 - 8,000 \text{ tris}$
* **Normals & Mặt phẳng**:
  * Kiểm tra **Face Orientation** (Viewport Overlays): Toàn bộ mặt ngoài phải hiển thị màu **Xanh (Blue)**, không bị lật mặt đỏ (Red).
  * Sửa lỗi lật mặt: `Edit Mode` $\rightarrow$ Chọn tất cả (`A`) $\rightarrow$ `Shift + N` (Recalculate Outside).

---

## 🏷️ Quy tắc đặt tên (Naming Convention)

Tuân thủ quy chuẩn theo `docs/NAMING.md`:

1. **PascalCase**: Đặt tên file `.blend` và `.fbx` theo dạng PascalCase.
2. **Khớp với Configuration**:
   * World 1 Objective: `Spider.fbx` (Khớp với `ModelName = "Spider"` trong `World1Config.luau`).
   * Portals: `Portal_World1.fbx`, `FreeRewardPortal.fbx`, `PaidRewardPortal.fbx`.
   * Growth Upgrades: Khớp với ID trong `UpgradeConfig.luau` (VD: `Dumbbell_Tier1.fbx`).
3. **Collision Mesh (Nếu dùng collision tùy chỉnh)**:
   * Thêm hậu tố `_Collider` vào mesh va chạm (VD: `Spider_Collider`).

---

## 📤 Hướng dẫn Export sang FBX

1. Chọn các object cần xuất trong Blender (`Selected Objects`).
2. Vào `File` $\rightarrow$ `Export` $\rightarrow$ `FBX (.fbx)`.
3. Trong bảng cấu hình export:
   * **Include**: Tick chọn `Limit to: Selected Objects`.
   * **Object Types**: Chọn `Mesh` (hoặc `Armature` nếu có rig).
   * **Transform**:
     * Scale: `1.0`
     * Forward: `-Y Forward`
     * Up: `Z Up`
     * Tick chọn `Apply Unit` và `Apply Transform`.
   * **Geometry**:
     * Smoothing: `Face` hoặc `Normals Only`.
     * Tick chọn `Apply Modifiers`.
4. Lưu file xuất vào thư mục `blender/exports/`.
5. Mở Roblox Studio $\rightarrow$ `Asset Manager` $\rightarrow$ `Bulk Import` để đưa model vào game.
