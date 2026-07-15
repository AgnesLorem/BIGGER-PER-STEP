--!strict
--// Types \\--

export type WorldInstance = {
	WorldInstanceId: string,
	OwnerUserId: number,
	OwnerPlayer: Player,
	Model: Instance,
	ObjectiveActive: boolean,
	ObjectiveCompleted: boolean,
	ObjectiveId: string,
	Connections: { RBXScriptConnection },
}

--// Variables \\--

local ActiveWorldInstances: { [Player]: WorldInstance } = {}

--// Service \\--

local WorldInstances = {}

function WorldInstances.Get(Player: Player): WorldInstance?
	return ActiveWorldInstances[Player]
end

function WorldInstances.Set(Player: Player, WorldInstance: WorldInstance)
	ActiveWorldInstances[Player] = WorldInstance
end

function WorldInstances.Remove(Player: Player)
	ActiveWorldInstances[Player] = nil
end

function WorldInstances.GetAll(): { [Player]: WorldInstance }
	return ActiveWorldInstances
end

return table.freeze(WorldInstances)
