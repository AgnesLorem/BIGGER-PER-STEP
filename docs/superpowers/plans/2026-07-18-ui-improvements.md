# UI Improvements Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Modify the Roblox MainHUD progress bar and buttons to match the reference mockup styling, add Classic Studs textures, and wire up all developer products and animations.

**Architecture:** Use Roblox Studio MCP tools (`execute_luau` and `multi_edit`) to modify UI instances in Edit mode. Sync local `GuiController.luau` changes and ensure the game is fully functional during playtest verification.

**Tech Stack:** Luau (Roblox Studio client-side), Roblox Studio MCP.

## Global Constraints
- Naming, folder layout, and constraints must follow `Jarvis.md`.
- No placeholders (`TODO`, `TBD`, or incomplete functions).
- Commit frequently.

---

### Task 1: Update Roblox Studio GUI Hierarchy and Layout

**Files:**
- Modify: `game.StarterGui.MainHUD` (via Studio MCP)

**Interfaces:**
- Produces: Updated GUI layout including `ProgressStatsLabel` and `StudsPattern` overlays.

- [ ] **Step 1: Move progress bar text labels and set colors**
  Run Luau code in Roblox Studio to adjust `LevelLabel` and `ProgressTextLabel` position and colors above the bar.
  Run:
  ```luau
  local p = game:GetService("StarterGui").MainHUD.SafeAreaRoot.PersistentHUD.BottomHUD.ProgressBarFrame
  local bg = p.ProgressBG
  local lvl = bg.LevelLabel
  local prg = bg.ProgressTextLabel

  lvl.Position = UDim2.new(0, 0, 0, -12)
  lvl.AnchorPoint = Vector2.new(0, 1)
  lvl.Size = UDim2.new(0.45, 0, 0.8, 0)
  lvl.TextXAlignment = Enum.TextXAlignment.Left
  lvl.TextColor3 = Color3.fromRGB(150, 255, 0)
  local lvlGrad = lvl:FindFirstChildOfClass("UIGradient")
  if lvlGrad then lvlGrad:Destroy() end

  prg.Position = UDim2.new(1, 0, 0, -12)
  prg.AnchorPoint = Vector2.new(1, 1)
  prg.Size = UDim2.new(0.45, 0, 0.8, 0)
  prg.TextXAlignment = Enum.TextXAlignment.Right
  prg.TextColor3 = Color3.fromRGB(150, 255, 0)
  local prgGrad = prg:FindFirstChildOfClass("UIGradient")
  if prgGrad then prgGrad:Destroy() end
  ```

- [ ] **Step 2: Create ProgressStatsLabel TextLabel**
  Run Luau code in Roblox Studio to create the centered progress stats label.
  Run:
  ```luau
  local p = game:GetService("StarterGui").MainHUD.SafeAreaRoot.PersistentHUD.BottomHUD.ProgressBarFrame
  local bg = p.ProgressBG
  local stats = bg:FindFirstChild("ProgressStatsLabel")
  if stats then stats:Destroy() end

  stats = Instance.new("TextLabel")
  stats.Name = "ProgressStatsLabel"
  stats.Size = UDim2.new(1, 0, 0.8, 0)
  stats.Position = UDim2.new(0.5, 0, 0.5, 0)
  stats.AnchorPoint = Vector2.new(0.5, 0.5)
  stats.BackgroundTransparency = 1
  stats.TextColor3 = Color3.fromRGB(255, 255, 255)
  stats.Font = Enum.Font.FredokaOne
  stats.TextSize = 24
  stats.Text = "0 / 0"
  stats.ZIndex = 10

  local stroke = Instance.new("UIStroke")
  stroke.Color = Color3.fromRGB(0, 0, 0)
  stroke.Thickness = 3
  stroke.Parent = stats

  local constraint = Instance.new("UITextSizeConstraint")
  constraint.MaxTextSize = 24
  constraint.MinTextSize = 12
  constraint.Parent = stats

  stats.Parent = bg
  ```

