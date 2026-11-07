--!strict
--[[
	DataManager  |  ServerScriptService.Systems.DataManager
	------------------------------------------------------------------
	Gère TOUT ce qui touche à la sauvegarde d'un joueur.

	Fonctionnalités :
	  • Chargement avec 5 tentatives + backoff exponentiel
	  • Verrou de session (évite la duplication de données entre serveurs)
	  • Sauvegarde automatique toutes les X secondes
	  • Sauvegarde à la déconnexion + BindToClose
	  • Copie de secours (clé _backup) si les données sont corrompues
	  • Migration / validation des profils (ProfileTemplate.migrate)
	  • Plus jamais d'écrasement de données si le chargement échoue
	    (__saveBlocked) : on retente le chargement en arrière-plan.

	API publique (utilisée par tous les autres systèmes) :
	  DataManager.getProfile(player)        -> profile | nil
	  DataManager.waitForProfile(player)    -> profile
	  DataManager.addPower(player, n)       -> n appliqué
	  DataManager.addCoins(player, n)       -> n appliqué
	  DataManager.spendCoins(player, n)     -> bool
	  DataManager.addStat(player, stat, n)
	  DataManager.notify(player)            -> envoie ProfileUpdated au client
	  DataManager.save(player, releaseLock) -> bool
	  DataManager.broadcastProfile(player)
	  DataManager.isLoaded(player)
]]

local Players = game:GetService("Players")
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local ProfileTemplate = require(Modules:WaitForChild("ProfileTemplate"))
local Net = require(Modules:WaitForChild("Net"))
local Signal = require(Modules:WaitForChild("Signal"))
local Formulas = require(Modules:WaitForChild("Formulas"))

local DataManager = {}

local LOAD_ATTEMPTS = 5
local SAVE_ATTEMPTS = 3
local LOCK_TIMEOUT = 90 -- secondes avant de considérer un verrou comme périmé
local USE_DATASTORE = true -- passer à false pour tester sans DataStore (aucune sauvegarde)

DataManager.Events = {
	Loaded = Signal.new(),    -- (player, profile)
	Unloaded = Signal.new(),  -- (player, profile)
	Changed = Signal.new(),   -- (player, profile)
	PowerGained = Signal.new(), -- (player, amount, profile)
	CoinsGained = Signal.new(), -- (player, amount, profile)
	Rebirth = Signal.new(),   -- (player, profile)
}

local profiles: { [Player]: any } = {}
local saveBlocked: { [Player]: boolean } = {}
local notifyCooldown: { [Player]: number } = {}
local stores: { [string]: GlobalDataStore } = {}

local function getStore(name: string): GlobalDataStore
	local store = stores[name]
	if not store then
		store = DataStoreService:GetDataStore(name)
		stores[name] = store
	end
	return store
end

local function getKey(player: Player): string
	return GameConfig.DataStoreKeyPrefix .. tostring(player.UserId)
end

local function retry(attempts: number, waitTime: number, fn: (number) -> any): (boolean, any)
	local lastError = nil
	for attempt = 1, attempts do
		local ok, result = pcall(fn, attempt)
		if ok then
			return true, result
		end
		lastError = result
		warn(string.format("[DataManager] tentative %d/%d échouée : %s", attempt, attempts, tostring(result)))
		if attempt < attempts then
			task.wait(waitTime * attempt)
		end
	end
	return false, lastError
end

-- ============================================================
-- LEADERSTATS (affichage tableau des scores Roblox natif)
-- ============================================================
local function setupLeaderstats(player: Player, profile)
	local existing = player:FindFirstChild("leaderstats")
	if existing then
		existing:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "leaderstats"

	local function makeStat(name: string, value: number, order: number)
		local stat = Instance.new("IntValue")
		stat.Name = name
		stat.Value = math.clamp(math.floor(value), -2147483648, 2147483647)
		stat:SetAttribute("Order", order)
		stat.Parent = folder
		return stat
	end

	makeStat("Power", profile.power, 1)
	makeStat("Rebirths", profile.rebirths, 2)
	makeStat("Coins", profile.coins, 3)
	folder.Parent = player
end

function DataManager.syncLeaderstats(player: Player, profile)
	local folder = player:FindFirstChild("leaderstats")
	if not folder then
		return
	end
	local powerValue = folder:FindFirstChild("Power")
	local rebirthValue = folder:FindFirstChild("Rebirths")
	local coinValue = folder:FindFirstChild("Coins")
	if powerValue then
		powerValue.Value = math.clamp(math.floor(profile.power), -2147483648, 2147483647)
	end
	if rebirthValue then
		rebirthValue.Value = math.clamp(math.floor(profile.rebirths), -2147483648, 2147483647)
	end
	if coinValue then
		coinValue.Value = math.clamp(math.floor(profile.coins), -2147483648, 2147483647)
	end
