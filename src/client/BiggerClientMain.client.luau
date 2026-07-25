--// Requirings \\--
local CharacterScaleController = require(script.Parent.controllers.CharacterScaleController)
local GuiController = require(script.Parent.controllers.GuiController)
local ObjectiveController = require(script.Parent.controllers.ObjectiveController)
local RebirthController = require(script.Parent.controllers.RebirthController)
local ResponsiveController = require(script.Parent.controllers.ResponsiveController)

--// Initialization \\--
CharacterScaleController.Init()
ResponsiveController.Init()
GuiController.Init()
ObjectiveController.Init()
RebirthController.Init()

CharacterScaleController.Start()
ResponsiveController.Start()
GuiController.Start()
ObjectiveController.Start()
RebirthController.Start()
