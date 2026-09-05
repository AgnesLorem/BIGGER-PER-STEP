# Rebirth UI Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Restyle the Rebirth Panel UI in Roblox Studio using Asset Manager assets, and update the RebirthController to animate to a correct wide aspect ratio and render dynamic player size and rebirth data.

**Architecture:**
- Adjust target size in the client-side `RebirthController.luau` script.
- Restyle the Roblox Studio UI instances via command bar scripts to configure background textures, headers, stats boxes, progress bars, play icons, and action buttons.
- Ensure all text labels remain fully data-driven.

**Tech Stack:** Luau, Roblox Studio, Client/Server replication architecture.

## Global Constraints
- Do not roll back speculative RAM changes on save failure.
- All R15 avatar physical scaling must be set on the server.
- All reward operations follow strict validators/appliers separation.
- Event publishing via EventBus.Publish must run asynchronously.
- UI development follows Constraint-Driven Responsive Architecture.

---

### Task 1: Update Controller Sizing
Modify [RebirthController.luau](file:///f:/BIGGER/src/client/controllers/RebirthController.luau) to animate `RebirthPanel` to the correct aspect ratio.

**Files:**
- Modify: [src/client/controllers/RebirthController.luau](file:///f:/BIGGER/src/client/controllers/RebirthController.luau#L160-L190)

**Interfaces:**
- Consumes: None.
- Produces: Adjusted layout tween size.

- [ ] **Step 1: Update the tween target size**
  Change the open tween target size in [RebirthController.luau](file:///f:/BIGGER/src/client/controllers/RebirthController.luau#L165-L168) from `{0.4, 0.7}` to `{0.55, 0.55}`.

  ```luau
  -- Target lines 165-168:
  TweenService:Create(Panel, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
      Size = UDim2.fromScale(0.55, 0.55),
  }):Play()
  ```

- [ ] **Step 2: Commit client changes**
  Run git commands to stage and commit the change:
  ```bash
  git add src/client/controllers/RebirthController.luau
  git commit -m "feat(rebirth): update controller tween target size for wide aspect ratio"
  ```

---

### Task 2: Configure Backdrop and Header Bar
Execute a command bar script to configure the background image and the magenta header bar spanning the full panel width.

**Files:**
- Modify: Roblox Studio Datamodel (`StarterGui.MainHUD.SafeAreaRoot.OverlayHUD.RebirthPanel`)

**Interfaces:**
- Consumes: Wide aspect ratio sizing.
- Produces: Correctly sized header and backdrop image.

- [ ] **Step 1: Run the backdrop and header styling script in Roblox Studio (Edit Mode)**
  Execute this Luau script in the `Edit` datamodel:
  ```luau
  local panel = game:GetService("StarterGui").MainHUD.SafeAreaRoot.OverlayHUD.RebirthPanel
  panel.Size = UDim2.new(0.55, 0, 0.55, 0)
  panel.BackgroundTransparency = 1

  -- BGImage setup
  local bgImage = panel:FindFirstChild("BGImage")
  if not bgImage then
      bgImage = Instance.new("ImageLabel")
      bgImage.Name = "BGImage"
      bgImage.Parent = panel
  end
  bgImage.Image = "rbxgameasset://Background"
  bgImage.Size = UDim2.new(1, 0, 1, 0)
  bgImage.Position = UDim2.new(0, 0, 0, 0)
  bgImage.BackgroundTransparency = 1
  bgImage.ZIndex = 1

  -- Configure ZIndex order
  for _, child in ipairs(panel:GetChildren()) do
      if child ~= bgImage and child:IsA("GuiObject") then
          child.ZIndex = 2
          for _, gc in ipairs(child:GetDescendants()) do
              if gc:IsA("GuiObject") then
                  gc.ZIndex = child.ZIndex + 1
              end
          end
      end
  end

  -- Header styling
  local header = panel:FindFirstChild("Header")
  header.Position = UDim2.new(0.5, 0, 0, 0)
  header.Size = UDim2.new(1, 0, 0.14, 0)
  header.AnchorPoint = Vector2.new(0.5, 0)
  header.ZIndex = 2

  header.HeaderBG.Image = "rbxgameasset://Images/Header"
  header.HeaderBG.Size = UDim2.new(1, 0, 1, 0)
  header.HeaderBG.ZIndex = 2

  header.TitleText.Visible = false
  header.RebirthIcon.Visible = false

  local closeButton = header:FindFirstChild("CloseButton")
  closeButton.Position = UDim2.new(1, -8, 0.5, 0)
  closeButton.AnchorPoint = Vector2.new(1, 0.5)
  closeButton.Size = UDim2.new(0.8, 0, 0.8, 0)
  closeButton.ZIndex = 3
  closeButton.Icon.Image = "rbxgameasset://Images/Close"
  closeButton.Icon.ZIndex = 3
  ```

---

### Task 3: Configure Stats Boxes, Progress Bar, and Play Icon
Execute a command bar script to style the blue size boxes, configure the blue studs progress bar, and replace the play icon.

**Files:**
- Modify: Roblox Studio Datamodel (`StarterGui.MainHUD.SafeAreaRoot.OverlayHUD.RebirthPanel`)

**Interfaces:**
- Consumes: Header and backdrop configurations.
- Produces: Correctly styled stats panels, play button, and progress bar.

- [ ] **Step 1: Run the stats and progress styling script in Roblox Studio (Edit Mode)**
  Execute this Luau script in the `Edit` datamodel:
  ```luau
  local panel = game:GetService("StarterGui").MainHUD.SafeAreaRoot.OverlayHUD.RebirthPanel

  -- Current Size Box
  local currentSizeLabel = panel:FindFirstChild("CurrentSizeLabel")
  currentSizeLabel.Position = UDim2.new(0.08, 0, 0.52, 0)
  currentSizeLabel.Size = UDim2.new(0.34, 0, 0.15, 0)
  currentSizeLabel.ZIndex = 3
  currentSizeLabel.TextSize = 14
  currentSizeLabel.Font = Enum.Font.FredokaOne
  currentSizeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
  currentSizeLabel.TextXAlignment = Enum.TextXAlignment.Right
  currentSizeLabel.BGImage.Image = "rbxgameasset://Images/Multiplier"
  currentSizeLabel.BGImage.ZIndex = 2

  local padding = currentSizeLabel:FindFirstChild("UIPadding")
  if not padding then
      padding = Instance.new("UIPadding")
      padding.Parent = currentSizeLabel
  end
  padding.PaddingRight = UDim.new(0, 12)

  -- Required Size Box
  local requiredSizeLabel = panel:FindFirstChild("RequiredSizeLabel")
  requiredSizeLabel.Position = UDim2.new(0.58, 0, 0.52, 0)
  requiredSizeLabel.Size = UDim2.new(0.34, 0, 0.15, 0)
  requiredSizeLabel.ZIndex = 3
  requiredSizeLabel.TextSize = 14
  requiredSizeLabel.Font = Enum.Font.FredokaOne
  requiredSizeLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
  requiredSizeLabel.TextXAlignment = Enum.TextXAlignment.Right
  requiredSizeLabel.BGImage.Image = "rbxgameasset://Images/Multiplier"
  requiredSizeLabel.BGImage.ZIndex = 2

  local reqPadding = requiredSizeLabel:FindFirstChild("UIPadding")
  if not reqPadding then
      reqPadding = Instance.new("UIPadding")
      reqPadding.Parent = requiredSizeLabel
  end
  reqPadding.PaddingRight = UDim.new(0, 12)

  -- Arrows (Play icon frame)
  local arrows = panel:FindFirstChild("Arrows")
  arrows.Position = UDim2.new(0.5, 0, 0.52, 0)
  arrows.Size = UDim2.new(0.08, 0, 0.15, 0)
  arrows.AnchorPoint = Vector2.new(0.5, 0)
  arrows.ZIndex = 3
  arrows.LeftArrow.Visible = false
  arrows.RightArrow.Visible = false
  arrows.ArrImg.Image = "rbxgameasset://Images/Arrows"
  arrows.ArrImg.ZIndex = 3

  -- Progress Bar
  local multiplierBar = panel:FindFirstChild("MultiplierBar")
  multiplierBar.Position = UDim2.new(0.5, 0, 0.28, 0)
  multiplierBar.Size = UDim2.new(0.84, 0, 0.12, 0)
  multiplierBar.AnchorPoint = Vector2.new(0.5, 0)
  multiplierBar.ZIndex = 3

  local barBG = multiplierBar:FindFirstChild("BarBG")
  barBG.ZIndex = 3
  barBG.BGImage.Image = "rbxgameasset://Images/Multiplier"
  barBG.BGImage.ImageColor3 = Color3.fromRGB(0, 100, 200)
  barBG.BGImage.ZIndex = 3

  local barFill = barBG:FindFirstChild("BarFill")
  barFill.ZIndex = 4
  barFill.FillImage.Image = "rbxgameasset://Images/Multiplier"
  barFill.FillImage.ImageColor3 = Color3.fromRGB(0, 180, 255)
  barFill.FillImage.ZIndex = 4
  ```

---

### Task 4: Configure Buttons and Clean Up Labels
Execute a command bar script to style the green Rebirth and purple Skip buttons, and hide unnecessary labels.

**Files:**
- Modify: Roblox Studio Datamodel (`StarterGui.MainHUD.SafeAreaRoot.OverlayHUD.RebirthPanel`)

**Interfaces:**
- Consumes: Custom middle panels.
- Produces: Correct bottom action buttons layout, and hidden preview labels.

- [ ] **Step 1: Run the buttons and cleanup script in Roblox Studio (Edit Mode)**
  Execute this Luau script in the `Edit` datamodel:
  ```luau
  local panel = game:GetService("StarterGui").MainHUD.SafeAreaRoot.OverlayHUD.RebirthPanel

  -- Bottom Buttons
  local rebirthButton = panel:FindFirstChild("RebirthButton")
  rebirthButton.Position = UDim2.new(0.08, 0, 0.76, 0)
  rebirthButton.Size = UDim2.new(0.40, 0, 0.16, 0)
  rebirthButton.ZIndex = 3
  rebirthButton.BtnImg.Image = "rbxgameasset://Images/Rebirth"
  rebirthButton.BtnImg.ZIndex = 3

  local skipRebirthButton = panel:FindFirstChild("SkipRebirthButton")
  skipRebirthButton.Position = UDim2.new(0.52, 0, 0.76, 0)
  skipRebirthButton.Size = UDim2.new(0.40, 0, 0.16, 0)
  skipRebirthButton.ZIndex = 3
  skipRebirthButton.BtnImg.Image = "rbxgameasset://Images/SkipRebirth"
  skipRebirthButton.BtnImg.ZIndex = 3
  skipRebirthButton.RobuxIcon.Image = "rbxgameasset://Images/Robux"
  skipRebirthButton.RobuxIcon.ZIndex = 4

  -- Hidden Labels
  panel.RebirthCountLabel.Visible = false
  panel.MultiplierPreviewLabel.Visible = false
  ```

---

### Task 5: Verify Sizing and Symmetrical HUD Layout
Verify visual appearance and dynamic data rendering in Roblox Studio.

- [ ] **Step 1: Set panel visible in Edit Mode to inspect**
  Run code to show the panel:
  ```luau
  local hud = game:GetService("StarterGui").MainHUD.SafeAreaRoot
  hud.PersistentHUD.Visible = false
  hud.OverlayHUD.Visible = true
  hud.OverlayHUD.RebirthPanel.Visible = true
  ```

- [ ] **Step 2: Capture screen of the panel in Edit Mode**
  Take a screen capture to verify the final layout matches the mockup.

- [ ] **Step 3: Restore default HUD visibility and test in Play Solo**
  Run script to restore:
  ```luau
  local hud = game:GetService("StarterGui").MainHUD.SafeAreaRoot
  hud.PersistentHUD.Visible = true
  hud.OverlayHUD.Visible = true
  hud.OverlayHUD.RebirthPanel.Visible = false
  ```
  Start Play Solo in Studio and open the Rebirth Panel from the sidebar. Verify:
  - The tween animation is smooth and fits a wide aspect ratio.
  - The stats boxes show real size data (e.g. `0` or current player size).
  - The progress bar fill is correct.
