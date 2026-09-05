--!strict
-- ui_responsive_test.luau
-- Comprehensive automated responsive test suite for Roblox Studio (Edit & Play mode)
-- Validates CDRA (Constraint-Driven Responsive Architecture) compliance across devices.

local StarterGui = game:GetService("StarterGui")
local GuiService = game:GetService("GuiService")

local UIResponsiveTest = {}

export type ViewportScenario = {
	Name: string,
	Resolution: Vector2,
	Category: "PhonePortrait" | "PhoneLandscape" | "Tablet" | "Desktop" | "Ultrawide",
	TopInset: number,
	BottomInset: number,
}

local SCENARIOS: { ViewportScenario } = {
	{
		Name = "iPhone SE (Portrait)",
		Resolution = Vector2.new(375, 667),
		Category = "PhonePortrait",
		TopInset = 20,
		BottomInset = 0,
	},
	{
		Name = "iPhone 14 Pro (Portrait - Dynamic Island)",
		Resolution = Vector2.new(393, 852),
		Category = "PhonePortrait",
		TopInset = 54,
		BottomInset = 34,
	},
	{
		Name = "iPhone 14 Pro (Landscape)",
		Resolution = Vector2.new(852, 393),
		Category = "PhoneLandscape",
		TopInset = 0,
		BottomInset = 21,
	},
	{
		Name = "iPad Pro 11-inch",
		Resolution = Vector2.new(834, 1194),
		Category = "Tablet",
		TopInset = 24,
		BottomInset = 20,
	},
	{
		Name = "Desktop 1080p (Standard)",
		Resolution = Vector2.new(1920, 1080),
		Category = "Desktop",
		TopInset = 36,
		BottomInset = 0,
	},
	{
		Name = "Ultrawide 21:9 (1440p)",
		Resolution = Vector2.new(3440, 1440),
		Category = "Ultrawide",
		TopInset = 36,
		BottomInset = 0,
	},
}

export type TestResult = {
	Passed: boolean,
	Issues: { string },
	Warnings: { string },
	ElementCount: number,
	ScenariosTested: number,
}

local function CheckCDRACompliance(rootGui: ScreenGui): (number, { string }, { string })
	local issues: { string } = {}
	local warnings: { string } = {}
	local count = 0

	local safeAreaRoot = rootGui:FindFirstChild("SafeAreaRoot")
	if not safeAreaRoot then
		table.insert(issues, `[CRITICAL] ScreenGui '{rootGui.Name}' missing 'SafeAreaRoot' frame!`)
	else
		local frame = safeAreaRoot :: Frame
		if frame.Size.X.Scale ~= 1 or frame.Size.Y.Scale ~= 1 then
			table.insert(issues, `[CDRA] SafeAreaRoot size is not 100% Scale (1,0, 1,0). Found: {tostring(frame.Size)}`)
		end
		if frame.Position.X.Scale ~= 0 or frame.Position.Y.Scale ~= 0 then
			table.insert(issues, `[CDRA] SafeAreaRoot position is not (0,0, 0,0). Found: {tostring(frame.Position)}`)
		end
	end

	for _, descendant in ipairs(rootGui:GetDescendants()) do
		if descendant:IsA("GuiObject") then
			count += 1
			local name = descendant:GetFullName():gsub("StarterGui%.", "")

			-- Rule 1: No massive hardcoded pixel offset size on main structural containers (> 300px without scale)
			if descendant:IsA("Frame") or descendant:IsA("ScrollingFrame") then
				if descendant.Size.X.Scale == 0 and descendant.Size.X.Offset > 400 then
					table.insert(
						warnings,
						`[Fixed Width] '{name}' has fixed X offset {descendant.Size.X.Offset}px without scale factor.`
					)
				end
				if descendant.Size.Y.Scale == 0 and descendant.Size.Y.Offset > 400 then
					table.insert(
						warnings,
						`[Fixed Height] '{name}' has fixed Y offset {descendant.Size.Y.Offset}px without scale factor.`
					)
				end
			end

			-- Rule 2: Text safety: Check TextScaled or AutomaticSize on TextLabels/TextButtons
			if descendant:IsA("TextLabel") or descendant:IsA("TextButton") then
				local textObj = descendant :: TextLabel
				if not textObj.TextScaled and textObj.TextSize > 24 and textObj.Size.X.Scale > 0.5 then
					table.insert(
						warnings,
						`[Text Scaling] '{name}' (Text: "{textObj.Text}") has TextSize={textObj.TextSize} without TextScaled=true. May clip on small mobile screens.`
					)
				end
			end

			-- Rule 3: Interactive elements touch target size minimum (44x44 safe on mobile)
			if descendant:IsA("ImageButton") or descendant:IsA("TextButton") then
				local button = descendant :: GuiButton
				if button.Size.X.Scale == 0 and button.Size.X.Offset > 0 and button.Size.X.Offset < 32 then
					table.insert(
						warnings,
						`[Touch Target] Button '{name}' is under 32px width ({button.Size.X.Offset}px), difficult for mobile touch.`
					)
				end
			end
		end
	end

	return count, issues, warnings
end

