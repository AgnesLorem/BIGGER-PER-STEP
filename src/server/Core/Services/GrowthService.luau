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

--// Variables \\--
local MAX_SAFE_INTEGER = 9007199254740991

--// Helpers \\--
local function NormalizeBigger(Value: number): number?
	if Value ~= Value or Value <= -math.huge or Value >= math.huge then
		return nil
	end
	if Value < 1 or Value > MAX_SAFE_INTEGER then
		return nil
	end
	return math.floor(Value)
end

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

function GrowthService:SetBigger(Player: Player, Value: number): boolean
	local NormalizedValue = NormalizeBigger(Value)
	if not NormalizedValue then
		return false
	end
	if not Sessions.Mutate(Player, function(Session)
		Session.Bigger = NormalizedValue
	end) then
		return false
	end

	Player:SetAttribute("Bigger", NormalizedValue)

	local Level = math.floor((NormalizedValue / 236) ^ 0.25) + 1
	Player:SetAttribute("Level", Level)

	local Leaderstats = Player:FindFirstChild("leaderstats")
	local BiggerStat = Leaderstats and Leaderstats:FindFirstChild("Bigger")
	if BiggerStat and BiggerStat:IsA("IntValue") then
		BiggerStat.Value = NormalizedValue
	end

	EventBus.Publish("BiggerChanged", Player, NormalizedValue)
	return true
end

function GrowthService:AddBiggerAbsolute(Player: Player, Amount: number): boolean
	local Session = Sessions.Get(Player)
	if not Session then
		return false
	end
	local NewValue = Session.Bigger + Amount
	local Success, Applied = pcall(self.SetBigger, self, Player, NewValue)
	if Success then
		return Applied == true
	end
	local CurrentSession = Sessions.Get(Player)
	return CurrentSession ~= nil and CurrentSession.Bigger == math.floor(NewValue)
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

	local TotalGain = Gain + (Session.GrowthRemainder or 0)
	local WholeGain = math.floor(TotalGain)
	local NewValue = Session.Bigger + WholeGain
	if self:SetBigger(Player, NewValue) then
		Session.GrowthRemainder = TotalGain - WholeGain
	end
end

return GrowthService
