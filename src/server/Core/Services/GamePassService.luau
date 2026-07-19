--!strict
-- GamePassService.luau
-- Reconciles saved Game Pass entitlements with current Marketplace ownership.

--// Raw Requirings \\--

local MarketplaceService = game:GetService("MarketplaceService")

--// Requirings \\--

local GamePassConfig = require(script.Parent.Parent.Config.GamePassConfig)
local EventBus = require(script.Parent.Parent.Events.EventBus)
local ServiceRegistry = require(script.Parent.Parent.Registry.ServiceRegistry)
local Sessions = require(script.Parent.Parent.Registry.RuntimeRegistry.Sessions)
local Logger = require(script.Parent.Parent.Utilities.Logger)

--// Types \\--

type PassKey = "Vip" | "PremiumZone"
type PassConfig = {
	AssetId: number?,
	Price: number,
	ProfileKey: string,
}
type QueryBatch = {
	Changed: boolean,
	Pending: number,
}
type QueryRequest = {
	PassKey: PassKey,
	AssetId: number,
	Generation: number,
}

--// Variables \\--

local MaximumSafeInteger = 9007199254740991
local PassKeys: { PassKey } = table.freeze({ "Vip", "PremiumZone" })

--// Helpers \\--

local function ConfigFor(PassKey: string): PassConfig?
	if PassKey ~= "Vip" and PassKey ~= "PremiumZone" then
		return nil
	end
	return GamePassConfig[PassKey]
end

local function IsValidAssetId(AssetId: any): boolean
	return type(AssetId) == "number"
		and AssetId == AssetId
		and AssetId > 0
		and AssetId < math.huge
		and AssetId % 1 == 0
		and AssetId <= MaximumSafeInteger
end

local function ValidateConfig()
	local Count = 0
	local AssetIds: { [number]: PassKey } = {}
	for Key, Config in GamePassConfig do
		Count += 1
		if Key ~= "Vip" and Key ~= "PremiumZone" then
			error("GamePassService: unsupported PassKey " .. tostring(Key), 2)
		end
		if type(Config) ~= "table" then
			error("GamePassService: invalid config for " .. Key, 2)
		end
		local ExpectedPrice = if Key == "Vip" then 199 else 99
		local ExpectedProfileKey = if Key == "Vip" then "HasVip" else "HasPremiumZonePass"
		if Config.Price ~= ExpectedPrice or Config.ProfileKey ~= ExpectedProfileKey then
			error("GamePassService: invalid metadata for " .. Key, 2)
		end
		if not IsValidAssetId(Config.AssetId) then
			error("GamePassService: missing or invalid AssetId for " .. Key, 2)
		end
		local AssetId = Config.AssetId :: number
		if AssetIds[AssetId] then
			error("GamePassService: duplicate AssetId for " .. AssetIds[AssetId] .. " and " .. Key, 2)
		end
		AssetIds[AssetId] = Key
	end
	if Count ~= #PassKeys or not GamePassConfig.Vip or not GamePassConfig.PremiumZone then
		error("GamePassService: config must contain exactly Vip and PremiumZone", 2)
	end
end

local function GetOwned(Session: Sessions.Session, PassKey: PassKey): boolean
	return if PassKey == "Vip" then Session.HasVip else Session.HasPremiumZonePass
end

local function SetOwned(Session: Sessions.Session, PassKey: PassKey, Owned: boolean)
	if PassKey == "Vip" then
		Session.HasVip = Owned
	else
		Session.HasPremiumZonePass = Owned
	end
end

local function RefreshPresentation(Player: Player, PassKey: PassKey)
	if PassKey ~= "Vip" then
		return
	end
	ServiceRegistry.Get("GrowthService"):UpdateMultiplierAttribute(Player)
	ServiceRegistry.Get("CharacterScaleService"):UpdateVipTag(Player)
end

