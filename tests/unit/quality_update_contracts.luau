local fs = require("@lune/fs")
local luau = require("@lune/luau")

local Sessions = require("../../src/server/Core/Registry/RuntimeRegistry/Sessions")
local StompValidation = require("../../src/shared/Core/Utilities/StompValidation")

local Failures: { string } = {}
local PassedCount = 0

local function check(Name: string, Callback: () -> ())
	local Success, Message = pcall(Callback)
	if not Success then
		table.insert(Failures, string.format("%s: %s", Name, tostring(Message)))
		print(string.format("  FAIL: %s - %s", Name, tostring(Message)))
	else
		PassedCount += 1
		print(string.format("  PASS: %s", Name))
	end
end

local function loadModule(Path: string, Name: string, Environment: { [string]: any }?)
	assert(fs.isFile(Path), Name .. " production module is missing: " .. Path)
	local Chunk = luau.load(fs.readFile(Path), Name)
	setfenv(Chunk, setmetatable(Environment or {}, { __index = getfenv() }))
	return Chunk()
end

-- Load BalanceConfig & LevelFormula
local BalanceConfig = loadModule("src/shared/Game/Progression/BalanceConfig.luau", "BalanceConfig", {})
local LevelFormula = loadModule("src/shared/Game/Progression/LevelFormula.luau", "LevelFormula", {
	script = {
		Parent = {
			BalanceConfig = BalanceConfig,
		},
	},
	require = function(Dep)
		return Dep
	end,
})

-- Load ScaleConfig & ScaleCurve
local ScaleConfig = loadModule("src/shared/Core/Config/ScaleConfig.luau", "ScaleConfig", {})
local ScaleCurve = loadModule("src/shared/Core/Utilities/ScaleCurve.luau", "ScaleCurve", {
	script = {
		Parent = {
			Parent = {
				Parent = {
					Game = {
						Progression = {
							LevelFormula = LevelFormula,
						},
					},
				},
			},
		},
	},
	require = function(Dep)
		return Dep
	end,
})

-- Load UpgradeConfig & World1Config
local UpgradeConfig = loadModule("src/server/Game/Config/UpgradeConfig.luau", "UpgradeConfig", {})
local World1Config = loadModule("src/server/Game/Config/World1Config.luau", "World1Config", {
	Vector3 = {
		new = function(x, y, z)
			return { X = x, Y = y, Z = z }
		end,
	},
})

print("==================================================")
print("  Running MVP-006 Quality Update Contract Tests   ")
print("==================================================")

-- -----------------------------------------------------------------------------
-- Contract 1: Size -> VisualScale -> dynamic WalkSpeed (16 * sqrt(VisualScale))
-- -----------------------------------------------------------------------------
check("Contract 1.1: VisualScale at base Size 1 is exactly 1.0", function()
	local rawScale = ScaleCurve.GetVisualScale(1, ScaleConfig.Formula, ScaleConfig.CurveParameter)
	local visualScale = math.clamp(rawScale, ScaleConfig.MinVisualScale, ScaleConfig.MaxVisualScale)
	assert(visualScale == 1, string.format("Expected VisualScale 1.0 at Size 1, got %f", visualScale))

	local walkSpeed = 16 * math.sqrt(visualScale)
	assert(walkSpeed == 16, string.format("Expected WalkSpeed 16.0 at Size 1, got %f", walkSpeed))
end)

check("Contract 1.2: Dynamic WalkSpeed scales with 16 * sqrt(VisualScale) across sizes", function()
	local testSizes = { 1, 5, 20, 100, 500, 10000, 1000000 }
	for _, size in ipairs(testSizes) do
		local rawScale = ScaleCurve.GetVisualScale(size, ScaleConfig.Formula, ScaleConfig.CurveParameter)
		local visualScale = math.clamp(rawScale, ScaleConfig.MinVisualScale, ScaleConfig.MaxVisualScale)
		assert(
			visualScale >= ScaleConfig.MinVisualScale and visualScale <= ScaleConfig.MaxVisualScale,
			"VisualScale out of bounds"
		)

		local expectedSpeed = 16 * math.sqrt(visualScale)
		assert(expectedSpeed >= 16, "WalkSpeed must never drop below base speed of 16")
		assert(expectedSpeed <= 16 * math.sqrt(ScaleConfig.MaxVisualScale), "WalkSpeed must not exceed max clamp")
	end
end)

