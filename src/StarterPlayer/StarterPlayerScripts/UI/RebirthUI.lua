--!strict
--[[
	RebirthUI  |  StarterPlayer.StarterPlayerScripts.UI.RebirthUI
	------------------------------------------------------------------
	Écran de Rebirth : coût, multiplicateur actuel/gagné, récompenses,
	prochains paliers et bouton d'action.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local Formulas = require(Modules:WaitForChild("Formulas"))
local Net = require(Modules:WaitForChild("Net"))

local UIConfig = require(script.Parent.UIConfig)
local UILib = require(script.Parent.UILib)
local ClientState = require(script.Parent.Parent.Controllers.ClientState)

local RebirthUI = {}

local C = UIConfig.Colors

function RebirthUI.show(ctx)
	local frame, content = UILib.showModal(ctx.screenGui, "rebirth", "🔄 REBIRTH", { Size = UDim2.fromOffset(700, 560) })
	UILib.clearContent(content)

	-- Carte principale
	local hero = UILib.panel(content, {
		Name = "Hero",
		Size = UDim2.new(1, -8, 0, 210),
		Color = C.Panel,
		Radius = UIConfig.Radius.Large,
		LayoutOrder = 1,
		StrokeColor = C.Pink,
		StrokeThickness = 2,
		Gradient = { C.PanelLight, C.Panel },
		GradientRotation = 120,
	})

	local orb = UILib.panel(hero, {
		Size = UDim2.fromOffset(110, 110),
		Position = UDim2.fromOffset(24, 42),
		Color = C.Pink,
		Radius = UIConfig.Radius.Pill,
		StrokeColor = C.Gold,
		StrokeThickness = 3,
	})
	local orbText = UILib.label(orb, "🔄", {
		Size = UDim2.fromScale(1, 1),
		Font = UIConfig.FontTitle,
		TextScaled = true,
	})
	orbText.Name = "Emoji"
	UILib.padding(orb, 16)

	local rebirthTitle = UILib.label(hero, "Rebirth 0", {
		Size = UDim2.new(1, -200, 0, 34),
		Position = UDim2.fromOffset(154, 20),
		Font = UIConfig.FontTitle,
		TextSize = 26,
		Color = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	rebirthTitle.Name = "RebirthTitle"

	local multText = UILib.label(hero, "", {
		Size = UDim2.new(1, -200, 0, 22),
		Position = UDim2.fromOffset(154, 56),
		Font = UIConfig.FontBold,
		TextSize = 14,
		Color = C.Purple,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	multText.Name = "Multiplier"

	local costText = UILib.label(hero, "", {
		Size = UDim2.new(1, -200, 0, 22),
		Position = UDim2.fromOffset(154, 80),
		Font = UIConfig.FontBody,
		TextSize = 13,
		Color = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	costText.Name = "Cost"

	local progressHolder, progressFill = UILib.bar(hero, {
		Size = UDim2.new(1, -190, 0, 16),
		Position = UDim2.fromOffset(154, 110),
		Color = C.Pink,
	})
	progressHolder.Name = "Progress"

	local progressLabel = UILib.label(hero, "", {
		Size = UDim2.new(1, -190, 0, 18),
		Position = UDim2.fromOffset(154, 130),
		Font = UIConfig.FontSmall,
		TextSize = 11,
		Color = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	progressLabel.Name = "ProgressLabel"

	local actionButton = UILib.button(hero, "EFFECTUER LE REBIRTH", {
		Name = "Action",
		Size = UDim2.new(1, -190, 0, 48),
		Position = UDim2.fromOffset(154, 150),
		Color = C.Pink,
		TextColor = C.Text,
		Radius = UIConfig.Radius.Pill,
		Gradient = { C.Pink, C.Purple },
	})
	actionButton.MouseButton1Click:Connect(function()
		Net.event("RebirthRequest"):FireServer()
	end)

	-- Informations / paliers
	local infoCard = UILib.card(content, {
		Name = "Info",
		Size = UDim2.new(1, -8, 0, 120),
		Color = C.Card,
		LayoutOrder = 2,
	})
	UILib.padding(infoCard, 12)
	local infoTitle = UILib.label(infoCard, "COMMENT ÇA MARCHE", {
		Size = UDim2.new(1, 0, 0, 20),
		Font = UIConfig.FontBold,
		TextSize = 13,
		Color = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	local infoBody = UILib.label(infoCard, "", {
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 1, -24),
		Font = UIConfig.FontSmall,
		TextSize = 12,
		Color = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top,
		TextWrapped = true,
	})
	infoBody.Name = "Body"

	-- Paliers de titres
	local tiersCard = UILib.card(content, {
		Name = "Titles",
		Size = UDim2.new(1, -8, 0, 0),
		Color = C.Card,
		LayoutOrder = 3,
	})
	tiersCard.AutomaticSize = Enum.AutomaticSize.Y
	UILib.padding(tiersCard, 12)
	local tiersHolder = Instance.new("Frame")
	tiersHolder.Name = "List"
	tiersHolder.Size = UDim2.new(1, 0, 0, 0)
	tiersHolder.AutomaticSize = Enum.AutomaticSize.Y
	tiersHolder.BackgroundTransparency = 1
	tiersHolder.Parent = tiersCard
	UILib.grid(tiersHolder, UDim2.fromOffset(120, 32), UDim2.fromOffset(8, 8))

	for index, title in ipairs(GameConfig.Titles) do
		local chip = UILib.panel(tiersHolder, {
			Size = UDim2.fromOffset(120, 32),
			Color = C.PanelLight,
			Radius = UIConfig.Radius.Pill,
			LayoutOrder = index,
		})
		chip.Name = "TitleChip_" .. title.Id
		local label = UILib.label(chip, string.format("%s (🔄%d)", title.Name, title.Rebirth), {
			Size = UDim2.fromScale(1, 1),
			Font = UIConfig.FontBold,
			TextSize = 10,
			Color = C.TextDim,
		})
		label.Name = "Text"
		UILib.padding(chip, 0, 0, 4, 4)
	end

	local function refresh()
		local profile = ClientState.profile
		local rebirths = profile.rebirths or 0
		local maxRebirths = GameConfig.Rebirth.MaxRebirths
		local cost = Formulas.rebirthCost(rebirths)
		local power = profile.power or 0

		rebirthTitle.Text = string.format("Rebirth %d / %d", rebirths, maxRebirths)
		multText.Text = string.format(
			"Multiplicateur actuel ×%s  →  ×%s",
			string.format("%.2f", Formulas.rebirthMultiplier(rebirths)),
			string.format("%.2f", Formulas.rebirthMultiplier(math.min(rebirths + 1, maxRebirths)))
		)
		local maxed = rebirths >= maxRebirths
		if maxed then
			costText.Text = "🏆 Tu as atteint le Rebirth maximum ! Respect."
			actionButton.Text = "MAXIMUM ATTEINT"
			actionButton.BackgroundColor3 = C.PanelLight
			actionButton.TextColor3 = C.TextDim
			UILib.setBar(progressFill, 1)
			progressLabel.Text = ""
		else
			costText.Text = string.format("Coût : %s ⚡ (tu as %s)", Formulas.formatNumber(cost), Formulas.formatNumber(power))
			local ratio = math.clamp(power / cost, 0, 1)
			UILib.setBar(progressFill, ratio)
			progressLabel.Text = ratio >= 1
				and string.format("Prêt ! Récompense : +%s 🪙", Formulas.formatNumber(Formulas.rebirthCoinReward(rebirths + 1)))
				or string.format("Encore %s ⚡", Formulas.formatNumber(cost - power))
			actionButton.Text = ratio >= 1 and "EFFECTUER LE REBIRTH 🔄" or "PAS ASSEZ DE PUISSANCE"
			actionButton.BackgroundColor3 = ratio >= 1 and C.Pink or C.PanelLight
			actionButton.TextColor3 = ratio >= 1 and C.Text or C.TextDim
		end

		infoBody.Text = string.format(
			"Le Rebirth remet ta puissance à zéro mais te donne :\n• un multiplicateur PERMANENT (+%d%% par rebirth)\n• des pièces (%s + %s × rebirth)\n• l'accès aux mondes supérieurs et à de nouveaux titres\n\nTes pets et tes améliorations sont CONSERVÉS.",
			math.floor(GameConfig.Rebirth.MultPerRebirth * 100),
			Formulas.formatNumber(GameConfig.Rebirth.CoinRewardBase),
			Formulas.formatNumber(GameConfig.Rebirth.CoinRewardPerRebirth)
		)

		for _, title in ipairs(GameConfig.Titles) do
			local chip = tiersHolder:FindFirstChild("TitleChip_" .. title.Id)
			local text = chip and chip:FindFirstChild("Text")
			if chip and text then
				local unlocked = rebirths >= title.Rebirth
				text.TextColor3 = unlocked and title.Color or C.TextDim
				chip.BackgroundColor3 = unlocked and C.Card or C.PanelLight
			end
		end
	end

	refresh()
	return refresh
end

return RebirthUI
