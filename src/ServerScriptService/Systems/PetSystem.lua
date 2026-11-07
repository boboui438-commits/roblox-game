--!strict
--[[
	PetSystem  |  ServerScriptService.Systems.PetSystem
	------------------------------------------------------------------
	Œufs, inventaire, équipement, fusion et meilleurs pets.

	SÉCURITÉ (tout est serveur) :
	  • le client ne fait que DEMANDER ("ouvre l'œuf X")
	  • le tirage aléatoire est fait ici (Random.new)
	  • le prix est vérifié et débité ici
	  • les uid sont générés ici, jamais par le client
	  • impossible d'équiper un pet non possédé
	  • impossible de fusionner des pets non possédés
	  • limite d'inventaire (anti-duplication)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local Formulas = require(Modules:WaitForChild("Formulas"))
local Net = require(Modules:WaitForChild("Net"))
local Util = require(Modules:WaitForChild("Util"))
local Signal = require(Modules:WaitForChild("Signal"))

local DataManager = require(script.Parent.DataManager)

local PetSystem = {}

PetSystem.Events = {
	EggOpened = Signal.new(), -- (player, eggId, petId, rarity, isNew)
	PetEquipped = Signal.new(), -- (player, uid)
	PetFused = Signal.new(), -- (player, petId, newLevel)
}

local rng = Random.new(os.time() + math.floor(os.clock() * 1e6))
local lastEggOpen: { [Player]: number } = {}
local openBudget: { [Player]: number } = {}

-- Modifié par EventManager (Lucky Time) : chances de raretés améliorées
PetSystem.luckyMultiplier = 1

local RARE_SET = {
	Rare = true,
	Epic = true,
	Legendary = true,
	Mythical = true,
	Secret = true,
}

-- ============================================================
-- HELPERS
-- ============================================================
local function findPet(profile, uid: string)
	for index, pet in ipairs(profile.pets) do
		if pet.uid == uid then
			return pet, index
		end
	end
	return nil, nil
end

local function isEggAvailable(player: Player, profile, eggId: string): (boolean, string)
	local egg = GameConfig.Eggs[eggId]
	if not egg then
		return false, "Œuf inconnu."
	end
	if egg.MinRebirth and (profile.rebirths or 0) < egg.MinRebirth then
		return false, string.format("Nécessite %d rebirth(s).", egg.MinRebirth)
	end
	if egg.World and profile.maxWorld < egg.World then
		return false, "Débloque d'abord ce monde."
	end
	return true, ""
end

local function rollRarity(egg)
	local weights = {}
	for rarity, weight in pairs(egg.Rates) do
		local pool = egg.Pool[rarity]
		if pool and #pool > 0 then
			local adjusted = weight
			if RARE_SET[rarity] and PetSystem.luckyMultiplier > 1 then
				adjusted = weight * PetSystem.luckyMultiplier
			end
			weights[rarity] = adjusted
		end
	end
	local rarity = Util.weightedChoice(weights, rng)
	if not rarity then
		for _, candidate in ipairs(GameConfig.RarityOrder) do
			if egg.Pool[candidate] and #egg.Pool[candidate] > 0 then
				rarity = candidate
				break
			end
		end
	end
	return rarity
end

local function rollPetOfRarity(egg, rarity: string): string?
	local pool = egg.Pool[rarity]
	if not pool or #pool == 0 then
		return nil
	end
	local weighted = {}
	for _, petId in ipairs(pool) do
		local petInfo = GameConfig.Pets[petId]
		if petInfo then
			weighted[petId] = petInfo.Weight or GameConfig.PetWeightInsideRarity
		end
	end
	return Util.weightedChoice(weighted, rng)
end

local function createPetEntry(profile, petId: string)
	local uid = Util.generateUid(rng)
	while findPet(profile, uid) do
		uid = Util.generateUid(rng)
	end
	local pet = { uid = uid, id = petId, level = 1 }
	table.insert(profile.pets, pet)
	return pet
end

local function countRarity(profile, rarity: string): number
	local total = 0
	for _, pet in ipairs(profile.pets) do
		local info = GameConfig.Pets[pet.id]
		if info and info.Rarity == rarity then
			total = total + 1
		end
	end
	return total
end

-- ============================================================
-- OUVERTURE D'ŒUF
-- ============================================================
--- Accorde un pet directement (utilisé par les developer products)
function PetSystem.grantPet(player: Player, petId: string, rarityOverride: string?): any
	local profile = DataManager.getProfile(player)
	if not profile then
		return nil
	end
	if #profile.pets >= GameConfig.Misc.MaxPets then
		Net.event("Notify"):FireClient(player, "Inventaire plein ! Fusionne tes pets.", "ff6b6b", "⚠️")
		return nil
	end
	local alreadyOwned = false
	for _, pet in ipairs(profile.pets) do
		if pet.id == petId then
			alreadyOwned = true
			break
		end
	end
	local pet = createPetEntry(profile, petId)
	local info = GameConfig.Pets[petId]
	if info.Rarity == "Legendary" then
		DataManager.addStat(player, "legendaryPets", 1)
	elseif info.Rarity == "Mythical" then
		DataManager.addStat(player, "mythicalPets", 1)
	elseif info.Rarity == "Secret" then
		DataManager.addStat(player, "secretPets", 1)
	end
	Net.event("EggResult"):FireClient(player, info.Rarity, petId, info.Name, info.Mult, "DeveloperProduct", not alreadyOwned)
	DataManager.notify(player, true)
	PetSystem.Events.EggOpened:Fire(player, "DeveloperProduct", petId, info.Rarity, not alreadyOwned)
	return pet
end

--- Accorde un pet d'une rareté donnée (choisi dans tous les pets du jeu)
function PetSystem.grantPetOfRarity(player: Player, rarity: string)
	local candidates = {}
	for petId, info in pairs(GameConfig.Pets) do
		if info.Rarity == rarity then
			table.insert(candidates, petId)
		end
	end
	if #candidates == 0 then
		return nil
	end
	local petId = candidates[rng:NextInteger(1, #candidates)]
	return PetSystem.grantPet(player, petId)
end

function PetSystem.openEgg(player: Player, eggId: any, amount: any): number
	local profile = DataManager.getProfile(player)
	if not profile then
		return 0
	end
	if type(eggId) ~= "string" then
		return 0
	end
	local egg = GameConfig.Eggs[eggId]
	if not egg then
		return 0
	end

	-- anti-spam
	local now = os.clock()
	if lastEggOpen[player] and now - lastEggOpen[player] < 0.25 then
		return 0
	end
	local budget = (openBudget[player] or 0) + 1
	if now - (lastEggOpen[player] or 0) > 1 then
		budget = 1
	end
	if budget > 12 then
		return 0
	end
	openBudget[player] = budget
	lastEggOpen[player] = now

	local quantity = 1
	if type(amount) == "number" then
		quantity = math.clamp(math.floor(amount), 1, 3)
	end

	local available, reason = isEggAvailable(player, profile, eggId)
	if not available then
		Net.event("Notify"):FireClient(player, "🔒 " .. reason, "ff6b6b", "🔒")
		return 0
	end

	if egg.FreeOnePerPlayer and profile.freeEggsTaken[eggId] then
		Net.event("Notify"):FireClient(player, "Tu as déjà utilisé ton œuf gratuit ! Ouvre-en un autre.", "ff9f43", "🥚")
		return 0
	end

	local isFree = egg.FreeOnePerPlayer and not profile.freeEggsTaken[eggId]
	local totalPrice = 0
	if not isFree then
		totalPrice = (egg.Price or 0) * quantity
	else
		quantity = 1
	end

	if #profile.pets + quantity > GameConfig.Misc.MaxPets then
		Net.event("Notify"):FireClient(player, "Inventaire plein ! Fusionne tes pets.", "ff6b6b", "⚠️")
		return 0
	end

	if totalPrice > 0 then
		if profile.coins < totalPrice then
			Net.event("Notify"):FireClient(player, "Pas assez de pièces ! (" .. Formulas.formatNumber(totalPrice) .. " requis)", "ff6b6b", "🪙")
			return 0
		end
		profile.coins = profile.coins - totalPrice
	end

	if isFree then
		profile.freeEggsTaken[eggId] = true
	end

	local opened = 0
	for _ = 1, quantity do
		if #profile.pets >= GameConfig.Misc.MaxPets then
			break
		end
		local rarity = rollRarity(egg)
		local petId = rarity and rollPetOfRarity(egg, rarity) or nil
		if rarity and petId then
			local alreadyOwned = false
			for _, existingPet in ipairs(profile.pets) do
				if existingPet.id == petId then
					alreadyOwned = true
					break
				end
			end

			createPetEntry(profile, petId)
			DataManager.addStat(player, "eggsOpened", 1)

			if rarity == "Legendary" then
				DataManager.addStat(player, "legendaryPets", 1)
			elseif rarity == "Mythical" then
				DataManager.addStat(player, "mythicalPets", 1)
			elseif rarity == "Secret" then
				DataManager.addStat(player, "secretPets", 1)
			end

			local info = GameConfig.Pets[petId]
			Net.event("EggResult"):FireClient(player, rarity, petId, info.Name, info.Mult, eggId, not alreadyOwned)
			PetSystem.Events.EggOpened:Fire(player, eggId, petId, rarity, not alreadyOwned)
			opened = opened + 1

			-- notification globale pour les pets très rares
			if rarity == "Secret" or rarity == "Mythical" then
				for _, other in ipairs(Players:GetPlayers()) do
					local otherProfile = DataManager.getProfile(other)
					if otherProfile and other == player then
						Net.event("Notify"):FireClient(other, string.format("🎉 %s a obtenu %s %s !", player.DisplayName, GameConfig.Rarities[rarity].Name, info.Name), "ffd700", info.Emoji)
					elseif otherProfile and otherProfile.settings.effects then
						Net.event("Notify"):FireClient(other, string.format("🌟 %s a obtenu %s (%s) !", player.DisplayName, info.Name, rarity), "c9a6ff", info.Emoji)
					end
				end
			end
		end
	end

	DataManager.notify(player, true)
	return opened
end

-- ============================================================
-- ÉQUIPEMENT
-- ============================================================
function PetSystem.equip(player: Player, uid: any): boolean
	local profile = DataManager.getProfile(player)
	if not profile or type(uid) ~= "string" then
		return false
	end
	local pet = findPet(profile, uid)
	if not pet then
		return false
	end
	if Util.indexOf(profile.equipped, uid) > 0 then
		return false
	end
	local slots = Formulas.petSlots(profile, profile.gamePasses and profile.gamePasses.ExtraPetSlots)
	if #profile.equipped >= slots then
		Net.event("Notify"):FireClient(player, "Tous tes emplacements sont utilisés ! Améliore-les dans la boutique.", "ff6b6b", "🐾")
		return false
	end
	table.insert(profile.equipped, uid)
	DataManager.notify(player, true)
	PetSystem.Events.PetEquipped:Fire(player, uid)
	return true
end

function PetSystem.unequip(player: Player, uid: any): boolean
	local profile = DataManager.getProfile(player)
	if not profile or type(uid) ~= "string" then
		return false
	end
	if not Util.removeValue(profile.equipped, uid) then
		return false
	end
	DataManager.notify(player, true)
	return true
end

--- Équipe automatiquement les meilleurs pets possédés.
function PetSystem.equipBest(player: Player): number
	local profile = DataManager.getProfile(player)
	if not profile then
		return 0
	end
	local slots = Formulas.petSlots(profile, profile.gamePasses and profile.gamePasses.ExtraPetSlots)
	local sorted = {}
	for _, pet in ipairs(profile.pets) do
		table.insert(sorted, pet)
	end
	table.sort(sorted, function(a, b)
		return Formulas.petPower(a.id, a.level) > Formulas.petPower(b.id, b.level)
	end)
	local equipped = {}
	for index = 1, math.min(slots, #sorted) do
		equipped[index] = sorted[index].uid
	end
	profile.equipped = equipped
	DataManager.notify(player, true)
	Net.event("Notify"):FireClient(player, "✨ Meilleurs pets équipés !", "8affc1", "🐾")
	return #equipped
end

--- Vérifie que l'équipement reste valide (appelé après un changement de slots)
function PetSystem.validateEquipped(player: Player)
	local profile = DataManager.getProfile(player)
	if not profile then
		return
	end
	local owned = {}
	for _, pet in ipairs(profile.pets) do
		owned[pet.uid] = true
	end
	local slots = Formulas.petSlots(profile, profile.gamePasses and profile.gamePasses.ExtraPetSlots)
	local valid = {}
	for _, uid in ipairs(profile.equipped) do
		if owned[uid] and #valid < slots then
			table.insert(valid, uid)
		end
	end
	if #valid ~= #profile.equipped then
		profile.equipped = valid
		DataManager.notify(player, true)
	end
end

-- ============================================================
-- FUSION
-- ============================================================
function PetSystem.fuse(player: Player, petId: any): boolean
	local profile = DataManager.getProfile(player)
	if not profile or type(petId) ~= "string" then
		return false
	end
	local info = GameConfig.Pets[petId]
	if not info then
		return false
	end

	local needed = GameConfig.Misc.FuseCount
	local requiredLevel = nil
	local candidates = {}
	for _, pet in ipairs(profile.pets) do
		if pet.id == petId then
			table.insert(candidates, pet)
		end
	end

	-- on privilégie les pets du plus petit niveau identique
	table.sort(candidates, function(a, b)
		return a.level < b.level
	end)
	if #candidates < needed then
		Net.event("Notify"):FireClient(player, string.format("Il faut %d %s identiques (niveau identique).", needed, info.Name), "ff6b6b", "⚗️")
		return false
	end

	requiredLevel = candidates[1].level
	if requiredLevel >= GameConfig.Misc.MaxPetLevel then
		Net.event("Notify"):FireClient(player, "Ce pet est déjà au niveau maximum !", "ff6b6b", "⚗️")
		return false
	end

	local toConsume = {}
	for _, pet in ipairs(candidates) do
		if pet.level == requiredLevel and #toConsume < needed then
			table.insert(toConsume, pet)
		end
	end
	if #toConsume < needed then
		Net.event("Notify"):FireClient(player, string.format("Il faut %d %s de NIVEAU %d.", needed, info.Name, requiredLevel), "ff6b6b", "⚗️")
		return false
	end

	-- retrait sécurisé par uid
	local consumedUids = {}
	for _, pet in ipairs(toConsume) do
		consumedUids[pet.uid] = true
	end
	local newPets = {}
	for _, pet in ipairs(profile.pets) do
		if not consumedUids[pet.uid] then
			table.insert(newPets, pet)
		end
	end

	local wasEquipped = false
	for _, uid in ipairs(profile.equipped) do
		if consumedUids[uid] then
			wasEquipped = true
			break
		end
	end
	local newEquipped = {}
	for _, uid in ipairs(profile.equipped) do
		if not consumedUids[uid] then
			table.insert(newEquipped, uid)
		end
	end

	local upgraded = { uid = toConsume[1].uid, id = petId, level = requiredLevel + 1 }
	table.insert(newPets, upgraded)
	if wasEquipped then
		table.insert(newEquipped, upgraded.uid)
	end

	profile.pets = newPets
	profile.equipped = newEquipped
	DataManager.addStat(player, "fusions", 1)

	Net.event("Notify"):FireClient(
		player,
		string.format("⚗️ Fusion réussie ! %s %s niveau %d", info.Emoji, info.Name, upgraded.level),
		"8affc1",
		"⚗️"
	)
	Net.event("PlaySound"):FireClient(player, "fuse", 0.7)
	DataManager.notify(player, true)
	PetSystem.validateEquipped(player)
	PetSystem.Events.PetFused:Fire(player, petId, upgraded.level)
	return true
end

-- ============================================================
-- DÉMARRAGE
-- ============================================================
function PetSystem.start()
	Net.event("OpenEgg").OnServerEvent:Connect(function(player, eggId, amount)
		PetSystem.openEgg(player, eggId, amount)
	end)

	Net.event("EquipPet").OnServerEvent:Connect(function(player, uid)
		if PetSystem.equip(player, uid) then
			Net.event("PlaySound"):FireClient(player, "equip", 0.4)
		end
	end)

	Net.event("UnequipPet").OnServerEvent:Connect(function(player, uid)
		PetSystem.unequip(player, uid)
	end)

	Net.event("EquipBestPets").OnServerEvent:Connect(function(player)
		PetSystem.equipBest(player)
	end)

	Net.event("FusePet").OnServerEvent:Connect(function(player, petId)
		PetSystem.fuse(player, petId)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastEggOpen[player] = nil
		openBudget[player] = nil
	end)

	print("[PetSystem] Démarré")
end

return PetSystem
