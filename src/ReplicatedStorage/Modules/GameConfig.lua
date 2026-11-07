--!strict
--[[
	GameConfig  |  ReplicatedStorage.Modules.GameConfig
	------------------------------------------------------------------
	CONFIGURATION CENTRALE DU JEU (partagée client + serveur).
	Tout l'équilibrage du jeu se règle ICI. Aucun script ne doit
	contenir de valeur magique : il doit toujours lire GameConfig.

	ATTENTION SÉCURITÉ :
	Le serveur est la seule source de vérité. Le client lit ce module
	uniquement pour AFFICHER (prix, descriptions, probabilités…).
]]

local GameConfig = {}

GameConfig.GameName = "NOOB TO GOD SIMULATOR"
GameConfig.Version = 4
GameConfig.DataStoreName = "NoobToGodSimulator"
GameConfig.DataStoreKeyPrefix = "Player_"
GameConfig.DataVersion = 4

-- ============================================================
-- 1. COLLECTE
-- ============================================================
GameConfig.Collect = {
	-- Rayon de base (studs) dans lequel un objet est cliquable / aspiré
	TouchRadius = 12,
	ClickRadius = 260, -- distance max pour cliquer un objet (anti-cheat serveur)
	-- Resspawn d'un objet après absorption
	RespawnTime = 6,
	-- Nombre maximum d'objets actifs par joueur et par monde (optimisation mobile)
	MaxActivePerWorld = 90,
	-- Coins = Power * CoinRatio
	CoinRatio = 0.12,
	-- Pouvoir "VACUUM" (aspiration de zone)
	Vacuum = {
		BaseRadius = 45,
		BaseCooldown = 12,
		RadiusPerLevel = 9,
		CooldownReductionPerLevel = 0.9,
		MaxLevel = 5,
	},
	-- Seuil de "combo" : collecter vite fait monter un compteur de satisfaction
	ComboWindow = 2.5,
	ComboMaxStacks = 20,
	-- Limite anti-flood : requêtes de collecte acceptées par seconde
	MaxRequestsPerSecond = 22,
}

-- Types d'objets du monde 1 (valeurs demandées dans le brief)
GameConfig.ObjectTypes = {
	Trash      = { Name = "Déchet",           Power = 1,    Color = Color3.fromRGB(120, 130, 120), Material = Enum.Material.Sand,      Size = Vector3.new(1.4, 1.4, 1.4),  Shape = "Block" },
	Pizza      = { Name = "Pizza",            Power = 5,    Color = Color3.fromRGB(240, 170, 60),  Material = Enum.Material.SmoothPlastic, Size = Vector3.new(2.4, 0.4, 2.4), Shape = "Cylinder" },
	TV         = { Name = "Télévision",       Power = 20,   Color = Color3.fromRGB(40, 45, 60),    Material = Enum.Material.SmoothPlastic, Size = Vector3.new(3, 2.2, 1),     Shape = "Block" },
	Car        = { Name = "Voiture",          Power = 100,  Color = Color3.fromRGB(220, 60, 60),   Material = Enum.Material.SmoothPlastic, Size = Vector3.new(5, 1.8, 2.6),   Shape = "Block" },
	House      = { Name = "Maison",           Power = 500,  Color = Color3.fromRGB(230, 210, 180), Material = Enum.Material.Brick,     Size = Vector3.new(8, 7, 8),        Shape = "Block" },
	GiantTower = { Name = "Bâtiment géant",   Power = 5000, Color = Color3.fromRGB(150, 160, 190), Material = Enum.Material.Concrete, Size = Vector3.new(11, 26, 11),     Shape = "Block" },
}

-- ============================================================
-- 2. TRANSFORMATIONS (évolution visuelle & statistiques)
--    tier = index, seuil = puissance ACTUELLE nécessaire
-- ============================================================
GameConfig.Transformations = {
	{ Tier = 1,  Name = "Noob",      Emoji = "🪵", MinPower = 0,       Size = 1.00, Color = Color3.fromRGB(255, 214, 80),  Aura = Color3.fromRGB(255, 240, 160), ParticleRate = 0,  Desc = "Tu es un noob. Assumé." },
	{ Tier = 2,  Name = "Beginner",  Emoji = "🌱", MinPower = 50,      Size = 1.10, Color = Color3.fromRGB(120, 230, 120), Aura = Color3.fromRGB(180, 255, 180), ParticleRate = 6,  Desc = "Tu as compris le concept du clic." },
	{ Tier = 3,  Name = "Pro",       Emoji = "😎", MinPower = 250,     Size = 1.25, Color = Color3.fromRGB(80, 180, 255),  Aura = Color3.fromRGB(140, 220, 255), ParticleRate = 12, Desc = "Les noobs te demandent des conseils." },
	{ Tier = 4,  Name = "Hacker",    Emoji = "💻", MinPower = 1000,    Size = 1.45, Color = Color3.fromRGB(80, 255, 160),  Aura = Color3.fromRGB(0, 255, 140),   ParticleRate = 18, Desc = "Tu aspires la matrice. Illégalement." },
	{ Tier = 5,  Name = "Titan",     Emoji = "🗿", MinPower = 5000,    Size = 1.75, Color = Color3.fromRGB(200, 140, 90),  Aura = Color3.fromRGB(255, 190, 120), ParticleRate = 24, Desc = "Les bâtiments te craignent." },
	{ Tier = 6,  Name = "Monster",   Emoji = "👹", MinPower = 20000,   Size = 2.10, Color = Color3.fromRGB(200, 50, 90),   Aura = Color3.fromRGB(255, 40, 80),   ParticleRate = 30, Desc = "GrRRrR. Les pets se cachent." },
	{ Tier = 7,  Name = "God",       Emoji = "⚡", MinPower = 100000,  Size = 2.50, Color = Color3.fromRGB(255, 235, 120), Aura = Color3.fromRGB(255, 215, 0),   ParticleRate = 40, Desc = "Le serveur prie pour toi." },
	{ Tier = 8,  Name = "Cosmic",    Emoji = "🌌", MinPower = 500000,  Size = 3.00, Color = Color3.fromRGB(170, 120, 255), Aura = Color3.fromRGB(200, 160, 255), ParticleRate = 55, Desc = "Tu es fait d'étoiles maintenant." },
	{ Tier = 9,  Name = "Universal", Emoji = "🪐", MinPower = 2000000, Size = 3.60, Color = Color3.fromRGB(90, 200, 255),  Aura = Color3.fromRGB(60, 230, 255),  ParticleRate = 70, Desc = "Les planètes sont des snacks." },
	{ Tier = 10, Name = "Infinity",  Emoji = "♾️", MinPower = 10000000,Size = 4.30, Color = Color3.fromRGB(255, 255, 255), Aura = Color3.fromRGB(120, 255, 255), ParticleRate = 90, Desc = "Tu as dépassé le jeu. Bravo." },
}

