--!strict
--[[
	WorldFactory  |  ServerScriptService.Systems.WorldFactory
	------------------------------------------------------------------
	Construit 100% de la map depuis du code (aucune asset externe) :

	  Workspace.Lobby            -> plateforme, spawn, autel de rebirth,
	                                portails des 6 mondes, panneau du jeu,
	                                tableau des scores, piédestal d'œuf
	  Workspace.Worlds.World1..6 -> plateformes thématiques, décor,
	                                portail de retour, piédestal d'œuf

	Avantage : la map est versionnée dans Git, modifiable en 3 lignes,
	et il n'y a aucun asset à importer. Chaque monde expose ses zones
	de spawn d'objets à CollectSystem.
]]

local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))

local WorldFactory = {}

-- ============================================================
-- CONSTANTES DE LAYOUT
-- ============================================================
WorldFactory.LOBBY_CENTER = Vector3.new(0, 0, 0)
WorldFactory.LOBBY_SIZE = 420
WorldFactory.LOBBY_SPAWN = Vector3.new(0, 6, 90)
WorldFactory.WORLD_PLATFORM_SIZE = 700
WorldFactory.WORLD_SPACING = 1500

local worldInfos = {}

-- ============================================================
-- OUTILS DE CONSTRUCTION
-- ============================================================
local function part(parent: Instance, props: { [string]: any }): Part
	local instance = Instance.new("Part")
	instance.Anchored = true
	instance.TopSurface = Enum.SurfaceType.Smooth
	instance.BottomSurface = Enum.SurfaceType.Smooth
	for key, value in pairs(props) do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local function wedge(parent: Instance, props: { [string]: any }): WedgePart
	local instance = Instance.new("WedgePart")
	instance.Anchored = true
	for key, value in pairs(props) do
		instance[key] = value
	end
	instance.Parent = parent
	return instance
end

local function label(parent: Instance, text: string, color: Color3, size: Vector2?): BillboardGui
	local gui = Instance.new("BillboardGui")
	gui.Name = "Label"
	gui.Size = UDim2.fromOffset(size and size.X or 220, size and size.Y or 60)
	gui.StudsOffset = Vector3.new(0, 3, 0)
	gui.AlwaysOnTop = false
	gui.MaxDistance = 900
	gui.Adornee = parent
	gui.Parent = parent

	local textLabel = Instance.new("TextLabel")
	textLabel.BackgroundTransparency = 1
	textLabel.Size = UDim2.fromScale(1, 1)
	textLabel.Font = Enum.Font.FredokaOne
	textLabel.Text = text
	textLabel.TextColor3 = color
	textLabel.TextScaled = true
	textLabel.TextStrokeTransparency = 0.35
	textLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	textLabel.Parent = gui
	return gui
end

local function neon(parent: Instance, props: { [string]: any }): Part
	props.Material = Enum.Material.Neon
	props.CanCollide = false
	return part(parent, props)
end

