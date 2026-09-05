--!strict
-- UpgradeShopController.luau
-- Client controller managing 3D pedestals, BillboardGuis, and ProximityPrompts in Workspace.UpgradeShop.

--// Raw Requirings \\--
local Workspace = game:GetService("Workspace")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

--// Types \\--
export type UpgradeStatusEntry = {
	Order: number,
	Name: string,
	Id: string,
	Cost: number,
	AdditiveGrowth: number,
	IsUnlocked: boolean,
	IsEquipped: boolean,
	CanBuy: boolean,
}

export type UpgradeStatusPayload = {
	EquippedUpgrade: string?,
	UnlockedUpgrades: { [string]: boolean },
	Destruction: number,
	List: { UpgradeStatusEntry },
}

--// Variables \\--
local LocalPlayer = Players.LocalPlayer
local RequestBuyUpgradeRemote: RemoteEvent? = nil
local RequestEquipUpgradeRemote: RemoteEvent? = nil
local UpdateUpgradeStatusRemote: RemoteEvent? = nil

local CachedStatus: UpgradeStatusPayload? = nil
local Connections: { RBXScriptConnection } = {}
local PromptConnections: { [ProximityPrompt]: RBXScriptConnection } = {}
local Initialized = false
local Started = false

--// Helpers \\--
local function FormatNumber(Value: number): string
	if Value >= 1000000000 then
		return string.format("%.1fB", Value / 1000000000):gsub("%.0B", "B")
	elseif Value >= 1000000 then
		return string.format("%.1fM", Value / 1000000):gsub("%.0M", "M")
	elseif Value >= 1000 then
		return string.format("%.1fK", Value / 1000):gsub("%.0K", "K")
	end
	return tostring(Value)
end

local function FindStatusEntry(UpgradeKey: string): UpgradeStatusEntry?
	if not CachedStatus or not CachedStatus.List then
		return nil
	end
	for _, entry in CachedStatus.List do
		if entry.Name == UpgradeKey or entry.Id == UpgradeKey or tostring(entry.Order) == UpgradeKey then
			return entry
		end
	end
	return nil
end

local function UpdatePedestal(Pedestal: Instance, Entry: UpgradeStatusEntry)
	-- 1. Update BillboardGui if present
	local Billboard = Pedestal:FindFirstChildWhichIsA("BillboardGui", true)
	if Billboard then
		local NameLabel = Billboard:FindFirstChild("TitleLabel", true)
			or Billboard:FindFirstChild("NameLabel", true)
			or Billboard:FindFirstChild("UpgradeName", true)
		if NameLabel and NameLabel:IsA("TextLabel") then
			NameLabel.Text = Entry.Name
		end

		local GrowthLabel = Billboard:FindFirstChild("GrowthLabel", true)
			or Billboard:FindFirstChild("BenefitLabel", true)
		if GrowthLabel and GrowthLabel:IsA("TextLabel") then
			GrowthLabel.Text = string.format("+%s Growth", FormatNumber(Entry.AdditiveGrowth))
		end

		local CostLabel = Billboard:FindFirstChild("CostLabel", true) or Billboard:FindFirstChild("PriceLabel", true)
		if CostLabel and CostLabel:IsA("TextLabel") then
			if Entry.IsUnlocked then
				CostLabel.Text = if Entry.IsEquipped then "EQUIPPED" else "OWNED"
				CostLabel.TextColor3 = if Entry.IsEquipped
					then Color3.fromRGB(105, 220, 130)
					else Color3.fromRGB(200, 200, 200)
			else
				CostLabel.Text = string.format("Cost: %s Destruction", FormatNumber(Entry.Cost))
				CostLabel.TextColor3 = if Entry.CanBuy then Color3.fromRGB(255, 215, 0) else Color3.fromRGB(200, 80, 80)
			end
		end

		local StatusLabel = Billboard:FindFirstChild("StatusLabel", true)
		if StatusLabel and StatusLabel:IsA("TextLabel") then
			if Entry.IsEquipped then
				StatusLabel.Text = "EQUIPPED"
				StatusLabel.TextColor3 = Color3.fromRGB(105, 220, 130)
			elseif Entry.IsUnlocked then
				StatusLabel.Text = "UNLOCKED"
				StatusLabel.TextColor3 = Color3.fromRGB(100, 180, 255)
			elseif Entry.CanBuy then
				StatusLabel.Text = "AVAILABLE"
				StatusLabel.TextColor3 = Color3.fromRGB(255, 215, 0)
			else
				StatusLabel.Text = "LOCKED"
				StatusLabel.TextColor3 = Color3.fromRGB(150, 150, 150)
			end
		end
	end

	-- 2. Update ProximityPrompt if present
	local Prompt = Pedestal:FindFirstChildWhichIsA("ProximityPrompt", true)
	if Prompt then
		Prompt.ObjectText = Entry.Name
		if Entry.IsEquipped then
			Prompt.ActionText = "Equipped"
			Prompt.Enabled = false
		elseif Entry.IsUnlocked then
			Prompt.ActionText = "Equip"
			Prompt.Enabled = true
		elseif Entry.CanBuy then
			Prompt.ActionText = string.format("Buy (%s Destruction)", FormatNumber(Entry.Cost))
			Prompt.Enabled = true
		else
			Prompt.ActionText = "Locked"
			Prompt.Enabled = false
		end
	end
