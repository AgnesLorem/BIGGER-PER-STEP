# Rebirth UI Figma Realignment Design Specification

**Goal:** Realign the Roblox Studio `RebirthPanel` GUI elements to match the exact relative proportions, margins, and layout defined in the Figma file (`CJodtanVk9mYCZY3eXtMcb`).

## Layout Specifications

The Figma design defines a 906x671 main window with margins and relative positions. We convert these to scale/offset properties relative to the parent `RebirthPanel` frame.

### 1. Panel Aspect Ratio
- **Aspect Ratio**: 1.3502 (already preserved via `UIAspectRatioConstraint`).

### 2. Header & Close Button Row
- **Header**:
  - Position: `UDim2.new(0.004, 0, 0.006, 0)` (relative margins of 4px)
  - Size: `UDim2.new(0.886, 0, 0.161, 0)`
- **CloseButton**:
  - Position: `UDim2.new(0.895, 0, 0.006, 0)`
  - Size: `UDim2.new(0.100, 0, 0.161, 0)`

### 3. Progress Bar Container
- **MultiplierBar**:
  - AnchorPoint: `Vector2.new(0.5, 0)`
  - Position: `UDim2.new(0.5, 0, 0.252, 0)` (centered horizontally, 169px from top)
  - Size: `UDim2.new(0.901, 0, 0.185, 0)`

### 4. Strength Status Cards Row
- **CurrentLabel**:
  - Position: `UDim2.new(0.141, 0, 0.477, 0)` (aligned with card)
  - Size: `UDim2.new(0.264, 0, 0.086, 0)`
- **NextLabel**:
  - Position: `UDim2.new(0.618, 0, 0.477, 0)` (aligned with card)
  - Size: `UDim2.new(0.264, 0, 0.086, 0)`
- **CurrentCard**:
  - Position: `UDim2.new(0.141, 0, 0.571, 0)`
  - Size: `UDim2.new(0.264, 0, 0.110, 0)`
- **NextCard**:
  - Position: `UDim2.new(0.618, 0, 0.571, 0)`
  - Size: `UDim2.new(0.264, 0, 0.110, 0)`
- **Arrows** (vertical alignment between cards):
  - AnchorPoint: `Vector2.new(0.5, 0.5)`
  - Position: `UDim2.new(0.5, 0, 0.626, 0)`
  - Size: `UDim2.new(0.062, 0, 0.083, 0)`

### 5. Action Buttons Row
- **Buttons** (container frame):
  - AnchorPoint: `Vector2.new(0.5, 0)`
  - Position: `UDim2.new(0.5, 0, 0.815, 0)`
  - Size: `UDim2.new(0.700, 0, 0.151, 0)`
- **RebirthButton** (child of Buttons):
  - Position: `UDim2.new(0, 0, 0.035, 0)`
  - Size: `UDim2.new(0.328, 0, 0.931, 0)`
- **SkipRebirthButton** (child of Buttons):
  - Position: `UDim2.new(0.672, 0, 0.035, 0)`
  - Size: `UDim2.new(0.328, 0, 0.931, 0)`

## Implementation Strategy

We will execute an automated Luau script inside Roblox Studio Edit Mode to adjust all properties programmatically. This ensures 100% precision and avoids manual errors.
