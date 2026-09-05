local fs = require("@lune/fs")
local luau = require("@lune/luau")
local task = require("@lune/task")

local Sessions = require("../../src/server/Core/Registry/RuntimeRegistry/Sessions")

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

local function fakePart(Name: string, Properties: { [string]: any }?)
	local Part = {
		Name = Name,
		ClassName = "Part",
		CanCollide = true,
		Transparency = 0,
		Touched = fakeSignal(),
		Children = {},
	}
	if Properties then
		for K, V in Properties do
			Part[K] = V
		end
	end
	function Part:IsA(ClassName: string)
		return ClassName == "Part" or ClassName == "BasePart" or ClassName == "Instance"
	end
	function Part:FindFirstChild(ChildName: string, Recursive: boolean?)
		for _, Child in self.Children do
			if Child.Name == ChildName then
				return Child
			end
		end
		if Recursive then
			for _, Child in self.Children do
				if Child.FindFirstChild then
					local Found = Child:FindFirstChild(ChildName, true)
					if Found then
						return Found
					end
				end
			end
		end
		return nil
	end
	function Part:GetChildren()
		local List = {}
		for _, v in self.Children do
			table.insert(List, v)
		end
		return List
	end
	function Part:GetDescendants()
		local List = {}
		for _, v in self.Children do
			table.insert(List, v)
			if v.GetDescendants then
				for _, Desc in v:GetDescendants() do
					table.insert(List, Desc)
				end
			end
		end
		return List
	end
	return Part
end

local function fakeModel(Name: string, ChildrenDict: { [string]: any }?)
	local Model = {
		Name = Name,
		ClassName = "Model",
		Children = {},
	}
	if ChildrenDict then
		for ChildName, Child in ChildrenDict do
			if type(Child) == "table" then
				Child.Parent = Model
				table.insert(Model.Children, Child)
				Model[ChildName] = Child
			end
		end
	end
	function Model:IsA(ClassName: string)
		return ClassName == "Model" or ClassName == "Instance"
	end
	function Model:FindFirstChild(ChildName: string, Recursive: boolean?)
		for _, Child in self.Children do
			if Child.Name == ChildName then
				return Child
			end
		end
		if Recursive then
			for _, Child in self.Children do
				if Child.FindFirstChild then
					local Found = Child:FindFirstChild(ChildName, true)
					if Found then
						return Found
					end
				end
			end
		end
		return nil
	end
	function Model:FindFirstChildWhichIsA(ClassName: string, _Recursive: boolean?)
		for _, Child in self.Children do
			if Child.IsA and Child:IsA(ClassName) then
				return Child
			end
		end
		return nil
	end
	function Model:GetChildren()
		local List = {}
		for _, v in self.Children do
			table.insert(List, v)
		end
		return List
	end
	function Model:GetDescendants()
		local List = {}
		for _, v in self.Children do
			table.insert(List, v)
			if v.GetDescendants then
				for _, Desc in v:GetDescendants() do
					table.insert(List, Desc)
				end
			end
		end
		return List
	end
	return Model
end

local function createMockWorkspace(ChildrenDict: { [string]: any }?)
	local Workspace = {
		Name = "Workspace",
		ClassName = "Workspace",
		Children = {},
		ChildAdded = fakeSignal(),
		DescendantAdded = fakeSignal(),
	}
	if ChildrenDict then
		for ChildName, Child in ChildrenDict do
			if type(Child) == "table" and (Child.IsA or Child.ClassName or Child.Name) then
				Child.Parent = Workspace
				table.insert(Workspace.Children, Child)
				Workspace[ChildName] = Child
			elseif ChildName == "ChildAdded" or ChildName == "DescendantAdded" then
				Workspace[ChildName] = Child
			end
		end
	end
	function Workspace:FindFirstChild(ChildName: string, Recursive: boolean?)
		for _, Child in self.Children do
			if Child.Name == ChildName then
				return Child
			end
		end
		if Recursive then
			for _, Child in self.Children do
				if Child.FindFirstChild then
					local Found = Child:FindFirstChild(ChildName, true)
					if Found then
						return Found
					end
				end
			end
		end
		return nil
	end
	function Workspace:GetChildren()
		local List = {}
		for _, v in self.Children do
			table.insert(List, v)
		end
		return List
	end
	function Workspace:GetDescendants()
		local List = {}
		for _, v in self.Children do
			table.insert(List, v)
			if v.GetDescendants then
				for _, Desc in v:GetDescendants() do
					table.insert(List, Desc)
				end
			end
		end
		return List
	end
	return Workspace
end