end

local function BindPedestalPrompt(Pedestal: Instance, UpgradeName: string)
	local Prompt = Pedestal:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not Prompt then
		return
	end

	if PromptConnections[Prompt] then
		PromptConnections[Prompt]:Disconnect()
		PromptConnections[Prompt] = nil
	end

	PromptConnections[Prompt] = Prompt.Triggered:Connect(function(TriggeringPlayer: Player)
		if TriggeringPlayer ~= LocalPlayer then
			return
		end

		local Entry = FindStatusEntry(UpgradeName)
		if not Entry then
			-- Fallback: fire buy request directly
			if RequestBuyUpgradeRemote then
				RequestBuyUpgradeRemote:FireServer(UpgradeName)
			end
			return
		end

		if Entry.IsUnlocked and not Entry.IsEquipped then
			if RequestEquipUpgradeRemote then
				RequestEquipUpgradeRemote:FireServer(Entry.Name)
			end
		elseif not Entry.IsUnlocked and Entry.CanBuy then
			if RequestBuyUpgradeRemote then
				RequestBuyUpgradeRemote:FireServer(Entry.Name)
			end
		end
	end)
end

local function RefreshAllPedestals()
	local ShopFolder = Workspace:FindFirstChild("UpgradeShop")
	if not ShopFolder then
		return
	end

	for _, Child in ShopFolder:GetChildren() do
		local Entry = FindStatusEntry(Child.Name)
		if Entry then
			UpdatePedestal(Child, Entry)
			BindPedestalPrompt(Child, Entry.Name)
		else
			-- Try by Attribute "UpgradeName" or "Order"
			local AttrName = Child:GetAttribute("UpgradeName") or Child:GetAttribute("Name")
			if type(AttrName) == "string" then
				local AttrEntry = FindStatusEntry(AttrName)
				if AttrEntry then
					UpdatePedestal(Child, AttrEntry)
					BindPedestalPrompt(Child, AttrEntry.Name)
				end
			end
		end
	end
end

--// Service \\--
local UpgradeShopController = {}

function UpgradeShopController.Init()
	if Initialized then
		return
	end
	Initialized = true

	local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if RemotesFolder then
		RequestBuyUpgradeRemote = RemotesFolder:FindFirstChild("RequestBuyUpgrade") :: RemoteEvent?
		RequestEquipUpgradeRemote = RemotesFolder:FindFirstChild("RequestEquipUpgrade") :: RemoteEvent?
		UpdateUpgradeStatusRemote = RemotesFolder:FindFirstChild("UpdateUpgradeStatus") :: RemoteEvent?
	end
end

function UpgradeShopController.Start()
	if Started then
		return
	end
	UpgradeShopController.Init()
	Started = true

	if not UpdateUpgradeStatusRemote then
		local RemotesFolder = ReplicatedStorage:WaitForChild("Remotes", 5)
		if RemotesFolder then
			RequestBuyUpgradeRemote = RemotesFolder:WaitForChild("RequestBuyUpgrade", 5) :: RemoteEvent?
			RequestEquipUpgradeRemote = RemotesFolder:WaitForChild("RequestEquipUpgrade", 5) :: RemoteEvent?
			UpdateUpgradeStatusRemote = RemotesFolder:WaitForChild("UpdateUpgradeStatus", 5) :: RemoteEvent?
		end
	end

	if UpdateUpgradeStatusRemote then
		table.insert(
			Connections,
			UpdateUpgradeStatusRemote.OnClientEvent:Connect(function(Payload: UpgradeStatusPayload)
				CachedStatus = Payload
				RefreshAllPedestals()
			end)
		)
	end

	-- Listen for Workspace.UpgradeShop added dynamically
	local ShopFolder = Workspace:FindFirstChild("UpgradeShop")
	if ShopFolder then
		RefreshAllPedestals()
	end

	table.insert(
		Connections,
		Workspace.ChildAdded:Connect(function(Child)
			if Child.Name == "UpgradeShop" then
				RefreshAllPedestals()
			end
		end)
	)
end

function UpgradeShopController.GetCachedStatus(): UpgradeStatusPayload?
	return CachedStatus
end

function UpgradeShopController.Destroy()
	for _, Connection in Connections do
		Connection:Disconnect()
	end
	table.clear(Connections)

	for _, Connection in PromptConnections do
		Connection:Disconnect()
	end
	table.clear(PromptConnections)

	CachedStatus = nil
	Initialized = false
	Started = false
end

return UpgradeShopController
