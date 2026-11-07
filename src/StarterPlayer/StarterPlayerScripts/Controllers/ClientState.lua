--!strict
--[[
	ClientState  |  StarterPlayer.StarterPlayerScripts.Controllers.ClientState
	------------------------------------------------------------------
	Miroir local du profil serveur + état de l'interface.
	TOUTES les valeurs de progression viennent du serveur : le client ne
	fait que les afficher. Les calculs (multiplicateurs, tiers) sont refaits
	ici uniquement pour l'affichage, jamais pour valider quoi que ce soit.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Signal = require(Modules:WaitForChild("Signal"))
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local Formulas = require(Modules:WaitForChild("Formulas"))
local ProfileTemplate = require(Modules:WaitForChild("ProfileTemplate"))

local ClientState = {}

ClientState.profile = ProfileTemplate.new()
ClientState.hasProfile = false
ClientState.eventId = nil
ClientState.eventEndsAt = 0
ClientState.currentWorld = 0
ClientState.globalLeaderboard = {}
ClientState.serverLeaderboard = {}
ClientState.boostMult = 1
ClientState.boostEndsAt = 0
ClientState.dailyAvailable = false
ClientState.vacuumReadyAt = 0

ClientState.Signals = {
	Profile = Signal.new(),       -- (profile)
	Event = Signal.new(),         -- (eventId, endsAt)
	World = Signal.new(),         -- (worldIndex)
	Leaderboard = Signal.new(),   -- (global, server)
	EggResult = Signal.new(),     -- (rarity, petId, name, mult, eggId, isNew)
	Rebirth = Signal.new(),       -- (rebirths, coins)
	Notify = Signal.new(),        -- (text, color, icon)
	Boost = Signal.new(),         -- (mult, endsAt)
	Transformation = Signal.new(),-- (tier)
	ScreenFlash = Signal.new(),   -- (color, duration)
	CameraShake = Signal.new(),   -- (intensity)
	Sound = Signal.new(),         -- (key, volume)
	EffectBurst = Signal.new(),   -- (position, color, value)
	Daily = Signal.new(),         -- (available)
}

function ClientState.setProfile(profile)
	if type(profile) ~= "table" then
		return
	end
	local previous = ClientState.profile
	ClientState.profile = profile
	ClientState.hasProfile = true
	ClientState.currentWorld = profile.world or ClientState.currentWorld
	ClientState.Signals.Profile:Fire(profile, previous)
end

-- ============================================================
-- GETTERS (affichage)
-- ============================================================
function ClientState.getPower(): number
	return ClientState.profile.power or 0
end

function ClientState.getCoins(): number
	return ClientState.profile.coins or 0
end

function ClientState.getRebirths(): number
	return ClientState.profile.rebirths or 0
end

function ClientState.getTierIndex(): number
	return Formulas.getTransformIndex(ClientState.getPower())
end

function ClientState.getTier()
	local index = Formulas.getTransformIndex(ClientState.getPower())
	return GameConfig.Transformations[index], index
end

function ClientState.getNextTier()
	local index = Formulas.getTransformIndex(ClientState.getPower())
	return GameConfig.Transformations[index + 1], index
end

function ClientState.getTierProgress(): number
	local current, index = ClientState.getTier()
	local nextTier = GameConfig.Transformations[index + 1]
	if not nextTier then
		return 1
	end
	local span = nextTier.MinPower - current.MinPower
	if span <= 0 then
		return 1
	end
	return math.clamp((ClientState.getPower() - current.MinPower) / span, 0, 1)
end

function ClientState.getBoost(): number
	if ClientState.boostEndsAt > os.time() then
		return math.max(1, ClientState.boostMult)
	end
	return 1
end

--- Multiplicateur d'événement côté client (affichage uniquement ; la
--- valeur officielle est calculée par DataManager/getPowerMultiplier).
function ClientState.getEventMultiplier(): number
	if not ClientState.eventIsActive() then
		return 1
	end
	if ClientState.eventId == "GiantMode" then
		return GameConfig.EventRewards.GiantModePowerMult
	elseif ClientState.eventId == "LuckyTime" then
		return GameConfig.EventRewards.LuckyTimeMult
	end
	return 1
end

function ClientState.getPowerMultiplier(): number
	local profile = ClientState.profile
	local mult = Formulas.totalPowerMultiplier(profile, profile.gamePasses, ClientState.getEventMultiplier(), ClientState.getBoost())
	return mult
end

function ClientState.getPetSlots(): number
	return Formulas.petSlots(ClientState.profile, ClientState.profile.gamePasses and ClientState.profile.gamePasses.ExtraPetSlots)
end

function ClientState.getUpgradeLevel(upgradeId: string): number
	local upgrades = ClientState.profile.upgrades
	return (upgrades and upgrades[upgradeId]) or 0
end

function ClientState.getWorld(): number
	return ClientState.currentWorld
end

function ClientState.getWorldData(worldIndex: number?)
	local index = worldIndex or ClientState.currentWorld
	if index <= 0 then
		return nil
	end
	return GameConfig.Worlds[index]
end

function ClientState.isWorldUnlocked(worldIndex: number): boolean
	local profile = ClientState.profile
	if worldIndex <= 0 then
		return true
	end
	local world = GameConfig.Worlds[worldIndex]
	if not world then
		return false
	end
	return (profile.maxWorld or 1) >= worldIndex
end

function ClientState.ownsPet(uid: string): boolean
	for _, pet in ipairs(ClientState.profile.pets or {}) do
		if pet.uid == uid then
			return true
		end
	end
	return false
end

function ClientState.isEquipped(uid: string): boolean
	for _, equippedUid in ipairs(ClientState.profile.equipped or {}) do
		if equippedUid == uid then
			return true
		end
	end
	return false
end

function ClientState.getEquippedPets()
	local map = {}
	for _, pet in ipairs(ClientState.profile.pets or {}) do
		map[pet.uid] = pet
	end
	local list = {}
	for _, uid in ipairs(ClientState.profile.equipped or {}) do
		if map[uid] then
			table.insert(list, map[uid])
		end
	end
	return list
end

function ClientState.countPetId(petId: string, level: number?): number
	local total = 0
	for _, pet in ipairs(ClientState.profile.pets or {}) do
		if pet.id == petId and (level == nil or pet.level == level) then
			total = total + 1
		end
	end
	return total
end

function ClientState.getSetting(key: string): boolean
	local settings = ClientState.profile.settings
	if settings and settings[key] ~= nil then
		return settings[key] == true
	end
	return true
end

function ClientState.eventIsActive(): boolean
	return ClientState.eventId ~= nil and ClientState.eventEndsAt > os.time()
end

function ClientState.eventRemaining(): number
	return math.max(0, ClientState.eventEndsAt - os.time())
end

return ClientState
