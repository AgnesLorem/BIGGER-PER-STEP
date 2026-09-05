# Roblox UI Improvements Design Spec (2026-07-18)

Design specifications for upgrading the MainHUD progress bar, adding classic stud textures to buttons and progress bar elements, implementing hover/click scale animations, and ensuring developer products (Size, Multiplier, VIP) are clickable and functioning.

## Proposed Changes

### Roblox Studio UI Instances
Modify the `MainHUD` hierarchy in Roblox Studio:

1. **ProgressBarFrame.ProgressBG**:
   - Revert image to `"rbxassetid://88087258272440"` (rounded bar background).
   - Set `ImageColor3 = Color3.fromRGB(200, 200, 200)` (light gray background).
   - Move `LevelLabel` above the top-left corner:
     - `Position = UDim2.new(0, 0, 0, -12)`
     - `AnchorPoint = Vector2.new(0, 1)`
     - `TextXAlignment = Enum.TextXAlignment.Left`
     - `TextColor3 = Color3.fromRGB(150, 255, 0)` (lime green)
     - Remove `UIGradient` to maintain solid color.
   - Move `ProgressTextLabel` above the top-right corner:
     - `Position = UDim2.new(1, 0, 0, -12)`
     - `AnchorPoint = Vector2.new(1, 1)`
     - `TextXAlignment = Enum.TextXAlignment.Right`
     - `TextColor3 = Color3.fromRGB(150, 255, 0)` (lime green)
     - Remove `UIGradient` to maintain solid color.
   - Add a new `TextLabel` named `ProgressStatsLabel` centered inside `ProgressBG`:
     - `Position = UDim2.new(0.5, 0, 0.5, 0)`
     - `AnchorPoint = Vector2.new(0.5, 0.5)`
     - `Size = UDim2.new(1, 0, 0.8, 0)`
     - `BackgroundTransparency = 1`
     - `TextColor3 = Color3.fromRGB(255, 255, 255)` (white)
     - `Font = Enum.Font.FredokaOne`
     - Add `UIStroke` (thickness `3`, black) and `UITextSizeConstraint`.
   - Add child `ImageLabel` named `StudsPattern` inside `ProgressBG` and `ProgressFill`:
     - `Image = "rbxassetid://18878366001"` (Classic studs texture)
     - `ScaleType = Enum.ScaleType.Tile`
     - `TileSize = UDim2.new(0, 24, 0, 24)`
     - `ImageTransparency = 0.85`
     - `BackgroundTransparency = 1`
     - `ZIndex` configured to layer directly above the background and below the text label.
     - Add a cloned `UICorner` matching the parent object.

2. **Buttons Stud Texture Overlay**:
   - Add the same `StudsPattern` overlay to all bottom buttons (`Bigger150K`, `Bigger1M`, `Bigger10M`) and right sidebar buttons (`DoubleMultiplier`, `Vip`).
   - For bottom buttons, keep `Image = "rbxassetid://122745440429816"` (rounded button frame) and let the `StudsPattern` layer on top.

### client/controllers/GuiController.luau
Update `GuiController.luau` to:
- Bind progress bar and text updates to real data from attributes (`Bigger`, `Level`, `Multiplier`).
- Update `ProgressStatsLabel` to show `[Current Size] / [Next Level Size]` (e.g. `999K / 1.50M`).
- Wire all developer product buttons to prompt their respective Product ID purchase.
- Hook up hover/click animations to all buttons using `UIScale`.

## Verification Plan

### Manual Verification
- Run play test in Roblox Studio.
- Verify that `Bigger`, `Multiplier` labels and the progress bar stats display actual player stats and update when size increases.
- Hover over and click all buttons to verify scale animations.
- Click the dev product buttons to verify that the Purchase Prompt pops up correctly.