-- ============================================================
-- 3. REBIRTH
-- ============================================================
GameConfig.Rebirth = {
	MaxRebirths = 40,
	-- Coût = BaseCost * CostGrowth^rebirths
	-- 1.85 est calibré pour que le rebirth 40 reste atteignable avec des
	-- pets maxés (~9700 clics) tout en gardant un début de partie rapide
	-- (~12 clics pour le rebirth 1).
	BaseCost = 2500,
	CostGrowth = 1.85,
	-- Multiplicateur permanent : 1 + (rebirths * 0.35)  (additif, lisible)
	MultPerRebirth = 0.35,
	-- Coins offerts au rebirth
	CoinRewardBase = 250,
	CoinRewardPerRebirth = 175,
	-- Titre débloqué tous les N rebirths (voir Titles)
	TitlesEvery = 5,
}

-- ============================================================
-- 4. AMÉLIORATIONS (boutique en pièces)
-- ============================================================
GameConfig.Upgrades = {
	PowerMult = {
		Name = "Multiplicateur de Puissance",
		Desc = "+25% de puissance par niveau.",
		Icon = "⚡",
		MaxLevel = 25,
		BaseCost = 120,
		CostGrowth = 1.55,
		Effect = 0.25,
	},
	CoinMult = {
		Name = "Multiplicateur de Pièces",
		Desc = "+20% de pièces par niveau.",
		Icon = "🪙",
		MaxLevel = 20,
		BaseCost = 150,
		CostGrowth = 1.6,
		Effect = 0.20,
	},
	AutoCollect = {
		Name = "Absorption Automatique",
		Desc = "Aspire automatiquement les objets proches. Niveau 1 = débloqué.",
		Icon = "🌀",
		MaxLevel = 10,
		BaseCost = 400,
		CostGrowth = 1.75,
		-- rayon = 14 + level*7, intervalle = 2.2 - level*0.13
		RadiusBase = 14,
		RadiusPerLevel = 7,
		IntervalBase = 2.2,
		IntervalPerLevel = 0.13,
	},
	Vacuum = {
		Name = "Aspirateur de Zone",
		Desc = "+9 studs de rayon et -0.9s de recharge par niveau.",
		Icon = "🌪️",
		MaxLevel = 5,
		BaseCost = 700,
		CostGrowth = 1.9,
	},
	WalkSpeed = {
		Name = "Vitesse de Course",
		Desc = "+1.5 de vitesse de déplacement par niveau.",
		Icon = "🏃",
		MaxLevel = 12,
		BaseCost = 200,
		CostGrowth = 1.5,
		Effect = 1.5,
	},
	PetSlots = {
		Name = "Emplacements de Pets",
		Desc = "Équipe un pet supplémentaire (3 de base, 8 max).",
		Icon = "🐾",
		MaxLevel = 5,
		BaseCost = 1200,
		CostGrowth = 2.2,
	},
}

GameConfig.BasePetSlots = 3

-- ============================================================
-- 5. RARETÉS DE PETS
-- ============================================================
GameConfig.Rarities = {
	Common    = { Name = "Common",    Color = Color3.fromRGB(170, 180, 195), Weight = 1,   Order = 1 },
	Uncommon  = { Name = "Uncommon",  Color = Color3.fromRGB(110, 220, 130), Weight = 2,   Order = 2 },
	Rare      = { Name = "Rare",      Color = Color3.fromRGB(90, 170, 255),  Weight = 3,   Order = 3 },
	Epic      = { Name = "Epic",      Color = Color3.fromRGB(190, 110, 255), Weight = 4,   Order = 4 },
	Legendary = { Name = "Legendary", Color = Color3.fromRGB(255, 190, 60),  Weight = 5,   Order = 5 },
	Mythical  = { Name = "Mythical",  Color = Color3.fromRGB(255, 80, 120),  Weight = 6,   Order = 6 },
	Secret    = { Name = "Secret",    Color = Color3.fromRGB(60, 255, 235),  Weight = 7,   Order = 7 },
}

GameConfig.RarityOrder = { "Common", "Uncommon", "Rare", "Epic", "Legendary", "Mythical", "Secret" }

