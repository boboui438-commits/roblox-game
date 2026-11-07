--!strict
--[[
	ProfileTemplate  |  ReplicatedStorage.Modules.ProfileTemplate
	------------------------------------------------------------------
	Structure EXACTE des données d'un joueur.
	Utilisé par le serveur (DataManager) et par le client (valeurs par
	défaut en attendant la sauvegarde).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = require(script.Parent.GameConfig)

local ProfileTemplate = {}

--- Retourne un profil neuf
function ProfileTemplate.new()
	return {
		version = GameConfig.DataVersion,
		created = os.time(),
		lastSeen = os.time(),
		playtime = 0,

		-- Progression -------------------------------------------------
		power = 0,          -- puissance ACTUELLE (reset au rebirth)
		bestPower = 0,      -- record de puissance (succès)
		totalPower = 0,     -- puissance cumulée à vie
		coins = 0,
		rebirths = 0,
		totalRebirths = 0,
		world = 1,          -- monde où le joueur se trouve
		maxWorld = 1,       -- monde le plus élevé débloqué

		-- Pets --------------------------------------------------------
		pets = {},          -- { { uid = string, id = string, level = number }, ... }
		equipped = {},      -- { uid, uid, ... }

		-- Améliorations ----------------------------------------------
		upgrades = {},      -- { PowerMult = 0, CoinMult = 0, ... }

		-- Succès ------------------------------------------------------
		achievements = {},  -- { achievementId = true }

		-- Statistiques (servent aux succès) --------------------------
		stats = {
			collected = 0,
			eggsOpened = 0,
			legendaryPets = 0,
			mythicalPets = 0,
			secretPets = 0,
			fusions = 0,
			vacuums = 0,
			dailies = 0,
			events = 0,
			playerKills = 0,
		},

		-- Récompense quotidienne --------------------------------------
		daily = {
			lastClaim = 0,
			streak = 0,
			dayIndex = 1,
		},

		-- Titres ------------------------------------------------------
		titles = { "noob" },
		titleSelected = "noob",

		-- Œufs gratuits déjà utilisés ---------------------------------
		freeEggsTaken = {},

		-- Boost temporaire (developer product / daily) ----------------
		boost = {
			mult = 1,
			endsAt = 0,
		},

		-- Paramètres --------------------------------------------------
		settings = {
			music = true,
			sfx = true,
			effects = true,
			particles = true,
			cameraShake = true,
			petsVisible = true,
			damageNumbers = true,
		},

		-- Rempli par MonetizationSystem (jamais sauvegardé) -----------
		gamePasses = {
			DoublePower = false,
			AutoCollect = false,
			ExtraPetSlots = false,
			VIP = false,
			Cosmetics = false,
		},

		-- Interne -----------------------------------------------------
		__saveBlocked = false,
	}
end

--- Réparation / migration d'un profil chargé depuis le DataStore.
--- Ne lève jamais d'erreur : renvoie toujours un profil valide.
function ProfileTemplate.migrate(saved)
	local profile = ProfileTemplate.new()
	if type(saved) ~= "table" then
		return profile
	end

	local numericFields = { "power", "bestPower", "totalPower", "coins", "rebirths", "totalRebirths", "playtime", "created", "lastSeen" }
	for _, field in ipairs(numericFields) do
		local value = saved[field]
		if type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge then
			profile[field] = math.max(0, value)
		end
	end

	local worldValue = saved.world
	if type(worldValue) == "number" then
		-- 0 = lobby, 1..#Worlds = mondes jouables
		profile.world = math.clamp(math.floor(worldValue), 0, #GameConfig.Worlds)
	end
	local maxWorldValue = saved.maxWorld
	if type(maxWorldValue) == "number" then
		profile.maxWorld = math.clamp(math.floor(maxWorldValue), 1, #GameConfig.Worlds)
	end

	-- Pets : validation stricte (anti-duplication / anti-corruption)
	if type(saved.pets) == "table" then
		local seenUids = {}
		local pets = {}
		for _, pet in ipairs(saved.pets) do
			if type(pet) == "table" and type(pet.uid) == "string" and type(pet.id) == "string" and GameConfig.Pets[pet.id] then
				if not seenUids[pet.uid] and #pets < GameConfig.Misc.MaxPets then
					seenUids[pet.uid] = true
					table.insert(pets, {
						uid = pet.uid,
						id = pet.id,
						level = math.clamp(math.floor(tonumber(pet.level) or 1), 1, GameConfig.Misc.MaxPetLevel),
					})
				end
			end
		end
		profile.pets = pets
	end

	if type(saved.equipped) == "table" then
		local ownedUids = {}
		for _, pet in ipairs(profile.pets) do
			ownedUids[pet.uid] = true
		end
		local equipped = {}
		for _, uid in ipairs(saved.equipped) do
			if type(uid) == "string" and ownedUids[uid] and #equipped < 12 then
				table.insert(equipped, uid)
			end
		end
		profile.equipped = equipped
	end

	if type(saved.upgrades) == "table" then
		for upgradeId, info in pairs(GameConfig.Upgrades) do
			local level = saved.upgrades[upgradeId]
			if type(level) == "number" then
				profile.upgrades[upgradeId] = math.clamp(math.floor(level), 0, info.MaxLevel)
			end
		end
	end

	if type(saved.achievements) == "table" then
		for achievementId in pairs(saved.achievements) do
			if GameConfig.Achievements[achievementId] then
				profile.achievements[achievementId] = true
			end
		end
	end

	if type(saved.stats) == "table" then
		for statName in pairs(profile.stats) do
			local value = saved.stats[statName]
			if type(value) == "number" and value == value then
				profile.stats[statName] = math.max(0, math.floor(value))
			end
		end
	end

	if type(saved.daily) == "table" then
		profile.daily.lastClaim = math.max(0, tonumber(saved.daily.lastClaim) or 0)
		profile.daily.streak = math.max(0, math.floor(tonumber(saved.daily.streak) or 0))
		profile.daily.dayIndex = math.clamp(math.floor(tonumber(saved.daily.dayIndex) or 1), 1, #GameConfig.DailyRewards)
	end

	if type(saved.titles) == "table" then
		local validTitles = {}
		for _, titleId in ipairs(saved.titles) do
			for _, title in ipairs(GameConfig.Titles) do
				if title.Id == titleId then
					table.insert(validTitles, titleId)
					break
				end
			end
		end
		if #validTitles > 0 then
			profile.titles = validTitles
		end
	end

	if type(saved.titleSelected) == "string" then
		for _, title in ipairs(GameConfig.Titles) do
			if title.Id == saved.titleSelected then
				profile.titleSelected = saved.titleSelected
				break
			end
		end
	end

	if type(saved.freeEggsTaken) == "table" then
		for eggId, taken in pairs(saved.freeEggsTaken) do
			if GameConfig.Eggs[eggId] and taken == true then
				profile.freeEggsTaken[eggId] = true
			end
		end
	end

	if type(saved.boost) == "table" then
		local mult = tonumber(saved.boost.mult) or 1
		local endsAt = tonumber(saved.boost.endsAt) or 0
		if mult > 1 and endsAt > os.time() then
			profile.boost.mult = math.clamp(mult, 1, 10)
			profile.boost.endsAt = endsAt
		end
	end

	if type(saved.settings) == "table" then
		for key in pairs(profile.settings) do
			if type(saved.settings[key]) == "boolean" then
				profile.settings[key] = saved.settings[key]
			end
		end
	end

	profile.version = GameConfig.DataVersion
	return profile
end

--- Version "publique" : ce qui est envoyé au client (pas de champs internes)
function ProfileTemplate.toPublic(profile)
	local public = {
		version = profile.version,
		power = profile.power,
		bestPower = profile.bestPower,
		totalPower = profile.totalPower,
		coins = profile.coins,
		rebirths = profile.rebirths,
		totalRebirths = profile.totalRebirths,
		world = profile.world,
		maxWorld = profile.maxWorld,
		pets = profile.pets,
		equipped = profile.equipped,
		upgrades = profile.upgrades,
		achievements = profile.achievements,
		stats = profile.stats,
		daily = profile.daily,
		titles = profile.titles,
		titleSelected = profile.titleSelected,
		freeEggsTaken = profile.freeEggsTaken,
		boost = profile.boost,
		settings = profile.settings,
		gamePasses = profile.gamePasses,
		playtime = profile.playtime,
	}
	return public
end

return ProfileTemplate
