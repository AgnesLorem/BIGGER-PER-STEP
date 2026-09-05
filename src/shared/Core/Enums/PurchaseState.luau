--!strict

--// Variables \\--

local PurchaseState = {
	None = 0,
	Dispatched = 1,
	Completed = 2,
}

return table.freeze(PurchaseState)
