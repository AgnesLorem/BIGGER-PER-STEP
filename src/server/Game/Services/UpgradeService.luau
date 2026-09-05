--!strict
-- UpgradeConfig.luau / UpgradeService.luau
-- Authoritative server service managing Growth Upgrades purchasing, equipping, and client synchronization.

--// Raw Requirings \\--
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Requirings \\--
local Sessions = require(script.Parent.Parent.Parent.Core.Registry.RuntimeRegistry.Sessions)
local Logger = require(script.Parent.Parent.Parent.Core.Utilities.Logger)
local EventBus = require(script.Parent.Parent.Parent.Core.Events.EventBus)
local UpgradeConfig = require(script.Parent.Parent.Config.UpgradeConfig)

--// Types \\--
type Session = Sessions.Session
type Upgrade = UpgradeConfig.Upgrade

--// Variables \\--
local RequestBuyUpgradeRemote: RemoteEvent
local RequestEquipUpgradeRemote: RemoteEvent
local UpdateUpgradeStatusRemote: RemoteEvent

--// Helpers \\--
local function EnsureRemote(Name: string): RemoteEvent
	local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if not RemotesFolder then
		RemotesFolder = Instance.new("Folder")
		RemotesFolder.Name = "Remotes"
		RemotesFolder.Parent = ReplicatedStorage
	end

	local Existing = RemotesFolder:FindFirstChild(Name)
	if Existing and Existing:IsA("RemoteEvent") then
		return Existing
	end

	local Remote = Instance.new("RemoteEvent")
	Remote.Name = Name
	Remote.Parent = RemotesFolder
	return Remote
end

--// Service \\--
local UpgradeService = {}

function UpgradeService:Init()
	RequestBuyUpgradeRemote = EnsureRemote("RequestBuyUpgrade")
	RequestEquipUpgradeRemote = EnsureRemote("RequestEquipUpgrade")
	UpdateUpgradeStatusRemote = EnsureRemote("UpdateUpgradeStatus")

	RequestBuyUpgradeRemote.OnServerEvent:Connect(function(Client: Player, UpgradeName: any)
		self:RequestBuyUpgrade(Client, UpgradeName)
	end)

	RequestEquipUpgradeRemote.OnServerEvent:Connect(function(Client: Player, UpgradeName: any)
		self:RequestEquipUpgrade(Client, UpgradeName)
	end)

	EventBus.Subscribe("PlayerSessionCreated", function(Player: Player)
		task.spawn(function()
			task.wait()
			self:PushUpgradeStatus(Player)
		end)
	end)

	Logger.Info("Upgrade", "UpgradeService initialized")
end

function UpgradeService:Start()
	for _, Player in Players:GetPlayers() do
		if Sessions.Get(Player) then
			task.spawn(function()
				self:PushUpgradeStatus(Player)
			end)
		end
	end
end

function UpgradeService:GetUpgradeStatus(Player: Player)
	local Session = Sessions.Get(Player)
	if not Session then
		return nil
	end

	local Equipped = Session.EquippedGrowthUpgrade
	local Destruction = Session.Destruction or 0
	local StatusList = {}

	for _, Upgrade in UpgradeConfig.List do
		local isUnlocked = (Session.UnlockedGrowthUpgrades[Upgrade.Name] == true)
			or (Session.UnlockedGrowthUpgrades[Upgrade.Id] == true)
		local isEquipped = (Equipped == Upgrade.Name or Equipped == Upgrade.Id)

		local Prev = UpgradeConfig.GetPrevious(Upgrade)
		local prevUnlocked = (Prev == nil)
			or (Session.UnlockedGrowthUpgrades[Prev.Name] == true or Session.UnlockedGrowthUpgrades[Prev.Id] == true)

		local requirement = Upgrade.DestructionRequirement or Upgrade.Cost
		local canBuy = (not isUnlocked) and prevUnlocked and (Destruction >= requirement)

		table.insert(StatusList, {
			Order = Upgrade.Order,
			Name = Upgrade.Name,
			Id = Upgrade.Id,
			Cost = Upgrade.Cost,
			DestructionRequirement = requirement,
			AdditiveGrowth = Upgrade.AdditiveGrowth,
			IsUnlocked = isUnlocked,
			IsEquipped = isEquipped,
			CanBuy = canBuy,
		})
	end

	return {
		EquippedUpgrade = Equipped,
		UnlockedUpgrades = Session.UnlockedGrowthUpgrades,
		Destruction = Destruction,
		List = StatusList,
	}
