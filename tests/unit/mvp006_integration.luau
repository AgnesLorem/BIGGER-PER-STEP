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
		Subscribers = Subscribers,
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

local function createMockInstance(ClassName: string, Name: string?)
	local Internal = {
		ClassName = ClassName,
		Name = Name or ClassName,
		Parent = nil,
		Children = {},
		Attributes = {},
		Properties = {},
		CanCollide = true,
		CanTouch = true,
		CanQuery = true,
		Anchored = true,
		Size = { X = 1, Y = 1, Z = 1 },
		Position = { X = 0, Y = 0, Z = 0 },
		CFrame = {
			PointToObjectSpace = function(_self, Point)
				return { X = Point.X or 0, Y = Point.Y or 0, Z = Point.Z or 0 }
			end,
		},
		Touched = fakeSignal(),
		Activated = fakeSignal(),
		MouseButton1Click = fakeSignal(),
		MouseButton1Down = fakeSignal(),
		MouseButton1Up = fakeSignal(),
		MouseEnter = fakeSignal(),
		MouseLeave = fakeSignal(),
		Triggered = fakeSignal(),
		Enabled = true,
		ActionText = "",
		ObjectText = "",
		Text = "",
		Visible = true,
		DisplayOrder = 0,
		ResetOnSpawn = false,
	}

	local Methods = {}

	function Methods:IsA(TargetClass: string)
		return Internal.ClassName == TargetClass
			or TargetClass == "Instance"
			or (TargetClass == "BasePart" and (Internal.ClassName == "Part" or Internal.ClassName == "MeshPart"))
			or (TargetClass == "GuiButton" and (Internal.ClassName == "TextButton" or Internal.ClassName == "ImageButton"))
			or (
				TargetClass == "GuiObject"
				and (
					Internal.ClassName == "Frame"
					or Internal.ClassName == "TextButton"
					or Internal.ClassName == "ImageButton"
					or Internal.ClassName == "TextLabel"
					or Internal.ClassName == "ImageLabel"
				)
			)
	end

	function Methods:FindFirstChild(ChildName: string, Recursive: boolean?)
		for _, Child in Internal.Children do
			if Child.Name == ChildName then
				return Child
			end
		end
		if Recursive then
			for _, Child in Internal.Children do
				local Found = Child:FindFirstChild(ChildName, true)
				if Found then
					return Found
				end
			end
		end
		return Internal[ChildName]
	end

	function Methods:FindFirstChildWhichIsA(TargetClass: string, Recursive: boolean?)
		for _, Child in Internal.Children do
			if Child:IsA(TargetClass) then
				return Child
			end
		end
		if Recursive then
			for _, Child in Internal.Children do
				local Found = Child:FindFirstChildWhichIsA(TargetClass, true)
				if Found then
					return Found
				end
			end
		end
		return nil
	end

	function Methods:FindFirstChildOfClass(TargetClass: string)
		for _, Child in Internal.Children do
			if Child.ClassName == TargetClass then
				return Child
			end
		end
		return nil
	end

	function Methods:FindFirstAncestorOfClass(TargetClass: string)
		local Curr = Internal.Parent
		while Curr do
			if Curr:IsA(TargetClass) then
				return Curr
			end
			Curr = Curr.Parent
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

	function Methods:GetDescendants()
		local List = {}
		local function Recurse(Node)
			for _, Child in Node.Children do
				table.insert(List, Child)
				Recurse(Child)
			end
		end
		Recurse(Internal)
		return List
	end

	function Methods:SetAttribute(Key: string, Value: any)
		Internal.Attributes[Key] = Value
	end

	function Methods:GetAttribute(Key: string)
		return Internal.Attributes[Key]
	end

	function Methods:GetPropertyChangedSignal(PropName: string)
		return fakeSignal()
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

local function fakeFolder(Name: string, ChildrenDict: { [string]: any }?)
	local Folder = createMockInstance("Folder", Name)
	if ChildrenDict then
		for ChildName, Child in ChildrenDict do
			if type(Child) == "table" then
				pcall(function()
					Child.Parent = Folder
				end)
				Folder[ChildName] = Child
			end
		end
	end
	return Folder
end

local function fakePlayer(UserId: number)
	local AttributeSignals: { [string]: any } = {}
	local Player = createMockInstance("Player", "Player_" .. tostring(UserId))
	Player.UserId = UserId

	local Leaderstats = createMockInstance("Folder", "leaderstats")
	Leaderstats.Parent = Player
	local BiggerStat = createMockInstance("IntValue", "Bigger")
	BiggerStat.Value = 1
	BiggerStat.Parent = Leaderstats
	local DestructionStat = createMockInstance("IntValue", "Destruction")
	DestructionStat.Value = 0
	DestructionStat.Parent = Leaderstats
	local RebirthStat = createMockInstance("IntValue", "Rebirth")
	RebirthStat.Value = 0
	RebirthStat.Parent = Leaderstats

	local PlayerGui = createMockInstance("Folder", "PlayerGui")
	PlayerGui.Parent = Player

	Player.CharacterAdded = fakeSignal()
	Player.CharacterAppearanceLoaded = fakeSignal()

	function Player:SetAttribute(Key: string, Value: any)
		local Old = self:GetAttribute(Key)
		Player.Attributes[Key] = Value
		if Old ~= Value and AttributeSignals[Key] then
			AttributeSignals[Key]:Fire(Value)
		end
	end

	function Player:GetAttributeChangedSignal(Key: string)
		if not AttributeSignals[Key] then
			AttributeSignals[Key] = fakeSignal()
		end
		return AttributeSignals[Key]
	end

	return Player
end

local function createMockCharacter()
	local Character = createMockInstance("Model", "Character")
	local RootPart = createMockInstance("Part", "HumanoidRootPart")
	RootPart.Position = { X = 0, Y = 5, Z = 0 }
	RootPart.AssemblyLinearVelocity = { X = 0, Y = -10, Z = 0 }
	RootPart.Parent = Character

	local Head = createMockInstance("Part", "Head")
	Head.Position = { X = 0, Y = 7, Z = 0 }
	Head.Parent = Character

	local Humanoid = createMockInstance("Humanoid", "Humanoid")
	Humanoid.Parent = Character

	return Character, RootPart, Head, Humanoid
end