-- ============================================================
-- LOBBY
-- ============================================================
local function buildLobby(): Folder
	local lobby = Instance.new("Folder")
	lobby.Name = "Lobby"

	-- Sol principal
	local floor = part(lobby, {
		Name = "LobbyFloor",
		Size = Vector3.new(WorldFactory.LOBBY_SIZE, 4, WorldFactory.LOBBY_SIZE),
		Position = Vector3.new(0, -2, 0),
		Color = Color3.fromRGB(120, 200, 255),
		Material = Enum.Material.SmoothPlastic,
	})
	floor:SetAttribute("Permanent", true)

	-- Bordure décorative
	for _, offset in ipairs({
		{ Vector3.new(0, 0, -WorldFactory.LOBBY_SIZE / 2), Vector3.new(WorldFactory.LOBBY_SIZE, 6, 6) },
		{ Vector3.new(0, 0, WorldFactory.LOBBY_SIZE / 2), Vector3.new(WorldFactory.LOBBY_SIZE, 6, 6) },
		{ Vector3.new(-WorldFactory.LOBBY_SIZE / 2, 0, 0), Vector3.new(6, 6, WorldFactory.LOBBY_SIZE) },
		{ Vector3.new(WorldFactory.LOBBY_SIZE / 2, 0, 0), Vector3.new(6, 6, WorldFactory.LOBBY_SIZE) },
	}) do
		neon(lobby, {
			Name = "Border",
			Size = offset[2],
			Position = offset[1] + Vector3.new(0, 2, 0),
			Color = Color3.fromRGB(90, 220, 255),
			Transparency = 0.25,
		})
	end

	-- Spawn officiel
	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "LobbySpawn"
	spawn.Size = Vector3.new(24, 1, 24)
	spawn.Position = WorldFactory.LOBBY_SPAWN - Vector3.new(0, 5, 0)
	spawn.Anchored = true
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.Color = Color3.fromRGB(90, 220, 255)
	spawn.Material = Enum.Material.Neon
	spawn.Transparency = 0.35
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = lobby
	label(spawn, "SPAWN", Color3.fromRGB(255, 255, 255), Vector2.new(150, 40))

	-- Autel de Rebirth
	local altar = Instance.new("Model")
	altar.Name = "RebirthAltar"
	altar.Parent = lobby

	part(altar, {
		Name = "AltarBase",
		Size = Vector3.new(46, 2, 46),
		Position = Vector3.new(0, 1, -30),
		Color = Color3.fromRGB(255, 215, 90),
		Material = Enum.Material.Neon,
	})
	part(altar, {
		Name = "AltarPillar",
		Size = Vector3.new(14, 26, 14),
		Position = Vector3.new(0, 15, -30),
		Color = Color3.fromRGB(255, 240, 180),
		Material = Enum.Material.Marble,
	})
	local orb = neon(altar, {
		Name = "AltarOrb",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(16, 16, 16),
		Position = Vector3.new(0, 34, -30),
		Color = Color3.fromRGB(255, 230, 120),
		Transparency = 0.15,
	})
	orb:SetAttribute("Animated", "float")

	local altarLight = Instance.new("PointLight")
	altarLight.Brightness = 4
	altarLight.Range = 60
	altarLight.Color = Color3.fromRGB(255, 220, 120)
	altarLight.Parent = orb

	label(orb, "⟳ REBIRTH", Color3.fromRGB(255, 235, 150), Vector2.new(320, 80))

	-- Portails des mondes
	local portals = Instance.new("Folder")
	portals.Name = "Portals"
	portals.Parent = lobby

	local firstX = -250
	for index, world in ipairs(GameConfig.Worlds) do
		local portalModel = Instance.new("Model")
		portalModel.Name = "Portal" .. tostring(index)
		portalModel:SetAttribute("WorldIndex", index)
		portalModel.Parent = portals

		local position = Vector3.new(firstX + (index - 1) * 100, 0, -155)

		-- Pad au sol
		local pad = neon(portalModel, {
			Name = "Pad",
			Size = Vector3.new(30, 1, 30),
			Position = position + Vector3.new(0, 1, 0),
			Color = world.FloorColor,
			Transparency = 0.25,
		})
		pad:SetAttribute("PortalPad", index)

		-- Arche
		local archLeft = neon(portalModel, {
			Name = "ArchL",
			Size = Vector3.new(4, 30, 4),
			Position = position + Vector3.new(-13, 15, 0),
			Color = world.SkyColor,
			Transparency = 0.15,
		})
		local archRight = neon(portalModel, {
			Name = "ArchR",
			Size = Vector3.new(4, 30, 4),
			Position = position + Vector3.new(13, 15, 0),
			Color = world.SkyColor,
			Transparency = 0.15,
		})
		local archTop = neon(portalModel, {
			Name = "ArchTop",
			Size = Vector3.new(30, 4, 4),
			Position = position + Vector3.new(0, 30, 0),
			Color = world.SkyColor,
			Transparency = 0.15,
		})

		-- Champ d'énergie
		local field = neon(portalModel, {
			Name = "Field",
			Size = Vector3.new(22, 28, 1),
			Position = position + Vector3.new(0, 16, 0),
			Color = world.SkyColor,
			Transparency = 0.55,
		})
		field:SetAttribute("Animated", "portal")
		field:SetAttribute("WorldIndex", index)

		local fieldLight = Instance.new("PointLight")
		fieldLight.Brightness = 2
		fieldLight.Range = 40
		fieldLight.Color = world.SkyColor
		fieldLight.Parent = field

		label(archTop, "PORTAL " .. tostring(index), Color3.fromRGB(255, 255, 255), Vector2.new(240, 50))
		label(archTop, string.upper(world.Name) .. "  " .. world.Emoji, Color3.fromRGB(255, 255, 255), Vector2.new(360, 60)).StudsOffset = Vector3.new(0, 6, 0)

		archLeft.Name = "ArchL"
		archRight.Name = "ArchR"
	end

	-- Piédestal de l'œuf du noob (gratuit)
	local eggPedestal = Instance.new("Model")
	eggPedestal.Name = "EggPedestal_StarterEgg"
	eggPedestal:SetAttribute("EggId", "StarterEgg")
	eggPedestal.Parent = lobby

	part(eggPedestal, {
		Name = "Base",
		Size = Vector3.new(16, 2, 16),
		Position = Vector3.new(-90, 1, 30),
		Color = Color3.fromRGB(240, 240, 240),
		Material = Enum.Material.Marble,
	})
	local egg = neon(eggPedestal, {
		Name = "Egg",
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(10, 13, 10),
		Position = Vector3.new(-90, 9, 30),
		Color = Color3.fromRGB(255, 255, 255),
		Transparency = 0.1,
	})
	egg:SetAttribute("Animated", "float")
	label(egg, "🥚 ŒUF GRATUIT", Color3.fromRGB(255, 255, 255), Vector2.new(300, 70))

	-- Panneau du jeu
	local sign = part(lobby, {
		Name = "GameSign",
		Size = Vector3.new(150, 40, 3),
		Position = Vector3.new(0, 70, -195),
		Color = Color3.fromRGB(25, 25, 40),
		Material = Enum.Material.SmoothPlastic,
	})
	local surface = Instance.new("SurfaceGui")
	surface.Face = Enum.NormalId.Front
	surface.CanvasSize = Vector2.new(1500, 400)
	surface.Parent = sign

	local title = Instance.new("TextLabel")
	title.Size = UDim2.fromScale(1, 0.62)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.FredokaOne
	title.Text = "NOOB ➜ GOD SIMULATOR"
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 230, 100)
	title.TextStrokeTransparency = 0
	title.TextStrokeColor3 = Color3.fromRGB(255, 60, 180)
	title.Parent = surface

	local subtitle = Instance.new("TextLabel")
	subtitle.Position = UDim2.fromScale(0, 0.62)
	subtitle.Size = UDim2.fromScale(1, 0.32)
	subtitle.BackgroundTransparency = 1
	subtitle.Font = Enum.Font.GothamBold
	subtitle.Text = "Absorbe. Grandis. Deviens un dieu. 👑"
	subtitle.TextScaled = true
	subtitle.TextColor3 = Color3.fromRGB(200, 240, 255)
	subtitle.Parent = surface

	for _, offset in ipairs({ Vector3.new(-70, 20, 0), Vector3.new(70, 20, 0) }) do
		neon(lobby, {
			Name = "SignPillar",
			Size = Vector3.new(6, 50, 6),
			Position = Vector3.new(0, 45, -195) + offset,
			Color = Color3.fromRGB(120, 80, 255),
			Transparency = 0.2,
		})
	end

	-- Tableau des scores du serveur (SurfaceGui rempli par LeaderboardManager)
	local board = part(lobby, {
		Name = "ServerBoard",
		Size = Vector3.new(70, 48, 3),
		Position = Vector3.new(140, 46, 40),
		Color = Color3.fromRGB(20, 22, 34),
		Material = Enum.Material.SmoothPlastic,
	})
	board.CFrame = CFrame.new(board.Position, Vector3.new(140, 46, 200))
	local boardGui = Instance.new("SurfaceGui")
	boardGui.Name = "ServerLeaderboard"
	boardGui.Face = Enum.NormalId.Front
	boardGui.CanvasSize = Vector2.new(700, 480)
	boardGui.Parent = board

	local boardTitle = Instance.new("TextLabel")
	boardTitle.Name = "Title"
	boardTitle.Size = UDim2.new(1, 0, 0, 60)
	boardTitle.BackgroundTransparency = 1
	boardTitle.Font = Enum.Font.FredokaOne
	boardTitle.Text = "🏆 TOP DU SERVEUR"
	boardTitle.TextScaled = true
	boardTitle.TextColor3 = Color3.fromRGB(255, 220, 90)
	boardTitle.Parent = boardGui

	local boardList = Instance.new("Frame")
	boardList.Name = "List"
	boardList.Position = UDim2.new(0, 10, 0, 70)
	boardList.Size = UDim2.new(1, -20, 1, -80)
	boardList.BackgroundTransparency = 1
	boardList.Parent = boardGui
	local listLayout = Instance.new("UIListLayout")
	listLayout.Padding = UDim.new(0, 4)
	listLayout.SortOrder = Enum.SortOrder.LayoutOrder
	listLayout.Parent = boardList

	-- Décor du lobby : petits noobs en statue
	for index = 1, 10 do
		local angle = (index / 10) * math.pi * 2
		local radius = 190
		local position = Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius - 20)
		local statue = part(lobby, {
			Name = "Statue",
			Size = Vector3.new(6, 10, 6),
			Position = position + Vector3.new(0, 5, 0),
			Color = Color3.fromRGB(255, 214, 80),
			Material = Enum.Material.SmoothPlastic,
		})
		local head = part(lobby, {
			Name = "StatueHead",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(6, 6, 6),
			Position = position + Vector3.new(0, 13, 0),
			Color = Color3.fromRGB(255, 235, 150),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
		})
		statue.CanCollide = false
		head.CanCollide = false
	end

	lobby.Parent = Workspace
	return lobby
