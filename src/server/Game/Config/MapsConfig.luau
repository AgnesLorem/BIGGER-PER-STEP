--!strict
--// Config \\--

export type ObjectiveConfig = {
	ObjectiveId: string,
	ModelName: string,
	HitboxName: string,
	Text: string,
	Reward: string,
	MinimumDownwardVelocity: number,
	HorizontalPadding: number,
	MaximumRootHeight: number,
}

export type RewardPortalsConfig = {
	FreeName: string,
	PaidName: string,
	FreeDestruction: number,
	PaidDestruction: number,
	PaidProductKey: string,
	FreeLabel: string,
	PaidLabel: string,
}

export type MapDefinition = {
	MapId: string,
	CategoryId: string,
	TemplateName: string,
	Name: string,
	Description: string,
	RequiredLevel: number,
	RequiredSize: number,
	IsComingSoon: boolean,
	Objective: ObjectiveConfig,
	Rewards: RewardPortalsConfig,
}

export type CategoryDefinition = {
	CategoryId: string,
	Name: string,
	Description: string,
	MapIds: { string },
}

local Categories: { [string]: CategoryDefinition } = table.freeze({
	Forest = table.freeze({
		CategoryId = "Forest",
		Name = "Khu Rừng (Forest)",
		Description = "Khu rừng nguyên sinh rậm rạp với các sinh vật tự nhiên khổng lồ.",
		MapIds = table.freeze({ "MAP1", "MAP2", "MAP3" }),
	}),
	Residential = table.freeze({
		CategoryId = "Residential",
		Name = "Khu Dân Cư (Residential)",
		Description = "Khu đô thị ngoại ô với các công trình nhà ở và chướng ngại vật cơ khí.",
		MapIds = table.freeze({ "MAP4", "MAP5", "MAP6" }),
	}),
	Metropolis = table.freeze({
		CategoryId = "Metropolis",
		Name = "Siêu Đô Thị (Metropolis)",
		Description = "Đại đô thị tương lai với các tòa nhà chọc trời và robot khổng lồ.",
		MapIds = table.freeze({ "MAP7", "MAP8", "MAP9", "MAP10" }),
	}),
})

