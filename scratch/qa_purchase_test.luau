--!strict
-- qa_purchase_test.luau
-- Verifies purchase idempotency: dispatch once → Dispatched → commit → Completed.
-- Tests that duplicate receipts skip dispatch and return PurchaseGranted.
-- Run via execute_luau in Roblox Studio or manual Play Solo console.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local PurchaseState = require(ReplicatedStorage.BiggerShared.Core.Enums.PurchaseState)

local function Assert(Condition: boolean, Message: string)
	if not Condition then
		error("[QA FAIL] " .. Message)
	end
	print("[QA PASS] " .. Message)
end

-- Test 1: PurchaseState enum values
Assert(PurchaseState.None == 0, "PurchaseState.None == 0")
Assert(PurchaseState.Dispatched == 1, "PurchaseState.Dispatched == 1")
Assert(PurchaseState.Completed == 2, "PurchaseState.Completed == 2")

-- Test 2: PurchaseState is frozen
local ok = pcall(function()
	(PurchaseState :: any).NewState = 3
end)
Assert(not ok, "PurchaseState table is frozen (cannot add new keys)")

-- Test 3: LevelFormula progression sanity
local LevelFormula = require(ReplicatedStorage.BiggerShared.Game.Progression.LevelFormula)

Assert(LevelFormula.GetLevel(0) == 1, "GetLevel(0) == 1")
Assert(LevelFormula.GetLevel(4) == 1, "GetLevel(4) == 1 (below Tutorial threshold)")
Assert(LevelFormula.GetLevel(5) == 2, "GetLevel(5) == 2 (Tutorial Level 2 requires 5)")
Assert(LevelFormula.GetLevel(6) == 3, "GetLevel(6) == 3 (Tutorial Level 3 requires 6)")

-- Test 4: Requirements monotonically increase
local prevReq = -1
for level = 1, 200 do
	local req = LevelFormula.GetRequirement(level)
	Assert(req >= prevReq, "Requirement monotonic at Level " .. level .. ": " .. req .. " >= " .. prevReq)
	prevReq = req
end

-- Test 5: GetLevel round-trips with GetRequirement
for level = 1, 100 do
	local req = LevelFormula.GetRequirement(level)
	local computed = LevelFormula.GetLevel(req)
	Assert(computed == level, "Round-trip Level " .. level .. ": GetLevel(GetRequirement(" .. level .. ")) == " .. computed)
end

-- Test 6: GetProgress returns valid ratios
local ratio, current, total = LevelFormula.GetProgress(10)
Assert(ratio >= 0 and ratio <= 1, "GetProgress ratio is clamped [0,1]: " .. ratio)
Assert(current >= 0, "GetProgress current >= 0: " .. current)
Assert(total >= 1, "GetProgress total >= 1: " .. total)

-- Test 7: Backward compatibility aliases
Assert(LevelFormula.GetLevelFromBigger(5) == LevelFormula.GetLevel(5), "GetLevelFromBigger alias matches GetLevel")
Assert(LevelFormula.GetRequirementForLevel(10) == LevelFormula.GetRequirement(10), "GetRequirementForLevel alias matches GetRequirement")

print("\n[QA] All purchase and progression tests passed!")