end

-- ============================================================
-- DÉCOR PAR MONDE
-- ============================================================
local decorBuilders = {}

decorBuilders[1] = function(worldFolder, center: Vector3, world)
	-- Palmiers et collines
	local rng = Random.new(1337)
	for index = 1, 26 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(180, 320)
		local position = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local height = rng:NextNumber(14, 26)
		part(worldFolder, {
			Name = "PalmTrunk",
			Size = Vector3.new(2.5, height, 2.5),
			Position = position + Vector3.new(0, height / 2, 0),
			Color = Color3.fromRGB(140, 100, 60),
			Material = Enum.Material.Wood,
			CanCollide = false,
			CastShadow = false,
		})
		for leaf = 1, 5 do
			local leafAngle = (leaf / 5) * math.pi * 2
			local offset = Vector3.new(math.cos(leafAngle) * 6, height - 1, math.sin(leafAngle) * 6)
			local leafPart = part(worldFolder, {
				Name = "PalmLeaf",
				Size = Vector3.new(11, 0.6, 3.5),
				Position = position + offset,
				Color = Color3.fromRGB(70, 190, 90),
				Material = Enum.Material.Grass,
				CanCollide = false,
				CastShadow = false,
			})
			leafPart.CFrame = CFrame.new(leafPart.Position, leafPart.Position + Vector3.new(math.cos(leafAngle), -0.35, math.sin(leafAngle)))
		end
	end
	-- Collines
	for index = 1, 8 do
		local angle = (index / 8) * math.pi * 2
		local radius = 300
		part(worldFolder, {
			Name = "Hill",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(60, 34, 60),
			Position = center + Vector3.new(math.cos(angle) * radius, 4, math.sin(angle) * radius),
			Color = world.DecorColor,
			Material = Enum.Material.Grass,
			CanCollide = true,
			CastShadow = false,
		})
	end
