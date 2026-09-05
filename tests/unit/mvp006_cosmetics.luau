local fs = require("@lune/fs")
local luau = require("@lune/luau")
local task = require("@lune/task")

local Sessions = require("../../src/server/Core/Registry/RuntimeRegistry/Sessions")
local ServiceRegistry = require("../../src/server/Core/Registry/ServiceRegistry")

local Failures = {}

local function check(Name: string, Callback: () -> ())
	local Success, Message = pcall(Callback)
	if not Success then
		table.insert(Failures, string.format("%s: %s", Name, tostring(Message)))
		print(string.format("  FAIL: %s - %s", Name, tostring(Message)))
	else
		print(string.format("  PASS: %s", Name))
	end
end

local function loadModule(Path: string, Name: string, Environment: { [string]: any }?)
	assert(fs.isFile(Path), Name .. " production module is missing: " .. Path)
	local Chunk = luau.load(fs.readFile(Path), Name)
	setfenv(Chunk, setmetatable(Environment or {}, { __index = getfenv() }))
	return Chunk()
end

local function fakeSignal()
	local Signal = { Callbacks = {} }
	function Signal:Connect(Callback)
		table.insert(self.Callbacks, Callback)
		local Connected = true
		return {
			Disconnect = function()
				if not Connected then
					return
				end
				Connected = false
				local Index = table.find(self.Callbacks, Callback)
				if Index then
					table.remove(self.Callbacks, Index)
				end
			end,
		}
	end
	function Signal:Fire(...)
		for _, Callback in self.Callbacks do
			Callback(...)
		end
	end
	return Signal
end

local function createMockEventBus()
	local Subscribers = {}
	return {
		Subscribe = function(Name: string, Callback: (...any) -> ())
			Subscribers[Name] = Subscribers[Name] or {}
			table.insert(Subscribers[Name], Callback)
			return {
				Disconnect = function()
					local Index = table.find(Subscribers[Name], Callback)
					if Index then
						table.remove(Subscribers[Name], Index)
					end
				end,
			}
		end,
		Publish = function(Name: string, ...: any)
			for _, Callback in Subscribers[Name] or {} do
				Callback(...)
			end
		end,
	}
end

local function fakeRemoteEvent(Name: string)
	local Remote = {
		Name = Name,
		ClassName = "RemoteEvent",
		OnServerEvent = fakeSignal(),
		OnClientEvent = fakeSignal(),
		FiredClientEvents = {},
		FiredServerEvents = {},
	}
	function Remote:IsA(ClassName: string)
		return ClassName == "RemoteEvent" or ClassName == "Instance"
	end
	function Remote:FireServer(...)
		table.insert(self.FiredServerEvents, { ... })
		self.OnServerEvent:Fire(nil, ...)
	end
	function Remote:FireClient(Player: any, ...)
		table.insert(self.FiredClientEvents, { Player = Player, Args = { ... } })
		self.OnClientEvent:Fire(...)
	end
	function Remote:FireAllClients(...)
		table.insert(self.FiredClientEvents, { Player = "All", Args = { ... } })
		self.OnClientEvent:Fire(...)
	end
	return Remote
end

local function fakeRemoteFunction(Name: string)
	local Remote = {
		Name = Name,
		ClassName = "RemoteFunction",
		OnServerInvoke = nil,
		OnClientInvoke = nil,
	}
	function Remote:IsA(ClassName: string)
		return ClassName == "RemoteFunction" or ClassName == "Instance"
	end
	function Remote:InvokeServer(...)
		if self.OnServerInvoke then
			return self.OnServerInvoke(nil, ...)
		end
		return nil
	end
	function Remote:InvokeClient(Player: any, ...)
		if self.OnClientInvoke then
			return self.OnClientInvoke(...)
		end
		return nil
	end
	return Remote
end

local function fakeFolder(Name: string, ChildrenDict: { [string]: any }?)
	local Folder = {
		Name = Name,
		ClassName = "Folder",
		Children = {},
	}
	if ChildrenDict then
		for ChildName, Child in ChildrenDict do
			if type(Child) == "table" then
				pcall(function()
					Child.Parent = Folder
				end)
				table.insert(Folder.Children, Child)
				Folder[ChildName] = Child
			end
		end
	end
	function Folder:IsA(ClassName: string)
		return ClassName == "Folder" or ClassName == "Instance"
	end
	function Folder:FindFirstChild(ChildName: string)
		for _, Child in self.Children do
			if Child.Name == ChildName then
				return Child
			end
		end
		return self[ChildName]
	end
	function Folder:WaitForChild(ChildName: string, _Timeout: number?)
		local Found = self:FindFirstChild(ChildName)
		if Found then
			return Found
		end
		return self[ChildName]
	end
	function Folder:GetChildren()
		local List = {}
		for _, v in self.Children do
			table.insert(List, v)
		end
		return List
	end
	return Folder
