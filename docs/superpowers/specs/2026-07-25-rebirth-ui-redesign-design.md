# Rebirth UI Redesign Spec (2026-07-25)

Design specifications for restyling the Rebirth Panel to match the target mockup design. All assets are retrieved directly from the Roblox Asset Manager (`rbxgameasset://` URIs).

## Proposed Changes

### Roblox Studio UI Instances
Modify the `RebirthPanel` hierarchy in Roblox Studio:

1. **RebirthPanel**:
   - Change `Size` to `{0.55, 0}, {0.55, 0}` to match the wide rectangular aspect ratio.
   - Set `BackgroundTransparency = 1` (since the background image will handle the visual representation).
   - Add a new `ImageLabel` named `BGImage`:
     - `Image = "rbxgameasset://Background"`
     - `Size = UDim2.new(1, 0, 1, 0)`
     - `Position = UDim2.new(0, 0, 0, 0)`
     - `BackgroundTransparency = 1`
     - `ZIndex = 1` (ensure it layers behind all other UI components).

2. **Header**:
   - Change `Position` to `UDim2.new(0.5, 0, 0, 0)`.
   - Change `Size` to `UDim2.new(1, 0, 0.14, 0)`.
   - Set `AnchorPoint = Vector2.new(0.5, 0)`.
   - Set `HeaderBG.Image = "rbxgameasset://Images/Header"`.
   - Set `HeaderBG.Size = UDim2.new(1, 0, 1, 0)`.
   - Set `TitleText.Visible = false` (hide the `"REBIRTH"` text label as the background image already contains it).
   - Set `RebirthIcon.Visible = false` (hide the extra rebirth icon overlay as it's included in the header asset).
   - Set `CloseButton.Position = UDim2.new(1, -8, 0.5, 0)`.
   - Set `CloseButton.AnchorPoint = Vector2.new(1, 0.5)`.
   - Set `CloseButton.Size = UDim2.new(0.8, 0, 0.8, 0)` (keeps it square-like relative to the header height).
   - Set `CloseButton.Icon.Image = "rbxgameasset://Images/Close"`.

3. **Stats Boxes (`CurrentSizeLabel` & `RequiredSizeLabel`)**:
   - Update `BGImage.Image = "rbxgameasset://Images/Multiplier"` on both labels.
   - Adjust `TextSize = 14`.
   - Adjust `Font = Enum.Font.FredokaOne`.
   - Position `CurrentSizeLabel` at `UDim2.new(0.08, 0, 0.52, 0)` and `RequiredSizeLabel` at `UDim2.new(0.58, 0, 0.52, 0)` with size `UDim2.new(0.34, 0, 0.15, 0)`.
   - Position `Arrows` (play icon frame) at `UDim2.new(0.5, 0, 0.52, 0)` with size `UDim2.new(0.08, 0, 0.15, 0)` and `AnchorPoint = Vector2.new(0.5, 0)`.
   - Set `Arrows.ArrImg.Image = "rbxgameasset://Images/Arrows"`.
   - Make `Arrows.LeftArrow` and `Arrows.RightArrow` invisible (set `Visible = false`), as the mockup doesn't use arrow buttons around the play icon.

4. **Multiplier Progress Bar (`MultiplierBar`)**:
   - Set `BarBG.BGImage.Image = "rbxgameasset://Images/Multiplier"`.
   - Set `BarBG.BGImage.ImageColor3 = Color3.fromRGB(0, 120, 255)` (tinted dark blue).
   - Set `BarBG.BarFill.FillImage.Image = "rbxgameasset://Images/Multiplier"`.
   - Set `BarBG.BarFill.FillImage.ImageColor3 = Color3.fromRGB(0, 200, 255)` (tinted bright blue).
   - Clean up any other glossy overlays or borders.

5. **Bottom Action Buttons**:
   - **RebirthButton**:
     - Position = `UDim2.new(0.08, 0, 0.76, 0)`.
     - Size = `UDim2.new(0.40, 0, 0.16, 0)`.
     - `BtnImg.Image = "rbxgameasset://Images/Rebirth"`.
   - **SkipRebirthButton**:
     - Position = `UDim2.new(0.52, 0, 0.76, 0)`.
     - Size = `UDim2.new(0.40, 0, 0.16, 0)`.
     - `BtnImg.Image = "rbxgameasset://Images/SkipRebirth"`.
     - `RobuxIcon.Image = "rbxgameasset://Images/Robux"`.

6. **Temporary / Extraneous Labels**:
   - Set `RebirthCountLabel.Visible = false` (mockup does not display this label).
   - Set `MultiplierPreviewLabel.Visible = false` (mockup does not display this label).

### client/controllers/RebirthController.luau
Update `RebirthController.luau` to:
- Adjust the open animation target size to `UDim2.fromScale(0.55, 0.55)` (or similar offset/scale matching the spec size) to prevent UI stretching.
- Ensure `CurrentSizeLabel` and `RequiredSizeLabel` continue to receive and display the dynamic player size data.
- Ensure the progress bar fill maps to `CurrentSize / RequiredSize` accurately.

## Verification Plan

### Manual Verification
- Execute properties update script in Edit Mode.
- Capture the screen in Edit Mode to verify visual appearance matches the mockup.
- Run Play Solo mode in Roblox Studio.
- Trigger the Rebirth Panel to verify tween animations and data binding (Current Size, Required Size, progress bar fill, and button activation).
