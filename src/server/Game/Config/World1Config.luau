--!strict
--// Config \\--

return table.freeze({
	WorldId = "WORLD1",
	TemplateName = "WORLD1",
	TemplateFolderName = "WorldTemplates",
	RuntimeFolderName = "RuntimeWorlds",
	RuntimeOffset = Vector3.new(0, 0, 450),
	PortalName = "Portal_World1",
	RequiredLevel = 5,
	EntryMarkerName = "EntrySpawn",
	ReturnWorldName = "Big Island",
	ReturnMarkerName = "ReturnSpawn",
	TeleportHeightOffset = 5,
	ReturnPortalDebounceSeconds = 1.5,
	RewardProductKey = "World1TripleReward",
	RewardPortals = table.freeze({
		FreeName = "FreeRewardPortal",
		PaidName = "PaidRewardPortal",
		FreeDestruction = 1,
		FreeLabel = "FREE • 1 DESTRUCTION",
		PaidLabel = "3 DESTRUCTION • 29 R$",
	}),
	Objective = table.freeze({
		ObjectiveId = "WORLD1_SPIDER",
		ModelName = "Spider",
		HitboxName = "ObjectiveHitbox",
		Text = "Stomp the Spider",
		Reward = "+1 Destruction",
		MinimumDownwardVelocity = -2,
		HorizontalPadding = 1,
		MaximumRootHeight = 8,
	}),
})