end

local function createMockInstance(ClassName: string, Name: string?)
	local Internal = {
		ClassName = ClassName,
		Name = Name or ClassName,
		Parent = nil,
		Children = {},
		Attributes = {},
		Properties = {},
	}

	local Methods = {}

	function Methods:IsA(TargetClass: string)
		return Internal.ClassName == TargetClass or TargetClass == "Instance"
	end
	function Methods:FindFirstChild(ChildName: string, _Recursive: boolean?)
		for _, Child in Internal.Children do
			if Child.Name == ChildName then
				return Child
			end
		end
		return nil
	end
	function Methods:WaitForChild(ChildName: string, _Timeout: number?)
		local Child = self:FindFirstChild(ChildName)
		if Child then
			return Child
		end
		return Internal[ChildName]
	end
	function Methods:GetChildren()
		local List = {}
		for _, Child in Internal.Children do
			table.insert(List, Child)
		end
		return List
	end
	function Methods:SetAttribute(Key: string, Value: any)
		Internal.Attributes[Key] = Value
	end
	function Methods:GetAttribute(Key: string)
		return Internal.Attributes[Key]
	end

	local Proxy = {}

	function Methods:Destroy()
		if Internal.Parent and Internal.Parent.Children then
			local Index = table.find(Internal.Parent.Children, Proxy)
			if Index then
				table.remove(Internal.Parent.Children, Index)
			end
		end
		Internal.Parent = nil
		table.clear(Internal.Children)
	end

	local Meta = {
		__index = function(_t, k)
			if Methods[k] ~= nil then
				return Methods[k]
			end
			return Internal[k]
		end,
		__newindex = function(_t, k, v)
			if k == "Parent" then
				local OldParent = Internal.Parent
				if OldParent and OldParent.Children then
					local Idx = table.find(OldParent.Children, Proxy)
					if Idx then
						table.remove(OldParent.Children, Idx)
					end
				end
				Internal.Parent = v
				if v and v.Children then
					table.insert(v.Children, Proxy)
				end
			else
				Internal[k] = v
			end
		end,
	}

	return setmetatable(Proxy, Meta)
end

local function fakeColor3(R: number, G: number, B: number)
	return { R = R, G = G, B = B, ClassName = "Color3" }
end

local function fakeColorSequence(Keypoints: any)
	return { Keypoints = Keypoints, ClassName = "ColorSequence" }
end

local function fakeVector3(X: number, Y: number, Z: number)
	return { X = X, Y = Y, Z = Z, ClassName = "Vector3" }
end

local function fakeUDim2(XScale: number, XOffset: number, YScale: number, YOffset: number)
	return {
		X = { Scale = XScale or 0, Offset = XOffset or 0 },
		Y = { Scale = YScale or 0, Offset = YOffset or 0 },
		ClassName = "UDim2",
	}
end

local MockInstance = {
	new = function(ClassName: string, Parent: any?)
		local Inst = createMockInstance(ClassName)
		if Parent then
			Inst.Parent = Parent
			if Parent.Children then
				table.insert(Parent.Children, Inst)
			end
		end
		return Inst
	end,
}

local function fakePlayer(UserId: number)
	local AttributeSignals: { [string]: any } = {}
	local Player = {
		UserId = UserId,
		Name = "CosmeticPlayer_" .. tostring(UserId),
		Attributes = {},
		Character = nil,
		CharacterAdded = fakeSignal(),
		CharacterAppearanceLoaded = fakeSignal(),
	}
	function Player:IsA(ClassName: string)
		return ClassName == "Player" or ClassName == "Instance"
	end
	function Player:SetAttribute(Key: string, Value: any)
		local Old = self.Attributes[Key]
		self.Attributes[Key] = Value
		if Old ~= Value and AttributeSignals[Key] then
			AttributeSignals[Key]:Fire(Value)
		end
	end
	function Player:GetAttribute(Key: string)
		return self.Attributes[Key]
	end
	function Player:GetAttributeChangedSignal(Key: string)
		if not AttributeSignals[Key] then
			AttributeSignals[Key] = fakeSignal()
		end
		return AttributeSignals[Key]
	end
	function Player:FindFirstChild(Name: string)
		return self[Name]
	end
	function Player:WaitForChild(Name: string, _Timeout: number?)
		return self[Name]
	end
	return Player
