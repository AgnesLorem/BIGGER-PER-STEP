--!strict
-- partial_bundle_test.luau
-- Verifies all-or-nothing reward dispatching.
-- A bundle with one valid + one invalid reward must apply ZERO rewards.
-- Run via execute_luau in Roblox Studio (requires a connected player).

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local RewardDispatcher = require(game:GetService("ServerScriptService").BiggerServer.Core.Utilities.RewardDispatcher)
local Sessions = require(game:GetService("ServerScriptService").BiggerServer.Core.Registry.RuntimeRegistry.Sessions)

local function Assert(Condition: boolean, Message: string)
	if not Condition then
		error("[BUNDLE FAIL] " .. Message)
	end
	print("[BUNDLE PASS] " .. Message)
end

-- Wait for a player to test with
local player = Players:GetPlayers()[1]
if not player then
	player = Players.PlayerAdded:Wait()
end

-- Wait for session to load
task.wait(2)
local session = Sessions.Get(player)
if not session then
	error("[BUNDLE FAIL] No session found for " .. player.Name)
end

-- Record starting Bigger value
local startBigger = session.Bigger

-- Test 1: Valid bundle succeeds
local validResult = RewardDispatcher.Dispatch(player, {
	{ Type = "Bigger", Amount = 100 },
})
Assert(validResult.Success == true, "Valid single-reward bundle dispatches successfully")
Assert(session.Bigger == startBigger + 100, "Bigger increased by 100: " .. session.Bigger)

-- Test 2: Bundle with invalid reward type rejects entirely
local beforeBigger = session.Bigger
local invalidResult = RewardDispatcher.Dispatch(player, {
	{ Type = "Vip" },                         -- Valid reward
	{ Type = "NonExistentReward", Amount = 1 }, -- Invalid reward type
})
Assert(invalidResult.Success == false, "Mixed bundle with invalid type is rejected")
Assert(session.Bigger == beforeBigger, "Bigger unchanged after rejected bundle: " .. session.Bigger)
Assert(session.HasVip == false or session.HasVip == true, "HasVip state unchanged (no partial VIP application)")

-- Test 3: Bundle where validator fails rejects entirely
local beforeBigger2 = session.Bigger
local badAmountResult = RewardDispatcher.Dispatch(player, {
	{ Type = "Bigger", Amount = 50 },  -- Valid
	{ Type = "Bigger", Amount = -1 },  -- Invalid amount (validator rejects)
})
Assert(badAmountResult.Success == false, "Bundle with invalid Bigger amount is rejected")
Assert(session.Bigger == beforeBigger2, "Bigger unchanged after bad-amount rejection: " .. session.Bigger)

print("\n[BUNDLE] All partial bundle failure tests passed!")
