--!strict
--// Raw Requirings \\--
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")

--// Types \\--
type ReportItem = {
	Path: string,
	Type: string,
	Message: string,
}

--// Variables \\--
local MainHUD = StarterGui:FindFirstChild("MainHUD")
if not MainHUD then
	error("MainHUD not found under StarterGui!")
end

-- Supported modes: "ValidateOnly" | "Repair" | "Backup" | "Restore"
local Mode: "ValidateOnly" | "Repair" | "Backup" | "Restore" = "ValidateOnly"

-- Embedded backup data for RESTORE mode (injected programmatically by the runner)
local RESTORE_DATA: { [string]: any }? = nil

--// Helpers \\--
local function toSerializable(val: any): any
	if typeof(val) == "UDim2" then
		return {val.X.Scale, val.X.Offset, val.Y.Scale, val.Y.Offset}
	elseif typeof(val) == "Vector2" then
		return {val.X, val.Y}
	elseif typeof(val) == "UDim" then
		return {val.Scale, val.Offset}
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
	elseif typeof(v1) == "UDim" then
		return v1.Scale == v2.Scale and v1.Offset == v2.Offset
	else
		return v1 == v2
	end
end

-- Reconstruct the logical path of any descendant of MainHUD relative to MainHUD
local function getLogicalPath(inst: Instance): string?
	if inst == MainHUD then return nil end

	local parts = {}
	local current: Instance = inst
	while current and current ~= MainHUD do
		if current.Name == "LeftSidebar" or current.Name == "BottomHUD" or current.Name == "RightSidebar" then
			table.insert(parts, 1, current.Name)
			break
		elseif current.Name == "SafeAreaRoot" then
			table.insert(parts, 1, "SafeAreaRoot")
			break
		elseif current.Name == "PersistentHUD" and current.Parent and current.Parent.Name == "SafeAreaRoot" then
			table.insert(parts, 1, "PersistentHUD")
		elseif current.Name == "OverlayHUD" and current.Parent and current.Parent.Name == "SafeAreaRoot" then
			table.insert(parts, 1, "OverlayHUD")
		else
			table.insert(parts, 1, current.Name)
		end
		
		local parent = current.Parent
		if not parent then break end
		current = parent
	end

	if #parts == 0 then return nil end
	return table.concat(parts, ".")
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

	local function backupInstance(inst: Instance)
		local path = getLogicalPath(inst)
		if not path then return end

		local props = {}
		if inst:IsA("GuiObject") then
			if inst.Name == "SafeAreaRoot" or inst.Name == "PersistentHUD" or inst.Name == "OverlayHUD" then
				props = {"Size", "Position", "BackgroundTransparency"}
			elseif inst.Name == "LeftSidebar" or inst.Name == "RightSidebar" or inst.Name == "BottomHUD" then
				props = {"AnchorPoint", "Position", "Size", "ZIndex"}
			else
				props = {"AnchorPoint", "Position", "Size"}
				if inst:IsA("TextLabel") or inst:IsA("TextBox") then
					table.insert(props, "TextScaled")
				end
			end
		elseif inst:IsA("UIAspectRatioConstraint") then
			props = {"AspectRatio"}
		elseif inst:IsA("UITextSizeConstraint") then
			props = {"MinTextSize", "MaxTextSize"}
		elseif inst:IsA("UIScale") then
			props = {"Scale"}
		elseif inst:IsA("UICorner") then
			props = {"CornerRadius"}
		elseif inst:IsA("UIPadding") then
			props = {"PaddingTop", "PaddingBottom", "PaddingLeft", "PaddingRight"}
		elseif inst:IsA("UIGridLayout") then
			props = {"CellSize", "CellPadding"}
		elseif inst:IsA("UIListLayout") then
			props = {"Padding", "FillDirection", "HorizontalAlignment", "VerticalAlignment", "SortOrder"}
		end

		if #props > 0 then
			serializeInstance(path, inst, props)
		end
	end

	-- Traverse and backup all elements under MainHUD
	for _, descendant in ipairs(MainHUD:GetDescendants()) do
		backupInstance(descendant)
	end

	printJSON("HUD_BACKUP", backup)
end

