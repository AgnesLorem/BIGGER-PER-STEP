--!strict
--// Types \\--

export type Session = {
	Player: Player,
	Bigger: number,
	Destruction: number,
	Rebirth: number,
	UnlockedGrowthUpgrades: { [string]: boolean },
	EquippedGrowthUpgrade: string?,
	CompletedPortals: { [string]: boolean },
	Settings: {
		SoundEnabled: boolean,
		MusicEnabled: boolean,
	},
	State: string,
	JoinedAt: number,
	PurchaseHistory: { [string]: number },
	CurrentWorldInstanceId: string?,
	HasDoubleMultiplier: boolean,
	HasVip: boolean,
	HasPremiumZonePass: boolean,
	HasAutoWins: boolean,
	DailyRewardDay: number,
	LastDailyClaimTimestamp: number,
	SpinTokens: number,
	UnlockedTrails: { [string]: true },
	EquippedTrail: string?,
	UnlockedTitles: { [string]: true },
	EquippedTitle: string?,
	AutoWinsEnabled: boolean,
	GrowthRemainder: number,
	CurrentAFKZone: string?,
	PremiumZonePromptedThisEntry: boolean,
	GamePassQueryGenerations: { Vip: number, PremiumZone: number },
	EquipmentRequestInFlight: boolean,
	EquipmentLastRequestTimestamp: number,
	LastActiveTimestamp: number,
	LastLogoutTimestamp: number,
	LastSaveTimestamp: number,
	ProfileMutationsFrozen: boolean,
	ProfileMutationFreezeReason: string?,
}

--// Variables \\--

local ActiveSessions: { [Player]: Session } = {}

--// Service \\--

local Sessions = {}

function Sessions.Get(Player: Player): Session?
	return ActiveSessions[Player]
end

function Sessions.Set(Player: Player, Session: Session)
	ActiveSessions[Player] = Session
end

function Sessions.Remove(Player: Player)
	ActiveSessions[Player] = nil
end

function Sessions.Mutate(Player: Player, Callback: (Session) -> ()): boolean
	local Session = ActiveSessions[Player]
	if not Session or Session.ProfileMutationsFrozen then
		return false
	end
	Callback(Session)
	return true
end

return table.freeze(Sessions)
