--// Requirings \\--
local CharacterScaleController = require(script.Parent.controllers.CharacterScaleController)
local GuiController = require(script.Parent.controllers.GuiController)
local ObjectiveController = require(script.Parent.controllers.ObjectiveController)
local EquipmentController = require(script.Parent.controllers.EquipmentController)

--// Initialization \\--
CharacterScaleController.Init()
GuiController.Init()
ObjectiveController.Init()
EquipmentController.Init()

CharacterScaleController.Start()
GuiController.Start()
ObjectiveController.Start()
EquipmentController.Start()