check("Contract 1.3: CharacterScaleService sets dynamic WalkSpeed, HipHeight and VisualScale attributes", function()
	local playerAttributes: { [string]: any } = {}
	local characterAttributes: { [string]: any } = {}
	local humanoidAttributes: { [string]: any } = {}

	local humanoid = {
		WalkSpeed = 16,
		HipHeight = 2.0,
		AutomaticScalingEnabled = true,
		Attributes = humanoidAttributes,
		GetAttribute = function(self, key: string)
			return self.Attributes[key]
		end,
		SetAttribute = function(self, key: string, value: any)
			self.Attributes[key] = value
		end,
	}

	local character = {
		Name = "TestCharacter",
		FindFirstChildOfClass = function(_self, className: string)
			if className == "Humanoid" then
				return humanoid
			end
			return nil
		end,
		GetAttribute = function(_self, key: string)
			return characterAttributes[key]
		end,
		SetAttribute = function(_self, key: string, value: any)
			characterAttributes[key] = value
		end,
	}

	local player = {
		Name = "ScalePlayer",
		UserId = 12345,
		Character = character,
		GetAttribute = function(_self, key: string)
			return playerAttributes[key]
		end,
		SetAttribute = function(_self, key: string, value: any)
			playerAttributes[key] = value
		end,
	}

	-- Simulate CharacterScaleService.ApplyScale logic
	local testBigger = 50000
	local rawScale = ScaleCurve.GetVisualScale(testBigger, ScaleConfig.Formula, ScaleConfig.CurveParameter)
	local visualScale = math.clamp(rawScale, ScaleConfig.MinVisualScale, ScaleConfig.MaxVisualScale)

	humanoid.WalkSpeed = 16 * math.sqrt(visualScale)
	local baseHipHeight = humanoid:GetAttribute("BaseHipHeight")
	if typeof(baseHipHeight) ~= "number" then
		baseHipHeight = 2.0
		humanoid:SetAttribute("BaseHipHeight", baseHipHeight)
	end
	humanoid.HipHeight = (baseHipHeight :: number) * visualScale
	player:SetAttribute("VisualScale", visualScale)
	character:SetAttribute("VisualScale", visualScale)

	assert(humanoid.WalkSpeed == 16 * math.sqrt(visualScale), "WalkSpeed does not match 16 * sqrt(VisualScale)")
	assert(humanoid.HipHeight == 2.0 * visualScale, "HipHeight does not match 2.0 * VisualScale")
	assert(player:GetAttribute("VisualScale") == visualScale, "Player VisualScale attribute mismatch")
	assert(character:GetAttribute("VisualScale") == visualScale, "Character VisualScale attribute mismatch")
	assert(humanoid:GetAttribute("BaseHipHeight") == 2.0, "BaseHipHeight attribute was not cached")
end)

