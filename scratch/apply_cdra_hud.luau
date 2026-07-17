--!strict
--// Raw Requirings \\--
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")

--// Variables \\--
local MainHUD = StarterGui:FindFirstChild("MainHUD")
if not MainHUD then
	error("MainHUD not found under StarterGui!")
end

-- Supported modes: "ValidateOnly" | "Repair" | "Backup" | "Restore"
local Mode: "ValidateOnly" | "Repair" | "Backup" | "Restore" = "ValidateOnly"

-- Embedded backup data for RESTORE mode (injected programmatically by the runner)
local RESTORE_DATA = nil

--// Helpers \\--
local function toSerializable(val: any): any
	if typeof(val) == "UDim2" then
		return {val.X.Scale, val.X.Offset, val.Y.Scale, val.Y.Offset}
	elseif typeof(val) == "Vector2" then
		return {val.X, val.Y}
	else
		return val
	end
end

local function printJSON(marker: string, data: any)
	local jsonStr = HttpService:JSONEncode(data)
	print("---START_" .. marker .. "---")
	print(jsonStr)
	print("---END_" .. marker .. "---")
end

local function valuesEqual(v1: any, v2: any): boolean
	if typeof(v1) ~= typeof(v2) then return false end
	if typeof(v1) == "UDim2" then
		return v1.X.Scale == v2.X.Scale and v1.X.Offset == v2.X.Offset and
			v1.Y.Scale == v2.Y.Scale and v1.Y.Offset == v2.Y.Offset
	elseif typeof(v1) == "Vector2" then
		return v1.X == v2.X and v1.Y == v2.Y
	else
		return v1 == v2
	end
end

