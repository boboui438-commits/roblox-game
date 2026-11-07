--!strict
--[[
	Bootstrap  |  ServerScriptService.Bootstrap (Script)
	------------------------------------------------------------------
	POINT D'ENTRÉE UNIQUE DU SERVEUR.

	Ordre de démarrage (important) :
	  1. Net.init() ................ crée les RemoteEvents/Functions
	  2. WorldFactory.buildAll() ... génère la map (lobby + 6 mondes)
	  3. Systèmes .................. enregistrent leurs remotes et signaux
	  4. DataManager.start() ....... EN DERNIER : charge les joueurs
	                                 (comme ça tous les systèmes écoutent
	                                 déjà l'événement "Loaded")
	  5. BindToClose ............... sauvegarde tout à la fermeture
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local Net = require(Modules:WaitForChild("Net"))

local Systems = ServerScriptService:WaitForChild("Systems")

print(string.format("===== %s v%d — démarrage =====", GameConfig.GameName, GameConfig.Version))

-- 1. Réseau
Net.init()

-- 2. Map
local WorldFactory = require(Systems:WaitForChild("WorldFactory"))
WorldFactory.buildAll()

-- 3. Systèmes (l'ordre n'a pas d'importance pour les signaux, mais on le
--    garde logique : données → gameplay → social → monétisation)
local systemOrder = {
	"CollectSystem",
	"CharacterSystem",
	"PetSystem",
	"ShopSystem",
	"RebirthSystem",
	"AchievementSystem",
	"DailyRewardSystem",
	"EventManager",
	"LeaderboardManager",
	"SettingsSystem",
	"MonetizationSystem",
	"WorldManager",
}

local loadedSystems = {}
for _, systemName in ipairs(systemOrder) do
	local module = Systems:FindFirstChild(systemName)
	if module then
		local ok, system = pcall(require, module)
		if ok and system and type(system.start) == "function" then
			local started, err = pcall(system.start)
			if started then
				loadedSystems[systemName] = system
			else
				warn(string.format("[Bootstrap] %s.start() a échoué : %s", systemName, tostring(err)))
			end
		else
			warn(string.format("[Bootstrap] impossible de charger %s : %s", systemName, tostring(system)))
		end
	end
end

-- 4. Données (en dernier)
local DataManager = require(Systems:WaitForChild("DataManager"))
DataManager.start()

-- 5. Fermeture propre du serveur
game:BindToClose(function()
	print("[Bootstrap] Fermeture du serveur : sauvegarde de tous les joueurs…")
	pcall(function()
		DataManager.shutdown()
	end)
end)

-- Réglages globaux de confort
Players.CharacterAutoLoads = true
Players.RespawnTime = 3

print(string.format("===== %s prêt (%d systèmes actifs) =====", GameConfig.GameName, (function()
	local count = 0
	for _ in pairs(loadedSystems) do
		count = count + 1
	end
	return count
end)()))
