--// Requirings \\--
local CharacterScaleController = require(script.Parent.controllers.CharacterScaleController)
local GuiController = require(script.Parent.controllers.GuiController)
local ObjectiveController = require(script.Parent.controllers.ObjectiveController)

--// Initialization \\--
CharacterScaleController.Init()
GuiController.Init()
ObjectiveController.Init()

CharacterScaleController.Start()
GuiController.Start()
ObjectiveController.Start()
