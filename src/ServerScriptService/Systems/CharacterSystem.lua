--!strict
--[[
	CharacterSystem  |  ServerScriptService.Systems.CharacterSystem
	------------------------------------------------------------------
	Applique les TRANSFORMATIONS sur le personnage :
	  • taille (Model:ScaleTo)
	  • vitesse de déplacement (amélioration)
	  • aura / particules / traînée / lumière selon le tier
	  • titre au-dessus de la tête (BillboardGui) + puissance
	  • mode Géant (événement)
	  • réapplication automatique après un respawn

	Le client ajoute en plus des effets locaux (EffectsController) : il lit
	les attributs "TransformTier" et "TitleId" posés ici.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local Formulas = require(Modules:WaitForChild("Formulas"))
local Net = require(Modules:WaitForChild("Net"))

local DataManager = require(script.Parent.DataManager)

local CharacterSystem = {}

CharacterSystem.sizeMultiplier = 1 -- modifié par EventManager (Giant Mode)

local state: { [Player]: any } = {}

local function clearEffects(character: Model)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root then
		return
	end
	for _, child in ipairs(root:GetChildren()) do
		if child:IsA("ParticleEmitter") or child:IsA("PointLight") or child:IsA("Trail") or child:IsA("Attachment") then
			if child:GetAttribute("TransformFx") then
				child:Destroy()
			end
		end
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local oldGui = character:FindFirstChild("TitleGui")
		if oldGui then
			oldGui:Destroy()
		end
	end
end

local function buildTitle(character: Model, profile)
	local head = character:FindFirstChild("Head")
	if not head then
		return
	end
	local existing = character:FindFirstChild("TitleGui")
	if existing then
		existing:Destroy()
	end

	local titleGui = Instance.new("BillboardGui")
	titleGui.Name = "TitleGui"
	titleGui.Size = UDim2.fromOffset(240, 64)
	titleGui.StudsOffset = Vector3.new(0, 3.2, 0)
	titleGui.AlwaysOnTop = false
	titleGui.MaxDistance = 250
	titleGui.Adornee = head
	titleGui.Parent = character

	local titleData = nil
	for _, title in ipairs(GameConfig.Titles) do
		if title.Id == profile.titleSelected then
			titleData = title
			break
		end
	end

	local label = Instance.new("TextLabel")
	label.Name = "TitleLabel"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 0.55)
	label.Font = Enum.Font.FredokaOne
	label.Text = (titleData and titleData.Name) or "Noob"
	label.TextColor3 = (titleData and titleData.Color) or Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.35
	label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	label.TextScaled = true
	label.Parent = titleGui

	local powerLabel = Instance.new("TextLabel")
	powerLabel.Name = "PowerLabel"
	powerLabel.BackgroundTransparency = 1
	powerLabel.Position = UDim2.fromScale(0, 0.52)
	powerLabel.Size = UDim2.fromScale(1, 0.42)
	powerLabel.Font = Enum.Font.GothamBold
	powerLabel.Text = Formulas.formatNumber(profile.power) .. " ⚡"
	powerLabel.TextColor3 = Color3.fromRGB(255, 235, 150)
	powerLabel.TextStrokeTransparency = 0.4
	powerLabel.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	powerLabel.TextScaled = true
	powerLabel.Parent = titleGui
end

local function applyAura(character: Model, tier, hasCosmetics: boolean)
	local root = character:FindFirstChild("HumanoidRootPart")
	if not root or not root:IsA("BasePart") then
		return
	end

	if tier.ParticleRate and tier.ParticleRate > 0 then
		local emitter = Instance.new("ParticleEmitter")
		emitter:SetAttribute("TransformFx", true)
		emitter.Name = "TransformAura"
		emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
		emitter.Color = ColorSequence.new(tier.Aura)
		emitter.LightEmission = 0.8
		emitter.LightInfluence = 0
		emitter.Rate = math.min(tier.ParticleRate, 60)
		emitter.Lifetime = NumberRange.new(0.6, 1.4)
		emitter.Speed = NumberRange.new(2, 5)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.2),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Parent = root

		local light = Instance.new("PointLight")
		light:SetAttribute("TransformFx", true)
		light.Name = "TransformLight"
		light.Color = tier.Aura
		light.Brightness = math.min(1 + tier.Tier * 0.35, 5)
		light.Range = 14 + tier.Tier * 3
		light.Parent = root
	end

	-- Traînée (à partir du tier 4) ou cosmétique VIP
	if tier.Tier >= 4 or hasCosmetics then
		local top = Instance.new("Attachment")
		top:SetAttribute("TransformFx", true)
		top.Name = "TrailTop"
		top.Position = Vector3.new(0, 1.4, 0)
		top.Parent = root

		local bottom = Instance.new("Attachment")
		bottom:SetAttribute("TransformFx", true)
		bottom.Name = "TrailBottom"
		bottom.Position = Vector3.new(0, -1.4, 0)
		bottom.Parent = root

		local trail = Instance.new("Trail")
		trail:SetAttribute("TransformFx", true)
		trail.Name = "TransformTrail"
		trail.Attachment0 = top
		trail.Attachment1 = bottom
		trail.Color = ColorSequence.new(hasCosmetics and Color3.fromRGB(255, 215, 0) or tier.Aura)
		trail.Lifetime = 0.7
		trail.MinLength = 0
		trail.WidthScale = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.4),
			NumberSequenceKeypoint.new(1, 0),
		})
		trail.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		trail.Parent = root
	end
