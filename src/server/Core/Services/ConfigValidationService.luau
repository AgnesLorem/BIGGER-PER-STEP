--!strict
-- ConfigValidationService.luau
-- Validates configurations at server startup to prevent mismatched or invalid products.

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Logger = require(script.Parent.Parent.Utilities.Logger)

local ShopUIConfig = require(
	ReplicatedStorage:WaitForChild("BiggerShared")
		:WaitForChild("Core")
		:WaitForChild("Config")
		:WaitForChild("ShopUIConfig")
)
local DeveloperProductConfig = require(script.Parent.Parent.Config.DeveloperProductConfig)
local RewardType = require(
	ReplicatedStorage:WaitForChild("BiggerShared"):WaitForChild("Core"):WaitForChild("Enums"):WaitForChild("RewardType")
)
local BalanceConfig = require(
	ReplicatedStorage:WaitForChild("BiggerShared"):WaitForChild("Game"):WaitForChild("Progression"):WaitForChild("BalanceConfig")
)
local LevelFormula = require(
	ReplicatedStorage:WaitForChild("BiggerShared"):WaitForChild("Game"):WaitForChild("Progression"):WaitForChild("LevelFormula")
)

local ConfigValidationService = {}

function ConfigValidationService:Init()
	Logger.Info("ConfigValidation", "Starting configuration consistency checks...")

	local shopKeys = {}
	local serverKeys = {}

	local shopProductIds = {}
	local serverProductIds = {}
	local serverAnalyticsKeys = {}

	-- 1. Validate ShopUIConfig
	for productKey, uiConfig in pairs(ShopUIConfig) do
		if shopKeys[productKey] then
			error("ConfigValidation: Duplicate ProductKey in ShopUIConfig: " .. productKey)
		end
		shopKeys[productKey] = true

		local productId = uiConfig.ProductId
		if not productId or typeof(productId) ~= "number" or productId <= 0 then
			error(
				"ConfigValidation: Invalid ProductId for key "
					.. productKey
					.. " in ShopUIConfig: "
					.. tostring(productId)
			)
		end

		if shopProductIds[productId] then
			error(
				"ConfigValidation: Duplicate ProductId in ShopUIConfig: "
					.. productId
					.. " (keys: "
					.. shopProductIds[productId]
					.. ", "
					.. productKey
					.. ")"
			)
		end
		shopProductIds[productId] = productKey
	end

	-- 2. Validate DeveloperProductConfig
	for productKey, serverConfig in pairs(DeveloperProductConfig) do
		if serverKeys[productKey] then
			error("ConfigValidation: Duplicate ProductKey in DeveloperProductConfig: " .. productKey)
		end
		serverKeys[productKey] = true

		local productId = serverConfig.ProductId
		if not productId or typeof(productId) ~= "number" or productId <= 0 then
			error(
				"ConfigValidation: Invalid ProductId for key "
					.. productKey
					.. " in DeveloperProductConfig: "
					.. tostring(productId)
			)
		end

		if serverProductIds[productId] then
			error(
				"ConfigValidation: Duplicate ProductId in DeveloperProductConfig: "
					.. productId
					.. " (keys: "
					.. serverProductIds[productId]
					.. ", "
					.. productKey
					.. ")"
			)
		end
		serverProductIds[productId] = productKey

		-- Check AnalyticsKey
		local analyticsKey = serverConfig.AnalyticsKey
		if not analyticsKey or typeof(analyticsKey) ~= "string" or string.len(analyticsKey) == 0 then
			error("ConfigValidation: Missing or empty AnalyticsKey for ProductKey: " .. productKey)
		end

		if serverAnalyticsKeys[analyticsKey] then
			error(
				"ConfigValidation: Duplicate AnalyticsKey: "
					.. analyticsKey
					.. " (keys: "
					.. serverAnalyticsKeys[analyticsKey]
					.. ", "
					.. productKey
					.. ")"
			)
		end
		serverAnalyticsKeys[analyticsKey] = productKey

		-- Check Rewards
		local rewards = serverConfig.Rewards
		if not rewards or typeof(rewards) ~= "table" or #rewards == 0 then
			error("ConfigValidation: Empty or missing Rewards list for ProductKey: " .. productKey)
		end

		for i, reward in ipairs(rewards) do
			local rType = reward.Type
			if not rType or typeof(rType) ~= "string" or not RewardType[rType] then
				error(
					"ConfigValidation: Unknown or missing RewardType: "
						.. tostring(rType)
						.. " in ProductKey: "
						.. productKey
				)
			end

			-- Check specific reward configurations (e.g. Bigger needs Amount)
			if rType == RewardType.Bigger or rType == RewardType.Coins then
				local amount = reward.Amount
				if not amount or typeof(amount) ~= "number" or amount <= 0 then
					error(
						"ConfigValidation: Reward index "
							.. i
							.. " for ProductKey "
							.. productKey
							.. " must have an Amount > 0. Got: "
							.. tostring(amount)
					)
				end
			end
		end
	end

	-- 3. Verify 1-to-1 match between ShopUIConfig and DeveloperProductConfig
	for productKey in pairs(shopKeys) do
		if not serverKeys[productKey] then
			error(
				"ConfigValidation: Mismatched configuration. ProductKey '"
					.. productKey
					.. "' exists in ShopUIConfig but is missing in DeveloperProductConfig!"
			)
		end

		-- Verify ProductIds match
		if ShopUIConfig[productKey].ProductId ~= DeveloperProductConfig[productKey].ProductId then
			error(
				"ConfigValidation: Mismatched ProductIds for ProductKey '"
					.. productKey
					.. "'. ShopUIConfig has "
					.. ShopUIConfig[productKey].ProductId
					.. " while DeveloperProductConfig has "
					.. DeveloperProductConfig[productKey].ProductId
			)
		end
	end

	for productKey in pairs(serverKeys) do
		if not shopKeys[productKey] then
			error(
				"ConfigValidation: Mismatched configuration. ProductKey '"
					.. productKey
					.. "' exists in DeveloperProductConfig but is missing in ShopUIConfig!"
			)
		end
	end

	Logger.Info("ConfigValidation", "Shop/Product configuration checks passed.")

	-- 4. Validate BalanceConfig progression stages
	local stages = BalanceConfig.Stages
	if not stages or #stages == 0 then
		error("ConfigValidation: BalanceConfig.Stages is empty or missing")
	end

	for i = 1, #stages do
		local stage = stages[i]
		if stage.MinLevel > stage.MaxLevel then
			error("ConfigValidation: Stage '" .. stage.Name .. "' has MinLevel > MaxLevel")
		end
		if i > 1 then
			local prevStage = stages[i - 1]
			if stage.MinLevel ~= prevStage.MaxLevel + 1 then
				error("ConfigValidation: Level gap between stages '" .. prevStage.Name .. "' and '" .. stage.Name .. "'")
			end
		end
	end

	-- Verify requirements are monotonically increasing for first 50 levels
	local prevReq = -1
	for level = 1, 50 do
		local req = LevelFormula.GetRequirement(level)
		if req < prevReq then
			error("ConfigValidation: Non-monotonic requirement at Level " .. level .. ": " .. req .. " < " .. prevReq)
		end
		prevReq = req
	end

	-- Verify LevelFormula round-trip sanity
	local testLevel = LevelFormula.GetLevel(0)
	if testLevel ~= 1 then
		error("ConfigValidation: LevelFormula.GetLevel(0) should be 1, got " .. testLevel)
	end

	Logger.Info("ConfigValidation", "BalanceConfig and LevelFormula validation passed.")
	Logger.Info("ConfigValidation", "All configuration checks completed successfully. Config is consistent!")
end

function ConfigValidationService:Start() end

return ConfigValidationService