end

-- ============================================================
-- CHARGEMENT
-- ============================================================
local function acquireLockAndLoad(player: Player): (any, boolean)
	local store = getStore(GameConfig.DataStoreName)
	local key = getKey(player)
	local lockOk = false
	local data = nil

	local success, result = retry(LOAD_ATTEMPTS, 1.2, function()
		return store:UpdateAsync(key, function(oldEntry)
			local now = os.time()
			if type(oldEntry) == "table" and type(oldEntry.lock) == "table" then
				local otherJob = oldEntry.lock.jobId
				local lockedAt = tonumber(oldEntry.lock.at) or 0
				local isStale = (now - lockedAt) > LOCK_TIMEOUT
				if otherJob and otherJob ~= game.JobId and not isStale then
					return nil -- verrou détenu par un autre serveur : on abandonne
				end
			end

			local entry = {}
			if type(oldEntry) == "table" then
				entry = oldEntry
			end
			if type(entry.data) == "table" then
				data = entry.data
			end
			entry.lock = { jobId = game.JobId, at = now }
			entry.version = GameConfig.DataVersion
			-- la copie de secours est rafraîchie aussi
			return entry
		end)
	end)

	lockOk = success and result ~= nil
	return data, lockOk
end

-- Récupère la copie de secours si les données principales sont illisibles
local function readBackup(player: Player)
	local backupStore = getStore(GameConfig.DataStoreName .. "_Backup")
	local ok, data = pcall(function()
		return backupStore:GetAsync(getKey(player))
	end)
	if ok and type(data) == "table" then
		return data
	end
	return nil
end

local function finishLoad(player: Player, profile, isFresh: boolean)
	profiles[player] = profile
	saveBlocked[player] = false
	-- On garde l'horodatage de la session précédente : il sert à calculer
	-- les gains hors-ligne (DailyRewardSystem). La clé "__" n'est jamais
	-- sauvegardée (voir serialize()).
	profile.__previousLastSeen = profile.lastSeen or os.time()
	profile.lastSeen = os.time()

	setupLeaderstats(player, profile)
	DataManager.syncLeaderstats(player, profile)

	DataManager.Events.Loaded:Fire(player, profile)

	-- Si le joueur a déjà chargé son UI, on lui envoie l'état immédiatement
	Net.event("ProfileUpdated"):FireClient(player, ProfileTemplate.toPublic(profile))
	if profile.power > 0 or not isFresh then
		Net.event("Notify"):FireClient(player, "Bienvenue ! Tes données sont chargées. 💾", "8affc1", "💾")
	end
end

function DataManager.load(player: Player)
	local data, lockOk = acquireLockAndLoad(player)

	if data == nil and not lockOk then
		-- Échec total du DataStore : on laisse jouer mais SANS sauvegarder
		-- pour ne jamais écraser une vraie sauvegarde.
		warn("[DataManager] chargement impossible pour " .. player.Name .. " → mode invité (sauvegarde bloquée)")
		saveBlocked[player] = true
		local profile = ProfileTemplate.new()
		profile.__saveBlocked = true
		profiles[player] = profile
		profile.__previousLastSeen = profile.lastSeen
		profile.lastSeen = os.time()
		setupLeaderstats(player, profile)
		DataManager.Events.Loaded:Fire(player, profile)
		Net.event("Notify"):FireClient(player, "⚠️ Sauvegarde indisponible, rechargement en cours…", "ff9f43", "⚠️")
		-- on retente en arrière-plan
		task.spawn(function()
			for attempt = 1, 10 do
				task.wait(15)
				if not player.Parent then
					return
				end
				local retryData, retryLock = acquireLockAndLoad(player)
				if retryData ~= nil or retryLock then
					local migrated = ProfileTemplate.migrate(retryData)
					profiles[player] = migrated
					saveBlocked[player] = false
					DataManager.syncLeaderstats(player, migrated)
					DataManager.Events.Loaded:Fire(player, migrated)
					DataManager.notify(player)
					Net.event("Notify"):FireClient(player, "✅ Sauvegarde rétablie !", "8affc1", "✅")
					return
				end
			end
		end)
		return profile
	end

	if data == nil then
		-- aucune donnée existante (première visite) mais le verrou a été pris
		local backup = readBackup(player)
		if backup then
			warn("[DataManager] données principales absentes, restauration depuis la copie de secours : " .. player.Name)
			data = backup
		end
	end

	local profile = ProfileTemplate.migrate(data)
	finishLoad(player, profile, data == nil)
	return profile
