--!strict
-- CosmeticsService.luau
-- Authoritative server service managing cosmetic Trails and Overhead Titles.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Sessions = require(script.Parent.Parent.Parent.Core.Registry.RuntimeRegistry.Sessions)
local Logger = require(script.Parent.Parent.Parent.Core.Utilities.Logger)
local EventBus = require(script.Parent.Parent.Parent.Core.Events.EventBus)
local TrailConfig = require(script.Parent.Parent.Config.TrailConfig)
local TitleConfig = require(script.Parent.Parent.Config.TitleConfig)

export type CosmeticsStatus = {
	UnlockedTrails: { [string]: boolean },
	EquippedTrail: string?,
	UnlockedTitles: { [string]: boolean },
	EquippedTitle: string?,
	Trails: { TrailConfig.Trail },
	Titles: { TitleConfig.Title },
}

--// Variables \\--
local GetCosmeticsStatusRemoteFunc: RemoteFunction? = nil
local RequestEquipTrailRemote: RemoteEvent? = nil
local RequestUnequipTrailRemote: RemoteEvent? = nil
local RequestEquipTitleRemote: RemoteEvent? = nil
local RequestUnequipTitleRemote: RemoteEvent? = nil
local CosmeticsStatusUpdatedRemote: RemoteEvent? = nil

local PlayerConnections: { [Player]: { RBXScriptConnection } } = {}
local Initialized = false

--// Helpers \\--
local function EnsureRemoteEvent(Name: string): RemoteEvent
	local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if not RemotesFolder then
		RemotesFolder = Instance.new("Folder")
		RemotesFolder.Name = "Remotes"
		RemotesFolder.Parent = ReplicatedStorage
	end

	local Existing = RemotesFolder:FindFirstChild(Name)
	if Existing and (not Existing.IsA or Existing:IsA("RemoteEvent")) then
		return Existing :: RemoteEvent
	end

	local Remote = Instance.new("RemoteEvent")
	Remote.Name = Name
	Remote.Parent = RemotesFolder
	return Remote
end

local function EnsureRemoteFunction(Name: string): RemoteFunction
	local RemotesFolder = ReplicatedStorage:FindFirstChild("Remotes")
	if not RemotesFolder then
		RemotesFolder = Instance.new("Folder")
		RemotesFolder.Name = "Remotes"
		RemotesFolder.Parent = ReplicatedStorage
	end

	local Existing = RemotesFolder:FindFirstChild(Name)
	if Existing and (not Existing.IsA or Existing:IsA("RemoteFunction")) then
		return Existing :: RemoteFunction
	end

	local Remote = Instance.new("RemoteFunction")
	Remote.Name = Name
	Remote.Parent = RemotesFolder
	return Remote
end

--// Service \\--
local CosmeticsService = {}

function CosmeticsService:Init()
	if Initialized then
		return
	end
	Initialized = true

	GetCosmeticsStatusRemoteFunc = EnsureRemoteFunction("GetCosmeticsStatus")
	RequestEquipTrailRemote = EnsureRemoteEvent("RequestEquipTrail")
	RequestUnequipTrailRemote = EnsureRemoteEvent("RequestUnequipTrail")
	RequestEquipTitleRemote = EnsureRemoteEvent("RequestEquipTitle")
	RequestUnequipTitleRemote = EnsureRemoteEvent("RequestUnequipTitle")
	CosmeticsStatusUpdatedRemote = EnsureRemoteEvent("CosmeticsStatusUpdated")

	if GetCosmeticsStatusRemoteFunc then
		GetCosmeticsStatusRemoteFunc.OnServerInvoke = function(Client: Player)
			return self:GetCosmeticsStatus(Client)
		end
	end

	if RequestEquipTrailRemote and RequestEquipTrailRemote.OnServerEvent then
		RequestEquipTrailRemote.OnServerEvent:Connect(function(Client: Player, TrailId: any)
			if type(TrailId) == "string" then
				self:EquipTrail(Client, TrailId)
			end
		end)
	end

	if RequestUnequipTrailRemote and RequestUnequipTrailRemote.OnServerEvent then
		RequestUnequipTrailRemote.OnServerEvent:Connect(function(Client: Player)
			self:UnequipTrail(Client)
		end)
	end

	if RequestEquipTitleRemote and RequestEquipTitleRemote.OnServerEvent then
		RequestEquipTitleRemote.OnServerEvent:Connect(function(Client: Player, TitleId: any)
			if type(TitleId) == "string" then
				self:EquipTitle(Client, TitleId)
			end
		end)
	end

	if RequestUnequipTitleRemote and RequestUnequipTitleRemote.OnServerEvent then
		RequestUnequipTitleRemote.OnServerEvent:Connect(function(Client: Player)
			self:UnequipTitle(Client)
		end)
	end

	EventBus.Subscribe("PlayerSessionCreated", function(Player: Player, Session: any)
		self:OnPlayerSessionCreated(Player, Session)
	end)

	Players.PlayerAdded:Connect(function(Player: Player)
		self:OnPlayerAdded(Player)
	end)

	Players.PlayerRemoving:Connect(function(Player: Player)
		self:OnPlayerRemoving(Player)
	end)

	Logger.Info("Cosmetics", "CosmeticsService initialized")
