local fs = require("@lune/fs")
local luau = require("@lune/luau")
local task = require("@lune/task")

local Sessions = require("../../src/server/Core/Registry/RuntimeRegistry/Sessions")

local TEST_SYNTHETIC_VIP_PASS_ASSET_ID = 910001
local TEST_SYNTHETIC_PREMIUM_ZONE_PASS_ASSET_ID = 910002
local TEST_SYNTHETIC_WORLD1_TRIPLE_REWARD_PRODUCT_ID = 920001
local MAXIMUM_SAFE_INTEGER = 9007199254740991
local BULLET = utf8.char(0x2022)

local Failures = {}

local function check(Name, Callback)
	local Success, Message = pcall(Callback)
	if not Success then
		table.insert(Failures, string.format("%s: %s", Name, tostring(Message)))
	end
end

local function waitUntil(Predicate, Message)
	local Deadline = os.clock() + 1
	while not Predicate() and os.clock() < Deadline do
		task.wait()
	end
	assert(Predicate(), Message)
end

local function loadModule(Path, Name, Environment)
	assert(fs.isFile(Path), Name .. " production module is missing")
	local Chunk = luau.load(fs.readFile(Path), Name)
	setfenv(Chunk, setmetatable(Environment or {}, { __index = getfenv() }))
	return Chunk()
end

local function childContainer(Children)
	function Children:WaitForChild(Name)
		return assert(self[Name], "missing child " .. Name)
	end
	function Children:FindFirstChild(Name)
		return self[Name]
	end
	return Children
end

local function signal()
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

local function fakePlayer(UserId)
	local Player = {
		UserId = UserId,
		Name = "MVP005TestPlayer",
		Attributes = {},
	}
	function Player:SetAttribute(Key, Value)
		self.Attributes[Key] = Value
	end
	function Player:GetAttribute(Key)
		return self.Attributes[Key]
	end
	function Player:FindFirstChild(Name)
		return self[Name]
	end
	return Player
end

local function fakeSession(Player)
	return {
		Player = Player,
		Bigger = 1,
		Destruction = 0,
		Rebirth = 0,
		UnlockedGrowthUpgrades = {},
		CompletedPortals = {},
		Settings = { SoundEnabled = true, MusicEnabled = true },
		HasDoubleMultiplier = false,
		HasVip = false,
		HasPremiumZonePass = false,
		PurchaseHistory = {},
		ProfileMutationsFrozen = false,
		State = "InLobby",
		GrowthRemainder = 0,
		CurrentAFKZone = nil,
		PremiumZonePromptedThisEntry = false,
		GamePassQueryGenerations = { Vip = 0, PremiumZone = 0 },
	}
end

local function scaleCharacter()
	local Values = {
		BodyHeightScale = { Value = 1 },
		BodyWidthScale = { Value = 1 },
		BodyDepthScale = { Value = 1 },
		HeadScale = { Value = 1 },
	}
	local Humanoid = { AutomaticScalingEnabled = false }
	function Humanoid:WaitForChild(Name)
		return Values[Name]
	end
	local Head = {}
	function Head:FindFirstChild()
		return nil
	end
	local Character = {}
	function Character:FindFirstChildOfClass(Name)
		return if Name == "Humanoid" then Humanoid else nil
	end
	function Character:WaitForChild(Name)
		return if Name == "Head" then Head else nil
	end
	return Character, Humanoid, Values
end

local function loadCharacterScaleService(BiggerValues)
	local Players = {
		PlayerAdded = signal(),
		PlayerRemoving = signal(),
		Items = {},
	}
	function Players:GetPlayers()
		return self.Items
	end
	local EventBus = { Subscribers = {} }
	function EventBus.Subscribe(Name, Callback)
		EventBus.Subscribers[Name] = EventBus.Subscribers[Name] or {}
		table.insert(EventBus.Subscribers[Name], Callback)
		return {
			Disconnect = function()
				local Index = table.find(EventBus.Subscribers[Name], Callback)
				if Index then
					table.remove(EventBus.Subscribers[Name], Index)
				end
			end,
		}
	end
	function EventBus.Publish(Name, ...)
		for _, Callback in EventBus.Subscribers[Name] or {} do
			Callback(...)
		end
	end
	local ScaleCurve = require("../../src/shared/Core/Utilities/ScaleCurve")
	local ScaleConfig = require("../../src/shared/Core/Config/ScaleConfig")
	local ReplicatedStorage = childContainer({
		BiggerShared = childContainer({
			Core = childContainer({
				Utilities = childContainer({ ScaleCurve = ScaleCurve }),
				Config = childContainer({ ScaleConfig = ScaleConfig }),
			}),
		}),
	})
	local Game = {}
	function Game:GetService(Name)
		return if Name == "Players" then Players else ReplicatedStorage
	end
	local ServicesFolder = {}
	ServicesFolder.Parent = {
		Registry = { RuntimeRegistry = { Sessions = Sessions } },
		Events = { EventBus = EventBus },
		Utilities = { Logger = { Info = function() end, Warn = function() end } },
	}
	local PlayerStates = {}
	for Index, Bigger in BiggerValues do
		local Player = fakePlayer(6000 + Index)
		Player.CharacterAdded = signal()
		Player.CharacterAppearanceLoaded = signal()
		local Character, Humanoid, Values = scaleCharacter()
		Player.Character = Character
		local Session = fakeSession(Player)
		Session.Bigger = Bigger
		Sessions.Set(Player, Session)
		table.insert(Players.Items, Player)
		table.insert(PlayerStates, {
			Player = Player,
			Session = Session,
			Character = Character,
			Humanoid = Humanoid,
			Values = Values,
		})
	end
	local Service = loadModule("src/server/Core/Services/CharacterScaleService.luau", "CharacterScaleService", {
		game = Game,
		script = { Parent = ServicesFolder },
		require = function(Dependency)
			return Dependency
		end,
		task = {
			spawn = function(Callback, ...)
				Callback(...)
			end,
		},
	})
	return Service, Players, EventBus, PlayerStates
end

local function assertScale(Actual, Expected)
	assert(math.abs(Actual - Expected) < 1e-9, `expected scale {Expected}, got {Actual}`)
end

check("CharacterScaleService reapplies authoritative scale after appearance and Bigger changes", function()
	local Service, _, EventBus, States = loadCharacterScaleService({ 60416 })
	local State = States[1]
	Service:Init()
	Service:Start()
	local Expected = 1.8
	assertScale(State.Values.BodyHeightScale.Value, Expected)
	assert(State.Humanoid.AutomaticScalingEnabled == true)
	for _, Value in State.Values do
		Value.Value = 1
	end
	State.Player.CharacterAppearanceLoaded:Fire(State.Character)
	assertScale(State.Values.BodyHeightScale.Value, Expected)
	State.Session.Bigger = 1548396
	EventBus.Publish("BiggerChanged", State.Player, State.Session.Bigger)
	local GrownExpected = 2.8
	assertScale(State.Values.BodyHeightScale.Value, GrownExpected)
	assertScale(State.Values.BodyWidthScale.Value, GrownExpected)
	assertScale(State.Values.BodyDepthScale.Value, GrownExpected)
	assertScale(State.Values.HeadScale.Value, GrownExpected)
	Sessions.Remove(State.Player)
end)

