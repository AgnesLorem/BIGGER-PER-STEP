--!strict
--// Variables \\--

local Services: { [string]: any } = {}

--// Service \\--

local ServiceRegistry = {}

function ServiceRegistry.Register(Name: string, Service: any)
	if Services[Name] then
		error(`[ServiceRegistry] Service already registered: {Name}`)
	end
	Services[Name] = Service
end

function ServiceRegistry.Get(Name: string): any
	local Service = Services[Name]
	if not Service then
		error(`[ServiceRegistry] Service not found: {Name}`)
	end
	return Service
end

function ServiceRegistry.GetAll(): { [string]: any }
	return table.freeze(table.clone(Services))
end

return table.freeze(ServiceRegistry)
