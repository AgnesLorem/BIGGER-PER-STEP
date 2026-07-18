--!strict

local SaveConfig = {
	StoreName = "BiggerPlayerProfiles_v1",
	ProductionPlaceId = 104031194350622,
	AutosaveIntervalSeconds = 60,
	LeaseDurationSeconds = 180,
	ShutdownTimeoutSeconds = 25,
	MaximumOfflineSeconds = 28800,
	OfflineRewardPerMinute = 30,
}

function SaveConfig.ResolveScope(IsStudio: boolean, PlaceId: number): string
	if IsStudio then
		return "Studio"
	end
	if PlaceId == SaveConfig.ProductionPlaceId then
		return "Production"
	end
	error(string.format("SaveConfig: unknown live PlaceId %s", tostring(PlaceId)), 2)
end

function SaveConfig.ProfileKey(UserId: number): string
	if UserId % 1 ~= 0 or UserId < 1 then
		error("SaveConfig: UserId must be a positive integer", 2)
	end
	return "Player_" .. tostring(UserId)
end

return table.freeze(SaveConfig)
