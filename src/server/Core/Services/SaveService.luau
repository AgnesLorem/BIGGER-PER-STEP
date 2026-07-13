--// Requirings \\--

local Logger = require(script.Parent.Parent.Utilities.Logger)

--// Service \\--

local SaveService = {}

function SaveService:Init() end

function SaveService:Start() end

function SaveService:LoadProfile(_Player: Player): { Bigger: number, Destruction: number, Rebirth: number }
	return { Bigger = 1, Destruction = 0, Rebirth = 0 }
end

function SaveService:SaveProfile(Player: Player)
	Logger.Info("Save", "SaveProfile called for %s (stub)", Player.Name)
end

return SaveService
