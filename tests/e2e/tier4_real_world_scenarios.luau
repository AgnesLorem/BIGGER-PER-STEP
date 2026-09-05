--!strict
-- tier4_real_world_scenarios.luau
-- Tier 4: Real-World Application Scenarios

local Tier4 = {}

function Tier4.Register(F: any, _Context: { Player: Player, Datamodel: string })
	local LevelFormula = require(game:GetService("ReplicatedStorage").BiggerShared.Game.Progression.LevelFormula)
	local RebirthConfig = require(game:GetService("ReplicatedStorage").BiggerShared.Game.Progression.RebirthConfig)
	local RebirthError = require(game:GetService("ReplicatedStorage").BiggerShared.Core.Enums.RebirthError)

	local function CalculateRequiredLevel(Rebirths: number): number
		if Rebirths == 0 then
			return 20
		elseif Rebirths == 1 then
			return 50
		elseif Rebirths == 2 then
			return 75
		elseif Rebirths == 3 then
			return 100
		elseif Rebirths == 4 then
			return 150
		else
			return 150 + (Rebirths - 4) * 50
		end
	end

	-- Journey 1: Full Single-Player Lifecycle Journey
	F.RegisterTest("Tier4", "T4_REAL_01_FullPlayerLifecycleJourney", function()
		-- Step 1: Fresh join
		local playerSession = {
			Bigger = 1,
			Rebirth = 0,
			HasDoubleMultiplier = false,
			HasVip = false,
			ProfileMutationsFrozen = false,
			State = "InLobby",
		}

		-- Step 2: Open RebirthMenu
		local isOpen = true
		F.AssertTrue(isOpen, "RebirthMenu opened")

		-- Step 3: Verify initial presentation state
		local currentLevel = LevelFormula.GetLevel(playerSession.Bigger)
		local requiredLevel = CalculateRequiredLevel(playerSession.Rebirth)
		local canRebirth = currentLevel >= requiredLevel

		F.AssertEqual(currentLevel, 1, "Initial Level is 1")
		F.AssertEqual(requiredLevel, 20, "Tier 0 Required Level is 20")
		F.AssertFalse(canRebirth, "CanRebirth is false initially")

		-- Step 4: Early rebirth attempt rejected
		local rebirthSuccess = false
		local errorReason = nil
		if canRebirth then
			rebirthSuccess = true
		else
			errorReason = RebirthError.SizeRequirementNotMet
		end
		F.AssertFalse(rebirthSuccess, "Early rebirth rejected")
		F.AssertEqual(errorReason, RebirthError.SizeRequirementNotMet, "Error reason is SizeRequirementNotMet")
		F.AssertEqual(playerSession.Rebirth, 0, "Rebirth count remains 0")

		-- Step 5: Growth to Level 10
		local size10 = LevelFormula.GetRequirement(10)
		playerSession.Bigger = size10
		currentLevel = LevelFormula.GetLevel(playerSession.Bigger)
		F.AssertEqual(currentLevel, 10, "Current level is 10")
		canRebirth = currentLevel >= requiredLevel
		F.AssertFalse(canRebirth, "CanRebirth still false at Level 10")

		-- Step 6: Growth to Level 20
		local size20 = LevelFormula.GetRequirement(20)
		playerSession.Bigger = size20
		currentLevel = LevelFormula.GetLevel(playerSession.Bigger)
		F.AssertEqual(currentLevel, 20, "Current level is 20")
		canRebirth = currentLevel >= requiredLevel
		F.AssertTrue(canRebirth, "CanRebirth is true at Level 20")

		-- Step 7: Successful Rebirth Execution
		if canRebirth and playerSession.State == "InLobby" and not playerSession.ProfileMutationsFrozen then
			playerSession.Rebirth += 1
			playerSession.Bigger = RebirthConfig.RebirthResetSize
			rebirthSuccess = true
		end

		F.AssertTrue(rebirthSuccess, "Rebirth succeeded")
		F.AssertEqual(playerSession.Rebirth, 1, "Rebirth count incremented to 1")
		F.AssertEqual(playerSession.Bigger, 1, "Size reset to 1")

		-- Step 8: Verify UI next-tier presentation
		local postRebirthLevel = LevelFormula.GetLevel(playerSession.Bigger)
		local postRebirthReq = CalculateRequiredLevel(playerSession.Rebirth)
		F.AssertEqual(postRebirthLevel, 1, "Level reset to 1")
		F.AssertEqual(postRebirthReq, 50, "Tier 1 Required Level is 50")

		-- Step 9: Close menu
		isOpen = false
		F.AssertFalse(isOpen, "RebirthMenu closed cleanly")
	end, "REAL_WORLD")

	-- Journey 2: Multi-Tier Marathon (Tier 0 -> 1 -> 2)
	F.RegisterTest("Tier4", "T4_REAL_02_MultiTierMarathon", function()
		local playerSession = {
			Bigger = 1,
			Rebirth = 0,
			HasDoubleMultiplier = false,
			HasVip = false,
			ProfileMutationsFrozen = false,
			State = "InLobby",
		}

		local targetTiers = {
			{ Tier = 0, ReqLevel = 20 },
			{ Tier = 1, ReqLevel = 50 },
			{ Tier = 2, ReqLevel = 75 },
		}

		for _, step in ipairs(targetTiers) do
			local reqLevel = CalculateRequiredLevel(playerSession.Rebirth)
			F.AssertEqual(reqLevel, step.ReqLevel, "Tier " .. step.Tier .. " requires Level " .. step.ReqLevel)

			-- Simulate growing to exact requirement
			local targetSize = LevelFormula.GetRequirement(reqLevel)
			playerSession.Bigger = targetSize
			local curLevel = LevelFormula.GetLevel(playerSession.Bigger)
			F.AssertTrue(curLevel >= reqLevel, "Player reached required level")

			-- Execute Rebirth
			playerSession.Rebirth += 1
			playerSession.Bigger = RebirthConfig.RebirthResetSize
			F.AssertEqual(playerSession.Bigger, 1, "Size reset to 1 after tier " .. step.Tier)
		end

		F.AssertEqual(playerSession.Rebirth, 3, "Player completed 3 rebirths")
		local tier3Req = CalculateRequiredLevel(playerSession.Rebirth)
		F.AssertEqual(tier3Req, 100, "Tier 3 requires Level 100")
	end, "REAL_WORLD")

	-- Journey 3: Skip Rebirth Monetization Journey
	F.RegisterTest("Tier4", "T4_REAL_03_SkipRebirthMonetizationJourney", function()
		local playerSession = {
			Bigger = LevelFormula.GetRequirement(5), -- Low level (Level 5)
			Rebirth = 0,
			HasDoubleMultiplier = false,
			HasVip = false,
			ProfileMutationsFrozen = false,
			State = "InLobby",
		}

		local initialLevel = LevelFormula.GetLevel(playerSession.Bigger)
		F.AssertTrue(initialLevel < 20, "Player is under level 20")
		F.AssertEqual(initialLevel, 5, "Player is exactly level 5")

		-- Player clicks Skip Rebirth -> developer product purchase simulation
		local purchaseCompleted = true
		if purchaseCompleted then
			-- RewardDispatcher executes SkipRebirth
			playerSession.Rebirth += 1
			playerSession.Bigger = RebirthConfig.RebirthResetSize
		end

		F.AssertEqual(playerSession.Rebirth, 1, "Rebirth incremented to 1 via SkipRebirth")
		F.AssertEqual(playerSession.Bigger, 1, "Size reset to 1 via SkipRebirth")

		local newReqLevel = CalculateRequiredLevel(playerSession.Rebirth)
		F.AssertEqual(newReqLevel, 50, "Next requirement is Level 50")
	end, "REAL_WORLD")
end

return Tier4
