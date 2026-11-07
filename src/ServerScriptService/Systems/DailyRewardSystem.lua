--!strict
--[[
	DailyRewardSystem  |  ServerScriptService.Systems.DailyRewardSystem
	------------------------------------------------------------------
	• Récompense quotidienne (7 jours à la suite, puis reset du cycle)
	• Système de série (streak) avec cooldown de 20 h
	• Bonus de boost temporaire et œuf gratuit le 7e jour
	• Gains hors-ligne : si le joueur a l'absorption automatique, il
	  récupère une partie de sa production pendant son absence
	  (plafonnée à 8 h, calculée côté serveur uniquement)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local Formulas = require(Modules:WaitForChild("Formulas"))
local Net = require(Modules:WaitForChild("Net"))

local DataManager = require(script.Parent.DataManager)
local PetSystem = require(script.Parent.PetSystem)

local DailyRewardSystem = {}

local function isAvailable(profile): boolean
	return (os.time() - (profile.daily.lastClaim or 0)) >= GameConfig.DailyResetSeconds
end

function DailyRewardSystem.getStatus(profile)
	if not profile then
		return { available = false, nextAt = 0, dayIndex = 1, streak = 0 }
	end
	local available = isAvailable(profile)
	local remaining = math.max(0, GameConfig.DailyResetSeconds - (os.time() - profile.daily.lastClaim))
	return {
		available = available,
		remaining = available and 0 or remaining,
		nextAt = profile.daily.lastClaim + GameConfig.DailyResetSeconds,
		dayIndex = profile.daily.dayIndex,
		streak = profile.daily.streak,
	}
end

function DailyRewardSystem.claim(player: Player): boolean
	local profile = DataManager.getProfile(player)
	if not profile then
		return false
	end
	if not isAvailable(profile) then
		local remaining = GameConfig.DailyResetSeconds - (os.time() - profile.daily.lastClaim)
		Net.event("Notify"):FireClient(player, "⏳ Reviens dans " .. Formulas.formatTime(remaining), "ff9f43", "⏳")
		return false
	end

	local now = os.time()
	-- Si le joueur a raté plus de 2 jours, la série retombe à 0
	if profile.daily.lastClaim > 0 and (now - profile.daily.lastClaim) > (GameConfig.DailyResetSeconds * 2.5) then
		profile.daily.streak = 0
		profile.daily.dayIndex = 1
	end

	local dayIndex = math.clamp(profile.daily.dayIndex or 1, 1, #GameConfig.DailyRewards)
	local reward = GameConfig.DailyRewards[dayIndex]

	profile.daily.lastClaim = now
	profile.daily.streak = (profile.daily.streak or 0) + 1
	profile.daily.dayIndex = (dayIndex % #GameConfig.DailyRewards) + 1

	profile.coins = profile.coins + (reward.Coins or 0)
	DataManager.addStat(player, "dailies", 1)

	if reward.BoostMinutes and reward.BoostMinutes > 0 then
		profile.boost = {
			mult = math.max(2, profile.boost and profile.boost.mult or 1),
			endsAt = os.time() + reward.BoostMinutes * 60,
		}
		Net.event("BoostUpdate"):FireClient(player, profile.boost.mult, profile.boost.endsAt)
	end

	if reward.FreeEgg and GameConfig.Eggs[reward.FreeEgg] then
		PetSystem.openEgg(player, reward.FreeEgg, 1)
	end

	Net.event("Notify"):FireClient(
		player,
		string.format("📅 Jour %d réclamé ! +%s 🪙  (série : %d)", dayIndex, Formulas.formatNumber(reward.Coins), profile.daily.streak),
		"8affc1",
		"📅"
	)
	Net.event("PlaySound"):FireClient(player, "daily", 0.7)
	Net.event("DailyAvailable"):FireClient(player, false)
	DataManager.notify(player, true)
	return true
end

-- ============================================================
-- GAINS HORS-LIGNE
-- ============================================================
local function computeOfflineEarnings(profile): number
	local autoLevel = (profile.upgrades and profile.upgrades.AutoCollect) or 0
	local hasPass = profile.gamePasses and profile.gamePasses.AutoCollect
	if autoLevel <= 0 and not hasPass then
		return 0
	end
	local lastSeen = profile.__previousLastSeen or profile.lastSeen or os.time()
	local secondsAway = math.clamp(os.time() - lastSeen, 0, GameConfig.MaxOfflineHours * 3600)
	if secondsAway < 300 then
		return 0
	end
	-- estimation : 6 objets/seconde × puissance moyenne du monde courant × 0.35
	local worldIndex = math.clamp(profile.world or 1, 1, #GameConfig.Worlds)
	local world = GameConfig.Worlds[worldIndex]
	local avgObjectPower = 0
	local weightSum = 0
	for objectId, weight in pairs(world.ObjectWeights) do
		local data = Formulas.getObjectData(objectId)
		if data then
			avgObjectPower = avgObjectPower + data.Power * weight
			weightSum = weightSum + weight
		end
	end
	if weightSum == 0 then
		return 0
	end
	avgObjectPower = (avgObjectPower / weightSum) * world.ValueMult
	local estimated = avgObjectPower * 4 * secondsAway * 0.35 * DataManager.getPowerMultiplierFor(profile)
	return math.floor(estimated)
end

function DailyRewardSystem.grantOfflineEarnings(player: Player, profile)
	local earnings = computeOfflineEarnings(profile)
	if earnings <= 0 then
		return
	end
	earnings = math.min(earnings, 1e12)
	DataManager.addPower(player, earnings, "offline")
	local coins = math.floor(earnings * Formulas.totalCoinMultiplier(profile, profile.gamePasses))
	DataManager.addCoins(player, coins)
	task.delay(2, function()
		if player.Parent then
			Net.event("Notify"):FireClient(
				player,
				string.format("💤 Gains hors-ligne : +%s ⚡ et +%s 🪙", Formulas.formatNumber(earnings), Formulas.formatNumber(coins)),
				"8affc1",
				"💤"
			)
			DataManager.notify(player, true)
		end
	end)
end

-- ============================================================
-- DÉMARRAGE
-- ============================================================
function DailyRewardSystem.start()
	Net.event("ClaimDaily").OnServerEvent:Connect(function(player)
		DailyRewardSystem.claim(player)
	end)

	DataManager.Events.Loaded:Connect(function(player, profile)
		task.wait(1.5)
		Net.event("DailyAvailable"):FireClient(player, isAvailable(profile))
		if profile.boost and profile.boost.endsAt > os.time() then
			Net.event("BoostUpdate"):FireClient(player, profile.boost.mult, profile.boost.endsAt)
		end
		DailyRewardSystem.grantOfflineEarnings(player, profile)
	end)

	print("[DailyRewardSystem] Démarré")
end

return DailyRewardSystem