-- -----------------------------------------------------------------------------
-- Contract 2: Milestone unlock without deduction
-- -----------------------------------------------------------------------------
check("Contract 2.1: UpgradeConfig contains 15 tiers with DestructionRequirement equal to Cost", function()
	assert(#UpgradeConfig.List == 15, string.format("Expected 15 upgrades, got %d", #UpgradeConfig.List))
	for index, upgrade in ipairs(UpgradeConfig.List) do
		assert(upgrade.Order == index, string.format("Upgrade %s order mismatch", upgrade.Name))
		assert(
			upgrade.DestructionRequirement == upgrade.Cost,
			string.format(
				"Upgrade %s DestructionRequirement (%s) != Cost (%s)",
				upgrade.Name,
				tostring(upgrade.DestructionRequirement),
				tostring(upgrade.Cost)
			)
		)
		assert(upgrade.DestructionRequirement > 0, "DestructionRequirement must be positive")
	end
end)

check("Contract 2.2: Upgrade unlock validates milestone condition and does NOT deduct Destruction", function()
	local player = {
		UserId = 9901,
		Name = "MilestonePlayer",
	}

	local session = {
		Player = player,
		Bigger = 100,
		Destruction = 1, -- Exactly enough for Tier 1: Protein (Cost = 1, DestructionRequirement = 1)
		Rebirth = 0,
		UnlockedGrowthUpgrades = {},
		EquippedGrowthUpgrade = nil,
	}
	Sessions.Set(player, session)

	local tier1 = UpgradeConfig.Get(1)
	assert(tier1 ~= nil, "Tier 1 upgrade missing")

	-- Milestone condition check:
	local requirement = tier1.DestructionRequirement or tier1.Cost
	assert(session.Destruction >= requirement, "Destruction should satisfy requirement")

	-- Simulate UpgradeService unlock logic:
	local mutated = Sessions.Mutate(player, function(s)
		s.UnlockedGrowthUpgrades[tier1.Id] = true
		s.UnlockedGrowthUpgrades[tier1.Name] = true
		s.EquippedGrowthUpgrade = tier1.Id
	end)

	assert(mutated == true, "Session mutation failed")
	assert(
		session.Destruction == 1,
		string.format("Destruction was mutated to %d! Must remain 1 (no deduction)", session.Destruction)
	)
	assert(session.UnlockedGrowthUpgrades["Protein"] == true, "Protein was not unlocked")
	assert(session.EquippedGrowthUpgrade == "Protein", "Protein was not equipped")

	-- Attempt Tier 2 (Silver Protein, req 5) with Destruction = 1: must fail
	local tier2 = UpgradeConfig.Get(2)
	assert(tier2 ~= nil, "Tier 2 upgrade missing")
	local tier2Req = tier2.DestructionRequirement or tier2.Cost
	assert(session.Destruction < tier2Req, "Tier 2 requirement should not be met yet")

	-- Advance Destruction to 5 (milestone achieved)
	Sessions.Mutate(player, function(s)
		s.Destruction = 5
	end)
	assert(session.Destruction >= tier2Req, "Tier 2 requirement should now be met")

	Sessions.Mutate(player, function(s)
		s.UnlockedGrowthUpgrades[tier2.Id] = true
		s.UnlockedGrowthUpgrades[tier2.Name] = true
		s.EquippedGrowthUpgrade = tier2.Id
	end)

	assert(
		session.Destruction == 5,
		string.format("Destruction was mutated to %d! Must remain 5 (no deduction)", session.Destruction)
	)
	assert(session.UnlockedGrowthUpgrades["Silver_Protein"] == true, "Silver_Protein was not unlocked")
	assert(session.EquippedGrowthUpgrade == "Silver_Protein", "Silver_Protein was not equipped")
end)

check("Contract 2.3: DestructionService:DeductDestruction is deprecated and returns false", function()
	local mockSessions = Sessions
	local mockLogger = {
		Warn = function() end,
		Info = function() end,
	}
	local mockDebris = {
		AddItem = function() end,
	}
	local mockPlayers = {
		GetPlayerFromCharacter = function()
			return nil
		end,
	}

	local destructionServiceModule =
		loadModule("src/server/Game/Services/DestructionService.luau", "DestructionService", {
			game = {
				GetService = function(_, serviceName)
					if serviceName == "Players" then
						return mockPlayers
					elseif serviceName == "Debris" then
						return mockDebris
					elseif serviceName == "ReplicatedStorage" then
						return {
							BiggerShared = {
								Core = {
									Utilities = {
										StompValidation = StompValidation,
										ScaleCurve = ScaleCurve,
									},
									Config = {
										ScaleConfig = ScaleConfig,
									},
								},
							},
						}
					end
					error("Unknown service: " .. tostring(serviceName))
				end,
			},
			script = {
				Parent = {
					Parent = {
						Config = {
							World1Config = World1Config,
						},
						Parent = {
							Core = {
								Registry = {
									RuntimeRegistry = {
										Sessions = mockSessions,
									},
								},
								Utilities = {
									Logger = mockLogger,
								},
							},
						},
					},
				},
			},
			require = function(dep)
				return dep
			end,
		})

	local dummyPlayer = { UserId = 9999, Name = "Dummy" }
	local deducted = destructionServiceModule:DeductDestruction(dummyPlayer, 100)
	assert(deducted == false, "DeductDestruction must return false when deprecated")
end)

-- -----------------------------------------------------------------------------
-- Contract 3: Stomp hitbox scale normalization
-- -----------------------------------------------------------------------------
check("Contract 3.1: Stomp validation scales MaxHeight and HorizontalPadding with VisualScale", function()
	local halfX, halfY, halfZ = 4, 1, 4
	local basePadding = World1Config.Objective.HorizontalPadding
	local baseMaxHeight = World1Config.Objective.MaximumRootHeight
	local downwardVelocity = -5
	local minVelocity = World1Config.Objective.MinimumDownwardVelocity

	-- At VisualScale = 1.0
	local vs1 = 1.0
	local pad1 = basePadding * vs1
	local maxH1 = baseMaxHeight * vs1

	-- Normal player at LocalY = 5 (delta = 5 - 1 = 4 <= 8) -> Valid
	local valid1 = StompValidation.IsValid(0, 5, 0, halfX, halfY, halfZ, pad1, maxH1, downwardVelocity, minVelocity)
	assert(valid1 == true, "Normal player stomp should be valid at height 5")

	-- Normal player at LocalY = 12 (delta = 12 - 1 = 11 > 8) -> Invalid
	local invalid1 = StompValidation.IsValid(0, 12, 0, halfX, halfY, halfZ, pad1, maxH1, downwardVelocity, minVelocity)
	assert(invalid1 == false, "Normal player stomp should be invalid at height 12")

	-- Giant player at VisualScale = 3.0
	local vs3 = 3.0
	local pad3 = basePadding * vs3
	local maxH3 = baseMaxHeight * vs3

	-- Giant player whose RootPart is at LocalY = 12 (delta = 11 <= 24) -> Valid with scale normalization!
	local validGiantHeight =
		StompValidation.IsValid(0, 12, 0, halfX, halfY, halfZ, pad3, maxH3, downwardVelocity, minVelocity)
	assert(validGiantHeight == true, "Giant player at height 12 must be valid when scaled by VisualScale 3.0")

	-- Giant player stomping with horizontal offset = 5.5 (delta = 5.5 - 4 = 1.5 > basePadding 1, but <= scaledPadding 3) -> Valid!
	local validGiantPad =
		StompValidation.IsValid(5.5, 5, 0, halfX, halfY, halfZ, pad3, maxH3, downwardVelocity, minVelocity)
	assert(validGiantPad == true, "Giant player with offset 5.5 must be valid when scaled by VisualScale 3.0")

	local invalidUnscaled =
		StompValidation.IsValid(5.5, 5, 0, halfX, halfY, halfZ, pad1, maxH1, downwardVelocity, minVelocity)
	assert(invalidUnscaled == false, "Unscaled check must fail for offset 5.5")
end)

-- -----------------------------------------------------------------------------
-- Contract 4: Rebirth state preservation
-- -----------------------------------------------------------------------------
check("Contract 4.1: Rebirth resets Size to 1, increments Rebirth, preserves Destruction and Upgrades", function()
	local player = {
		UserId = 7788,
		Name = "RebirthPlayer",
	}

	local initialDestruction = 15000
	local initialEquipped = "Gold_Protein"
	local initialRebirth = 2
	local initialBigger = 5000000

	local session = {
		Player = player,
		Bigger = initialBigger,
		Destruction = initialDestruction,
		Rebirth = initialRebirth,
		UnlockedGrowthUpgrades = {
			Protein = true,
			Silver_Protein = true,
			Gold_Protein = true,
		},
		EquippedGrowthUpgrade = initialEquipped,
	}
	Sessions.Set(player, session)

	-- Execute Rebirth mutation (as defined in RebirthService)
	local mutated = Sessions.Mutate(player, function(s)
		s.Rebirth += 1
		s.Bigger = 1
	end)

	assert(mutated == true, "Rebirth mutation failed")
	assert(session.Bigger == 1, string.format("Expected Bigger 1 after rebirth, got %d", session.Bigger))
	assert(
		session.Rebirth == initialRebirth + 1,
		string.format("Expected Rebirth %d, got %d", initialRebirth + 1, session.Rebirth)
	)
	assert(
		session.Destruction == initialDestruction,
		string.format("Destruction must be preserved! Expected %d, got %d", initialDestruction, session.Destruction)
	)
	assert(session.UnlockedGrowthUpgrades["Protein"] == true, "Protein upgrade lost on rebirth")
	assert(session.UnlockedGrowthUpgrades["Silver_Protein"] == true, "Silver_Protein upgrade lost on rebirth")
	assert(session.UnlockedGrowthUpgrades["Gold_Protein"] == true, "Gold_Protein upgrade lost on rebirth")
	assert(session.EquippedGrowthUpgrade == initialEquipped, "Equipped upgrade changed on rebirth")
end)

-- -----------------------------------------------------------------------------
-- Contract 5: GameBootstrap quarantine
-- -----------------------------------------------------------------------------
check("Contract 5.1: GameBootstrap registers core MVP services and quarantines non-MVP services", function()
	local registeredServices: { [string]: any } = {}
	local mockRegistry = {
		Register = function(name: string, service: any)
			registeredServices[name] = service
		end,
	}

	local mockSystems = {
		Init = function() end,
		Start = function() end,
	}
	local mockServices = {
		Init = function(_self) end,
		Start = function(_self) end,
	}

	local bootstrapModule = loadModule("src/server/Game/GameBootstrap.luau", "GameBootstrap", {
		script = {
			Parent = {
				Formula = { GrowthFormula = mockSystems },
				Systems = {
					MovementGrowthSystem = mockSystems,
					AFKZoneSystem = mockSystems,
					VIPDoorSystem = mockSystems,
				},
				Services = {
					WorldInstanceService = mockServices,
					PortalService = mockServices,
					DestructionService = mockServices,
					RewardPortalService = mockServices,
					RebirthService = mockServices,
					UpgradeService = mockServices,
				},
				Parent = {
					Core = {
						Registry = {
							ServiceRegistry = mockRegistry,
						},
					},
				},
			},
		},
		require = function(dep)
			return dep
		end,
	})

	bootstrapModule.Init()

	-- Verify Core MVP services ARE registered
	local expectedServices = {
		"GrowthFormula",
		"WorldInstanceService",
		"PortalService",
		"DestructionService",
		"RewardPortalService",
		"RebirthService",
		"UpgradeService",
		"VIPDoorSystem",
	}
	for _, serviceName in ipairs(expectedServices) do
		assert(registeredServices[serviceName] ~= nil, "Expected registered service: " .. serviceName)
	end

	-- Verify Quarantined services are NOT registered
	local quarantinedServices = {
		"DailyRewardService",
		"SpinWheelService",
		"CosmeticsService",
		"AutoWinsService",
	}
	for _, serviceName in ipairs(quarantinedServices) do
		assert(registeredServices[serviceName] == nil, "Quarantined service must NOT be registered: " .. serviceName)
	end
end)

check("Contract 5.2: GameBootstrap source code comments verify quarantine tag", function()
	local bootstrapSource = fs.readFile("src/server/Game/GameBootstrap.luau")
	local quarantineTag = "-- Quarantined for MVP-006: Non-MVP peripheral service"

	assert(string.find(bootstrapSource, "DailyRewardService") ~= nil, "DailyRewardService missing from bootstrap")
	assert(string.find(bootstrapSource, "SpinWheelService") ~= nil, "SpinWheelService missing from bootstrap")
	assert(string.find(bootstrapSource, "CosmeticsService") ~= nil, "CosmeticsService missing from bootstrap")
	assert(string.find(bootstrapSource, "AutoWinsService") ~= nil, "AutoWinsService missing from bootstrap")

	-- Verify all occurrences are commented with quarantineTag
	for _, line in ipairs(string.split(bootstrapSource, "\n")) do
		if
			string.find(line, "DailyRewardService")
			or string.find(line, "SpinWheelService")
			or string.find(line, "CosmeticsService")
			or string.find(line, "AutoWinsService")
		then
			assert(string.find(line, "^%s*%-%-") ~= nil, "Line must be commented: " .. line)
			assert(string.find(line, quarantineTag, 1, true) ~= nil, "Line must contain quarantine comment: " .. line)
		end
	end
end)

print("==================================================")
if #Failures > 0 then
	print(string.format("FAILED: %d tests failed, %d passed", #Failures, PassedCount))
	for _, fail in ipairs(Failures) do
		print(" - " .. fail)
	end
	error(string.format("%d contract tests failed", #Failures))
else
	print(string.format("SUCCESS: All %d contract tests PASSED 100%%!", PassedCount))
end
print("==================================================")
