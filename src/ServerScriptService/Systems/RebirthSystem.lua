--!strict
--[[
	RebirthSystem  |  ServerScriptService.Systems.RebirthSystem
	------------------------------------------------------------------
	Rebirth : le joueur sacrifie sa puissance actuelle contre un
	multiplicateuf permanent + des pièces + un nouveau titre.

	• Coût croissant : 2500 × 2.15^rebirths (40 rebirths max)
	• Multiplicateur permanent : +0.35× par rebirth
	• Récompense en pièces + déblocage de titres tous les 5 rebirths
	• Annonce à tout le serveur (effet de victoire)
	• Tout est vérifié côté serveur, une seule requête par 2 secondes
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local Formulas = require(Modules:WaitForChild("Formulas"))
local Net = require(Modules:WaitForChild("Net"))
local Signal = require(Modules:WaitForChild("Signal"))

local DataManager = require(script.Parent.DataManager)
local WorldManager = require(script.Parent.WorldManager)
local CharacterSystem = require(script.Parent.CharacterSystem)

local RebirthSystem = {}

RebirthSystem.Events = {
	RebirthPerformed = Signal.new(), -- (player, rebirths)
}

local lastRequest: { [Player]: number } = {}

-- ============================================================
-- TITRES
-- ============================================================
local function updateTitles(player: Player, profile)
	for _, title in ipairs(GameConfig.Titles) do
		if profile.rebirths >= title.Rebirth then
			if not table.find(profile.titles, title.Id) then
				table.insert(profile.titles, title.Id)
				Net.event("Notify"):FireClient(player, "🏷️ Nouveau titre débloqué : " .. title.Name, "ffd700", "🏷️")
			end
		end
	end
end

-- ============================================================
-- REBIRTH
-- ============================================================
function RebirthSystem.canRebirth(player: Player): (boolean, string, number)
	local profile = DataManager.getProfile(player)
	if not profile then
		return false, "Profil non chargé.", 0
	end
	if profile.rebirths >= GameConfig.Rebirth.MaxRebirths then
		return false, "Rebirth maximum atteint ! 🏆", 0
	end
	local cost = Formulas.rebirthCost(profile.rebirths)
	if profile.power < cost then
		return false, string.format("Il te manque %s de puissance.", Formulas.formatNumber(cost - profile.power)), cost
	end
	return true, "", cost
end

function RebirthSystem.rebirth(player: Player): boolean
	local now = os.clock()
	if lastRequest[player] and now - lastRequest[player] < 2 then
		return false
	end
	lastRequest[player] = now

	local profile = DataManager.getProfile(player)
	if not profile then
		return false
	end

	local can, reason, cost = RebirthSystem.canRebirth(player)
	if not can then
		Net.event("Notify"):FireClient(player, "❌ " .. reason, "ff6b6b", "❌")
		return false
	end

	if profile.power < cost then
		return false
	end

	-- Application (atomique)
	profile.power = 0
	profile.rebirths = profile.rebirths + 1
	profile.totalRebirths = profile.totalRebirths + 1

	local coinReward = Formulas.rebirthCoinReward(profile.rebirths)
	profile.coins = profile.coins + coinReward

	updateTitles(player, profile)
	DataManager.addStat(player, "rebirths", 1)

	-- Les pets restent équipés, les améliorations sont conservées.
	-- Le joueur repart de zéro en puissance mais avec un multiplicateur.

	Net.event("RebirthSuccess"):FireClient(player, profile.rebirths, coinReward)
	Net.event("PlaySound"):FireClient(player, "rebirth", 0.9)
	Net.event("CameraShake"):FireClient(player, 1.2)
	Net.event("ScreenFlash"):FireClient(player, "ffffff", 0.5)

	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			Net.event("Notify"):FireClient(
				other,
				string.format("🔄 %s vient d'effectuer son Rebirth %d !", player.DisplayName, profile.rebirths),
				"ffd700",
				"🔄"
			)
		end
	end

	DataManager.notify(player, true)
	DataManager.save(player, false)

	WorldManager.checkUnlocks(player, true)
	CharacterSystem.reset(player)
	task.delay(0.2, function()
		CharacterSystem.refresh(player)
	end)

	RebirthSystem.Events.RebirthPerformed:Fire(player, profile.rebirths)
	DataManager.Events.Rebirth:Fire(player, profile)
	return true
end

-- ============================================================
-- DÉMARRAGE
-- ============================================================
function RebirthSystem.start()
	Net.event("RebirthRequest").OnServerEvent:Connect(function(player)
		RebirthSystem.rebirth(player)
	end)

	-- L'autel de rebirth est aussi cliquable dans le lobby (Touched)
	task.spawn(function()
		local lobby = workspace:WaitForChild("Lobby", 20)
		if not lobby then
			return
		end
		local altar = lobby:FindFirstChild("RebirthAltar")
		if not altar then
			return
		end
		local base = altar:FindFirstChild("AltarBase")
		if base and base:IsA("BasePart") then
			base.Touched:Connect(function(hit)
				local character = hit:FindFirstAncestorOfClass("Model")
				local touchPlayer = character and Players:GetPlayerFromCharacter(character)
				if touchPlayer then
					Net.event("Notify"):FireClient(touchPlayer, "Appuie sur le bouton 🔄 Rebirth de l'interface !", "ffd700", "🔄")
				end
			end)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastRequest[player] = nil
	end)

	print("[RebirthSystem] Démarré")
end

return RebirthSystem