local Maps: { [string]: MapDefinition } = table.freeze({
	MAP1 = table.freeze({
		MapId = "MAP1",
		CategoryId = "Forest",
		TemplateName = "MAP1",
		Name = "Nhện Rừng (Forest Spider)",
		Description = "Tiêu diệt con nhện rừng gai góc ẩn nấp sâu trong rừng sâu.",
		RequiredLevel = 5,
		RequiredSize = 50,
		IsComingSoon = false,
		Objective = table.freeze({
			ObjectiveId = "MAP1_SPIDER",
			ModelName = "Spider",
			HitboxName = "ObjectiveHitbox",
			Text = "Stomp the Spider",
			Reward = "+1 Destruction",
			MinimumDownwardVelocity = -2,
			HorizontalPadding = 1,
			MaximumRootHeight = 8,
		}),
		Rewards = table.freeze({
			FreeName = "FreeRewardPortal",
			PaidName = "PaidRewardPortal",
			FreeDestruction = 1,
			PaidDestruction = 3,
			PaidProductKey = "World1TripleReward",
			FreeLabel = "FREE\n+1 DESTRUCTION",
			PaidLabel = "3 DESTRUCTION • 29 R$",
		}),
	}),
	MAP2 = table.freeze({
		MapId = "MAP2",
		CategoryId = "Forest",
		TemplateName = "MAP2",
		Name = "Heo Rừng Gai (Wild Boar)",
		Description = "Dẫm nát heo rừng hung hãn với cặp ngà nhọn hoắt.",
		RequiredLevel = 15,
		RequiredSize = 500,
		IsComingSoon = false,
		Objective = table.freeze({
			ObjectiveId = "MAP2_BOAR",
			ModelName = "WildBoar",
			HitboxName = "ObjectiveHitbox",
			Text = "Stomp the Wild Boar",
			Reward = "+5 Destruction",
			MinimumDownwardVelocity = -2,
			HorizontalPadding = 1.2,
			MaximumRootHeight = 10,
		}),
		Rewards = table.freeze({
			FreeName = "FreeRewardPortal",
			PaidName = "PaidRewardPortal",
			FreeDestruction = 5,
			PaidDestruction = 15,
			PaidProductKey = "World2TripleReward",
			FreeLabel = "FREE\n+5 DESTRUCTION",
			PaidLabel = "15 DESTRUCTION • 29 R$",
		}),
	}),
	MAP3 = table.freeze({
		MapId = "MAP3",
		CategoryId = "Forest",
		TemplateName = "MAP3",
		Name = "Gấu Chúa Cổ Đại (Ancient Bear)",
		Description = "Đối đầu gấu chúa hộ thần với giáp đá cổ ngữ uy mãnh.",
		RequiredLevel = 35,
		RequiredSize = 5000,
		IsComingSoon = false,
		Objective = table.freeze({
			ObjectiveId = "MAP3_BEAR",
			ModelName = "AncientBear",
			HitboxName = "ObjectiveHitbox",
			Text = "Stomp the Ancient Bear",
			Reward = "+20 Destruction",
			MinimumDownwardVelocity = -2,
			HorizontalPadding = 1.5,
			MaximumRootHeight = 14,
		}),
		Rewards = table.freeze({
			FreeName = "FreeRewardPortal",
			PaidName = "PaidRewardPortal",
			FreeDestruction = 20,
			PaidDestruction = 60,
			PaidProductKey = "World3TripleReward",
			FreeLabel = "FREE\n+20 DESTRUCTION",
			PaidLabel = "60 DESTRUCTION • 29 R$",
		}),
	}),
	MAP4 = table.freeze({
		MapId = "MAP4",
		CategoryId = "Residential",
		TemplateName = "MAP4",
		Name = "Xe Tải Hỏng (Crashed Truck)",
		Description = "Khu ngoại ô yên bình bị chặn bởi xe tải khổng lồ.",
		RequiredLevel = 60,
		RequiredSize = 25000,
		IsComingSoon = true,
		Objective = table.freeze({
			ObjectiveId = "MAP4_TRUCK",
			ModelName = "CrashedTruck",
			HitboxName = "ObjectiveHitbox",
			Text = "Crush the Truck",
			Reward = "+50 Destruction",
			MinimumDownwardVelocity = -2,
			HorizontalPadding = 2,
			MaximumRootHeight = 16,
		}),
		Rewards = table.freeze({
			FreeName = "FreeRewardPortal",
			PaidName = "PaidRewardPortal",
			FreeDestruction = 50,
			PaidDestruction = 150,
			PaidProductKey = "World4TripleReward",
			FreeLabel = "FREE\n+50 DESTRUCTION",
			PaidLabel = "150 DESTRUCTION • 29 R$",
		}),
	}),
	MAP5 = table.freeze({
		MapId = "MAP5",
		CategoryId = "Residential",
		TemplateName = "MAP5",
		Name = "Biệt Thự Bỏ Hoang (Abandoned Villa)",
		Description = "Tòa nhà 2 tầng cũ kỹ cần được giải tỏa.",
		RequiredLevel = 100,
		RequiredSize = 100000,
		IsComingSoon = true,
		Objective = table.freeze({
			ObjectiveId = "MAP5_VILLA",
			ModelName = "AbandonedVilla",
			HitboxName = "ObjectiveHitbox",
			Text = "Demolish the Villa",
			Reward = "+120 Destruction",
			MinimumDownwardVelocity = -2,
			HorizontalPadding = 2.5,
			MaximumRootHeight = 20,
		}),
		Rewards = table.freeze({
			FreeName = "FreeRewardPortal",
			PaidName = "PaidRewardPortal",
			FreeDestruction = 120,
			PaidDestruction = 360,
			PaidProductKey = "World5TripleReward",
			FreeLabel = "FREE\n+120 DESTRUCTION",
			PaidLabel = "360 DESTRUCTION • 29 R$",
		}),
	}),
	MAP6 = table.freeze({
		MapId = "MAP6",
		CategoryId = "Residential",
		TemplateName = "MAP6",
		Name = "Cần Cẩu Công Trình (Construction Crane)",
		Description = "Cần cẩu thép cao sừng sững tại khu công trường.",
		RequiredLevel = 150,
		RequiredSize = 500000,
		IsComingSoon = true,
		Objective = table.freeze({
			ObjectiveId = "MAP6_CRANE",
			ModelName = "ConstructionCrane",
			HitboxName = "ObjectiveHitbox",
			Text = "Topple the Crane",
			Reward = "+300 Destruction",
			MinimumDownwardVelocity = -2,
			HorizontalPadding = 3,
			MaximumRootHeight = 25,
		}),
		Rewards = table.freeze({
			FreeName = "FreeRewardPortal",
			PaidName = "PaidRewardPortal",
			FreeDestruction = 300,
			PaidDestruction = 900,
			PaidProductKey = "World6TripleReward",
			FreeLabel = "FREE\n+300 DESTRUCTION",
			PaidLabel = "900 DESTRUCTION • 29 R$",
		}),
	}),
	MAP7 = table.freeze({
		MapId = "MAP7",
		CategoryId = "Metropolis",
		TemplateName = "MAP7",
		Name = "Trạm Điện Giao Lộ (Power Substation)",
		Description = "Trạm điện cao thế cấp năng lượng cho thành phố.",
		RequiredLevel = 220,
		RequiredSize = 2500000,
		IsComingSoon = true,
		Objective = table.freeze({
			ObjectiveId = "MAP7_POWER",
			ModelName = "PowerSubstation",
			HitboxName = "ObjectiveHitbox",
			Text = "Overload Substation",
			Reward = "+800 Destruction",
			MinimumDownwardVelocity = -2,
			HorizontalPadding = 3.5,
			MaximumRootHeight = 30,
		}),
		Rewards = table.freeze({
			FreeName = "FreeRewardPortal",
			PaidName = "PaidRewardPortal",
			FreeDestruction = 800,
			PaidDestruction = 2400,
			PaidProductKey = "World7TripleReward",
			FreeLabel = "FREE\n+800 DESTRUCTION",
			PaidLabel = "2400 DESTRUCTION • 29 R$",
		}),
	}),
	MAP8 = table.freeze({
		MapId = "MAP8",
		CategoryId = "Metropolis",
		TemplateName = "MAP8",
		Name = "Tháp Ngân Hàng (Bank Tower)",
		Description = "Tòa cao ốc kính hiện đại lộng lẫy.",
		RequiredLevel = 300,
		RequiredSize = 10000000,
		IsComingSoon = true,
		Objective = table.freeze({
			ObjectiveId = "MAP8_BANK",
			ModelName = "BankTower",
			HitboxName = "ObjectiveHitbox",
			Text = "Flatten the Tower",
			Reward = "+2,000 Destruction",
			MinimumDownwardVelocity = -2,
			HorizontalPadding = 4,
			MaximumRootHeight = 35,
		}),
		Rewards = table.freeze({
			FreeName = "FreeRewardPortal",
			PaidName = "PaidRewardPortal",
			FreeDestruction = 2000,
			PaidDestruction = 6000,
			PaidProductKey = "World8TripleReward",
			FreeLabel = "FREE\n+2,000 DESTRUCTION",
			PaidLabel = "6,000 DESTRUCTION • 29 R$",
		}),
	}),
	MAP9 = table.freeze({
		MapId = "MAP9",
		CategoryId = "Metropolis",
		TemplateName = "MAP9",
		Name = "Chiến Hạm Bay (Hover Cruiser)",
		Description = "Tàu bay tuần tra công nghệ cao neo đậu trên nóc nhà.",
		RequiredLevel = 400,
		RequiredSize = 50000000,
		IsComingSoon = true,
		Objective = table.freeze({
			ObjectiveId = "MAP9_CRUISER",
			ModelName = "HoverCruiser",
			HitboxName = "ObjectiveHitbox",
			Text = "Smash the Cruiser",
			Reward = "+5,000 Destruction",
			MinimumDownwardVelocity = -2,
			HorizontalPadding = 5,
			MaximumRootHeight = 40,
		}),
		Rewards = table.freeze({
			FreeName = "FreeRewardPortal",
			PaidName = "PaidRewardPortal",
			FreeDestruction = 5000,
			PaidDestruction = 15000,
			PaidProductKey = "World9TripleReward",
			FreeLabel = "FREE\n+5,000 DESTRUCTION",
			PaidLabel = "15,000 DESTRUCTION • 29 R$",
		}),
	}),
	MAP10 = table.freeze({
		MapId = "MAP10",
		CategoryId = "Metropolis",
		TemplateName = "MAP10",
		Name = "Robot Titan (Titan Mecha)",
		Description = "Trùm cuối người máy bảo vệ lõi năng lượng siêu đô thị.",
		RequiredLevel = 500,
		RequiredSize = 250000000,
		IsComingSoon = true,
		Objective = table.freeze({
			ObjectiveId = "MAP10_TITAN",
			ModelName = "TitanMecha",
			HitboxName = "ObjectiveHitbox",
			Text = "Destroy the Titan",
			Reward = "+15,000 Destruction",
			MinimumDownwardVelocity = -2,
			HorizontalPadding = 6,
			MaximumRootHeight = 50,
		}),
		Rewards = table.freeze({
			FreeName = "FreeRewardPortal",
			PaidName = "PaidRewardPortal",
			FreeDestruction = 15000,
			PaidDestruction = 45000,
			PaidProductKey = "World10TripleReward",
			FreeLabel = "FREE\n+15,000 DESTRUCTION",
			PaidLabel = "45,000 DESTRUCTION • 29 R$",
		}),
	}),
})

