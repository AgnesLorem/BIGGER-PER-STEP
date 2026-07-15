--!strict
--// Raw Requirings \\--
local Players = game:GetService("Players")

--// Requirings \\--
local MovementConfig = require(script.Parent.Parent.Config.MovementConfig)
local Sessions = require(script.Parent.Parent.Parent.Core.Registry.RuntimeRegistry.Sessions)
local MovementValidation = require(game:GetService("ReplicatedStorage").BiggerShared.Core.Utilities.MovementValidation)
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

--// Types \\--
type MovementState = {
	LastPosition: Vector3,
	LastSampleTime: number,
	LastRewardTime: number,
	AccumulatedDistance: number,
}

--// Variables \\--
local MovementStates: { [Player]: MovementState } = {}

--// Helpers \\--
local function ProcessMovement()
	local Success, GrowthService = pcall(function()
		return ServiceRegistry.Get("GrowthService")
	end)
	if not Success or not GrowthService then
		return
	end

	local CurrentTime = time()
	for _, Player in Players:GetPlayers() do
		local Session = Sessions.Get(Player)
		local Character = Player.Character
		local RootPart = Character and Character:FindFirstChild("HumanoidRootPart")
		if not Session or Session.State ~= "InLobby" or not RootPart or not RootPart:IsA("BasePart") then
			MovementStates[Player] = nil
			continue
		end

		local CurrentPosition = RootPart.Position
		local State = MovementStates[Player]
		if not State then
			MovementStates[Player] = {
				LastPosition = CurrentPosition,
				LastSampleTime = CurrentTime,
				LastRewardTime = CurrentTime,
				AccumulatedDistance = 0,
			}
			continue
		end

		local DeltaSeconds = CurrentTime - State.LastSampleTime
		local Delta = CurrentPosition - State.LastPosition
		local HorizontalDistance = Vector3.new(Delta.X, 0, Delta.Z).Magnitude
		State.LastPosition = CurrentPosition
		State.LastSampleTime = CurrentTime

		if
			DeltaSeconds > MovementConfig.MaximumSampleGap
			or not MovementValidation.IsPlausible(
				HorizontalDistance,
				DeltaSeconds,
				MovementConfig.MaximumRewardSpeed,
				MovementConfig.DistanceSlack
			)
		then
			State.AccumulatedDistance = 0
			continue
		end

		State.AccumulatedDistance += HorizontalDistance
		if State.AccumulatedDistance < MovementConfig.DistanceThreshold then
			continue
		end
		if CurrentTime - State.LastRewardTime < MovementConfig.MinimumRewardInterval then
			continue
		end

		State.AccumulatedDistance = 0
		State.LastRewardTime = CurrentTime
		GrowthService:AddBigger(Player, {
			BaseGain = MovementConfig.BaseGain,
			Source = GrowthSource.Movement,
		})
	end
end

local function CleanupPlayer(Player: Player)
	MovementStates[Player] = nil
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