check("CharacterScaleService owns one lifecycle per Player across respawn and removal", function()
	local Service, Players, _, States = loadCharacterScaleService({ 60416 })
	local State = States[1]
	Service:Init()
	Players.PlayerAdded:Fire(State.Player)
	Service:Start()
	assert(#State.Player.CharacterAdded.Callbacks == 1)
	assert(#State.Player.CharacterAppearanceLoaded.Callbacks == 1)
	local Replacement, _, ReplacementValues = scaleCharacter()
	State.Player.Character = Replacement
	State.Player.CharacterAdded:Fire(Replacement)
	State.Player.CharacterAppearanceLoaded:Fire(Replacement)
	local Expected = 1.8
	assertScale(ReplacementValues.BodyHeightScale.Value, Expected)
	Players.PlayerRemoving:Fire(State.Player)
	assert(#State.Player.CharacterAdded.Callbacks == 0)
	assert(#State.Player.CharacterAppearanceLoaded.Callbacks == 0)
	Sessions.Remove(State.Player)
end)

check("CharacterScaleService isolates two authoritative Player states", function()
	local Service, _, EventBus, States = loadCharacterScaleService({ 60416, 1548396 })
	Service:Init()
	Service:Start()
	local First, Second = States[1], States[2]
	local FirstExpected = 1.8
	local SecondExpected = 2.8
	assertScale(First.Values.BodyHeightScale.Value, FirstExpected)
	assertScale(Second.Values.BodyHeightScale.Value, SecondExpected)
	First.Session.Bigger = 78299136
	EventBus.Publish("BiggerChanged", First.Player, First.Session.Bigger)
	assertScale(First.Values.BodyHeightScale.Value, 5.8)
	assertScale(Second.Values.BodyHeightScale.Value, SecondExpected)
	Sessions.Remove(First.Player)
	Sessions.Remove(Second.Player)
end)

check("GamePassConfig uses explicit deferred placeholders for Vip and PremiumZone", function()
	assert(fs.isFile("src/server/Core/Config/GamePassConfig.luau"), "GamePassConfig production module is missing")
	local GamePassConfig = require("../../src/server/Core/Config/GamePassConfig")
	local Keys = {}
	for Key in GamePassConfig do
		table.insert(Keys, Key)
	end
	table.sort(Keys)
	assert(table.concat(Keys, ",") == "PremiumZone,Vip")
	assert(GamePassConfig.Vip.Price == 199)
	assert(GamePassConfig.PremiumZone.Price == 99)
	for _, Key in Keys do
		local AssetId = GamePassConfig[Key].AssetId or GamePassConfig[Key].GamePassId
		assert(AssetId == 0, Key .. " must use the explicit unconfigured placeholder")
	end
end)

local function loadGamePassService(QueryPlans, Options)
	Options = Options or {}
	local Player = fakePlayer(6101)
	local Session = fakeSession(Player)
	Sessions.Set(Player, Session)

	local GamePassConfig = Options.GamePassConfig
		or {
			Vip = { AssetId = TEST_SYNTHETIC_VIP_PASS_ASSET_ID, Price = 199, ProfileKey = "HasVip" },
			PremiumZone = {
				AssetId = TEST_SYNTHETIC_PREMIUM_ZONE_PASS_ASSET_ID,
				Price = 99,
				ProfileKey = "HasPremiumZonePass",
			},
		}
	local MarketplaceService = {
		PromptGamePassPurchaseFinished = signal(),
		Queries = {},
		Prompts = {},
	}
	function MarketplaceService:UserOwnsGamePassAsync(UserId, AssetId)
		assert(UserId == Player.UserId)
		self.Queries[AssetId] = (self.Queries[AssetId] or 0) + 1
		local Plan = assert(QueryPlans[AssetId][self.Queries[AssetId]], "missing synthetic ownership query plan")
		while Plan.Blocked do
			task.wait()
		end
		if Plan.Error then
			Plan.Completed = true
			error(Plan.Error)
		end
		Plan.Completed = true
		return Plan.Result
	end
	function MarketplaceService:PromptGamePassPurchase(PromptPlayer, AssetId)
		table.insert(self.Prompts, { PromptPlayer, AssetId })
	end

	local EventBus = { Subscribers = {} }
	function EventBus.Subscribe(Name, Callback)
		EventBus.Subscribers[Name] = EventBus.Subscribers[Name] or {}
		table.insert(EventBus.Subscribers[Name], Callback)
	end
	function EventBus.Publish(Name, ...)
		for _, Callback in EventBus.Subscribers[Name] or {} do
			Callback(...)
		end
	end

	local SaveService = { SaveCalls = 0 }
	function SaveService:IsProfileWritable()
		return not Session.ProfileMutationsFrozen
	end
	function SaveService:SaveProfile()
		self.SaveCalls += 1
	end
	local GrowthService = { UpdateCalls = 0 }
	function GrowthService:UpdateMultiplierAttribute()
		self.UpdateCalls += 1
	end
	local CharacterScaleService = { UpdateCalls = 0 }
	function CharacterScaleService:UpdateVipTag()
		self.UpdateCalls += 1
	end
	local ServiceRegistry = {}
	function ServiceRegistry.Get(Name)
		if Name == "SaveService" then
			return SaveService
		elseif Name == "GrowthService" then
			return GrowthService
		elseif Name == "CharacterScaleService" then
			return CharacterScaleService
		end
		error("unexpected service " .. Name)
	end

	local ServicesFolder = {}
	local Logger = { Warnings = {} }
	function Logger.Info() end
	function Logger.Warn(Category, Message, ...)
		table.insert(Logger.Warnings, { Category, string.format(Message, ...) })
	end
	local CoreFolder = {
		Config = { GamePassConfig = GamePassConfig },
		Events = { EventBus = EventBus },
		Registry = {
			ServiceRegistry = ServiceRegistry,
			RuntimeRegistry = { Sessions = Sessions },
		},
		Utilities = { Logger = Logger },
	}
	ServicesFolder.Parent = CoreFolder
	local Game = {}
	function Game:GetService(Name)
		if Name == "MarketplaceService" then
			return MarketplaceService
		end
		error("unexpected service " .. Name)
	end

	local Service = loadModule("src/server/Core/Services/GamePassService.luau", "GamePassService", {
		game = Game,
		script = { Parent = ServicesFolder },
		require = function(Dependency)
			return Dependency
		end,
		task = task,
	})
	Service:Init()
	return {
		CharacterScaleService = CharacterScaleService,
		EventBus = EventBus,
		GamePassConfig = GamePassConfig,
		GrowthService = GrowthService,
		MarketplaceService = MarketplaceService,
		Logger = Logger,
		Player = Player,
		SaveService = SaveService,
		Service = Service,
		Session = Session,
	}
end

check("missing GamePass IDs disable only those entitlements and warn once", function()
	local Harness = loadGamePassService({}, {
		GamePassConfig = {
			Vip = { AssetId = 0, Price = 199, ProfileKey = "HasVip" },
			PremiumZone = { AssetId = 0, Price = 99, ProfileKey = "HasPremiumZonePass" },
		},
	})
	Harness.Service:Init()
	assert(Harness.Service:GetConfigurationStatus("Vip").ErrorCode == "MissingAssetId")
	assert(Harness.Service:GetConfigurationStatus("PremiumZone").ErrorCode == "MissingAssetId")
	Harness.Session.HasVip = true
	Harness.Session.HasPremiumZonePass = true
	assert(Harness.Service:IsOwned(Harness.Player, "Vip") == false)
	assert(Harness.Service:IsOwned(Harness.Player, "PremiumZone") == false)
	assert(Harness.Service:Prompt(Harness.Player, "Vip") == false)
	Harness.EventBus.Publish("PlayerSessionCreated", Harness.Player, Harness.Session)
	task.wait()
	assert(next(Harness.MarketplaceService.Queries) == nil)
	assert(#Harness.Logger.Warnings == 2)
	assert(#Harness.EventBus.Subscribers.PlayerSessionCreated == 1)
	assert(#Harness.MarketplaceService.PromptGamePassPurchaseFinished.Callbacks == 1)
	Sessions.Remove(Harness.Player)
end)

check("GamePass queries coalesce changed entitlements into one save", function()
	local Harness = loadGamePassService({
		[TEST_SYNTHETIC_VIP_PASS_ASSET_ID] = { { Result = true } },
		[TEST_SYNTHETIC_PREMIUM_ZONE_PASS_ASSET_ID] = { { Result = true } },
	})
	Harness.EventBus.Publish("PlayerSessionCreated", Harness.Player, Harness.Session)
	waitUntil(function()
		return Harness.Session.HasVip and Harness.Session.HasPremiumZonePass
	end, "initial synthetic Game Pass queries did not apply")
	assert(Harness.SaveService.SaveCalls == 1)
	assert(Harness.Service:IsOwned(Harness.Player, "Vip") == true)
	assert(Harness.Service:IsOwned(Harness.Player, "PremiumZone") == true)
	Sessions.Remove(Harness.Player)
end)

check("stale GamePass results cannot overwrite a newer generation", function()
	local OldVipQuery = { Result = false, Blocked = true }
	local Harness = loadGamePassService({
		[TEST_SYNTHETIC_VIP_PASS_ASSET_ID] = { OldVipQuery, { Result = true } },
		[TEST_SYNTHETIC_PREMIUM_ZONE_PASS_ASSET_ID] = { { Result = false } },
	})
	Harness.EventBus.Publish("PlayerSessionCreated", Harness.Player, Harness.Session)
	waitUntil(function()
		return Harness.MarketplaceService.Queries[TEST_SYNTHETIC_VIP_PASS_ASSET_ID] == 1
	end, "first synthetic VIP query did not start")
	Harness.MarketplaceService.PromptGamePassPurchaseFinished:Fire(
		Harness.Player,
		TEST_SYNTHETIC_VIP_PASS_ASSET_ID,
		true
	)
	waitUntil(function()
		return Harness.Session.HasVip == true
	end, "newer synthetic VIP query did not apply")
	OldVipQuery.Blocked = false
	task.wait()
	assert(Harness.Session.HasVip == true)
	Sessions.Remove(Harness.Player)
end)

check("GamePass generations are independent per PassKey", function()
	local OldVipQuery = { Result = false, Blocked = true }
	local OldPremiumZoneQuery = { Result = true, Blocked = true }
	local Harness = loadGamePassService({
		[TEST_SYNTHETIC_VIP_PASS_ASSET_ID] = { OldVipQuery, { Result = true } },
		[TEST_SYNTHETIC_PREMIUM_ZONE_PASS_ASSET_ID] = { OldPremiumZoneQuery, { Result = false } },
	})
	Harness.EventBus.Publish("PlayerSessionCreated", Harness.Player, Harness.Session)
	waitUntil(function()
		return Harness.MarketplaceService.Queries[TEST_SYNTHETIC_VIP_PASS_ASSET_ID] == 1
			and Harness.MarketplaceService.Queries[TEST_SYNTHETIC_PREMIUM_ZONE_PASS_ASSET_ID] == 1
	end, "overlapping synthetic Game Pass queries did not start")

	Harness.MarketplaceService.PromptGamePassPurchaseFinished:Fire(
		Harness.Player,
		TEST_SYNTHETIC_VIP_PASS_ASSET_ID,
		true
	)
	waitUntil(function()
		return Harness.Session.HasVip == true
	end, "newer synthetic VIP generation did not apply")
	OldPremiumZoneQuery.Blocked = false
	waitUntil(function()
		return Harness.Session.HasPremiumZonePass == true
	end, "VIP generation incorrectly invalidated PremiumZone generation")
	OldVipQuery.Blocked = false
	task.wait()
	assert(Harness.Session.HasVip == true, "stale VIP generation overwrote the newer VIP result")

	Harness.MarketplaceService.PromptGamePassPurchaseFinished:Fire(
		Harness.Player,
		TEST_SYNTHETIC_PREMIUM_ZONE_PASS_ASSET_ID,
		true
	)
	waitUntil(function()
		return Harness.Session.HasPremiumZonePass == false
	end, "newer synthetic PremiumZone generation did not apply")
	assert(Harness.Session.HasVip == true, "PremiumZone generation changed VIP ownership")
	Sessions.Remove(Harness.Player)
end)

check("GamePass query errors preserve saved true and false values", function()
	local Harness = loadGamePassService({
		[TEST_SYNTHETIC_VIP_PASS_ASSET_ID] = { { Error = "TEST_SYNTHETIC_VIP_QUERY_FAILURE" } },
		[TEST_SYNTHETIC_PREMIUM_ZONE_PASS_ASSET_ID] = {
			{ Error = "TEST_SYNTHETIC_PREMIUM_ZONE_QUERY_FAILURE" },
		},
	})
	Harness.Session.HasVip = true
	Harness.Session.HasPremiumZonePass = false
	Harness.EventBus.Publish("PlayerSessionCreated", Harness.Player, Harness.Session)
	waitUntil(function()
		return Harness.MarketplaceService.Queries[TEST_SYNTHETIC_VIP_PASS_ASSET_ID] == 1
			and Harness.MarketplaceService.Queries[TEST_SYNTHETIC_PREMIUM_ZONE_PASS_ASSET_ID] == 1
	end, "synthetic failing Game Pass queries did not run")
	task.wait()
	assert(Harness.Session.HasVip == true, "failed VIP query cleared saved true ownership")
	assert(Harness.Session.HasPremiumZonePass == false, "failed PremiumZone query overwrote saved false ownership")
	assert(Harness.SaveService.SaveCalls == 0, "failed Game Pass queries queued a save")
	Sessions.Remove(Harness.Player)
end)

check("prompt-finished re-queries instead of trusting wasPurchased", function()
	local Harness = loadGamePassService({
		[TEST_SYNTHETIC_VIP_PASS_ASSET_ID] = { { Result = false }, { Result = false } },
		[TEST_SYNTHETIC_PREMIUM_ZONE_PASS_ASSET_ID] = { { Result = false } },
	})
	Harness.EventBus.Publish("PlayerSessionCreated", Harness.Player, Harness.Session)
	waitUntil(function()
		return Harness.MarketplaceService.Queries[TEST_SYNTHETIC_VIP_PASS_ASSET_ID] == 1
	end, "initial synthetic VIP query did not finish")
	Harness.MarketplaceService.PromptGamePassPurchaseFinished:Fire(
		Harness.Player,
		TEST_SYNTHETIC_VIP_PASS_ASSET_ID,
		true
	)
	waitUntil(function()
		return Harness.MarketplaceService.Queries[TEST_SYNTHETIC_VIP_PASS_ASSET_ID] == 2
	end, "purchase-finished did not start a fresh query")
	assert(Harness.Session.HasVip == false)
	assert(Harness.Service:Prompt(Harness.Player, "Vip") == true)
	assert(Harness.MarketplaceService.Prompts[1][2] == TEST_SYNTHETIC_VIP_PASS_ASSET_ID)
	assert(Harness.Service:Prompt(Harness.Player, "Unknown") == false)
	Sessions.Remove(Harness.Player)
end)

check("GamePass prompts reject frozen sessions", function()
	local Harness = loadGamePassService({
		[TEST_SYNTHETIC_VIP_PASS_ASSET_ID] = { { Result = false } },
		[TEST_SYNTHETIC_PREMIUM_ZONE_PASS_ASSET_ID] = { { Result = false } },
	})
	Harness.Session.ProfileMutationsFrozen = true
	assert(Harness.Service:Prompt(Harness.Player, "Vip") == false)
	assert(#Harness.MarketplaceService.Prompts == 0)
	Sessions.Remove(Harness.Player)
end)

check("GamePass prompts reject missing sessions", function()
	local Harness = loadGamePassService({
		[TEST_SYNTHETIC_VIP_PASS_ASSET_ID] = { { Result = false } },
		[TEST_SYNTHETIC_PREMIUM_ZONE_PASS_ASSET_ID] = { { Result = false } },
	})
	local PromptCount = #Harness.MarketplaceService.Prompts
	Sessions.Remove(Harness.Player)
	assert(Harness.Service:Prompt(Harness.Player, "Vip") == false)
	assert(#Harness.MarketplaceService.Prompts == PromptCount)
	Sessions.Remove(Harness.Player)
end)

check("stale GamePass batches never save a replacement session", function()
	local PremiumZoneQuery = { Result = false, Blocked = true }
	local Harness = loadGamePassService({
		[TEST_SYNTHETIC_VIP_PASS_ASSET_ID] = { { Result = true } },
		[TEST_SYNTHETIC_PREMIUM_ZONE_PASS_ASSET_ID] = { PremiumZoneQuery },
	})
	Harness.EventBus.Publish("PlayerSessionCreated", Harness.Player, Harness.Session)
	waitUntil(function()
		return Harness.Session.HasVip == true
	end, "first synthetic Game Pass result did not apply")
	Sessions.Set(Harness.Player, fakeSession(Harness.Player))
	PremiumZoneQuery.Blocked = false
	waitUntil(function()
		return PremiumZoneQuery.Completed == true
	end, "second synthetic Game Pass query did not complete")
	assert(Harness.SaveService.SaveCalls == 0, "stale batch saved the replacement session")
	Sessions.Remove(Harness.Player)
end)

check("Developer Product config exposes one portal-only 29 Robux triple reward", function()
	local RewardType = { Bigger = "Bigger", Destruction = "Destruction" }
	local ReplicatedStorage = childContainer({
		BiggerShared = childContainer({
			Core = childContainer({ Enums = childContainer({ RewardType = RewardType }) }),
		}),
	})
	local Game = {}
	function Game:GetService(Name)
		assert(Name == "ReplicatedStorage")
		return ReplicatedStorage
	end
	local Products = loadModule("src/server/Core/Config/DeveloperProductConfig.luau", "DeveloperProductConfig", {
		game = Game,
		require = function(Dependency)
			return Dependency
		end,
	})
	local PortalProducts = {}
	local PortalProductCount = 0
	for Key, Product in Products do
		if Product.Surface == "PortalOnly" then
			PortalProducts[Key] = Product
			PortalProductCount += 1
		else
			assert(Product.Surface == "Shop")
		end
	end
	local Product = PortalProducts.World1TripleReward
	assert(Product ~= nil and PortalProductCount == 1)
	for ProductKey in Products do
		local LowerProductKey = string.lower(ProductKey)
		assert(
			not (
					string.find(LowerProductKey, "world1", 1, true)
					and (
						string.find(LowerProductKey, "vip", 1, true)
						or string.find(LowerProductKey, "discount", 1, true)
					)
				),
			"forbidden VIP-discount WORLD1 Developer Product key is present: " .. ProductKey
		)
	end
	assert(Products.World1TripleRewardVip == nil, "forbidden World1TripleRewardVip product is present")
	assert(Products.World1TripleRewardVipDiscount == nil, "forbidden World1TripleRewardVipDiscount product is present")
	assert(Product.Price == 29)
	assert(Product.ProductId == 0, "World1TripleReward must use the explicit unconfigured placeholder")
	assert(#Product.Rewards == 1)
	assert(Product.Rewards[1].Type == "Destruction")
	assert(Product.Rewards[1].Amount == 3)
end)

local function loadDestructionService()
	local Player = fakePlayer(6201)
	local Session = fakeSession(Player)
	Session.State = "InWorld"
	Session.CurrentWorldInstanceId = "TEST_WORLD_1"
	Sessions.Set(Player, Session)
	local DestructionStat = { Value = 0 }
	function DestructionStat:IsA(Name)
		return Name == "IntValue"
	end
	Player.leaderstats = {}
	function Player.leaderstats:FindFirstChild(Name)
		return if Name == "Destruction" then DestructionStat else nil
	end

	local Players = {}
	function Players:GetPlayerFromCharacter(Character)
		return if Character == Player.Character then Player else nil
	end
	local Debris = { Items = {} }
	function Debris:AddItem(Item, Lifetime)
		table.insert(self.Items, { Item = Item, Lifetime = Lifetime })
	end
	local RewardPortalService = { ActivationCalls = 0 }
	function RewardPortalService:ActivateChoices(WorldInstance)
		self.ActivationCalls += 1
		WorldInstance.RewardState = "Choosing"
		return true
	end
	local SessionService = {}
	function SessionService:TransitionState(TargetPlayer, Expected, Next)
		local Current = Sessions.Get(TargetPlayer)
		if not Current or Current.State ~= Expected then
			return false
		end
		Current.State = Next
		return true
	end
	local ServiceRegistry = {}
	function ServiceRegistry.Get(Name)
		if Name == "RewardPortalService" then
			return RewardPortalService
		elseif Name == "SessionService" then
			return SessionService
		end
		error("unexpected service " .. Name)
	end

	local World1Config = {
		ReturnPortalDebounceSeconds = 1.5,
		Objective = {
			ModelName = "Spider",
			HitboxName = "ObjectiveHitbox",
			DestructionReward = 1,
			HorizontalPadding = 1,
			MaximumRootHeight = 8,
			MinimumDownwardVelocity = -2,
		},
	}
	local StompValidation = {}
	function StompValidation.IsValid()
		return true
	end
	local ReplicatedStorage = {
		BiggerShared = { Core = { Utilities = { StompValidation = StompValidation } } },
	}
	local Game = {}
	function Game:GetService(Name)
		if Name == "Players" then
			return Players
		elseif Name == "Debris" then
			return Debris
		end
		return ReplicatedStorage
	end
	local ServicesFolder = {}
	local Logger = { Warnings = {} }
	function Logger.Warn(Category, Message, ...)
		table.insert(Logger.Warnings, Category .. ": " .. string.format(Message, ...))
	end
	local GameFolder = {
		Config = { World1Config = World1Config },
		Parent = {
			Core = {
				Registry = { RuntimeRegistry = { Sessions = Sessions }, ServiceRegistry = ServiceRegistry },
				Utilities = { Logger = Logger },
			},
		},
	}
	ServicesFolder.Parent = GameFolder
	local Service = loadModule("src/server/Game/Services/DestructionService.luau", "DestructionService", {
		game = Game,
		Vector3 = {
			new = function(X, Y, Z)
				return { X = X, Y = Y, Z = Z }
			end,
		},
		script = { Parent = ServicesFolder },
		require = function(Dependency)
			return Dependency
		end,
		task = {
			delay = function(_, Callback)
				Callback()
			end,
		},
	})
	return {
		Debris = Debris,
		DestructionStat = DestructionStat,
		Logger = Logger,
		Player = Player,
		RewardPortalService = RewardPortalService,
		Service = Service,
		Session = Session,
	}
end

check("GrantDestruction validates safe integers and synchronizes presentation", function()
	local Harness = loadDestructionService()
	for _, InvalidAmount in { 0, -1, 1.5, 0 / 0, math.huge, MAXIMUM_SAFE_INTEGER + 1 } do
		assert(Harness.Service:GrantDestruction(Harness.Player, InvalidAmount) == false)
	end
	assert(Harness.Service:GrantDestruction(Harness.Player, 3) == true)
	assert(Harness.Session.Destruction == 3)
	assert(Harness.Player.Attributes.Destruction == 3)
	assert(Harness.DestructionStat.Value == 3)
	Harness.Session.Destruction = MAXIMUM_SAFE_INTEGER
	assert(Harness.Service:GrantDestruction(Harness.Player, 1) == false)
	assert(Harness.Session.Destruction == MAXIMUM_SAFE_INTEGER)
	Harness.Session.ProfileMutationsFrozen = true
	assert(Harness.Service:GrantDestruction(Harness.Player, 1) == false)
	Sessions.Remove(Harness.Player)
end)

check("GrantDestruction keeps committed success when presentation sync fails", function()
	local Harness = loadDestructionService()
	function Harness.Player:SetAttribute(Key, Value)
		if Key == "Destruction" then
			error("expected synthetic presentation failure")
		end
		self.Attributes[Key] = Value
	end

	local Attempts = 0
	local Granted = false
	repeat
		Attempts += 1
		Granted = Harness.Service:GrantDestruction(Harness.Player, 3)
	until Granted or Attempts == 2
	local Destruction = Harness.Session.Destruction
	local WarningCount = #Harness.Logger.Warnings
	Sessions.Remove(Harness.Player)

	assert(Granted == true, "committed Destruction was reported as failed")
	assert(Attempts == 1, "false-after-commit caused a retry")
	assert(Destruction == 3, "presentation failure rolled back or double-granted Destruction")
	assert(WarningCount == 1, "presentation failure was not logged exactly once")
end)

check("stomp stays gated until initialization and completes exactly once", function()
	local Harness = loadDestructionService()
	Harness.Player:SetAttribute("ObjectiveActive", true)
	local Position = { X = 0, Y = 1, Z = 0 }
	local Vector = setmetatable({ X = 2, Y = 2, Z = 2 }, {
		__div = function(Value, Divisor)
			return { X = Value.X / Divisor, Y = Value.Y / Divisor, Z = Value.Z / Divisor }
		end,
	})
	local RootPart = { Position = Position, AssemblyLinearVelocity = { Y = -10 } }
	function RootPart:IsA(Name)
		return Name == "BasePart"
	end
	local Character = {}
	function Character:FindFirstChild(Name)
		return if Name == "HumanoidRootPart" then RootPart else nil
	end
	Harness.Player.Character = Character
	local Hit = {}
	function Hit:FindFirstAncestorOfClass(Name)
		return if Name == "Model" then Character else nil
	end
	local Hitbox = {
		CFrame = {
			PointToObjectSpace = function(_, Value)
				return Value
			end,
		},
		Size = Vector,
		CanTouch = true,
		Transparency = 0,
		Parent = {},
	}
	local WorldInstance = {
		WorldInstanceId = "TEST_WORLD_1",
		OwnerUserId = Harness.Player.UserId,
		OwnerPlayer = Harness.Player,
		ObjectiveActive = true,
		ObjectiveInitialized = false,
		ObjectiveCompleted = false,
		RewardState = "Inactive",
	}
	local WorldCoordinator = { ReturnCalls = 0, RecoverCalls = 0 }
	function WorldCoordinator:ReturnPlayerToLobby()
		self.ReturnCalls += 1
		return true
	end
	function WorldCoordinator:RecoverPlayer()
		self.RecoverCalls += 1
	end
	Harness.Service:TryCompleteObjective(WorldInstance, Hitbox, Hit, WorldCoordinator)
	assert(WorldInstance.ObjectiveCompleted == false)
	assert(Harness.RewardPortalService.ActivationCalls == 0)
	WorldInstance.ObjectiveInitialized = true
	Harness.Service:TryCompleteObjective(WorldInstance, Hitbox, Hit, WorldCoordinator)
	assert(WorldInstance.ObjectiveCompleted == true)
	assert(WorldInstance.ObjectiveActive == false)
	assert(Harness.Player:GetAttribute("ObjectiveActive") == false)
	assert(WorldInstance.RewardState == "Choosing")
	assert(Harness.RewardPortalService.ActivationCalls == 1)
	assert(Harness.Session.State == "InWorld")
	assert(Harness.Session.Destruction == 0)
	assert(WorldCoordinator.ReturnCalls == 0 and WorldCoordinator.RecoverCalls == 0)
	Harness.Service:TryCompleteObjective(WorldInstance, Hitbox, Hit, WorldCoordinator)
	assert(Harness.RewardPortalService.ActivationCalls == 1)
	Sessions.Remove(Harness.Player)
end)

local function fakeInstance(Name, ClassName)
	local Instance = {
		Name = Name,
		ClassName = ClassName,
		Children = {},
		Transparency = 0,
		CanTouch = false,
		CanCollide = false,
		CanQuery = false,
		Touched = signal(),
	}
	function Instance:IsA(Expected)
		return self.ClassName == Expected or (Expected == "BasePart" and self.ClassName == "Part")
	end
	function Instance:FindFirstChild(ChildName, Recursive)
		local Child = self.Children[ChildName]
		if Child or not Recursive then
			return Child
		end
		for _, Descendant in self.Children do
			local Found = Descendant:FindFirstChild(ChildName, true)
			if Found then
				return Found
			end
		end
		return nil
	end
	function Instance:GetChildren()
		local Children = {}
		for _, Child in self.Children do
			table.insert(Children, Child)
		end
		return Children
	end
	function Instance:GetDescendants()
		local Descendants = {}
		local function Visit(Parent)
			for _, Child in Parent.Children do
				table.insert(Descendants, Child)
				Visit(Child)
			end
		end
		Visit(self)
		return Descendants
	end
	function Instance:AddChild(Child)
		self.Children[Child.Name] = Child
		Child.Parent = self
		return Child
	end
	return Instance
end

local function rewardPortalModel(Name)
	local Model = fakeInstance(Name, "Model")
	Model:AddChild(fakeInstance("Visual", "Part"))
	Model:AddChild(fakeInstance("Trigger", "Part"))
	local LabelPart = Model:AddChild(fakeInstance("LabelPart", "Part"))
	local SurfaceGui = LabelPart:AddChild(fakeInstance("SurfaceGui", "SurfaceGui"))
	local TextLabel = SurfaceGui:AddChild(fakeInstance("TextLabel", "TextLabel"))
	TextLabel.Text = ""
	return Model
end

check("DestructionService binds before arming the objective", function()
	local Harness = loadDestructionService()
	Harness.Session.State = "InWorld"
	Harness.Session.CurrentWorldInstanceId = "TEST_WORLD"
	local WorldModel = fakeInstance("TEST_WORLD", "Model")
	local Spider = WorldModel:AddChild(fakeInstance("Spider", "Model"))
	local Hitbox = Spider:AddChild(fakeInstance("ObjectiveHitbox", "Part"))
	local VisualA = Spider:AddChild(fakeInstance("VisualA", "Part"))
	local VisualB = Spider:AddChild(fakeInstance("VisualB", "Part"))
	VisualA.Anchored = true
	VisualA.CanCollide = true
	VisualA.CanTouch = true
	VisualA.CanQuery = true
	VisualA.Position = { X = -2, Y = 0, Z = 0 }
	VisualB.Anchored = true
	VisualB.CanCollide = true
	VisualB.CanTouch = true
	VisualB.CanQuery = true
	VisualB.Position = { X = 2, Y = 0, Z = 0 }
	Hitbox.Position = { X = 0, Y = 0, Z = 0 }
	Hitbox.CFrame = {
		PointToObjectSpace = function(_, Value)
			return Value
		end,
	}
	Hitbox.Size = setmetatable({ X = 2, Y = 2, Z = 2 }, {
		__div = function(Value, Divisor)
			return { X = Value.X / Divisor, Y = Value.Y / Divisor, Z = Value.Z / Divisor }
		end,
	})
	Hitbox.CanTouch = true
	local WorldInstance = {
		WorldInstanceId = "TEST_WORLD",
		OwnerUserId = Harness.Player.UserId,
		OwnerPlayer = Harness.Player,
		Model = WorldModel,
		ObjectiveActive = false,
		ObjectiveInitialized = false,
		ObjectiveCompleted = false,
		RewardState = "Inactive",
		Connections = {},
	}
	assert(Harness.Service:BindWorld(WorldInstance, {}) == true)
	assert(Hitbox.CanTouch == false)
	assert(WorldInstance.ObjectiveInitialized == false)
	assert(Harness.Service:ActivateWorld(WorldInstance) == true)
	assert(Hitbox.CanTouch == true)
	assert(WorldInstance.ObjectiveInitialized == true)
	assert(WorldInstance.ObjectiveActive == true)
	assert(Harness.Service:ActivateWorld(WorldInstance) == false)
	local RootPart = { Position = { X = 0, Y = 1, Z = 0 }, AssemblyLinearVelocity = { Y = -10 } }
	function RootPart:IsA(Name)
		return Name == "BasePart"
	end
	local Character = {}
	function Character:FindFirstChild(Name)
		return if Name == "HumanoidRootPart" then RootPart else nil
	end
	Harness.Player.Character = Character
	local Hit = {}
	function Hit:FindFirstAncestorOfClass(Name)
		return if Name == "Model" then Character else nil
	end
	Hitbox.Touched:Fire(Hit)
	assert(WorldInstance.ObjectiveCompleted == true)
	assert(Hitbox.CanTouch == false and Hitbox.Anchored ~= false)
	for _, Visual in { VisualA, VisualB } do
		assert(Visual.Anchored == false)
		assert(Visual.CanCollide == false and Visual.CanTouch == false and Visual.CanQuery == false)
		assert(Visual.AssemblyLinearVelocity ~= nil and Visual.AssemblyAngularVelocity ~= nil)
	end
	assert(#Harness.Debris.Items == 2)
	for _, Item in Harness.Debris.Items do
		assert(Item.Item ~= Hitbox and Item.Lifetime >= 1.5 and Item.Lifetime <= 3)
	end
	Hitbox.Touched:Fire(Hit)
	assert(#Harness.Debris.Items == 2, "duplicate stomp scheduled duplicate fragments")
	Sessions.Remove(Harness.Player)
end)

check("PortalService arms the objective only after entering InWorld", function()
	local Player = fakePlayer(6249)
	local Session = fakeSession(Player)
	Session.Bigger = 60416
	Session.State = "InLobby"
	Session.CurrentWorldInstanceId = nil
	Sessions.Set(Player, Session)
	local Character = {}
	Player.Character = Character
	local Hit = {}
	function Hit:FindFirstAncestorOfClass(Name)
		return if Name == "Model" then Character else nil
	end
	local Players = {}
	function Players:GetPlayerFromCharacter(Target)
		return if Target == Character then Player else nil
	end
	local Workspace = {}
	function Workspace:FindFirstChild()
		return nil
	end
	local LevelFormula = {
		GetLevelFromBigger = function()
			return 5
		end,
	}
	local ReplicatedStorage = childContainer({
		BiggerShared = childContainer({
			Game = childContainer({ Progression = childContainer({ LevelFormula = LevelFormula }) }),
		}),
	})
	local Game = {}
	function Game:GetService(Name)
		if Name == "Workspace" then
			return Workspace
		elseif Name == "ReplicatedStorage" then
			return ReplicatedStorage
		end
		assert(Name == "Players")
		return Players
	end
	local ServiceRegistry = {
		Get = function()
			error("unexpected registry lookup")
		end,
	}
	local World1Config = {
		PortalName = "Portal_World1",
		RequiredLevel = 5,
		ReturnPortalDebounceSeconds = 1.5,
	}
	local ServicesFolder = {}
	ServicesFolder.Parent = {
		Config = { World1Config = World1Config },
		Parent = {
			Core = {
				Registry = { RuntimeRegistry = { Sessions = Sessions }, ServiceRegistry = ServiceRegistry },
				Utilities = { Logger = { Warn = function() end } },
			},
		},
	}
	local Service = loadModule("src/server/Game/Services/PortalService.luau", "PortalService", {
		game = Game,
		script = { Parent = ServicesFolder },
		require = function(Dependency)
			return Dependency
		end,
		task = { delay = function() end },
	})
	local SessionService = {}
	function SessionService:TransitionState(TargetPlayer, Expected, Next)
		assert(TargetPlayer == Player and Session.State == Expected)
		Session.State = Next
		return true
	end
	local WorldInstance = { WorldInstanceId = "TEST_WORLD" }
	local WorldInstanceService = { CreateState = nil, ActivateState = nil, ActivateCalls = 0 }
	function WorldInstanceService:GetPlayerWorld()
		return nil
	end
	function WorldInstanceService:CreateWorldForPlayer()
		self.CreateState = Session.State
		return WorldInstance
	end
	function WorldInstanceService:ActivateWorld(TargetPlayer)
		assert(TargetPlayer == Player)
		self.ActivateCalls += 1
		self.ActivateState = Session.State
		return true
	end
	Service:TryEnterPortal(Hit, SessionService, WorldInstanceService)
	assert(WorldInstanceService.CreateState == "EnteringWorld")
	assert(Session.State == "InWorld")
	assert(WorldInstanceService.ActivateCalls == 1)
	assert(WorldInstanceService.ActivateState == "InWorld")
	Sessions.Remove(Player)
end)

local function loadRewardPortalService(ProductId)
	ProductId = if ProductId == nil then TEST_SYNTHETIC_WORLD1_TRIPLE_REWARD_PRODUCT_ID else ProductId
	local Player = fakePlayer(6251)
	local Session = fakeSession(Player)
	Session.State = "InWorld"
	Session.CurrentWorldInstanceId = "TEST_REWARD_WORLD_1"
	Sessions.Set(Player, Session)
	local Character = {}
	Player.Character = Character
	local Hit = {}
	function Hit:FindFirstAncestorOfClass(Name)
		return if Name == "Model" then Character else nil
	end
	local OtherPlayer = fakePlayer(6252)
	local OtherCharacter = {}
	OtherPlayer.Character = OtherCharacter
	local OtherHit = {}
	function OtherHit:FindFirstAncestorOfClass(Name)
		return if Name == "Model" then OtherCharacter else nil
	end

	local WorldModel = fakeInstance("TEST_REWARD_WORLD_1", "Model")
	local FreePortal = WorldModel:AddChild(rewardPortalModel("FreeRewardPortal"))
	local PaidPortal = WorldModel:AddChild(rewardPortalModel("PaidRewardPortal"))
	local WorldInstance = {
		WorldInstanceId = "TEST_REWARD_WORLD_1",
		OwnerUserId = Player.UserId,
		OwnerPlayer = Player,
		Model = WorldModel,
		ObjectiveActive = false,
		ObjectiveCompleted = true,
		RewardState = "Inactive",
		PendingRewardPrompt = nil,
		Connections = {},
	}

	local Players = {}
	function Players:GetPlayerFromCharacter(TargetCharacter)
		if TargetCharacter == Character then
			return Player
		elseif TargetCharacter == OtherCharacter then
			return OtherPlayer
		end
		return nil
	end
	function Players:GetPlayerByUserId(UserId)
		if UserId == Player.UserId then
			return Player
		elseif UserId == OtherPlayer.UserId then
			return OtherPlayer
		end
		return nil
	end
	local MarketplaceService = {
		PromptProductPurchaseFinished = signal(),
		Prompts = {},
	}
	function MarketplaceService:PromptProductPurchase(PromptPlayer, ProductId)
		table.insert(self.Prompts, { PromptPlayer, ProductId })
	end
	local HttpService = {}
	function HttpService:GenerateGUID()
		return "TEST_SYNTHETIC_PROMPT_TOKEN"
	end

	local EventBus = { Subscribers = {} }
	function EventBus.Subscribe(Name, Callback)
		EventBus.Subscribers[Name] = EventBus.Subscribers[Name] or {}
		table.insert(EventBus.Subscribers[Name], Callback)
	end
	function EventBus.Publish(Name, ...)
		for _, Callback in EventBus.Subscribers[Name] or {} do
			Callback(...)
		end
	end
	local WorldInstances = {}
	function WorldInstances.Get(TargetPlayer)
		return if TargetPlayer == Player then WorldInstance else nil
	end
	local DestructionService = { Calls = {} }
	function DestructionService:GrantDestruction(TargetPlayer, Amount)
		table.insert(self.Calls, { TargetPlayer, Amount })
		Session.Destruction += Amount
		return true
	end
	local SessionService = { ThrowOnTransition = false }
	function SessionService:TransitionState(TargetPlayer, Expected, Next)
		if self.ThrowOnTransition then
			error("transition failed")
		end
		local Current = Sessions.Get(TargetPlayer)
		if not Current or Current.State ~= Expected then
			return false
		end
		Current.State = Next
		return true
	end
	local SaveService = {}
	function SaveService:IsProfileWritable()
		return not Session.ProfileMutationsFrozen
	end
	local ServiceRegistry = {}
	function ServiceRegistry.Get(Name)
		if Name == "DestructionService" then
			return DestructionService
		elseif Name == "SessionService" then
			return SessionService
		elseif Name == "SaveService" then
			return SaveService
		end
		error("unexpected service " .. Name)
	end

	local DeveloperProductConfig = {
		World1TripleReward = {
			ProductId = ProductId,
			Price = 29,
			Surface = "PortalOnly",
			Rewards = { { Type = "Destruction", Amount = 3 } },
		},
	}
	local ConfigValidationService = {}
	function ConfigValidationService:GetDeveloperProductStatus()
		return if ProductId > 0
			then { IsConfigured = true }
			else { IsConfigured = false, ErrorCode = "MissingProductId" }
	end
	local World1Config = {
		RewardProductKey = "World1TripleReward",
		RewardPortals = {
			FreeName = "FreeRewardPortal",
			PaidName = "PaidRewardPortal",
			FreeDestruction = 1,
			FreeLabel = "FREE\n+1 DESTRUCTION",
			PaidLabel = "3 DESTRUCTION " .. BULLET .. " 29 R$",
		},
	}
	local ServicesFolder = {}
	local GameFolder = {
		Config = { World1Config = World1Config },
		Parent = {
			Core = {
				Config = { DeveloperProductConfig = DeveloperProductConfig },
				Services = { ConfigValidationService = ConfigValidationService },
				Events = { EventBus = EventBus },
				Registry = {
					ServiceRegistry = ServiceRegistry,
					RuntimeRegistry = { Sessions = Sessions, WorldInstances = WorldInstances },
				},
				Utilities = { Logger = { Info = function() end, Warn = function() end } },
			},
		},
	}
	ServicesFolder.Parent = GameFolder
	local Game = {}
	function Game:GetService(Name)
		if Name == "MarketplaceService" then
			return MarketplaceService
		elseif Name == "Players" then
			return Players
		elseif Name == "HttpService" then
			return HttpService
		end
		error("unexpected service " .. Name)
	end
	local Service = loadModule("src/server/Game/Services/RewardPortalService.luau", "RewardPortalService", {
		game = Game,
		script = { Parent = ServicesFolder },
		require = function(Dependency)
			return Dependency
		end,
	})
	Service:Init()
	local Coordinator = { ReturnCalls = 0, RecoverCalls = 0, ThrowOnReturn = false }
	function Coordinator:ReturnPlayerToLobby(TargetPlayer)
		assert(TargetPlayer == Player)
		if self.ThrowOnReturn then
			error("return failed")
		end
		self.ReturnCalls += 1
		return true
	end
	function Coordinator:RecoverPlayer(TargetPlayer)
		assert(TargetPlayer == Player)
		self.RecoverCalls += 1
		Session.State = "InLobby"
	end
	return {
		Coordinator = Coordinator,
		DestructionService = DestructionService,
		EventBus = EventBus,
		FreePortal = FreePortal,
		Hit = Hit,
		MarketplaceService = MarketplaceService,
		OtherHit = OtherHit,
		PaidPortal = PaidPortal,
		Player = Player,
		Service = Service,
		Session = Session,
		SessionService = SessionService,
		WorldInstance = WorldInstance,
	}
end

check("unconfigured paid reward stays unavailable without blocking free reward", function()
	local Harness = loadRewardPortalService(0)
	assert(Harness.Service:BindWorld(Harness.WorldInstance, Harness.Coordinator) == true)
	assert(Harness.Service:ActivateChoices(Harness.WorldInstance, Harness.Coordinator) == true)
	local Status = Harness.Service:GetPaidRewardStatus()
	assert(Status.IsConfigured == false and Status.ErrorCode == "MissingProductId")
	assert(Harness.FreePortal.Children.Trigger.CanTouch == true)
	assert(Harness.PaidPortal.Children.Trigger.CanTouch == false)
	assert(Harness.PaidPortal.Children.Visual.Transparency == 0)
	assert(Harness.PaidPortal.Children.LabelPart.Children.SurfaceGui.Enabled == true)
	assert(Harness.PaidPortal.Children.LabelPart.Children.SurfaceGui.Children.TextLabel.Text == "UNAVAILABLE")
	Harness.PaidPortal.Children.Trigger.Touched:Fire(Harness.Hit)
	assert(#Harness.MarketplaceService.Prompts == 0)
	assert(Harness.WorldInstance.RewardState == "Choosing")
	Harness.FreePortal.Children.Trigger.Touched:Fire(Harness.Hit)
	assert(#Harness.DestructionService.Calls == 1)
	Sessions.Remove(Harness.Player)
end)

check("reward choice hierarchy is exactly Free and Paid", function()
	local Harness = loadRewardPortalService(0)
	assert(Harness.Service:BindWorld(Harness.WorldInstance, Harness.Coordinator) == true)
	assert(#Harness.WorldInstance.Connections == 2)
	assert(Harness.WorldInstance.Model.Children.FreeRewardPortal ~= nil)
	assert(Harness.WorldInstance.Model.Children.PaidRewardPortal ~= nil)
	assert(Harness.FreePortal.Children.LabelPart.Children.SurfaceGui.Children.TextLabel.Text == "FREE\n+1 DESTRUCTION")
	Sessions.Remove(Harness.Player)
end)

check("free reward settles once and never invokes the paid prompt", function()
	local Harness = loadRewardPortalService()
	assert(Harness.Service:BindWorld(Harness.WorldInstance, Harness.Coordinator) == true)
	assert(Harness.WorldInstance.RewardState == "Inactive")
	assert(Harness.Service:ActivateChoices(Harness.WorldInstance, Harness.Coordinator) == true)
	assert(Harness.WorldInstance.RewardState == "Choosing")
	Harness.FreePortal.Children.Trigger.Touched:Fire(Harness.Hit)
	assert(Harness.WorldInstance.RewardState == "Settled")
	assert(#Harness.DestructionService.Calls == 1)
	assert(Harness.DestructionService.Calls[1][2] == 1)
	assert(#Harness.MarketplaceService.Prompts == 0)
	assert(Harness.Coordinator.ReturnCalls == 1)
	assert(Harness.Coordinator.RecoverCalls == 1)
	assert(Harness.Session.State == "InLobby")
	Harness.FreePortal.Children.Trigger.Touched:Fire(Harness.Hit)
	assert(#Harness.DestructionService.Calls == 1 and Harness.Coordinator.RecoverCalls == 1)
	Sessions.Remove(Harness.Player)
end)

check("free reward rejects wrong-player and wrong-world touches", function()
	local Harness = loadRewardPortalService()
	assert(Harness.Service:BindWorld(Harness.WorldInstance, Harness.Coordinator) == true)
	assert(Harness.Service:ActivateChoices(Harness.WorldInstance, Harness.Coordinator) == true)
	Harness.FreePortal.Children.Trigger.Touched:Fire(Harness.OtherHit)
	assert(Harness.WorldInstance.RewardState == "Choosing")
	assert(#Harness.DestructionService.Calls == 0 and Harness.Coordinator.ReturnCalls == 0)

	Harness.Session.CurrentWorldInstanceId = "OTHER_WORLD"
	Harness.FreePortal.Children.Trigger.Touched:Fire(Harness.Hit)
	assert(Harness.WorldInstance.RewardState == "Choosing")
	assert(#Harness.DestructionService.Calls == 0 and Harness.Coordinator.ReturnCalls == 0)
	Sessions.Remove(Harness.Player)
end)

check("paid reward uses prompt correlation and never grants directly", function()
	local Harness = loadRewardPortalService()
	assert(Harness.Service:BindWorld(Harness.WorldInstance, Harness.Coordinator) == true)
	assert(Harness.Service:ActivateChoices(Harness.WorldInstance, Harness.Coordinator) == true)
	Harness.PaidPortal.Children.Trigger.Touched:Fire(Harness.Hit)
	assert(Harness.WorldInstance.RewardState == "PromptOpen")
	assert(#Harness.MarketplaceService.Prompts == 1)
	local Pending = assert(Harness.WorldInstance.PendingRewardPrompt)
	assert(Pending.WorldInstanceId == Harness.WorldInstance.WorldInstanceId)
	assert(Pending.ProductKey == "World1TripleReward")
	assert(Pending.ProductId == TEST_SYNTHETIC_WORLD1_TRIPLE_REWARD_PRODUCT_ID)
	assert(Pending.PromptToken == "TEST_SYNTHETIC_PROMPT_TOKEN")
	assert(Pending.State == "PromptOpen")

	Harness.MarketplaceService.PromptProductPurchaseFinished:Fire(Harness.Player.UserId, 999999, true)
	assert(Harness.WorldInstance.RewardState == "PromptOpen")
	Harness.MarketplaceService.PromptProductPurchaseFinished:Fire(
		Harness.Player.UserId,
		TEST_SYNTHETIC_WORLD1_TRIPLE_REWARD_PRODUCT_ID,
		true
	)
	assert(Harness.WorldInstance.RewardState == "AwaitingReceipt")
	assert(Harness.WorldInstance.PendingRewardPrompt.State == "AwaitingReceipt")
	Harness.EventBus.Publish("DeveloperProductCommitted", Harness.Player, "WrongProduct", "TEST_PURCHASE_WRONG")
	assert(Harness.WorldInstance.RewardState == "AwaitingReceipt")
	assert(Harness.Coordinator.ReturnCalls == 0)
	Harness.EventBus.Publish(
		"DeveloperProductCommitted",
		Harness.Player,
		"World1TripleReward",
		"TEST_PURCHASE_MATCHING"
	)
	assert(Harness.WorldInstance.RewardState == "Settled")
	assert(Harness.Coordinator.ReturnCalls == 1)
	assert(Harness.Coordinator.RecoverCalls == 1)
	assert(Harness.Session.State == "InLobby")
	assert(#Harness.DestructionService.Calls == 0)
	Sessions.Remove(Harness.Player)
end)

check("cancelled and delayed paid results fail closed", function()
	local Harness = loadRewardPortalService()
	assert(Harness.Service:BindWorld(Harness.WorldInstance, Harness.Coordinator) == true)
	assert(Harness.Service:ActivateChoices(Harness.WorldInstance, Harness.Coordinator) == true)
	Harness.PaidPortal.Children.Trigger.Touched:Fire(Harness.Hit)
	Harness.MarketplaceService.PromptProductPurchaseFinished:Fire(
		Harness.Player.UserId,
		TEST_SYNTHETIC_WORLD1_TRIPLE_REWARD_PRODUCT_ID,
		false
	)
	assert(Harness.WorldInstance.RewardState == "Choosing")
	assert(Harness.WorldInstance.PendingRewardPrompt == nil)
	Harness.EventBus.Publish("DeveloperProductCommitted", Harness.Player, "World1TripleReward", "TEST_PURCHASE_DELAYED")
	assert(Harness.Coordinator.ReturnCalls == 0)
	assert(#Harness.DestructionService.Calls == 0)
	Sessions.Remove(Harness.Player)
end)

check("AFK zone config is exact", function()
	local AFKZones = require("../../src/server/Game/Config/AFKZones")
	local Multipliers = { 1, 2, 2.5, 3, 3.5, 4, 4.5 }
	for Index, Multiplier in Multipliers do
		local Zone = assert(AFKZones["AFKZone" .. Index])
		assert(Zone.ZoneMultiplier == Multiplier)
		assert(Zone.BaseGain == 1)
		assert(Zone.TickRate == 1)
		assert((Zone.PassKey or Zone.RequiredPass) == (if Index == 7 then "PremiumZone" else nil))
	end
	assert(AFKZones.Spawn == nil and AFKZones.Forest == nil and AFKZones.Volcano == nil)
end)

local function loadAFKZoneSystem(PremiumOwned)
	local Player = fakePlayer(6271)
	local Session = fakeSession(Player)
	Session.HasPremiumZonePass = PremiumOwned
	Sessions.Set(Player, Session)
	local RootPart = { Position = { X = 0, Y = 0, Z = 0 } }
	function RootPart:IsA(Name)
		return Name == "BasePart"
	end
	local Character = {}
	function Character:FindFirstChild(Name)
		return if Name == "HumanoidRootPart" then RootPart else nil
	end
	Player.Character = Character

	local HalfSize = { X = 5, Y = 5, Z = 5 }
	local Size = setmetatable({ X = 10, Y = 10, Z = 10 }, {
		__div = function()
			return HalfSize
		end,
	})
	local Inside = {}
	local ZoneParts = {}
	for Index = 1, 7 do
		local ZoneName = "AFKZone" .. Index
		Inside[ZoneName] = true
		local Part = { Name = ZoneName, Size = Size }
		function Part:IsA(Name)
			return Name == "BasePart"
		end
		Part.CFrame = {
			PointToObjectSpace = function()
				return if Inside[ZoneName] then { X = 0, Y = 0, Z = 0 } else { X = 100, Y = 0, Z = 0 }
			end,
		}
		ZoneParts[ZoneName] = Part
	end
	local AFKZoneFolder = {}
	function AFKZoneFolder:FindFirstChild(Name)
		return ZoneParts[Name]
	end
	local Workspace = {}
	function Workspace:FindFirstChild(Name)
		return if Name == "AFKZones" then AFKZoneFolder else nil
	end
	local Players = {}
	function Players:GetPlayers()
		return { Player }
	end

	local GrowthService = { Calls = {} }
	function GrowthService:AddBigger(TargetPlayer, Context)
		table.insert(self.Calls, { TargetPlayer, Context })
	end
	local GamePassService = { PromptCalls = 0 }
	function GamePassService:IsOwned(TargetPlayer, PassKey)
		assert(TargetPlayer == Player and PassKey == "PremiumZone")
		return Session.HasPremiumZonePass
	end
	function GamePassService:Prompt(TargetPlayer, PassKey)
		assert(TargetPlayer == Player and PassKey == "PremiumZone")
		self.PromptCalls += 1
		return true
	end
	local ServiceRegistry = {}
	function ServiceRegistry.Get(Name)
		if Name == "GrowthService" then
			return GrowthService
		elseif Name == "GamePassService" then
			return GamePassService
		end
		error("unexpected service " .. Name)
	end
	local Scheduler = { Jobs = {} }
	function Scheduler.AddJob(Config)
		Scheduler.Jobs[Config.Name] = Config
	end
	local AFKZones = require("../../src/server/Game/Config/AFKZones")
	local GrowthSource = { AFKZone = "AFKZone" }
	local ReplicatedStorage = childContainer({
		BiggerShared = childContainer({
			Core = childContainer({ Enums = childContainer({ GrowthSource = GrowthSource }) }),
		}),
	})
	local SystemsFolder = {}
	local GameFolder = {
		Config = { AFKZones = AFKZones },
		Parent = {
			Core = {
				Registry = { RuntimeRegistry = { Sessions = Sessions }, ServiceRegistry = ServiceRegistry },
				Scheduler = { Scheduler = Scheduler },
				Services = { GamePassService = GamePassService },
				Utilities = { Logger = { Info = function() end } },
			},
		},
	}
	SystemsFolder.Parent = GameFolder
	local Game = {}
	function Game:GetService(Name)
		if Name == "Players" then
			return Players
		elseif Name == "Workspace" then
			return Workspace
		elseif Name == "ReplicatedStorage" then
			return ReplicatedStorage
		end
		error("unexpected service " .. Name)
	end
	local System = loadModule("src/server/Game/Systems/AFKZoneSystem.luau", "AFKZoneSystem", {
		game = Game,
		script = { Parent = SystemsFolder },
		require = function(Dependency)
			return Dependency
		end,
	})
	System.Start()
	return {
		GamePassService = GamePassService,
		GrowthService = GrowthService,
		Inside = Inside,
		Player = Player,
		Process = assert(Scheduler.Jobs.AFKZoneCheck).Callback,
		Session = Session,
	}
end

check("AFK zones select one highest-priority containing zone", function()
	local Harness = loadAFKZoneSystem(true)
	Harness.Process()
	assert(#Harness.GrowthService.Calls == 1)
	local Context = Harness.GrowthService.Calls[1][2]
	assert(Context.SourceId == "AFKZone7")
	assert(Context.ZoneMultiplier == 4.5)
	Sessions.Remove(Harness.Player)
end)

check("locked AFKZone7 never falls back and prompts once per entry", function()
	local Harness = loadAFKZoneSystem(false)
	Harness.Process()
	Harness.Process()
	assert(#Harness.GrowthService.Calls == 0)
	assert(Harness.GamePassService.PromptCalls == 1)
	Harness.Inside.AFKZone7 = false
	Harness.Process()
	assert(#Harness.GrowthService.Calls == 1)
	assert(Harness.GrowthService.Calls[1][2].SourceId == "AFKZone6")
	Harness.Inside.AFKZone7 = true
	Harness.Process()
	assert(#Harness.GrowthService.Calls == 1)
	assert(Harness.GamePassService.PromptCalls == 2)
	Harness.Session.HasPremiumZonePass = true
	Harness.Process()
	assert(#Harness.GrowthService.Calls == 2)
	assert(Harness.GrowthService.Calls[2][2].ZoneMultiplier == 4.5)
	Sessions.Remove(Harness.Player)
end)

local function loadGrowthFormula()
	local GrowthTypes = {}
	local ReplicatedStorage = childContainer({
		BiggerShared = childContainer({
			Core = childContainer({ Types = childContainer({ GrowthTypes = GrowthTypes }) }),
		}),
	})
	local Game = {}
	function Game:GetService(Name)
		assert(Name == "ReplicatedStorage")
		return ReplicatedStorage
	end
	local FormulaFolder =
		{ Parent = { Parent = { Core = { Registry = { RuntimeRegistry = { Sessions = Sessions } } } } } }
	return loadModule("src/server/Game/Formula/GrowthFormula.luau", "GrowthFormula", {
		game = Game,
		script = { Parent = FormulaFolder },
		require = function(Dependency)
			return Dependency
		end,
	})
end

local function loadGrowthService(GrowthFormula)
	local GrowthTypes = {}
	local ReplicatedStorage = childContainer({
		BiggerShared = childContainer({
			Core = childContainer({ Types = childContainer({ GrowthTypes = GrowthTypes }) }),
		}),
	})
	local EventBus = { Publish = function() end }
	local ServiceRegistry = {
		Get = function()
			return GrowthFormula
		end,
	}
	local ServicesFolder = {}
	local CoreFolder = {
		Registry = { RuntimeRegistry = { Sessions = Sessions }, ServiceRegistry = ServiceRegistry },
		Events = { EventBus = EventBus },
		Utilities = { Logger = { Warn = function() end } },
	}
	ServicesFolder.Parent = CoreFolder
	local Game = {}
	function Game:GetService(Name)
		assert(Name == "ReplicatedStorage")
		return ReplicatedStorage
	end
	return loadModule("src/server/Core/Services/GrowthService.luau", "GrowthService", {
		game = Game,
		script = { Parent = ServicesFolder },
		require = function(Dependency)
			return Dependency
		end,
	})
end

check("ObjectiveController shows each objective activation for exactly three seconds", function()
	local AttributeSignals = {
		ObjectiveActive = signal(),
		ObjectiveText = signal(),
		ObjectiveReward = signal(),
	}
	local Player = fakePlayer(6307)
	Player.Attributes = {
		ObjectiveActive = false,
		ObjectiveText = "STOMP THE SPIDER",
		ObjectiveReward = "+1 Destruction",
	}
	Player.PlayerGui = nil
	Player.ChildAdded = signal()
	Player.ChildRemoved = signal()
	local WaitTimeout
	function Player:FindFirstChild(Name)
		return self[Name]
	end
	function Player:WaitForChild(Name, Timeout)
		WaitTimeout = Timeout
		return self[Name]
	end
	function Player:GetAttributeChangedSignal(Name)
		return AttributeSignals[Name]
	end

	local Created = {}
	local Instance = {}
	function Instance.new(ClassName)
		local Object = { ClassName = ClassName }
		table.insert(Created, Object)
		return Object
	end
	local Delays = {}
	local Warnings = {}
	local FakeTask = {}
	function FakeTask.delay(Duration, Callback)
		table.insert(Delays, { Duration = Duration, Callback = Callback })
	end
	local Game = {}
	function Game:GetService(Name)
		assert(Name == "Players")
		return { LocalPlayer = Player }
	end
	local function Values(...)
		return { ... }
	end
	local Controller = loadModule("src/client/controllers/ObjectiveController.luau", "ObjectiveController", {
		game = Game,
		Instance = Instance,
		task = FakeTask,
		Vector2 = { new = Values },
		UDim2 = { fromScale = Values, fromOffset = Values, new = Values },
		UDim = { new = Values },
		Color3 = { fromRGB = Values },
		Enum = {
			Font = { GothamBold = "GothamBold", Gotham = "Gotham" },
			TextXAlignment = { Left = "Left" },
			TextYAlignment = { Top = "Top" },
		},
		warn = function(Message)
			table.insert(Warnings, Message)
		end,
	})
	Controller.Start()
	Controller.Start()
	assert(Controller.GetStatus() == "PlayerGuiUnavailable")
	assert(WaitTimeout == 5)
	local PlayerGui = { Name = "PlayerGui" }
	Player.PlayerGui = PlayerGui
	Player.ChildAdded:Fire(PlayerGui)
	assert(Controller.GetStatus() == "Ready")
	local ObjectiveGui
	for _, Object in Created do
		if Object.ClassName == "ScreenGui" then
			ObjectiveGui = Object
		end
	end
	assert(ObjectiveGui and ObjectiveGui.Enabled == false)
	Player.Attributes.ObjectiveActive = true
	AttributeSignals.ObjectiveActive:Fire()
	assert(ObjectiveGui.Enabled == true)
	assert(#Delays == 1 and Delays[1].Duration == 3)
	AttributeSignals.ObjectiveText:Fire()
	assert(#Delays == 1 and ObjectiveGui.Enabled == true)
	Delays[1].Callback()
	assert(ObjectiveGui.Enabled == false)
	assert(#AttributeSignals.ObjectiveActive.Callbacks == 1)
	assert(#AttributeSignals.ObjectiveText.Callbacks == 1)
	assert(#AttributeSignals.ObjectiveReward.Callbacks == 1)
	Player.PlayerGui = nil
	Player.ChildRemoved:Fire(PlayerGui)
	assert(Controller.GetStatus() == "PlayerGuiUnavailable")
	local ReplacementPlayerGui = { Name = "PlayerGui" }
	Player.PlayerGui = ReplacementPlayerGui
	Player.ChildAdded:Fire(ReplacementPlayerGui)
	assert(Controller.GetStatus() == "Ready")
	local ScreenGuiCount = 0
	for _, Object in Created do
		if Object.ClassName == "ScreenGui" then
			ScreenGuiCount += 1
		end
	end
	assert(ScreenGuiCount == 2)
	assert(#Warnings == 1)
	Controller.Destroy()
	assert(Controller.GetStatus() == "PlayerGuiUnavailable")
end)

local function runGrowthSequence(ZoneMultiplier, HasVip, Count)
	local Formula = loadGrowthFormula()
	local Service = loadGrowthService(Formula)
	local Player = fakePlayer(6300 + Count)
	local Session = fakeSession(Player)
	Session.HasVip = HasVip
	Sessions.Set(Player, Session)
	local Gains = {}
	for _ = 1, Count do
		local Before = Session.Bigger
		Service:AddBigger(Player, { BaseGain = 1, ZoneMultiplier = ZoneMultiplier, Source = "AFKZone" })
		table.insert(Gains, Session.Bigger - Before)
	end
	Sessions.Remove(Player)
	return Gains, Session, Service, Player
end

check("GrowthFormula returns unfloored gain", function()
	local Formula = loadGrowthFormula()
	assert(Formula.Calculate(fakeSession(fakePlayer(6301)), { BaseGain = 1, ZoneMultiplier = 2.5 }) == 2.5)
end)

check("fractional growth sequences are deterministic", function()
	local Gains25 = runGrowthSequence(2.5, false, 4)
	assert(table.concat(Gains25, ",") == "2,3,2,3")
	local Gains45 = runGrowthSequence(4.5, false, 4)
	assert(table.concat(Gains45, ",") == "4,5,4,5")
	local VipGains = runGrowthSequence(4.5, true, 4)
	assert(table.concat(VipGains, ",") == "9,9,9,9")
end)

check("failed, frozen, and overflowing growth does not consume remainder", function()
	local Formula = loadGrowthFormula()
	local Service = loadGrowthService(Formula)
	local Player = fakePlayer(6302)
	local Session = fakeSession(Player)
	Session.GrowthRemainder = 0.75
	Session.ProfileMutationsFrozen = true
	Sessions.Set(Player, Session)
	Service:AddBigger(Player, { BaseGain = 1, ZoneMultiplier = 2.5, Source = "AFKZone" })
	assert(Session.Bigger == 1 and Session.GrowthRemainder == 0.75)
	Session.ProfileMutationsFrozen = false
	Session.Bigger = MAXIMUM_SAFE_INTEGER
	Service:AddBigger(Player, { BaseGain = 1, ZoneMultiplier = 2.5, Source = "AFKZone" })
	assert(Session.Bigger == MAXIMUM_SAFE_INTEGER and Session.GrowthRemainder == 0.75)
	Sessions.Remove(Player)
end)

if #Failures > 0 then
	error("mvp005_gameplay: expected RED\n- " .. table.concat(Failures, "\n- "), 0)
end

print("mvp005_gameplay: PASS")
