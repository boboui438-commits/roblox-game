--!strict
--[[
	SettingsSystem  |  ServerScriptService.Systems.SettingsSystem
	------------------------------------------------------------------
	• Paramètres joueur (musique, sons, effets, particules, pets visibles)
	  → validés et sauvegardés par le serveur (le client ne peut écrire
	    que les clés autorisées, avec des booléens)
	• Sélection de titre (uniquement les titres débloqués)
	• "ClientReady" : le serveur renvoie l'état complet au client
	• Petites actions sociales : comparaison de puissance
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local Formulas = require(Modules:WaitForChild("Formulas"))
local Net = require(Modules:WaitForChild("Net"))
local ProfileTemplate = require(Modules:WaitForChild("ProfileTemplate"))

local DataManager = require(script.Parent.DataManager)
local CharacterSystem = require(script.Parent.CharacterSystem)

local SettingsSystem = {}

local VALID_SETTINGS = {
	music = true,
	sfx = true,
	effects = true,
	particles = true,
	cameraShake = true,
	petsVisible = true,
	damageNumbers = true,
}

function SettingsSystem.setSetting(player: Player, key: any, value: any): boolean
	if type(key) ~= "string" or type(value) ~= "boolean" then
		return false
	end
	if VALID_SETTINGS[key] ~= true then
		return false
	end
	local profile = DataManager.getProfile(player)
	if not profile then
		return false
	end
	profile.settings[key] = value
	DataManager.notify(player)
	return true
end

function SettingsSystem.selectTitle(player: Player, titleId: any): boolean
	if type(titleId) ~= "string" then
		return false
	end
	local profile = DataManager.getProfile(player)
	if not profile then
		return false
	end
	if not table.find(profile.titles, titleId) then
		return false
	end
	profile.titleSelected = titleId
	CharacterSystem.reset(player)
	CharacterSystem.refresh(player)
	DataManager.notify(player, true)
	Net.event("PlaySound"):FireClient(player, "equip", 0.4)
	return true
end

--- Comparaison de puissance demandée par le client (bouton "Comparer")
function SettingsSystem.compare(player: Player, otherPlayer: Player)
	local a = DataManager.getProfile(player)
	local b = DataManager.getProfile(otherPlayer)
	if not a or not b then
		return
	end
	local diff = a.power - b.power
	local message
	if diff >= 0 then
		message = string.format("Tu es plus puissant que %s de %s ⚡ !", otherPlayer.DisplayName, Formulas.formatNumber(diff))
	else
		message = string.format("%s est plus puissant que toi de %s ⚡…", otherPlayer.DisplayName, Formulas.formatNumber(-diff))
	end
	Net.event("Notify"):FireClient(player, message, "8ac8ff", "⚖️")
end

function SettingsSystem.start()
	Net.event("SetSetting").OnServerEvent:Connect(function(player, key, value)
		SettingsSystem.setSetting(player, key, value)
	end)

	Net.event("SelectTitle").OnServerEvent:Connect(function(player, titleId)
		SettingsSystem.selectTitle(player, titleId)
	end)

	-- Comparaison de puissance avec un autre joueur du serveur
	Net.event("ComparePower").OnServerEvent:Connect(function(player, userId)
		if type(userId) ~= "number" then
			return
		end
		local otherPlayer = Players:GetPlayerByUserId(userId)
		if otherPlayer and otherPlayer ~= player then
			SettingsSystem.compare(player, otherPlayer)
		end
	end)

	Net.event("ClientReady").OnServerEvent:Connect(function(player)
		local profile = DataManager.waitForProfile(player, 20)
		if profile then
			Net.event("ProfileUpdated"):FireClient(player, ProfileTemplate.toPublic(profile))
			Net.event("SetWorld"):FireClient(player, profile.world)
		end
	end)

	Net.func("GetProfile").OnServerInvoke = function(player)
		local profile = DataManager.waitForProfile(player, 15)
		if profile then
			return ProfileTemplate.toPublic(profile)
		end
		return nil
	end

	Net.func("GetServerInfo").OnServerInvoke = function(player)
		return {
			players = #Players:GetPlayers(),
			serverTime = os.time(),
		}
	end

	Net.event("PlayEmote").OnServerEvent:Connect(function(player, emote)
		if type(emote) ~= "string" then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid then
			local animations = {
				dance = "rbxassetid://507771019",
				wave = "rbxassetid://507770239",
				laugh = "rbxassetid://507770818",
				cheer = "rbxassetid://507770677",
			}
			local assetId = animations[emote]
			if assetId then
				local animation = Instance.new("Animation")
				animation.AnimationId = assetId
				local track = humanoid:FindFirstChildOfClass("Animator") and humanoid:FindFirstChildOfClass("Animator"):LoadAnimation(animation)
				if track then
					track:Play()
					task.delay(4, function()
						if track.IsPlaying then
							track:Stop()
						end
					end)
				end
			end
		end
	end)

	print("[SettingsSystem] Démarré")
end

return SettingsSystem
