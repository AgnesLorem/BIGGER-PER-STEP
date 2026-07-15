--// Requirings \\--
local CharacterScaleController = require(script.Parent.controllers.CharacterScaleController)
local GuiController = require(script.Parent.controllers.GuiController)

--// Initialization \\--
CharacterScaleController.Init()
GuiController.Init()

CharacterScaleController.Start()
GuiController.Start()