- [ ] **Step 3: Create and apply StudsPattern overlays**
  Run Luau code in Roblox Studio to add tiling classic studs to all required elements.
  Run:
  ```luau
  local p = game:GetService("StarterGui").MainHUD.SafeAreaRoot.PersistentHUD.BottomHUD.ProgressBarFrame
  local bg = p.ProgressBG
  local container = bg.BarContainer
  local fill = container.ProgressFill
  local bottom = game:GetService("StarterGui").MainHUD.SafeAreaRoot.PersistentHUD.BottomHUD.ButtonsContainer
  local right = game:GetService("StarterGui").MainHUD.SafeAreaRoot.PersistentHUD.RightSidebar

  bg.Image = "rbxassetid://88087258272440"
  bg.ImageColor3 = Color3.fromRGB(200, 200, 200)

  fill.Image = "rbxassetid://88087258272440"
  fill.ImageColor3 = Color3.fromRGB(0, 170, 255)

  local function applyStuds(parent)
      local old = parent:FindFirstChild("StudsPattern")
      if old then old:Destroy() end

      local studs = Instance.new("ImageLabel")
      studs.Name = "StudsPattern"
      studs.Size = UDim2.new(1, 0, 1, 0)
      studs.BackgroundTransparency = 1
      studs.Image = "rbxassetid://18878366001"
      studs.ScaleType = Enum.ScaleType.Tile
      studs.TileSize = UDim2.new(0, 24, 0, 24)
      studs.ImageTransparency = 0.85
      studs.ZIndex = 2

      local corner = parent:FindFirstChildOfClass("UICorner")
      if corner then
          corner:Clone().Parent = studs
      end
      studs.Parent = parent

      local text = parent:FindFirstChildOfClass("TextLabel")
      if text then text.ZIndex = 3 end
      
      local robux = parent:FindFirstChild("RobuxBadge")
      if robux then robux.ZIndex = 4 end
      local robuxIcon = parent:FindFirstChild("RobuxIcon")
      if robuxIcon then robuxIcon.ZIndex = 4 end
  end

  applyStuds(bg)
  applyStuds(fill)

  for _, child in ipairs(bottom:GetChildren()) do
      if child:IsA("ImageButton") then
          child.Image = "rbxassetid://122745440429816"
          child.BackgroundTransparency = 1
          applyStuds(child)
      end
  end

  for _, child in ipairs(right:GetChildren()) do
      if child:IsA("ImageButton") then
          applyStuds(child)
      end
  end
  ```

- [ ] **Step 4: Verify UI changes**
  Capture Roblox Studio screen to confirm styling matches mockup.

---

### Task 2: Sync and Update Client Controller Script

**Files:**
- Modify: `src/client/controllers/GuiController.luau`
- Modify: `game.StarterPlayer.StarterPlayerScripts.BiggerClient.controllers.GuiController` (via Studio MCP)

**Interfaces:**
- Consumes: Updated GUI hierarchy in Studio.
- Produces: Working click and hover events for VIP, multiplier, and growth buttons, and live stat binding for progress bar labels.

- [ ] **Step 1: Write local script modifications**
  Modify local `src/client/controllers/GuiController.luau` to:
  - Add reference to `ProgressStatsLabel`.
  - Update `UpdateHUD()` to set stats label and use `targetBigger` from `LevelFormula.GetProgress()`.
  - Ensure all right sidebar product buttons connect to product click prompts.

  Code changes in `UpdateHUD` (around lines 61-83):
  ```luau
  local function UpdateHUD()
  	local bigger = LocalPlayer:GetAttribute("Bigger") or 1
  	local level = LocalPlayer:GetAttribute("Level") or 1
  	local multiplier = LocalPlayer:GetAttribute("Multiplier") or 1

  	LevelLabel.Text = FormatNumber(bigger) .. " BIGGER"

  	local ratio, _, targetBigger = CalculateLevelProgress(bigger, level)
  	local progressStatsLabel = ProgressFill.Parent.Parent:FindFirstChild("ProgressStatsLabel") :: TextLabel?
  	if progressStatsLabel then
  		progressStatsLabel.Text = FormatNumber(bigger) .. " / " .. FormatNumber(targetBigger)
  	end

  	-- Hide progress fill if player has no size points yet (starting state)
  	if bigger <= 1 then
  		ProgressFill.Visible = false
  		ProgressFill.Size = UDim2.new(0, 0, 1, 0)
  	else
  		ProgressFill.Visible = true
  		-- Animate progress fill size inside the BarContainer
  		TweenService:Create(ProgressFill, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
  			Size = UDim2.new(ratio, 0, 1, 0),
  		}):Play()
  	end

  	ProgressTextLabel.Text = tostring(multiplier) .. "X Multiplier"
  end
  ```

- [ ] **Step 2: Mirror source to Roblox Studio**
  Update the script source of `game.StarterPlayer.StarterPlayerScripts.BiggerClient.controllers.GuiController` to match the updated local `src/client/controllers/GuiController.luau` file.

- [ ] **Step 3: Playtest verification**
  Run Play Solo mode in Roblox Studio.
  Verify:
  - Hovering over bottom and right buttons scales them slightly.
  - Clicking any developer product button prompts purchase window correctly.
  - Progress bar shows `Bigger / TargetBigger` numbers in the center and updates when `Bigger` changes.
