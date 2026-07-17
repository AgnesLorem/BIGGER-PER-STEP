return function(Player: Player, SessionService: any, Sessions: any, DestructionService: any)
	for _, State in { "EnteringWorld", "InWorld", "Returning" } do
		local Session = Sessions.Get(Player)
		assert(Session, "test player session missing")
		Session.State = State
		Session.CurrentWorldInstanceId = "RECOVERY_TEST"
		Player:SetAttribute("CurrentWorldId", "WORLD1")
		Player:SetAttribute("ObjectiveActive", true)
		Player:SetAttribute("ObjectiveText", "test")
		Player:SetAttribute("ObjectiveReward", "test")

		assert(SessionService:RecoverToLobby(Player, `Test_{State}`) == true)
		assert(Session.State == "InLobby")
		assert(Session.CurrentWorldInstanceId == nil)
		assert(Player:GetAttribute("CurrentWorldId") == nil)
		assert(Player:GetAttribute("ObjectiveActive") == false)
		assert(Player:GetAttribute("ObjectiveText") == nil)
		assert(Player:GetAttribute("ObjectiveReward") == nil)

		Session.State = State
		Session.CurrentWorldInstanceId = "RECOVERY_REPEAT_TEST"
		Player:SetAttribute("CurrentWorldId", "WORLD1")
		Player:SetAttribute("ObjectiveActive", true)
		Player:SetAttribute("ObjectiveText", "repeat")
		Player:SetAttribute("ObjectiveReward", "repeat")
		assert(SessionService:RecoverToLobby(Player, `Repeat_{State}`) == true)
		assert(Session.State == "InLobby")
		assert(Session.CurrentWorldInstanceId == nil)
		assert(Player:GetAttribute("CurrentWorldId") == nil)
		assert(Player:GetAttribute("ObjectiveActive") == false)
		assert(Player:GetAttribute("ObjectiveText") == nil)
		assert(Player:GetAttribute("ObjectiveReward") == nil)
	end

	local Session = Sessions.Get(Player)
	assert(Session, "test player session missing")
	local Character = Player.Character or Player.CharacterAdded:Wait()
	local RootPart = Character:FindFirstChild("HumanoidRootPart") or Character:WaitForChild("HumanoidRootPart", 10)
	assert(RootPart and RootPart:IsA("BasePart"), "test player root missing")

	local Hitbox = Instance.new("Part")
	Hitbox.Anchored = true
	Hitbox.Size = Vector3.new(20, 2, 20)
	Hitbox.CFrame = RootPart.CFrame - Vector3.new(0, 5, 0)
	RootPart.AssemblyLinearVelocity = Vector3.new(0, -10, 0)

	local InitialDestruction = Session.Destruction
	Session.State = "InWorld"
	Session.CurrentWorldInstanceId = "COORDINATOR_TEST"
	local WorldInstance = {
		WorldInstanceId = "COORDINATOR_TEST",
		OwnerUserId = Player.UserId,
		OwnerPlayer = Player,
		Model = Hitbox,
		ObjectiveActive = true,
		ObjectiveCompleted = false,
		Connections = {},
	}

	local CoordinatorUsed = false
	local Coordinator = {}
	function Coordinator:ReturnPlayerToLobby(_Player: Player): boolean
		return false
	end
	function Coordinator:RecoverPlayer(RecoverPlayer: Player, Reason: string, Respawn: boolean)
		CoordinatorUsed = Reason == "ReturnSpawnUnavailableAtCompletion" and Respawn
		SessionService:RecoverToLobby(RecoverPlayer, Reason)
	end

	DestructionService:TryCompleteObjective(WorldInstance, Hitbox, RootPart, Coordinator)
	Session.Destruction = InitialDestruction
	Player:SetAttribute("Destruction", InitialDestruction)
	local Leaderstats = Player:FindFirstChild("leaderstats")
	local DestructionStat = Leaderstats and Leaderstats:FindFirstChild("Destruction")
	if DestructionStat and DestructionStat:IsA("IntValue") then
		DestructionStat.Value = InitialDestruction
	end
	Hitbox:Destroy()

	assert(CoordinatorUsed, "objective completion ignored its established recovery coordinator")
end
