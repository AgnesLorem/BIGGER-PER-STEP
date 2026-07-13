--!strict
--// Raw Requirings \\--
local Players = game:GetService("Players")

--// Requirings \\--
local MovementConfig = require(script.Parent.Parent.Config.MovementConfig)
local GrowthSource = require(
	game:GetService("ReplicatedStorage")
		:WaitForChild("BiggerShared")
		:WaitForChild("Core")
		:WaitForChild("Enums")
		:WaitForChild("GrowthSource")
)
local Scheduler = require(script.Parent.Parent.Parent.Core.Scheduler.Scheduler)
local ServiceRegistry = require(script.Parent.Parent.Parent.Core.Registry.ServiceRegistry)
local Logger = require(script.Parent.Parent.Parent.Core.Utilities.Logger)

--// Variables \\--
local LastPositions: { [Player]: Vector3 } = {}
local LastRewardTimes: { [Player]: number } = {}

--// Helpers \\--
local function ProcessMovement()
	local Success, GrowthService = pcall(function()
		return ServiceRegistry.Get("GrowthService")
	end)
	if not Success or not GrowthService then
		return
	end

	for _, Player in Players:GetPlayers() do
		local Character = Player.Character
		local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
		if not RootPart or not RootPart:IsA("BasePart") then
			continue
		end

		local CurrentPosition = RootPart.Position
		local LastPosition = LastPositions[Player]

		if not LastPosition then
			LastPositions[Player] = CurrentPosition
			continue
		end

		local Distance = (CurrentPosition - LastPosition).Magnitude
		if Distance >= MovementConfig.DistanceThreshold then
			local CurrentTime = tick()
			local LastRewardTime = LastRewardTimes[Player] or 0

			if CurrentTime - LastRewardTime >= MovementConfig.MinimumRewardInterval then
				LastRewardTimes[Player] = CurrentTime
				LastPositions[Player] = CurrentPosition
				GrowthService:AddBigger(Player, {
					BaseGain = MovementConfig.BaseGain,
					Source = GrowthSource.Movement,
				})
			end
		end
	end
end

local function CleanupPlayer(Player: Player)
	LastPositions[Player] = nil
	LastRewardTimes[Player] = nil
end

--// Service \\--
local MovementGrowthSystem = {}

function MovementGrowthSystem.Init()
	Players.PlayerRemoving:Connect(CleanupPlayer)
end

function MovementGrowthSystem.Start()
	Scheduler.AddJob({
		Name = "MovementGrowth",
		IntervalSeconds = MovementConfig.TickRate,
		Callback = ProcessMovement,
		Priority = 10,
	})
	Logger.Info("Runtime", "MovementGrowthSystem job added to Scheduler")
end

return MovementGrowthSystem
