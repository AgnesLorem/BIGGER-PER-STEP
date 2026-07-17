--!strict
---/// Content \\\---

-- Purpose: central client event bus to decouple UI controllers and views.
-- Use when:
-- - Communicating UI states (like layout changes, inventory/shop toggles) across controllers.
-- Avoid when:
-- - Dealing with low-level local frame-by-frame GUI layout adjustments.
-- Public API:
-- - UIEventBus.Subscribe(eventName: string, callback: (...any) -> ()) -> EventConnection
-- - UIEventBus.Publish(eventName: string, ...any)
-- Related:
-- - src/client/controllers/GuiController.luau

--// Types \\--
export type EventConnection = {
	Disconnect: () -> ()
}

type Callback = (...any) -> ()

--// Variables \\--
local Listeners: { [string]: { Callback } } = {}

--// Service \\--
local UIEventBus = {}

-- Subscribe to a UI event. Returns an EventConnection to clean up later.
function UIEventBus.Subscribe(eventName: string, callback: Callback): EventConnection
	if not Listeners[eventName] then
		Listeners[eventName] = {}
	end
	table.insert(Listeners[eventName], callback)

	return {
		Disconnect = function()
			local list = Listeners[eventName]
			if list then
				local idx = table.find(list, callback)
				if idx then
					table.remove(list, idx)
				end
			end
		end
	}
end

-- Publish a UI event. Invokes all subscribers asynchronously in task.spawn.
function UIEventBus.Publish(eventName: string, ...: any)
	local list = Listeners[eventName]
	if not list then return end

	local args = { ... }
	for _, callback in ipairs(list) do
		task.spawn(function()
			callback(unpack(args))
		end)
	end
end

return table.freeze(UIEventBus)
