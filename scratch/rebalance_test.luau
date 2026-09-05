--!strict
-- rebalance_test.luau
-- Verifies that the milestone-based BalanceConfig system adapts correctly
-- to parameter changes. Tests stage boundary continuity and formula correctness.
-- Run via execute_luau in Roblox Studio.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local BalanceConfig = require(ReplicatedStorage.BiggerShared.Game.Progression.BalanceConfig)
local LevelFormula = require(ReplicatedStorage.BiggerShared.Game.Progression.LevelFormula)

local function Assert(Condition: boolean, Message: string)
	if not Condition then
		error("[REBALANCE FAIL] " .. Message)
	end
	print("[REBALANCE PASS] " .. Message)
end

-- Test 1: Stages exist and are contiguous
local stages = BalanceConfig.Stages
Assert(#stages >= 2, "At least 2 stages exist: " .. #stages)

for i = 2, #stages do
	local prev = stages[i - 1]
	local curr = stages[i]
	Assert(curr.MinLevel == prev.MaxLevel + 1, "Stage continuity: " .. prev.Name .. " ends at " .. prev.MaxLevel .. ", " .. curr.Name .. " starts at " .. curr.MinLevel)
end

-- Test 2: BaseRequirements are resolved correctly
for i = 2, #stages do
	local stage = stages[i]
	Assert(stage.BaseRequirement > 0, "Stage '" .. stage.Name .. "' has BaseRequirement > 0: " .. stage.BaseRequirement)
end

-- Test 3: Tutorial stage values
Assert(LevelFormula.GetRequirement(1) == 0, "Level 1 requires 0 Bigger")
Assert(LevelFormula.GetRequirement(2) == 5, "Level 2 requires 5 Bigger")
Assert(LevelFormula.GetRequirement(3) == 6, "Level 3 requires 6 Bigger")
Assert(LevelFormula.GetRequirement(20) == 23, "Level 20 requires 23 Bigger (5 + 18)")

-- Test 4: Stage transitions are smooth (no negative jumps)
for level = 1, 200 do
	local req = LevelFormula.GetRequirement(level)
	local nextReq = LevelFormula.GetRequirement(level + 1)
	Assert(nextReq >= req, "Level " .. level .. " -> " .. (level + 1) .. ": " .. nextReq .. " >= " .. req)
end

-- Test 5: Late stage grows aggressively (cubic)
local level160Req = LevelFormula.GetRequirement(160)
local level170Req = LevelFormula.GetRequirement(170)
local level180Req = LevelFormula.GetRequirement(180)
local gap1 = level170Req - level160Req
local gap2 = level180Req - level170Req
Assert(gap2 > gap1, "Late stage acceleration: gap 170-180 (" .. gap2 .. ") > gap 160-170 (" .. gap1 .. ")")

-- Test 6: ScaleCurve uses LevelFormula (no 236 hardcoding)
local ScaleCurve = require(ReplicatedStorage.BiggerShared.Core.Utilities.ScaleCurve)
local scale1 = ScaleCurve.GetVisualScale(0, "level", 0.2)
local scale5 = ScaleCurve.GetVisualScale(5, "level", 0.2)
Assert(scale1 == 1, "ScaleCurve level(0) == 1: " .. scale1)
Assert(scale5 > scale1, "ScaleCurve level(5) > level(0): " .. scale5 .. " > " .. scale1)

print("\n[REBALANCE] All rebalance tests passed!")
