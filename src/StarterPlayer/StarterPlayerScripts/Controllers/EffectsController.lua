--!strict
--[[
	EffectsController  |  StarterPlayer.StarterPlayerScripts.Controllers.EffectsController
	------------------------------------------------------------------
	Tous les effets visuels côté client :

	  • explosion de particules + nombre flottant à chaque absorption
	  • flash d'écran, secousse de caméra
	  • ambiance lumineuse par monde (Atmosphere/Fog/Brume locale)
	  • animation des objets à absorber proches (rotation/flottement)
	  • animation des portails
	  • anneau de transformation

	100% client : aucun coût réseau, désactivé sur mobile si le joueur
	coupe les effets dans les paramètres.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")
local Lighting = game:GetService("Lighting")
local Debris = game:GetService("Debris")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local Formulas = require(Modules:WaitForChild("Formulas"))

local ClientState = require(script.Parent.ClientState)

local EffectsController = {}

local screenGui: ScreenGui? = nil
local fxLayer: Frame? = nil
local shakeAmount = 0
local shakeConnection = nil
local currentWorld = 0
local camera = Workspace.CurrentCamera

local function toHex(color: Color3): string
	return string.format("%02x%02x%02x", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

-- ============================================================
-- PARTICULES D'ABSORPTION
-- ============================================================
function EffectsController.burst(position: Vector3, colorHex: string, value: number)
	if not ClientState.getSetting("effects") then
		return
	end
	local color = Color3.fromRGB(tonumber(string.sub(colorHex, 1, 2), 16) or 140, tonumber(string.sub(colorHex, 3, 4), 16) or 255, tonumber(string.sub(colorHex, 5, 6), 16) or 190)

	local anchor = Instance.new("Part")
	anchor.Name = "FxAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.CFrame = CFrame.new(position)
	anchor.Parent = Workspace

	if ClientState.getSetting("particles") then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = SPARKLE
		emitter.Color = ColorSequence.new(color)
		emitter.LightEmission = 1
		emitter.LightInfluence = 0
		emitter.Rate = 0
		emitter.Lifetime = NumberRange.new(0.35, 0.7)
		emitter.Speed = NumberRange.new(14, 26)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1.6),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(1, 1),
		})
		emitter.Parent = anchor
		emitter:Emit(math.clamp(8 + math.log10(math.max(value, 1)) * 5, 8, 40))

		local ring = Instance.new("ParticleEmitter")
		ring.Texture = SMOKE
		ring.Color = ColorSequence.new(color)
		ring.Rate = 0
		ring.Lifetime = NumberRange.new(0.4, 0.6)
		ring.Speed = NumberRange.new(20, 30)
		ring.SpreadAngle = Vector2.new(0, 360)
		ring.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.5),
			NumberSequenceKeypoint.new(1, 3),
		})
		ring.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.2),
			NumberSequenceKeypoint.new(1, 1),
		})
		ring.Parent = anchor
		ring:Emit(10)
	end

	-- Nombre flottant
	if ClientState.getSetting("damageNumbers") then
		local billboard = Instance.new("BillboardGui")
		billboard.Name = "FloatNumber"
		billboard.Size = UDim2.fromOffset(160, 44)
		billboard.AlwaysOnTop = true
		billboard.Adornee = anchor
		billboard.Parent = anchor

		local label = Instance.new("TextLabel")
		label.BackgroundTransparency = 1
		label.Size = UDim2.fromScale(1, 1)
		label.Font = Enum.Font.FredokaOne
		label.Text = "+" .. Formulas.formatNumber(value) .. " ⚡"
		label.TextColor3 = color
		label.TextStrokeTransparency = 0.2
		label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		label.TextScaled = true
		label.Parent = billboard

		TweenService:Create(anchor, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = CFrame.new(position + Vector3.new(math.random(-2, 2), 5, math.random(-2, 2))),
		}):Play()
		TweenService:Create(label, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	end

	Debris:AddItem(anchor, 1.2)
end

-- ============================================================
-- FLASH / SHAKE
-- ============================================================
function EffectsController.flash(colorHex: string, duration: number?)
	if not fxLayer or not ClientState.getSetting("effects") then
		return
	end
	local color = Color3.fromRGB(tonumber(string.sub(colorHex, 1, 2), 16) or 255, tonumber(string.sub(colorHex, 3, 4), 16) or 255, tonumber(string.sub(colorHex, 5, 6), 16) or 255)
	local flashFrame = Instance.new("Frame")
	flashFrame.Size = UDim2.fromScale(1, 1)
	flashFrame.BackgroundColor3 = color
	flashFrame.BackgroundTransparency = 0.55
	flashFrame.BorderSizePixel = 0
	flashFrame.ZIndex = 50
	flashFrame.Parent = fxLayer
	TweenService:Create(flashFrame, TweenInfo.new(duration or 0.4), { BackgroundTransparency = 1 }):Play()
	Debris:AddItem(flashFrame, (duration or 0.4) + 0.1)
end

function EffectsController.shake(intensity: number)
	if not ClientState.getSetting("cameraShake") then
		return
	end
	shakeAmount = math.clamp(shakeAmount + intensity * 1.4, 0, 3)
	if shakeConnection then
		return
	end
	shakeConnection = RunService.RenderStepped:Connect(function(deltaTime)
		local cam = Workspace.CurrentCamera
		if not cam then
			return
		end
		if shakeAmount <= 0.001 then
			if shakeConnection then
				shakeConnection:Disconnect()
				shakeConnection = nil
			end
			return
		end
		local offset = Vector3.new(
			(math.random() - 0.5) * shakeAmount,
			(math.random() - 0.5) * shakeAmount,
			0
		)
		cam.CFrame = cam.CFrame * CFrame.new(offset)
		shakeAmount = math.max(0, shakeAmount - deltaTime * 4.5)
	end)
end

-- ============================================================
-- TRANSFORMATION
-- ============================================================
function EffectsController.transformation(tierIndex: number)
	local tier = GameConfig.Transformations[tierIndex]
	if not tier or not ClientState.getSetting("effects") then
		return
	end
	EffectsController.flash(toHex(tier.Aura), 0.45)
	EffectsController.shake(0.8)

	local character = game:GetService("Players").LocalPlayer.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if root and ClientState.getSetting("particles") then
		local emitter = Instance.new("ParticleEmitter")
		emitter.Texture = SPARKLE
		emitter.Color = ColorSequence.new(tier.Aura)
		emitter.LightEmission = 1
		emitter.Rate = 0
		emitter.Lifetime = NumberRange.new(0.6, 1.3)
		emitter.Speed = NumberRange.new(30, 55)
		emitter.SpreadAngle = Vector2.new(180, 180)
		emitter.Size = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 2),
			NumberSequenceKeypoint.new(1, 0),
		})
		emitter.Parent = root
		emitter:Emit(90)
		Debris:AddItem(emitter, 2)
	end
