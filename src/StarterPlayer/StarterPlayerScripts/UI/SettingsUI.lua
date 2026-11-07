--!strict
--[[
	SettingsUI  |  StarterPlayer.StarterPlayerScripts.UI.SettingsUI
	------------------------------------------------------------------
	Réglages (music, sfx, effets, particules, shake, pets visibles),
	sélection du titre, statistiques du joueur et crédits.
	Chaque réglage est envoyé au serveur (RemoteEvent SetSetting) pour
	être sauvegardé.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local Formulas = require(Modules:WaitForChild("Formulas"))
local Net = require(Modules:WaitForChild("Net"))

local UIConfig = require(script.Parent.UIConfig)
local UILib = require(script.Parent.UILib)
local ClientState = require(script.Parent.Parent.Controllers.ClientState)

local SettingsUI = {}

local C = UIConfig.Colors

local SETTINGS = {
	{ Key = "music", Label = "🎵 Musique", Desc = "Musique d'ambiance des mondes" },
	{ Key = "sfx", Label = "🔊 Effets sonores", Desc = "Sons d'absorption, boutons, événements" },
	{ Key = "effects", Label = "✨ Effets visuels", Desc = "Particules, flashs, animations d'objets" },
	{ Key = "particles", Label = "💫 Particules", Desc = "Désactive pour + de FPS sur mobile" },
	{ Key = "cameraShake", Label = "📳 Secousse caméra", Desc = "Secousses lors des grosses actions" },
	{ Key = "damageNumbers", Label = "🔢 Nombres flottants", Desc = "Affiche +puissance à chaque absorption" },
	{ Key = "petsVisible", Label = "🐾 Afficher mes pets", Desc = "Masque les pets 3D (performance)" },
}

local function buildToggle(parent: Instance, setting, layoutOrder: number)
	local row = UILib.card(parent, {
		Name = "Setting_" .. setting.Key,
		Size = UDim2.new(1, -8, 0, 60),
		Color = C.Card,
		LayoutOrder = layoutOrder,
	})

	UILib.label(row, setting.Label, {
		Size = UDim2.new(1, -180, 0, 22),
		Position = UDim2.fromOffset(14, 8),
		Font = UIConfig.FontBold,
		TextSize = 14,
		Color = C.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local desc = UILib.label(row, setting.Desc, {
		Size = UDim2.new(1, -180, 0, 18),
		Position = UDim2.fromOffset(14, 30),
		Font = UIConfig.FontSmall,
		TextSize = 11,
		Color = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	desc.Name = "Desc"

	local toggle = UILib.button(row, "", {
		Size = UDim2.fromOffset(70, 34),
		Position = UDim2.new(1, -84, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Color = C.Green,
		Radius = UIConfig.Radius.Pill,
	})

	local knob = UILib.panel(toggle, {
		Size = UDim2.fromOffset(26, 26),
		Position = UDim2.new(1, -30, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Color = C.White,
		Radius = UIConfig.Radius.Pill,
		Stroke = false,
	})
	knob.Name = "Knob"

	local state = ClientState.getSetting(setting.Key)

	local function apply()
		toggle.BackgroundColor3 = state and C.Green or C.PanelLight
		knob.Position = state and UDim2.new(1, -30, 0.5, 0) or UDim2.new(0, 4, 0.5, 0)
		-- application locale immédiate (le serveur sauvegarde aussi)
		if ClientState.profile.settings then
			ClientState.profile.settings[setting.Key] = state
		end
		if setting.Key == "music" then
			ClientState.Signals.Sound:Fire("click", 0.1)
		end
	end

	toggle.MouseButton1Click:Connect(function()
		state = not state
		apply()
		Net.event("SetSetting"):FireServer(setting.Key, state)
	end)

	apply()
	return function()
		local profileState = ClientState.getSetting(setting.Key)
		if profileState ~= state then
			state = profileState
			apply()
		end
	end
end

function SettingsUI.show(ctx)
	local frame, content = UILib.showModal(ctx.screenGui, "settings", "⚙️ RÉGLAGES", { Size = UDim2.fromOffset(720, 580) })
	UILib.clearContent(content)

	local refreshers = {}

	-- Section paramètres
	local settingsSection = UILib.card(content, {
		Name = "SettingsSection",
		Size = UDim2.new(1, -8, 0, 0),
		Color = C.Panel,
		LayoutOrder = 0,
	})
	settingsSection.AutomaticSize = Enum.AutomaticSize.Y
	UILib.padding(settingsSection, 10)
	local settingsHolder = Instance.new("Frame")
	settingsHolder.Name = "Holder"
	settingsHolder.Size = UDim2.new(1, 0, 0, 0)
	settingsHolder.AutomaticSize = Enum.AutomaticSize.Y
	settingsHolder.BackgroundTransparency = 1
	settingsHolder.Parent = settingsSection
	UILib.list(settingsHolder, { Padding = UDim.new(0, 8) })

	local titleHeader = UILib.label(settingsHolder, "PARAMÈTRES", {
		Size = UDim2.new(1, 0, 0, 20),
		Font = UIConfig.FontBold,
		TextSize = 12,
		Color = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
	})

	for index, setting in ipairs(SETTINGS) do
		table.insert(refreshers, buildToggle(settingsHolder, setting, index))
	end

	-- Section titres
	local titlesSection = UILib.card(content, {
		Name = "TitlesSection",
		Size = UDim2.new(1, -8, 0, 0),
		Color = C.Panel,
		LayoutOrder = 1,
	})
	titlesSection.AutomaticSize = Enum.AutomaticSize.Y
	UILib.padding(titlesSection, 10)

	local titlesHolder = Instance.new("Frame")
	titlesHolder.Name = "Holder"
	titlesHolder.Size = UDim2.new(1, 0, 0, 0)
	titlesHolder.AutomaticSize = Enum.AutomaticSize.Y
	titlesHolder.BackgroundTransparency = 1
	titlesHolder.Parent = titlesSection
	UILib.list(titlesHolder, { Padding = UDim.new(0, 8) })

	UILib.label(titlesHolder, "TITRE AFFICHÉ AU-DESSUS DE TA TÊTE", {
		Size = UDim2.new(1, 0, 0, 20),
		Font = UIConfig.FontBold,
		TextSize = 12,
		Color = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
		LayoutOrder = 0,
	})

	local titleButtons = {}
	for index, title in ipairs(GameConfig.Titles) do
		local button = UILib.button(titlesHolder, string.format("%s  (🔄 %d)", title.Name, title.Rebirth), {
			Size = UDim2.new(1, -8, 0, 40),
			Color = C.Card,
			Radius = UIConfig.Radius.Medium,
			TextSize = 13,
		})
		button.LayoutOrder = index
		button:SetAttribute("TitleId", title.Id)
		button.MouseButton1Click:Connect(function()
			Net.event("SelectTitle"):FireServer(title.Id)
		end)
		titleButtons[title.Id] = button
	end

	-- Section statistiques
	local statsSection = UILib.card(content, {
		Name = "StatsSection",
		Size = UDim2.new(1, -8, 0, 0),
		Color = C.Panel,
		LayoutOrder = 2,
	})
	statsSection.AutomaticSize = Enum.AutomaticSize.Y
	UILib.padding(statsSection, 10)
	local statsLabel = UILib.label(statsSection, "", {
		Size = UDim2.new(1, 0, 0, 0),
		Font = UIConfig.FontSmall,
		TextSize = 12,
		Color = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
	})
	statsLabel.Name = "Text"
	statsLabel.AutomaticSize = Enum.AutomaticSize.Y
	statsLabel.TextYAlignment = Enum.TextYAlignment.Top

	local function refresh()
		for _, refreshFn in ipairs(refreshers) do
			pcall(refreshFn)
		end

		local profile = ClientState.profile
		local rebirths = profile.rebirths or 0
		for _, title in ipairs(GameConfig.Titles) do
			local button = titleButtons[title.Id]
			if button then
				local unlocked = rebirths >= title.Rebirth
				local selected = profile.titleSelected == title.Id
				button.Text = string.format("%s%s%s  (🔄 %d)", selected and "✅ " or "", unlocked and "" or "🔒 ", title.Name, title.Rebirth)
				button.TextColor3 = unlocked and title.Color or C.TextDim
				button.BackgroundColor3 = selected and C.PanelLight or C.Card
			end
		end

		statsLabel.Text = string.format(
			"📊 TES STATISTIQUES\n• Puissance actuelle : %s ⚡\n• Record de puissance : %s ⚡\n• Puissance totale cumulée : %s ⚡\n• Objets absorbés : %s\n• Œufs ouverts : %s\n• Pets possédés : %d\n• Fusions : %s\n• Rebirths : %d\n• Temps de jeu : %s\n• Multiplicateur total : ×%s",
			Formulas.formatNumber(profile.power or 0),
			Formulas.formatNumber(profile.bestPower or 0),
			Formulas.formatNumber(profile.totalPower or 0),
			Formulas.formatNumber((profile.stats and profile.stats.collected) or 0),
			Formulas.formatNumber((profile.stats and profile.stats.eggsOpened) or 0),
			#(profile.pets or {}),
			Formulas.formatNumber((profile.stats and profile.stats.fusions) or 0),
			rebirths,
			Formulas.formatTime(profile.playtime or 0),
			string.format("%.2f", ClientState.getPowerMultiplier())
		)
	end

	refresh()
	return refresh
end

return SettingsUI