end

-- ============================================================
-- SAUVEGARDE
-- ============================================================
local function serialize(profile)
	-- On ne sauvegarde jamais les champs internes
	local payload = {}
	for key, value in pairs(profile) do
		if string.sub(key, 1, 2) ~= "__" and key ~= "gamePasses" then
			payload[key] = value
		end
	end
	payload.lastSeen = os.time()
	payload.version = GameConfig.DataVersion
	return payload
end

function DataManager.save(player: Player, releaseLock: boolean?): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	if saveBlocked[player] or profile.__saveBlocked then
		return false
	end
	if not USE_DATASTORE then
		return true
	end

	local payload = serialize(profile)
	local key = getKey(player)
	local store = getStore(GameConfig.DataStoreName)

	local ok = retry(SAVE_ATTEMPTS, 1.5, function()
		return store:UpdateAsync(key, function(oldEntry)
			local entry = oldEntry
			if type(entry) ~= "table" then
				entry = {}
			end
			-- Ne jamais écraser les données d'un autre serveur actif
			if type(entry.lock) == "table" then
				local otherJob = entry.lock.jobId
				local lockedAt = tonumber(entry.lock.at) or 0
				if otherJob and otherJob ~= game.JobId and (os.time() - lockedAt) < LOCK_TIMEOUT then
					warn("[DataManager] sauvegarde annulée : verrou détenu par un autre serveur (" .. tostring(otherJob) .. ")")
					return nil
				end
			end
			entry.data = payload
			entry.version = GameConfig.DataVersion
			if releaseLock then
				entry.lock = nil
			else
				entry.lock = { jobId = game.JobId, at = os.time() }
			end
			return entry
		end)
	end)

	if not ok then
		warn("[DataManager] sauvegarde échouée pour " .. player.Name)
		return false
	end

	-- copie de secours (best effort, jamais bloquante)
	task.spawn(function()
		local backupStore = getStore(GameConfig.DataStoreName .. "_Backup")
		pcall(function()
			backupStore:SetAsync(key, payload)
		end)
	end)
	return true
end

-- ============================================================
-- NOTIFICATION CLIENT (throttlée)
-- ============================================================
function DataManager.notify(player: Player, force: boolean?)
	local profile = profiles[player]
	if not profile or not player.Parent then
		return
	end
	local now = os.clock()
	local last = notifyCooldown[player] or 0
	if not force and now - last < 0.1 then
		-- trop rapide : on planifie une notification différée
		if not profile.__notifyPending then
			profile.__notifyPending = true
			task.delay(0.12, function()
				profile.__notifyPending = false
				if profiles[player] == profile then
					DataManager.notify(player, true)
				end
			end)
		end
		return
	end
	notifyCooldown[player] = now

	DataManager.syncLeaderstats(player, profile)
	Net.event("ProfileUpdated"):FireClient(player, ProfileTemplate.toPublic(profile))
	DataManager.Events.Changed:Fire(player, profile)
end

function DataManager.broadcastProfile(player: Player)
	DataManager.notify(player, true)
end

-- ============================================================
-- HELPERS DE PROGRESSION
-- ============================================================
function DataManager.getProfile(player: Player)
	return profiles[player]
end

function DataManager.isLoaded(player: Player): boolean
	return profiles[player] ~= nil
end

function DataManager.waitForProfile(player: Player, timeout: number?)
	local startTime = os.clock()
	local limit = timeout or 30
	while os.clock() - startTime < limit do
		local profile = profiles[player]
		if profile then
			return profile
		end
		if not player.Parent then
			return nil
		end
		task.wait(0.1)
	end
	return nil
end

function DataManager.getProfiles()
	return profiles
end

--- Ajoute de la puissance. Renvoie le montant réellement appliqué.
function DataManager.addPower(player: Player, amount: number, note: string?): number
	local profile = profiles[player]
	if not profile then
		return 0
	end
	if not (amount == amount) or amount == math.huge or amount <= 0 then
		return 0
	end
	amount = math.floor(amount)
	profile.power = profile.power + amount
	profile.totalPower = profile.totalPower + amount
	if profile.power > profile.bestPower then
		profile.bestPower = profile.power
	end
	DataManager.Events.PowerGained:Fire(player, amount, profile)
	return amount
end