-- ============================================================
-- 6. PETS  (modèles générés proceduralement : aucune asset externe)
--    Shape : "Block" | "Ball" | "Wedge" | "Cylinder"
--    Mult  : multiplicateur de puissance additionné
-- ============================================================
GameConfig.Pets = {
	-- --- Communs
	Cat = { Name = "Chat Noob", Rarity = "Common", Mult = 0.05, Shape = "Block", BodyColor = Color3.fromRGB(245, 230, 200), AccentColor = Color3.fromRGB(255, 120, 120), Emoji = "🐱", Scale = 1.0 },
	Dog = { Name = "Chien Teubé", Rarity = "Common", Mult = 0.06, Shape = "Block", BodyColor = Color3.fromRGB(200, 160, 110), AccentColor = Color3.fromRGB(120, 80, 50), Emoji = "🐶", Scale = 1.0 },
	Trash = { Name = "Poubelle Vivante", Rarity = "Common", Mult = 0.04, Shape = "Cylinder", BodyColor = Color3.fromRGB(120, 140, 120), AccentColor = Color3.fromRGB(80, 90, 80), Emoji = "🗑️", Scale = 1.1 },
	Fish = { Name = "Poisson Pané", Rarity = "Common", Mult = 0.07, Shape = "Ball", BodyColor = Color3.fromRGB(255, 200, 120), AccentColor = Color3.fromRGB(255, 150, 60), Emoji = "🐟", Scale = 0.9 },
	-- --- Peu communs
	Bunny = { Name = "Lapin Turbo", Rarity = "Uncommon", Mult = 0.14, Shape = "Block", BodyColor = Color3.fromRGB(250, 250, 255), AccentColor = Color3.fromRGB(255, 170, 200), Emoji = "🐰", Scale = 1.0 },
	Frog = { Name = "Grenouille DJ", Rarity = "Uncommon", Mult = 0.16, Shape = "Ball", BodyColor = Color3.fromRGB(120, 220, 120), AccentColor = Color3.fromRGB(60, 150, 60), Emoji = "🐸", Scale = 1.0 },
	Pizza = { Name = "Pizza Sentiente", Rarity = "Uncommon", Mult = 0.18, Shape = "Cylinder", BodyColor = Color3.fromRGB(255, 200, 90), AccentColor = Color3.fromRGB(220, 60, 60), Emoji = "🍕", Scale = 1.1 },
	Bee = { Name = "Abeille Syndiquée", Rarity = "Uncommon", Mult = 0.20, Shape = "Ball", BodyColor = Color3.fromRGB(255, 220, 60), AccentColor = Color3.fromRGB(50, 50, 50), Emoji = "🐝", Scale = 0.85 },
	-- --- Rares
	Dragon = { Name = "Dragon de Poche", Rarity = "Rare", Mult = 0.35, Shape = "Block", BodyColor = Color3.fromRGB(90, 200, 130), AccentColor = Color3.fromRGB(255, 220, 90), Emoji = "🐲", Scale = 1.15 },
	Unicorn = { Name = "Licorne Fiscaliste", Rarity = "Rare", Mult = 0.40, Shape = "Block", BodyColor = Color3.fromRGB(255, 220, 255), AccentColor = Color3.fromRGB(190, 120, 255), Emoji = "🦄", Scale = 1.1 },
	Shark = { Name = "Requin de Bureau", Rarity = "Rare", Mult = 0.38, Shape = "Wedge", BodyColor = Color3.fromRGB(120, 170, 210), AccentColor = Color3.fromRGB(255, 255, 255), Emoji = "🦈", Scale = 1.2 },
	Robot = { Name = "Robot Stagiaire", Rarity = "Rare", Mult = 0.42, Shape = "Block", BodyColor = Color3.fromRGB(180, 190, 210), AccentColor = Color3.fromRGB(80, 255, 200), Emoji = "🤖", Scale = 1.1 },
	-- --- Épiques
	Ghost = { Name = "Fantôme Timide", Rarity = "Epic", Mult = 0.75, Shape = "Ball", BodyColor = Color3.fromRGB(230, 240, 255), AccentColor = Color3.fromRGB(140, 190, 255), Emoji = "👻", Scale = 1.2, Transparent = 0.35 },
	Golem = { Name = "Golem de Lave", Rarity = "Epic", Mult = 0.85, Shape = "Block", BodyColor = Color3.fromRGB(90, 40, 30), AccentColor = Color3.fromRGB(255, 110, 30), Emoji = "🌋", Scale = 1.35 },
	Alien = { Name = "Alien en CDD", Rarity = "Epic", Mult = 0.80, Shape = "Ball", BodyColor = Color3.fromRGB(150, 255, 170), AccentColor = Color3.fromRGB(60, 60, 60), Emoji = "👽", Scale = 1.15 },
	Penguin = { Name = "Pingouin Manager", Rarity = "Epic", Mult = 0.90, Shape = "Block", BodyColor = Color3.fromRGB(40, 45, 60), AccentColor = Color3.fromRGB(255, 255, 255), Emoji = "🐧", Scale = 1.15 },
	-- --- Légendaires
	Phoenix = { Name = "Phoénix Pressé", Rarity = "Legendary", Mult = 1.8, Shape = "Wedge", BodyColor = Color3.fromRGB(255, 120, 40), AccentColor = Color3.fromRGB(255, 230, 60), Emoji = "🔥", Scale = 1.4, Glow = true },
	Trex = { Name = "T-Rex Végétarien", Rarity = "Legendary", Mult = 2.0, Shape = "Block", BodyColor = Color3.fromRGB(140, 200, 110), AccentColor = Color3.fromRGB(250, 240, 200), Emoji = "🦖", Scale = 1.5 },
	NyanCat = { Name = "Nyan Cat Ancien", Rarity = "Legendary", Mult = 2.2, Shape = "Block", BodyColor = Color3.fromRGB(255, 150, 220), AccentColor = Color3.fromRGB(120, 220, 255), Emoji = "🌈", Scale = 1.3, Glow = true },
	Kraken = { Name = "Kraken Hypothécaire", Rarity = "Legendary", Mult = 2.5, Shape = "Ball", BodyColor = Color3.fromRGB(60, 90, 160), AccentColor = Color3.fromRGB(0, 220, 255), Emoji = "🐙", Scale = 1.6 },
	-- --- Mythiques
	GalaxyDragon = { Name = "Dragon Galactique", Rarity = "Mythical", Mult = 5.5, Shape = "Wedge", BodyColor = Color3.fromRGB(80, 50, 160), AccentColor = Color3.fromRGB(190, 130, 255), Emoji = "🌌", Scale = 1.8, Glow = true },
	DemonKing = { Name = "Roi Démon", Rarity = "Mythical", Mult = 6.0, Shape = "Block", BodyColor = Color3.fromRGB(70, 20, 40), AccentColor = Color3.fromRGB(255, 40, 90), Emoji = "😈", Scale = 1.9, Glow = true },
	Angel = { Name = "Ange Fonctionnaire", Rarity = "Mythical", Mult = 6.5, Shape = "Ball", BodyColor = Color3.fromRGB(255, 250, 220), AccentColor = Color3.fromRGB(255, 240, 150), Emoji = "😇", Scale = 1.7, Glow = true },
	-- --- Secrets
	DevPet = { Name = "Le Dev du Jeu", Rarity = "Secret", Mult = 20, Shape = "Block", BodyColor = Color3.fromRGB(30, 30, 40), AccentColor = Color3.fromRGB(60, 255, 235), Emoji = "🧑‍💻", Scale = 2.0, Glow = true },
	NoobGod = { Name = "Noob Suprême", Rarity = "Secret", Mult = 25, Shape = "Ball", BodyColor = Color3.fromRGB(255, 240, 90), AccentColor = Color3.fromRGB(255, 60, 200), Emoji = "👑", Scale = 2.1, Glow = true },
	ErrorPet = { Name = "Glitch Absolu", Rarity = "Secret", Mult = 30, Shape = "Block", BodyColor = Color3.fromRGB(255, 0, 90), AccentColor = Color3.fromRGB(0, 255, 200), Emoji = "👾", Scale = 2.0, Glow = true },
}