end

local function createMockCharacter()
	local Character = createMockInstance("Model", "Character")
	local RootPart = createMockInstance("Part", "HumanoidRootPart")
	local Head = createMockInstance("Part", "Head")
	local Humanoid = createMockInstance("Humanoid", "Humanoid")

	RootPart.Parent = Character
	Head.Parent = Character
	Humanoid.Parent = Character

	return Character, RootPart, Head, Humanoid
end

local function createMockSession(Player: any, Overrides: { [string]: any }?)
	local Session = {
		Player = Player,
		Bigger = 100,
		Destruction = 0,
		Rebirth = 0,
		UnlockedGrowthUpgrades = {},
		EquippedGrowthUpgrade = nil,
		CompletedPortals = {},
		Settings = {
			SoundEnabled = true,
			MusicEnabled = true,
		},
		State = "InLobby",
		JoinedAt = os.time(),
		PurchaseHistory = {},
		CurrentWorldInstanceId = nil,
		HasDoubleMultiplier = false,
		HasVip = false,
		HasPremiumZonePass = false,
		HasAutoWins = false,
		DailyRewardDay = 1,
		LastDailyClaimTimestamp = 0,
		SpinTokens = 0,
		UnlockedTrails = { Default = true },
		EquippedTrail = "Default",
		UnlockedTitles = { Newbie = true },
		EquippedTitle = "Newbie",
		AutoWinsEnabled = false,
		GrowthRemainder = 0,
		CurrentAFKZone = nil,
		PremiumZonePromptedThisEntry = false,
		GamePassQueryGenerations = { Vip = 0, PremiumZone = 0 },
		LastActiveTimestamp = os.time(),
		LastLogoutTimestamp = 0,
		LastSaveTimestamp = os.time(),
		ProfileMutationsFrozen = false,
		ProfileMutationFreezeReason = nil,
	}
	if Overrides then
		for K, V in Overrides do
			Session[K] = V
		end
	end
	return Session
end

print("=== Running MVP-006 Task 9 Unit Tests (Cosmetic Systems: Trails & Titles) ===")

