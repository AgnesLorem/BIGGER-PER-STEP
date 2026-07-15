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
	Objective = table.freeze({
		ObjectiveId = "WORLD1_SPIDER",
		ModelName = "Spider",
		HitboxName = "ObjectiveHitbox",
		Text = "Stomp the Spider",
		Reward = "+1 Destruction",
		DestructionReward = 1,
		MinimumDownwardVelocity = -2,
		AboveHitboxPadding = 1,
	}),
})
