--!strict
--[[
	EventManager  |  ServerScriptService.Systems.EventManager
	------------------------------------------------------------------
	Un événement aléatoire toutes les 5 minutes (configurable) :

	  🦍 Giant Mode      -> tous les joueurs ×1.8 en taille, puissance ×1.5
	  💰 Money Rain      -> des pièces tombent du ciel dans tous les mondes
	  🌙 Low Gravity     -> gravité divisée par 4
	  ✨ Golden Objects  -> 100% d'objets dorés (×5 puissance)
	  🌪️ Chaos Mode      -> mini-événements imprévisibles en chaîne
	  🍀 Lucky Time      -> gains ×2 et pets rares 2× plus probables

	Chaque événement a un compte à rebours diffusé à tous les clients.
	Le nettoyage est garanti (pcall + liste de "revert").
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local Formulas = require(Modules:WaitForChild("Formulas"))
local Net = require(Modules:WaitForChild("Net"))
local Signal = require(Modules:WaitForChild("Signal"))

local DataManager = require(script.Parent.DataManager)
local CollectSystem = require(script.Parent.CollectSystem)
local CharacterSystem = require(script.Parent.CharacterSystem)
local PetSystem = require(script.Parent.PetSystem)

local EventManager = {}

EventManager.Events = {
	Started = Signal.new(), -- (eventId)
	Ended = Signal.new(),   -- (eventId)
}

EventManager.currentEventId = nil
EventManager.endsAt = 0

local BASE_GRAVITY = 196.2
local BASE_GOLDEN_CHANCE = 0.05
local activeReverts = {}
local participatedThisEvent = {}
local moneyRainParts = {}

local function setRevert(key: string, callback: (() -> ())?)
	if callback then
		activeReverts[key] = callback
	else
		activeReverts[key] = nil
	end
end

local function runReverts()
	for key, callback in pairs(activeReverts) do
		local ok, err = pcall(callback)
		if not ok then
			warn("[EventManager] revert " .. key .. " : " .. tostring(err))
		end
	end
	activeReverts = {}
end

local function announce(eventId: string, message: string, color: string?)
	for _, player in ipairs(Players:GetPlayers()) do
		Net.event("Notify"):FireClient(player, message, color or "ffd700", "🎉")
		Net.event("PlaySound"):FireClient(player, "event", 0.8)
	end
end

local function broadcastEventState(eventId: string?, endsAt: number?)
	Net.event("EventUpdate"):FireAllClients(eventId, endsAt)
end

local function refreshAllCharacters()
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			local ok, err = pcall(CharacterSystem.refresh, player)
			if not ok then
				warn("[EventManager] refresh : " .. tostring(err))
			end
		end)
	end
end

-- ============================================================
-- EFFETS DES ÉVÉNEMENTS
-- ============================================================
local eventEffects = {}

--- 🦍 Tous les joueurs deviennent géants
eventEffects.GiantMode = function()
	CharacterSystem.sizeMultiplier = 1.8
	DataManager.eventMultiplier = DataManager.eventMultiplier * GameConfig.EventRewards.GiantModePowerMult
	refreshAllCharacters()
	setRevert("giant", function()
		CharacterSystem.sizeMultiplier = 1
		refreshAllCharacters()
	end)
	announce("GiantMode", "🦍 GIANT MODE ! Tout le monde devient GÉANT (puissance ×1.5) !", "ff8c3c")
end

--- 💰 Des pièces tombent du ciel
local function spawnMoneyRain(burst: number?)
	local worldsWithPlayers = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = DataManager.getProfile(player)
		if profile and profile.world > 0 then
			worldsWithPlayers[profile.world] = true
		end
	end
	if next(worldsWithPlayers) == nil then
		worldsWithPlayers[1] = true
	end

	local folder = Workspace:FindFirstChild("MoneyRain")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "MoneyRain"
		folder.Parent = Workspace
	end

	for worldIndex in pairs(worldsWithPlayers) do
		local info = require(script.Parent.WorldFactory).getWorldInfo(worldIndex)
		if info then
			local count = burst or 26
			for _ = 1, count do
				local coin = Instance.new("Part")
				coin.Name = "CoinDrop"
				coin.Shape = Enum.PartType.Cylinder
				coin.Size = Vector3.new(0.6, 3, 3)
				coin.Color = Color3.fromRGB(255, 215, 60)
				coin.Material = Enum.Material.Neon
				coin.Anchored = false
				coin.CanCollide = false
				coin.CanTouch = true
				coin.CastShadow = false
				local x = info.Center.X + math.random(-280, 280)
				local z = info.Center.Z + math.random(-280, 280)
				coin.CFrame = CFrame.new(x, math.random(110, 150), z) * CFrame.Angles(0, 0, math.rad(90))
				coin:SetAttribute("EventCoin", true)

				local light = Instance.new("PointLight")
				light.Color = Color3.fromRGB(255, 220, 80)
				light.Brightness = 1.5
				light.Range = 16
				light.Parent = coin

				coin.Touched:Connect(function(hit)
					if not coin.Parent then
						return
					end
					local character = hit:FindFirstAncestorOfClass("Model")
					local player = character and Players:GetPlayerFromCharacter(character)
					if player then
						local profile = DataManager.getProfile(player)
						if profile then
							local amount = math.max(25, math.floor(GameConfig.EventRewards.MoneyRainCoins * (1 + profile.rebirths * 0.25)))
							DataManager.addCoins(player, amount)
							Net.event("EffectBurst"):FireClient(player, coin.Position, "ffd700", amount)
							Net.event("PlaySound"):FireClient(player, "coin", 0.4)
							DataManager.notify(player)
						end
						coin:Destroy()
					end
				end)

				coin.Parent = folder
				table.insert(moneyRainParts, coin)
			end
		end
	end

	-- Nettoyage des pièces non ramassées
	task.delay(40, function()
		for index = #moneyRainParts, 1, -1 do
			local coin = moneyRainParts[index]
			if coin and coin.Parent then
				coin:Destroy()
			end
			table.remove(moneyRainParts, index)
		end
	end)
end

eventEffects.MoneyRain = function()
	announce("MoneyRain", "💰 MONEY RAIN ! Des pièces tombent du ciel, attrape-les !", "ffd700")
	spawnMoneyRain(34)
	setRevert("moneyrain", function() end)
	-- vagues successives
	for wave = 1, 3 do
		task.delay(wave * 12, function()
			if EventManager.currentEventId == "MoneyRain" then
				spawnMoneyRain(18)
			end
		end)
	end
end

--- 🌙 Gravité réduite
eventEffects.LowGravity = function()
	Workspace.Gravity = BASE_GRAVITY / 4
	setRevert("gravity", function()
		Workspace.Gravity = BASE_GRAVITY
	end)
	announce("LowGravity", "🌙 LOW GRAVITY ! La gravité est divisée par 4, envole-toi !", "a0c8ff")
end

--- ✨ Objets dorés
eventEffects.GoldenObjects = function()
	CollectSystem.goldenChance = 1
	CollectSystem.spawnMultiplier = 1.4
	setRevert("golden", function()
		CollectSystem.goldenChance = BASE_GOLDEN_CHANCE
		CollectSystem.spawnMultiplier = 1
	end)
	announce("GoldenObjects", "✨ GOLDEN OBJECTS ! Tous les objets sont dorés : puissance ×5 !", "ffc832")
end

--- 🍀 Chance doublée
eventEffects.LuckyTime = function()
	DataManager.eventMultiplier = DataManager.eventMultiplier * GameConfig.EventRewards.LuckyTimeMult
	PetSystem.luckyMultiplier = 2
	setRevert("lucky", function()
		PetSystem.luckyMultiplier = 1
	end)
	announce("LuckyTime", "🍀 LUCKY TIME ! Gains ×2 et pets rares 2× plus probables !", "5aff8c")
end

--- 🌪️ Chaos : mini-événements aléatoires en chaîne
eventEffects.ChaosMode = function()
	announce("ChaosMode", "🌪️ CHAOS MODE ! Tout peut arriver... accroche-toi !", "ff3cc8")
	local chaosFunctions = {
		function()
			Workspace.Gravity = BASE_GRAVITY * 0.3
			announce("ChaosMode", "🌀 Gravité mollassonne !", "ff3cc8")
			task.delay(8, function()
				Workspace.Gravity = BASE_GRAVITY
			end)
		end,
		function()
			spawnMoneyRain(12)
			announce("ChaosMode", "💰 Pluie de pièces surprise !", "ffd700")
		end,
		function()
			CollectSystem.goldenChance = 1
			task.delay(8, function()
				CollectSystem.goldenChance = BASE_GOLDEN_CHANCE
			end)
			announce("ChaosMode", "✨ Objets dorés pendant 8 secondes !", "ffc832")
		end,
		function()
			CharacterSystem.sizeMultiplier = 2.2
			refreshAllCharacters()
			task.delay(8, function()
				CharacterSystem.sizeMultiplier = 1
				refreshAllCharacters()
			end)
			announce("ChaosMode", "🦍 GÉANT pendant 8 secondes !", "ff8c3c")
		end,
		function()
			announce("ChaosMode", "🎁 Cadeau du chaos : +puissance pour tous !", "8affc1")
			for _, player in ipairs(Players:GetPlayers()) do
				local profile = DataManager.getProfile(player)
				if profile then
					local bonus = math.max(10, math.floor(profile.power * 0.15))
					DataManager.addPower(player, bonus, "chaos")
					Net.event("EffectBurst"):FireClient(player, player.Character and player.Character:GetPivot().Position or Vector3.zero, "ff3cc8", bonus)
					DataManager.notify(player)
				end
			end
		end,
	}
	for index = 1, 8 do
		task.delay(index * 8, function()
			if EventManager.currentEventId == "ChaosMode" then
				local chaos = chaosFunctions[math.random(1, #chaosFunctions)]
				pcall(chaos)
			end
		end)
	end
	setRevert("chaos", function()
		Workspace.Gravity = BASE_GRAVITY
		CollectSystem.goldenChance = BASE_GOLDEN_CHANCE
		CharacterSystem.sizeMultiplier = 1
		refreshAllCharacters()
	end)
end

-- ============================================================
-- CYCLE DES ÉVÉNEMENTS
-- ============================================================
function EventManager.startEvent(eventId: string)
	local eventData = GameConfig.Events[eventId]
	if not eventData then
		return
	end
	if EventManager.currentEventId then
		EventManager.stopEvent()
	end

	EventManager.currentEventId = eventId
	EventManager.endsAt = os.time() + (eventData.Duration or GameConfig.EventDuration)
	participatedThisEvent = {}

	broadcastEventState(eventId, EventManager.endsAt)
	EventManager.Events.Started:Fire(eventId)

	local effect = eventEffects[eventId]
	if effect then
		local ok, err = pcall(effect)
		if not ok then
			warn("[EventManager] effet " .. eventId .. " : " .. tostring(err))
			EventManager.stopEvent()
			return
		end
	end

	print(string.format("[EventManager] Événement lancé : %s (%d s)", eventData.Name, eventData.Duration or GameConfig.EventDuration))
end

function EventManager.stopEvent()
	local eventId = EventManager.currentEventId
	if not eventId then
		return
	end
	runReverts()
	DataManager.eventMultiplier = 1
	PetSystem.luckyMultiplier = 1
	Workspace.Gravity = BASE_GRAVITY
	CollectSystem.goldenChance = BASE_GOLDEN_CHANCE
	CollectSystem.spawnMultiplier = 1
	CharacterSystem.sizeMultiplier = 1
	refreshAllCharacters()

	EventManager.currentEventId = nil
	EventManager.endsAt = 0
	broadcastEventState(nil, nil)

	local eventData = GameConfig.Events[eventId]
	if eventData then
		announce("", string.format("%s est terminé ! Prochain événement dans %s.", eventData.Name, Formulas.formatTime(GameConfig.EventInterval)), "aaaaaa")
	end
	EventManager.Events.Ended:Fire(eventId)
	print("[EventManager] Événement terminé : " .. eventId)
end

function EventManager.start()
	-- Participation : collecter pendant un événement compte pour un succès
	CollectSystem.Events.Collected:Connect(function(player)
		if EventManager.currentEventId then
			local profile = DataManager.getProfile(player)
			if profile and not participatedThisEvent[player] then
				participatedThisEvent[player] = true
				DataManager.addStat(player, "events", 1)
			end
		end
	end)

	-- Boucle principale
	task.spawn(function()
		task.wait(25) -- laisse le temps aux joueurs de charger
		while true do
			EventManager.startEvent(GameConfig.EventOrder[math.random(1, #GameConfig.EventOrder)])

			local duration = (GameConfig.Events[EventManager.currentEventId] and GameConfig.Events[EventManager.currentEventId].Duration) or GameConfig.EventDuration
			-- compte à rebours : petites mises à jour (les clients calculent en local)
			for _ = 1, duration do
				task.wait(1)
			end

			EventManager.stopEvent()
			task.wait(GameConfig.EventInterval - duration)
		end
	end)

	-- Un joueur qui rejoint pendant un événement reçoit l'état courant
	DataManager.Events.Loaded:Connect(function(player)
		task.wait(1)
		if EventManager.currentEventId then
			Net.event("EventUpdate"):FireClient(player, EventManager.currentEventId, EventManager.endsAt)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		participatedThisEvent[player] = nil
	end)

	print("[EventManager] Démarré (intervalle : " .. GameConfig.EventInterval .. "s)")
end

return EventManager
