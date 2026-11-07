--!strict
--[[
	CollectSystem  |  ServerScriptService.Systems.CollectSystem
	------------------------------------------------------------------
	Gère la mécanique principale : ABSORBER DES OBJETS.

	  • Fait apparaître les objets des 6 mondes (pool dynamique, limité
	    pour les mobiles : 40 objets si le monde est vide, 90 sinon).
	  • Traite les clics validés côté serveur (distance + existence +
	    rate limit) → jamais de gain de puissance côté client.
	  • Gère l'absorption automatique (upgrade / game pass).
	  • Gère l'aspirateur de zone (VACUUM) avec cooldown serveur.
	  • Déclenche les effets visuels/sonores chez le bon joueur.
]]

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local Formulas = require(Modules:WaitForChild("Formulas"))
local Net = require(Modules:WaitForChild("Net"))
local Signal = require(Modules:WaitForChild("Signal"))

local DataManager = require(script.Parent.DataManager)
local WorldFactory = require(script.Parent.WorldFactory)

local CollectSystem = {}

CollectSystem.Events = {
	Collected = Signal.new(), -- (player, objectId, power, golden)
	VacuumUsed = Signal.new(), -- (player, count, totalPower)
}

-- Réglages modifiables par EventManager
CollectSystem.goldenChance = 0.05
CollectSystem.spawnMultiplier = 1

-- ============================================================
-- ÉTAT INTERNE
-- ============================================================
local registry: { [BasePart]: any } = {}
local worldCounts: { [number]: number } = {}
local occupiedCells: { [number]: { [string]: boolean } } = {}
local vacuumCooldown: { [Player]: number } = {}
local requestBudget: { [Player]: { tokens: number, last: number } } = {}

local CELL_SIZE = 42

local function getCollectiblesFolder(): Folder
	local folder = Workspace:FindFirstChild("Collectibles")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Collectibles"
		folder.Parent = Workspace
	end
	return folder :: Folder
end

local function worldFolder(index: number): Folder?
	local info = WorldFactory.getWorldInfo(index)
	if info and info.Folder then
		return info.Folder
	end
	return nil
end

-- ============================================================
-- RATE LIMITING (anti-flood / anti-exploit)
-- ============================================================
local function getBudget(player: Player)
	local budget = requestBudget[player]
	if not budget then
		budget = { tokens = GameConfig.Collect.MaxRequestsPerSecond, last = os.clock() }
		requestBudget[player] = budget
	end
	local now = os.clock()
	local elapsed = now - budget.last
	budget.last = now
	budget.tokens = math.min(GameConfig.Collect.MaxRequestsPerSecond, budget.tokens + elapsed * GameConfig.Collect.MaxRequestsPerSecond)
	return budget
end

local function consumeToken(player: Player): boolean
	local budget = getBudget(player)
	if budget.tokens < 1 then
		return false
	end
	budget.tokens = budget.tokens - 1
	return true
end

-- ============================================================
-- SPAWN DES OBJETS
-- ============================================================
local function cellKey(position: Vector3): string
	return string.format("%d_%d", math.floor(position.X / CELL_SIZE), math.floor(position.Z / CELL_SIZE))
end