end

function CosmeticsService:Start()
	for _, Player in Players:GetPlayers() do
		self:OnPlayerAdded(Player)
		local Session = Sessions.Get(Player)
		if Session then
			self:OnPlayerSessionCreated(Player, Session)
		end
	end
end

function CosmeticsService:OnPlayerAdded(Player: Player)
	if PlayerConnections[Player] then
		return
	end

	PlayerConnections[Player] = {
		Player.CharacterAdded:Connect(function(Character)
			self:ApplyCharacterCosmetics(Player, Character)
		end),
		Player.CharacterAppearanceLoaded:Connect(function(Character)
			self:ApplyCharacterCosmetics(Player, Character)
		end),
	}

	if Player.Character then
		self:ApplyCharacterCosmetics(Player, Player.Character)
	end
end

function CosmeticsService:OnPlayerRemoving(Player: Player)
	local Connections = PlayerConnections[Player]
	if Connections then
		for _, Connection in Connections do
			if typeof(Connection) == "RBXScriptConnection" then
				Connection:Disconnect()
			elseif type(Connection) == "table" and type(Connection.Disconnect) == "function" then
				Connection.Disconnect()
			end
		end
		PlayerConnections[Player] = nil
	end
end

function CosmeticsService:OnPlayerSessionCreated(Player: Player, Session: any)
	if not Session then
		return
	end

	-- Grant defaults
	for _, Trail in TrailConfig.List do
		if Trail.DefaultUnlocked and Session.UnlockedTrails[Trail.Id] ~= true then
			Session.UnlockedTrails[Trail.Id] = true
		end
	end

	for _, Title in TitleConfig.List do
		if Title.DefaultUnlocked and Session.UnlockedTitles[Title.Id] ~= true then
			Session.UnlockedTitles[Title.Id] = true
		end
	end

	Player:SetAttribute("EquippedTrail", Session.EquippedTrail or "")
	Player:SetAttribute("EquippedTitle", Session.EquippedTitle or "")

	if Player.Character then
		self:ApplyCharacterCosmetics(Player, Player.Character)
	end

	self:PushCosmeticsStatus(Player)
end

function CosmeticsService:GetCosmeticsStatus(Player: Player): CosmeticsStatus?
	local Session = Sessions.Get(Player)
	if not Session then
		return nil
	end

	return {
		UnlockedTrails = Session.UnlockedTrails or {},
		EquippedTrail = Session.EquippedTrail,
		UnlockedTitles = Session.UnlockedTitles or {},
		EquippedTitle = Session.EquippedTitle,
		Trails = TrailConfig.List,
		Titles = TitleConfig.List,
	}
end

function CosmeticsService:PushCosmeticsStatus(Player: Player)
	local Status = self:GetCosmeticsStatus(Player)
	if Status and CosmeticsStatusUpdatedRemote then
		pcall(function()
			CosmeticsStatusUpdatedRemote:FireClient(Player, Status)
		end)
	end
end

function CosmeticsService:EquipTrail(Player: Player, TrailId: string): boolean
	local Session = Sessions.Get(Player)
	if not Session or Session.ProfileMutationsFrozen then
		return false
	end

	local TrailData = TrailConfig.Get(TrailId)
	if not TrailData then
		return false
	end

	if Session.UnlockedTrails[TrailId] ~= true then
		return false
	end

	Sessions.Mutate(Player, function(CurrentSession)
		CurrentSession.EquippedTrail = TrailId
	end)

	Player:SetAttribute("EquippedTrail", TrailId)

	if Player.Character then
		self:ApplyCharacterCosmetics(Player, Player.Character)
	end

	self:PushCosmeticsStatus(Player)
	EventBus.Publish("CosmeticsEquipped", Player, "Trail", TrailId)
	Logger.Info("Cosmetics", "Player %s equipped trail %s", Player.Name, TrailId)

	return true
end

function CosmeticsService:UnequipTrail(Player: Player): boolean
	local Session = Sessions.Get(Player)
	if not Session or Session.ProfileMutationsFrozen then
		return false
	end

	Sessions.Mutate(Player, function(CurrentSession)
		CurrentSession.EquippedTrail = nil
	end)

	Player:SetAttribute("EquippedTrail", "")

	if Player.Character then
		self:ApplyCharacterCosmetics(Player, Player.Character)
	end

	self:PushCosmeticsStatus(Player)
	EventBus.Publish("CosmeticsUnequipped", Player, "Trail")
	Logger.Info("Cosmetics", "Player %s unequipped trail", Player.Name)

	return true
end