-- Poids d'apparition d'un pet à l'intérieur de sa rareté
GameConfig.PetWeightInsideRarity = 1 -- uniforme (modifiable pet par pet via Pets[id].Weight)

-- ============================================================
-- 7. ŒUFS
--    Pool = liste de pets pouvant sortir, par rareté.
--    Les probabilités affichées = somme des poids de la rareté.
-- ============================================================
GameConfig.Eggs = {
	StarterEgg = {
		Name = "Œuf du Noob",
		Emoji = "🥚",
		Price = 0, -- gratuit (1 seul par joueur, voir PetSystem)
		FreeOnePerPlayer = true,
		World = 1,
		MinRebirth = 0,
		Color = Color3.fromRGB(240, 240, 240),
		Rates = { Common = 65, Uncommon = 25, Rare = 8, Epic = 2 },
		Pool = {
			Common = { "Cat", "Dog", "Trash", "Fish" },
			Uncommon = { "Bunny", "Frog" },
			Rare = { "Robot" },
			Epic = { "Ghost" },
		},
	},
	BasicEgg = {
		Name = "Œuf Basique",
		Emoji = "🥚",
		Price = 150,
		World = 1,
		MinRebirth = 0,
		Color = Color3.fromRGB(255, 240, 210),
		Rates = { Common = 55, Uncommon = 27, Rare = 13, Epic = 4, Legendary = 1 },
		Pool = {
			Common = { "Cat", "Dog", "Trash", "Fish" },
			Uncommon = { "Bunny", "Frog", "Pizza", "Bee" },
			Rare = { "Dragon", "Unicorn", "Robot" },
			Epic = { "Ghost", "Penguin" },
			Legendary = { "Phoenix" },
		},
	},
	CandyEgg = {
		Name = "Œuf Bonbon",
		Emoji = "🍬",
		Price = 2500,
		World = 2,
		MinRebirth = 0,
		Color = Color3.fromRGB(255, 150, 210),
		Rates = { Common = 40, Uncommon = 30, Rare = 18, Epic = 8, Legendary = 3.4, Mythical = 0.6 },
		Pool = {
			Common = { "Bunny", "Fish" },
			Uncommon = { "Frog", "Bee", "Pizza" },
			Rare = { "Unicorn", "Dragon", "Shark" },
			Epic = { "Ghost", "Alien", "Penguin" },
			Legendary = { "NyanCat", "Phoenix" },
			Mythical = { "Angel" },
		},
	},
	LavaEgg = {
		Name = "Œuf Volcanique",
		Emoji = "🔥",
		Price = 25000,
		World = 3,
		MinRebirth = 1,
		Color = Color3.fromRGB(255, 90, 40),
		Rates = { Common = 30, Uncommon = 28, Rare = 22, Epic = 12, Legendary = 6, Mythical = 1.7, Secret = 0.3 },
		Pool = {
			Common = { "Trash", "Dog" },
			Uncommon = { "Frog", "Bee" },
			Rare = { "Dragon", "Shark", "Robot" },
			Epic = { "Golem", "Penguin", "Alien" },
			Legendary = { "Phoenix", "Trex", "Kraken" },
			Mythical = { "DemonKing" },
			Secret = { "DevPet" },
		},
	},
	SpaceEgg = {
		Name = "Œuf Cosmique",
		Emoji = "🚀",
		Price = 250000,
		World = 4,
		MinRebirth = 3,
		Color = Color3.fromRGB(80, 90, 200),
		Rates = { Common = 22, Uncommon = 26, Rare = 24, Epic = 15, Legendary = 9, Mythical = 3.4, Secret = 0.6 },
		Pool = {
			Common = { "Fish", "Cat" },
			Uncommon = { "Bunny", "Pizza" },
			Rare = { "Shark", "Robot", "Unicorn" },
			Epic = { "Alien", "Ghost", "Penguin" },
			Legendary = { "Kraken", "NyanCat", "Trex" },
			Mythical = { "GalaxyDragon", "Angel" },
			Secret = { "NoobGod" },
		},
	},
	GlitchEgg = {
		Name = "Œuf Glitché",
		Emoji = "👾",
		Price = 2000000,
		World = 5,
		MinRebirth = 6,
		Color = Color3.fromRGB(255, 0, 120),
		Rates = { Common = 15, Uncommon = 22, Rare = 25, Epic = 18, Legendary = 13, Mythical = 5.6, Secret = 1.4 },
		Pool = {
			Common = { "Trash", "Dog" },
			Uncommon = { "Bee", "Frog" },
			Rare = { "Robot", "Shark" },
			Epic = { "Alien", "Golem" },
			Legendary = { "NyanCat", "Kraken", "Phoenix" },
			Mythical = { "DemonKing", "GalaxyDragon" },
			Secret = { "ErrorPet", "DevPet" },
		},
	},
	GodEgg = {
		Name = "Œuf Divin",
		Emoji = "👑",
		Price = 60000000,
		World = 6,
		MinRebirth = 10,
		Color = Color3.fromRGB(255, 220, 90),
		Rates = { Common = 8, Uncommon = 15, Rare = 24, Epic = 22, Legendary = 18, Mythical = 10, Secret = 3 },
		Pool = {
			Common = { "Cat", "Fish" },
			Uncommon = { "Bunny", "Bee" },
			Rare = { "Dragon", "Robot" },
			Epic = { "Penguin", "Ghost" },
			Legendary = { "Trex", "Phoenix", "Kraken" },
			Mythical = { "Angel", "GalaxyDragon", "DemonKing" },
			Secret = { "NoobGod", "ErrorPet", "DevPet" },
		},
	},
}

GameConfig.EggOrder = { "StarterEgg", "BasicEgg", "CandyEgg", "LavaEgg", "SpaceEgg", "GlitchEgg", "GodEgg" }

