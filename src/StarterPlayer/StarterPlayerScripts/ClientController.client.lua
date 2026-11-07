--!strict
--[[
	ClientController  |  StarterPlayer.StarterPlayerScripts.ClientController (LocalScript)
	------------------------------------------------------------------
	POINT D'ENTRÉE DU CLIENT. Il :
	  1. construit l'UI (UIController)
	  2. écoute tous les RemoteEvents et met à jour ClientState
	  3. démarre les contrôleurs d'effets / pets / sons
	  4. gère la collecte au clic, au tap et en maintien (auto-clic)
	  5. demande le profil au serveur (ClientReady + GetProfile)

	Aucune valeur de progression n'est calculée ici : tout vient du
	serveur (ProfileUpdated). Le client ne fait que de l'affichage.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local Formulas = require(Modules:WaitForChild("Formulas"))
local Net = require(Modules:WaitForChild("Net"))

local Controllers = script.Parent:WaitForChild("Controllers")
local UIFolder = script.Parent:WaitForChild("UI")

local ClientState = require(Controllers:WaitForChild("ClientState"))
local SoundController = require(Controllers:WaitForChild("SoundController"))
local EffectsController = require(Controllers:WaitForChild("EffectsController"))
local PetFollowController = require(Controllers:WaitForChild("PetFollowController"))
local UIController = require(UIFolder:WaitForChild("UIController"))
local UIConfig = require(UIFolder:WaitForChild("UIConfig"))

local C = UIConfig.Colors

-- ============================================================
-- 1. INTERFACE
-- ============================================================
local screenGui = UIController.start()

-- ============================================================
-- 2. CONTRÔLEURS
-- ============================================================
SoundController.start()
EffectsController.start(screenGui)
PetFollowController.start()

-- ============================================================
-- 3. REMOTES → ÉTAT LOCAL
-- ============================================================
local function colorFromHex(hex: string?): Color3
	if type(hex) ~= "string" or #hex < 6 then
		return C.Gold
	end
	return UIConfig.fromHex(hex)
end

Net.event("ProfileUpdated").OnClientEvent:Connect(function(profile)
	local wasReady = ClientState.hasProfile
	ClientState.setProfile(profile)
	if not wasReady then
		UIController.hideLoading()
		SoundController.playWorldMusic(profile.world or 1)
	end
end)

Net.event("Notify").OnClientEvent:Connect(function(text, colorHex, icon)
	UIController.toast(text, colorFromHex(colorHex), icon or "✨")
	ClientState.Signals.Notify:Fire(text, colorHex, icon)
end)

Net.event("EffectBurst").OnClientEvent:Connect(function(position, colorHex, value)
	ClientState.Signals.EffectBurst:Fire(position, colorHex, value)
end)

Net.event("PlaySound").OnClientEvent:Connect(function(key, volume)
	SoundController.play(key, volume)
end)

Net.event("CameraShake").OnClientEvent:Connect(function(intensity)
	ClientState.Signals.CameraShake:Fire(intensity)
end)

Net.event("ScreenFlash").OnClientEvent:Connect(function(colorHex, duration)
	ClientState.Signals.ScreenFlash:Fire(colorHex, duration)
end)

Net.event("EventUpdate").OnClientEvent:Connect(function(eventId, endsAt)
	ClientState.eventId = eventId
	ClientState.eventEndsAt = endsAt or 0
	ClientState.Signals.Event:Fire(eventId, endsAt or 0)
end)

Net.event("EggResult").OnClientEvent:Connect(function(rarity, petId, name, mult, eggId, isNew)
	UIController.queueEggReveal({ rarity = rarity, petId = petId, name = name, mult = mult, eggId = eggId, isNew = isNew })
	ClientState.Signals.EggResult:Fire(rarity, petId, name, mult, eggId, isNew)
end)

Net.event("LeaderboardData").OnClientEvent:Connect(function(global, server)
	if type(global) == "table" then
		ClientState.globalLeaderboard = global
	end
	if type(server) == "table" then
		ClientState.serverLeaderboard = server
	end
	ClientState.Signals.Leaderboard:Fire(global, server)
end)

Net.event("SetWorld").OnClientEvent:Connect(function(worldIndex)
	ClientState.currentWorld = worldIndex
	ClientState.Signals.World:Fire(worldIndex)
	ClientState.Signals.Sound:Fire("teleport", 0.5)
end)

Net.event("Transformation").OnClientEvent:Connect(function(tier)
	ClientState.Signals.Transformation:Fire(tier)
	local data = GameConfig.Transformations[tier]
	if data then
		UIController.toast(string.format("Transformation : %s %s !", data.Emoji, data.Name), data.Aura, data.Emoji)
	end
end)

Net.event("DailyAvailable").OnClientEvent:Connect(function(available)
	ClientState.dailyAvailable = available
	ClientState.Signals.Daily:Fire(available)
end)

Net.event("BoostUpdate").OnClientEvent:Connect(function(mult, endsAt)
	ClientState.boostMult = mult or 1
	ClientState.boostEndsAt = endsAt or 0
	ClientState.Signals.Boost:Fire(mult, endsAt)
end)

Net.event("RebirthSuccess").OnClientEvent:Connect(function(rebirths, coins)
	ClientState.Signals.Rebirth:Fire(rebirths, coins)
	UIController.toast(string.format("🔄 REBIRTH %d ! +%s pièces", rebirths, Formulas.formatNumber(coins or 0)), C.Pink, "🔄")
end)

-- ============================================================
-- 4. COLLECTE (clic / tap / maintien)
-- ============================================================
local lastClickTime = 0
local holding = false
local lastPointer = Vector2.new(0, 0)
local collectiblesFolder = nil

local function getCollectibles(): Instance?
	if collectiblesFolder and collectiblesFolder.Parent then
		return collectiblesFolder
	end
	collectiblesFolder = Workspace:FindFirstChild("Collectibles")
	return collectiblesFolder
end

--- Trouve l'objet le plus proche du joueur (fallback mobile / tap dans le vide)
local function findNearestCollectible(maxDistance: number): BasePart?
	local folder = getCollectibles()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not folder or not root then
		return nil
	end
	local origin = (root :: BasePart).Position
	local best = nil
	local bestDistance = maxDistance
	for _, part in ipairs(folder:GetChildren()) do
		if part:IsA("BasePart") then
			local distance = ((part :: BasePart).Position - origin).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				best = part
			end
		end
	end
	return best
end

local function tryCollectAt(screenPosition: Vector2)
	local now = os.clock()
	if now - lastClickTime < 0.045 then
		return
	end
	lastClickTime = now

	local camera = Workspace.CurrentCamera
	local folder = getCollectibles()
	if not camera or not folder then
		return
	end

	local ray = camera:ScreenPointToRay(screenPosition.X, screenPosition.Y)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }
	params.IgnoreWater = true
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 800, params)

	local target = result and result.Instance
	if target and target:IsA("BasePart") then
		Net.event("CollectRequest"):FireServer(target)
		return
	end

	-- Rien de visé : on prend l'objet le plus proche (très pratique sur mobile)
	local nearest = findNearestCollectible(48)
	if nearest then
		Net.event("CollectRequest"):FireServer(nearest)
	end