end

--- Applique la transformation / le titre / la vitesse au personnage.
function CharacterSystem.refresh(player: Player)
	local profile = DataManager.getProfile(player)
	local character = player.Character
	if not profile or not character then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not humanoid or not root then
		return
	end

	local tierIndex = Formulas.getTransformIndex(profile.power)
	local tier = GameConfig.Transformations[tierIndex]
	local playerState = state[player]
	if not playerState then
		playerState = {}
		state[player] = playerState
	end

	local targetScale = tier.Size * CharacterSystem.sizeMultiplier
	local tierChanged = playerState.tier ~= tierIndex
	local scaleChanged = playerState.scale == nil or math.abs(playerState.scale - targetScale) > 0.01
	local titleChanged = playerState.title ~= profile.titleSelected

	if tierChanged or scaleChanged then
		local ok, err = pcall(function()
			(character :: Model):ScaleTo(targetScale)
		end)
		if not ok then
			warn("[CharacterSystem] ScaleTo : " .. tostring(err))
		end
		playerState.scale = targetScale
		player:SetAttribute("CharacterScale", targetScale)
	end

	if tierChanged then
		clearEffects(character)
		applyAura(character, tier, profile.gamePasses and profile.gamePasses.Cosmetics or false)
		playerState.tier = tierIndex
		character:SetAttribute("TransformTier", tierIndex)
		character:SetAttribute("TransformName", tier.Name)
		Net.event("Transformation"):FireClient(player, tierIndex)
		if tierIndex > 1 then
			Net.event("PlaySound"):FireClient(player, "transform", 0.55)
		end
	end

	if titleChanged or tierChanged then
		buildTitle(character, profile)
		playerState.title = profile.titleSelected
	end

	-- Vitesse de déplacement
	local walkSpeed = Formulas.walkSpeed(profile)
	if math.abs(humanoid.WalkSpeed - walkSpeed) > 0.1 then
		humanoid.WalkSpeed = walkSpeed
	end
end

--- Force la reconstruction complète (respawn, changement de titre…)
function CharacterSystem.reset(player: Player)
	state[player] = nil
end

local function updatePowerLabel(player: Player)
	local character = player.Character
	local profile = DataManager.getProfile(player)
	if not character or not profile then
		return
	end
	local titleGui = character:FindFirstChild("TitleGui")
	local powerLabel = titleGui and titleGui:FindFirstChild("PowerLabel")
	if powerLabel and powerLabel:IsA("TextLabel") then
		powerLabel.Text = Formulas.formatNumber(profile.power) .. " ⚡"
	end
end

function CharacterSystem.start()
	local function onCharacter(player: Player, character: Model)
		CharacterSystem.reset(player)
		character:WaitForChild("Humanoid", 10)
		character:WaitForChild("HumanoidRootPart", 10)
		task.wait(0.35)
		CharacterSystem.refresh(player)
	end

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function(character)
			task.spawn(onCharacter, player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		player.CharacterAdded:Connect(function(character)
			task.spawn(onCharacter, player, character)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end

	-- Le titre / la puissance change : on rafraîchit au fil de l'eau
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in ipairs(Players:GetPlayers()) do
				if DataManager.isLoaded(player) then
					local ok, err = pcall(CharacterSystem.refresh, player)
					if not ok then
						warn("[CharacterSystem] refresh : " .. tostring(err))
					end
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(2)
			for _, player in ipairs(Players:GetPlayers()) do
				updatePowerLabel(player)
			end
		end
	end)

	DataManager.Events.Rebirth:Connect(function(player)
		CharacterSystem.reset(player)
		task.wait(0.2)
		CharacterSystem.refresh(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		state[player] = nil
	end)

	print("[CharacterSystem] Démarré")
end

return CharacterSystem
