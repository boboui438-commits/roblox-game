--!strict
--[[
	Formulas  |  ReplicatedStorage.Modules.Formulas
	------------------------------------------------------------------
	Toutes les formules d'équilibrage. Utilisé par le SERVEUR (calculs
	officiels) et par le CLIENT (affichage / prévisions uniquement).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameConfig = nil

-- require compatible avec un ModuleScript placé ailleurs
local function getConfig()
	if GameConfig then
		return GameConfig
	end
	local module = script.Parent:FindFirstChild("GameConfig")
	assert(module, "GameConfig introuvable à côté de Formulas")
	GameConfig = require(module)
	return GameConfig
end

local Formulas = {}

local SUFFIXES = { "", "K", "M", "B", "T", "Qa", "Qi", "Sx", "Sp", "Oc", "No", "Dc", "Ud", "Dd", "Td", "Qad", "Qid", "Sxd", "Spd", "Ocd", "Nod", "Vg" }

--- Formate un nombre à la Roblox Simulator : 1 234 → 1.23K
function Formulas.formatNumber(value: number): string
	if value ~= value then
		return "0"
	end
	if value < 0 then
		return "-" .. Formulas.formatNumber(-value)
	end
	if value < 1000 then
		if value == math.floor(value) then
			return tostring(math.floor(value))
		end
		return string.format("%.1f", value)
	end
	local index = math.floor(math.log(value, 1000))
	index = math.clamp(index, 1, #SUFFIXES - 1)
	local scaled = value / (1000 ^ index)
	local text
	if scaled < 10 then
		text = string.format("%.2f", scaled)
	elseif scaled < 100 then
		text = string.format("%.1f", scaled)
	else
		text = string.format("%.0f", scaled)
	end
	-- retire les ".00" inutiles
	text = string.gsub(text, "(%.%d-)0+$", "%1")
	text = string.gsub(text, "%.$", "")
	return text .. SUFFIXES[index + 1]
end

--- Formate une durée en mm:ss
function Formulas.formatTime(seconds: number): string
	seconds = math.max(0, math.floor(seconds))
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	if m >= 60 then
		local h = math.floor(m / 60)
		return string.format("%dh%02d", h, m % 60)
	end
	return string.format("%d:%02d", m, s)
end

--- Tier de transformation selon la puissance ACTUELLE
function Formulas.getTransformIndex(power: number): number
	local list = getConfig().Transformations
	local index = 1
	for i = 1, #list do
		if power >= list[i].MinPower then
			index = i
		else
			break
		end
	end
	return index
end

function Formulas.getTransformation(power: number)
	local config = getConfig()
	return config.Transformations[Formulas.getTransformIndex(power)]
end

--- Puissance nécessaire pour la transformation suivante (ou nil)
function Formulas.getNextTransformation(power: number)
	local config = getConfig()
	local index = Formulas.getTransformIndex(power)
	return config.Transformations[index + 1]
end

--- Coût du prochain rebirth
function Formulas.rebirthCost(rebirths: number): number
	local config = getConfig()
	return math.floor(config.Rebirth.BaseCost * (config.Rebirth.CostGrowth ^ rebirths))
end

--- Multiplicateur de rebirth
function Formulas.rebirthMultiplier(rebirths: number): number
	return 1 + rebirths * getConfig().Rebirth.MultPerRebirth
end

--- Coût d'une amélioration
function Formulas.upgradeCost(upgradeId: string, level: number): number
	local upgrade = getConfig().Upgrades[upgradeId]
	if not upgrade then
		return math.huge
	end
	return math.floor(upgrade.BaseCost * (upgrade.CostGrowth ^ level))
end

function Formulas.upgradeMaxLevel(upgradeId: string): number
	local upgrade = getConfig().Upgrades[upgradeId]
	return upgrade and upgrade.MaxLevel or 0
end

--- Somme des multiplicateurs de pets équipés
function Formulas.petMultiplier(profile): number
	local config = getConfig()
	local total = 0
	local owned = {}
	for _, pet in ipairs(profile.pets or {}) do
		owned[pet.uid] = pet
	end
	for _, uid in ipairs(profile.equipped or {}) do
		local pet = owned[uid]
		if pet then
			local info = config.Pets[pet.id]
			if info then
				total = total + info.Mult * Formulas.petLevelMultiplier(pet.level or 1)
			end
		end
	end
	return 1 + total
end

--- Chaque niveau de pet ajoute +25% de son multiplicateur de base
function Formulas.petLevelMultiplier(level: number): number
	return 1 + (math.max(1, level) - 1) * 0.25
end

function Formulas.petPower(petId: string, level: number): number
	local info = getConfig().Pets[petId]
	if not info then
		return 0
	end
	return info.Mult * Formulas.petLevelMultiplier(level)
end

--- Multiplicateur d'amélioration de puissance
function Formulas.upgradeMultiplier(profile, upgradeId: string): number
	local upgrade = getConfig().Upgrades[upgradeId]
	local level = (profile.upgrades and profile.upgrades[upgradeId]) or 0
	if not upgrade or not upgrade.Effect then
		return 1
	end
	return 1 + level * upgrade.Effect
end

--- Multiplicateur TOTAL de puissance d'un joueur.
--- gamePasses = { DoublePower = bool, VIP = bool } (fourni par le serveur)
function Formulas.totalPowerMultiplier(profile, gamePasses, eventMult: number?, boostMult: number?): number
	local config = getConfig()
	local mult = 1
	mult = mult * Formulas.rebirthMultiplier(profile.rebirths or 0)
	mult = mult * Formulas.petMultiplier(profile)
	mult = mult * Formulas.upgradeMultiplier(profile, "PowerMult")
	mult = mult * (eventMult or 1)
	mult = mult * (boostMult or 1)
	if gamePasses then
		if gamePasses.DoublePower then
			mult = mult * 2
		end
		if gamePasses.VIP then
			mult = mult * 1.5
		end
	end
	return mult
end

function Formulas.totalCoinMultiplier(profile, gamePasses): number
	local config = getConfig()
	local mult = Formulas.upgradeMultiplier(profile, "CoinMult")
	if gamePasses and gamePasses.VIP then
		mult = mult * 1.5
	end
	return mult * config.Collect.CoinRatio
end

--- Nombre d'emplacements de pets du joueur
function Formulas.petSlots(profile, hasExtraSlots: boolean?): number
	local config = getConfig()
	local level = (profile.upgrades and profile.upgrades.PetSlots) or 0
	local slots = config.BasePetSlots + level
	if hasExtraSlots then
		slots = slots + 3
	end
	return slots
end

--- Valeur de puissance d'un objet
function Formulas.objectPower(worldIndex: number, objectId: string, golden: boolean?): number
	local config = getConfig()
	local world = config.Worlds[worldIndex]
	if not world then
		return 0
	end
	local data = config.ObjectTypes[objectId] or config.WorldObjectTypes[objectId]
	if not data then
		return 0
	end
	local value = data.Power * world.ValueMult
	if golden then
		value = value * config.EventRewards.GoldenObjectsMult
	end
	return value
end

function Formulas.getObjectData(objectId: string)
	local config = getConfig()
	return config.ObjectTypes[objectId] or config.WorldObjectTypes[objectId]
end

--- Rayon d'absorption automatique (0 = non débloqué)
function Formulas.autoCollectRadius(profile, hasGamePass: boolean?): number
	local config = getConfig()
	local level = (profile.upgrades and profile.upgrades.AutoCollect) or 0
	if level <= 0 and not hasGamePass then
		return 0
	end
	level = math.max(level, 1)
	return config.Upgrades.AutoCollect.RadiusBase + (level - 1) * config.Upgrades.AutoCollect.RadiusPerLevel
end

function Formulas.autoCollectInterval(profile): number
	local config = getConfig()
	local level = math.max(1, (profile.upgrades and profile.upgrades.AutoCollect) or 1)
	local interval = config.Upgrades.AutoCollect.IntervalBase - (level - 1) * config.Upgrades.AutoCollect.IntervalPerLevel
	return math.max(0.35, interval)
end

function Formulas.vacuumRadius(profile): number
	local config = getConfig()
	local level = (profile.upgrades and profile.upgrades.Vacuum) or 0
	return config.Collect.Vacuum.BaseRadius + level * config.Collect.Vacuum.RadiusPerLevel
end

function Formulas.vacuumCooldown(profile): number
	local config = getConfig()
	local level = (profile.upgrades and profile.upgrades.Vacuum) or 0
	return math.max(2, config.Collect.Vacuum.BaseCooldown - level * config.Collect.Vacuum.CooldownReductionPerLevel)
end

function Formulas.walkSpeed(profile): number
	local config = getConfig()
	local level = (profile.upgrades and profile.upgrades.WalkSpeed) or 0
	return 16 + level * config.Upgrades.WalkSpeed.Effect
end

--- Probabilités réellement affichées pour un œuf (somme = 100)
function Formulas.eggDisplayOdds(eggId: string)
	local config = getConfig()
	local egg = config.Eggs[eggId]
	local result = {}
	if not egg then
		return result
	end
	local total = 0
	for rarity, weight in pairs(egg.Rates) do
		local pool = egg.Pool[rarity]
		if pool and #pool > 0 then
			total = total + weight
		end
	end
	if total <= 0 then
		return result
	end
	for _, rarity in ipairs(config.RarityOrder) do
		local weight = egg.Rates[rarity]
		local pool = egg.Pool[rarity]
		if weight and pool and #pool > 0 then
			table.insert(result, {
				Rarity = rarity,
				Chance = (weight / total) * 100,
				Color = config.Rarities[rarity].Color,
				Pets = pool,
			})
		end
	end
	return result
end

--- Prix affiché du rebirth suivant (identique au serveur)
function Formulas.rebirthCoinReward(rebirths: number): number
	local config = getConfig()
	return config.Rebirth.CoinRewardBase + config.Rebirth.CoinRewardPerRebirth * rebirths
end

return Formulas
