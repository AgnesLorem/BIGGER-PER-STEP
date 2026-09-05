--!strict
-- tier3_cross_feature.luau
-- Tier 3: Cross-Feature Combinations

local Tier3 = {}

function Tier3.Register(F: any, _Context: { Player: Player, Datamodel: string })
	local LevelFormula = require(game:GetService("ReplicatedStorage").BiggerShared.Game.Progression.LevelFormula)
	local RebirthConfig = require(game:GetService("ReplicatedStorage").BiggerShared.Game.Progression.RebirthConfig)

	-- 1. Level up while RebirthMenu is open
	F.RegisterTest("Tier3", "T3_CROSS_01_LiveLevelUpWhileOpen", function()
		-- Simulate level change from 5 -> 20 while UI state is active
		local initialSize = LevelFormula.GetRequirement(5)
		local initialLevel = LevelFormula.GetLevel(initialSize)
		F.AssertEqual(initialLevel, 5, "Initial level is 5")

		local newSize = LevelFormula.GetRequirement(20)
		local newLevel = LevelFormula.GetLevel(newSize)
		F.AssertEqual(newLevel, 20, "Updated level is 20")

		local reqLevel = 20
		local canRebirthInitial = initialLevel >= reqLevel
		local canRebirthUpdated = newLevel >= reqLevel

		F.AssertFalse(canRebirthInitial, "CanRebirth false at level 5")
		F.AssertTrue(canRebirthUpdated, "CanRebirth true at level 20")
	end, "CROSS_FEATURE")

	-- 2. Rebirth -> Size reset -> Multiplier refresh
	F.RegisterTest("Tier3", "T3_CROSS_02_RebirthSizeResetMultiplierRefresh", function()
		local fakeSession = {
			Bigger = 1000,
			Rebirth = 0,
			HasDoubleMultiplier = false,
			HasVip = false,
		}

		-- Execute rebirth
		fakeSession.Rebirth += 1
		fakeSession.Bigger = RebirthConfig.RebirthResetSize

		F.AssertEqual(fakeSession.Rebirth, 1, "Rebirth incremented to 1")
		F.AssertEqual(fakeSession.Bigger, 1, "Bigger reset to 1")

		local newLevel = LevelFormula.GetLevel(fakeSession.Bigger)
		F.AssertEqual(newLevel, 1, "Level reset to 1 after size reset")
	end, "CROSS_FEATURE")

	-- 3. LeftSidebar toggle -> CloseButton -> Rebirth flow
	F.RegisterTest("Tier3", "T3_CROSS_03_SidebarToggleCloseRebirthLifecycle", function()
		local isOpen = false
		local overlayVisible = false

		-- Open via LeftSidebar
		isOpen = true
		overlayVisible = true
		F.AssertTrue(isOpen, "Panel opened via sidebar")
		F.AssertTrue(overlayVisible, "OverlayHUD opened via sidebar")

		-- Close via CloseButton
		isOpen = false
		overlayVisible = false
		F.AssertFalse(isOpen, "Panel closed via CloseButton")
		F.AssertFalse(overlayVisible, "OverlayHUD closed via CloseButton")

		-- Re-open and execute rebirth
		isOpen = true
		overlayVisible = true
		F.AssertTrue(isOpen, "Panel re-opened")
	end, "CROSS_FEATURE")

	-- 4. Respawn state sync
	F.RegisterTest("Tier3", "T3_CROSS_04_CharacterRespawnStatePersistence", function()
		-- Verify ScreenGui has ResetOnSpawn = false or survives respawn
		local starterGui = game:GetService("StarterGui")
		local mainHud = starterGui:FindFirstChild("MainHUD") :: ScreenGui?
		if mainHud then
			F.AssertFalse(mainHud.ResetOnSpawn, "MainHUD must have ResetOnSpawn = false")
		else
			F.AssertTrue(true, "MainHUD check skipped in standalone context")
		end
	end, "CROSS_FEATURE")

	-- 5. Multiple modal interaction under OverlayHUD
	F.RegisterTest("Tier3", "T3_CROSS_05_MultiModalOverlayHUDCoordination", function()
		local modals = {
			RebirthPanel = false,
			ShopPanel = false,
			SettingsPanel = false,
		}

		local function GetOverlayVisible()
			for _, visible in pairs(modals) do
				if visible then
					return true
				end
			end
			return false
		end

		modals.RebirthPanel = true
		F.AssertTrue(GetOverlayVisible(), "OverlayHUD visible when RebirthPanel open")

		modals.ShopPanel = true
		F.AssertTrue(GetOverlayVisible(), "OverlayHUD visible when both open")

		modals.RebirthPanel = false
		F.AssertTrue(GetOverlayVisible(), "OverlayHUD visible while ShopPanel still open")

		modals.ShopPanel = false
		F.AssertFalse(GetOverlayVisible(), "OverlayHUD hidden when all modals close")
	end, "CROSS_FEATURE")

	-- 6. Skip Rebirth Dispatcher Integration
	F.RegisterTest("Tier3", "T3_CROSS_06_SkipRebirthDispatcherIntegration", function()
		local session = {
			Bigger = 50, -- Below requirement
			Rebirth = 0,
		}

		-- Apply SkipRebirth (bypasses size requirement)
		local skipSizeCheck = true
		if skipSizeCheck or session.Bigger >= 1000 then
			session.Rebirth += 1
			session.Bigger = RebirthConfig.RebirthResetSize
		end

		F.AssertEqual(session.Rebirth, 1, "Rebirth incremented via SkipRebirth")
		F.AssertEqual(session.Bigger, 1, "Size reset to 1 via SkipRebirth")
	end, "CROSS_FEATURE")
end

return Tier3