end

function UpgradeService:PushUpgradeStatus(Player: Player)
	if not UpdateUpgradeStatusRemote then
		return
	end
	local Status = self:GetUpgradeStatus(Player)
	if Status then
		pcall(function()
			UpdateUpgradeStatusRemote:FireClient(Player, Status)
		end)
	end
end

function UpgradeService:RequestBuyUpgrade(Player: Player, UpgradeName: any): boolean
	if type(UpgradeName) ~= "string" and type(UpgradeName) ~= "number" and type(UpgradeName) ~= "table" then
		return false
	end

	local Session = Sessions.Get(Player)
	if not Session or Session.ProfileMutationsFrozen then
		return false
	end

	local Upgrade = UpgradeConfig.Get(UpgradeName)
	if not Upgrade then
		return false
	end

	-- Check if already unlocked
	if Session.UnlockedGrowthUpgrades[Upgrade.Name] == true or Session.UnlockedGrowthUpgrades[Upgrade.Id] == true then
		return false
	end

	-- Check sequential unlock (Order 1 or previous order unlocked)
	local Prev = UpgradeConfig.GetPrevious(Upgrade)
	if Prev ~= nil then
		local prevUnlocked = (Session.UnlockedGrowthUpgrades[Prev.Name] == true)
			or (Session.UnlockedGrowthUpgrades[Prev.Id] == true)
		if not prevUnlocked then
			return false
		end
	end

	-- Check lifetime milestone requirement (Destruction is permanent milestone, not spent or deducted)
	local requirement = Upgrade.DestructionRequirement or Upgrade.Cost
	if (Session.Destruction or 0) < requirement then
		return false
	end

	-- Mutate session
	local Mutated = Sessions.Mutate(Player, function(S)
		S.UnlockedGrowthUpgrades[Upgrade.Id] = true
		if Upgrade.Name ~= Upgrade.Id then
			S.UnlockedGrowthUpgrades[Upgrade.Name] = true
		end
		S.EquippedGrowthUpgrade = Upgrade.Id
	end)

	if not Mutated then
		return false
	end

	EventBus.Publish("UpgradeEquipped", Player, Upgrade.Name)
	self:PushUpgradeStatus(Player)
	Logger.Info("Upgrade", "Player %s bought and equipped upgrade: %s", Player.Name, Upgrade.Name)
	return true
end

function UpgradeService:RequestEquipUpgrade(Player: Player, UpgradeName: any): boolean
	if type(UpgradeName) ~= "string" and type(UpgradeName) ~= "number" and type(UpgradeName) ~= "table" then
		return false
	end

	local Session = Sessions.Get(Player)
	if not Session or Session.ProfileMutationsFrozen then
		return false
	end

	local Upgrade = UpgradeConfig.Get(UpgradeName)
	if not Upgrade then
		return false
	end

	-- Verify ownership
	local isUnlocked = (Session.UnlockedGrowthUpgrades[Upgrade.Name] == true)
		or (Session.UnlockedGrowthUpgrades[Upgrade.Id] == true)
	if not isUnlocked then
		return false
	end

	local Mutated = Sessions.Mutate(Player, function(S)
		S.EquippedGrowthUpgrade = Upgrade.Id
	end)

	if not Mutated then
		return false
	end

	EventBus.Publish("UpgradeEquipped", Player, Upgrade.Name)
	self:PushUpgradeStatus(Player)
	Logger.Info("Upgrade", "Player %s equipped upgrade: %s", Player.Name, Upgrade.Name)
	return true
end

return UpgradeService
