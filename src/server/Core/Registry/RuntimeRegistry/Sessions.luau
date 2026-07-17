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
	PurchaseHistory: { [string]: boolean },
	CurrentWorldInstanceId: string?,
	HasDoubleMultiplier: boolean,
	HasVip: boolean,
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

return table.freeze(Sessions)
