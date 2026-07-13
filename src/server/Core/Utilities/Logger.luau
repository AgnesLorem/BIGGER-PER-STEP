--!strict
--// Service \\--

local Logger = {}

function Logger.Info(Category: string, Message: string, ...: any)
	if select("#", ...) > 0 then
		print(`[{Category}] {string.format(Message, ...)}`)
	else
		print(`[{Category}] {Message}`)
	end
end

function Logger.Warn(Category: string, Message: string, ...: any)
	if select("#", ...) > 0 then
		warn(`[{Category}] {string.format(Message, ...)}`)
	else
		warn(`[{Category}] {Message}`)
	end
end

function Logger.Error(Category: string, Message: string, ...: any)
	if select("#", ...) > 0 then
		error(`[{Category}] {string.format(Message, ...)}`)
	else
		error(`[{Category}] {Message}`)
	end
end

return table.freeze(Logger)
