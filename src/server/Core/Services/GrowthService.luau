--!strict
--// Raw Requirings \\--

--// Requirings \\--
local Sessions = require(script.Parent.Parent.Registry.RuntimeRegistry.Sessions)
local Logger = require(script.Parent.Parent.Utilities.Logger)
local EventBus = require(script.Parent.Parent.Events.EventBus)
local ServiceRegistry = require(script.Parent.Parent.Registry.ServiceRegistry)
local GrowthTypes = require(
	game:GetService("ReplicatedStorage")
		:WaitForChild("BiggerShared")
		:WaitForChild("Core")
		:WaitForChild("Types")
		:WaitForChild("GrowthTypes")
)

--// Types \\--
type GrowthContext = GrowthTypes.GrowthContext

--// Service \\--
local GrowthService = {}

function GrowthService:Init()
	-- No-op for initialization
end

function GrowthService:Start()
	-- No-op for start
end

function GrowthService:GetBigger(Player: Player): number
	local Session = Sessions.Get(Player)
	if not Session then
		return 0
	end
	return Session.Bigger
end

function GrowthService:UpdateMultiplierAttribute(Player: Player)
	local Session = Sessions.Get(Player)
	if not Session then
		return
	end

	local Success, GrowthFormula = pcall(function()
		return ServiceRegistry.Get("GrowthFormula")
	end)

	if Success and GrowthFormula then
		local Multiplier = GrowthFormula.GetMultiplier(Session)
		Player:SetAttribute("Multiplier", Multiplier)
	end
end

function GrowthService:SetBigger(Player: Player, Value: number)
	local Session = Sessions.Get(Player)
	if not Session then
		return
	end

	Session.Bigger = Value

	Player:SetAttribute("Bigger", Value)

	local Level = math.floor((Value / 236) ^ 0.25) + 1
	Player:SetAttribute("Level", Level)

	local Leaderstats = Player:FindFirstChild("leaderstats")
	local BiggerStat = Leaderstats and Leaderstats:FindFirstChild("Bigger")
	if BiggerStat and BiggerStat:IsA("IntValue") then
		BiggerStat.Value = Value
	end

	EventBus.Publish("BiggerChanged", Player, Value)
end

function GrowthService:AddBiggerAbsolute(Player: Player, Amount: number)
	local Session = Sessions.Get(Player)
	if not Session then
		return
	end
	local NewValue = Session.Bigger + Amount
	self:SetBigger(Player, NewValue)
end

function GrowthService:AddBigger(Player: Player, Context: GrowthContext)
	local Session = Sessions.Get(Player)
	if not Session then
		return
	end

	-- GrowthFormula is loaded from the Game layer via ServiceRegistry to prevent circular dependencies in Core
	local Success, GrowthFormula = pcall(function()
		return ServiceRegistry.Get("GrowthFormula")
	end)

	if not Success or not GrowthFormula then
		Logger.Warn("Growth", "GrowthFormula not found in ServiceRegistry, cannot add Bigger")
		return
	end

	local Gain = GrowthFormula.Calculate(Session, Context)
	if Gain <= 0 then
		return
	end

	local NewValue = Session.Bigger + Gain
	self:SetBigger(Player, NewValue)
end

return GrowthService
