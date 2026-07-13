--!strict
--// Variables \\--

local ActiveTimers: { [string]: thread } = {}

--// Service \\--

local Timers = {}

function Timers.Set(Key: string, Handle: thread)
	ActiveTimers[Key] = Handle
end

function Timers.Get(Key: string): thread?
	return ActiveTimers[Key]
end

function Timers.Remove(Key: string)
	ActiveTimers[Key] = nil
end

function Timers.Clear()
	table.clear(ActiveTimers)
end

return table.freeze(Timers)