local function findFreePosition(worldIndex: number): Vector3?
	local info = WorldFactory.getWorldInfo(worldIndex)
	if not info then
		return nil
	end
	local area = info.SpawnArea
	local cells = occupiedCells[worldIndex]
	if not cells then
		cells = {}
		occupiedCells[worldIndex] = cells
	end

	for _ = 1, 24 do
		local x = math.random() * (area.MaxX - area.MinX) + area.MinX
		local z = math.random() * (area.MaxZ - area.MinZ) + area.MinZ
		local y = math.random() * (area.MaxY - area.MinY) + area.MinY
		local position = Vector3.new(x, y, z)
		-- évite le centre (zone du piédestal d'œuf) et les abords du spawn
		local distanceToEgg = (Vector3.new(x, 0, z) - Vector3.new(info.Center.X, 0, info.Center.Z - 60)).Magnitude
		local distanceToSpawn = (Vector3.new(x, 0, z) - Vector3.new(info.Center.X, 0, info.Center.Z + 280)).Magnitude
		if distanceToEgg > 30 and distanceToSpawn > 60 then
			local key = cellKey(position)
			if not cells[key] then
				cells[key] = true
				return position
			end
		end
	end
	return nil
end

local function chooseObjectId(worldIndex: number): string
	local world = GameConfig.Worlds[worldIndex]
	local weights = world.ObjectWeights
	local total = 0
	for _, weight in pairs(weights) do
		total = total + weight
	end
	local roll = math.random() * total
	local accumulator = 0
	local fallback = world.Objects[1]
	for objectId, weight in pairs(weights) do
		accumulator = accumulator + weight
		if roll <= accumulator then
			return objectId
		end
	end
	return fallback
end

local function despawn(part: BasePart, notifyRespawn: boolean)
	local data = registry[part]
	if not data then
		return
	end
	registry[part] = nil

	local worldIndex = data.worldIndex
	worldCounts[worldIndex] = math.max(0, (worldCounts[worldIndex] or 1) - 1)
	local cells = occupiedCells[worldIndex]
	if cells then
		cells[cellKey(data.position)] = nil
	end
	part:Destroy()

	if notifyRespawn then
		task.delay(GameConfig.Collect.RespawnTime, function()
			CollectSystem.spawnOne(worldIndex)
		end)
	end
end

--- Crée un objet à absorber dans un monde donné.
function CollectSystem.spawnOne(worldIndex: number, forcedObjectId: string?, forcedPosition: Vector3?)
	local world = GameConfig.Worlds[worldIndex]
	if not world then
		return nil
	end
	local target = CollectSystem.getWorldTarget(worldIndex)
	if (worldCounts[worldIndex] or 0) >= target then
		return nil
	end

	local objectId = forcedObjectId or chooseObjectId(worldIndex)
	local objectData = Formulas.getObjectData(objectId)
	if not objectData then
		return nil
	end
	local position = forcedPosition or findFreePosition(worldIndex)
	if not position then
		return nil
	end

	local golden = math.random() < CollectSystem.goldenChance

	local part = Instance.new("Part")
	part.Name = objectId
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Color = golden and Color3.fromRGB(255, 215, 0) or objectData.Color
	part.Material = golden and Enum.Material.Neon or objectData.Material
	part.Size = objectData.Size
	if objectData.Shape == "Ball" then
		part.Shape = Enum.PartType.Ball
	elseif objectData.Shape == "Cylinder" then
		part.Shape = Enum.PartType.Cylinder
		part.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	else
		part.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(math.random(0, 359)), 0)
	end
	if part.Shape == Enum.PartType.Ball or part.Shape == Enum.PartType.Block then
		part.CFrame = CFrame.new(position) * CFrame.Angles(0, math.rad(math.random(0, 359)), 0)
	end
	part.Position = position

	-- Petit marqueur visuel pour les objets dorés
	if golden then
		local light = Instance.new("PointLight")
		light.Brightness = 2
		light.Range = 22
		light.Color = Color3.fromRGB(255, 215, 0)
		light.Parent = part
	end

	local power = Formulas.objectPower(worldIndex, objectId, golden)
	part:SetAttribute("ObjectId", objectId)
	part:SetAttribute("WorldIndex", worldIndex)
	part:SetAttribute("Power", power)
	part:SetAttribute("Golden", golden)

	registry[part] = {
		worldIndex = worldIndex,
		objectId = objectId,
		power = power,
		golden = golden,
		position = position,
	}
	worldCounts[worldIndex] = (worldCounts[worldIndex] or 0) + 1
	part.Parent = getCollectiblesFolder()
	return part
end

--- Nombre d'objets visés pour un monde (optimisation mobile)
function CollectSystem.getWorldTarget(worldIndex: number): number
	local hasPlayers = CollectSystem.worldOccupancy and (CollectSystem.worldOccupancy[worldIndex] or 0) > 0
	local base = hasPlayers and GameConfig.Collect.MaxActivePerWorld or 34
	return math.floor(base * CollectSystem.spawnMultiplier)
