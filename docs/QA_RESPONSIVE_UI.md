# Project Bigger - Quy Trình & Kịch Bản Kiểm Tra Responsive UI

Tài liệu này cung cấp kịch bản kiểm tra toàn diện (Automated & Manual QA Checklist) nhằm xác minh giao diện người dùng (UI) trong Roblox Studio đáp ứng chuẩn **CDRA (Constraint-Driven Responsive Architecture)** trên mọi loại màn hình và thiết bị.

---

## 1. Automated Test Suite (Kiểm Tra Tự Động)

Script test tự động được lưu tại: [`tests/studio/ui_responsive_test.luau`](file:///f:/BIGGER/tests/studio/ui_responsive_test.luau).

### Cách chạy trong Roblox Studio:
1. Mở Roblox Studio với Place `Bigger Per Step`.
2. Mở cửa sổ **Command Bar** (View -> Command Bar).
3. Thực thi lệnh sau:
   ```luau
   local TestSuite = require(game.ReplicatedStorage.BiggerShared.Core.Config.ResponsiveConfig) -- hoặc require file test
   -- Hoặc chạy trực tiếp script tests/studio/ui_responsive_test.luau qua TestRunner
   ```
4. Xem kết quả thống kê tại cửa sổ **Output**.

### Kết quả kiểm tra hiện tại:
- **Tổng ScreenGui quét**: 1 (`MainHUD`)
- **Tổng GUI Object kiểm tra**: 61 đối tượng
- **Lỗi nghiêm trọng (Critical Issues)**: 0
- **Cảnh báo (Warnings)**: 0
- **Trạng thái**: **PASS (Đạt toàn bộ tiêu chí CDRA)**

---

## 2. Kịch Bản Kiểm Tra Thủ Công Bằng Studio Device Emulator (Manual QA)

Trong Roblox Studio, bật cửa sổ **Device Emulator** (`Ctrl + Shift + I` hoặc `Test -> Device`) và lần lượt kiểm tra các Preset sau:

| # | Thiết bị giả lập | Độ phân giải | Loại (Category) | Hành vi kỳ vọng (Expected Behavior) |
|---|---|---|---|---|
| 1 | **iPhone SE (1st/2nd Gen)** | $375 \times 667$ | `PhonePortrait` | Sidebar trái/phải ẩn; BottomHUD chuyển sang chế độ Compact; Nút bấm tối thiểu 44px; Chữ hiển thị đầy đủ không bị cắt lẹm. |
| 2 | **iPhone 14 Pro / 15 Pro** | $393 \times 852$ | `PhonePortrait` | `SafeAreaRoot` tránh vùng tai thỏ / Dynamic Island và Topbar inset phía trên ($54\text{px}$) & thanh gạt Home phía dưới. |
| 3 | **iPhone 14 Pro (Ngang)** | $852 \times 393$ | `PhoneLandscape` | Sidebar trái thu gọn/icon nhỏ; Sidebar phải ẩn; BottomHUD gọn gàng; Tầm nhìn camera 3D không bị che khuất quá $30\%$. |
| 4 | **iPad Pro 11-inch** | $834 \times 1194$ | `Tablet` | Cả 2 Sidebar hiển thị ở dạng icon thu gọn vừa phải; RebirthPanel Popup nằm chính giữa màn hình với kích thước cân đối ($65\%$ scale). |
| 5 | **Desktop 1080p** | $1920 \times 1080$ | `Desktop` | Đầy đủ Sidebar trái (6 nút), Sidebar phải (VIP + $2\times$ Multiplier), BottomHUD đầy đủ kèm thanh tiến trình Level bar. |
| 6 | **Ultrawide 21:9 (1440p)** | $3440 \times 1440$ | `Ultrawide` | Sidebar mở rộng hai bên rìa màn hình, BottomHUD nằm chính giữa đáy màn hình, không bị kéo dãn biến dạng. |

---

## 3. Bảng Checklist Kiểm Tra Từng Thành Phần UI

### A. MainHUD - PersistentHUD
- [x] **SafeAreaRoot**: Bao phủ $100\%$ Scale `(1, 0, 1, 0)`, vị trí `(0, 0, 0, 0)`.
- [x] **LeftSidebar**:
  - Tự động co dãn theo `UIGridLayout` / `UIListLayout`.
  - Có hiệu ứng hover / click đàn hồi (`UIScale` 1.1x / 0.95x).
  - Điều hướng tay cầm Gamepad (`NextSelectionUp/Down/Left/Right`) hoạt động liền mạch.
- [x] **RightSidebar**:
  - Hiển thị nút VIP GamePass & Double Multiplier Developer Product.
  - Các badge Robux và TextLabel tự căn chỉnh theo AspectRatio.
- [x] **BottomHUD**:
  - Thanh tiến trình `ProgressFill` cập nhật mượt qua TweenService khi `Bigger` thay đổi.
  - `ProgressStatsLabel` hiển thị định dạng số gọn (vd: `1.5M / 10M`).
  - Nút mua nhanh (`Bigger150K`, `Bigger1M`, `Bigger10M`) kích hoạt đúng `MarketplaceService:PromptProductPurchase`.

### B. OverlayHUD - Rebirth & Modal Popups
- [x] **ModalBackdrop**: Phủ mờ toàn màn hình `(1, 0, 1, 0)` với độ trong suốt tối ưu.
- [x] **RebirthPanel**:
  - `AnchorPoint = (0.5, 0.5)` và `Position = (0.5, 0, 0.5, 0)` đảm bảo luôn nằm trung tâm ở mọi thiết bị.
  - Chứa `UIAspectRatioConstraint` chống méo tỷ lệ thẻ Rebirth.
  - Hỗ trợ đóng mở qua phím ESC / nút Close / click ra ngoài nền đen.

---

## 4. Tiêu Chuẩn Phê Duyệt Release (Sign-off Criteria)
1. Tất cả 6 thiết bị trong Device Emulator không xảy ra lỗi tràn chữ, đè nút, hoặc mất nút.
2. Script `tests/studio/ui_responsive_test.luau` in trạng thái `PASS`.
3. Không có bất kỳ cảnh báo console đỏ nào trong F9 Console.
