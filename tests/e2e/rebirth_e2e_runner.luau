--!strict
-- rebirth_e2e_runner.luau
-- Unified E2E Test Suite Runner for Roblox Studio & Game Context.

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")

local F = require(script.Parent.test_framework)
local Tier1 = require(script.Parent.tier1_feature_coverage)
local Tier2 = require(script.Parent.tier2_boundary_corner)
local Tier3 = require(script.Parent.tier3_cross_feature)
local Tier4 = require(script.Parent.tier4_real_world_scenarios)

local Runner = {}

function Runner.Run(TargetPlayer: Player?): string
	F.ClearTests()

	local player = TargetPlayer or Players:GetPlayers()[1] or Players.LocalPlayer
	local context = {
		Player = player,
		Datamodel = if game:GetService("RunService"):IsServer() then "Server" else "Client",
	}

	-- Register all 4 tiers
	Tier1.Register(F, context)
	Tier2.Register(F, context)
	Tier3.Register(F, context)
	Tier4.Register(F, context)

	-- Execute all tests
	local report = F.RunAll()

	return HttpService:JSONEncode(report)
end

return Runner