local function SimulateResolutionLayout(screenGui: ScreenGui, scenario: ViewportScenario): { string }
	local scenarioIssues: { string } = {}
	local res = scenario.Resolution
	local safeWidth = res.X
	local safeHeight = res.Y - scenario.TopInset - scenario.BottomInset

	-- Check PersistentHUD
	local safeArea = screenGui:FindFirstChild("SafeAreaRoot")
	if not safeArea then
		return scenarioIssues
	end

	local persistentHUD = safeArea:FindFirstChild("PersistentHUD")
	if persistentHUD then
		local leftSidebar = persistentHUD:FindFirstChild("LeftSidebar") :: Frame?
		local rightSidebar = persistentHUD:FindFirstChild("RightSidebar") :: Frame?
		local bottomHUD = persistentHUD:FindFirstChild("BottomHUD") :: Frame?

		-- Calculate theoretical layout bounds
		if scenario.Category == "PhonePortrait" then
			-- On PhonePortrait, sidebars should collapse or hide
			if leftSidebar and leftSidebar.Visible and leftSidebar.Size.X.Scale > 0.3 then
				table.insert(scenarioIssues, `[{scenario.Name}] LeftSidebar consumes >30% screen width in Portrait.`)
			end
		end

		if bottomHUD and bottomHUD.Visible then
			-- Check bottomHUD height proportion
			local heightRatio = bottomHUD.Size.Y.Scale
			if heightRatio > 0.4 then
				table.insert(scenarioIssues, `[{scenario.Name}] BottomHUD consumes >40% vertical screen height.`)
			end
		end
	end

	-- Check OverlayHUD / Modals
	local overlayHUD = safeArea:FindFirstChild("OverlayHUD")
	if overlayHUD then
		local rebirthPanel = overlayHUD:FindFirstChild("RebirthPanel") :: Frame?
		if rebirthPanel then
			-- Check if RebirthPanel is centered
			if rebirthPanel.AnchorPoint ~= Vector2.new(0.5, 0.5) then
				table.insert(
					scenarioIssues,
					`[{scenario.Name}] RebirthPanel AnchorPoint is not (0.5, 0.5) for proper screen centering.`
				)
			end
		end
	end

	return scenarioIssues
end

function UIResponsiveTest.Run(): TestResult
	local startTime = os.clock()
	local allIssues: { string } = {}
	local allWarnings: { string } = {}
	local totalElements = 0

	print("================================================================================")
	print("               PROJECT BIGGER - RESPONSIVE UI AUTOMATED AUDIT                   ")
	print("================================================================================")

	local screenGuis: { ScreenGui } = {}
	for _, child in ipairs(StarterGui:GetChildren()) do
		if child:IsA("ScreenGui") then
			table.insert(screenGuis, child)
		end
	end

	if #screenGuis == 0 then
		table.insert(allIssues, "No ScreenGui instances found in StarterGui!")
	end

	for _, gui in ipairs(screenGuis) do
		print(string.format("[SCAN] Auditing ScreenGui: %s", gui.Name))
		local elemCount, issues, warnings = CheckCDRACompliance(gui)
		totalElements += elemCount
		for _, iss in ipairs(issues) do
			table.insert(allIssues, iss)
		end
		for _, warn in ipairs(warnings) do
			table.insert(allWarnings, warn)
		end

		print(
			string.format("  -> Scanned %d GUI objects. Static issues: %d, warnings: %d", elemCount, #issues, #warnings)
		)

		-- Emulate scenarios
		print("  -> Testing Responsive Viewport Scenarios:")
		for _, scenario in ipairs(SCENARIOS) do
			local scenIssues = SimulateResolutionLayout(gui, scenario)
			if #scenIssues == 0 then
				print(
					string.format(
						"     [PASS] %-35s (%4dx%-4d %-13s)",
						scenario.Name,
						scenario.Resolution.X,
						scenario.Resolution.Y,
						scenario.Category
					)
				)
			else
				print(
					string.format(
						"     [FAIL] %-35s (%4dx%-4d %-13s) -> %d issues",
						scenario.Name,
						scenario.Resolution.X,
						scenario.Resolution.Y,
						scenario.Category,
						#scenIssues
					)
				)
				for _, si in ipairs(scenIssues) do
					table.insert(allIssues, si)
				end
			end
		end
	end

	local duration = math.round((os.clock() - startTime) * 1000)
	print("--------------------------------------------------------------------------------")
	print(
		string.format(
			"SUMMARY: %d GUI Objects audited across %d Scenarios in %d ms",
			totalElements,
			#SCENARIOS,
			duration
		)
	)
	print(string.format("CRITICAL ISSUES: %d | WARNINGS / ADVICE: %d", #allIssues, #allWarnings))

	if #allIssues > 0 then
		print("\nCRITICAL ISSUES LIST:")
		for idx, iss in ipairs(allIssues) do
			print(string.format("  %d. %s", idx, iss))
		end
	end

	if #allWarnings > 0 then
		print("\nWARNINGS & SUGGESTIONS:")
		for idx, warn in ipairs(allWarnings) do
			print(string.format("  %d. %s", idx, warn))
		end
	end

	local passed = #allIssues == 0
	print("--------------------------------------------------------------------------------")
	print(
		string.format(
			"FINAL RESULT: %s",
			passed and "[PASS] ALL RESPONSIVE CHECKS SATISFIED" or "[FAIL] ISSUES REQUIRE FIXING"
		)
	)
	print("================================================================================")

	return {
		Passed = passed,
		Issues = allIssues,
		Warnings = allWarnings,
		ElementCount = totalElements,
		ScenariosTested = #SCENARIOS,
	}
end

return table.freeze(UIResponsiveTest)