--- Ajoute des pièces.
function DataManager.addCoins(player: Player, amount: number): number
	local profile = profiles[player]
	if not profile then
		return 0
	end
	if not (amount == amount) or amount <= 0 then
		return 0
	end
	amount = math.floor(amount)
	profile.coins = profile.coins + amount
	DataManager.Events.CoinsGained:Fire(player, amount, profile)
	return amount
end

--- Dépense des pièces si possible (atomique côté serveur).
function DataManager.spendCoins(player: Player, amount: number): boolean
	local profile = profiles[player]
	if not profile then
		return false
	end
	if amount <= 0 or profile.coins < amount then
		return false
	end
	profile.coins = profile.coins - amount
	DataManager.notify(player)
	return true
end

--- Incrémente une statistique de succès.
function DataManager.addStat(player: Player, statName: string, amount: number?)
	local profile = profiles[player]
	if not profile then
		return
	end
	if profile.stats[statName] == nil then
		return
	end
	profile.stats[statName] = profile.stats[statName] + (amount or 1)
end

--- Fixe une statistique (ex: maxWorld, streak)
function DataManager.setStat(player: Player, statName: string, value: number)
	local profile = profiles[player]
	if not profile then
		return
	end
	if profile.stats[statName] == nil then
		return
	end
	profile.stats[statName] = math.max(profile.stats[statName], value)
end

function DataManager.getGamePasses(player: Player)
	local profile = profiles[player]
	if not profile then
		return {}
	end
	return profile.gamePasses
end

--- Multiplicateur d'événement actif (rempli par EventManager)
DataManager.eventMultiplier = 1
--- Boost temporaire global du joueur, lu par les systèmes
function DataManager.getBoostMultiplier(profile): number
	if profile.boost and profile.boost.endsAt > os.time() and profile.boost.mult > 1 then
		return profile.boost.mult
	end
	return 1
end

--- Multiplicateur total courant (utilisé par CollectSystem et l'UI)
function DataManager.getPowerMultiplier(player: Player): number
	local profile = profiles[player]
	if not profile then
		return 1
	end
	return Formulas.totalPowerMultiplier(profile, profile.gamePasses, DataManager.eventMultiplier, DataManager.getBoostMultiplier(profile))
end

--- Multiplicateur total calculé depuis un profil (sans Player).
--- Utilisé par les gains hors-ligne.
function DataManager.getPowerMultiplierFor(profile): number
	if not profile then
		return 1
	end
	return Formulas.totalPowerMultiplier(
		profile,
		profile.gamePasses,
		DataManager.eventMultiplier,
		DataManager.getBoostMultiplier(profile)
	)
end

-- ============================================================
-- CYCLE DE VIE
-- ============================================================
local function onPlayerAdded(player: Player)
	local ok, err = pcall(function()
		DataManager.load(player)
	end)
	if not ok then
		warn("[DataManager] erreur fatale de chargement pour " .. player.Name .. " : " .. tostring(err))
		local profile = ProfileTemplate.new()
		profiles[player] = profile
		saveBlocked[player] = true
		setupLeaderstats(player, profile)
		DataManager.Events.Loaded:Fire(player, profile)
	end
end

local function onPlayerRemoving(player: Player)
	local profile = profiles[player]
	if profile then
		profile.playtime = profile.playtime + 1
		DataManager.save(player, true)
		DataManager.Events.Unloaded:Fire(player, profile)
	end
	profiles[player] = nil
	saveBlocked[player] = nil
	notifyCooldown[player] = nil
end

function DataManager.start()
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end
	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		task.spawn(onPlayerRemoving, player)
	end)

	-- Sauvegarde automatique
	task.spawn(function()
		while true do
			task.wait(GameConfig.Misc.SaveInterval)
			for player in pairs(profiles) do
				if player.Parent then
					task.spawn(function()
						DataManager.save(player, false)
					end)
				end
			end
		end
	end)

	-- Temps de jeu
	task.spawn(function()
		while true do
			task.wait(60)
			for _, profile in pairs(profiles) do
				profile.playtime = profile.playtime + 60
			end
		end
	end)
end

--- À appeler depuis Bootstrap (BindToClose)
function DataManager.shutdown()
	local threads = {}
	for player in pairs(profiles) do
		table.insert(threads, task.spawn(function()
			DataManager.save(player, true)
		end))
	end
	-- attente max 20s (limite Roblox à la fermeture)
	local deadline = os.clock() + 20
	for _, thread in ipairs(threads) do
		while coroutine.status(thread) ~= "dead" and os.clock() < deadline do
			task.wait(0.1)
		end
	end
end

return DataManager
