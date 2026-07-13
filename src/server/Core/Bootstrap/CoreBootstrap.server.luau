--!strict
--[[
	CoreBootstrap.server.luau
	Server boot entry point.
	Boot -> Register Services -> Init Services -> Start Services -> Accept Players.
]]

--// Raw Requirings \\--
local Players = game:GetService("Players")

--// Requirings \\--
local Logger = require(script.Parent.Parent.Utilities.Logger)
local ServiceRegistry = require(script.Parent.Parent.Registry.ServiceRegistry)
local Scheduler = require(script.Parent.Parent.Scheduler.Scheduler)
local EventBus = require(script.Parent.Parent.Events.EventBus)

local SessionService = require(script.Parent.Parent.Services.SessionService)
local SaveService = require(script.Parent.Parent.Services.SaveService)
local GrowthService = require(script.Parent.Parent.Services.GrowthService)
local CharacterScaleService = require(script.Parent.Parent.Services.CharacterScaleService)

local GameBootstrap = require(script.Parent.Parent.Parent.Game.GameBootstrap)

--// Variables \\--
local BootOrder = {
	{ Name = "SessionService", Service = SessionService },
	{ Name = "SaveService", Service = SaveService },
	{ Name = "GrowthService", Service = GrowthService },
	{ Name = "CharacterScaleService", Service = CharacterScaleService },
}

--// Helpers \\--
local function RegisterServices()
	for _, Entry in BootOrder do
		ServiceRegistry.Register(Entry.Name, Entry.Service)
	end
	Logger.Info("Runtime", "All core services registered")
end

local function InitServices()
	for _, Entry in BootOrder do
		if Entry.Service.Init then
			Entry.Service:Init()
		end
	end
	Logger.Info("Runtime", "All core services initialized")
end

local function StartServices()
	for _, Entry in BootOrder do
		if Entry.Service.Start then
			Entry.Service:Start()
		end
	end
	Logger.Info("Runtime", "All core services started")
end

local function InitGame()
	GameBootstrap.Init()
	Logger.Info("Runtime", "Game layer initialized")
end

local function StartGame()
	GameBootstrap.Start()
	Scheduler.Start()
	Logger.Info("Runtime", "Game layer started, scheduler running")
end

local function AcceptPlayers()
	Logger.Info("Runtime", "Accepting players, server is ready")
end

--// Boot Sequence \\--
Logger.Info("Runtime", "Server boot started")

RegisterServices()
InitServices()
InitGame()
StartServices()
StartGame()
AcceptPlayers()

Logger.Info("Runtime", "Server boot complete")