local MapsConfig = {
	Categories = Categories,
	Maps = Maps,
	CategoryOrder = table.freeze({ "Forest", "Residential", "Metropolis" }),
	MapOrder = table.freeze({
		"MAP1",
		"MAP2",
		"MAP3",
		"MAP4",
		"MAP5",
		"MAP6",
		"MAP7",
		"MAP8",
		"MAP9",
		"MAP10",
	}),
	TemplateFolderName = "WorldTemplates",
	RuntimeFolderName = "RuntimeWorlds",
	RuntimeOffset = Vector3.new(0, 0, 450),
	TeleportHeightOffset = 5,
	ReturnWorldName = "Big Island",
	ReturnMarkerName = "ReturnSpawn",
	ReturnPortalDebounceSeconds = 1.5,
	PortalName = "Portal_World1",
}

function MapsConfig.GetMap(MapId: string?): MapDefinition?
	if not MapId or type(MapId) ~= "string" then
		return Maps["MAP1"]
	end
	local UpperId = string.upper(MapId)
	if UpperId == "WORLD1" or UpperId == "WORLD_1" or UpperId == "MAP_1" then
		return Maps["MAP1"]
	end
	return Maps[UpperId] or Maps[MapId]
end

function MapsConfig.GetCategory(CategoryId: string): CategoryDefinition?
	return Categories[CategoryId]
end

function MapsConfig.GetMapsInCategory(CategoryId: string): { MapDefinition }
	local Category = Categories[CategoryId]
	if not Category then
		return {}
	end
	local List = {}
	for _, MapId in Category.MapIds do
		local Def = Maps[MapId]
		if Def then
			table.insert(List, Def)
		end
	end
	return List
end

return table.freeze(MapsConfig)