--// Backup Mode Execution \\--
local function runBackup()
	local backup = {}

	local function serializeInstance(path: string, inst: Instance, props: {string})
		local data = { ClassName = inst.ClassName, Properties = {} }
		for _, prop in ipairs(props) do
			local ok, val = pcall(function() return (inst :: any)[prop] end)
			if ok then
				data.Properties[prop] = toSerializable(val)
			end
		end
		backup[path] = data
	end

	-- 1. Backup wrappers if they exist
	local safeAreaRoot = MainHUD:FindFirstChild("SafeAreaRoot")
	if safeAreaRoot then
		serializeInstance("SafeAreaRoot", safeAreaRoot, {"Size", "Position", "BackgroundTransparency"})
		local persistentHUD = safeAreaRoot:FindFirstChild("PersistentHUD")
		if persistentHUD then
			serializeInstance("SafeAreaRoot.PersistentHUD", persistentHUD, {"Size", "Position", "BackgroundTransparency"})
		end
		local overlayHUD = safeAreaRoot:FindFirstChild("OverlayHUD")
		if overlayHUD then
			serializeInstance("SafeAreaRoot.OverlayHUD", overlayHUD, {"Size", "Position", "BackgroundTransparency"})
		end
	end

	-- 2. Find LeftSidebar, BottomHUD, RightSidebar recursively
	local leftSidebar = MainHUD:FindFirstChild("LeftSidebar", true)
	local bottomHUD = MainHUD:FindFirstChild("BottomHUD", true)
	local rightSidebar = MainHUD:FindFirstChild("RightSidebar", true)

	if leftSidebar then
		serializeInstance("LeftSidebar", leftSidebar, {"AnchorPoint", "Position", "Size", "ZIndex"})
		local grid = leftSidebar:FindFirstChildOfClass("UIGridLayout")
		if grid then
			serializeInstance("LeftSidebar." .. grid.Name, grid, {"CellSize", "CellPadding"})
		end
		for _, child in ipairs(leftSidebar:GetChildren()) do
			if child:IsA("ImageButton") then
				serializeInstance("LeftSidebar." .. child.Name, child, {"AnchorPoint", "Position", "Size"})
				local aspect = child:FindFirstChildOfClass("UIAspectRatioConstraint")
				if aspect then
					serializeInstance("LeftSidebar." .. child.Name .. "." .. aspect.Name, aspect, {"AspectRatio"})
				end
			end
		end
	end

	if rightSidebar then
		serializeInstance("RightSidebar", rightSidebar, {"AnchorPoint", "Position", "Size", "ZIndex"})
		for _, child in ipairs(rightSidebar:GetChildren()) do
			if child:IsA("ImageButton") then
				serializeInstance("RightSidebar." .. child.Name, child, {"AnchorPoint", "Position", "Size"})
				local aspect = child:FindFirstChildOfClass("UIAspectRatioConstraint")
				if aspect then
					serializeInstance("RightSidebar." .. child.Name .. "." .. aspect.Name, aspect, {"AspectRatio"})
				end
				local textLabel = child:FindFirstChildOfClass("TextLabel")
				if textLabel then
					serializeInstance("RightSidebar." .. child.Name .. "." .. textLabel.Name, textLabel, {"AnchorPoint", "Position", "Size", "TextScaled"})
					local textSize = textLabel:FindFirstChildOfClass("UITextSizeConstraint")
					if textSize then
						serializeInstance("RightSidebar." .. child.Name .. "." .. textLabel.Name .. "." .. textSize.Name, textSize, {"MinTextSize", "MaxTextSize"})
					end
				end
			end
		end
	end

	if bottomHUD then
		serializeInstance("BottomHUD", bottomHUD, {"AnchorPoint", "Position", "Size", "ZIndex"})
		local progressBarFrame = bottomHUD:FindFirstChild("ProgressBarFrame")
		if progressBarFrame then
			serializeInstance("BottomHUD.ProgressBarFrame", progressBarFrame, {"AnchorPoint", "Position", "Size"})
			local progressBG = progressBarFrame:FindFirstChild("ProgressBG")
			if progressBG then
				serializeInstance("BottomHUD.ProgressBarFrame.ProgressBG", progressBG, {"AnchorPoint", "Position", "Size"})
				local barContainer = progressBG:FindFirstChild("BarContainer")
				if barContainer then
					serializeInstance("BottomHUD.ProgressBarFrame.ProgressBG.BarContainer", barContainer, {"AnchorPoint", "Position", "Size"})
					local progressFill = barContainer:FindFirstChild("ProgressFill")
					if progressFill then
						serializeInstance("BottomHUD.ProgressBarFrame.ProgressBG.BarContainer.ProgressFill", progressFill, {"AnchorPoint", "Position", "Size"})
					end
				end
				local levelLabel = progressBG:FindFirstChild("LevelLabel")
				if levelLabel then
					serializeInstance("BottomHUD.ProgressBarFrame.ProgressBG.LevelLabel", levelLabel, {"AnchorPoint", "Position", "Size", "TextScaled"})
					local textSize = levelLabel:FindFirstChildOfClass("UITextSizeConstraint")
					if textSize then
						serializeInstance("BottomHUD.ProgressBarFrame.ProgressBG.LevelLabel." .. textSize.Name, textSize, {"MinTextSize", "MaxTextSize"})
					end
				end
				local progressTextLabel = progressBG:FindFirstChild("ProgressTextLabel")
				if progressTextLabel then
					serializeInstance("BottomHUD.ProgressBarFrame.ProgressBG.ProgressTextLabel", progressTextLabel, {"AnchorPoint", "Position", "Size", "TextScaled"})
					local textSize = progressTextLabel:FindFirstChildOfClass("UITextSizeConstraint")
					if textSize then
						serializeInstance("BottomHUD.ProgressBarFrame.ProgressBG.ProgressTextLabel." .. textSize.Name, textSize, {"MinTextSize", "MaxTextSize"})
					end
				end
			end
		end

		local buttonsContainer = bottomHUD:FindFirstChild("ButtonsContainer")
		if buttonsContainer then
			serializeInstance("BottomHUD.ButtonsContainer", buttonsContainer, {"AnchorPoint", "Position", "Size"})
			for _, child in ipairs(buttonsContainer:GetChildren()) do
				if child:IsA("ImageButton") then
					serializeInstance("BottomHUD.ButtonsContainer." .. child.Name, child, {"AnchorPoint", "Position", "Size"})
					local aspect = child:FindFirstChildOfClass("UIAspectRatioConstraint")
					if aspect then
						serializeInstance("BottomHUD.ButtonsContainer." .. child.Name .. "." .. aspect.Name, aspect, {"AspectRatio"})
					end
				end
			end
		end
	end

	printJSON("HUD_BACKUP", backup)
