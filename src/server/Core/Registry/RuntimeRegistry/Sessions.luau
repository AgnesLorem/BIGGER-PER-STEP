--!strict
--// Types \\--

export type Session = {
	Player: Player,
	Bigger: number,
	Destruction: number,
	Rebirth: number,
	State: string,
	JoinedAt: number,
	PurchaseHistory: { [string]: boolean },
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

function Sessions.GetAll(): { [Player]: Session }
	return ActiveSessions
end

return table.freeze(Sessions)