end

--- Remplit un monde jusqu'à sa cible
function CollectSystem.fillWorld(worldIndex: number)
	local target = CollectSystem.getWorldTarget(worldIndex)
	local created = 0
	for _ = 1, target do
		if (worldCounts[worldIndex] or 0) >= target then
			break
		end
		if CollectSystem.spawnOne(worldIndex) then
			created = created + 1
		else
			break
		end
	end
	return created
end

function CollectSystem.counts()
	return worldCounts
end

-- ============================================================
-- ABSORPTION
-- ============================================================
local function awardPower(player: Player, worldIndex: number, objectId: string, basePower: number, golden: boolean, position: Vector3, silent: boolean?)
	local profile = DataManager.getProfile(player)
	if not profile then
		return 0
	end

	local multiplier = DataManager.getPowerMultiplier(player)
	local power = math.floor(basePower * multiplier)
	if power < 1 then
		power = 1
	end
	DataManager.addPower(player, power, objectId)

	-- Pièces
	local coinMultiplier = Formulas.totalCoinMultiplier(profile, profile.gamePasses)
	local coins = math.max(1, math.floor(power * coinMultiplier))
	DataManager.addCoins(player, coins)

	DataManager.addStat(player, "collected", 1)

	-- Retour visuel / sonore au joueur (pas un remote par objet en auto-collect :
	-- collectRadius envoie un seul effet groupé à la fin)
	if not silent then
		local color = golden and "ffd700" or "8affc1"
		Net.event("EffectBurst"):FireClient(player, position, color, power)
		Net.event("PlaySound"):FireClient(player, golden and "golden" or "absorb", 0.6)
	end

	CollectSystem.Events.Collected:Fire(player, objectId, power, golden)
	DataManager.notify(player)
	return power
end

--- Tente d'absorber un objet précis (clic client validé).
function CollectSystem.tryCollect(player: Player, part: any): boolean
	if typeof(part) ~= "Instance" or not part:IsA("BasePart") then
		return false
	end
	local data = registry[part]
	if not data then
		return false
	end
	local profile = DataManager.getProfile(player)
	if not profile then
		return false
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return false
	end

	-- ANTI-CHEAT 1 : portée
	local distance = ((root :: BasePart).Position - data.position).Magnitude
	if distance > GameConfig.Collect.ClickRadius then
		return false
	end

	-- ANTI-CHEAT 2 : rate limit
	if not consumeToken(player) then
		return false
	end

	-- ANTI-CHEAT 3 : le joueur doit être dans le bon monde
	if profile.world ~= data.worldIndex then
		return false
	end

	despawn(part, true)
	awardPower(player, data.worldIndex, data.objectId, data.power, data.golden, data.position)
	return true
end

--- Absorbe tous les objets dans un rayon (auto-collect / vacuum).
function CollectSystem.collectRadius(player: Player, radius: number, silent: boolean?): (number, number)
	local profile = DataManager.getProfile(player)
	if not profile then
		return 0, 0
	end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root then
		return 0, 0
	end
	local origin = (root :: BasePart).Position
	local worldIndex = profile.world

	local toCollect = {}
	for part, data in pairs(registry) do
		if data.worldIndex == worldIndex then
			if (data.position - origin).Magnitude <= radius then
				table.insert(toCollect, part)
			end
		end
	end

	if #toCollect == 0 then
		return 0, 0
	end

	local totalPower = 0
	local collectedCount = 0
	for _, part in ipairs(toCollect) do
		local data = registry[part]
		if data then
			local basePower = data.power
			despawn(part, true)
			totalPower = totalPower + awardPower(player, data.worldIndex, data.objectId, basePower, data.golden, data.position, silent)
			collectedCount = collectedCount + 1
		end
	end

	if not silent and collectedCount > 0 then
		Net.event("EffectBurst"):FireClient(player, origin, "8affc1", totalPower)
		Net.event("PlaySound"):FireClient(player, "vacuum", 0.8)
		Net.event("CameraShake"):FireClient(player, math.min(0.7, 0.15 + collectedCount * 0.01))
	end
	return collectedCount, totalPower
