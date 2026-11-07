--!strict
--[[
	PetFactory  |  StarterPlayer.StarterPlayerScripts.Controllers.PetFactory
	------------------------------------------------------------------
	Construit les modèles 3D des pets à partir de primitives Roblox.
	Aucun asset externe : chaque pet = corps + tête + yeux + accessoire,
	coloré selon sa rareté. Les pets sont affichés côté client uniquement
	(le serveur ne connaît que les données).

	Utilisation :
		local model = PetFactory.create("Dragon", 3)
		model:PivotTo(cframe)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))

local PetFactory = {}

local function makePart(name: string, size: Vector3, color: Color3, material: Enum.Material?, parent: Instance): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.Color = color
	part.Material = material or Enum.Material.SmoothPlastic
	part.Anchored = true
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.CastShadow = false
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Massless = true
	part.Parent = parent
	return part
end

--- Crée le modèle 3D d'un pet.
function PetFactory.create(petId: string, level: number?): Model
	local info = GameConfig.Pets[petId]
	local rarity = info and GameConfig.Rarities[info.Rarity] or GameConfig.Rarities.Common
	local petLevel = level or 1
	local scale = (info and info.Scale or 1) * (1 + (petLevel - 1) * 0.06)

	local model = Instance.new("Model")
	model.Name = "Pet_" .. petId

	local bodySize = Vector3.new(1.7, 1.7, 1.7)
	if info and info.Shape == "Ball" then
		bodySize = Vector3.new(1.9, 1.9, 1.9)
	elseif info and info.Shape == "Cylinder" then
		bodySize = Vector3.new(1.6, 1.6, 2.1)
	elseif info and info.Shape == "Wedge" then
		bodySize = Vector3.new(1.9, 1.4, 2.4)
	end

	local material = Enum.Material.SmoothPlastic
	if info and info.Glow then
		material = Enum.Material.Neon
	end

	local bodyColor = info and info.BodyColor or Color3.fromRGB(230, 230, 230)
	local accentColor = info and info.AccentColor or Color3.fromRGB(255, 255, 255)

	local body = makePart("Body", bodySize * scale, bodyColor, material, model)
	if info and info.Shape == "Ball" then
		body.Shape = Enum.PartType.Ball
	end
	if info and info.Transparent then
		body.Transparency = info.Transparent
	end

	local head = makePart("Head", Vector3.new(1.35, 1.35, 1.35) * scale, bodyColor, material, model)
	head.Shape = Enum.PartType.Ball
	head.CFrame = CFrame.new(0, bodySize.Y * 0.55 * scale, bodySize.Z * 0.32 * scale)

	-- Yeux
	for _, side in ipairs({ -1, 1 }) do
		local eye = makePart("Eye", Vector3.new(0.34, 0.34, 0.2) * scale, Color3.fromRGB(20, 20, 30), Enum.Material.SmoothPlastic, model)
		eye.CFrame = head.CFrame * CFrame.new(0.3 * side * scale, 0.18 * scale, -0.55 * scale)
	end

	-- Museau / accent
	local accent = makePart("Accent", Vector3.new(0.7, 0.45, 0.4) * scale, accentColor, Enum.Material.SmoothPlastic, model)
	accent.CFrame = head.CFrame * CFrame.new(0, -0.22 * scale, -0.55 * scale)

	-- Ailes / accessoire selon la rareté
	local rarityOrder = rarity.Order or 1
	if rarityOrder >= 3 then
		for _, side in ipairs({ -1, 1 }) do
			local wing = makePart("Wing", Vector3.new(0.18, 1.5, 0.9) * scale, accentColor, Enum.Material.Neon, model)
			wing.CFrame = body.CFrame * CFrame.new(0.95 * side * scale, 0.2 * scale, 0.15 * scale) * CFrame.Angles(0, 0, math.rad(22 * side))
		end
	end
	if rarityOrder >= 5 then
		local crown = makePart("Crown", Vector3.new(0.95, 0.3, 0.95) * scale, Color3.fromRGB(255, 215, 70), Enum.Material.Neon, model)
		crown.Shape = Enum.PartType.Cylinder
		crown.CFrame = head.CFrame * CFrame.new(0, 0.85 * scale, 0) * CFrame.Angles(0, 0, math.rad(90))
	end
	if rarityOrder >= 6 then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(rarity.Color)
		emitter.Rate = 12
		emitter.Lifetime = NumberRange.new(0.4, 0.9)
		emitter.Speed = NumberRange.new(1, 3)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.LightEmission = 1
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.6),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Parent = body
	end

	-- Lumière pour les pets rares
	if rarityOrder >= 4 or (info and info.Glow) then
		local light = Instance.new("PointLight")
		light.Color = rarity.Color
		light.Brightness = 1.2
		light.Range = 12
		light.Parent = body
	end

	-- Étiquette au-dessus du pet
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "PetTag"
	billboard.Size = UDim2.fromOffset(120, 40)
	billboard.StudsOffset = Vector3.new(0, 2.1 * scale, 0)
	billboard.AlwaysOnTop = false
	billboard.MaxDistance = 90
	billboard.Adornee = body
	billboard.Parent = model

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Size = UDim2.fromScale(1, 0.6)
	nameLabel.Font = Enum.Font.FredokaOne
	nameLabel.Text = string.format("%s %s", (info and info.Emoji) or "🐾", (info and info.Name) or petId)
	nameLabel.TextColor3 = rarity.Color
	nameLabel.TextStrokeTransparency = 0.4
	nameLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	nameLabel.TextScaled = true
	nameLabel.Parent = billboard

	local levelLabel = Instance.new("TextLabel")
	levelLabel.BackgroundTransparency = 1
	levelLabel.Position = UDim2.fromScale(0, 0.58)
	levelLabel.Size = UDim2.fromScale(1, 0.4)
	levelLabel.Font = Enum.Font.GothamBold
	levelLabel.Text = petLevel > 1 and ("Nv." .. petLevel .. "  ×" .. string.format("%.2f", (info and info.Mult or 0) * (1 + (petLevel - 1) * 0.25))) or ("×" .. string.format("%.2f", info and info.Mult or 0))
	levelLabel.TextColor3 = Color3.fromRGB(240, 245, 255)
	levelLabel.TextStrokeTransparency = 0.5
	levelLabel.TextScaled = true
	levelLabel.Parent = billboard

	model.PrimaryPart = body
	model:SetAttribute("PetId", petId)
	model:SetAttribute("PetLevel", petLevel)
	return model
end

return PetFactory
