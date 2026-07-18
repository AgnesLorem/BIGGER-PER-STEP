--!strict

export type RequestKind = "Load" | "Autosave" | "Receipt" | "Final"

export type Request = {
	Kind: RequestKind,
	Callback: () -> ...any,
	Completed: boolean,
	Success: boolean?,
	Results: { any }?,
	ResultCount: number,
	Error: string?,
	CompletionCallbacks: { (boolean, ...any) -> () },
	Waiters: { thread },
}

export type Entry = {
	UserId: number,
	Phase: "Loading" | "Active" | "Releasing" | "Released",
	OwnerToken: string,
	LeaseExpiresAt: number?,
	EntitlementProbe: (any) -> number,
	WriteQueue: { Request },
	Worker: thread?,
	PendingPurchaseIds: { [string]: boolean },
	Released: boolean,
	LastError: string?,
	ActiveRequest: Request?,
	HasFirstRequest: boolean,
}

local Entries: { [number]: Entry } = {}

local Profiles = {}

local function Complete(Request: Request, Success: boolean, PackedResults: { [any]: any })
	Request.Completed = true
	Request.Success = Success
	if Success then
		local Results = {}
		for Index = 2, PackedResults.n do
			Results[Index - 1] = PackedResults[Index]
		end
		Request.Results = Results
		Request.ResultCount = PackedResults.n - 1
	else
		Request.Error = tostring(PackedResults[2])
	end

	for _, CompletionCallback in Request.CompletionCallbacks do
		if Success then
			pcall(CompletionCallback, true, table.unpack(Request.Results, 1, Request.ResultCount))
		else
			pcall(CompletionCallback, false, Request.Error)
		end
	end
	for _, Waiter in Request.Waiters do
		coroutine.resume(Waiter)
	end
	table.clear(Request.Waiters)
end

local function StartWorker(Entry: Entry)
	if Entry.Worker ~= nil then
		return
	end

	local Worker = coroutine.create(function()
		while #Entry.WriteQueue > 0 do
			local Request = table.remove(Entry.WriteQueue, 1)
			Entry.ActiveRequest = Request
			local PackedResults = table.pack(pcall(Request.Callback))
			local Success = PackedResults[1] == true
			if not Success then
				Entry.LastError = tostring(PackedResults[2])
			end

			if Request.Kind == "Load" and Success then
				Entry.Phase = "Active"
			elseif Request.Kind == "Final" then
				if Success then
					Entry.Phase = "Released"
					Entry.Released = true
				elseif not Entry.Released then
					Entry.Phase = "Releasing"
				end
			end
			Entry.ActiveRequest = nil
			if Request.Kind == "Load" and not Success then
				Entry.Released = true
				if Entries[Entry.UserId] == Entry then
					Entries[Entry.UserId] = nil
				end
			end
			Complete(Request, Success, PackedResults)

			if Request.Kind == "Load" and not Success then
				for _, QueuedRequest in Entry.WriteQueue do
					Complete(QueuedRequest, false, table.pack(false, Entry.LastError))
				end
				table.clear(Entry.WriteQueue)
			end
		end
		Entry.Worker = nil
		if Entry.Released and Entries[Entry.UserId] == Entry then
			Entries[Entry.UserId] = nil
		end
	end)
	Entry.Worker = Worker
	coroutine.resume(Worker)
end

function Profiles.Create(UserId: number, OwnerToken: string, EntitlementProbe: (any) -> number): Entry
	if Entries[UserId] ~= nil then
		error(string.format("Profiles: UserId %d already has a runtime entry", UserId), 2)
	end

	local Entry: Entry = {
		UserId = UserId,
		Phase = "Loading",
		OwnerToken = OwnerToken,
		LeaseExpiresAt = nil,
		EntitlementProbe = EntitlementProbe,
		WriteQueue = {},
		Worker = nil,
		PendingPurchaseIds = {},
		Released = false,
		LastError = nil,
		ActiveRequest = nil,
		HasFirstRequest = false,
	}
	Entries[UserId] = Entry
	return Entry
end

function Profiles.Get(UserId: number): Entry?
	return Entries[UserId]
end

function Profiles.Remove(UserId: number, ExpectedEntry: Entry?): boolean
	local Entry = Entries[UserId]
	if Entry == nil or (ExpectedEntry ~= nil and Entry ~= ExpectedEntry) then
		return false
	end
	Entries[UserId] = nil
	return true
end

function Profiles.Enqueue(
	Entry: Entry,
	Kind: RequestKind,
	Callback: () -> ...any,
	CompletionCallback: ((boolean, ...any) -> ())?
): Request
	if Entries[Entry.UserId] ~= Entry then
		error("Profiles: runtime entry is not registered", 2)
	end
	if Entry.Released then
		error("Profiles: runtime entry has been released", 2)
	end
	if not Entry.HasFirstRequest and Kind ~= "Load" then
		error("Profiles: load must be the first worker request", 2)
	end
	if Entry.Phase == "Releasing" and Kind ~= "Final" then
		error("Profiles: runtime entry is releasing", 2)
	end

	if Kind == "Autosave" then
		if Entry.ActiveRequest ~= nil and Entry.ActiveRequest.Kind == "Autosave" then
			if CompletionCallback ~= nil then
				table.insert(Entry.ActiveRequest.CompletionCallbacks, CompletionCallback)
			end
			return Entry.ActiveRequest
		end
		for _, QueuedRequest in Entry.WriteQueue do
			if QueuedRequest.Kind == "Autosave" then
				if CompletionCallback ~= nil then
					table.insert(QueuedRequest.CompletionCallbacks, CompletionCallback)
				end
				return QueuedRequest
			end
		end
	end

	local Request: Request = {
		Kind = Kind,
		Callback = Callback,
		Completed = false,
		Success = nil,
		Results = nil,
		ResultCount = 0,
		Error = nil,
		CompletionCallbacks = {},
		Waiters = {},
	}
	if CompletionCallback ~= nil then
		table.insert(Request.CompletionCallbacks, CompletionCallback)
	end
	Entry.HasFirstRequest = true
	if Kind == "Final" then
		Entry.Phase = "Releasing"
	end
	table.insert(Entry.WriteQueue, Request)
	StartWorker(Entry)
	return Request
end

function Profiles.Await(Request: Request): (boolean, ...any)
	if not Request.Completed then
		table.insert(Request.Waiters, coroutine.running())
		coroutine.yield()
	end
	if Request.Success then
		return true, table.unpack(Request.Results, 1, Request.ResultCount)
	end
	return false, Request.Error
end

return table.freeze(Profiles)
