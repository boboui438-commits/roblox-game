--!strict
--[[
	MonetizationSystem  |  ServerScriptService.Systems.MonetizationSystem
	------------------------------------------------------------------
	GAME PASSES (permanents, vérifiés côté serveur) :
	  DoublePower, AutoCollect, ExtraPetSlots, VIP, Cosmetics

	DEVELOPER PRODUCTS (consommables) :
	  PowerBoost ×3 (15 min), CoinPack, MegaCoinPack, LuckyEgg (légendaire)

	⚠️ IMPORTANT : remplace les Id = 0 dans GameConfig par tes vrais IDs.
	   Tant que les IDs valent 0, tout le système de paiement est ignoré
	   (aucune erreur) et le jeu reste 100% jouable gratuitement.

	Sécurité : ProcessReceipt est idempotent (PurchaseId mémorisé dans le
	profil), les récompenses sont accordées uniquement côté serveur.
]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local Formulas = require(Modules:WaitForChild("Formulas"))
local Net = require(Modules:WaitForChild("Net"))

local DataManager = require(script.Parent.DataManager)
local PetSystem = require(script.Parent.PetSystem)

local MonetizationSystem = {}

local productById: { [number]: any } = {}
local receiptHistory: { [number]: { [string]: boolean } } = {}

local function buildProductIndex()
	for productName, product in pairs(GameConfig.DeveloperProducts) do
		if product.Id and product.Id > 0 then
			productById[product.Id] = product
			product.Key = product.Key or productName
		end
	end
end

-- ============================================================
-- GAME PASSES
-- ============================================================
local function checkGamePass(player: Player, passId: number): boolean
	if passId <= 0 then
		return false
	end
	local ok, owns = pcall(function()
		return MarketplaceService:UserOwnsGamePassAsync(player.UserId, passId)
	end)
	if ok then
		return owns == true
	end
	warn("[Monetization] UserOwnsGamePassAsync : " .. tostring(owns))
	return false
end

function MonetizationSystem.refreshGamePasses(player: Player)
	local profile = DataManager.getProfile(player)
	if not profile then
		return
	end
	local passes = profile.gamePasses
	for passName, pass in pairs(GameConfig.GamePasses) do
		passes[passName] = checkGamePass(player, pass.Id or 0)
	end
	DataManager.notify(player, true)
end

-- ============================================================
-- DEVELOPER PRODUCTS
-- ============================================================
local function grantProduct(player: Player, productKey: string): boolean
	local profile = DataManager.getProfile(player)
	if not profile then
		return false
	end
	local rewards = GameConfig.ProductRewards[productKey]
	if not rewards then
		return false
	end

	if rewards.BoostMult and rewards.BoostSeconds then
		local endsAt = os.time() + rewards.BoostSeconds
		local currentMult = 1
		if profile.boost and profile.boost.endsAt > os.time() then
			currentMult = profile.boost.mult
		end
		profile.boost = { mult = math.max(currentMult, rewards.BoostMult), startsAt = os.time(), endsAt = endsAt }
		Net.event("BoostUpdate"):FireClient(player, profile.boost.mult, endsAt)
		Net.event("Notify"):FireClient(player, "🚀 Boost ×" .. tostring(profile.boost.mult) .. " activé pour 15 min !", "8affc1", "🚀")
	end

	if rewards.Coins and rewards.Coins > 0 then
		DataManager.addCoins(player, rewards.Coins)
		Net.event("Notify"):FireClient(player, "🪙 +" .. Formulas.formatNumber(rewards.Coins) .. " pièces !", "ffd700", "🪙")
	end

	if rewards.GuaranteedRarity then
		PetSystem.grantPetOfRarity(player, rewards.GuaranteedRarity)
	end

	DataManager.notify(player, true)
	return true
end

function MonetizationSystem.start()
	buildProductIndex()

	MarketplaceService.ProcessReceipt = function(receiptInfo)
		local player = Players:GetPlayerByUserId(receiptInfo.PlayerId)
		if not player then
			-- le joueur est parti : on ne débite pas, il sera remboursé
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local profile = DataManager.getProfile(player)
		if not profile then
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		-- Idempotence
		local history = receiptHistory[player.UserId]
		if not history then
			history = {}
			receiptHistory[player.UserId] = history
		end
		if history[receiptInfo.PurchaseId] then
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end

		local product = productById[receiptInfo.ProductId]
		local productKey = product and product.Key or nil
		if not productKey then
			-- produit non configuré : on cherche par nom dans la config
			for name, entry in pairs(GameConfig.DeveloperProducts) do
				if entry.Id == receiptInfo.ProductId then
					productKey = entry.Key or name
					break
				end
			end
		end

		if not productKey then
			warn("[Monetization] produit inconnu : " .. tostring(receiptInfo.ProductId))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		local ok, err = pcall(grantProduct, player, productKey)
		if not ok then
			warn("[Monetization] échec d'attribution : " .. tostring(err))
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end

		history[receiptInfo.PurchaseId] = true
		DataManager.save(player, false)
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- Vérification des game passes à l'arrivée
	DataManager.Events.Loaded:Connect(function(player)
		task.spawn(function()
			MonetizationSystem.refreshGamePasses(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		receiptHistory[player.UserId] = nil
	end)

	local configured = 0
	for _, pass in pairs(GameConfig.GamePasses) do
		if (pass.Id or 0) > 0 then
			configured = configured + 1
		end
	end
	if configured == 0 then
		print("[MonetizationSystem] Démarré — ⚠️ aucun Game Pass configuré (IDs = 0), monétisation désactivée.")
	else
		print(string.format("[MonetizationSystem] Démarré — %d game passes configurés.", configured))
	end
end

return MonetizationSystem