local function fakePlayer(UserId: number)
	local AttributeSignals: { [string]: any } = {}

	local Character = fakeModel("Character")
	local HumanoidRootPart = fakePart("HumanoidRootPart")
	HumanoidRootPart.Parent = Character
	table.insert(Character.Children, HumanoidRootPart)
	Character.HumanoidRootPart = HumanoidRootPart

	local Player = {
		UserId = UserId,
		Name = "TestPlayer_" .. tostring(UserId),
		Attributes = {},
		Character = Character,
	}
	Character.Parent = Player

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
	return Player
end

local function fakeSession(Player: any)
	return {
		Player = Player,
		Bigger = 1,
		Destruction = 0,
		Rebirth = 0,
		UnlockedGrowthUpgrades = {},
		EquippedGrowthUpgrade = nil,
		CompletedPortals = {},
		Settings = { SoundEnabled = true, MusicEnabled = true },
		HasDoubleMultiplier = false,
		HasVip = false,
		HasPremiumZonePass = false,
		HasAutoWins = false,
		DailyRewardDay = 1,
		LastDailyClaimTimestamp = 0,
		SpinTokens = 0,
		UnlockedTrails = {},
		EquippedTrail = nil,
		UnlockedTitles = {},
		EquippedTitle = nil,
		ProcessedPurchaseIds = {},
		ProfileMutationsFrozen = false,
		State = "InLobby",
		GrowthRemainder = 0,
		CurrentAFKZone = nil,
		PremiumZonePromptedThisEntry = false,
		GamePassQueryGenerations = { Vip = 0, PremiumZone = 0, AutoWins = 0 },
	}
end

print("=== Running MVP-006 Task 7 Unit Tests (VIP Gate & Exclusive Zone Handling) ===")