--// Restore Mode Execution \\--
local function runRestore()
	local restoreData = RESTORE_DATA
	if not restoreData then
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
	for logicalPath, data in pairs(restoreData) do
		local inst = findByLogicalPath(logicalPath)
		if inst then
			for propName, serializableVal in pairs(data.Properties) do
				local val = nil
				if propName == "Position" or propName == "Size" or propName == "CellSize" or propName == "CellPadding" then
					val = UDim2.new(serializableVal[1], serializableVal[2], serializableVal[3], serializableVal[4])
				elseif propName == "AnchorPoint" then
					val = Vector2.new(serializableVal[1], serializableVal[2])
				elseif propName == "PaddingTop" or propName == "PaddingBottom" or propName == "PaddingLeft" or propName == "PaddingRight" or propName == "CornerRadius" or propName == "Padding" then
					val = UDim.new(serializableVal[1], serializableVal[2])
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

	-- Destroy any new helper instances created during Repair mode that did not exist in the backup
	local helperClasses = {"UITextSizeConstraint", "UIAspectRatioConstraint", "UIScale", "UIPadding", "UICorner"}
	local destroyedHelpersCount = 0
	for _, descendant in ipairs(MainHUD:GetDescendants()) do
		if table.find(helperClasses, descendant.ClassName) then
			local logicalPath = getLogicalPath(descendant)
			if logicalPath and not restoreData[logicalPath] then
				descendant:Destroy()
				destroyedHelpersCount = destroyedHelpersCount + 1
				print("[Restore] Destroyed new helper: " .. logicalPath)
			end
		end
	end
	print("[Restore] Cleaned up " .. tostring(destroyedHelpersCount) .. " new helper elements.")
end