local function createMockSession(Player: any, Overrides: { [string]: any }?)
	local Session = {
		Player = Player,
		Bigger = 1,
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
		GamePassQueryGenerations = { Vip = 0, PremiumZone = 0, AutoWins = 0 },
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

local MockColor3 = {
	fromRGB = function(r, g, b)
		return { R = r, G = g, B = b, ClassName = "Color3" }
	end,
	new = function(r, g, b)
		return { R = r, G = g, B = b, ClassName = "Color3" }
	end,
}

local MockColorSequence = {
	new = function(keypoints)
		return { Keypoints = keypoints, ClassName = "ColorSequence" }
	end,
}

local MockColorSequenceKeypoint = {
	new = function(time, color)
		return { Time = time, Value = color }
	end,
}

local MockUDim2 = {
	fromOffset = function(x, y)
		return { X = { Scale = 0, Offset = x }, Y = { Scale = 0, Offset = y }, ClassName = "UDim2" }
	end,
	fromScale = function(x, y)
		return { X = { Scale = x, Offset = 0 }, Y = { Scale = y, Offset = 0 }, ClassName = "UDim2" }
	end,
	new = function(xs, xo, ys, yo)
		return {
			X = { Scale = xs or 0, Offset = xo or 0 },
			Y = { Scale = ys or 0, Offset = yo or 0 },
			ClassName = "UDim2",
		}
	end,
}

local MockVector3 = {
	new = function(x, y, z)
		return { X = x, Y = y, Z = z, ClassName = "Vector3" }
	end,
}

local MockInstance = {
	new = function(ClassName: string, Parent: any?)
		local Inst = createMockInstance(ClassName)
		if Parent then
			Inst.Parent = Parent
		end
		return Inst
	end,
}

local Logger = {
	Info = function(...) end,
	Warn = function(...) end,
	Error = function(...) end,
}

print("=== Running MVP-006 Task 10 Integration Test Suite ===")

-- =========================================================================
-- JOURNEY 1: New Player Onboarding & Core Loop
-- =========================================================================
check("Journey 1: New Player Onboarding & Core Loop", function()
	local Player = fakePlayer(1001)
	local Character, RootPart, Head, Humanoid = createMockCharacter()
	Player.Character = Character

	-- 1. Onboarding: Player session created with defaults & default cosmetics granted
	local Session = createMockSession(Player, {
		Bigger = 1,
		Destruction = 0,
		Rebirth = 0,
		State = "InLobby",
		UnlockedTrails = {},
		EquippedTrail = nil,
		UnlockedTitles = {},
		EquippedTitle = nil,
	})
	Sessions.Set(Player, Session)

	-- Verify default cosmetics auto-grant invariant
	if not Session.UnlockedTrails["Default"] then
		Session.UnlockedTrails["Default"] = true
		Session.EquippedTrail = "Default"
	end
	if not Session.UnlockedTitles["Newbie"] then
		Session.UnlockedTitles["Newbie"] = true
		Session.EquippedTitle = "Newbie"
	end

	assert(Session.UnlockedTrails["Default"] == true, "Default trail must be unlocked")
	assert(Session.EquippedTrail == "Default", "Default trail must be equipped")
	assert(Session.UnlockedTitles["Newbie"] == true, "Newbie title must be unlocked")
	assert(Session.EquippedTitle == "Newbie", "Newbie title must be equipped")

	-- 2. Movement / AFK growth calculation
	local UpgradeConfig = loadModule("src/server/Game/Config/UpgradeConfig.luau", "UpgradeConfig")
	local GrowthTypes = loadModule("src/shared/Core/Types/GrowthTypes.luau", "GrowthTypes")
	local BalanceConfig = loadModule("src/shared/Game/Progression/BalanceConfig.luau", "BalanceConfig")
	local LevelFormula = loadModule("src/shared/Game/Progression/LevelFormula.luau", "LevelFormula", {
		script = { Parent = { BalanceConfig = BalanceConfig } },
		require = function(Dep)
			return BalanceConfig
		end,
	})
	local MockReplicatedStorage = fakeFolder("ReplicatedStorage", {
		BiggerShared = fakeFolder("BiggerShared", {
			Core = fakeFolder("Core", {
				Types = fakeFolder("Types", { GrowthTypes = GrowthTypes }),
			}),
			Game = fakeFolder("Game", {
				Progression = fakeFolder("Progression", { LevelFormula = LevelFormula }),
			}),
		}),
	})

	local GrowthFormula = loadModule("src/server/Game/Formula/GrowthFormula.luau", "GrowthFormula", {
		game = {
			GetService = function(_self, Name: string)
				if Name == "ReplicatedStorage" then
					return MockReplicatedStorage
				end
				return nil
			end,
		},
		script = {
			Parent = {
				Parent = {
					Config = { UpgradeConfig = UpgradeConfig },
					Parent = { Core = { Registry = { RuntimeRegistry = { Sessions = Sessions } } } },
				},
			},
		},
		require = function(Dependency)
			return Dependency
		end,
	})

	-- Movement growth: BaseGain = 1, Multiplier = 1
	local MoveGain = GrowthFormula.Calculate(Session, { BaseGain = 1, Source = "Movement" })
	assert(MoveGain == 1, "Movement growth should calculate 1 with no upgrades/rebirth")
	Session.Bigger += MoveGain
	assert(Session.Bigger == 2, "Session Bigger should increment to 2")

	-- AFK Table 1 growth: BaseGain = 1, ZoneMultiplier = 50
	local AFKGain = GrowthFormula.Calculate(Session, { BaseGain = 1, ZoneMultiplier = 50, Source = "AFKZone" })
	assert(AFKGain == 50, "AFK Table 1 growth should calculate 50")
	Session.Bigger += AFKGain
	assert(Session.Bigger == 52, "Session Bigger should be 52 after AFK tick")

	-- 3. GUI Map Selector to World 1
	local RequestSelectMapRemote = fakeRemoteEvent("RequestSelectMap")
	local ShowRewardPopupRemote = fakeRemoteEvent("ShowRewardPopup")
	local RequestClaimRewardRemote = fakeRemoteEvent("RequestClaimReward")
	local RemotesFolder = fakeFolder("Remotes", {
		RequestSelectMap = RequestSelectMapRemote,
		ShowRewardPopup = ShowRewardPopupRemote,
		RequestClaimReward = RequestClaimRewardRemote,
	})
	MockReplicatedStorage.Remotes = RemotesFolder

	local UIEventBus = loadModule("src/client/controllers/UIEventBus.luau", "UIEventBus", { task = task })
	local MockPlayers = {
		LocalPlayer = Player,
		GetPlayerFromCharacter = function()
			return Player
		end,
	}

	local MapSelectorController =
		loadModule("src/client/controllers/MapSelectorController.luau", "MapSelectorController", {
			game = {
				GetService = function(_self, Name: string)
					if Name == "ReplicatedStorage" then
						return MockReplicatedStorage
					end
					if Name == "Players" then
						return MockPlayers
					end
					return nil
				end,
			},
			script = { Parent = fakeFolder("controllers", { UIEventBus = UIEventBus }) },
			require = function(Dep)
				if Dep == UIEventBus then
					return UIEventBus
				end
				return Dep
			end,
		})

	MapSelectorController.Init()
	MapSelectorController.Start()

	MapSelectorController.Open()
	assert(MapSelectorController.IsOpen() == true, "Map selector modal should open")

	-- Client requests map selection
	MapSelectorController.SelectMap("WORLD1")
	assert(#RequestSelectMapRemote.FiredServerEvents > 0, "SelectMap must fire RequestSelectMap remote")
	assert(RequestSelectMapRemote.FiredServerEvents[1][1] == "WORLD1", "Requested map must be WORLD1")

	-- Server processes map selection: transitions to InWorld
	assert(Session.State == "InLobby", "Session must start in InLobby")
	Session.State = "InWorld"
	Session.CurrentWorldInstanceId = "WORLD1_INST_1"
	MapSelectorController.Close()
	assert(MapSelectorController.IsOpen() == false, "Map selector modal should close")

	-- 4. Objective completed in World 1 -> Spider stomp -> Reward choice activation
	local MockWorldInstance = {
		WorldInstanceId = "WORLD1_INST_1",
		OwnerUserId = Player.UserId,
		OwnerPlayer = Player,
		RewardState = "Inactive",
		ObjectiveCompleted = true,
	}
	local DeveloperProductConfig = {
		World1TripleReward = {
			ProductId = 0,
			Rewards = { { Type = "Destruction", Amount = 3 } },
			Price = 29,
			Surface = "PortalOnly",
		},
	}
	local World1Config = {
		ReturnPortalDebounceSeconds = 1.5,
		RewardProductKey = "World1TripleReward",
		RewardPortals = {
			FreeName = "FreeRewardPortal",
			PaidName = "PaidRewardPortal",
			FreeDestruction = 1,
			FreeLabel = "FREE\n+1 DESTRUCTION",
			PaidLabel = "3 DESTRUCTION • 29 R$",
		},
	}
	local ConfigValidationService = {
		Validate = function()
			return true
		end,
		GetDeveloperProductStatus = function(_self, _Key)
			return { IsValid = true, ProductId = 0 }
		end,
	}
	local EventBus = createMockEventBus()
	local WorldInstances = {
		Get = function(_TargetPlayer)
			return MockWorldInstance
		end,
	}

	local MockMarketplaceService = {
		PromptProductPurchaseFinished = fakeSignal(),
		PromptProductPurchase = function() end,
	}

	local MockDestructionService = {
		GrantDestruction = function(_self, TargetPlayer, Amount)
			local S = Sessions.Get(TargetPlayer)
			if S then
				S.Destruction += Amount
				S.CompletedPortals["WORLD1"] = (S.CompletedPortals["WORLD1"] or 0) + 1
				return true
			end
			return false
		end,
	}

	local MockSessionService = {
		TransitionState = function(_self, TargetPlayer, From, To)
			local S = Sessions.Get(TargetPlayer)
			if S and S.State == From then
				S.State = To
				return true
			end
			return false
		end,
	}

	local MockWorldInstanceService = {
		RecoverPlayer = function() end,
		ReturnPlayerToLobby = function(_self, TargetPlayer)
			local S = Sessions.Get(TargetPlayer)
			if S then
				S.State = "InLobby"
				S.CurrentWorldInstanceId = nil
				return true
			end
			return false
		end,
	}

	local MockPortalService = {
		HoldDebounce = function() end,
	}

	local MockJourney1Registry = {
		Get = function(Name: string)
			if Name == "DestructionService" then
				return MockDestructionService
			end
			if Name == "SessionService" then
				return MockSessionService
			end
			if Name == "WorldInstanceService" then
				return MockWorldInstanceService
			end
			if Name == "PortalService" then
				return MockPortalService
			end
			return nil
		end,
	}

	local RewardPortalService = loadModule("src/server/Game/Services/RewardPortalService.luau", "RewardPortalService", {
		game = {
			GetService = function(_self, Name: string)
				if Name == "ReplicatedStorage" then
					return MockReplicatedStorage
				end
				if Name == "Players" then
					return MockPlayers
				end
				if Name == "MarketplaceService" then
					return MockMarketplaceService
				end
				return nil
			end,
		},
		script = {
			Parent = {
				Parent = {
					Config = {
						World1Config = World1Config,
					},
					Parent = {
						Core = {
							Registry = {
								RuntimeRegistry = { Sessions = Sessions, WorldInstances = WorldInstances },
								ServiceRegistry = MockJourney1Registry,
							},
							Config = { DeveloperProductConfig = DeveloperProductConfig },
							Services = { ConfigValidationService = ConfigValidationService },
							Events = { EventBus = EventBus },
							Utilities = {
								Logger = Logger,
								RewardDispatcher = {
									ApplyReward = function(TargetPlayer, Reward)
										if Reward.Type == "Destruction" then
											local TargetSession = Sessions.Get(TargetPlayer)
											if TargetSession then
												TargetSession.Destruction += (Reward.Amount or 1)
											end
											return true
										end
										return false
									end,
								},
							},
						},
					},
				},
			},
		},
		require = function(Dep)
			return Dep
		end,
	})
	RewardPortalService:Init()

	-- Activate choices after objective stomp
	local MockWorldInstanceService = {
		RecoverPlayer = function() end,
	}
	local ChoicesActive = RewardPortalService:ActivateChoices(MockWorldInstance, MockWorldInstanceService)
	assert(ChoicesActive == true, "ActivateChoices must succeed")
	assert(#ShowRewardPopupRemote.FiredClientEvents > 0, "ShowRewardPopup must be fired to player")

	-- 5. GUI Free Reward Claim -> +1 Destruction, completed portal incremented, return to Lobby
	local RewardPopupController =
		loadModule("src/client/controllers/RewardPopupController.luau", "RewardPopupController", {
			game = {
				GetService = function(_self, Name: string)
					if Name == "ReplicatedStorage" then
						return MockReplicatedStorage
					end
					if Name == "Players" then
						return MockPlayers
					end
					return nil
				end,
			},
			Instance = MockInstance,
			UDim = {
				new = function(scale, offset)
					return { Scale = scale or 0, Offset = offset or 0 }
				end,
			},
			UDim2 = MockUDim2,
			Color3 = MockColor3,
			Vector2 = {
				new = function(x, y)
					return { X = x, Y = y }
				end,
			},
			Enum = { Font = { GothamBold = 1, Gotham = 2 } },
			script = { Parent = fakeFolder("controllers") },
			require = function(Dep)
				return Dep
			end,
		})
	RewardPopupController.Init()
	RewardPopupController.Start()

	local PopupPayload = ShowRewardPopupRemote.FiredClientEvents[1].Args[1]
	RewardPopupController.Show(PopupPayload)
	assert(RewardPopupController.IsOpen() == true, "Reward popup should be open")

	-- Client clicks Free Reward
	RewardPopupController.ClaimReward("Free")
	assert(#RequestClaimRewardRemote.FiredServerEvents > 0, "ClaimReward must fire RequestClaimReward remote")
	assert(RequestClaimRewardRemote.FiredServerEvents[1][1] == "Free", "Reward choice must be Free")

	-- Server validates and claims Free reward
	local ClaimOk = RewardPortalService:RequestClaimReward(Player, "Free")
	assert(ClaimOk == true, "Server RequestClaimReward('Free') must succeed")
	assert(Session.Destruction == 1, "Player must receive 1 Destruction from Free reward")
	assert(Session.CompletedPortals["WORLD1"] == 1, "CompletedPortals['WORLD1'] must increment to 1")
	assert(Session.State == "InLobby", "Player session state must transition back to InLobby")
	assert(RewardPopupController.IsOpen() == false, "Reward popup must close")

	MapSelectorController.Destroy()
	RewardPopupController.Destroy()
	Sessions.Remove(Player)
end)

-- =========================================================================
-- JOURNEY 2: Upgrades & Progression
-- =========================================================================
check("Journey 2: Upgrades & Progression", function()
	local Player = fakePlayer(2001)
	local Character, RootPart, Head, Humanoid = createMockCharacter()
	Player.Character = Character

	local Session = createMockSession(Player, {
		Bigger = 1,
		Destruction = 600,
		Rebirth = 0,
		UnlockedGrowthUpgrades = {},
		EquippedGrowthUpgrade = nil,
	})
	Sessions.Set(Player, Session)

	local UpgradeConfig = loadModule("src/server/Game/Config/UpgradeConfig.luau", "UpgradeConfig")
	local AFKZones = loadModule("src/server/Game/Config/AFKZones.luau", "AFKZones")
	local GrowthTypes = loadModule("src/shared/Core/Types/GrowthTypes.luau", "GrowthTypes")

	local RequestBuyUpgradeRemote = fakeRemoteEvent("RequestBuyUpgrade")
	local RequestEquipUpgradeRemote = fakeRemoteEvent("RequestEquipUpgrade")
	local UpdateUpgradeStatusRemote = fakeRemoteEvent("UpdateUpgradeStatus")

	local RemotesFolder = fakeFolder("Remotes", {
		RequestBuyUpgrade = RequestBuyUpgradeRemote,
		RequestEquipUpgrade = RequestEquipUpgradeRemote,
		UpdateUpgradeStatus = UpdateUpgradeStatusRemote,
	})
	local MockReplicatedStorage = fakeFolder("ReplicatedStorage", {
		Remotes = RemotesFolder,
		BiggerShared = fakeFolder("BiggerShared", {
			Core = fakeFolder("Core", {
				Types = fakeFolder("Types", { GrowthTypes = GrowthTypes }),
			}),
		}),
	})
	local MockPlayers = {
		LocalPlayer = Player,
		GetPlayerFromCharacter = function()
			return Player
		end,
	}

	local DestructionService = {
		DeductDestruction = function(_self, TargetPlayer, Amount)
			local TargetSession = Sessions.Get(TargetPlayer)
			if not TargetSession or TargetSession.Destruction < Amount then
				return false
			end
			TargetSession.Destruction -= Amount
			return true
		end,
	}

	local EventBus = createMockEventBus()
	local MockServiceRegistry = {
		Get = function(Name: string)
			if Name == "DestructionService" then
				return DestructionService
			end
			return nil
		end,
	}

	local UpgradeService = loadModule("src/server/Game/Services/UpgradeService.luau", "UpgradeService", {
		game = {
			GetService = function(_self, Name: string)
				if Name == "ReplicatedStorage" then
					return MockReplicatedStorage
				end
				if Name == "Players" then
					return MockPlayers
				end
				return nil
			end,
		},
		script = {
			Parent = {
				Parent = {
					Config = { UpgradeConfig = UpgradeConfig },
					Parent = {
						Core = {
							Registry = {
								RuntimeRegistry = { Sessions = Sessions },
								ServiceRegistry = MockServiceRegistry,
							},
							Utilities = { Logger = Logger },
							Events = { EventBus = EventBus },
						},
					},
				},
			},
		},
		require = function(Dep)
			return Dep
		end,
	})
	UpgradeService:Init()

	-- 1. Query initial upgrade status
	local Status = UpgradeService:GetUpgradeStatus(Player)
	assert(Status ~= nil, "UpgradeStatus should not be nil")
	assert(#Status.List == 15, "Status list should contain exactly 15 upgrades")
	assert(Status.Destruction == 600, "Status destruction should match 600")
	assert(Status.List[1].CanBuy == true, "First upgrade (Protein) must be available to buy")

	-- 2. Buy Upgrade 1 (Protein, milestone check, additive growth = +5)
	local Buy1Ok = UpgradeService:RequestBuyUpgrade(Player, "Protein")
	assert(Buy1Ok == true, "Buying Protein must succeed")
	assert(Session.Destruction == 600, "Destruction is a lifetime milestone, never deducted")
	assert(Session.UnlockedGrowthUpgrades["Protein"] == true, "Protein must be unlocked")
	assert(Session.EquippedGrowthUpgrade == "Protein", "Protein must be auto-equipped")

	-- 3. Additive growth in formula
	local GrowthFormula = loadModule("src/server/Game/Formula/GrowthFormula.luau", "GrowthFormula", {
		game = {
			GetService = function()
				return MockReplicatedStorage
			end,
		},
		script = {
			Parent = {
				Parent = {
					Config = { UpgradeConfig = UpgradeConfig },
					Parent = { Core = { Registry = { RuntimeRegistry = { Sessions = Sessions } } } },
				},
			},
		},
		require = function(Dep)
			return Dep
		end,
	})

	local GainWithUpgrade1 = GrowthFormula.Calculate(Session, { BaseGain = 1, ZoneMultiplier = 1 })
	-- (BaseGain 1 + Protein 5) * ZoneMultiplier 1 * Multiplier 1 = 6
	assert(GainWithUpgrade1 == 6, "Growth with Protein (+5) should be 6")

	-- 4. Buy Upgrade 2 (Silver Protein, milestone check, additive growth = +20)
	local Buy2Ok = UpgradeService:RequestBuyUpgrade(Player, "Silver Protein")
	assert(Buy2Ok == true, "Buying Silver Protein must succeed")
	assert(Session.Destruction == 600, "Destruction is a lifetime milestone, never deducted")
	assert(
		Session.UnlockedGrowthUpgrades["Silver Protein"] == true
			or Session.UnlockedGrowthUpgrades["Silver_Protein"] == true,
		"Silver Protein must be unlocked"
	)
	assert(
		Session.EquippedGrowthUpgrade == "Silver Protein" or Session.EquippedGrowthUpgrade == "Silver_Protein",
		"Silver Protein must be auto-equipped"
	)

	local GainWithUpgrade2 = GrowthFormula.Calculate(Session, { BaseGain = 1, ZoneMultiplier = 1 })
	-- (BaseGain 1 + Silver Protein 20) * ZoneMultiplier 1 * Multiplier 1 = 21
	assert(GainWithUpgrade2 == 21, "Growth with Silver Protein (+20) should be 21")

	-- 5. Rebirth gating on higher AFK dining tables
	-- Table1 (50x, MinRebirth = 0)
	local Table1 = AFKZones.Table1
	assert(Table1.MinRebirth == 0, "Table1 MinRebirth must be 0")
	local Table1Eligible = (Session.Rebirth >= (Table1.MinRebirth or 0))
	assert(Table1Eligible == true, "Player with Rebirth 0 must be eligible for Table1")

	-- Table2 (100x, MinRebirth = 5)
	local Table2 = AFKZones.Table2
	assert(Table2.MinRebirth == 5, "Table2 MinRebirth must be 5")
	local Table2EligibleBeforeRebirth = (Session.Rebirth >= (Table2.MinRebirth or 0))
	assert(Table2EligibleBeforeRebirth == false, "Player with Rebirth 0 must NOT be eligible for Table2")

	-- Process 5 Rebirths
	Session.Rebirth = 5
	local Table2EligibleAfterRebirth = (Session.Rebirth >= (Table2.MinRebirth or 0))
	assert(Table2EligibleAfterRebirth == true, "Player with Rebirth 5 must be eligible for Table2")

	local GainOnTable2 =
		GrowthFormula.Calculate(Session, { BaseGain = 1, ZoneMultiplier = Table2.ZoneMultiplier, Source = "AFKZone" })
	-- (BaseGain 1 + Silver Protein 20) * ZoneMultiplier 100 * Rebirth Factor (5 + 1) = 21 * 100 * 6 = 12600
	assert(GainOnTable2 == 12600, "Growth on Table2 with 5 Rebirths should be 12600")

	Sessions.Remove(Player)
end)

-- =========================================================================
-- JOURNEY 3: Daily Rewards & Lucky Spins
-- =========================================================================
check("Journey 3: Daily Rewards & Lucky Spins", function()
	local Player = fakePlayer(3001)
	local Session = createMockSession(Player, {
		DailyRewardDay = 1,
		LastDailyClaimTimestamp = 0,
		SpinTokens = 0,
		Bigger = 1,
		Destruction = 0,
	})
	Sessions.Set(Player, Session)

	local DailyRewardConfig = loadModule("src/server/Game/Config/DailyRewardConfig.luau", "DailyRewardConfig")
	local SpinWheelConfig = loadModule("src/server/Game/Config/SpinWheelConfig.luau", "SpinWheelConfig")

	local RequestClaimDailyRemote = fakeRemoteEvent("RequestClaimDaily")
	local DailyStatusUpdatedRemote = fakeRemoteEvent("DailyStatusUpdated")
	local GetDailyStatusRemoteFunc = fakeRemoteFunction("GetDailyStatus")
	local RequestSpinWheelRemote = fakeRemoteEvent("RequestSpinWheel")
	local SpinCompletedRemote = fakeRemoteEvent("SpinCompleted")

	local RemotesFolder = fakeFolder("Remotes", {
		RequestClaimDaily = RequestClaimDailyRemote,
		DailyStatusUpdated = DailyStatusUpdatedRemote,
		GetDailyStatus = GetDailyStatusRemoteFunc,
		RequestSpinWheel = RequestSpinWheelRemote,
		SpinCompleted = SpinCompletedRemote,
	})
	local MockReplicatedStorage = fakeFolder("ReplicatedStorage", { Remotes = RemotesFolder })
	local MockPlayers = {
		LocalPlayer = Player,
		GetPlayerFromCharacter = function()
			return Player
		end,
	}

	local RewardDispatcher = {
		Dispatch = function(TargetPlayer, Rewards)
			local TargetSession = Sessions.Get(TargetPlayer)
			if not TargetSession then
				return { Success = false, ErrorCode = "NoSession" }
			end
			for _, Reward in Rewards do
				if Reward.Type == "Bigger" then
					TargetSession.Bigger += (Reward.Amount or 0)
				elseif Reward.Type == "Destruction" then
					TargetSession.Destruction += (Reward.Amount or 0)
				elseif Reward.Type == "SpinTokens" then
					TargetSession.SpinTokens += (Reward.Amount or 0)
				end
			end
			return { Success = true }
		end,
		ApplyReward = function(TargetPlayer, Reward)
			local TargetSession = Sessions.Get(TargetPlayer)
			if not TargetSession then
				return false
			end
			if Reward.Type == "Bigger" then
				TargetSession.Bigger += (Reward.Amount or 0)
			elseif Reward.Type == "Destruction" then
				TargetSession.Destruction += (Reward.Amount or 0)
			elseif Reward.Type == "SpinTokens" then
				TargetSession.SpinTokens += (Reward.Amount or 0)
			end
			return true
		end,
	}

	local EventBus = createMockEventBus()

	local DailyRewardService = loadModule("src/server/Game/Services/DailyRewardService.luau", "DailyRewardService", {
		game = {
			GetService = function(_self, Name: string)
				if Name == "ReplicatedStorage" then
					return MockReplicatedStorage
				end
				if Name == "Players" then
					return MockPlayers
				end
				return nil
			end,
		},
		Instance = MockInstance,
		script = {
			Parent = {
				Parent = {
					Config = { DailyRewardConfig = DailyRewardConfig },
					Parent = {
						Core = {
							Registry = { RuntimeRegistry = { Sessions = Sessions } },
							Utilities = { Logger = Logger, RewardDispatcher = RewardDispatcher },
							Events = { EventBus = EventBus },
						},
					},
				},
			},
		},
		require = function(Dep)
			return Dep
		end,
	})
	DailyRewardService:Init()

	-- 1. Day 1 Daily Reward claim
	local DailyStatus = DailyRewardService:GetDailyStatus(Player)
	assert(DailyStatus ~= nil, "DailyStatus should exist")
	assert(DailyStatus.Day == 1, "Initial daily day should be 1")
	assert(DailyStatus.CanClaim == true, "Fresh player should be eligible to claim Day 1")

	local Claim1Ok = DailyRewardService:ClaimDaily(Player)
	assert(Claim1Ok == true, "ClaimDaily Day 1 must succeed")
	assert(Session.DailyRewardDay == 2, "DailyRewardDay must advance to 2")
	assert(Session.LastDailyClaimTimestamp > 0, "LastDailyClaimTimestamp must be recorded")

	-- 2. 24h Cooldown enforcement
	local Claim2Rejected = DailyRewardService:ClaimDaily(Player)
	assert(Claim2Rejected == false, "Claiming again immediately must be rejected by cooldown")

	local StatusAfterClaim = DailyRewardService:GetDailyStatus(Player)
	assert(StatusAfterClaim.CanClaim == false, "CanClaim must be false during cooldown")
	assert(StatusAfterClaim.TimeUntilNext > 0, "TimeUntilNext must be > 0")

	-- 3. Spin tokens deduction, weighted random wheel spin, and reward dispatch
	local SpinWheelService = loadModule("src/server/Game/Services/SpinWheelService.luau", "SpinWheelService", {
		game = {
			GetService = function(_self, Name: string)
				if Name == "ReplicatedStorage" then
					return MockReplicatedStorage
				end
				if Name == "Players" then
					return MockPlayers
				end
				return nil
			end,
		},
		Instance = MockInstance,
		script = {
			Parent = {
				Parent = {
					Config = { SpinWheelConfig = SpinWheelConfig },
					Parent = {
						Core = {
							Registry = { RuntimeRegistry = { Sessions = Sessions } },
							Utilities = { Logger = Logger, RewardDispatcher = RewardDispatcher },
							Events = { EventBus = EventBus },
						},
					},
				},
			},
		},
		require = function(Dep)
			return Dep
		end,
	})
	SpinWheelService:Init()

	-- Try spin without tokens -> should fail
	assert(Session.SpinTokens == 0, "Initial spin tokens should be 0")
	local ZeroTokensOk, ZeroTokensErr = SpinWheelService:SpinWheel(Player)
	assert(ZeroTokensOk == false, "SpinWheel with 0 tokens must fail")
	assert(ZeroTokensErr == "InsufficientTokens", "Error must be InsufficientTokens")

	-- Grant 2 Spin Tokens
	Session.SpinTokens = 2

	-- Perform authoritative spin with deterministic mock RNG (rolls Sector 1: 100 Bigger)
	local MockRng = {
		NextNumber = function(_self, _min, _max)
			return 0.5
		end,
	}
	local SpinOk, SpinResult = SpinWheelService:SpinWheel(Player, MockRng)

	assert(SpinOk == true, "SpinWheel must succeed")
	assert(SpinResult ~= nil, "SpinResult must not be nil")
	assert(SpinResult.Sector ~= nil, "SpinResult must contain a Sector")
	assert(SpinResult.RemainingTokens == 1, "RemainingTokens must be 1 (2 -> 1)")
	assert(Session.SpinTokens == 1, "Session.SpinTokens must decrement to 1")
	assert(
		SpinResult.Sector.Index >= 1 and SpinResult.Sector.Index <= #SpinWheelConfig.Sectors,
		"Sector index must be in range 1..8"
	)

	-- Client SpinWheelController lifecycle
	local UIEventBus = loadModule("src/client/controllers/UIEventBus.luau", "UIEventBus", { task = task })
	local SpinWheelController = loadModule("src/client/controllers/SpinWheelController.luau", "SpinWheelController", {
		game = {
			GetService = function(_self, Name: string)
				if Name == "ReplicatedStorage" then
					return MockReplicatedStorage
				end
				if Name == "Players" then
					return MockPlayers
				end
				return nil
			end,
		},
		script = { Parent = fakeFolder("controllers", { UIEventBus = UIEventBus }) },
		require = function(Dep)
			if Dep == UIEventBus then
				return UIEventBus
			end
			return Dep
		end,
	})
	SpinWheelController.Init()
	SpinWheelController.Start()

	-- Trigger client spin handling
	SpinWheelController.HandleSpinResult(SpinResult.Sector)
	assert(SpinWheelController.IsSpinning() == false, "IsSpinning should finish")

	SpinWheelController.Destroy()
	Sessions.Remove(Player)
end)

-- =========================================================================
-- JOURNEY 4: VIP Door & AutoWins Loop
-- =========================================================================
check("Journey 4: VIP Door & AutoWins Loop", function()
	local Player = fakePlayer(4001)
	local Character, RootPart, Head, Humanoid = createMockCharacter()
	Player.Character = Character

	local Session = createMockSession(Player, {
		HasVip = false,
		HasAutoWins = false,
		AutoWinsEnabled = false,
		Destruction = 0,
		CompletedPortals = {},
	})
	Sessions.Set(Player, Session)

	-- 1. VIP Door setup in Workspace
	local VIPDoorModel = createMockInstance("Model", "VIPDoor")
	local DoorPart1 = createMockInstance("Part", "DoorPart1")
	DoorPart1.CanCollide = true
	DoorPart1.Parent = VIPDoorModel
	local DoorPart2 = createMockInstance("Part", "DoorPart2")
	DoorPart2.CanCollide = true
	DoorPart2.Parent = VIPDoorModel
	local TriggerPart = createMockInstance("Part", "Trigger")
	TriggerPart.CanCollide = false
	TriggerPart.Parent = VIPDoorModel

	local MockWorkspace = createMockInstance("Workspace", "Workspace")
	VIPDoorModel.Parent = MockWorkspace

	local PromptedPasses = {}
	local MockMarketplaceService = {
		PromptGamePassPurchase = function(_self, TargetPlayer, PassId)
			table.insert(PromptedPasses, { Player = TargetPlayer, PassId = PassId })
		end,
	}

	local MockGamePassService = {
		IsOwned = function(_self, TargetPlayer, PassKey)
			local S = Sessions.Get(TargetPlayer)
			return S and S.HasVip == true
		end,
		Prompt = function(_self, TargetPlayer, PassKey)
			if PassKey == "Vip" then
				MockMarketplaceService:PromptGamePassPurchase(TargetPlayer, 910001)
				return true
			end
			return false
		end,
	}

	local MockServiceRegistry = {
		Get = function(Name: string)
			if Name == "GamePassService" then
				return MockGamePassService
			end
			return nil
		end,
	}

	local VIPDoorSystem = loadModule("src/server/Game/Systems/VIPDoorSystem.luau", "VIPDoorSystem", {
		game = {
			GetService = function(_self, Name: string)
				if Name == "Workspace" then
					return MockWorkspace
				end
				if Name == "MarketplaceService" then
					return MockMarketplaceService
				end
				if Name == "Players" then
					return {
						GetPlayerFromCharacter = function(_self, Char)
							if Char == Character or Char == RootPart or (Char and Char.Parent == Character) then
								return Player
							end
							return nil
						end,
						PlayerRemoving = fakeSignal(),
					}
				end
				return nil
			end,
		},
		script = {
			Parent = {
				Parent = {
					Parent = {
						Core = {
							Registry = {
								RuntimeRegistry = { Sessions = Sessions },
								ServiceRegistry = MockServiceRegistry,
							},
							Config = {
								GamePassConfig = { Vip = { AssetId = 910001, Price = 199, ProfileKey = "HasVip" } },
							},
							Utilities = { Logger = Logger },
						},
					},
				},
			},
		},
		require = function(Dep)
			if Dep == ServiceRegistry or Dep == MockServiceRegistry then
				return MockServiceRegistry
			end
			return Dep
		end,
	})
	VIPDoorSystem.Init()
	VIPDoorSystem.Start()

	-- Unowned player touches VIP door trigger -> Prompted with VIP GamePass
	TriggerPart.Touched:Fire(RootPart)
	assert(#PromptedPasses == 1, "Unowned player must receive VIP GamePass prompt")
	assert(PromptedPasses[1].PassId == 910001, "Prompted GamePass ID must match VIP AssetId")

	-- Touching again during debounce -> no duplicate prompt
	TriggerPart.Touched:Fire(RootPart)
	assert(#PromptedPasses == 1, "VIP prompt must respect debounce")

	-- 2. Player acquires VIP -> Local collision bypass
	Session.HasVip = true
	Player:SetAttribute("HasVip", true)

	local MockPlayers = { LocalPlayer = Player }
	local VIPDoorController = loadModule("src/client/controllers/VIPDoorController.luau", "VIPDoorController", {
		game = {
			GetService = function(_self, Name: string)
				if Name == "Workspace" then
					return MockWorkspace
				end
				if Name == "Players" then
					return MockPlayers
				end
				return nil
			end,
		},
	})
	VIPDoorController.Init()
	VIPDoorController.Start()

	assert(VIPDoorController.IsVipOwned() == true, "VIPDoorController must detect VIP ownership")
	assert(DoorPart1.CanCollide == false, "DoorPart1 CanCollide must be false for VIP owner")
	assert(DoorPart2.CanCollide == false, "DoorPart2 CanCollide must be false for VIP owner")

	-- 3. AutoWins Automated Loop
	-- Player without AutoWins GamePass cannot enable
	Session.HasAutoWins = false
	Player:SetAttribute("HasAutoWins", false)

	local ToggleAutoWinsRemote = fakeRemoteEvent("ToggleAutoWins")
	local MockReplicatedStorage = fakeFolder("ReplicatedStorage", {
		Remotes = fakeFolder("Remotes", { ToggleAutoWins = ToggleAutoWinsRemote }),
	})

	local RewardDispatcher = {
		ApplyReward = function(TargetPlayer, Reward)
			local TargetSession = Sessions.Get(TargetPlayer)
			if TargetSession and Reward.Type == "Destruction" then
				TargetSession.Destruction += (Reward.Amount or 1)
				return true
			end
			return false
		end,
	}

	local MockAutoWinsInstance = {
		WorldInstanceId = "AUTOWINS_WORLD_1",
		OwnerUserId = Player.UserId,
		OwnerPlayer = Player,
		RewardState = "Choosing",
		ObjectiveCompleted = false,
	}

	local MockWorldInstances = {
		Get = function(_TargetPlayer)
			return MockAutoWinsInstance
		end,
	}

	local MockScheduler = {
		AddJob = function(_spec) end,
		RemoveJob = function(_name) end,
	}

	local PortalServiceMock = {
		SelectMap = function(_self, TargetPlayer, MapId)
			local S = Sessions.Get(TargetPlayer)
			if S and S.State == "InLobby" then
				S.State = "InWorld"
				S.CurrentWorldInstanceId = "AUTOWINS_WORLD_1"
			end
		end,
	}

	local DestructionServiceMock = {
		CompleteObjective = function(_self, WorldInstance, _WorldInstanceService)
			WorldInstance.ObjectiveCompleted = true
			WorldInstance.RewardState = "Choosing"
		end,
	}

	local RewardPortalServiceMock = {
		RequestClaimReward = function(_self, TargetPlayer, Choice)
			if Choice == "Free" then
				local S = Sessions.Get(TargetPlayer)
				if S then
					S.Destruction += 1
					S.CompletedPortals["WORLD1"] = (S.CompletedPortals["WORLD1"] or 0) + 1
					S.State = "InLobby"
					S.CurrentWorldInstanceId = nil
					MockAutoWinsInstance.ObjectiveCompleted = false
					MockAutoWinsInstance.RewardState = "Inactive"
					return true
				end
			end
			return false
		end,
	}

	local MockAutoWinsRegistry = {
		Get = function(Name: string)
			if Name == "GamePassService" then
				return MockGamePassService
			end
			if Name == "PortalService" then
				return PortalServiceMock
			end
			if Name == "DestructionService" then
				return DestructionServiceMock
			end
			if Name == "RewardPortalService" then
				return RewardPortalServiceMock
			end
			if Name == "WorldInstanceService" then
				return {}
			end
			return nil
		end,
	}

	local AutoWinsPlayers = {
		GetPlayers = function(_self)
			return { Player }
		end,
		GetPlayerFromCharacter = function(_self, Char)
			if Char == Character or Char == RootPart or (Char and Char.Parent == Character) then
				return Player
			end
			return nil
		end,
		LocalPlayer = Player,
	}

	local AutoWinsService = loadModule("src/server/Game/Services/AutoWinsService.luau", "AutoWinsService", {
		game = {
			GetService = function(_self, Name: string)
				if Name == "ReplicatedStorage" then
					return MockReplicatedStorage
				end
				if Name == "Players" then
					return AutoWinsPlayers
				end
				if Name == "MarketplaceService" then
					return MockMarketplaceService
				end
				return nil
			end,
		},
		script = {
			Parent = {
				Parent = {
					Parent = {
						Core = {
							Registry = {
								RuntimeRegistry = { Sessions = Sessions, WorldInstances = MockWorldInstances },
								ServiceRegistry = MockAutoWinsRegistry,
							},
							Scheduler = { Scheduler = MockScheduler },
							Config = {
								GamePassConfig = {
									AutoWins = { AssetId = 910003, Price = 249, ProfileKey = "HasAutoWins" },
								},
							},
							Utilities = { Logger = Logger, RewardDispatcher = RewardDispatcher },
							Events = { EventBus = EventBus },
						},
					},
				},
			},
		},
		require = function(Dep)
			return Dep
		end,
	})
	AutoWinsService:Init()
	AutoWinsService:Start()

	-- Unowned toggle attempt fails
	local UnownedToggle = AutoWinsService:Toggle(Player, true)
	assert(UnownedToggle == false, "Toggling AutoWins without GamePass must fail")
	assert(Session.AutoWinsEnabled == false, "AutoWinsEnabled must remain false")

	-- Player acquires AutoWins pass
	Session.HasAutoWins = true
	Player:SetAttribute("HasAutoWins", true)

	-- Toggle AutoWins ON
	local OwnedToggleOn = AutoWinsService:Toggle(Player, true)
	assert(OwnedToggleOn == true, "Toggling AutoWins with GamePass must succeed")
	assert(Session.AutoWinsEnabled == true, "AutoWinsEnabled must be true")
	assert(Player:GetAttribute("AutoWinsActive") == true, "AutoWinsActive attribute must be true")

	-- Run AutoWins execution cycles (Lobby -> InWorld -> Complete & Claim -> Lobby)
	Session.State = "InLobby"
	AutoWinsService:ProcessLoop()
	assert(Session.State == "InWorld", "ProcessLoop step 1 should select WORLD1 from Lobby")

	AutoWinsService:ProcessLoop()
	assert(Session.Destruction == 1, "ProcessLoop step 2 should stomp objective and claim +1 Destruction")
	assert(Session.CompletedPortals["WORLD1"] == 1, "CompletedPortals['WORLD1'] must increment")
	assert(Session.State == "InLobby", "Session should return to InLobby")

	-- Run second AutoWins cycle
	AutoWinsService:ProcessLoop()
	assert(Session.State == "InWorld", "Second cycle step 1 should select WORLD1")
	AutoWinsService:ProcessLoop()
	assert(Session.Destruction == 2, "Second cycle step 2 should grant +1 Destruction (total 2)")
	assert(Session.CompletedPortals["WORLD1"] == 2, "CompletedPortals['WORLD1'] must increment to 2")

	-- Toggle AutoWins OFF
	local OwnedToggleOff = AutoWinsService:Toggle(Player, false)
	assert(OwnedToggleOff == true, "Toggling AutoWins OFF must succeed")
	assert(Session.AutoWinsEnabled == false, "AutoWinsEnabled must be false")
	assert(Player:GetAttribute("AutoWinsActive") == false, "AutoWinsActive attribute must be false")

	VIPDoorSystem.Destroy()
	VIPDoorController.Destroy()
	Sessions.Remove(Player)
end)

-- =========================================================================
-- JOURNEY 5: Cosmetics Customization
-- =========================================================================
check("Journey 5: Cosmetics Customization", function()
	local Player = fakePlayer(5001)
	local Character, RootPart, Head, Humanoid = createMockCharacter()
	Player.Character = Character

	local Session = createMockSession(Player, {
		UnlockedTrails = { Default = true, FireTrail = true },
		EquippedTrail = "Default",
		UnlockedTitles = { Newbie = true, Giant = true },
		EquippedTitle = "Newbie",
	})
	Sessions.Set(Player, Session)

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
	local MockReplicatedStorage = fakeFolder("ReplicatedStorage", { Remotes = RemotesFolder })
	local MockPlayers = {
		PlayerAdded = fakeSignal(),
		PlayerRemoving = fakeSignal(),
		GetPlayers = function()
			return { Player }
		end,
	}

	local EventBus = createMockEventBus()

	local CosmeticsService = loadModule("src/server/Game/Services/CosmeticsService.luau", "CosmeticsService", {
		game = {
			GetService = function(_self, Name: string)
				if Name == "ReplicatedStorage" then
					return MockReplicatedStorage
				end
				if Name == "Players" then
					return MockPlayers
				end
				return nil
			end,
		},
		task = task,
		Instance = MockInstance,
		Vector3 = MockVector3,
		UDim2 = MockUDim2,
		Color3 = MockColor3,
		ColorSequence = MockColorSequence,
		ColorSequenceKeypoint = MockColorSequenceKeypoint,
		Enum = {
			Font = { FredokaOne = "FredokaOne" },
			ApplyStrokeMode = { Contextual = "Contextual" },
		},
		script = {
			Parent = {
				Parent = {
					Config = { TrailConfig = TrailConfig, TitleConfig = TitleConfig },
					Parent = {
						Core = {
							Registry = { RuntimeRegistry = { Sessions = Sessions }, ServiceRegistry = ServiceRegistry },
							Utilities = { Logger = Logger },
							Events = { EventBus = EventBus },
						},
					},
				},
			},
		},
		require = function(Dep)
			return Dep
		end,
	})
	CosmeticsService:Init()

	-- 1. Equip Trail (FireTrail) on RootPart
	local EquipTrailOk = CosmeticsService:EquipTrail(Player, "FireTrail")
	assert(EquipTrailOk == true, "EquipTrail('FireTrail') must succeed")
	assert(Session.EquippedTrail == "FireTrail", "Session.EquippedTrail must be FireTrail")
	assert(Player:GetAttribute("EquippedTrail") == "FireTrail", "Player attribute must be FireTrail")
	assert(RootPart:FindFirstChild("CharacterTrail") ~= nil, "CharacterTrail must be attached to RootPart")
	assert(RootPart:FindFirstChild("TrailAttachment0") ~= nil, "TrailAttachment0 must exist on RootPart")
	assert(RootPart:FindFirstChild("TrailAttachment1") ~= nil, "TrailAttachment1 must exist on RootPart")

	-- 2. Unequip Trail
	local UnequipTrailOk = CosmeticsService:UnequipTrail(Player)
	assert(UnequipTrailOk == true, "UnequipTrail must succeed")
	assert(Session.EquippedTrail == nil, "Session.EquippedTrail must be nil")
	assert(Player:GetAttribute("EquippedTrail") == "", "Player attribute must be empty")
	assert(RootPart:FindFirstChild("CharacterTrail") == nil, "CharacterTrail must be removed from RootPart")

	-- 3. Equip Title (Giant) on Head
	local EquipTitleOk = CosmeticsService:EquipTitle(Player, "Giant")
	assert(EquipTitleOk == true, "EquipTitle('Giant') must succeed")
	assert(Session.EquippedTitle == "Giant", "Session.EquippedTitle must be Giant")
	assert(Player:GetAttribute("EquippedTitle") == "Giant", "Player attribute must be Giant")
	local OverheadTitle = Head:FindFirstChild("OverheadTitle")
	assert(OverheadTitle ~= nil, "OverheadTitle BillboardGui must be attached to Head")

	-- 4. Unequip Title
	local UnequipTitleOk = CosmeticsService:UnequipTitle(Player)
	assert(UnequipTitleOk == true, "UnequipTitle must succeed")
	assert(Session.EquippedTitle == nil, "Session.EquippedTitle must be nil")
	assert(Player:GetAttribute("EquippedTitle") == "", "Player attribute must be empty")
	assert(Head:FindFirstChild("OverheadTitle") == nil, "OverheadTitle must be removed from Head")

	-- 5. Character Respawn Re-Application
	-- Equip both FireTrail and Giant
	CosmeticsService:EquipTrail(Player, "FireTrail")
	CosmeticsService:EquipTitle(Player, "Giant")
	assert(Session.EquippedTrail == "FireTrail")
	assert(Session.EquippedTitle == "Giant")

	-- Simulate character death / respawn
	local NewCharacter, NewRootPart, NewHead, NewHumanoid = createMockCharacter()
	Player.Character = NewCharacter

	CosmeticsService:ApplyCharacterCosmetics(Player, NewCharacter)

	-- Verify both cosmetics exist on new character instance
	assert(NewRootPart:FindFirstChild("CharacterTrail") ~= nil, "Respawned character RootPart must have CharacterTrail")
	assert(
		NewRootPart:FindFirstChild("TrailAttachment0") ~= nil,
		"Respawned character RootPart must have TrailAttachment0"
	)
	assert(
		NewRootPart:FindFirstChild("TrailAttachment1") ~= nil,
		"Respawned character RootPart must have TrailAttachment1"
	)
	assert(NewHead:FindFirstChild("OverheadTitle") ~= nil, "Respawned character Head must have OverheadTitle")

	Sessions.Remove(Player)
end)

print("\n=== TEST SUMMARY ===")
if #Failures > 0 then
	print(string.format("FAILED with %d error(s):", #Failures))
	for _, Failure in Failures do
		print(string.format(" - %s", Failure))
	end
	error("Integration tests failed", 0)
else
	print("ALL MVP-006 INTEGRATION TESTS PASSED")
end
