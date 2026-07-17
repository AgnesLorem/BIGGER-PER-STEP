--!strict
--// Requirings \\--

local Logger = require(script.Parent.Parent.Utilities.Logger)
local Timers = require(script.Parent.Parent.Registry.RuntimeRegistry.Timers)

--// Types \\--

export type JobConfig = {
	Name: string,
	IntervalSeconds: number,
	Callback: () -> (),
	Priority: number?,
}

--// Variables \\--

local Jobs: { [string]: JobConfig } = {}

--// Service \\--

local Scheduler = {}

function Scheduler.AddJob(Config: JobConfig)
	if Config.Name == "" then
		error("[Scheduler] Job name cannot be empty")
	end
	if Config.IntervalSeconds <= 0 then
		error("[Scheduler] IntervalSeconds must be positive")
	end
	if Jobs[Config.Name] then
		error(`[Scheduler] Job already exists: {Config.Name}`)
	end
	Jobs[Config.Name] = Config
end

function Scheduler.RemoveJob(Name: string)
	Jobs[Name] = nil
	local Handle = Timers.Get(Name)
	if not Handle then
		return
	end
	task.cancel(Handle)
	Timers.Remove(Name)
end

function Scheduler.Start()
	local Count = 0
	for Name, Config in Jobs do
		Count += 1
		local Handle = task.spawn(function()
			while true do
				task.wait(Config.IntervalSeconds)
				local Success, Message = xpcall(Config.Callback, debug.traceback)
				if not Success then
					Logger.Warn("Scheduler", "Job %s failed: %s", Name, tostring(Message))
				end
			end
		end)
		Timers.Set(Name, Handle)
	end
	Logger.Info("Scheduler", "Started %d jobs", Count)
end

function Scheduler.Stop()
	for Name, _ in Jobs do
		local Handle = Timers.Get(Name)
		if not Handle then
			continue
		end
		task.cancel(Handle)
		Timers.Remove(Name)
	end
	Logger.Info("Scheduler", "Stopped all jobs")
end

return table.freeze(Scheduler)
