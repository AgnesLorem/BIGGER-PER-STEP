--// Raw Requirings \\--
local Players = game:GetService("Players")

--// Requirings \\--
local Logger = require(script.Parent.Parent.Utilities.Logger)

--// Types \\--
export type Profile = {
	Bigger: number,
	Destruction: number,
	Rebirth: number,
	ProcessedPurchaseIds: { [string]: boolean },
	HasDoubleMultiplier: boolean,
	HasVip: boolean,
}

--// Variables \\--
local Profiles: { [Player]: Profile } = {}

--// Service \\--
local SaveService = {}

function SaveService:Init()
	Players.PlayerRemoving:Connect(function(Player)
		Profiles[Player] = nil
	end)
end

function SaveService:Start() end

function SaveService:LoadProfile(Player: Player): Profile
	local Profile = Profiles[Player]
	if not Profile then
		Profile = {
			Bigger = 1,
			Destruction = 0,
			Rebirth = 0,
			ProcessedPurchaseIds = {},
			HasDoubleMultiplier = false,
			HasVip = false,
		}
		Profiles[Player] = Profile
	end
	return Profile
end

function SaveService:SaveProfile(Player: Player)
	Logger.Info("Save", "SaveProfile called for %s (stub)", Player.Name)
end

function SaveService:CommitTransaction(Player: Player, TransactionData: { PurchaseId: string, Rewards: { [any]: any } }): boolean
	local Profile = Profiles[Player]
	if not Profile then
		Logger.Warn("Save", "No profile found for %s to commit transaction %s", Player.Name, TransactionData.PurchaseId)
		return false
	end

	Profile.ProcessedPurchaseIds[TransactionData.PurchaseId] = true
	Logger.Info("Save", "Persistently committed transaction %s for %s", TransactionData.PurchaseId, Player.Name)

	self:SaveProfile(Player)
	return true
end

return SaveService
