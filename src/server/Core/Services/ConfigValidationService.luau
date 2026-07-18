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

local ConfigValidationService = {}
local MaximumSafeInteger = 9007199254740991
local SupportedDeveloperProductRewards = table.freeze({
	[RewardType.Bigger] = true,
	[RewardType.DoubleMultiplier] = true,
	[RewardType.Vip] = true,
})

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
		if typeof(rewards) ~= "table" or #rewards ~= 1 then
			error(
				"ConfigValidation: ProductKey "
					.. productKey
					.. " must contain exactly one reward. Got: "
					.. tostring(if typeof(rewards) == "table" then #rewards else nil)
			)
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
			if not SupportedDeveloperProductRewards[rType] then
				error("ConfigValidation: Unsupported Developer Product RewardType: " .. rType)
			end

			if rType == RewardType.Bigger then
				local amount = reward.Amount
				if
					type(amount) ~= "number"
					or amount ~= amount
					or amount <= 0
					or amount >= math.huge
					or amount % 1 ~= 0
					or amount > MaximumSafeInteger
				then
					error(
						"ConfigValidation: Reward index "
							.. i
							.. " for ProductKey "
							.. productKey
							.. " must have a positive safe integer Amount. Got: "
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

	Logger.Info("ConfigValidation", "All configuration checks completed successfully. Config is consistent!")
end

function ConfigValidationService:Start() end

return ConfigValidationService
