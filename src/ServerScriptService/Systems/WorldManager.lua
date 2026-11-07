--!strict
--[[
	WorldManager  |  ServerScriptService.Systems.WorldManager
	------------------------------------------------------------------
	  • Téléportation entre le lobby et les 6 mondes (validée serveur)
	  • Déblocage automatique des mondes (puissance + rebirths)
	  • Gestion des portails (Touched) et du pad de retour
	  • Compteur de joueurs par monde (utilisé par CollectSystem pour
	    n'activer les objets que dans les mondes occupés)
	  • Vérifie en boucle qu'un joueur n'a pas besoin d'être replacé.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local Net = require(Modules:WaitForChild("Net"))
local Signal = require(Modules:WaitForChild("Signal"))

local DataManager = require(script.Parent.DataManager)
local WorldFactory = require(script.Parent.WorldFactory)
local CollectSystem = require(script.Parent.CollectSystem)

local WorldManager = {}

WorldManager.Events = {
	WorldChanged = Signal.new(), -- (player, worldIndex)
	WorldUnlocked = Signal.new(), -- (player, worldIndex)
}

local lastTravel: { [Player]: number } = {}
local portalDebounce: { [Player]: number } = {}
local arrivalGrace: { [Player]: number } = {} -- anti "retour immédiat" au lobby
local occupancy: { [number]: number } = {}
local firstJoinDone: { [Player]: boolean } = {}

-- ============================================================
-- OCCUPATION
-- ============================================================
local function updateOccupancy(profile, delta: number, worldIndex: number?)
	local index = worldIndex or (profile and profile.world) or 0
	occupancy[index] = math.max(0, (occupancy[index] or 0) + delta)
	CollectSystem.worldOccupancy = occupancy
end

local function recomputeOccupancy()
	occupancy = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local profile = DataManager.getProfile(player)
		if profile then
			occupancy[profile.world] = (occupancy[profile.world] or 0) + 1
		end
	end
	CollectSystem.worldOccupancy = occupancy
end

function WorldManager.getOccupancy()
	return occupancy
end

-- ============================================================
-- PLACEMENT DU PERSONNAGE
-- ============================================================
local function getSpawnPosition(worldIndex: number): Vector3
	if worldIndex <= 0 then
		return WorldFactory.getLobbySpawn()
	end
	return WorldFactory.getWorldPosition(worldIndex)
end

local function placeCharacter(player: Player, worldIndex: number)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end
	local position = getSpawnPosition(worldIndex)
	(character :: Model):PivotTo(CFrame.new(position + Vector3.new(0, 3, 0)))
	return true
end

-- ============================================================
-- VOYAGE
-- ============================================================
function WorldManager.isWorldUnlocked(profile, worldIndex: number): boolean
	if worldIndex <= 0 then
		return true
	end
	local world = GameConfig.Worlds[worldIndex]
	if not world then
		return false
	end
	if profile.maxWorld < worldIndex then
		return false
	end
	if (profile.rebirths or 0) < world.UnlockRebirth then
		return false
	end
	return true
end

--- Téléporte un joueur. Renvoie true si le voyage a eu lieu.
function WorldManager.travel(player: Player, worldIndex: number, silent: boolean?): boolean
	local profile = DataManager.getProfile(player)
	if not profile then
		return false
	end
	if worldIndex ~= 0 and not GameConfig.Worlds[worldIndex] then
		return false
	end
	if not WorldManager.isWorldUnlocked(profile, worldIndex) then
		Net.event("Notify"):FireClient(player, "🔒 Ce monde n'est pas encore débloqué !", "ff6b6b", "🔒")
		return false
	end

	local now = os.clock()
	if lastTravel[player] and now - lastTravel[player] < 0.75 then
		return false
	end
	lastTravel[player] = now

	local previous = profile.world
	updateOccupancy(profile, -1, previous)
	profile.world = worldIndex
	updateOccupancy(profile, 1, worldIndex)

	Net.event("SetWorld"):FireClient(player, worldIndex)
	Net.event("PlaySound"):FireClient(player, "teleport", 0.5)

	-- petit délai pour laisser le fondu client se jouer
	task.spawn(function()
		task.wait(silent and 0 or 0.28)
		-- StreamingEnabled : on force le chargement de la zone AVANT de
		-- téléporter, sinon le joueur risque de tomber dans le vide.
		pcall(function()
			player:RequestStreamAroundAsync(getSpawnPosition(worldIndex))
		end)
		if player.Parent and profile.world == worldIndex then
			if not placeCharacter(player, worldIndex) then
				-- personnage en cours de respawn : on retente une fois
				task.wait(0.5)
				placeCharacter(player, worldIndex)
			end
		end
	end)

	-- 3 s de grâce : on ignore les pads/portails juste après une arrivée
	arrivalGrace[player] = os.clock() + 3

	WorldManager.Events.WorldChanged:Fire(player, worldIndex)
	DataManager.notify(player)
	return true
end

--- Vérifie et débloque les mondes accessibles.
function WorldManager.checkUnlocks(player: Player, announce: boolean?)
	local profile = DataManager.getProfile(player)
	if not profile then
		return
	end
	for index = profile.maxWorld + 1, #GameConfig.Worlds do
		local world = GameConfig.Worlds[index]
		local hasPower = profile.bestPower >= world.UnlockPower or profile.power >= world.UnlockPower
		local hasRebirth = (profile.rebirths or 0) >= world.UnlockRebirth
		if hasPower and hasRebirth then
			profile.maxWorld = index
			if announce then
				Net.event("Notify"):FireClient(
					player,
					string.format("%s %s débloqué ! (%s de puissance)", world.Emoji, world.Name, string.format("%.0f", world.UnlockPower)),
					"8affc1",
					"🌍"
				)
				Net.event("PlaySound"):FireClient(player, "unlock", 0.7)
			end
			WorldManager.Events.WorldUnlocked:Fire(player, index)
		else
			break
		end
	end
end

-- ============================================================
-- PORTAILS
-- ============================================================
local function onPortalTouched(player: Player, worldIndex: number?)
	if not DataManager.isLoaded(player) then
		return
	end
	local now = os.clock()
	if portalDebounce[player] and now - portalDebounce[player] < 2 then
		return
	end
	if arrivalGrace[player] and now < arrivalGrace[player] then
		return
	end
	portalDebounce[player] = now

	if worldIndex and worldIndex > 0 then
		WorldManager.travel(player, worldIndex)
	else
		WorldManager.travel(player, 0)
	end
end

local function connectTouch(part: BasePart, callback: (Player) -> ())
	part.Touched:Connect(function(hit)
		local character = hit:FindFirstAncestorOfClass("Model")
		if not character then
			return
		end
		local player = Players:GetPlayerFromCharacter(character)
		if player then
			callback(player)
		end
	end)
end

local function setupPortals()
	local lobby = Workspace:FindFirstChild("Lobby")
	if not lobby then
		return
	end
	local portals = lobby:FindFirstChild("Portals")
	if not portals then
		return
	end
	for _, portalModel in ipairs(portals:GetChildren()) do
		local worldIndex = portalModel:GetAttribute("WorldIndex")
		if type(worldIndex) == "number" then
			for _, descendant in ipairs(portalModel:GetDescendants()) do
				if descendant:IsA("BasePart") and descendant.Name == "Pad" then
					connectTouch(descendant, function(player)
						onPortalTouched(player, worldIndex)
					end)
				end
			end
		end
	end
end

local function setupReturnPads()
	local worldsFolder = Workspace:FindFirstChild("Worlds")
	if not worldsFolder then
		return
	end
	for _, worldFolder in ipairs(worldsFolder:GetChildren()) do
		local returnPad = worldFolder:FindFirstChild("ReturnPad")
		if returnPad and returnPad:IsA("BasePart") then
			connectTouch(returnPad, function(player)
				onPortalTouched(player, 0)
			end)
		end
		local returnPortal = worldFolder:FindFirstChild("ReturnPortal")
		if returnPortal then
			local field = returnPortal:FindFirstChild("Field")
			if field and field:IsA("BasePart") then
				connectTouch(field, function(player)
					onPortalTouched(player, 0)
				end)
			end
		end
	end
end

-- ============================================================
-- CYCLE DE VIE
-- ============================================================
local function onCharacterAdded(player: Player, character: Model)
	local profile = DataManager.waitForProfile(player, 15)
	if not profile then
		return
	end
	character:WaitForChild("HumanoidRootPart", 10)
	task.wait(0.2)
	if character.Parent and player.Parent then
		placeCharacter(player, profile.world)
		if not firstJoinDone[player] then
			firstJoinDone[player] = true
			local world = GameConfig.Worlds[profile.world]
			if world then
				Net.event("Notify"):FireClient(
					player,
					string.format("Bienvenue dans %s %s ! Clique sur les objets pour les absorber.", world.Emoji, world.Name),
					"8affc1",
					"👋"
				)
			end
		end
	end
end

local function onPlayerAdded(player: Player)
	local profile = DataManager.waitForProfile(player, 20)
	if not profile then
		return
	end
	WorldManager.checkUnlocks(player, false)
	-- Si le joueur était dans le lobby, on l'envoie dans son monde
	if profile.world <= 0 then
		profile.world = math.max(1, profile.maxWorld)
		DataManager.notify(player)
	end
	updateOccupancy(profile, 1, profile.world)

	player.CharacterAdded:Connect(function(character)
		task.spawn(onCharacterAdded, player, character)
	end)
	if player.Character then
		task.spawn(onCharacterAdded, player, player.Character)
	end
end

function WorldManager.start()
	setupPortals()
	setupReturnPads()

	Net.event("TravelWorld").OnServerEvent:Connect(function(player, worldIndex)
		if type(worldIndex) ~= "number" then
			return
		end
		worldIndex = math.floor(worldIndex)
		if worldIndex < 0 or worldIndex > #GameConfig.Worlds then
			return
		end
		WorldManager.travel(player, worldIndex)
	end)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(onPlayerAdded, player)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(onPlayerAdded, player)
	end

	Players.PlayerRemoving:Connect(function(player)
		local profile = DataManager.getProfile(player)
		if profile then
			updateOccupancy(profile, -1, profile.world)
		end
		lastTravel[player] = nil
		portalDebounce[player] = nil
		arrivalGrace[player] = nil
		firstJoinDone[player] = nil
	end)

	-- Vérification périodique des déblocages + occupation
	task.spawn(function()
		while true do
			task.wait(2)
			recomputeOccupancy()
			for _, player in ipairs(Players:GetPlayers()) do
				if DataManager.isLoaded(player) then
					WorldManager.checkUnlocks(player, true)
				end
			end
		end
	end)

	print("[WorldManager] Démarré")
end

return WorldManager