-- ============================================================
-- 8. MONDES
-- ============================================================
GameConfig.Worlds = {
	{
		Index = 1,
		Id = "NoobIsland",
		Name = "Noob Island",
		Emoji = "🏝️",
		UnlockPower = 0,
		UnlockRebirth = 0,
		ValueMult = 1,
		SkyColor = Color3.fromRGB(120, 190, 255),
		Ambient = Color3.fromRGB(140, 150, 170),
		FloorColor = Color3.fromRGB(120, 200, 110),
		FloorMaterial = Enum.Material.Grass,
		DecorColor = Color3.fromRGB(100, 160, 90),
		AtmosphereColor = Color3.fromRGB(200, 220, 255),
		MusicId = "", -- remplir avec un ID audio (roblox.com/library)
		Objects = { "Trash", "Pizza", "TV", "Car", "House", "GiantTower" },
		ObjectWeights = { Trash = 35, Pizza = 25, TV = 18, Car = 12, House = 7, GiantTower = 3 },
		Egg = "BasicEgg",
	},
	{
		Index = 2,
		Id = "CandyWorld",
		Name = "Candy World",
		Emoji = "🍭",
		UnlockPower = 1500,
		UnlockRebirth = 0,
		ValueMult = 5,
		SkyColor = Color3.fromRGB(255, 190, 230),
		Ambient = Color3.fromRGB(230, 190, 220),
		FloorColor = Color3.fromRGB(255, 170, 210),
		FloorMaterial = Enum.Material.SmoothPlastic,
		DecorColor = Color3.fromRGB(255, 240, 250),
		AtmosphereColor = Color3.fromRGB(255, 210, 240),
		MusicId = "",
		Objects = { "Candy", "Lollipop", "Cake", "Gingerbread", "ChocolateFountain", "CandyCastle" },
		ObjectWeights = { Candy = 35, Lollipop = 25, Cake = 18, Gingerbread = 12, ChocolateFountain = 7, CandyCastle = 3 },
		Egg = "CandyEgg",
	},
	{
		Index = 3,
		Id = "LavaWorld",
		Name = "Lava World",
		Emoji = "🌋",
		UnlockPower = 25000,
		UnlockRebirth = 1,
		ValueMult = 30,
		SkyColor = Color3.fromRGB(120, 30, 20),
		Ambient = Color3.fromRGB(120, 60, 50),
		FloorColor = Color3.fromRGB(80, 40, 35),
		FloorMaterial = Enum.Material.Basalt,
		DecorColor = Color3.fromRGB(255, 90, 30),
		AtmosphereColor = Color3.fromRGB(255, 120, 40),
		MusicId = "",
		Objects = { "Coal", "MagmaRock", "LavaCar", "Volcano", "LavaMansion", "VolcanoTower" },
		ObjectWeights = { Coal = 35, MagmaRock = 25, LavaCar = 18, Volcano = 12, LavaMansion = 7, VolcanoTower = 3 },
		Egg = "LavaEgg",
	},
	{
		Index = 4,
		Id = "SpaceWorld",
		Name = "Space World",
		Emoji = "🚀",
		UnlockPower = 400000,
		UnlockRebirth = 3,
		ValueMult = 200,
		SkyColor = Color3.fromRGB(10, 10, 40),
		Ambient = Color3.fromRGB(60, 70, 110),
		FloorColor = Color3.fromRGB(70, 75, 95),
		FloorMaterial = Enum.Material.Metal,
		DecorColor = Color3.fromRGB(120, 140, 200),
		AtmosphereColor = Color3.fromRGB(90, 120, 255),
		MusicId = "",
		Objects = { "Asteroid", "Satellite", "Rocket", "UFO", "SpaceStation", "Planet" },
		ObjectWeights = { Asteroid = 35, Satellite = 25, Rocket = 18, UFO = 12, SpaceStation = 7, Planet = 3 },
		Egg = "SpaceEgg",
	},
	{
		Index = 5,
		Id = "GlitchWorld",
		Name = "Glitch World",
		Emoji = "👾",
		UnlockPower = 6000000,
		UnlockRebirth = 6,
		ValueMult = 1500,
		SkyColor = Color3.fromRGB(20, 0, 30),
		Ambient = Color3.fromRGB(90, 40, 110),
		FloorColor = Color3.fromRGB(40, 20, 60),
		FloorMaterial = Enum.Material.Neon,
		DecorColor = Color3.fromRGB(0, 255, 180),
		AtmosphereColor = Color3.fromRGB(255, 0, 150),
		MusicId = "",
		Objects = { "GlitchCube", "ErrorCode", "CorruptedTV", "FloatingCar", "BrokenHouse", "RealityTear" },
		ObjectWeights = { GlitchCube = 35, ErrorCode = 25, CorruptedTV = 18, FloatingCar = 12, BrokenHouse = 7, RealityTear = 3 },
		Egg = "GlitchEgg",
	},
	{
		Index = 6,
		Id = "GodWorld",
		Name = "God World",
		Emoji = "⛩️",
		UnlockPower = 90000000,
		UnlockRebirth = 10,
		ValueMult = 12000,
		SkyColor = Color3.fromRGB(255, 235, 170),
		Ambient = Color3.fromRGB(255, 245, 210),
		FloorColor = Color3.fromRGB(255, 250, 235),
		FloorMaterial = Enum.Material.Marble,
		DecorColor = Color3.fromRGB(255, 215, 90),
		AtmosphereColor = Color3.fromRGB(255, 240, 180),
		MusicId = "",
		Objects = { "HolyStatue", "GoldenCloud", "DivineThrone", "SunChariot", "CelestialPalace", "UniverseCore" },
		ObjectWeights = { HolyStatue = 35, GoldenCloud = 25, DivineThrone = 18, SunChariot = 12, CelestialPalace = 7, UniverseCore = 3 },
		Egg = "GodEgg",
	},
}