end

-- ============================================================
-- REMOTES
-- ============================================================
local function setupRemotes()
	Net.event("CollectRequest").OnServerEvent:Connect(function(player, part)
		if not DataManager.isLoaded(player) then
			return
		end
		CollectSystem.tryCollect(player, part)
	end)

	Net.event("VacuumRequest").OnServerEvent:Connect(function(player)
		local profile = DataManager.getProfile(player)
		if not profile then
			return
		end
		local now = os.clock()
		local last = vacuumCooldown[player] or 0
		local cooldown = Formulas.vacuumCooldown(profile)
		if now - last < cooldown then
			return
		end
		vacuumCooldown[player] = now

		local radius = Formulas.vacuumRadius(profile)
		local count, totalPower = CollectSystem.collectRadius(player, radius, false)
		if count > 0 then
			DataManager.addStat(player, "vacuums", 1)
			CollectSystem.Events.VacuumUsed:Fire(player, count, totalPower)
			DataManager.notify(player)
		end
	end)
end

-- ============================================================
-- ABSORPTION AUTOMATIQUE
-- ============================================================
local function autoCollectLoop()
	while true do
		task.wait(0.25)
		for _, player in ipairs(Players:GetPlayers()) do
			local profile = DataManager.getProfile(player)
			if profile then
				local hasGamePass = profile.gamePasses and profile.gamePasses.AutoCollect
				local radius = Formulas.autoCollectRadius(profile, hasGamePass)
				if radius > 0 then
					local nextTick = player:GetAttribute("AutoCollectNext")
					if not nextTick or os.clock() >= nextTick then
						local interval = Formulas.autoCollectInterval(profile)
						player:SetAttribute("AutoCollectNext", os.clock() + interval)
						local count = CollectSystem.collectRadius(player, radius, true)
						if count > 0 then
							Net.event("PlaySound"):FireClient(player, "auto", 0.25)
						end
					end
				end
			end
		end
	end
end

-- ============================================================
-- MAINTENANCE (remplissage / nettoyage)
-- ============================================================
local function maintenanceLoop()
	while true do
		task.wait(4)
		for index = 1, #GameConfig.Worlds do
			local target = CollectSystem.getWorldTarget(index)
			local current = worldCounts[index] or 0
			if current < target then
				for _ = 1, math.min(12, target - current) do
					if not CollectSystem.spawnOne(index) then
						break
					end
				end
			elseif current > target + 10 then
				-- trop d'objets (le monde s'est vidé) : on en retire
				local removed = 0
				for part in pairs(registry) do
					if registry[part].worldIndex == index then
						despawn(part, false)
						removed = removed + 1
						if removed >= 10 then
							break
						end
					end
				end
			end
		end
	end
end

-- ============================================================
-- CYCLE DE VIE
-- ============================================================
function CollectSystem.start()
	setupRemotes()

	-- Occupation des mondes (pour l'optimisation mobile)
	CollectSystem.worldOccupancy = {}

	Players.PlayerRemoving:Connect(function(player)
		vacuumCooldown[player] = nil
		requestBudget[player] = nil
	end)

	-- Remplissage initial
	for index = 1, #GameConfig.Worlds do
		task.spawn(function()
			CollectSystem.fillWorld(index)
		end)
	end

	task.spawn(autoCollectLoop)
	task.spawn(maintenanceLoop)

	-- Nettoyage du registry des objets détruits par autre chose
	RunService.Heartbeat:Connect(function()
		for part in pairs(registry) do
			if not part.Parent then
				local data = registry[part]
				registry[part] = nil
				if data then
					worldCounts[data.worldIndex] = math.max(0, (worldCounts[data.worldIndex] or 1) - 1)
				end
			end
		end
	end)

	print("[CollectSystem] Démarré")
end

return CollectSystem