--// Validate & Repair Modes Execution \\--
local function runValidateOrRepair()
	local errors: {ReportItem} = {}
	local warnings: {ReportItem} = {}
	local duplicates: {ReportItem} = {}
	local fixesApplied = 0
	local totalChecks = 0
	local failedChecks = 0

	local function logError(path: string, typeName: string, msg: string)
		table.insert(errors, {
			Path = path,
			Type = typeName,
			Message = msg,
		})
		failedChecks = failedChecks + 1
	end

	local function logWarning(path: string, typeName: string, msg: string)
		table.insert(warnings, {
			Path = path,
			Type = typeName,
			Message = msg,
		})
		failedChecks = failedChecks + 1
	end

	local function logDuplicate(path: string, typeName: string, msg: string)
		local item = {
			Path = path,
			Type = typeName,
			Message = msg,
		}
		table.insert(duplicates, item)
		table.insert(errors, item) -- Report them in Duplicates / Errors as DuplicateConstraint
		failedChecks = failedChecks + 1
	end

	local function check(cond: boolean, isError: boolean, typeName: string, path: string, msg: string): boolean
		totalChecks = totalChecks + 1
		if not cond then
			if isError then
				logError(path, typeName, msg)
			else
				logWarning(path, typeName, msg)
			end
			return false
		end
		return true
	end

	local function checkProperty(instName: string, inst: Instance, propName: string, expected: any, isError: boolean): boolean
		local ok, actual = pcall(function() return (inst :: any)[propName] end)
		local path = "StarterGui.MainHUD." .. instName
		if not ok then
			check(false, isError, "InvalidProperty", path, string.format("Property %s not found on %s (%s)", propName, instName, inst.ClassName))
			return false
		end

		local match = valuesEqual(actual, expected)
		if check(match, isError, "InvalidScale", path, string.format("%s.%s is %s, expected %s", instName, propName, tostring(actual), tostring(expected))) then
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

	local function checkDuplicates(parentName: string, parentInst: Instance)
		local constraintClasses = {
			"UIAspectRatioConstraint",
			"UITextSizeConstraint",
			"UISizeConstraint",
			"UIScale",
			"UIPadding",
			"UIStroke",
			"UICorner",
			"UIListLayout",
			"UIGridLayout"
		}

		local foundCounts = {}
		for _, child in ipairs(parentInst:GetChildren()) do
			local className = child.ClassName
			if table.find(constraintClasses, className) then
				if not foundCounts[className] then
					foundCounts[className] = {}
				end
				table.insert(foundCounts[className], child)
			end
		end

		for className, instances in pairs(foundCounts) do
			if #instances > 1 then
				local path = "StarterGui.MainHUD." .. parentName
				totalChecks = totalChecks + 1
				logDuplicate(path, "DuplicateConstraint", string.format("Duplicate %s constraints (%d) found under %s", className, #instances, parentName))
				if Mode == "Repair" then
					for i = 2, #instances do
						local inst = instances[i]
						inst:Destroy()
						fixesApplied = fixesApplied + 1
						print(string.format("[Repair] Removed duplicate %s under %s", className, parentName))
					end
				end
			end
		end
	end

	local function checkConstraint(parentName: string, parentInst: Instance, className: string, expectedProps: {[string]: any})
		local path = "StarterGui.MainHUD." .. parentName
		totalChecks = totalChecks + 1
		local found = {}
		for _, child in ipairs(parentInst:GetChildren()) do
			if child.ClassName == className then
				table.insert(found, child)
			end
		end

		if #found == 0 then
			logWarning(path, "MissingConstraint", string.format("Missing %s under %s", className, parentName))
			if Mode == "Repair" then
				local newConst = Instance.new(className)
				for prop, val in pairs(expectedProps) do
					(newConst :: any)[prop] = val
				end
				newConst.Parent = parentInst
				fixesApplied = fixesApplied + 1
				print(string.format("[Repair] Created %s under %s", className, parentName))
				-- Check properties of newly created constraint
				for prop, val in pairs(expectedProps) do
					checkProperty(parentName .. "." .. className, newConst, prop, val, false)
				end
			end
			return
		end

		local targetConst = found[1]
		for prop, val in pairs(expectedProps) do
			checkProperty(parentName .. "." .. className, targetConst, prop, val, false)
		end
	end

	local function checkContainerRules(containerName: string, containerInst: Instance, expectedLayoutClass: string)
		local path = "StarterGui.MainHUD." .. containerName

		-- 1. UIPadding check
		local paddings = {}
		for _, child in ipairs(containerInst:GetChildren()) do
			if child.ClassName == "UIPadding" then
				table.insert(paddings, child)
			end
		end

		totalChecks = totalChecks + 1
		if #paddings == 0 then
			logWarning(path, "MissingPadding", string.format("Missing UIPadding under %s", containerName))
			if Mode == "Repair" then
				local padding = Instance.new("UIPadding")
				padding.PaddingTop = UDim.new(0, 0)
				padding.PaddingBottom = UDim.new(0, 0)
				padding.PaddingLeft = UDim.new(0, 0)
				padding.PaddingRight = UDim.new(0, 0)
				padding.Parent = containerInst
				fixesApplied = fixesApplied + 1
				print(string.format("[Repair] Created UIPadding under %s", containerName))
			end
		elseif #paddings > 1 then
			logDuplicate(path, "DuplicateConstraint", string.format("Duplicate UIPadding (%d) found under %s", #paddings, containerName))
			if Mode == "Repair" then
				for i = 2, #paddings do
					paddings[i]:Destroy()
					fixesApplied = fixesApplied + 1
					print(string.format("[Repair] Removed duplicate UIPadding under %s", containerName))
				end
			end
		end

		-- 2. Layout object check
		local layouts = {}
		for _, child in ipairs(containerInst:GetChildren()) do
			if child.ClassName == "UIListLayout" or child.ClassName == "UIGridLayout" or child.ClassName == "UIFlexItem" then
				table.insert(layouts, child)
			end
		end

		totalChecks = totalChecks + 1
		if #layouts == 0 then
			logWarning(path, "MissingLayout", string.format("Missing Layout object under %s", containerName))
			if Mode == "Repair" then
				local layout = Instance.new(expectedLayoutClass)
				layout.Parent = containerInst
				fixesApplied = fixesApplied + 1
				print(string.format("[Repair] Created %s under %s", expectedLayoutClass, containerName))
			end
		elseif #layouts > 1 then
			logDuplicate(path, "DuplicateConstraint", string.format("Duplicate Layout (%d) found under %s", #layouts, containerName))
			if Mode == "Repair" then
				for i = 2, #layouts do
					layouts[i]:Destroy()
					fixesApplied = fixesApplied + 1
					print(string.format("[Repair] Removed duplicate Layout under %s", containerName))
				end
			end
		else
			local layout = layouts[1]
			if layout.ClassName ~= expectedLayoutClass then
				logWarning(path, "InvalidLayout", string.format("Expected layout of class %s, found %s under %s", expectedLayoutClass, layout.ClassName, containerName))
			end
		end
	end

	-- 1. Verify Hierarchy Integrity
	local hierarchyOk = true
	local safeAreaRoot = MainHUD:FindFirstChild("SafeAreaRoot")
	if not check(safeAreaRoot ~= nil, true, "MissingSafeArea", "StarterGui.MainHUD.SafeAreaRoot", "Missing SafeAreaRoot under MainHUD") then
		hierarchyOk = false
	else
		local persistentHUD = (safeAreaRoot :: Instance):FindFirstChild("PersistentHUD")
		if not check(persistentHUD ~= nil, true, "MissingPersistentHUD", "StarterGui.MainHUD.SafeAreaRoot.PersistentHUD", "Missing PersistentHUD under SafeAreaRoot") then
			hierarchyOk = false
		else
			local leftSidebar = MainHUD:FindFirstChild("LeftSidebar", true)
			if check(leftSidebar ~= nil, true, "MissingContainer", "StarterGui.MainHUD.LeftSidebar", "Missing LeftSidebar in MainHUD") then
				if not check(leftSidebar.Parent == persistentHUD, true, "InvalidParentage", "StarterGui.MainHUD.LeftSidebar", "LeftSidebar is not parented to PersistentHUD") then
					hierarchyOk = false
				end
			else
				hierarchyOk = false
			end

			local bottomHUD = MainHUD:FindFirstChild("BottomHUD", true)
			if check(bottomHUD ~= nil, true, "MissingContainer", "StarterGui.MainHUD.BottomHUD", "Missing BottomHUD in MainHUD") then
				if not check(bottomHUD.Parent == persistentHUD, true, "InvalidParentage", "StarterGui.MainHUD.BottomHUD", "BottomHUD is not parented to PersistentHUD") then
					hierarchyOk = false
				end
			else
				hierarchyOk = false
			end

			local rightSidebar = MainHUD:FindFirstChild("RightSidebar", true)
			if check(rightSidebar ~= nil, true, "MissingContainer", "StarterGui.MainHUD.RightSidebar", "Missing RightSidebar in MainHUD") then
				if not check(rightSidebar.Parent == persistentHUD, true, "InvalidParentage", "StarterGui.MainHUD.RightSidebar", "RightSidebar is not parented to PersistentHUD") then
					hierarchyOk = false
				end
			else
				hierarchyOk = false
			end
		end

		local overlayHUD = (safeAreaRoot :: Instance):FindFirstChild("OverlayHUD")
		check(overlayHUD ~= nil, true, "MissingOverlayHUD", "StarterGui.MainHUD.SafeAreaRoot.OverlayHUD", "Missing OverlayHUD under SafeAreaRoot")
	end

	if not hierarchyOk and Mode == "Repair" then
		error("Hierarchy validation failed: Base HUD containers not found in correct wrapper hierarchy. Aborting migration!")
	end

	-- 2. Validate/Repair wrappers if they exist
	if safeAreaRoot then
		checkProperty("SafeAreaRoot", safeAreaRoot, "Size", UDim2.new(1, 0, 1, 0), true)
		checkProperty("SafeAreaRoot", safeAreaRoot, "Position", UDim2.new(0, 0, 0, 0), true)
		checkProperty("SafeAreaRoot", safeAreaRoot, "BackgroundTransparency", 1, true)
	end
	local persistentHUD = safeAreaRoot and safeAreaRoot:FindFirstChild("PersistentHUD")
	if persistentHUD then
		checkProperty("SafeAreaRoot.PersistentHUD", persistentHUD, "Size", UDim2.new(1, 0, 1, 0), true)
		checkProperty("SafeAreaRoot.PersistentHUD", persistentHUD, "Position", UDim2.new(0, 0, 0, 0), true)
		checkProperty("SafeAreaRoot.PersistentHUD", persistentHUD, "BackgroundTransparency", 1, true)
	end
	local overlayHUD = safeAreaRoot and safeAreaRoot:FindFirstChild("OverlayHUD")
	if overlayHUD then
		checkProperty("SafeAreaRoot.OverlayHUD", overlayHUD, "Size", UDim2.new(1, 0, 1, 0), true)
		checkProperty("SafeAreaRoot.OverlayHUD", overlayHUD, "Position", UDim2.new(0, 0, 0, 0), true)
		checkProperty("SafeAreaRoot.OverlayHUD", overlayHUD, "BackgroundTransparency", 1, true)
	end

	-- 3. Validate/Repair sidebar and bottom HUD properties
	local leftSidebar = MainHUD:FindFirstChild("LeftSidebar", true)
	local bottomHUD = MainHUD:FindFirstChild("BottomHUD", true)
	local rightSidebar = MainHUD:FindFirstChild("RightSidebar", true)

	if leftSidebar then
		checkProperty("LeftSidebar", leftSidebar, "AnchorPoint", Vector2.new(0, 0.5), true)
		checkProperty("LeftSidebar", leftSidebar, "Position", UDim2.new(0.02, 0, 0.5, 0), true)
		checkProperty("LeftSidebar", leftSidebar, "Size", UDim2.new(0.12, 0, 0.35, 0), true)
		checkProperty("LeftSidebar", leftSidebar, "ZIndex", 10, true)

		checkContainerRules("LeftSidebar", leftSidebar, "UIGridLayout")
		checkDuplicates("LeftSidebar", leftSidebar)

		local grid = leftSidebar:FindFirstChildOfClass("UIGridLayout")
		if grid then
			checkProperty("LeftSidebar.UIGridLayout", grid, "CellSize", UDim2.new(0.46, 0, 0.3, 0), true)
			checkProperty("LeftSidebar.UIGridLayout", grid, "CellPadding", UDim2.new(0.08, 0, 0.05, 0), true)
		end

		for _, child in ipairs(leftSidebar:GetChildren()) do
			if child:IsA("ImageButton") then
				checkConstraint("LeftSidebar." .. child.Name, child, "UIAspectRatioConstraint", {AspectRatio = 1.0})
				checkConstraint("LeftSidebar." .. child.Name, child, "UIScale", {Scale = 1.0})
				checkConstraint("LeftSidebar." .. child.Name, child, "UICorner", {CornerRadius = UDim.new(0, 8)})
				checkDuplicates("LeftSidebar." .. child.Name, child)
			end
		end
	end

	if bottomHUD then
		checkProperty("BottomHUD", bottomHUD, "AnchorPoint", Vector2.new(0.5, 1), true)
		checkProperty("BottomHUD", bottomHUD, "Position", UDim2.new(0.5, 0, 1, -10), true)
		checkProperty("BottomHUD", bottomHUD, "Size", UDim2.new(0.5, 0, 0.22, 0), true)
		checkProperty("BottomHUD", bottomHUD, "ZIndex", 10, true)

		local progressBarFrame = bottomHUD:FindFirstChild("ProgressBarFrame")
		if check(progressBarFrame ~= nil, true, "MissingFrame", "StarterGui.MainHUD.BottomHUD.ProgressBarFrame", "Missing ProgressBarFrame under BottomHUD") then
			checkProperty("BottomHUD.ProgressBarFrame", progressBarFrame, "AnchorPoint", Vector2.new(0, 0), true)
			checkProperty("BottomHUD.ProgressBarFrame", progressBarFrame, "Position", UDim2.new(0, 0, 0, 0), true)
			checkProperty("BottomHUD.ProgressBarFrame", progressBarFrame, "Size", UDim2.new(1, 0, 0.3, 0), true)

			local progressBG = progressBarFrame:FindFirstChild("ProgressBG")
			if check(progressBG ~= nil, true, "MissingImage", "StarterGui.MainHUD.BottomHUD.ProgressBarFrame.ProgressBG", "Missing ProgressBG under ProgressBarFrame") then
				checkProperty("BottomHUD.ProgressBarFrame.ProgressBG", progressBG, "AnchorPoint", Vector2.new(0.5, 0.5), true)
				checkProperty("BottomHUD.ProgressBarFrame.ProgressBG", progressBG, "Position", UDim2.new(0.5, 0, 0.5, 0), true)
				checkProperty("BottomHUD.ProgressBarFrame.ProgressBG", progressBG, "Size", UDim2.new(1, -8, 1, -8), true)

				local barContainer = progressBG:FindFirstChild("BarContainer")
				if check(barContainer ~= nil, true, "MissingFrame", "StarterGui.MainHUD.BottomHUD.ProgressBarFrame.ProgressBG.BarContainer", "Missing BarContainer under ProgressBG") then
					checkProperty("BottomHUD.ProgressBarFrame.ProgressBG.BarContainer", barContainer, "AnchorPoint", Vector2.new(0.5, 0.5), true)
					checkProperty("BottomHUD.ProgressBarFrame.ProgressBG.BarContainer", barContainer, "Position", UDim2.new(0.5, 0, 0.5, 0), true)
					checkProperty("BottomHUD.ProgressBarFrame.ProgressBG.BarContainer", barContainer, "Size", UDim2.new(1, -8, 1, -8), true)

					local progressFill = barContainer:FindFirstChild("ProgressFill")
					if check(progressFill ~= nil, true, "MissingImage", "StarterGui.MainHUD.BottomHUD.ProgressBarFrame.ProgressBG.BarContainer.ProgressFill", "Missing ProgressFill under BarContainer") then
						checkProperty("BottomHUD.ProgressBarFrame.ProgressBG.BarContainer.ProgressFill", progressFill, "AnchorPoint", Vector2.new(0, 0.5), true)
						checkProperty("BottomHUD.ProgressBarFrame.ProgressBG.BarContainer.ProgressFill", progressFill, "Position", UDim2.new(0, 0, 0.5, 0), true)
						checkProperty("BottomHUD.ProgressBarFrame.ProgressBG.BarContainer.ProgressFill", progressFill, "Size", UDim2.new(0, 0, 1, 0), true)
					end
				end

				local levelLabel = progressBG:FindFirstChild("LevelLabel")
				if check(levelLabel ~= nil, true, "MissingLabel", "StarterGui.MainHUD.BottomHUD.ProgressBarFrame.ProgressBG.LevelLabel", "Missing LevelLabel under ProgressBG") then
					checkProperty("BottomHUD.ProgressBarFrame.ProgressBG.LevelLabel", levelLabel, "AnchorPoint", Vector2.new(0, 0.5), true)
					checkProperty("BottomHUD.ProgressBarFrame.ProgressBG.LevelLabel", levelLabel, "Position", UDim2.new(0.02, 0, 0.5, 0), true)
					checkProperty("BottomHUD.ProgressBarFrame.ProgressBG.LevelLabel", levelLabel, "Size", UDim2.new(0.45, 0, 0.8, 0), true)
					checkProperty("BottomHUD.ProgressBarFrame.ProgressBG.LevelLabel", levelLabel, "TextScaled", true, true)
					checkConstraint("BottomHUD.ProgressBarFrame.ProgressBG.LevelLabel", levelLabel, "UITextSizeConstraint", {MinTextSize = 12, MaxTextSize = 32})
					checkDuplicates("BottomHUD.ProgressBarFrame.ProgressBG.LevelLabel", levelLabel)
				end

				local progressTextLabel = progressBG:FindFirstChild("ProgressTextLabel")
				if check(progressTextLabel ~= nil, true, "MissingLabel", "StarterGui.MainHUD.BottomHUD.ProgressBarFrame.ProgressBG.ProgressTextLabel", "Missing ProgressTextLabel under ProgressBG") then
					checkProperty("BottomHUD.ProgressBarFrame.ProgressBG.ProgressTextLabel", progressTextLabel, "AnchorPoint", Vector2.new(1, 0.5), true)
					checkProperty("BottomHUD.ProgressBarFrame.ProgressBG.ProgressTextLabel", progressTextLabel, "Position", UDim2.new(0.98, 0, 0.5, 0), true)
					checkProperty("BottomHUD.ProgressBarFrame.ProgressBG.ProgressTextLabel", progressTextLabel, "Size", UDim2.new(0.45, 0, 0.8, 0), true)
					checkProperty("BottomHUD.ProgressBarFrame.ProgressBG.ProgressTextLabel", progressTextLabel, "TextScaled", true, true)
					checkConstraint("BottomHUD.ProgressBarFrame.ProgressBG.ProgressTextLabel", progressTextLabel, "UITextSizeConstraint", {MinTextSize = 12, MaxTextSize = 32})
					checkDuplicates("BottomHUD.ProgressBarFrame.ProgressBG.ProgressTextLabel", progressTextLabel)
				end
			end
		end

		local buttonsContainer = bottomHUD:FindFirstChild("ButtonsContainer")
		if check(buttonsContainer ~= nil, true, "MissingContainer", "StarterGui.MainHUD.BottomHUD.ButtonsContainer", "Missing ButtonsContainer under BottomHUD") then
			checkProperty("BottomHUD.ButtonsContainer", buttonsContainer, "AnchorPoint", Vector2.new(0, 0), true)
			checkProperty("BottomHUD.ButtonsContainer", buttonsContainer, "Position", UDim2.new(0, 0, 0.65, 0), true)
			checkProperty("BottomHUD.ButtonsContainer", buttonsContainer, "Size", UDim2.new(1, 0, 0.35, 0), true)

			checkContainerRules("BottomHUD.ButtonsContainer", buttonsContainer, "UIListLayout")
			checkDuplicates("BottomHUD.ButtonsContainer", buttonsContainer)

			for _, child in ipairs(buttonsContainer:GetChildren()) do
				if child:IsA("ImageButton") then
					checkConstraint("BottomHUD.ButtonsContainer." .. child.Name, child, "UIAspectRatioConstraint", {AspectRatio = 2.5})
					checkConstraint("BottomHUD.ButtonsContainer." .. child.Name, child, "UIScale", {Scale = 1.0})
					checkConstraint("BottomHUD.ButtonsContainer." .. child.Name, child, "UICorner", {CornerRadius = UDim.new(0, 8)})
					checkDuplicates("BottomHUD.ButtonsContainer." .. child.Name, child)
				end
			end
		end
	end

	if rightSidebar then
		checkProperty("RightSidebar", rightSidebar, "AnchorPoint", Vector2.new(1, 0.5), true)
		checkProperty("RightSidebar", rightSidebar, "Position", UDim2.new(0.98, 0, 0.5, 0), true)
		checkProperty("RightSidebar", rightSidebar, "Size", UDim2.new(0.18, 0, 0.22, 0), true)
		checkProperty("RightSidebar", rightSidebar, "ZIndex", 10, true)

		checkContainerRules("RightSidebar", rightSidebar, "UIListLayout")
		checkDuplicates("RightSidebar", rightSidebar)

		for _, child in ipairs(rightSidebar:GetChildren()) do
			if child:IsA("ImageButton") then
				checkConstraint("RightSidebar." .. child.Name, child, "UIAspectRatioConstraint", {AspectRatio = 2.5})
				checkConstraint("RightSidebar." .. child.Name, child, "UIScale", {Scale = 1.0})
				checkConstraint("RightSidebar." .. child.Name, child, "UICorner", {CornerRadius = UDim.new(0, 8)})
				checkDuplicates("RightSidebar." .. child.Name, child)

				local textLabel = child:FindFirstChildOfClass("TextLabel")
				if check(textLabel ~= nil, true, "MissingTextLabel", "StarterGui.MainHUD.RightSidebar." .. child.Name, "Missing TextLabel under RightSidebar." .. child.Name) then
					checkProperty("RightSidebar." .. child.Name .. ".TextLabel", textLabel, "TextScaled", true, true)
					checkConstraint("RightSidebar." .. child.Name .. ".TextLabel", textLabel, "UITextSizeConstraint", {MinTextSize = 12, MaxTextSize = 32})
					checkDuplicates("RightSidebar." .. child.Name .. ".TextLabel", textLabel)
				end
			end
		end
	end

	local complianceScore = 100
	if totalChecks > 0 then
		complianceScore = math.floor((totalChecks - failedChecks) / totalChecks * 100)
	end

	local report = {
		Timestamp = DateTime.now():ToIsoDate(),
		ComplianceScore = complianceScore,
		FixesApplied = fixesApplied,
		Errors = errors,
		Warnings = warnings,
		Duplicates = duplicates,
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