-- Objets des mondes 2 à 6 (les valeurs sont multipliées par World.ValueMult)
GameConfig.WorldObjectTypes = {
	-- World 2 : Candy
	Candy = { Name = "Bonbon", Power = 1, Color = Color3.fromRGB(255, 120, 180), Material = Enum.Material.SmoothPlastic, Size = Vector3.new(1.6, 1.6, 1.6), Shape = "Ball" },
	Lollipop = { Name = "Sucette", Power = 5, Color = Color3.fromRGB(255, 90, 200), Material = Enum.Material.SmoothPlastic, Size = Vector3.new(2, 4, 2), Shape = "Cylinder" },
	Cake = { Name = "Gâteau", Power = 20, Color = Color3.fromRGB(255, 220, 230), Material = Enum.Material.SmoothPlastic, Size = Vector3.new(4, 3, 4), Shape = "Cylinder" },
	Gingerbread = { Name = "Maison en Pain d'Épice", Power = 100, Color = Color3.fromRGB(190, 120, 60), Material = Enum.Material.WoodPlanks, Size = Vector3.new(7, 6, 7), Shape = "Block" },
	ChocolateFountain = { Name = "Fontaine de Chocolat", Power = 500, Color = Color3.fromRGB(90, 50, 30), Material = Enum.Material.SmoothPlastic, Size = Vector3.new(9, 12, 9), Shape = "Cylinder" },
	CandyCastle = { Name = "Château en Sucre", Power = 5000, Color = Color3.fromRGB(255, 180, 220), Material = Enum.Material.Neon, Size = Vector3.new(12, 24, 12), Shape = "Block" },
	-- World 3 : Lava
	Coal = { Name = "Charbon", Power = 1, Color = Color3.fromRGB(35, 35, 40), Material = Enum.Material.Slate, Size = Vector3.new(1.6, 1.6, 1.6), Shape = "Block" },
	MagmaRock = { Name = "Roche de Magma", Power = 5, Color = Color3.fromRGB(255, 100, 30), Material = Enum.Material.Neon, Size = Vector3.new(2.5, 2.5, 2.5), Shape = "Ball" },
	LavaCar = { Name = "Voiture en Fusion", Power = 20, Color = Color3.fromRGB(255, 70, 20), Material = Enum.Material.Neon, Size = Vector3.new(5, 2, 3), Shape = "Block" },
	Volcano = { Name = "Mini Volcan", Power = 100, Color = Color3.fromRGB(70, 30, 25), Material = Enum.Material.Basalt, Size = Vector3.new(8, 10, 8), Shape = "Cylinder" },
	LavaMansion = { Name = "Manoir de Lave", Power = 500, Color = Color3.fromRGB(120, 40, 30), Material = Enum.Material.Neon, Size = Vector3.new(10, 12, 10), Shape = "Block" },
	VolcanoTower = { Name = "Tour Volcanique", Power = 5000, Color = Color3.fromRGB(255, 80, 20), Material = Enum.Material.Neon, Size = Vector3.new(12, 28, 12), Shape = "Block" },
	-- World 4 : Space
	Asteroid = { Name = "Astéroïde", Power = 1, Color = Color3.fromRGB(90, 90, 100), Material = Enum.Material.Rock, Size = Vector3.new(2, 2, 2), Shape = "Ball" },
	Satellite = { Name = "Satellite", Power = 5, Color = Color3.fromRGB(200, 210, 230), Material = Enum.Material.Metal, Size = Vector3.new(3, 2, 2), Shape = "Block" },
	Rocket = { Name = "Fusée", Power = 20, Color = Color3.fromRGB(230, 230, 240), Material = Enum.Material.Metal, Size = Vector3.new(3, 8, 3), Shape = "Cylinder" },
	UFO = { Name = "OVNI", Power = 100, Color = Color3.fromRGB(120, 255, 180), Material = Enum.Material.Neon, Size = Vector3.new(9, 3, 9), Shape = "Cylinder" },
	SpaceStation = { Name = "Station Spatiale", Power = 500, Color = Color3.fromRGB(160, 170, 200), Material = Enum.Material.Metal, Size = Vector3.new(14, 6, 8), Shape = "Block" },
	Planet = { Name = "Planète", Power = 5000, Color = Color3.fromRGB(120, 90, 255), Material = Enum.Material.SmoothPlastic, Size = Vector3.new(20, 20, 20), Shape = "Ball" },
	-- World 5 : Glitch
	GlitchCube = { Name = "Cube Glitché", Power = 1, Color = Color3.fromRGB(255, 0, 140), Material = Enum.Material.Neon, Size = Vector3.new(1.8, 1.8, 1.8), Shape = "Block" },
	ErrorCode = { Name = "Code d'Erreur", Power = 5, Color = Color3.fromRGB(0, 255, 180), Material = Enum.Material.Neon, Size = Vector3.new(2.5, 1.2, 2.5), Shape = "Block" },
	CorruptedTV = { Name = "TV Corrompue", Power = 20, Color = Color3.fromRGB(160, 0, 255), Material = Enum.Material.Neon, Size = Vector3.new(4, 3, 1), Shape = "Block" },
	FloatingCar = { Name = "Voiture Flottante", Power = 100, Color = Color3.fromRGB(0, 200, 255), Material = Enum.Material.Neon, Size = Vector3.new(5, 2, 3), Shape = "Block" },
	BrokenHouse = { Name = "Maison Bugguée", Power = 500, Color = Color3.fromRGB(255, 255, 0), Material = Enum.Material.Neon, Size = Vector3.new(9, 9, 9), Shape = "Block" },
	RealityTear = { Name = "Déchirure Réelle", Power = 5000, Color = Color3.fromRGB(255, 0, 60), Material = Enum.Material.ForceField, Size = Vector3.new(10, 26, 4), Shape = "Block" },
	-- World 6 : God
	HolyStatue = { Name = "Statue Sacrée", Power = 1, Color = Color3.fromRGB(255, 250, 220), Material = Enum.Material.Marble, Size = Vector3.new(2, 4, 2), Shape = "Block" },
	GoldenCloud = { Name = "Nuage Doré", Power = 5, Color = Color3.fromRGB(255, 230, 140), Material = Enum.Material.Neon, Size = Vector3.new(4, 2, 4), Shape = "Ball" },
	DivineThrone = { Name = "Trône Divin", Power = 20, Color = Color3.fromRGB(255, 215, 80), Material = Enum.Material.Neon, Size = Vector3.new(4, 5, 4), Shape = "Block" },
	SunChariot = { Name = "Char du Soleil", Power = 100, Color = Color3.fromRGB(255, 200, 40), Material = Enum.Material.Neon, Size = Vector3.new(8, 5, 5), Shape = "Block" },
	CelestialPalace = { Name = "Palais Céleste", Power = 500, Color = Color3.fromRGB(255, 245, 200), Material = Enum.Material.Marble, Size = Vector3.new(14, 14, 14), Shape = "Block" },
	UniverseCore = { Name = "Cœur de l'Univers", Power = 5000, Color = Color3.fromRGB(140, 255, 255), Material = Enum.Material.Neon, Size = Vector3.new(16, 16, 16), Shape = "Ball" },
}

