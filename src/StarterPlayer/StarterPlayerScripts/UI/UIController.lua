--!strict
--[[
	UIController  |  StarterPlayer.StarterPlayerScripts.UI.UIController
	------------------------------------------------------------------
	Chef d'orchestre de l'interface :
	  • crée le ScreenGui principal ("MainUI")
	  • construit le HUD
	  • gère la pile de modales (une seule ouverte à la fois)
	  • rafraîchit l'écran ouvert (2x/seconde) sans reconstruire le DOM
	  • écran de chargement
  • file de toasts
	  • notification centrale de résultat d'œuf (animation de révélation)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local Formulas = require(Modules:WaitForChild("Formulas"))

local UIConfig = require(script.Parent.UIConfig)
local UILib = require(script.Parent.UILib)
local ClientState = require(script.Parent.Parent.Controllers.ClientState)

local HudUI = require(script.Parent.HudUI)
local ShopUI = require(script.Parent.ShopUI)
local PetsUI = require(script.Parent.PetsUI)
local RebirthUI = require(script.Parent.RebirthUI)
local WorldsUI = require(script.Parent.WorldsUI)
local LeaderboardUI = require(script.Parent.LeaderboardUI)
local AchievementsUI = require(script.Parent.AchievementsUI)
local SettingsUI = require(script.Parent.SettingsUI)
local DailyUI = require(script.Parent.DailyUI)

local UIController = {}

local C = UIConfig.Colors

local screenGui: ScreenGui? = nil
local toastStack: Frame? = nil
local activeRefresh: (() -> ())? = nil
local lastRefresh = 0
local eggRevealHolder: Frame? = nil
local eggQueue = {}
local eggRevealing = false

-- ============================================================
-- MODALES
-- ============================================================
local screens = {
	shop = function(ctx) return ShopUI.show(ctx) end,
	eggs = function(ctx) return PetsUI.show(ctx, "eggs") end,
	pets = function(ctx) return PetsUI.show(ctx, "pets") end,
	rebirth = function(ctx) return RebirthUI.show(ctx) end,
	worlds = function(ctx) return WorldsUI.show(ctx) end,
	ranks = function(ctx) return LeaderboardUI.show(ctx) end,
	achievements = function(ctx) return AchievementsUI.show(ctx) end,
	settings = function(ctx) return SettingsUI.show(ctx) end,
	daily = function(ctx) return DailyUI.show(ctx) end,
}

local function openModal(id: string)
	if not screenGui then
		return
	end
	local screen = screens[id]
	if not screen then
		return
	end
	local ctx = { screenGui = screenGui, openModal = openModal }
	local ok, refresh = pcall(screen, ctx)
	if not ok then
		warn("[UIController] erreur d'ouverture de " .. id .. " : " .. tostring(refresh))
		return
	end
	activeRefresh = type(refresh) == "function" and refresh or nil
	lastRefresh = 0
	UILib.playClick("pop")
end

-- ============================================================
-- RÉVÉLATION D'ŒUF
-- ============================================================
local function showNextEgg()
	if eggRevealing or #eggQueue == 0 or not screenGui then
		return
	end
	eggRevealing = true
	local result = table.remove(eggQueue, 1)

	local rarity = GameConfig.Rarities[result.rarity] or GameConfig.Rarities.Common
	local petInfo = GameConfig.Pets[result.petId] or { Name = result.name or "?", Emoji = "🐾", Mult = 0 }

	local holder = Instance.new("Frame")
	holder.Name = "EggReveal"
	holder.Size = UDim2.fromScale(1, 1)
	holder.BackgroundColor3 = C.Background
	holder.BackgroundTransparency = 0.35
	holder.BorderSizePixel = 0
	holder.ZIndex = 60
	holder.Parent = screenGui
	eggRevealHolder = holder

	local card = Instance.new("Frame")
	card.Size = UDim2.fromOffset(420, 320)
	card.Position = UDim2.fromScale(0.5, 0.5)
	card.AnchorPoint = Vector2.new(0.5, 0.5)
	card.BackgroundColor3 = C.Panel
	card.BorderSizePixel = 0
	card.ZIndex = 61
	card.Parent = holder
	UILib.corner(card, UIConfig.Radius.Large)
	UILib.stroke(card, rarity.Color, 4, 0)
	UILib.gradient(card, rarity.Color:Lerp(C.Background, 0.8), C.Background, 90)

	local cardScale = Instance.new("UIScale")
	cardScale.Scale = 0.6
	cardScale.Parent = card
	UILib.tween(cardScale, { Scale = 1 }, TweenInfo.new(0.35, Enum.EasingStyle.Back, Enum.EasingDirection.Out))

	local title = UILib.label(card, result.isNew and "NOUVEAU PET !" or "PET OBTENU !", {
		Size = UDim2.new(1, 0, 0, 34),
		Position = UDim2.fromOffset(0, 18),
		Font = UIConfig.FontTitle,
		TextSize = 24,
		Color = rarity.Color,
		ZIndex = 62,
	})
	title.Name = "Title"

	local emoji = UILib.label(card, petInfo.Emoji or "🐾", {
		Size = UDim2.fromOffset(120, 120),
		Position = UDim2.fromOffset(150, 58),
		Font = UIConfig.FontTitle,
		TextScaled = true,
		ZIndex = 62,
	})
	emoji.Name = "Emoji"
	UILib.pulse(emoji, 1.2)

	local name = UILib.label(card, petInfo.Name, {
		Size = UDim2.new(1, -40, 0, 30),
		Position = UDim2.fromOffset(20, 182),
		Font = UIConfig.FontTitle,
		TextSize = 22,
		Color = C.Text,
		TextWrapped = true,
		ZIndex = 62,
	})
	name.Name = "Name"

	local rarityLabel = UILib.label(card, string.upper(rarity.Name), {
		Size = UDim2.new(1, -40, 0, 20),
		Position = UDim2.fromOffset(20, 212),
		Font = UIConfig.FontBold,
		TextSize = 14,
		Color = rarity.Color,
		ZIndex = 62,
	})
	rarityLabel.Name = "Rarity"

	local multLabel = UILib.label(card, string.format("Multiplicateur ×%s", string.format("%.2f", petInfo.Mult or 0)), {
		Size = UDim2.new(1, -40, 0, 22),
		Position = UDim2.fromOffset(20, 234),
		Font = UIConfig.FontBold,
		TextSize = 14,
		Color = C.Gold,
		ZIndex = 62,
	})
	multLabel.Name = "Mult"

	local closeButton = UILib.button(card, "SUPER !", {
		Size = UDim2.fromOffset(240, 46),
		Position = UDim2.fromOffset(90, 262),
		Color = rarity.Color,
		TextColor = C.TextDark,
		Radius = UIConfig.Radius.Pill,
		ZIndex = 63,
	})

	local function closeReveal()
		if not holder.Parent then
			return
		end
		UILib.tween(cardScale, { Scale = 0.7 }, TweenInfo.new(0.18))
		UILib.tween(holder, { BackgroundTransparency = 1 }, TweenInfo.new(0.18))
		task.delay(0.2, function()
			holder:Destroy()
			eggRevealing = false
			task.delay(0.1, showNextEgg)
		end)
	end

	closeButton.MouseButton1Click:Connect(closeReveal)

	-- Cliquer n'importe où ferme la révélation (texture invisible plein écran)
	local blocker = Instance.new("TextButton")
	blocker.Name = "Blocker"
	blocker.Size = UDim2.fromScale(1, 1)
	blocker.BackgroundTransparency = 1
	blocker.Text = ""
	blocker.AutoButtonColor = false
	blocker.ZIndex = 60
	blocker.Parent = holder
	blocker.MouseButton1Click:Connect(closeReveal)

	ClientState.Signals.Sound:Fire("rarity", 1)
	task.delay(4.5, function()
		if holder.Parent then
			closeReveal()
		end
	end)
end

function UIController.queueEggReveal(result)
	table.insert(eggQueue, result)
	showNextEgg()
end

-- ============================================================
-- ÉCRAN DE CHARGEMENT
-- ============================================================
local function buildLoadingScreen(): Frame
	local loading = Instance.new("Frame")
	loading.Name = "Loading"
	loading.Size = UDim2.fromScale(1, 1)
	loading.BackgroundColor3 = C.Background
	loading.BorderSizePixel = 0
	loading.ZIndex = 100
	loading.Parent = screenGui

	local logo = UILib.label(loading, "NOOB ➜ GOD", {
		Size = UDim2.new(1, 0, 0, 80),
		Position = UDim2.fromScale(0, 0.38),
		Font = UIConfig.FontTitle,
		TextScaled = true,
		Color = C.Gold,
		Stroke = true,
		ZIndex = 101,
	})
	logo.Name = "Logo"
	UILib.padding(logo, 0, 0, 60, 60)

	local sub = UILib.label(loading, "SIMULATOR", {
		Size = UDim2.new(1, 0, 0, 40),
		Position = UDim2.fromScale(0, 0.47),
		Font = UIConfig.FontTitle,
		TextScaled = true,
		Color = C.Pink,
		ZIndex = 101,
	})
	UILib.padding(sub, 0, 0, 120, 120)

	local barHolder, barFill = UILib.bar(loading, {
		Size = UDim2.new(0, 360, 0, 12),
		Position = UDim2.fromScale(0.5, 0.62),
		Color = C.Green,
	})
	barHolder.AnchorPoint = Vector2.new(0.5, 0.5)
	barHolder.ZIndex = 101
	barFill.Size = UDim2.fromScale(0.05, 1)
	UILib.tween(barFill, { Size = UDim2.fromScale(1, 1) }, TweenInfo.new(1.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))

	local status = UILib.label(loading, "Chargement de tes données…", {
		Size = UDim2.new(1, 0, 0, 24),
		Position = UDim2.fromScale(0, 0.67),
		Font = UIConfig.FontBold,
		TextSize = 14,
		Color = C.TextDim,
		ZIndex = 101,
	})
	status.Name = "Status"

	return loading
end

function UIController.hideLoading()
	local loading = screenGui and screenGui:FindFirstChild("Loading")
	if loading then
		UILib.tween(loading, { BackgroundTransparency = 1 }, TweenInfo.new(0.4))
		for _, descendant in ipairs(loading:GetDescendants()) do
			if descendant:IsA("TextLabel") then
				UILib.tween(descendant, { TextTransparency = 1 }, TweenInfo.new(0.3))
			elseif descendant:IsA("Frame") then
				UILib.tween(descendant, { BackgroundTransparency = 1 }, TweenInfo.new(0.3))
			end
		end
		task.delay(0.5, function()
			loading:Destroy()
		end)
	end
end

-- ============================================================
-- DÉMARRAGE
-- ============================================================
function UIController.start()
	local gui = Instance.new("ScreenGui")
	gui.Name = "MainUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = true
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.DisplayOrder = 10
	gui.Parent = Players.LocalPlayer:WaitForChild("PlayerGui")
	screenGui = gui

	buildLoadingScreen()

	-- Pile de toasts (haut droite sous le HUD)
	local stack = Instance.new("Frame")
	stack.Name = "ToastStack"
	stack.Size = UDim2.fromOffset(360, 280)
	stack.Position = UDim2.new(1, -16, 1, -110)
	stack.AnchorPoint = Vector2.new(1, 1)
	stack.BackgroundTransparency = 1
	stack.ZIndex = 80 -- visible même quand une modale est ouverte
	stack.Parent = gui
	toastStack = stack
	UILib.setToastStack(stack)

	HudUI.start(gui, { openModal = openModal })

	-- Rafraîchit l'écran ouvert
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if activeRefresh and now - lastRefresh > 0.5 then
			lastRefresh = now
			if UILib.getOpenModal() then
				local ok, err = pcall(activeRefresh)
				if not ok then
					warn("[UIController] refresh : " .. tostring(err))
				end
			else
				activeRefresh = nil
			end
		end
	end)

	print("[UIController] Construit")
	return gui
end

function UIController.getScreenGui()
	return screenGui
end

function UIController.toast(text: string, color: Color3?, icon: string?)
	UILib.toast(text, color, icon)
end

return UIController
