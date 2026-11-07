--!strict
--[[
	Net  |  ReplicatedStorage.Modules.Net
	------------------------------------------------------------------
	Registre central des RemoteEvents / RemoteFunctions.
	Le SERVEUR crée tout (Net.init()), le CLIENT attend (Net.get).

	Utilisation :
		Serveur : local net = require(ReplicatedStorage.Modules.Net); net.init()
		          net.event("CollectRequest").OnServerEvent:Connect(...)
		Client  : local net = require(ReplicatedStorage.Modules.Net)
		          net.event("CollectRequest"):FireServer(part)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Net = {}

Net.FOLDER_NAME = "Remotes"

--- Client → Serveur
Net.RemoteEvents = {
	"CollectRequest",       -- (collectible: Instance)
	"VacuumRequest",        -- ()
	"BuyUpgrade",           -- (upgradeId: string)
	"OpenEgg",              -- (eggId: string, amount: number)
	"EquipPet",             -- (uid: string)
	"UnequipPet",           -- (uid: string)
	"EquipBestPets",        -- ()
	"FusePet",              -- (petId: string)
	"RebirthRequest",       -- ()
	"TravelWorld",          -- (worldIndex: number)
	"ClaimDaily",           -- ()
	"ClaimAchievement",     -- (achievementId: string)
	"SelectTitle",          -- (titleId: string)
	"SetSetting",           -- (key: string, value: any)
	"ClientReady",          -- ()
	"PlayEmote",            -- (emote: string)
	"ComparePower",         -- (userId: number) comparaison de puissance

	-- Serveur → Client
	"ProfileUpdated",       -- (profile: table)
	"Notify",               -- (text, colorHex?, icon?)
	"EffectBurst",          -- (position: Vector3, colorHex: string, amount: number)
	"EventUpdate",          -- (eventId: string?, endsAt: number?, message: string?)
	"EggResult",            -- (rarity, petId, name, mult, eggId, isNew)
	"LeaderboardData",      -- (global: table, server: table)
	"PlaySound",            -- (soundKey: string, volume: number?)
	"CameraShake",          -- (intensity: number)
	"ScreenFlash",          -- (colorHex: string, duration: number?)
	"SetWorld",             -- (worldIndex: number)
	"Transformation",       -- (tier: number)
	"DailyAvailable",       -- (available: boolean)
	"BoostUpdate",          -- (mult: number, endsAt: number)
	"RebirthSuccess",       -- (rebirths: number, coins: number)
}

--- Client → Serveur avec réponse
Net.RemoteFunctions = {
	"GetProfile",           -- () -> profile
	"GetLeaderboards",      -- () -> global, server
	"GetServerInfo",        -- () -> { players = n, eventId = ..., serverTime = ... }
}

local remotesFolder: Folder? = nil

local function getFolder(): Folder
	if remotesFolder and remotesFolder.Parent then
		return remotesFolder
	end
	if RunService:IsServer() then
		local existing = ReplicatedStorage:FindFirstChild(Net.FOLDER_NAME)
		if not existing then
			existing = Instance.new("Folder")
			existing.Name = Net.FOLDER_NAME
			existing.Parent = ReplicatedStorage
		end
		remotesFolder = existing :: Folder
		return remotesFolder
	end
	local existing = ReplicatedStorage:WaitForChild(Net.FOLDER_NAME, 30)
	assert(existing, "Dossier Remotes introuvable (le serveur doit appeler Net.init())")
	remotesFolder = existing :: Folder
	return remotesFolder
end

local function getSubFolder(name: string): Folder
	local folder = getFolder()
	local existing = folder:FindFirstChild(name)
	if existing then
		return existing :: Folder
	end
	local sub = Instance.new("Folder")
	sub.Name = name
	sub.Parent = folder
	return sub
end

--- Appelé UNIQUEMENT par le serveur, au démarrage.
function Net.init()
	local events = getSubFolder("Events")
	for _, name in ipairs(Net.RemoteEvents) do
		if not events:FindFirstChild(name) then
			local remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = events
		end
	end
	local functions = getSubFolder("Functions")
	for _, name in ipairs(Net.RemoteFunctions) do
		if not functions:FindFirstChild(name) then
			local remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = functions
		end
	end
	return true
end

--- Récupère un RemoteEvent (attend côté client)
function Net.event(name: string): RemoteEvent
	local events = getSubFolder("Events")
	local remote = events:FindFirstChild(name)
	if not remote then
		if RunService:IsServer() then
			remote = Instance.new("RemoteEvent")
			remote.Name = name
			remote.Parent = events
		else
			remote = events:WaitForChild(name, 30)
		end
	end
	assert(remote, "RemoteEvent manquant : " .. name)
	return remote :: RemoteEvent
end

--- Récupère un RemoteFunction (attend côté client)
function Net.func(name: string): RemoteFunction
	local functions = getSubFolder("Functions")
	local remote = functions:FindFirstChild(name)
	if not remote then
		if RunService:IsServer() then
			remote = Instance.new("RemoteFunction")
			remote.Name = name
			remote.Parent = functions
		else
			remote = functions:WaitForChild(name, 30)
		end
	end
	assert(remote, "RemoteFunction manquante : " .. name)
	return remote :: RemoteFunction
end

--- Raccourci serveur : envoie un event à un joueur
function Net.fire(player: Player, name: string, ...)
	Net.event(name):FireClient(player, ...)
end

--- Raccourci serveur : envoie à tous les joueurs
function Net.fireAll(name: string, ...)
	Net.event(name):FireAllClients(...)
end

return Net