-- ============================================================
-- 9. ÉVÉNEMENTS ALÉATOIRES
-- ============================================================
GameConfig.EventInterval = 300 -- toutes les 5 minutes
GameConfig.EventDuration = 60
GameConfig.Events = {
	GiantMode = { Name = "Giant Mode", Emoji = "🦍", Duration = 60, Color = Color3.fromRGB(255, 140, 60), Desc = "Tout le monde devient GÉANT !" },
	MoneyRain = { Name = "Money Rain", Emoji = "💰", Duration = 45, Color = Color3.fromRGB(255, 220, 60), Desc = "Des pièces tombent du ciel !" },
	LowGravity = { Name = "Low Gravity", Emoji = "🌙", Duration = 60, Color = Color3.fromRGB(160, 200, 255), Desc = "La gravité est divisée par 4 !" },
	GoldenObjects = { Name = "Golden Objects", Emoji = "✨", Duration = 60, Color = Color3.fromRGB(255, 200, 40), Desc = "Les objets dorés valent ×5 !" },
	ChaosMode = { Name = "Chaos Mode", Emoji = "🌪️", Duration = 75, Color = Color3.fromRGB(255, 60, 200), Desc = "Événements imprévisibles en chaîne !" },
	LuckyTime = { Name = "Lucky Time", Emoji = "🍀", Duration = 60, Color = Color3.fromRGB(90, 255, 140), Desc = "Gains ×2 et pets 2× plus rares !" },
}
GameConfig.EventOrder = { "GiantMode", "MoneyRain", "LowGravity", "GoldenObjects", "ChaosMode", "LuckyTime" }
GameConfig.EventRewards = {
	GiantModePowerMult = 1.5,
	GoldenObjectsMult = 5,
	LuckyTimeMult = 2,
	MoneyRainCoins = 120,
	ChaosRandomEffects = true,
}

-- ============================================================
-- 10. SUCCÈS
-- ============================================================
GameConfig.Achievements = {
	FirstAbsorb   = { Name = "Premier pas",        Desc = "Absorbe ton premier objet.",                 Icon = "👶", Goal = 1,       Stat = "collected", Reward = 50 },
	Collect100    = { Name = "Petit glouton",      Desc = "Absorbe 100 objets.",                        Icon = "🍽️", Goal = 100,     Stat = "collected", Reward = 200 },
	Collect1000   = { Name = "Trou noir",          Desc = "Absorbe 1 000 objets.",                      Icon = "🕳️", Goal = 1000,    Stat = "collected", Reward = 1500 },
	Collect10000  = { Name = "Fin de l'univers",   Desc = "Absorbe 10 000 objets.",                     Icon = "🌠", Goal = 10000,   Stat = "collected", Reward = 15000 },
	Power1k       = { Name = "Ça commence",        Desc = "Atteins 1 000 de puissance.",                Icon = "📈", Goal = 1000,    Stat = "bestPower", Reward = 150 },
	Power1M       = { Name = "Milliardaire",       Desc = "Atteins 1 000 000 de puissance.",            Icon = "💎", Goal = 1000000, Stat = "bestPower", Reward = 5000 },
	Power1B       = { Name = "Inflation",          Desc = "Atteins 1 000 000 000 de puissance.",        Icon = "🏦", Goal = 1e9,     Stat = "bestPower", Reward = 250000 },
	Rebirth1      = { Name = "Renaissance",        Desc = "Effectue ton premier Rebirth.",              Icon = "🔄", Goal = 1,       Stat = "rebirths",   Reward = 500 },
	Rebirth10     = { Name = "Boucle temporelle",  Desc = "Effectue 10 Rebirths.",                      Icon = "⏳", Goal = 10,      Stat = "rebirths",   Reward = 25000 },
	Rebirth25     = { Name = "Immortel",           Desc = "Effectue 25 Rebirths.",                      Icon = "♾️", Goal = 25,      Stat = "rebirths",   Reward = 1000000 },
	Egg1          = { Name = "Éclosion",           Desc = "Ouvre ton premier œuf.",                     Icon = "🥚", Goal = 1,       Stat = "eggsOpened", Reward = 100 },
	Egg50         = { Name = "Éleveur",            Desc = "Ouvre 50 œufs.",                             Icon = "🐣", Goal = 50,      Stat = "eggsOpened", Reward = 2500 },
	PetLegendary  = { Name = "Chanceux",           Desc = "Obtiens un pet Légendaire.",                 Icon = "🌟", Goal = 1,       Stat = "legendaryPets", Reward = 5000 },
	PetMythical   = { Name = "Mythe vivant",       Desc = "Obtiens un pet Mythique.",                   Icon = "🔮", Goal = 1,       Stat = "mythicalPets", Reward = 50000 },
	PetSecret     = { Name = "Chance insolente",   Desc = "Obtiens un pet Secret.",                     Icon = "🎰", Goal = 1,       Stat = "secretPets", Reward = 500000 },
	Fuse1         = { Name = "Alchimiste",         Desc = "Réalise ta première fusion de pets.",        Icon = "⚗️", Goal = 1,       Stat = "fusions",   Reward = 300 },
	World2        = { Name = "Voyageur",           Desc = "Débloque Candy World.",                      Icon = "🍭", Goal = 2,       Stat = "maxWorld",  Reward = 500 },
	World4        = { Name = "Astronaute",         Desc = "Débloque Space World.",                      Icon = "🚀", Goal = 4,       Stat = "maxWorld",  Reward = 20000 },
	World6        = { Name = "Divinité",           Desc = "Débloque God World.",                        Icon = "👑", Goal = 6,       Stat = "maxWorld",  Reward = 1000000 },
	Vacuum1       = { Name = "Aspirateur",         Desc = "Utilise l'aspirateur de zone.",              Icon = "🌪️", Goal = 1,       Stat = "vacuums",   Reward = 100 },
	Vacuum100     = { Name = "Dyson Humain",       Desc = "Utilise 100 fois l'aspirateur.",             Icon = "🧹", Goal = 100,     Stat = "vacuums",   Reward = 10000 },
	Daily1        = { Name = "Fidèle",             Desc = "Réclame ta première récompense quotidienne.",Icon = "📅", Goal = 1,       Stat = "dailies",   Reward = 250 },
	Daily7        = { Name = "Semaine parfaite",   Desc = "Réclame 7 jours d'affilée.",                 Icon = "🗓️", Goal = 7,       Stat = "streak",    Reward = 5000 },
	Event1        = { Name = "Fêtard",             Desc = "Participe à un événement.",                  Icon = "🎉", Goal = 1,       Stat = "events",    Reward = 500 },
}