end

local function canInteract(): boolean
	return ClientState.hasProfile and player.Character ~= nil
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if not canInteract() then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		holding = true
		lastPointer = input.Position
		tryCollectAt(input.Position)
	elseif input.UserInputType == Enum.UserInputType.Touch then
		lastPointer = input.Position
		tryCollectAt(input.Position)
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		lastPointer = input.Position
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		holding = false
	end
end)

-- Maintien du clic = clics automatiques rapides (très satisfaisant)
task.spawn(function()
	while true do
		local interval = 0.09
		task.wait(interval)
		if holding and canInteract() then
			tryCollectAt(lastPointer)
		end
	end
end)

-- ============================================================
-- 5. DÉMARRAGE RÉSEAU
-- ============================================================
Net.event("ClientReady"):FireServer()

task.spawn(function()
	local ok, profile = pcall(function()
		return Net.func("GetProfile"):InvokeServer()
	end)
	if ok and type(profile) == "table" and not ClientState.hasProfile then
		ClientState.setProfile(profile)
		UIController.hideLoading()
	end
end)

-- Sécurité : si le serveur met trop de temps, on enlève l'écran de chargement
task.delay(20, function()
	if not ClientState.hasProfile then
		UIController.hideLoading()
		UIController.toast("⚠️ Chargement lent… réessaie de rejoindre si ça bloque.", C.Red, "⚠️")
	end
end)

-- Vitesse / saut : le serveur gère la vitesse (amélioration), le client
-- s'assure juste que la physique reste agréable après un respawn
player.CharacterAdded:Connect(function(character)
	local humanoid = character:WaitForChild("Humanoid", 10)
	if humanoid then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = 50
	end
end)

print("[ClientController] Prêt — " .. GameConfig.GameName .. " v" .. tostring(GameConfig.Version))