function CosmeticsService:EquipTitle(Player: Player, TitleId: string): boolean
	local Session = Sessions.Get(Player)
	if not Session or Session.ProfileMutationsFrozen then
		return false
	end

	local TitleData = TitleConfig.Get(TitleId)
	if not TitleData then
		return false
	end

	if Session.UnlockedTitles[TitleId] ~= true then
		return false
	end

	Sessions.Mutate(Player, function(CurrentSession)
		CurrentSession.EquippedTitle = TitleId
	end)

	Player:SetAttribute("EquippedTitle", TitleId)

	if Player.Character then
		self:ApplyCharacterCosmetics(Player, Player.Character)
	end

	self:PushCosmeticsStatus(Player)
	EventBus.Publish("CosmeticsEquipped", Player, "Title", TitleId)
	Logger.Info("Cosmetics", "Player %s equipped title %s", Player.Name, TitleId)

	return true
end

function CosmeticsService:UnequipTitle(Player: Player): boolean
	local Session = Sessions.Get(Player)
	if not Session or Session.ProfileMutationsFrozen then
		return false
	end

	Sessions.Mutate(Player, function(CurrentSession)
		CurrentSession.EquippedTitle = nil
	end)

	Player:SetAttribute("EquippedTitle", "")

	if Player.Character then
		self:ApplyCharacterCosmetics(Player, Player.Character)
	end

	self:PushCosmeticsStatus(Player)
	EventBus.Publish("CosmeticsUnequipped", Player, "Title")
	Logger.Info("Cosmetics", "Player %s unequipped title", Player.Name)

	return true
end

function CosmeticsService:ApplyCharacterCosmetics(Player: Player, Character: Model)
	if not Character then
		return
	end

	local Session = Sessions.Get(Player)
	if not Session then
		return
	end

	-- Apply Trail
	local RootPart = Character:FindFirstChild("HumanoidRootPart")
		or Character:FindFirstChild("UpperTorso")
		or Character:FindFirstChild("Torso")
	if RootPart then
		local ExistingTrail = RootPart:FindFirstChild("CharacterTrail")
		if Session.EquippedTrail and Session.EquippedTrail ~= "" then
			local TrailData = TrailConfig.Get(Session.EquippedTrail)
			if TrailData then
				local Att0 = RootPart:FindFirstChild("TrailAttachment0") :: Attachment?
				if not Att0 then
					Att0 = Instance.new("Attachment")
					Att0.Name = "TrailAttachment0"
					Att0.Position = Vector3.new(0, 0.5, 0)
					Att0.Parent = RootPart
				end

				local Att1 = RootPart:FindFirstChild("TrailAttachment1") :: Attachment?
				if not Att1 then
					Att1 = Instance.new("Attachment")
					Att1.Name = "TrailAttachment1"
					Att1.Position = Vector3.new(0, -0.5, 0)
					Att1.Parent = RootPart
				end

				local TrailInst = ExistingTrail :: Trail?
				if not TrailInst then
					TrailInst = Instance.new("Trail")
					TrailInst.Name = "CharacterTrail"
					TrailInst.Parent = RootPart
				end

				TrailInst.Attachment0 = Att0
				TrailInst.Attachment1 = Att1
				TrailInst.Color = TrailData.Color
				TrailInst.Lifetime = TrailData.Lifetime
				TrailInst.LightEmission = TrailData.LightEmission
				if TrailData.Texture then
					TrailInst.Texture = TrailData.Texture
				end
			elseif ExistingTrail then
				ExistingTrail:Destroy()
			end
		elseif ExistingTrail then
			ExistingTrail:Destroy()
		end
	end

	-- Apply Title
	local Head = Character:FindFirstChild("Head")
	if Head then
		local ExistingTitle = Head:FindFirstChild("OverheadTitle")
		if Session.EquippedTitle and Session.EquippedTitle ~= "" then
			local TitleData = TitleConfig.Get(Session.EquippedTitle)
			if TitleData then
				local Billboard = ExistingTitle :: BillboardGui?
				if not Billboard then
					Billboard = Instance.new("BillboardGui")
					Billboard.Name = "OverheadTitle"
					Billboard.Size = UDim2.fromOffset(200, 50)
					Billboard.StudsOffset = Vector3.new(0, 2.5, 0)
					Billboard.AlwaysOnTop = true
					Billboard.LightInfluence = 0
					Billboard.Parent = Head
				end

				local Label = Billboard:FindFirstChild("TitleLabel") :: TextLabel?
				if not Label then
					Label = Instance.new("TextLabel")
					Label.Name = "TitleLabel"
					Label.Size = UDim2.fromScale(1, 1)
					Label.BackgroundTransparency = 1
					Label.Font = Enum.Font.FredokaOne
					Label.Parent = Billboard
				end

				Label.Text = TitleData.DisplayName
				Label.TextColor3 = TitleData.Color
				Label.TextSize = 20

				local Stroke = Label:FindFirstChild("UIStroke") :: UIStroke?
				if not Stroke then
					Stroke = Instance.new("UIStroke")
					Stroke.Parent = Label
				end
				Stroke.Color = TitleData.StrokeColor
				Stroke.Thickness = TitleData.StrokeThickness or 2
				Stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
			elseif ExistingTitle then
				ExistingTitle:Destroy()
			end
		elseif ExistingTitle then
			ExistingTitle:Destroy()
		end
	end
end

return CosmeticsService