GameConfig.AchievementOrder = {
	"FirstAbsorb", "Collect100", "Collect1000", "Collect10000",
	"Power1k", "Power1M", "Power1B",
	"Rebirth1", "Rebirth10", "Rebirth25",
	"Egg1", "Egg50", "PetLegendary", "PetMythical", "PetSecret", "Fuse1",
	"World2", "World4", "World6",
	"Vacuum1", "Vacuum100", "Daily1", "Daily7", "Event1",
}

-- ============================================================
-- 11. RÉCOMPENSES QUOTIDIENNES (7 jours)
-- ============================================================
GameConfig.DailyRewards = {
	{ Coins = 250,  Power = 0 },
	{ Coins = 500,  Power = 0 },
	{ Coins = 900,  Power = 0, BoostMinutes = 10 },
	{ Coins = 1500, Power = 0 },
	{ Coins = 2500, Power = 0, BoostMinutes = 15 },
	{ Coins = 4000, Power = 0 },
	{ Coins = 8000, Power = 0, BoostMinutes = 30, FreeEgg = "BasicEgg" },
}
GameConfig.DailyResetSeconds = 20 * 60 * 60 -- 20h de cooldown entre deux réclamations
GameConfig.MaxOfflineHours = 8 -- gains hors-ligne calculés (auto-collect)

-- ============================================================
-- 12. TITRES (affichés au-dessus de la tête)
-- ============================================================
GameConfig.Titles = {
	{ Id = "noob",      Name = "Noob Officiel",      Rebirth = 0,  Color = Color3.fromRGB(255, 214, 80) },
	{ Id = "clicker",   Name = "Cliqueur Pro",       Rebirth = 2,  Color = Color3.fromRGB(120, 230, 120) },
	{ Id = "hacker",    Name = "Hacker",             Rebirth = 5,  Color = Color3.fromRGB(0, 255, 140) },
	{ Id = "titan",     Name = "Titan",              Rebirth = 10, Color = Color3.fromRGB(200, 140, 90) },
	{ Id = "monster",   Name = "Monstre",            Rebirth = 15, Color = Color3.fromRGB(255, 40, 80) },
	{ Id = "god",       Name = "Dieu Vivant",        Rebirth = 20, Color = Color3.fromRGB(255, 215, 0) },
	{ Id = "cosmic",    Name = "Entité Cosmique",    Rebirth = 25, Color = Color3.fromRGB(200, 160, 255) },
	{ Id = "universal", Name = "Univers Incarné",    Rebirth = 30, Color = Color3.fromRGB(60, 230, 255) },
	{ Id = "infinity",  Name = "INFINI",             Rebirth = 40, Color = Color3.fromRGB(255, 255, 255) },
}

-- ============================================================
-- 13. MONÉTISATION (facultatif — le jeu reste 100% jouable gratuitement)
--     ⚠️ Remplace les 0 par tes vrais IDs (créés sur roblox.com/create)
-- ============================================================
GameConfig.GamePasses = {
	DoublePower = { Id = 0, Name = "Double Puissance", Desc = "×2 puissance en permanence.", Icon = "⚡", Color = Color3.fromRGB(255, 190, 60), Price = "R$ 99" },
	AutoCollect = { Id = 0, Name = "Auto Collect", Desc = "Absorption automatique débloquée à vie.", Icon = "🌀", Color = Color3.fromRGB(90, 200, 255), Price = "R$ 149" },
	ExtraPetSlots = { Id = 0, Name = "Slots de Pets +3", Desc = "+3 emplacements de pets équipés.", Icon = "🐾", Color = Color3.fromRGB(190, 120, 255), Price = "R$ 199" },
	VIP = { Id = 0, Name = "VIP", Desc = "+50% puissance et pièces, badge et aura VIP.", Icon = "👑", Color = Color3.fromRGB(255, 220, 60), Price = "R$ 299" },
	Cosmetics = { Id = 0, Name = "Effets Exclusifs", Desc = "Traînée et Aura dorée exclusives.", Icon = "✨", Color = Color3.fromRGB(255, 120, 220), Price = "R$ 79" },
}
GameConfig.GamePassOrder = { "DoublePower", "AutoCollect", "ExtraPetSlots", "VIP", "Cosmetics" }

GameConfig.DeveloperProducts = {
	PowerBoost = { Id = 0, Key = "PowerBoost", Name = "Boost ×3 (15 min)", Desc = "Multiplie tes gains par 3 pendant 15 minutes.", Icon = "🚀", Price = "R$ 25" },
	CoinPack = { Id = 0, Key = "CoinPack", Name = "Pack de pièces", Desc = "Ajoute 25 000 pièces.", Icon = "🪙", Price = "R$ 49" },
	MegaCoinPack = { Id = 0, Key = "MegaCoinPack", Name = "Méga Pack de pièces", Desc = "Ajoute 250 000 pièces.", Icon = "💰", Price = "R$ 199" },
	LuckyEgg = { Id = 0, Key = "LuckyEgg", Name = "Œuf Chanceux", Desc = "Un pet Légendaire garanti.", Icon = "🍀", Price = "R$ 299" },
}
GameConfig.DeveloperProductOrder = { "PowerBoost", "CoinPack", "MegaCoinPack", "LuckyEgg" }
GameConfig.ProductRewards = {
	PowerBoost = { BoostMult = 3, BoostSeconds = 900 },
	CoinPack = { Coins = 25000 },
	MegaCoinPack = { Coins = 250000 },
	LuckyEgg = { GuaranteedRarity = "Legendary" },
}

-- ============================================================
-- 14. RÉCOMPENSES DE PUISSANCE HORS-LIGNE / DIVERS
-- ============================================================
GameConfig.Misc = {
	MaxPets = 200,          -- limite d'inventaire (protection anti-duplication)
	MaxPetLevel = 10,
	FuseCount = 3,          -- 3 pets identiques → 1 pet niveau supérieur
	SaveInterval = 60,      -- sauvegarde auto (secondes)
	LeaderboardTop = 25,
	NotifyDuration = 4,
}

return GameConfig