-- TEST 1: TrailConfig & TitleConfig definitions and helper lookup functions
check("TrailConfig & TitleConfig definitions and helper lookup functions", function()
	local MockColor3 = {
		fromRGB = function(r, g, b)
			return fakeColor3(r, g, b)
		end,
		new = function(r, g, b)
			return fakeColor3(r, g, b)
		end,
	}
	local MockColorSequence = {
		new = function(keypoints)
			return fakeColorSequence(keypoints)
		end,
	}
	local MockColorSequenceKeypoint = {
		new = function(time, color)
			return { Time = time, Value = color }
		end,
	}

	local TrailConfig = loadModule("src/server/Game/Config/TrailConfig.luau", "TrailConfig", {
		Color3 = MockColor3,
		ColorSequence = MockColorSequence,
		ColorSequenceKeypoint = MockColorSequenceKeypoint,
	})

	local TitleConfig = loadModule("src/server/Game/Config/TitleConfig.luau", "TitleConfig", {
		Color3 = MockColor3,
		ColorSequence = MockColorSequence,
		ColorSequenceKeypoint = MockColorSequenceKeypoint,
	})

	assert(type(TrailConfig) == "table", "TrailConfig should be a table")
	assert(type(TitleConfig) == "table", "TitleConfig should be a table")

	-- Validate TrailConfig trails
	assert(type(TrailConfig.List) == "table", "TrailConfig.List should be a table")
	assert(#TrailConfig.List >= 5, "TrailConfig should define at least 5 trails")

	local RequiredTrails = { "Default", "FireTrail", "RainbowTrail", "VoidTrail", "GoldenTrail" }
	for _, TrailId in RequiredTrails do
		local Trail = TrailConfig.Get and TrailConfig.Get(TrailId) or TrailConfig.GetTrail(TrailId)
		assert(Trail ~= nil, "Trail " .. TrailId .. " must exist in TrailConfig")
		assert(Trail.Id == TrailId, "Trail.Id should match " .. TrailId)
		assert(type(Trail.Name) == "string" and #Trail.Name > 0, "Trail.Name must be a valid string")
		assert(type(Trail.Lifetime) == "number" and Trail.Lifetime > 0, "Trail.Lifetime must be > 0")
		assert(type(Trail.LightEmission) == "number" and Trail.LightEmission >= 0, "Trail.LightEmission must be >= 0")
		assert(type(Trail.DefaultUnlocked) == "boolean", "Trail.DefaultUnlocked must be boolean")
	end

	local DefaultTrail = TrailConfig.Get("Default")
	assert(DefaultTrail.DefaultUnlocked == true, "Default trail must be unlocked by default")

	-- Validate TitleConfig titles
	assert(type(TitleConfig.List) == "table", "TitleConfig.List should be a table")
	assert(#TitleConfig.List >= 6, "TitleConfig should define at least 6 titles")

	local RequiredTitles = { "Newbie", "Giant", "Colossus", "DailyMaster", "Titan", "GodOfGrowth" }
	for _, TitleId in RequiredTitles do
		local Title = TitleConfig.Get and TitleConfig.Get(TitleId) or TitleConfig.GetTitle(TitleId)
		assert(Title ~= nil, "Title " .. TitleId .. " must exist in TitleConfig")
		assert(Title.Id == TitleId, "Title.Id should match " .. TitleId)
		assert(type(Title.DisplayName) == "string" and #Title.DisplayName > 0, "Title.DisplayName must be non-empty")
		assert(type(Title.DefaultUnlocked) == "boolean", "Title.DefaultUnlocked must be boolean")
	end

	local NewbieTitle = TitleConfig.Get("Newbie")
	assert(NewbieTitle.DefaultUnlocked == true, "Newbie title must be unlocked by default")
end)

-- TEST 2: CosmeticsService authoritative equipping, unequipping, and validation
check("CosmeticsService: Authoritative Equip/Unequip for Trails and Titles", function()
	local MockColor3 = {
		fromRGB = function(r, g, b)
			return fakeColor3(r, g, b)
		end,
		new = function(r, g, b)
			return fakeColor3(r, g, b)
		end,
	}
	local MockColorSequence = {
		new = function(keypoints)
			return fakeColorSequence(keypoints)
		end,
	}
	local MockColorSequenceKeypoint = {
		new = function(time, color)
			return { Time = time, Value = color }
		end,
	}

	local TrailConfig = loadModule("src/server/Game/Config/TrailConfig.luau", "TrailConfig", {
		Color3 = MockColor3,
		ColorSequence = MockColorSequence,
		ColorSequenceKeypoint = MockColorSequenceKeypoint,
	})

	local TitleConfig = loadModule("src/server/Game/Config/TitleConfig.luau", "TitleConfig", {
		Color3 = MockColor3,
		ColorSequence = MockColorSequence,
		ColorSequenceKeypoint = MockColorSequenceKeypoint,
	})

	local RemotesFolder = fakeFolder("Remotes", {
		GetCosmeticsStatus = fakeRemoteFunction("GetCosmeticsStatus"),
		RequestEquipTrail = fakeRemoteEvent("RequestEquipTrail"),
		RequestUnequipTrail = fakeRemoteEvent("RequestUnequipTrail"),
		RequestEquipTitle = fakeRemoteEvent("RequestEquipTitle"),
		RequestUnequipTitle = fakeRemoteEvent("RequestUnequipTitle"),
		CosmeticsStatusUpdated = fakeRemoteEvent("CosmeticsStatusUpdated"),
	})
	local MockReplicatedStorage = fakeFolder("ReplicatedStorage", {
		Remotes = RemotesFolder,
	})

	local Logger = {
		Info = function(...) end,
		Warn = function(...) end,
		Error = function(...) end,
	}
	local EventBus = createMockEventBus()

	local ServerServicesFolder = {
		Parent = {
			Config = {
				TrailConfig = TrailConfig,
				TitleConfig = TitleConfig,
			},
			Parent = {
				Core = {
					Registry = {
						RuntimeRegistry = { Sessions = Sessions },
						ServiceRegistry = ServiceRegistry,
					},
					Utilities = {
						Logger = Logger,
					},
					Events = {
						EventBus = EventBus,
					},
				},
			},
		},
	}

	local MockPlayers = {
		PlayerAdded = fakeSignal(),
		PlayerRemoving = fakeSignal(),
		GetPlayers = function()
			return {}
		end,
	}

	local CosmeticsService = loadModule("src/server/Game/Services/CosmeticsService.luau", "CosmeticsService", {
		game = {
			GetService = function(_self, ServiceName: string)
				if ServiceName == "ReplicatedStorage" then
					return MockReplicatedStorage
				elseif ServiceName == "Players" then
					return MockPlayers
				end
				return nil
			end,
		},
		task = task,
		Instance = MockInstance,
		Vector3 = {
			new = fakeVector3,
		},
		UDim2 = {
			fromOffset = function(x, y)
				return fakeUDim2(0, x, 0, y)
			end,
			fromScale = function(x, y)
				return fakeUDim2(x, 0, y, 0)
			end,
			new = fakeUDim2,
		},
		Color3 = MockColor3,
		ColorSequence = MockColorSequence,
		ColorSequenceKeypoint = MockColorSequenceKeypoint,
		Enum = {
			Font = { FredokaOne = "FredokaOne" },
			ApplyStrokeMode = { Contextual = "Contextual" },
		},
		script = { Parent = ServerServicesFolder },
		require = function(Dependency)
			return Dependency
		end,
	})

	CosmeticsService:Init()

	local Player = fakePlayer(501)
	local Character, RootPart, Head = createMockCharacter()
	Player.Character = Character

	local Session = createMockSession(Player, {
		UnlockedTrails = { Default = true, FireTrail = true },
		EquippedTrail = "Default",
		UnlockedTitles = { Newbie = true, Giant = true },
		EquippedTitle = "Newbie",
	})
	Sessions.Set(Player, Session)

	-- 1. Status query
	local Status = CosmeticsService:GetCosmeticsStatus(Player)
	assert(Status ~= nil, "Status must not be nil")
	assert(Status.EquippedTrail == "Default", "EquippedTrail should be Default")
	assert(Status.UnlockedTrails.FireTrail == true, "FireTrail should be unlocked")
	assert(Status.EquippedTitle == "Newbie", "EquippedTitle should be Newbie")
	assert(Status.UnlockedTitles.Giant == true, "Giant should be unlocked")

	-- 2. Equip unowned trail (RainbowTrail) should fail
	local FailTrailOk = CosmeticsService:EquipTrail(Player, "RainbowTrail")
	assert(FailTrailOk == false, "Equipping unowned trail must fail")
	assert(Session.EquippedTrail == "Default", "EquippedTrail should remain Default")

	-- 3. Equip owned trail (FireTrail) should succeed
	local SuccessTrailOk = CosmeticsService:EquipTrail(Player, "FireTrail")
	assert(SuccessTrailOk == true, "Equipping owned trail must succeed")
	assert(Session.EquippedTrail == "FireTrail", "Session.EquippedTrail should be FireTrail")
	assert(Player:GetAttribute("EquippedTrail") == "FireTrail", "Player attribute EquippedTrail should be FireTrail")
	assert(RootPart:FindFirstChild("TrailAttachment0") ~= nil, "TrailAttachment0 must exist on RootPart")
	assert(RootPart:FindFirstChild("TrailAttachment1") ~= nil, "TrailAttachment1 must exist on RootPart")
	assert(RootPart:FindFirstChild("CharacterTrail") ~= nil, "CharacterTrail must exist on RootPart")

	-- 4. Unequip trail
	local UnequipTrailOk = CosmeticsService:UnequipTrail(Player)
	assert(UnequipTrailOk == true, "UnequipTrail must succeed")
	assert(Session.EquippedTrail == nil, "Session.EquippedTrail should be nil")
	assert(Player:GetAttribute("EquippedTrail") == "", "Player attribute EquippedTrail should be empty string")
	assert(RootPart:FindFirstChild("CharacterTrail") == nil, "CharacterTrail should be destroyed")

	-- 5. Equip unowned title (Titan) should fail
	local FailTitleOk = CosmeticsService:EquipTitle(Player, "Titan")
	assert(FailTitleOk == false, "Equipping unowned title must fail")
	assert(Session.EquippedTitle == "Newbie", "EquippedTitle should remain Newbie")

	-- 6. Equip owned title (Giant) should succeed
	local SuccessTitleOk = CosmeticsService:EquipTitle(Player, "Giant")
	assert(SuccessTitleOk == true, "Equipping owned title must succeed")
	assert(Session.EquippedTitle == "Giant", "Session.EquippedTitle should be Giant")
	assert(Player:GetAttribute("EquippedTitle") == "Giant", "Player attribute EquippedTitle should be Giant")
	local Overhead = Head:FindFirstChild("OverheadTitle")
	assert(Overhead ~= nil, "OverheadTitle BillboardGui must exist on Head")

	-- 7. Unequip title
	local UnequipTitleOk = CosmeticsService:UnequipTitle(Player)
	assert(UnequipTitleOk == true, "UnequipTitle must succeed")
	assert(Session.EquippedTitle == nil, "Session.EquippedTitle should be nil")
	assert(Player:GetAttribute("EquippedTitle") == "", "Player attribute EquippedTitle should be empty string")
	assert(Head:FindFirstChild("OverheadTitle") == nil, "OverheadTitle should be destroyed")

	-- 8. ApplyCharacterCosmetics on spawn
	Session.EquippedTrail = "FireTrail"
	Session.EquippedTitle = "Giant"
	CosmeticsService:ApplyCharacterCosmetics(Player, Character)
	assert(RootPart:FindFirstChild("CharacterTrail") ~= nil, "Spawn character should have trail")
	assert(Head:FindFirstChild("OverheadTitle") ~= nil, "Spawn character should have title")

	-- 9. Default granting on PlayerSessionCreated
	local FreshPlayer = fakePlayer(502)
	local FreshSession = createMockSession(FreshPlayer, {
		UnlockedTrails = {},
		EquippedTrail = nil,
		UnlockedTitles = {},
		EquippedTitle = nil,
	})
	Sessions.Set(FreshPlayer, FreshSession)
	EventBus.Publish("PlayerSessionCreated", FreshPlayer, FreshSession)
	assert(FreshSession.UnlockedTrails["Default"] == true, "Default trail should be granted automatically")
	assert(FreshSession.UnlockedTitles["Newbie"] == true, "Newbie title should be granted automatically")

	-- 10. Re-equipping another trail updates properties
	local ReequipTrailOk = CosmeticsService:EquipTrail(Player, "Default")
	assert(ReequipTrailOk == true, "Re-equipping Default trail should succeed")
	assert(Session.EquippedTrail == "Default", "EquippedTrail is Default")
	assert(Player:GetAttribute("EquippedTrail") == "Default", "Attribute is Default")

	-- 11. Invalid IDs (not in config)
	local InvalidTrailOk = CosmeticsService:EquipTrail(Player, "NonExistentTrail_999")
	assert(InvalidTrailOk == false, "Equipping non-existent trail ID must fail")
	local InvalidTitleOk = CosmeticsService:EquipTitle(Player, "NonExistentTitle_999")
	assert(InvalidTitleOk == false, "Equipping non-existent title ID must fail")

	-- 12. Frozen mutations reject equip and unequip
	Session.ProfileMutationsFrozen = true
	assert(CosmeticsService:EquipTrail(Player, "FireTrail") == false, "Frozen session must reject EquipTrail")
	assert(CosmeticsService:UnequipTrail(Player) == false, "Frozen session must reject UnequipTrail")
	assert(CosmeticsService:EquipTitle(Player, "Giant") == false, "Frozen session must reject EquipTitle")
	assert(CosmeticsService:UnequipTitle(Player) == false, "Frozen session must reject UnequipTitle")
	Session.ProfileMutationsFrozen = false

	-- 13. Player removing cleanup
	MockPlayers.PlayerRemoving:Fire(Player)
	MockPlayers.PlayerRemoving:Fire(FreshPlayer)

	Sessions.Remove(Player)
	Sessions.Remove(FreshPlayer)
end)

-- TEST 3: CosmeticsController client lifecycle, UI toggles, and remote triggers
check("CosmeticsController: Init, Start, UIEventBus, remote equip/unequip, Destroy", function()
	local RequestEquipTrailRemote = fakeRemoteEvent("RequestEquipTrail")
	local RequestUnequipTrailRemote = fakeRemoteEvent("RequestUnequipTrail")
	local RequestEquipTitleRemote = fakeRemoteEvent("RequestEquipTitle")
	local RequestUnequipTitleRemote = fakeRemoteEvent("RequestUnequipTitle")
	local CosmeticsStatusUpdatedRemote = fakeRemoteEvent("CosmeticsStatusUpdated")

	local RemotesFolder = fakeFolder("Remotes", {
		RequestEquipTrail = RequestEquipTrailRemote,
		RequestUnequipTrail = RequestUnequipTrailRemote,
		RequestEquipTitle = RequestEquipTitleRemote,
		RequestUnequipTitle = RequestUnequipTitleRemote,
		CosmeticsStatusUpdated = CosmeticsStatusUpdatedRemote,
	})
	local MockReplicatedStorage = fakeFolder("ReplicatedStorage", {
		Remotes = RemotesFolder,
	})

	local LocalPlayer = fakePlayer(601)
	local MockPlayers = {
		LocalPlayer = LocalPlayer,
	}

	local UIEventBus = loadModule("src/client/controllers/UIEventBus.luau", "UIEventBus", {
		task = task,
	})

	local CosmeticsController = loadModule("src/client/controllers/CosmeticsController.luau", "CosmeticsController", {
		game = {
			GetService = function(_self, ServiceName: string)
				if ServiceName == "ReplicatedStorage" then
					return MockReplicatedStorage
				elseif ServiceName == "Players" then
					return MockPlayers
				end
				return nil
			end,
		},
		task = task,
		script = {
			Parent = fakeFolder("controllers", {
				UIEventBus = UIEventBus,
			}),
		},
		require = function(Dependency)
			if Dependency == UIEventBus then
				return UIEventBus
			end
			return Dependency
		end,
	})

	CosmeticsController.Init()
	CosmeticsController.Start()

	-- 1. Open / Close modal
	CosmeticsController.Open()
	assert(CosmeticsController.IsOpen() == true, "Cosmetics modal should be open")
	CosmeticsController.Close()
	assert(CosmeticsController.IsOpen() == false, "Cosmetics modal should be closed")

	-- 2. Status update via remote
	local DummyStatus = {
		UnlockedTrails = { Default = true, FireTrail = true },
		EquippedTrail = "FireTrail",
		UnlockedTitles = { Newbie = true, Giant = true },
		EquippedTitle = "Giant",
	}
	CosmeticsStatusUpdatedRemote.OnClientEvent:Fire(DummyStatus)

	local Cached = CosmeticsController.GetStatus()
	assert(Cached ~= nil, "Cached status should exist")
	assert(Cached.EquippedTrail == "FireTrail", "EquippedTrail should be FireTrail")
	assert(Cached.EquippedTitle == "Giant", "EquippedTitle should be Giant")

	-- 3. Equip & Unequip methods firing remotes
	CosmeticsController.EquipTrail("FireTrail")
	assert(#RequestEquipTrailRemote.FiredServerEvents > 0, "EquipTrail should fire RequestEquipTrail")
	assert(RequestEquipTrailRemote.FiredServerEvents[1][1] == "FireTrail", "Remote payload must match trailId")

	CosmeticsController.UnequipTrail()
	assert(#RequestUnequipTrailRemote.FiredServerEvents > 0, "UnequipTrail should fire RequestUnequipTrail")

	CosmeticsController.EquipTitle("Giant")
	assert(#RequestEquipTitleRemote.FiredServerEvents > 0, "EquipTitle should fire RequestEquipTitle")
	assert(RequestEquipTitleRemote.FiredServerEvents[1][1] == "Giant", "Remote payload must match titleId")

	CosmeticsController.UnequipTitle()
	assert(#RequestUnequipTitleRemote.FiredServerEvents > 0, "UnequipTitle should fire RequestUnequipTitle")

	-- 4. UIEventBus events
	UIEventBus.Publish("OpenCosmetics")
	assert(CosmeticsController.IsOpen() == true, "UIEventBus OpenCosmetics should open modal")

	UIEventBus.Publish("CloseCosmetics")
	assert(CosmeticsController.IsOpen() == false, "UIEventBus CloseCosmetics should close modal")

	CosmeticsController.Destroy()
end)

print("\n=== TEST SUMMARY ===")
if #Failures > 0 then
	print(string.format("FAILED with %d error(s):", #Failures))
	for _, Failure in Failures do
		print(string.format(" - %s", Failure))
	end
	error(string.format("Unit tests failed with %d error(s)", #Failures))
else
	print("ALL MVP-006 TASK 9 TESTS PASSED")
end
