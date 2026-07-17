--// Requirings \\--
local CharacterScaleController = require(script.Parent.controllers.CharacterScaleController)
local GuiController = require(script.Parent.controllers.GuiController)
local ObjectiveController = require(script.Parent.controllers.ObjectiveController)
local ResponsiveController = require(script.Parent.controllers.ResponsiveController)

--// Initialization \\--
CharacterScaleController.Init()
ResponsiveController.Init()
GuiController.Init()
ObjectiveController.Init()

CharacterScaleController.Start()
ResponsiveController.Start()
GuiController.Start()
ObjectiveController.Start()