end

--// Restore Mode Execution \\--
local function runRestore()
	if not RESTORE_DATA then
		error("RESTORE_DATA is empty. Cannot restore!")
	end

	local function findByLogicalPath(logicalPath: string): Instance?
		local parts = string.split(logicalPath, ".")
		local current: Instance? = MainHUD

		local startIdx = 1
		if parts[1] == "LeftSidebar" or parts[1] == "BottomHUD" or parts[1] == "RightSidebar" then
			current = MainHUD:FindFirstChild(parts[1], true)
			startIdx = 2
		elseif parts[1] == "SafeAreaRoot" then
			current = MainHUD:FindFirstChild("SafeAreaRoot")
			startIdx = 2
			if current and parts[2] == "PersistentHUD" then
				current = current:FindFirstChild("PersistentHUD")
				startIdx = 3
			elseif current and parts[2] == "OverlayHUD" then
				current = current:FindFirstChild("OverlayHUD")
				startIdx = 3
			end
		end

		if not current then return nil end

		for i = startIdx, #parts do
			current = current:FindFirstChild(parts[i])
			if not current then return nil end
		end
		return current
	end

	local restoredCount = 0
	for logicalPath, data in pairs(RESTORE_DATA) do
		local inst = findByLogicalPath(logicalPath)
		if inst then
			for propName, serializableVal in pairs(data.Properties) do
				local val = nil
				if propName == "Position" or propName == "Size" or propName == "CellSize" or propName == "CellPadding" then
					val = UDim2.new(serializableVal[1], serializableVal[2], serializableVal[3], serializableVal[4])
				elseif propName == "AnchorPoint" then
					val = Vector2.new(serializableVal[1], serializableVal[2])
				else
					val = serializableVal
				end
				(inst :: any)[propName] = val
			end
			restoredCount = restoredCount + 1
			print("[Restore] Restored " .. logicalPath)
		else
			print("[Restore] Warning: element not found for path: " .. logicalPath)
		end
	end
	print("[Restore] Restored " .. tostring(restoredCount) .. " elements successfully!")
end