local function ApplyQuery(
	Player: Player,
	ExpectedSession: Sessions.Session,
	PassKey: PassKey,
	AssetId: number,
	Generation: number,
	Succeeded: boolean,
	Owned: any
): boolean
	if not Succeeded then
		Logger.Warn("GamePass", "Ownership query failed for %s (%s): %s", Player.Name, PassKey, tostring(Owned))
		return false
	end
	if type(Owned) ~= "boolean" then
		Logger.Warn("GamePass", "Ownership query returned invalid result for %s (%s)", Player.Name, PassKey)
		return false
	end
	local SaveService = ServiceRegistry.Get("SaveService")
	local CurrentConfig = ConfigFor(PassKey)
	local Session = Sessions.Get(Player)
	if
		Session ~= ExpectedSession
		or not SaveService:IsProfileWritable(Player)
		or not CurrentConfig
		or CurrentConfig.AssetId ~= AssetId
		or Session.GamePassQueryGenerations[PassKey] ~= Generation
	then
		return false
	end

	local Changed = false
	if
		not Sessions.Mutate(Player, function(CurrentSession)
			if
				CurrentSession ~= ExpectedSession
				or CurrentSession.GamePassQueryGenerations[PassKey] ~= Generation
				or GetOwned(CurrentSession, PassKey) == Owned
			then
				return
			end
			SetOwned(CurrentSession, PassKey, Owned)
			Changed = true
		end)
	then
		return false
	end
	if Changed then
		RefreshPresentation(Player, PassKey)
	end
	return Changed
end

local function BeginQueries(Player: Player, PassKeysToQuery: { PassKey })
	local Session = Sessions.Get(Player)
	local SaveService = ServiceRegistry.Get("SaveService")
	if not Session or not SaveService:IsProfileWritable(Player) then
		return
	end

	local Queries: { QueryRequest } = {}
	for _, PassKey in PassKeysToQuery do
		local Config = ConfigFor(PassKey)
		local AssetId = Config and Config.AssetId
		if not Config or not IsValidAssetId(AssetId) then
			continue
		end
		local Generation = Session.GamePassQueryGenerations[PassKey] + 1
		local GenerationApplied = false
		if
			not Sessions.Mutate(Player, function(CurrentSession)
				if CurrentSession == Session then
					CurrentSession.GamePassQueryGenerations[PassKey] = Generation
					GenerationApplied = true
				end
			end) or not GenerationApplied
		then
			continue
		end
		table.insert(Queries, {
			PassKey = PassKey,
			AssetId = AssetId :: number,
			Generation = Generation,
		})
	end

	local Batch: QueryBatch = { Changed = false, Pending = #Queries }
	for _, Query in Queries do
		task.spawn(function()
			local Succeeded, Owned =
				pcall(MarketplaceService.UserOwnsGamePassAsync, MarketplaceService, Player.UserId, Query.AssetId)
			if ApplyQuery(Player, Session, Query.PassKey, Query.AssetId, Query.Generation, Succeeded, Owned) then
				Batch.Changed = true
			end
			Batch.Pending -= 1
			if
				Batch.Pending == 0
				and Batch.Changed
				and Sessions.Get(Player) == Session
				and SaveService:IsProfileWritable(Player)
			then
				SaveService:SaveProfile(Player)
			end
		end)
	end
end

local function OnSessionCreated(Player: Player)
	Player:SetAttribute("VipGamePassAssetId", GamePassConfig.Vip.AssetId)
	BeginQueries(Player, PassKeys)
end

local function OnPromptFinished(Player: Player, AssetId: number, _WasPurchased: boolean)
	for _, PassKey in PassKeys do
		if GamePassConfig[PassKey].AssetId == AssetId then
			BeginQueries(Player, { PassKey })
			return
		end
	end
end

--// Service \\--

local GamePassService = {}

function GamePassService:Init()
	ValidateConfig()
	EventBus.Subscribe("PlayerSessionCreated", OnSessionCreated)
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(OnPromptFinished)
end

function GamePassService:Start() end

function GamePassService:IsOwned(Player: Player, PassKey: string): boolean
	local Config = ConfigFor(PassKey)
	local Session = Sessions.Get(Player)
	if not Config or not Session then
		return false
	end
	return GetOwned(Session, PassKey :: PassKey)
end

function GamePassService:Prompt(Player: Player, PassKey: string): boolean
	local Config = ConfigFor(PassKey)
	local Session = Sessions.Get(Player)
	local AssetId = Config and Config.AssetId
	if
		not Session
		or not Config
		or not IsValidAssetId(AssetId)
		or not ServiceRegistry.Get("SaveService"):IsProfileWritable(Player)
	then
		return false
	end
	MarketplaceService:PromptGamePassPurchase(Player, AssetId :: number)
	return true
end

return GamePassService
