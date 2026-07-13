--!strict
--// Types \\--

type Subscriber = {
	Callback: (...any) -> (),
	Priority: number,
}

--// Variables \\--

local Subscribers: { [string]: { Subscriber } } = {}

--// Helpers \\--

local function InsertSorted(List: { Subscriber }, Entry: Subscriber)
	for Index, Existing in List do
		if Entry.Priority > Existing.Priority then
			table.insert(List, Index, Entry)
			return
		end
	end
	table.insert(List, Entry)
end

--// Service \\--

local EventBus = {}

function EventBus.Subscribe(EventName: string, Callback: (...any) -> (), Priority: number?)
	local List = Subscribers[EventName]
	if not List then
		List = {}
		Subscribers[EventName] = List
	end
	InsertSorted(List, { Callback = Callback, Priority = Priority or 0 })
end

function EventBus.Publish(EventName: string, ...: any)
	local List = Subscribers[EventName]
	if not List then
		return
	end
	for _, Entry in List do
		Entry.Callback(...)
	end
end

function EventBus.Unsubscribe(EventName: string, Callback: (...any) -> ())
	local List = Subscribers[EventName]
	if not List then
		return
	end
	for Index = #List, 1, -1 do
		if List[Index].Callback == Callback then
			table.remove(List, Index)
			break
		end
	end
end

function EventBus.Clear()
	table.clear(Subscribers)
end

return table.freeze(EventBus)