--// Validate & Repair Modes Execution \\--
local function runValidateOrRepair()
	local errors = {}
	local warnings = {}
	local fixesApplied = 0
	local totalChecks = 0
	local failedChecks = 0

	local function logError(msg: string)
		table.insert(errors, msg)
		failedChecks = failedChecks + 1
	end

	local function logWarning(msg: string)
		table.insert(warnings, msg)
		failedChecks = failedChecks + 1
	end

	local function check(cond: boolean, isError: boolean, msg: string): boolean
		totalChecks = totalChecks + 1
		if not cond then
			if isError then
				logError(msg)
			else
				logWarning(msg)
			end
			return false
		end
		return true
	end

	local function checkProperty(instName: string, inst: Instance, propName: string, expected: any, isError: boolean): boolean
		local ok, actual = pcall(function() return (inst :: any)[propName] end)
		if not ok then
			check(false, isError, string.format("Property %s not found on %s (%s)", propName, instName, inst.ClassName))
			return false
		end

		local match = valuesEqual(actual, expected)
		if check(match, isError, string.format("%s.%s is %s, expected %s", instName, propName, tostring(actual), tostring(expected))) then
			return true
		else
			if Mode == "Repair" then
				local setOk, setErr = pcall(function() (inst :: any)[propName] = expected end)
				if setOk then
					fixesApplied = fixesApplied + 1
					print(string.format("[Repair] Set %s.%s to %s", instName, propName, tostring(expected)))
				else
					print(string.format("[Repair] Failed to set %s.%s: %s", instName, propName, tostring(setErr)))
				end
			end
			return false
		end
	end

	local function checkConstraint(parentName: string, parentInst: Instance, className: string, expectedProps: {[string]: any})
		totalChecks = totalChecks + 1
		local children = parentInst:GetChildren()
		local found = {}
		for _, child in ipairs(children) do
			if child.ClassName == className then
				table.insert(found, child)
			end
		end

		if #found == 0 then
			logWarning(string.format("Missing %s under %s", className, parentName))
			if Mode == "Repair" then
				local newConst = Instance.new(className)
				for prop, val in pairs(expectedProps) do
					(newConst :: any)[prop] = val
				end
				newConst.Parent = parentInst
				fixesApplied = fixesApplied + 1
				print(string.format("[Repair] Created %s under %s", className, parentName))
			end
			return
		end

		if #found > 1 then
			logWarning(string.format("Duplicate %s constraints (%d) found under %s", className, #found, parentName))
			if Mode == "Repair" then
				for i = 2, #found do
					found[i]:Destroy()
					fixesApplied = fixesApplied + 1
					print(string.format("[Repair] Removed duplicate %s under %s", className, parentName))
				end
			end
		end

		local targetConst = found[1]
		for prop, val in pairs(expectedProps) do
			checkProperty(parentName .. "." .. className, targetConst, prop, val, false)
		end
	end

	-- 1. Verify Hierarchy Integrity
	local hierarchyOk = true
	local safeAreaRoot = MainHUD:FindFirstChild("SafeAreaRoot")
	if not check(safeAreaRoot ~= nil, true, "Missing SafeAreaRoot under MainHUD") then
		hierarchyOk = false
	else
		local persistentHUD = (safeAreaRoot :: Instance):FindFirstChild("PersistentHUD")
		if not check(persistentHUD ~= nil, true, "Missing PersistentHUD under SafeAreaRoot") then
			hierarchyOk = false
		else
			local leftSidebar = MainHUD:FindFirstChild("LeftSidebar", true)
			if check(leftSidebar ~= nil, true, "Missing LeftSidebar in MainHUD") then
				if not check(leftSidebar.Parent == persistentHUD, true, "LeftSidebar is not parented to PersistentHUD") then
					hierarchyOk = false
				end
			else
				hierarchyOk = false
			end

			local bottomHUD = MainHUD:FindFirstChild("BottomHUD", true)
			if check(bottomHUD ~= nil, true, "Missing BottomHUD in MainHUD") then
				if not check(bottomHUD.Parent == persistentHUD, true, "BottomHUD is not parented to PersistentHUD") then
					hierarchyOk = false
				end
			else
				hierarchyOk = false
			end

			local rightSidebar = MainHUD:FindFirstChild("RightSidebar", true)
			if check(rightSidebar ~= nil, true, "Missing RightSidebar in MainHUD") then
				if not check(rightSidebar.Parent == persistentHUD, true, "RightSidebar is not parented to PersistentHUD") then
					hierarchyOk = false
				end
			else
				hierarchyOk = false
			end
		end

		local overlayHUD = (safeAreaRoot :: Instance):FindFirstChild("OverlayHUD")
		check(overlayHUD ~= nil, true, "Missing OverlayHUD under SafeAreaRoot")
	end

	if not hierarchyOk and Mode == "Repair" then
		error("Hierarchy validation failed: Base HUD containers not found in correct wrapper hierarchy. Aborting migration!")
	end

	-- 2. Validate/Repair sidebar and bottom HUD properties
	local leftSidebar = MainHUD:FindFirstChild("LeftSidebar", true)
	local bottomHUD = MainHUD:FindFirstChild("BottomHUD", true)
	local rightSidebar = MainHUD:FindFirstChild("RightSidebar", true)

	if leftSidebar then
		checkProperty("LeftSidebar", leftSidebar, "AnchorPoint", Vector2.new(0, 0.5), true)
		checkProperty("LeftSidebar", leftSidebar, "Position", UDim2.new(0.02, 0, 0.5, 0), true)
		checkProperty("LeftSidebar", leftSidebar, "Size", UDim2.new(0.12, 0, 0.35, 0), true)
		checkProperty("LeftSidebar", leftSidebar, "ZIndex", 10, true)

		local grid = leftSidebar:FindFirstChildOfClass("UIGridLayout")
		if check(grid ~= nil, true, "Missing UIGridLayout under LeftSidebar") then
			checkProperty("LeftSidebar.UIGridLayout", (grid :: Instance), "CellSize", UDim2.new(0.46, 0, 0.3, 0), true)
			checkProperty("LeftSidebar.UIGridLayout", (grid :: Instance), "CellPadding", UDim2.new(0.08, 0, 0.05, 0), true)
		end

		for _, child in ipairs(leftSidebar:GetChildren()) do
			if child:IsA("ImageButton") then
				checkConstraint("LeftSidebar." .. child.Name, child, "UIAspectRatioConstraint", {AspectRatio = 1.0})
			end
		end
	end

	if bottomHUD then
		checkProperty("BottomHUD", bottomHUD, "AnchorPoint", Vector2.new(0.5, 1), true)
		checkProperty("BottomHUD", bottomHUD, "Position", UDim2.new(0.5, 0, 1, -10), true)
		checkProperty("BottomHUD", bottomHUD, "Size", UDim2.new(0.5, 0, 0.22, 0), true)
		checkProperty("BottomHUD", bottomHUD, "ZIndex", 10, true)

		local progressBarFrame = bottomHUD:FindFirstChild("ProgressBarFrame")
		if check(progressBarFrame ~= nil, true, "Missing ProgressBarFrame under BottomHUD") then
			checkProperty("BottomHUD.ProgressBarFrame", progressBarFrame, "AnchorPoint", Vector2.new(0, 0), true)
			checkProperty("BottomHUD.ProgressBarFrame", progressBarFrame, "Position", UDim2.new(0, 0, 0, 0), true)
			checkProperty("BottomHUD.ProgressBarFrame", progressBarFrame, "Size", UDim2.new(1, 0, 0.3, 0), true)

			local progressBG = progressBarFrame:FindFirstChild("ProgressBG")
			if check(progressBG ~= nil, true, "Missing ProgressBG under ProgressBarFrame") then
				checkProperty("BottomHUD.ProgressBarFrame.ProgressBG", progressBG, "AnchorPoint", Vector2.new(0.5, 0.5), true)
				checkProperty("BottomHUD.ProgressBarFrame.ProgressBG", progressBG, "Position", UDim2.new(0.5, 0, 0.5, 0), true)
				checkProperty("BottomHUD.ProgressBarFrame.ProgressBG", progressBG, "Size", UDim2.new(1, -8, 1, -8), true)

				local barContainer = progressBG:FindFirstChild("BarContainer")
				if check(barContainer ~= nil, true, "Missing BarContainer under ProgressBG") then
					checkProperty("BottomHUD.ProgressBarFrame.ProgressBG.BarContainer", barContainer, "AnchorPoint", Vector2.new(0.5, 0.5), true)
					checkProperty("BottomHUD.ProgressBarFrame.ProgressBG.BarContainer", barContainer, "Position", UDim2.new(0.5, 0, 0.5, 0), true)
					checkProperty("BottomHUD.ProgressBarFrame.ProgressBG.BarContainer", barContainer, "Size", UDim2.new(1, -8, 1, -8), true)

					local progressFill = barContainer:FindFirstChild("ProgressFill")
					if check(progressFill ~= nil, true, "Missing ProgressFill under BarContainer") then
						checkProperty("BottomHUD.ProgressBarFrame.ProgressBG.BarContainer.ProgressFill", progressFill, "AnchorPoint", Vector2.new(0, 0.5), true)
						checkProperty("BottomHUD.ProgressBarFrame.ProgressBG.BarContainer.ProgressFill", progressFill, "Position", UDim2.new(0, 0, 0.5, 0), true)
						checkProperty("BottomHUD.ProgressBarFrame.ProgressBG.BarContainer.ProgressFill", progressFill, "Size", UDim2.new(0, 0, 1, 0), true)
					end
				end

				local levelLabel = progressBG:FindFirstChild("LevelLabel")
				if check(levelLabel ~= nil, true, "Missing LevelLabel under ProgressBG") then
					checkProperty("BottomHUD.ProgressBarFrame.ProgressBG.LevelLabel", levelLabel, "AnchorPoint", Vector2.new(0, 0.5), true)
					checkProperty("BottomHUD.ProgressBarFrame.ProgressBG.LevelLabel", levelLabel, "Position", UDim2.new(0.02, 0, 0.5, 0), true)
					checkProperty("BottomHUD.ProgressBarFrame.ProgressBG.LevelLabel", levelLabel, "Size", UDim2.new(0.45, 0, 0.8, 0), true)
					checkProperty("BottomHUD.ProgressBarFrame.ProgressBG.LevelLabel", levelLabel, "TextScaled", true, true)
					checkConstraint("BottomHUD.ProgressBarFrame.ProgressBG.LevelLabel", levelLabel, "UITextSizeConstraint", {MinTextSize = 12, MaxTextSize = 32})
				end

				local progressTextLabel = progressBG:FindFirstChild("ProgressTextLabel")
				if check(progressTextLabel ~= nil, true, "Missing ProgressTextLabel under ProgressBG") then
					checkProperty("BottomHUD.ProgressBarFrame.ProgressBG.ProgressTextLabel", progressTextLabel, "AnchorPoint", Vector2.new(1, 0.5), true)
					checkProperty("BottomHUD.ProgressBarFrame.ProgressBG.ProgressTextLabel", progressTextLabel, "Position", UDim2.new(0.98, 0, 0.5, 0), true)
					checkProperty("BottomHUD.ProgressBarFrame.ProgressBG.ProgressTextLabel", progressTextLabel, "Size", UDim2.new(0.45, 0, 0.8, 0), true)
					checkProperty("BottomHUD.ProgressBarFrame.ProgressBG.ProgressTextLabel", progressTextLabel, "TextScaled", true, true)
					checkConstraint("BottomHUD.ProgressBarFrame.ProgressBG.ProgressTextLabel", progressTextLabel, "UITextSizeConstraint", {MinTextSize = 12, MaxTextSize = 32})
				end
			end
		end

		local buttonsContainer = bottomHUD:FindFirstChild("ButtonsContainer")
		if check(buttonsContainer ~= nil, true, "Missing ButtonsContainer under BottomHUD") then
			for _, child in ipairs(buttonsContainer:GetChildren()) do
				if child:IsA("ImageButton") then
					checkConstraint("BottomHUD.ButtonsContainer." .. child.Name, child, "UIAspectRatioConstraint", {AspectRatio = 2.5})
				end
			end
		end
	end

	if rightSidebar then
		checkProperty("RightSidebar", rightSidebar, "AnchorPoint", Vector2.new(1, 0.5), true)
		checkProperty("RightSidebar", rightSidebar, "Position", UDim2.new(0.98, 0, 0.5, 0), true)
		checkProperty("RightSidebar", rightSidebar, "Size", UDim2.new(0.18, 0, 0.22, 0), true)
		checkProperty("RightSidebar", rightSidebar, "ZIndex", 10, true)

		for _, child in ipairs(rightSidebar:GetChildren()) do
			if child:IsA("ImageButton") then
				checkConstraint("RightSidebar." .. child.Name, child, "UIAspectRatioConstraint", {AspectRatio = 2.5})

				local textLabel = child:FindFirstChildOfClass("TextLabel")
				if check(textLabel ~= nil, true, "Missing TextLabel under RightSidebar." .. child.Name) then
					checkProperty("RightSidebar." .. child.Name .. ".TextLabel", textLabel, "TextScaled", true, true)
					checkConstraint("RightSidebar." .. child.Name .. ".TextLabel", textLabel, "UITextSizeConstraint", {MinTextSize = 12, MaxTextSize = 32})
				end
			end
		end
	end

	local complianceScore = 100
	if totalChecks > 0 then
		complianceScore = math.floor((totalChecks - failedChecks) / totalChecks * 100)
	end

	local report = {
		complianceScore = complianceScore,
		errors = errors,
		warnings = warnings,
		fixesApplied = fixesApplied,
		totalChecks = totalChecks,
		failedChecks = failedChecks,
	}

	printJSON("HUD_REPORT", report)
end

--// Main Router \\--
if Mode == "Backup" then
	runBackup()
elseif Mode == "Restore" then
	runRestore()
else
	runValidateOrRepair()
end

return "HUD CDRA migration run completed successfully!"
