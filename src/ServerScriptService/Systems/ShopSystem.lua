--!strict
--[[
	ShopSystem  |  ServerScriptService.Systems.ShopSystem
	------------------------------------------------------------------
	Améliorations achetables en pièces :
	  PowerMult, CoinMult, AutoCollect, Vacuum, WalkSpeed, PetSlots

	Tout est validé côté serveur : l'ID de l'amélioration doit exister,
	le niveau maximum doit être respecté, les pièces doivent être
	effectivement débitées (DataManager.spendCoins est atomique).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local Formulas = require(Modules:WaitForChild("Formulas"))
local Net = require(Modules:WaitForChild("Net"))

local DataManager = require(script.Parent.DataManager)
local PetSystem = require(script.Parent.PetSystem)
local CharacterSystem = require(script.Parent.CharacterSystem)

local ShopSystem = {}

local lastPurchase: { [Player]: number } = {}

-- ============================================================
-- ACHAT D'AMÉLIORATION
-- ============================================================
function ShopSystem.buyUpgrade(player: Player, upgradeId: any): boolean
	if type(upgradeId) ~= "string" then
		return false
	end
	local upgrade = GameConfig.Upgrades[upgradeId]
	if not upgrade then
		return false
	end
	local profile = DataManager.getProfile(player)
	if not profile then
		return false
	end

	-- anti-spam (5 achats/seconde max)
	local now = os.clock()
	local history = lastPurchase[player] or {}
	table.insert(history, now)
	while #history > 5 do
		table.remove(history, 1)
	end
	lastPurchase[player] = history
	if #history == 5 and now - history[1] < 1 then
		return false
	end

	local level = profile.upgrades[upgradeId] or 0
	if level >= upgrade.MaxLevel then
		Net.event("Notify"):FireClient(player, "Niveau maximum atteint pour " .. upgrade.Name, "ff6b6b", "⬆️")
		return false
	end

	local cost = Formulas.upgradeCost(upgradeId, level)
	if profile.coins < cost then
		Net.event("Notify"):FireClient(player, "Pas assez de pièces ! (" .. Formulas.formatNumber(cost) .. ")", "ff6b6b", "🪙")
		return false
	end

	if not DataManager.spendCoins(player, cost) then
		return false
	end

	profile.upgrades[upgradeId] = level + 1
	Net.event("PlaySound"):FireClient(player, "buy", 0.6)
	Net.event("Notify"):FireClient(
		player,
		string.format("%s %s niveau %d !", upgrade.Icon, upgrade.Name, level + 1),
		"8affc1",
		upgrade.Icon
	)

	if upgradeId == "PetSlots" then
		PetSystem.validateEquipped(player)
	end
	if upgradeId == "WalkSpeed" then
		CharacterSystem.refresh(player)
	end

	-- Auto-collect : on remet le compteur à zéro pour un effet immédiat
	if upgradeId == "AutoCollect" then
		player:SetAttribute("AutoCollectNext", 0)
	end

	DataManager.notify(player, true)
	return true
end

--- Prix/état de chaque amélioration (pour l'UI)
function ShopSystem.getUpgradeInfo(profile)
	local list = {}
	for upgradeId, upgrade in pairs(GameConfig.Upgrades) do
		local level = (profile and profile.upgrades and profile.upgrades[upgradeId]) or 0
		table.insert(list, {
			Id = upgradeId,
			Name = upgrade.Name,
			Desc = upgrade.Desc,
			Icon = upgrade.Icon,
			Level = level,
			MaxLevel = upgrade.MaxLevel,
			Cost = Formulas.upgradeCost(upgradeId, level),
			Maxed = level >= upgrade.MaxLevel,
		})
	end
	return list
end

function ShopSystem.start()
	Net.event("BuyUpgrade").OnServerEvent:Connect(function(player, upgradeId)
		ShopSystem.buyUpgrade(player, upgradeId)
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastPurchase[player] = nil
	end)

	print("[ShopSystem] Démarré")
end

return ShopSystem
