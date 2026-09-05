--!strict
-- BiggerClientMain.client.luau
-- Authoritative client entry point. Boots and starts all client controllers safely.

local ControllersFolder = script.Parent:WaitForChild("controllers")

local ControllerNames = {
	"CharacterScaleController",
	"ResponsiveController",
	"GuiController",
	"RebirthController",
	"ObjectiveController",
	"MapSelectorController",
	"RewardPopupController",
	"UpgradeShopController",
	"VIPDoorController",
	"EquipmentController",
	"CameraShakeController",
	"SoundController",
	"FloatingFeedbackController",
	"VFXController",
	"AuraController",
	-- Quarantined peripheral controllers (matching GameBootstrap quarantine on server):
	-- "AutoWinsController",
	-- "DailyRewardController",
	-- "SpinWheelController",
	-- "CosmeticsController",
}

local LoadedControllers: { [string]: any } = {}

-- 1. Require and Init Phase
for _, name in ipairs(ControllerNames) do
	local module = ControllersFolder:FindFirstChild(name)
	if module and module:IsA("ModuleScript") then
		local success, controller = pcall(function()
			return require(module) :: any
		end)
		if success and type(controller) == "table" then
			LoadedControllers[name] = controller
			if type(controller.Init) == "function" then
				local initOk, initErr = pcall(function()
					controller.Init()
				end)
				if not initOk then
					warn(string.format("[BiggerClient] Error initializing controller %s: %s", name, tostring(initErr)))
				end
			end
		else
			warn(string.format("[BiggerClient] Failed to require controller %s: %s", name, tostring(controller)))
		end
	end
end

-- 2. Start Phase
for _, name in ipairs(ControllerNames) do
	local controller = LoadedControllers[name]
	if controller and type(controller.Start) == "function" then
		local startOk, startErr = pcall(function()
			controller.Start()
		end)
		if not startOk then
			warn(string.format("[BiggerClient] Error starting controller %s: %s", name, tostring(startErr)))
		end
	end
end

print("[BiggerClient] Client boot completed successfully! Total controllers active: " .. tostring(#ControllerNames))