end

decorBuilders[2] = function(worldFolder, center: Vector3, world)
	local rng = Random.new(4242)
	for index = 1, 18 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(200, 320)
		local position = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local height = rng:NextNumber(16, 30)
		part(worldFolder, {
			Name = "CandyCane",
			Size = Vector3.new(3, height, 3),
			Position = position + Vector3.new(0, height / 2, 0),
			Color = Color3.fromRGB(255, 255, 255),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			CastShadow = false,
		})
		for stripe = 1, math.floor(height / 4) do
			part(worldFolder, {
				Name = "Stripe",
				Size = Vector3.new(3.2, 1.4, 3.2),
				Position = position + Vector3.new(0, stripe * 4, 0),
				Color = Color3.fromRGB(255, 70, 130),
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				CastShadow = false,
			})
		end
	end
	-- Gumdrop hills
	for index = 1, 14 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(160, 320)
		local colors = { Color3.fromRGB(255, 120, 180), Color3.fromRGB(150, 220, 255), Color3.fromRGB(255, 230, 120), Color3.fromRGB(180, 255, 180) }
		part(worldFolder, {
			Name = "Gumdrop",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(28, 22, 28),
			Position = center + Vector3.new(math.cos(angle) * radius, 8, math.sin(angle) * radius),
			Color = colors[rng:NextInteger(1, #colors)],
			Material = Enum.Material.SmoothPlastic,
			CastShadow = false,
		})
	end
end

decorBuilders[3] = function(worldFolder, center: Vector3, world)
	local rng = Random.new(9999)
	-- Pools de lave
	for index = 1, 10 do
		local angle = (index / 10) * math.pi * 2
		local radius = rng:NextNumber(190, 330)
		neon(worldFolder, {
			Name = "LavaPool",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(1, 60, 60),
			Position = center + Vector3.new(math.cos(angle) * radius, 0.6, math.sin(angle) * radius),
			Color = Color3.fromRGB(255, 90, 20),
			Transparency = 0.15,
			Orientation = Vector3.new(0, 0, 90),
		})
	end
	-- Volcans
	for index = 1, 7 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(230, 330)
		local position = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		local height = rng:NextNumber(24, 46)
		part(worldFolder, {
			Name = "VolcanoCone",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height, 50, 50),
			Position = position + Vector3.new(0, height / 2, 0),
			Color = Color3.fromRGB(70, 35, 30),
			Material = Enum.Material.Basalt,
			Orientation = Vector3.new(0, 0, 90),
			CastShadow = false,
		})
		neon(worldFolder, {
			Name = "LavaSpout",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(14, 14, 14),
			Position = position + Vector3.new(0, height + 6, 0),
			Color = Color3.fromRGB(255, 120, 20),
		})
	end
	-- Rochers
	for index = 1, 20 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(120, 340)
		local size = rng:NextNumber(5, 16)
		part(worldFolder, {
			Name = "Rock",
			Size = Vector3.new(size, size * 0.8, size),
			Position = center + Vector3.new(math.cos(angle) * radius, size * 0.4, math.sin(angle) * radius),
			Color = Color3.fromRGB(60, 50, 50),
			Material = Enum.Material.Rock,
			CastShadow = false,
		})
	end
end

decorBuilders[4] = function(worldFolder, center: Vector3, world)
	local rng = Random.new(777)
	-- Astéroïdes flottants
	for index = 1, 24 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(200, 340)
		local height = rng:NextNumber(20, 90)
		local size = rng:NextNumber(6, 22)
		part(worldFolder, {
			Name = "FloatingAsteroid",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(size, size, size),
			Position = center + Vector3.new(math.cos(angle) * radius, height, math.sin(angle) * radius),
			Color = Color3.fromRGB(90, 90, 105),
			Material = Enum.Material.Rock,
			CanCollide = false,
			CastShadow = false,
		})
	end
	-- Planètes lointaines
	for index = 1, 4 do
		local angle = (index / 4) * math.pi * 2
		part(worldFolder, {
			Name = "FarPlanet",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(120, 120, 120),
			Position = center + Vector3.new(math.cos(angle) * 520, 220, math.sin(angle) * 520),
			Color = Color3.fromRGB(80 + index * 30, 100, 220),
			Material = Enum.Material.Neon,
			CanCollide = false,
			CastShadow = false,
		})
	end
	-- Étoiles au sol
	for index = 1, 30 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(80, 330)
		neon(worldFolder, {
			Name = "Star",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(2, 2, 2),
			Position = center + Vector3.new(math.cos(angle) * radius, rng:NextNumber(2, 40), math.sin(angle) * radius),
			Color = Color3.fromRGB(255, 255, 200),
		})
	end
end

decorBuilders[5] = function(worldFolder, center: Vector3, world)
	local rng = Random.new(555)
	for index = 1, 40 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(90, 340)
		local size = rng:NextNumber(4, 20)
		local position = center + Vector3.new(math.cos(angle) * radius, rng:NextNumber(4, 120), math.sin(angle) * radius)
		local cube = neon(worldFolder, {
			Name = "GlitchCube",
			Size = Vector3.new(size, size, size),
			Position = position,
			Color = Color3.fromRGB(rng:NextInteger(0, 255), rng:NextInteger(0, 255), rng:NextInteger(0, 255)),
			Transparency = rng:NextNumber(0, 0.4),
			Orientation = Vector3.new(rng:NextNumber(0, 180), rng:NextNumber(0, 180), rng:NextNumber(0, 180)),
		})
		cube:SetAttribute("Animated", "spin")
	end
	-- Faille verticale
	neon(worldFolder, {
		Name = "Rift",
		Size = Vector3.new(6, 220, 90),
		Position = center + Vector3.new(0, 110, -300),
		Color = Color3.fromRGB(255, 0, 150),
		Transparency = 0.35,
	})
end

decorBuilders[6] = function(worldFolder, center: Vector3, world)
	local rng = Random.new(2025)
	-- Colonnes de marbre
	for index = 1, 20 do
		local angle = (index / 20) * math.pi * 2
		local radius = rng:NextNumber(220, 330)
		local height = rng:NextNumber(40, 80)
		local position = center + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius)
		part(worldFolder, {
			Name = "Pillar",
			Size = Vector3.new(10, height, 10),
			Position = position + Vector3.new(0, height / 2, 0),
			Color = world.FloorColor,
			Material = Enum.Material.Marble,
			CastShadow = false,
		})
		part(worldFolder, {
			Name = "PillarCap",
			Size = Vector3.new(14, 2, 14),
			Position = position + Vector3.new(0, height, 0),
			Color = Color3.fromRGB(255, 225, 140),
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
	end
	-- Nuages dorés
	for index = 1, 16 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(160, 340)
		neon(worldFolder, {
			Name = "GoldenCloud",
			Size = Vector3.new(rng:NextNumber(16, 34), 3, rng:NextNumber(16, 34)),
			Position = center + Vector3.new(math.cos(angle) * radius, rng:NextNumber(30, 70), math.sin(angle) * radius),
			Color = Color3.fromRGB(255, 235, 160),
			Transparency = 0.25,
		})
	end
end

-- ============================================================
-- CONSTRUCTION D'UN MONDE
-- ============================================================
local function buildWorld(index: number): any
	local world = GameConfig.Worlds[index]
	local center = Vector3.new(0, 0, index * WorldFactory.WORLD_SPACING)
	local size = WorldFactory.WORLD_PLATFORM_SIZE

	local folder = Instance.new("Folder")
	folder.Name = "World" .. tostring(index)

	-- Plateforme
	local platform = part(folder, {
		Name = "Platform",
		Size = Vector3.new(size, 4, size),
		Position = center + Vector3.new(0, -2, 0),
		Color = world.FloorColor,
		Material = world.FloorMaterial,
	})
	platform:SetAttribute("Permanent", true)
	platform:SetAttribute("WorldIndex", index)

	-- Bordure lumineuse + murs invisibles (anti-chute)
	neon(folder, {
		Name = "Rim",
		Size = Vector3.new(size + 8, 1, size + 8),
		Position = center + Vector3.new(0, 0.2, 0),
		Color = world.DecorColor,
		Transparency = 0.6,
	})

	local wallHeight = 90
	for _, offset in ipairs({
		{ Vector3.new(0, wallHeight / 2, -size / 2), Vector3.new(size, wallHeight, 2) },
		{ Vector3.new(0, wallHeight / 2, size / 2), Vector3.new(size, wallHeight, 2) },
		{ Vector3.new(-size / 2, wallHeight / 2, 0), Vector3.new(2, wallHeight, size) },
		{ Vector3.new(size / 2, wallHeight / 2, 0), Vector3.new(2, wallHeight, size) },
	}) do
		part(folder, {
			Name = "InvisibleWall",
			Size = offset[2],
			Position = center + offset[1],
			Transparency = 1,
			CanCollide = true,
			CastShadow = false,
			Material = Enum.Material.SmoothPlastic,
		})
	end

	-- Zone d'arrivée
	local spawnPosition = center + Vector3.new(0, 6, size / 2 - 70)

	-- Portail de retour : VOLONTAIREMENT décalé de 50 studs du spawn,
	-- sinon le joueur réapparaît dessus et retourne au lobby en boucle.
	local returnPosition = center + Vector3.new(0, 0, size / 2 - 18)
	local returnPad = neon(folder, {
		Name = "ReturnPad",
		Size = Vector3.new(36, 1, 36),
		Position = returnPosition + Vector3.new(0, 0.5, 0),
		Color = Color3.fromRGB(255, 120, 190),
		Transparency = 0.2,
	})
	returnPad:SetAttribute("ReturnPad", true)
	label(returnPad, "← LOBBY", Color3.fromRGB(255, 255, 255), Vector2.new(240, 60))

	local returnModel = Instance.new("Model")
	returnModel.Name = "ReturnPortal"
	returnModel.Parent = folder
	local returnField = neon(returnModel, {
		Name = "Field",
		Size = Vector3.new(20, 26, 1),
		Position = returnPosition + Vector3.new(0, 13, 22),
		Color = Color3.fromRGB(255, 120, 190),
		Transparency = 0.5,
	})
	returnField:SetAttribute("Animated", "portal")
	returnField:SetAttribute("ReturnPortal", true)
	label(returnField, "RETOUR AU LOBBY", Color3.fromRGB(255, 255, 255), Vector2.new(280, 60))

	-- Piédestal de l'œuf du monde
	local eggId = world.Egg
	if eggId and GameConfig.Eggs[eggId] then
		local eggModel = Instance.new("Model")
		eggModel.Name = "EggPedestal_" .. eggId
		eggModel:SetAttribute("EggId", eggId)
		eggModel.Parent = folder

		local eggPosition = center + Vector3.new(0, 0, -60)
		part(eggModel, {
			Name = "Base",
			Size = Vector3.new(20, 2, 20),
			Position = eggPosition + Vector3.new(0, 1, 0),
			Color = Color3.fromRGB(255, 255, 255),
			Material = Enum.Material.Marble,
		})
		local eggPart = neon(eggModel, {
			Name = "Egg",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(11, 14, 11),
			Position = eggPosition + Vector3.new(0, 10, 0),
			Color = GameConfig.Eggs[eggId].Color,
			Transparency = 0.1,
		})
		eggPart:SetAttribute("Animated", "float")

		local eggLight = Instance.new("PointLight")
		eggLight.Brightness = 3
		eggLight.Range = 40
		eggLight.Color = GameConfig.Eggs[eggId].Color
		eggLight.Parent = eggPart

		label(eggPart, GameConfig.Eggs[eggId].Emoji .. " " .. string.upper(GameConfig.Eggs[eggId].Name), Color3.fromRGB(255, 255, 255), Vector2.new(340, 70))
	end

	-- Décor spécifique au monde
	local decorBuilder = decorBuilders[index]
	if decorBuilder then
		local ok, err = pcall(decorBuilder, folder, center, world)
		if not ok then
			warn("[WorldFactory] décor du monde " .. index .. " : " .. tostring(err))
		end
	end

	folder.Parent = Workspace

	local info = {
		Index = index,
		Folder = folder,
		Center = center,
		Platform = platform,
		SpawnPosition = spawnPosition,
		ReturnPortalPosition = returnField.Position,
		-- Zone de spawn des objets à absorber
		SpawnArea = {
			MinX = center.X - 300,
			MaxX = center.X + 300,
			MinZ = center.Z - 300,
			MaxZ = center.Z + 300,
			MinY = 4,
			MaxY = 42,
		},
	}
	worldInfos[index] = info
	return info
end

-- ============================================================
-- API PUBLIQUE
-- ============================================================
function WorldFactory.getWorldInfo(index: number)
	return worldInfos[index]
end

function WorldFactory.getWorldPosition(index: number): Vector3
	local info = worldInfos[index]
	return info and info.SpawnPosition or WorldFactory.LOBBY_SPAWN
end

function WorldFactory.getLobbySpawn(): Vector3
	return WorldFactory.LOBBY_SPAWN
end

function WorldFactory.getLobby()
	return Workspace:FindFirstChild("Lobby")
end

--- Construit tout. Idempotent : si la map existe déjà, on la reconstruit.
function WorldFactory.buildAll()
	local existingLobby = Workspace:FindFirstChild("Lobby")
	if existingLobby then
		existingLobby:Destroy()
	end
	local existingWorlds = Workspace:FindFirstChild("Worlds")
	if existingWorlds then
		existingWorlds:Destroy()
	end
	-- nettoyage des collectibles d'une session précédente (Studio)
	local existingCollectibles = Workspace:FindFirstChild("Collectibles")
	if existingCollectibles then
		existingCollectibles:Destroy()
	end
	-- Filet de sécurité placé dans le .rbxlx : inutile une fois la map générée
	local fallback = Workspace:FindFirstChild("Fallback")
	if fallback then
		fallback:Destroy()
	end

	local startClock = os.clock()

	buildLobby()

	local worldsFolder = Instance.new("Folder")
	worldsFolder.Name = "Worlds"
	worldsFolder.Parent = Workspace

	for index = 1, #GameConfig.Worlds do
		local info = buildWorld(index)
		info.Folder.Parent = worldsFolder
	end

	-- Dossier des objets à absorber (rempli par CollectSystem)
	local collectibles = Instance.new("Folder")
	collectibles.Name = "Collectibles"
	collectibles.Parent = Workspace

	-- Réglages globaux du monde
	Workspace.Gravity = 196.2
	Workspace.FallenPartsDestroyHeight = -300
	Lighting.ClockTime = 14
	Lighting.Brightness = 2.5
	Lighting.EnvironmentDiffuseScale = 0.4
	Lighting.EnvironmentSpecularScale = 0.4
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(120, 130, 150)
	Lighting.OutdoorAmbient = Color3.fromRGB(140, 150, 170)

	local success, atmosphere = pcall(function()
		local existing = Lighting:FindFirstChildOfClass("Atmosphere")
		if existing then
			existing:Destroy()
		end
		local newAtmosphere = Instance.new("Atmosphere")
		newAtmosphere.Density = 0.32
		newAtmosphere.Offset = 0.1
		newAtmosphere.Color = Color3.fromRGB(200, 220, 255)
		newAtmosphere.Decay = Color3.fromRGB(120, 150, 200)
		newAtmosphere.Glare = 0.2
		newAtmosphere.Haze = 1.4
		newAtmosphere.Parent = Lighting
		return newAtmosphere
	end)
	if not success then
		warn("[WorldFactory] Atmosphere : " .. tostring(atmosphere))
	end

	print(string.format("[WorldFactory] Map générée en %.2fs (%d mondes + lobby)", os.clock() - startClock, #GameConfig.Worlds))
	return worldInfos
end

return WorldFactory
