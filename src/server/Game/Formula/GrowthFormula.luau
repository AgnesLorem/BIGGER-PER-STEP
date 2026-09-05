--!strict
--// Raw Requirings \\--

local ReplicatedStorageFound, ReplicatedStorage = pcall(function()
	return game:GetService("ReplicatedStorage")
end)

--// Requirings \\--
local UpgradesConfig: any = nil
local RebirthFormula: any = nil
local AuraFormula: any = nil

if ReplicatedStorageFound and ReplicatedStorage then
	pcall(function()
		local BiggerShared = if (ReplicatedStorage :: any).WaitForChild
			then (ReplicatedStorage :: any):WaitForChild("BiggerShared", 1)
			else (ReplicatedStorage :: any).BiggerShared
		if BiggerShared then
			local Game = if BiggerShared.WaitForChild then BiggerShared:WaitForChild("Game", 1) else BiggerShared.Game
			if Game then
				local Config = if Game.WaitForChild then Game:WaitForChild("Config", 1) else Game.Config
				if Config then
					local Upgrades = if Config.WaitForChild
						then Config:WaitForChild("UpgradesConfig", 1)
						else Config.UpgradesConfig
					if Upgrades then
						UpgradesConfig = require(Upgrades)
					end
				end
				local Progression = if Game.WaitForChild then Game:WaitForChild("Progression", 1) else Game.Progression
				if Progression then
					local RebirthMod = if Progression.WaitForChild
						then Progression:WaitForChild("RebirthFormula", 1)
						else Progression.RebirthFormula
					if RebirthMod then
						RebirthFormula = require(RebirthMod)
					end
					local AuraMod = if Progression.WaitForChild
						then Progression:WaitForChild("AuraFormula", 1)
						else Progression.AuraFormula
					if AuraMod then
						AuraFormula = require(AuraMod)
					end
				end
			end
		end
	end)
end

-- Fallback requires via script hierarchy (for Lune / unit test environments)
if not UpgradesConfig then
	pcall(function()
		UpgradesConfig = require(script.Parent.Parent.Parent.Parent.shared.Game.Config.UpgradesConfig)
	end)
end
if not RebirthFormula then
	pcall(function()
		RebirthFormula = require(script.Parent.Parent.Parent.Parent.shared.Game.Progression.RebirthFormula)
	end)
end
if not AuraFormula then
	pcall(function()
		AuraFormula = require(script.Parent.Parent.Parent.Parent.shared.Game.Progression.AuraFormula)
	end)
end

local Sessions = require(script.Parent.Parent.Parent.Core.Registry.RuntimeRegistry.Sessions)

local UpgradeConfig: any = nil
pcall(function()
	UpgradeConfig = require(script.Parent.Parent.Config.UpgradeConfig)
end)

--// Service \\--
local GrowthFormula = {}

function GrowthFormula.GetMultiplier(Session: Sessions.Session): number
	local EquipmentMult = if UpgradesConfig and UpgradesConfig.GetMultiplier
		then UpgradesConfig.GetMultiplier(Session.EquippedGrowthUpgrade)
		else 1.0
	local RebirthMult = if RebirthFormula and RebirthFormula.GetMultiplier
		then RebirthFormula.GetMultiplier(Session.Rebirth or 0)
		else (if Session.Rebirth and Session.Rebirth > 0 then Session.Rebirth + 1 else 1)
	local AuraMult = if AuraFormula and AuraFormula.GetMultiplier
		then AuraFormula.GetMultiplier(Session.UnlockedAuras or {})
		else 1.0

	local Multiplier = EquipmentMult * RebirthMult * AuraMult
	if Session.HasDoubleMultiplier then
		Multiplier *= 2
	end
	if Session.HasVip then
		Multiplier *= 2
	end

	return Multiplier
end

function GrowthFormula.Calculate(Session: Sessions.Session, Context: any): number
	local Multiplier = GrowthFormula.GetMultiplier(Session)
	local BaseGain = Context.BaseGain
	local AdditiveGrowth = 0
	if not UpgradesConfig and Session.EquippedGrowthUpgrade and UpgradeConfig and UpgradeConfig.Get then
		local Upgrade = UpgradeConfig.Get(Session.EquippedGrowthUpgrade)
		if Upgrade and Upgrade.AdditiveGrowth then
			AdditiveGrowth = Upgrade.AdditiveGrowth
		end
	end
	local ZoneMultiplier = Context.ZoneMultiplier or 1
	local FinalGain = (BaseGain + AdditiveGrowth) * ZoneMultiplier * Multiplier

	return FinalGain
end

return table.freeze(GrowthFormula)
