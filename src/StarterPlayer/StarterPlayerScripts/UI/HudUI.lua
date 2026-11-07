--!strict
--[[
	HudUI  |  StarterPlayer.StarterPlayerScripts.UI.HudUI
	------------------------------------------------------------------
	Interface permanente (HUD) :

	  ⚡ Puissance (+ multiplicateur)      🪙 Pièces      🔄 Rebirths
	  Barre de progression vers la transformation suivante
	  Bannière d'événement avec compte à rebours (en haut au centre)
	  Colonne de boutons : Boutique, Œufs, Pets, Rebirth, Mondes,
	                       Classement, Succès, Quotidien, Réglages
	  Bouton ASPIRER (VACUUM) avec cooldown
	  Indicateur d'absorption automatique

	S'adapte aux téléphones/tablettes/PC via un UIScale calculé sur la
	taille de l'écran.
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local Formulas = require(Modules:WaitForChild("Formulas"))
local Net = require(Modules:WaitForChild("Net"))

local UIConfig = require(script.Parent.UIConfig)
local UILib = require(script.Parent.UILib)
local ClientState = require(script.Parent.Parent.Controllers.ClientState)

local HudUI = {}

local C = UIConfig.Colors

local refs = {}
local currentPower = 0
local currentCoins = 0
local vacuumCooldownEnd = 0
local vacuumCooldownTotal = 12

-- ============================================================
-- CONSTRUCTION
-- ============================================================
local function buildStatCard(parent: Instance, emoji: string, caption: string, color: Color3, layoutOrder: number)
	local card = UILib.panel(parent, {
		Name = caption .. "Card",
		Size = UDim2.fromOffset(150, 62),
		Color = C.Panel,
		Radius = UIConfig.Radius.Medium,
		LayoutOrder = layoutOrder,
		StrokeColor = color,
		StrokeTransparency = 0.55,
	})
	local icon = UILib.label(card, emoji, {
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.fromOffset(10, 11),
		Font = UIConfig.FontTitle,
		TextScaled = true,
	})
	icon.Name = "Icon"

	local cap = UILib.label(card, caption, {
		Size = UDim2.new(1, -60, 0, 16),
		Position = UDim2.fromOffset(52, 10),
		Font = UIConfig.FontBold,
		TextSize = 11,
		Color = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	cap.Name = "Caption"

	local value = UILib.label(card, "0", {
		Size = UDim2.new(1, -60, 0, 26),
		Position = UDim2.fromOffset(52, 26),
		Font = UIConfig.FontTitle,
		TextScaled = true,
		Color = color,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	value.Name = "Value"
	UILib.padding(card, 0, 0, 0, 10)

	return card, value
end

function HudUI.start(screenGui: ScreenGui, ctx)
	-- Conteneur racine (scalé pour mobile)
	local root = Instance.new("Frame")
	root.Name = "Root"
	root.Size = UDim2.fromScale(1, 1)
	root.BackgroundTransparency = 1
	root.Parent = screenGui
	refs.root = root

	local scale = Instance.new("UIScale")
	scale.Parent = root
	refs.scale = scale

	local viewport = workspace.CurrentCamera and workspace.CurrentCamera.ViewportSize or Vector2.new(1280, 720)
	local function computeScale()
		local cam = workspace.CurrentCamera
		local size = cam and cam.ViewportSize or viewport
		-- 1.0 de référence sur 1000px de haut
		return math.clamp(size.Y / 900, 0.72, 1.15)
	end
	scale.Scale = computeScale()
	if workspace.CurrentCamera then
		workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(function()
			scale.Scale = computeScale()
		end)
	end

	-- ============================================================
	-- BLOC DE GAUCHE : puissance / pièces / rebirths
	-- ============================================================
	local leftColumn = Instance.new("Frame")
	leftColumn.Name = "LeftColumn"
	leftColumn.Size = UDim2.fromOffset(320, 200)
	leftColumn.Position = UDim2.fromOffset(16, 12)
	leftColumn.BackgroundTransparency = 1
	leftColumn.Parent = root
	UILib.list(leftColumn, { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Left })

	-- Carte de puissance
	local powerCard = UILib.panel(leftColumn, {
		Name = "PowerCard",
		Size = UDim2.fromOffset(320, 86),
		Color = C.Panel,
		Radius = UIConfig.Radius.Large,
		LayoutOrder = 1,
		StrokeColor = C.Gold,
		StrokeTransparency = 0.4,
		Gradient = { C.PanelLight, C.Panel },
		GradientRotation = 120,
	})

	local powerIcon = UILib.label(powerCard, "⚡", {
		Size = UDim2.fromOffset(54, 54),
		Position = UDim2.fromOffset(12, 16),
		Font = UIConfig.FontTitle,
		TextScaled = true,
	})
	powerIcon.Name = "Icon"

	local powerCaption = UILib.label(powerCard, "PUISSANCE", {
		Size = UDim2.new(1, -90, 0, 16),
		Position = UDim2.fromOffset(74, 10),
		Font = UIConfig.FontBold,
		TextSize = 12,
		Color = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	local powerValue = UILib.label(powerCard, "0", {
		Size = UDim2.new(1, -100, 0, 40),
		Position = UDim2.fromOffset(74, 26),
		Font = UIConfig.FontTitle,
		TextScaled = true,
		Color = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		Stroke = true,
	})
	powerValue.Name = "PowerValue"
	refs.powerValue = powerValue

	local multChip = UILib.panel(powerCard, {
		Name = "MultiplierChip",
		Size = UDim2.fromOffset(72, 26),
		Position = UDim2.new(1, -84, 0, 10),
		Color = C.Purple,
		Radius = UIConfig.Radius.Pill,
		Stroke = false,
	})
	local multLabel = UILib.label(multChip, "×1", {
		Size = UDim2.fromScale(1, 1),
		Font = UIConfig.FontBold,
		TextScaled = true,
		Color = C.TextDark,
	})
	multLabel.Name = "Text"
	UILib.padding(multChip, 2, 2, 6, 6)
	refs.multiplier = multLabel

	-- Ligne pièces / rebirths
	local row = Instance.new("Frame")
	row.Name = "StatsRow"
	row.Size = UDim2.fromOffset(320, 62)
	row.BackgroundTransparency = 1
	row.LayoutOrder = 2
	row.Parent = leftColumn
	UILib.list(row, { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Left })
	local rowDirection = Instance.new("UIGridLayout")
	rowDirection.CellSize = UDim2.fromOffset(156, 62)
	rowDirection.CellPadding = UDim2.fromOffset(8, 0)
	rowDirection.FillDirection = Enum.FillDirection.Horizontal
	rowDirection.SortOrder = Enum.SortOrder.LayoutOrder
	rowDirection.Parent = row
	if row:FindFirstChildOfClass("UIListLayout") then
		row:FindFirstChildOfClass("UIListLayout"):Destroy()
	end

	local _, coinValue = buildStatCard(row, "🪙", "PIÈCES", C.Gold, 1)
	local _, rebirthValue = buildStatCard(row, "🔄", "REBIRTHS", C.Pink, 2)
	refs.coins = coinValue
	refs.rebirths = rebirthValue

	-- Barre de transformation
	local tierCard = UILib.panel(leftColumn, {
		Name = "TierCard",
		Size = UDim2.fromOffset(320, 54),
		Color = C.Panel,
		Radius = UIConfig.Radius.Medium,
		LayoutOrder = 3,
		StrokeColor = C.Blue,
		StrokeTransparency = 0.6,
	})
	local tierLabel = UILib.label(tierCard, "🪵 Noob", {
		Size = UDim2.new(1, -20, 0, 18),
		Position = UDim2.fromOffset(10, 7),
		Font = UIConfig.FontTitle,
		TextSize = 14,
		Color = C.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	tierLabel.Name = "TierLabel"
	refs.tierLabel = tierLabel

	local tierBarHolder, tierBarFill = UILib.bar(tierCard, {
		Size = UDim2.new(1, -20, 0, 10),
		Position = UDim2.fromOffset(10, 30),
		Color = C.Blue,
	})
	refs.tierBar = tierBarFill

	local tierProgressLabel = UILib.label(tierCard, "", {
		Size = UDim2.new(1, -20, 0, 12),
		Position = UDim2.fromOffset(10, 40),
		Font = UIConfig.FontSmall,
		TextSize = 10,
		Color = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	refs.tierProgress = tierProgressLabel

	-- ============================================================
	-- BANNIÈRE D'ÉVÉNEMENT (haut centre)
	-- ============================================================
	local eventBanner = UILib.panel(root, {
		Name = "EventBanner",
		Size = UDim2.fromOffset(420, 62),
		Position = UDim2.new(0.5, 0, 0, 12),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = C.Panel,
		Radius = UIConfig.Radius.Pill,
		StrokeColor = C.Gold,
		StrokeThickness = 2,
		Gradient = { C.PanelLight, C.Panel },
		GradientRotation = 90,
	})
	eventBanner.Visible = false
	refs.eventBanner = eventBanner

	local eventEmoji = UILib.label(eventBanner, "🎉", {
		Size = UDim2.fromOffset(44, 44),
		Position = UDim2.fromOffset(12, 9),
		Font = UIConfig.FontTitle,
		TextScaled = true,
	})
	eventEmoji.Name = "Emoji"
	refs.eventEmoji = eventEmoji

	local eventTitle = UILib.label(eventBanner, "ÉVÉNEMENT", {
		Size = UDim2.new(1, -140, 0, 20),
		Position = UDim2.fromOffset(62, 12),
		Font = UIConfig.FontBold,
		TextSize = 13,
		Color = C.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	refs.eventTitle = eventTitle

	local eventTimer = UILib.label(eventBanner, "1:00", {
		Size = UDim2.new(1, -140, 0, 18),
		Position = UDim2.fromOffset(62, 32),
		Font = UIConfig.FontTitle,
		TextSize = 15,
		Color = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	refs.eventTimer = eventTimer

	local eventBarHolder, eventBarFill = UILib.bar(eventBanner, {
		Size = UDim2.fromOffset(70, 8),
		Position = UDim2.new(1, -84, 0.5, -4),
		Color = C.Gold,
	})
	refs.eventBar = eventBarFill

	-- ============================================================
	-- COLONNE DE BOUTONS (droite)
	-- ============================================================
	local buttonPanel = Instance.new("Frame")
	buttonPanel.Name = "Buttons"
	buttonPanel.Size = UDim2.fromOffset(176, 430)
	buttonPanel.Position = UDim2.new(1, -16, 0, 96)
	buttonPanel.AnchorPoint = Vector2.new(1, 0)
	buttonPanel.BackgroundTransparency = 1
	buttonPanel.Parent = root

	local grid = Instance.new("UIGridLayout")
	grid.CellSize = UDim2.fromOffset(84, 84)
	grid.CellPadding = UDim2.fromOffset(4, 4)
	grid.SortOrder = Enum.SortOrder.LayoutOrder
	grid.FillDirection = Enum.FillDirection.Horizontal
	grid.HorizontalAlignment = Enum.HorizontalAlignment.Right
	grid.Parent = buttonPanel
	refs.buttonPanel = buttonPanel

	local buttons = {
		{ Id = "shop", Emoji = "🛒", Caption = "Boutique", Color = C.Gold },
		{ Id = "eggs", Emoji = "🥚", Caption = "Œufs", Color = C.Orange },
		{ Id = "pets", Emoji = "🐾", Caption = "Pets", Color = C.Purple },
		{ Id = "rebirth", Emoji = "🔄", Caption = "Rebirth", Color = C.Pink },
		{ Id = "worlds", Emoji = "🌍", Caption = "Mondes", Color = C.Blue },
		{ Id = "ranks", Emoji = "🏆", Caption = "Classement", Color = C.Gold },
		{ Id = "achievements", Emoji = "🏅", Caption = "Succès", Color = C.Green },
		{ Id = "daily", Emoji = "📅", Caption = "Quotidien", Color = C.Cyan },
		{ Id = "settings", Emoji = "⚙️", Caption = "Réglages", Color = C.Card },
	}

	for index, buttonInfo in ipairs(buttons) do
		local button = UILib.iconButton(buttonPanel, buttonInfo.Emoji, buttonInfo.Caption, {
			Name = "Btn_" .. buttonInfo.Id,
			Color = C.Card,
			StrokeColor = buttonInfo.Color,
		})
		button.Parent.LayoutOrder = index
		button.LayoutOrder = index
		button.MouseButton1Click:Connect(function()
			if ctx and ctx.openModal then
				ctx.openModal(buttonInfo.Id)
			end
		end)
		refs["btn_" .. buttonInfo.Id] = button
		if buttonInfo.Id == "daily" then
			local badge = button:FindFirstChild("Badge")
			if badge then
				badge.Text = "!"
				badge.TextColor3 = C.Red
			end
		end
	end

	-- ============================================================
	-- BOUTON VACUUM (bas centre)
	-- ============================================================
	local vacuumHolder = Instance.new("Frame")
	vacuumHolder.Name = "VacuumHolder"
	vacuumHolder.Size = UDim2.fromOffset(300, 76)
	vacuumHolder.Position = UDim2.new(0.5, 0, 1, -22)
	vacuumHolder.AnchorPoint = Vector2.new(0.5, 1)
	vacuumHolder.BackgroundTransparency = 1
	vacuumHolder.Parent = root

	local vacuumButton = UILib.button(vacuumHolder, "", {
		Name = "VacuumButton",
		Size = UDim2.fromOffset(280, 70),
		Position = UDim2.new(0.5, 0, 1, 0),
		AnchorPoint = Vector2.new(0.5, 1),
		Color = C.Purple,
		Radius = UIConfig.Radius.Pill,
		Gradient = { C.Purple, C.Pink },
		GradientRotation = 0,
		StrokeColor = C.White,
		StrokeThickness = 2,
	})
	refs.vacuumButton = vacuumButton

	local vacuumLabel = UILib.label(vacuumButton, "🌪️ ASPIRER", {
		Size = UDim2.fromScale(1, 0.55),
		Position = UDim2.fromScale(0, 0.08),
		Font = UIConfig.FontTitle,
		TextScaled = true,
		Color = C.Text,
		Stroke = true,
	})
	vacuumLabel.Name = "Label"
	UILib.padding(vacuumLabel, 6, 0, 20, 20)

	local vacuumSub = UILib.label(vacuumButton, "Prêt", {
		Size = UDim2.new(1, 0, 0, 20),
		Position = UDim2.fromScale(0, 0.66),
		Font = UIConfig.FontBold,
		TextSize = 12,
		Color = C.Text,
	})
	vacuumSub.Name = "Sub"
	refs.vacuumSub = vacuumSub

	local vacuumCooldownOverlay = Instance.new("Frame")
	vacuumCooldownOverlay.Name = "Cooldown"
	vacuumCooldownOverlay.Size = UDim2.fromScale(0, 1)
	vacuumCooldownOverlay.BackgroundColor3 = C.Background
	vacuumCooldownOverlay.BackgroundTransparency = 0.35
	vacuumCooldownOverlay.BorderSizePixel = 0
	vacuumCooldownOverlay.ZIndex = 7
	vacuumCooldownOverlay.Parent = vacuumButton
	UILib.corner(vacuumCooldownOverlay, UIConfig.Radius.Pill)
	refs.vacuumCooldown = vacuumCooldownOverlay

	vacuumButton.MouseButton1Click:Connect(function()
		if os.clock() < vacuumCooldownEnd then
			return
		end
		local profile = ClientState.profile
		local cooldown = Formulas.vacuumCooldown(profile)
		vacuumCooldownTotal = cooldown
		vacuumCooldownEnd = os.clock() + cooldown
		Net.event("VacuumRequest"):FireServer()
		UILib.pulse(vacuumButton, 1.1)
	end)

	-- ============================================================
	-- INDICATEURS (bas gauche)
	-- ============================================================
	local indicators = Instance.new("Frame")
	indicators.Name = "Indicators"
	indicators.Size = UDim2.fromOffset(280, 60)
	indicators.Position = UDim2.new(0, 16, 1, -90)
	indicators.AnchorPoint = Vector2.new(0, 1)
	indicators.BackgroundTransparency = 1
	indicators.Parent = root
	UILib.list(indicators, { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Left })

	local autoChip = UILib.panel(indicators, {
		Name = "AutoChip",
		Size = UDim2.fromOffset(270, 30),
		Color = C.Panel,
		Radius = UIConfig.Radius.Pill,
		LayoutOrder = 1,
		StrokeColor = C.Green,
		StrokeTransparency = 0.5,
	})
	local autoLabel = UILib.label(autoChip, "🌀 Absorption auto : inactive", {
		Size = UDim2.fromScale(1, 1),
		Font = UIConfig.FontBold,
		TextSize = 12,
		Color = C.TextDim,
	})
	autoLabel.Name = "Text"
	UILib.padding(autoChip, 2, 2, 10, 10)
	refs.autoLabel = autoLabel
	refs.autoChip = autoChip

	local boostChip = UILib.panel(indicators, {
		Name = "BoostChip",
		Size = UDim2.fromOffset(270, 30),
		Color = C.Panel,
		Radius = UIConfig.Radius.Pill,
		LayoutOrder = 2,
		StrokeColor = C.Orange,
		StrokeTransparency = 0.5,
	})
	local boostLabel = UILib.label(boostChip, "", {
		Size = UDim2.fromScale(1, 1),
		Font = UIConfig.FontBold,
		TextSize = 12,
		Color = C.Orange,
	})
	boostLabel.Name = "Text"
	UILib.padding(boostChip, 2, 2, 10, 10)
	boostChip.Visible = false
	refs.boostChip = boostChip
	refs.boostLabel = boostLabel

	-- ============================================================
	-- MISE À JOUR
	-- ============================================================
	local function refreshProfile(profile)
		local power = profile.power or 0
		if power ~= currentPower then
			local from = currentPower
			currentPower = power
			if not refs.lastPowerUpdate or os.clock() - refs.lastPowerUpdate > 0.06 then
				refs.lastPowerUpdate = os.clock()
				UILib.animateNumber(powerValue, from, power, function(value)
					return Formulas.formatNumber(math.max(0, value))
				end, 0.35)
			end
		end
		currentCoins = profile.coins or 0
		coinValue.Text = Formulas.formatNumber(currentCoins)
		rebirthValue.Text = tostring(profile.rebirths or 0)
		multLabel.Text = "×" .. string.format("%.2f", ClientState.getPowerMultiplier())

		local tier, tierIndex = ClientState.getTier()
		tierLabel.Text = string.format("%s %s  (Tier %d/%d)", tier.Emoji, tier.Name, tierIndex, #GameConfig.Transformations)
		tierLabel.TextColor3 = tier.Aura
		UILib.setBar(tierBarFill, ClientState.getTierProgress())
		tierBarFill.BackgroundColor3 = tier.Aura
		local nextTier = ClientState.getNextTier()
		if nextTier then
			tierProgressLabel.Text = string.format("%s ⚡ → %s %s", Formulas.formatNumber(nextTier.MinPower), nextTier.Emoji, nextTier.Name)
		else
			tierProgressLabel.Text = "🏆 Transformation MAXIMALE atteinte !"
		end

		-- Auto collect
		local autoLevel = ClientState.getUpgradeLevel("AutoCollect")
		local hasPass = profile.gamePasses and profile.gamePasses.AutoCollect
		if autoLevel > 0 or hasPass then
			autoLabel.Text = string.format("🌀 Absorption auto : ACTIVE (niv. %d)", math.max(autoLevel, 1))
			autoLabel.TextColor3 = C.Green
		else
			autoLabel.Text = "🌀 Absorption auto : inactive (Boutique)"
			autoLabel.TextColor3 = C.TextDim
		end

		-- Badge quotidien
		local dailyButton = refs.btn_daily
		local badge = dailyButton and dailyButton:FindFirstChild("Badge")
		if badge then
			badge.Text = ClientState.dailyAvailable and "!" or ""
		end
	end

	function HudUI.refresh()
		refreshProfile(ClientState.profile)
	end

	ClientState.Signals.Profile:Connect(refreshProfile)
	ClientState.Signals.Event:Connect(function(eventId, endsAt)
		local eventData = eventId and GameConfig.Events[eventId]
		if eventData then
			eventBanner.Visible = true
			eventEmoji.Text = eventData.Emoji
			eventTitle.Text = string.upper(eventData.Name)
			eventTitle.TextColor3 = eventData.Color
			eventTimer.TextColor3 = eventData.Color
			UILib.pulse(eventBanner, 1.04)
		else
			eventBanner.Visible = false
		end
	end)
	ClientState.Signals.Boost:Connect(function(mult, endsAt)
		ClientState.boostMult = mult
		ClientState.boostEndsAt = endsAt
	end)
	ClientState.Signals.Daily:Connect(function(available)
		ClientState.dailyAvailable = available
		refreshProfile(ClientState.profile)
	end)
	ClientState.Signals.World:Connect(function()
		refreshProfile(ClientState.profile)
	end)

	-- Boucle d'animation (compte à rebours, cooldown, boost)
	RunService.Heartbeat:Connect(function()
		if ClientState.eventIsActive() then
			local remaining = ClientState.eventRemaining()
			eventTimer.Text = Formulas.formatTime(remaining)
			local total = GameConfig.Events[ClientState.eventId] and GameConfig.Events[ClientState.eventId].Duration or 60
			UILib.setBar(eventBarFill, remaining / total)
			if remaining <= 0 then
				eventBanner.Visible = false
			end
		end

		-- Cooldown du vacuum
		local now = os.clock()
		if now < vacuumCooldownEnd then
			local remaining = vacuumCooldownEnd - now
			vacuumCooldownOverlay.Size = UDim2.fromScale(remaining / math.max(vacuumCooldownTotal, 0.1), 1)
			vacuumSub.Text = string.format("Recharge… %.1fs", remaining)
			vacuumLabel.TextColor3 = C.TextDim
		else
			vacuumCooldownOverlay.Size = UDim2.fromScale(0, 1)
			local profile = ClientState.profile
			vacuumSub.Text = string.format("Rayon %d • %ds", math.floor(Formulas.vacuumRadius(profile)), math.floor(Formulas.vacuumCooldown(profile)))
			vacuumLabel.TextColor3 = C.Text
		end

		-- Boost
		if ClientState.boostEndsAt > os.time() then
			boostChip.Visible = true
			boostLabel.Text = string.format("🚀 Boost ×%s — %s", tostring(ClientState.boostMult), Formulas.formatTime(ClientState.boostEndsAt - os.time()))
		elseif boostChip.Visible then
			boostChip.Visible = false
		end
	end)

	refreshProfile(ClientState.profile)
	print("[HudUI] Construit")
end

return HudUI