end

-- ============================================================
-- AMBIANCE PAR MONDE (local, n'affecte que ce joueur)
-- ============================================================
local function getAtmosphere(): Atmosphere
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if not atmosphere then
		atmosphere = Instance.new("Atmosphere")
		atmosphere.Density = 0.3
		atmosphere.Offset = 0.1
		atmosphere.Color = Color3.fromRGB(200, 220, 255)
		atmosphere.Decay = Color3.fromRGB(120, 150, 200)
		atmosphere.Glare = 0.2
		atmosphere.Haze = 1.2
		atmosphere.Parent = Lighting
	end
	return atmosphere
end

--- Fondu noir rapide lors d'un voyage (rend le téléportation "propre")
function EffectsController.worldTransition()
	if not fxLayer then
		return
	end
	local fade = Instance.new("Frame")
	fade.Name = "WorldFade"
	fade.Size = UDim2.fromScale(1, 1)
	fade.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	fade.BackgroundTransparency = 0.15
	fade.BorderSizePixel = 0
	fade.ZIndex = 49
	fade.Parent = fxLayer
	TweenService:Create(fade, TweenInfo.new(0.45, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 1,
	}):Play()
	Debris:AddItem(fade, 0.6)
end

function EffectsController.setWorld(worldIndex: number)
	EffectsController.worldTransition()
	currentWorld = worldIndex
	local world = GameConfig.Worlds[worldIndex]
	if not world then
		-- Lobby
		pcall(function()
			Lighting.ClockTime = 14
			Lighting.FogEnd = 5000
			Lighting.FogStart = 0
			Lighting.FogColor = Color3.fromRGB(200, 220, 255)
			Lighting.Ambient = Color3.fromRGB(120, 130, 150)
			Lighting.OutdoorAmbient = Color3.fromRGB(140, 150, 170)
			local atmosphere = getAtmosphere()
			TweenService:Create(atmosphere, TweenInfo.new(0.8), {
				Color = Color3.fromRGB(200, 220, 255),
				Decay = Color3.fromRGB(120, 150, 200),
				Density = 0.3,
				Haze = 1.2,
			}):Play()
		end)
		return
	end

	pcall(function()
		local atmosphere = getAtmosphere()
		TweenService:Create(atmosphere, TweenInfo.new(0.9), {
			Color = world.AtmosphereColor,
			Decay = world.SkyColor,
			Density = worldIndex >= 4 and 0.4 or 0.3,
			Haze = worldIndex == 3 and 2.5 or 1.2,
			Glare = worldIndex == 6 and 0.8 or 0.2,
		}):Play()
		Lighting.FogColor = world.SkyColor
		Lighting.FogStart = 300
		Lighting.FogEnd = worldIndex >= 5 and 2200 or 4000
		Lighting.Ambient = world.Ambient
		Lighting.OutdoorAmbient = world.Ambient:Lerp(Color3.fromRGB(255, 255, 255), 0.25)
		Lighting.ClockTime = worldIndex == 4 and 0 or 14
	end)
end

-- ============================================================
-- ANIMATION DES OBJETS (rotation / flottement)
-- ============================================================
local animatedParts: { [BasePart]: any } = {}
local refreshTimer = 0

local function refreshAnimatedParts()
	animatedParts = {}
	local folder = Workspace:FindFirstChild("Collectibles")
	if folder then
		local cam = Workspace.CurrentCamera
		local cameraPosition = cam and cam.CFrame.Position or Vector3.zero
		local count = 0
		for _, part in ipairs(folder:GetChildren()) do
			if part:IsA("BasePart") and (part.Position - cameraPosition).Magnitude < 200 then
				animatedParts[part] = {
					baseCFrame = part.CFrame,
					phase = math.random() * math.pi * 2,
					speed = 0.6 + math.random() * 0.6,
				}
				count = count + 1
				if count >= 70 then
					break
				end
			end
		end
	end
	-- Portails animés
	local lobby = Workspace:FindFirstChild("Lobby")
	if lobby then
		for _, descendant in ipairs(lobby:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant:GetAttribute("Animated") then
				animatedParts[descendant] = { animated = true, baseCFrame = descendant.CFrame, phase = 0, speed = 1 }
			end
		end
	end
	local worlds = Workspace:FindFirstChild("Worlds")
	if worlds then
		for _, descendant in ipairs(worlds:GetDescendants()) do
			if descendant:IsA("BasePart") and descendant:GetAttribute("Animated") then
				animatedParts[descendant] = { animated = true, baseCFrame = descendant.CFrame, phase = 0, speed = 1 }
			end
		end
	end
end

local function animateLoop(deltaTime: number)
	refreshTimer = refreshTimer + deltaTime
	if refreshTimer > 0.5 then
		refreshTimer = 0
		refreshAnimatedParts()
	end
	if not ClientState.getSetting("effects") then
		return
	end
	local time = os.clock()
	for part, data in pairs(animatedParts) do
		if not part.Parent then
			animatedParts[part] = nil
		elseif data.animated then
			if string.find(part.Name, "Egg") or part.Name == "AltarOrb" then
				part.CFrame = data.baseCFrame * CFrame.new(0, math.sin(time * 1.5 + data.phase) * 0.6, 0)
			end
		else
			part.CFrame = data.baseCFrame * CFrame.new(0, math.sin(time * data.speed + data.phase) * 0.45, 0) * CFrame.Angles(0, time * data.speed * 0.6, 0)
		end
	end
end

-- ============================================================
-- DÉMARRAGE
-- ============================================================
function EffectsController.start(parentScreenGui: ScreenGui)
	screenGui = parentScreenGui

	fxLayer = Instance.new("Frame")
	fxLayer.Name = "FxLayer"
	fxLayer.Size = UDim2.fromScale(1, 1)
	fxLayer.BackgroundTransparency = 1
	fxLayer.ZIndex = 50
	fxLayer.Parent = parentScreenGui

	ClientState.Signals.EffectBurst:Connect(function(position, color, value)
		EffectsController.burst(position, color or "8affc1", value or 0)
	end)
	ClientState.Signals.ScreenFlash:Connect(function(color, duration)
		EffectsController.flash(color or "ffffff", duration)
	end)
	ClientState.Signals.CameraShake:Connect(function(intensity)
		EffectsController.shake(intensity or 0.4)
	end)
	ClientState.Signals.Transformation:Connect(function(tier)
		EffectsController.transformation(tier)
	end)
	ClientState.Signals.World:Connect(function(worldIndex)
		EffectsController.setWorld(worldIndex)
	end)

	refreshAnimatedParts()
	RunService.Heartbeat:Connect(animateLoop)

	-- Adapte les effets à la puissance (plus tu es puissant, plus c'est fort)

	print("[EffectsController] Démarré")
end

return EffectsController