-- Test 1: Server-side VIPDoorSystem prompts unowned player on touch with debounce
check("VIPDoorSystem prompts unowned player on touch and respects debounce", function()
	local PromptCalls = {}
	local IsOwnedMap = {}

	local MockGamePassService = {
		IsOwned = function(_self, Player: any, PassKey: string)
			return IsOwnedMap[Player.UserId] == true
		end,
		Prompt = function(_self, Player: any, PassKey: string)
			table.insert(PromptCalls, { Player = Player, PassKey = PassKey, Time = os.clock() })
			return true
		end,
	}

	local ServiceRegistry = {
		Services = {
			GamePassService = MockGamePassService,
		},
		Get = function(NameOrSelf: any, MaybeName: any)
			local Name = if type(NameOrSelf) == "string" then NameOrSelf else MaybeName
			return MockGamePassService
		end,
		Register = function(_self: any, Name: string, Service: any) end,
	}

	local Logger = {
		Info = function() end,
		Warn = function() end,
		Error = function() end,
	}

	local DoorTrigger = fakePart("Trigger", { CanCollide = false })
	local DoorBarrier = fakePart("DoorBarrier", { CanCollide = true })
	local VIPDoor = fakeModel("VIPDoor", {
		Trigger = DoorTrigger,
		DoorBarrier = DoorBarrier,
	})

	local ChildAddedSignal = fakeSignal()
	local DescendantAddedSignal = fakeSignal()
	local PlayerRemovingSignal = fakeSignal()

	local MockWorkspace = createMockWorkspace({
		VIPDoor = VIPDoor,
		ChildAdded = ChildAddedSignal,
		DescendantAdded = DescendantAddedSignal,
	})

	local MockPlayers = {
		GetPlayerFromCharacter = function(_self, Char: any)
			if Char and Char.Parent and Char.Parent.IsA and Char.Parent:IsA("Player") then
				return Char.Parent
			end
			return nil
		end,
		PlayerRemoving = PlayerRemovingSignal,
	}

	local SystemsFolder = {
		Parent = {
			Parent = {
				Core = {
					Registry = { ServiceRegistry = ServiceRegistry },
					Utilities = { Logger = Logger },
				},
			},
		},
	}

	local Env = {
		script = { Parent = SystemsFolder },
		require = function(Dep)
			return Dep
		end,
		game = {
			GetService = function(_self, Name: string)
				if Name == "Workspace" then
					return MockWorkspace
				elseif Name == "Players" then
					return MockPlayers
				end
				error("unhandled service " .. Name)
			end,
		},
	}

	local VIPDoorSystem = loadModule("src/server/Game/Systems/VIPDoorSystem.luau", "VIPDoorSystem", Env)
	VIPDoorSystem.Init()
	VIPDoorSystem.Start()

	local Player1 = fakePlayer(1001)
	Sessions.Set(Player1, fakeSession(Player1))
	IsOwnedMap[1001] = false

	-- Player touches trigger
	DoorTrigger.Touched:Fire(Player1.Character.HumanoidRootPart)
	assert(#PromptCalls == 1, "Expected 1 prompt call on first touch, got " .. tostring(#PromptCalls))
	assert(PromptCalls[1].Player == Player1, "Expected prompt for Player1")
	assert(PromptCalls[1].PassKey == "Vip", "Expected prompt for Vip pass")

	-- Immediate second touch within debounce should NOT prompt again
	DoorTrigger.Touched:Fire(Player1.Character.HumanoidRootPart)
	assert(#PromptCalls == 1, "Debounce failed: Expected still 1 prompt call, got " .. tostring(#PromptCalls))

	-- Touch from another unowned player should prompt for that player
	local Player2 = fakePlayer(1002)
	Sessions.Set(Player2, fakeSession(Player2))
	IsOwnedMap[1002] = false

	DoorTrigger.Touched:Fire(Player2.Character.HumanoidRootPart)
	assert(#PromptCalls == 2, "Expected prompt for Player2, got " .. tostring(#PromptCalls))
	assert(PromptCalls[2].Player == Player2, "Expected prompt for Player2")

	Sessions.Set(Player1, nil)
	Sessions.Set(Player2, nil)
	VIPDoorSystem.Destroy()
end)

-- Test 2: Server-side VIPDoorSystem does NOT prompt player who owns VIP
check("VIPDoorSystem does not prompt player who owns VIP", function()
	local PromptCalls = {}

	local MockGamePassService = {
		IsOwned = function(_self, _Player: any, PassKey: string)
			return PassKey == "Vip" -- player owns VIP
		end,
		Prompt = function(_self, Player: any, PassKey: string)
			table.insert(PromptCalls, { Player = Player, PassKey = PassKey })
			return true
		end,
	}

	local ServiceRegistry = {
		Services = {
			GamePassService = MockGamePassService,
		},
		Get = function(...)
			local args = { ... }
			local Name = args[#args]
			return ServiceRegistry.Services[Name]
		end,
	}

	local Logger = {
		Info = function() end,
		Warn = function() end,
		Error = function() end,
	}

	local DoorTrigger = fakePart("Trigger", { CanCollide = false })
	local DoorBarrier = fakePart("DoorBarrier", { CanCollide = true })
	local VIPDoor = fakeModel("VIPDoor", {
		Trigger = DoorTrigger,
		DoorBarrier = DoorBarrier,
	})

	local MockWorkspace = createMockWorkspace({
		VIPDoor = VIPDoor,
		ChildAdded = fakeSignal(),
		DescendantAdded = fakeSignal(),
	})

	local MockPlayers = {
		GetPlayerFromCharacter = function(_self, Char: any)
			if Char and Char.Parent and Char.Parent.IsA and Char.Parent:IsA("Player") then
				return Char.Parent
			end
			return nil
		end,
		PlayerRemoving = fakeSignal(),
	}

	local SystemsFolder = {
		Parent = {
			Parent = {
				Core = {
					Registry = { ServiceRegistry = ServiceRegistry },
					Utilities = { Logger = Logger },
				},
			},
		},
	}

	local Env = {
		script = { Parent = SystemsFolder },
		require = function(Dep)
			return Dep
		end,
		game = {
			GetService = function(_self, Name: string)
				if Name == "Workspace" then
					return MockWorkspace
				elseif Name == "Players" then
					return MockPlayers
				end
				error("unhandled service " .. Name)
			end,
		},
	}

	local VIPDoorSystem = loadModule("src/server/Game/Systems/VIPDoorSystem.luau", "VIPDoorSystem", Env)
	VIPDoorSystem.Init()
	VIPDoorSystem.Start()

	local Player = fakePlayer(2001)
	local Session = fakeSession(Player)
	Session.HasVip = true
	Sessions.Set(Player, Session)

	DoorTrigger.Touched:Fire(Player.Character.HumanoidRootPart)
	assert(#PromptCalls == 0, "Expected 0 prompt calls for VIP owner, got " .. tostring(#PromptCalls))

	Sessions.Set(Player, nil)
	VIPDoorSystem.Destroy()
end)

-- Test 3: Server-side VIPDoorSystem handles missing VIP door or missing trigger gracefully
check("VIPDoorSystem handles missing VIP door, missing trigger, and non-player hits safely", function()
	local MockGamePassService = {
		IsOwned = function(_self, _Player: any, _PassKey: string)
			return false
		end,
		Prompt = function(_self, _Player: any, _PassKey: string)
			return true
		end,
	}

	local ServiceRegistry = {
		Services = {
			GamePassService = MockGamePassService,
		},
		Get = function(...)
			local args = { ... }
			local Name = args[#args]
			return ServiceRegistry.Services[Name]
		end,
	}

	local Logger = {
		Info = function() end,
		Warn = function() end,
		Error = function() end,
	}

	local MockWorkspaceEmpty = createMockWorkspace({
		ChildAdded = fakeSignal(),
		DescendantAdded = fakeSignal(),
	})

	local MockPlayers = {
		GetPlayerFromCharacter = function(_self, _Char: any)
			return nil
		end,
		PlayerRemoving = fakeSignal(),
	}

	local SystemsFolder = {
		Parent = {
			Parent = {
				Core = {
					Registry = { ServiceRegistry = ServiceRegistry },
					Utilities = { Logger = Logger },
				},
			},
		},
	}

	local Env = {
		script = { Parent = SystemsFolder },
		require = function(Dep)
			return Dep
		end,
		game = {
			GetService = function(_self, Name: string)
				if Name == "Workspace" then
					return MockWorkspaceEmpty
				elseif Name == "Players" then
					return MockPlayers
				end
				error("unhandled service " .. Name)
			end,
		},
	}

	local VIPDoorSystem = loadModule("src/server/Game/Systems/VIPDoorSystem.luau", "VIPDoorSystem", Env)
	-- Should not error when VIPDoor is missing
	VIPDoorSystem.Init()
	VIPDoorSystem.Start()

	-- Workspace with VIPDoor that has no Trigger
	local IncompleteDoor = fakeModel("VIPDoor", {})
	local DescendantAdded = fakeSignal()
	local MockWorkspaceIncomplete = createMockWorkspace({
		VIPDoor = IncompleteDoor,
		ChildAdded = fakeSignal(),
		DescendantAdded = DescendantAdded,
	})
	local Env2 = {
		script = { Parent = SystemsFolder },
		require = function(Dep)
			return Dep
		end,
		game = {
			GetService = function(_self, Name: string)
				if Name == "Workspace" then
					return MockWorkspaceIncomplete
				elseif Name == "Players" then
					return MockPlayers
				end
				error("unhandled service " .. Name)
			end,
		},
	}
	local VIPDoorSystem2 = loadModule("src/server/Game/Systems/VIPDoorSystem.luau", "VIPDoorSystem", Env2)
	VIPDoorSystem2.Init()
	VIPDoorSystem2.Start()

	-- Dynamic addition of valid VIPDoor via DescendantAdded
	local DynamicTrigger = fakePart("Trigger", { CanCollide = false })
	local DynamicDoor = fakeModel("VIPDoor", { Trigger = DynamicTrigger })

	table.insert(MockWorkspaceIncomplete.Children, DynamicDoor)
	DynamicDoor.Parent = MockWorkspaceIncomplete
	DescendantAdded:Fire(DynamicDoor)

	-- Hit from non-player object (e.g. random debris)
	local RandomPart = fakePart("Debris")
	DynamicTrigger.Touched:Fire(RandomPart)
	-- Should not throw error

	VIPDoorSystem.Destroy()
	VIPDoorSystem2.Destroy()
end)

-- Test 4: Client-side VIPDoorController sets CanCollide = false for VIP owner
check("VIPDoorController sets CanCollide = false when player owns VIP and true when not", function()
	local LocalPlayer = fakePlayer(3001)
	local DoorBarrier1 = fakePart("DoorBarrier1", { CanCollide = true })
	local DoorBarrier2 = fakePart("DoorBarrier2", { CanCollide = true })
	local DoorTrigger = fakePart("Trigger", { CanCollide = false })
	local VIPDoor = fakeModel("VIPDoor", {
		DoorBarrier1 = DoorBarrier1,
		DoorBarrier2 = DoorBarrier2,
		Trigger = DoorTrigger,
	})

	local MockWorkspace = createMockWorkspace({
		VIPDoor = VIPDoor,
		ChildAdded = fakeSignal(),
		DescendantAdded = fakeSignal(),
	})

	local MockPlayers = {
		LocalPlayer = LocalPlayer,
	}

	local Env = {
		script = { Parent = {} },
		require = function(Dep)
			return Dep
		end,
		game = {
			GetService = function(_self, Name: string)
				if Name == "Workspace" then
					return MockWorkspace
				elseif Name == "Players" then
					return MockPlayers
				end
				error("unhandled service " .. Name)
			end,
		},
	}

	local VIPDoorController = loadModule("src/client/controllers/VIPDoorController.luau", "VIPDoorController", Env)
	VIPDoorController.Init()
	VIPDoorController.Start()

	-- Initially unowned: CanCollide should be true on barriers, false on trigger
	assert(VIPDoorController.IsVipOwned() == false, "Expected initial VIP ownership to be false")
	assert(DoorBarrier1.CanCollide == true, "Expected DoorBarrier1 CanCollide = true when unowned")
	assert(DoorBarrier2.CanCollide == true, "Expected DoorBarrier2 CanCollide = true when unowned")
	assert(DoorTrigger.CanCollide == false, "Trigger should remain CanCollide = false")

	-- Set HasVip attribute to true
	LocalPlayer:SetAttribute("HasVip", true)
	assert(VIPDoorController.IsVipOwned() == true, "Expected VIP ownership to be true after HasVip = true")
	assert(DoorBarrier1.CanCollide == false, "Expected DoorBarrier1 CanCollide = false when HasVip = true")
	assert(DoorBarrier2.CanCollide == false, "Expected DoorBarrier2 CanCollide = false when HasVip = true")

	-- Revoke HasVip attribute
	LocalPlayer:SetAttribute("HasVip", false)
	assert(VIPDoorController.IsVipOwned() == false, "Expected VIP ownership to be false after HasVip = false")
	assert(DoorBarrier1.CanCollide == true, "Expected DoorBarrier1 CanCollide = true when HasVip = false")
	assert(DoorBarrier2.CanCollide == true, "Expected DoorBarrier2 CanCollide = true when HasVip = false")

	-- Set Multiplier >= 2 (must NOT grant VIP access)
	LocalPlayer:SetAttribute("Multiplier", 2)
	assert(VIPDoorController.IsVipOwned() == false, "Multiplier >= 2 must not grant VIP access")
	assert(DoorBarrier1.CanCollide == true, "Expected DoorBarrier1 CanCollide = true when only Multiplier is high")

	-- Reset Multiplier
	LocalPlayer:SetAttribute("Multiplier", 1)
	assert(DoorBarrier1.CanCollide == true, "Expected DoorBarrier1 CanCollide = true when Multiplier = 1")

	-- Set VipOwned attribute
	LocalPlayer:SetAttribute("VipOwned", true)
	assert(VIPDoorController.IsVipOwned() == true, "Expected VIP ownership to be true when VipOwned = true")
	assert(DoorBarrier1.CanCollide == false, "Expected DoorBarrier1 CanCollide = false when VipOwned = true")

	if VIPDoorController.Destroy then
		VIPDoorController.Destroy()
	end
end)

-- Test 5: Client-side VIPDoorController handles nested VIPRoom/VIPDoor and dynamic door creation
check("VIPDoorController discovers nested VIPRoom doors and dynamically added doors", function()
	local LocalPlayer = fakePlayer(4001)
	LocalPlayer:SetAttribute("HasVip", true)

	local DescendantAdded = fakeSignal()
	local MockWorkspace = createMockWorkspace({
		ChildAdded = fakeSignal(),
		DescendantAdded = DescendantAdded,
	})

	local MockPlayers = {
		LocalPlayer = LocalPlayer,
	}

	local Env = {
		script = { Parent = {} },
		require = function(Dep)
			return Dep
		end,
		game = {
			GetService = function(_self, Name: string)
				if Name == "Workspace" then
					return MockWorkspace
				elseif Name == "Players" then
					return MockPlayers
				end
				error("unhandled service " .. Name)
			end,
		},
	}

	local VIPDoorController = loadModule("src/client/controllers/VIPDoorController.luau", "VIPDoorController", Env)
	VIPDoorController.Init()
	VIPDoorController.Start()

	-- Dynamically add VIPRoom with VIPDoor
	local DynBarrier = fakePart("DoorBarrier", { CanCollide = true })
	local DynVIPDoor = fakeModel("VIPDoor", { DoorBarrier = DynBarrier })
	local DynVIPRoom = fakeModel("VIPRoom", { VIPDoor = DynVIPDoor })

	table.insert(MockWorkspace.Children, DynVIPRoom)
	DynVIPRoom.Parent = MockWorkspace

	DescendantAdded:Fire(DynVIPDoor)

	assert(
		DynBarrier.CanCollide == false,
		"Dynamically added VIPDoor barrier should be CanCollide = false for VIP owner"
	)

	if VIPDoorController.Destroy then
		VIPDoorController.Destroy()
	end
end)

if #Failures > 0 then
	print(string.format("\nFAILED with %d error(s):", #Failures))
	for _, Failure in Failures do
		print("  - " .. Failure)
	end
	error("MVP-006 Task 7 unit tests failed")
else
	print("\n=== ALL MVP-006 TASK 7 UNIT TESTS PASSED ===")
end
