--!strict
--[[
	AchievementSystem  |  ServerScriptService.Systems.AchievementSystem
	------------------------------------------------------------------
	24 succès. La progression est calculée côté serveur à partir des
	statistiques réelles du profil (impossible à falsifier).
	Résultat : récompense en pièces + notification + animation UI.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local Net = require(Modules:WaitForChild("Net"))

local DataManager = require(script.Parent.DataManager)

local AchievementSystem = {}

local function getStatValue(profile, statName: string): number
	if statName == "rebirths" then
		return profile.rebirths or 0
	elseif statName == "bestPower" then
		return math.max(profile.bestPower or 0, profile.power or 0)
	elseif statName == "maxWorld" then
		return profile.maxWorld or 1
	elseif statName == "streak" then
		return (profile.daily and profile.daily.streak) or 0
	end
	return (profile.stats and profile.stats[statName]) or 0
end

--- Vérifie tous les succès d'un joueur, débloque ceux atteints.
function AchievementSystem.check(player: Player, silent: boolean?)
	local profile = DataManager.getProfile(player)
	if not profile then
		return 0
	end
	local unlocked = 0
	for _, achievementId in ipairs(GameConfig.AchievementOrder) do
		local achievement = GameConfig.Achievements[achievementId]
		if achievement and not profile.achievements[achievementId] then
			if getStatValue(profile, achievement.Stat) >= achievement.Goal then
				profile.achievements[achievementId] = true
				profile.coins = profile.coins + achievement.Reward
				unlocked = unlocked + 1
				Net.event("Notify"):FireClient(
					player,
					string.format("%s Succès débloqué : %s  (+%s 🪙)", achievement.Icon, achievement.Name, tostring(achievement.Reward)),
					"ffd700",
					"🏆"
				)
				Net.event("PlaySound"):FireClient(player, "achievement", 0.7)
			end
		end
	end
	if unlocked > 0 then
		DataManager.notify(player, true)
	end
	return unlocked
end

--- Liste des succès avec leur progression (pour l'UI)
function AchievementSystem.getList(profile)
	local list = {}
	for _, achievementId in ipairs(GameConfig.AchievementOrder) do
		local achievement = GameConfig.Achievements[achievementId]
		if achievement then
			local value = profile and getStatValue(profile, achievement.Stat) or 0
			table.insert(list, {
				Id = achievementId,
				Name = achievement.Name,
				Desc = achievement.Desc,
				Icon = achievement.Icon,
				Goal = achievement.Goal,
				Reward = achievement.Reward,
				Progress = math.min(value, achievement.Goal),
				Unlocked = profile and profile.achievements[achievementId] or false,
			})
		end
	end
	return list
end

function AchievementSystem.start()
	-- Vérification régulière (toutes les 2s, peu coûteux)
	task.spawn(function()
		while true do
			task.wait(2)
			for _, player in ipairs(Players:GetPlayers()) do
				if DataManager.isLoaded(player) then
					local ok, err = pcall(AchievementSystem.check, player, true)
					if not ok then
						warn("[AchievementSystem] " .. tostring(err))
					end
				end
			end
		end
	end)

	-- À chaque événement clé, on revérifie immédiatement
	DataManager.Events.Rebirth:Connect(function(player)
		AchievementSystem.check(player, false)
	end)

	Net.event("ClaimAchievement").OnServerEvent:Connect(function(player, achievementId)
		-- Les récompenses sont automatiques ; ce remote sert de "ping"
		AchievementSystem.check(player, false)
	end)

	print("[AchievementSystem] Démarré")
end

return AchievementSystem
