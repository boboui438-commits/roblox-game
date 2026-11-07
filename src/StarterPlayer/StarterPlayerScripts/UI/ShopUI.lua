--!strict
--[[
	ShopUI  |  StarterPlayer.StarterPlayerScripts.UI.ShopUI
	------------------------------------------------------------------
	Boutique en 3 onglets :
	  • Améliorations (pièces)   -> remotes BuyUpgrade (validés serveur)
	  • Game Passes (Robux)      -> MarketplaceService:PromptGamePassPurchase
	  • Boosts (Dev Products)    -> MarketplaceService:PromptProductPurchase

	Le client n'accorde JAMAIS rien : il envoie une demande ou ouvre le
	menu d'achat Roblox. Les récompenses sont données par le serveur.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local Formulas = require(Modules:WaitForChild("Formulas"))
local Net = require(Modules:WaitForChild("Net"))

local UIConfig = require(script.Parent.UIConfig)
local UILib = require(script.Parent.UILib)
local ClientState = require(script.Parent.Parent.Controllers.ClientState)

local ShopUI = {}

local C = UIConfig.Colors

local UPGRADE_ORDER = { "PowerMult", "CoinMult", "AutoCollect", "Vacuum", "WalkSpeed", "PetSlots" }

-- ============================================================
-- CARTES D'AMÉLIORATION
-- ============================================================
local function buildUpgradeCard(parent: Instance, upgradeId: string, layoutOrder: number)
	local upgrade = GameConfig.Upgrades[upgradeId]
	local card = UILib.card(parent, {
		Name = "Upgrade_" .. upgradeId,
		Size = UDim2.new(1, -8, 0, 92),
		Color = C.Card,
		LayoutOrder = layoutOrder,
	})

	local iconBox = UILib.panel(card, {
		Size = UDim2.fromOffset(62, 62),
		Position = UDim2.fromOffset(12, 15),
		Color = C.Panel,
		Radius = UIConfig.Radius.Medium,
		StrokeColor = C.Purple,
		StrokeTransparency = 0.4,
	})
	local icon = UILib.label(iconBox, upgrade.Icon, {
		Size = UDim2.fromScale(1, 1),
		Font = UIConfig.FontTitle,
		TextScaled = true,
	})
	icon.Name = "Icon"
	UILib.padding(iconBox, 8)

	local name = UILib.label(card, upgrade.Name, {
		Size = UDim2.new(1, -290, 0, 22),
		Position = UDim2.fromOffset(86, 10),
		Font = UIConfig.FontBold,
		TextSize = 15,
		Color = C.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	name.Name = "Name"

	local desc = UILib.label(card, upgrade.Desc, {
		Size = UDim2.new(1, -290, 0, 30),
		Position = UDim2.fromOffset(86, 32),
		Font = UIConfig.FontSmall,
		TextSize = 11,
		Color = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	})
	desc.Name = "Desc"

	local levelLabel = UILib.label(card, "", {
		Size = UDim2.new(1, -290, 0, 18),
		Position = UDim2.fromOffset(86, 64),
		Font = UIConfig.FontBold,
		TextSize = 11,
		Color = C.Green,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	levelLabel.Name = "Level"

	local barHolder, barFill = UILib.bar(card, {
		Size = UDim2.new(0, 180, 0, 8),
		Position = UDim2.fromOffset(86, 78),
		Color = C.Green,
	})
	barHolder.Name = "LevelBar"

	local buyButton = UILib.button(card, "ACHETER", {
		Name = "Buy",
		Size = UDim2.fromOffset(190, 52),
		Position = UDim2.new(1, -204, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Color = C.Green,
		TextColor = C.TextDark,
		Radius = UIConfig.Radius.Medium,
		Gradient = { C.Green, Color3.fromRGB(70, 220, 130) },
	})

	buyButton.MouseButton1Click:Connect(function()
		Net.event("BuyUpgrade"):FireServer(upgradeId)
	end)

	local function refresh()
		local profile = ClientState.profile
		local level = (profile.upgrades and profile.upgrades[upgradeId]) or 0
		local maxed = level >= upgrade.MaxLevel
		levelLabel.Text = string.format("Niveau %d / %d", level, upgrade.MaxLevel)
		UILib.setBar(barFill, level / upgrade.MaxLevel)

		if maxed then
			buyButton.Text = "MAX ✅"
			buyButton.BackgroundColor3 = C.PanelLight
			buyButton.TextColor3 = C.TextDim
			levelLabel.TextColor3 = C.Gold
		else
			local cost = Formulas.upgradeCost(upgradeId, level)
			local affordable = (profile.coins or 0) >= cost
			buyButton.Text = "🪙 " .. Formulas.formatNumber(cost)
			buyButton.BackgroundColor3 = affordable and C.Green or C.PanelLight
			buyButton.TextColor3 = affordable and C.TextDark or C.TextDim
			levelLabel.TextColor3 = C.Green
		end
	end

	return refresh
end

-- ============================================================
-- AFFICHAGE
-- ============================================================
function ShopUI.show(ctx)
	local frame, content = UILib.showModal(ctx.screenGui, "shop", "🛒 BOUTIQUE", { Size = UDim2.fromOffset(760, 540) })
	UILib.clearContent(content)
	frame.Name = "ShopModal"

	local refreshers = {}

	-- Barre d'onglets
	local tabBar = Instance.new("Frame")
	tabBar.Name = "TabBar"
	tabBar.Size = UDim2.new(1, -8, 0, 46)
	tabBar.BackgroundTransparency = 1
	tabBar.LayoutOrder = 0
	tabBar.Parent = content
	UILib.list(tabBar, { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Left })

	local backButton = UILib.button(tabBar, "⟵ Retour", {
		Size = UDim2.fromOffset(110, 42),
		Color = C.PanelLight,
		Radius = UIConfig.Radius.Medium,
		TextSize = 14,
	})
	backButton.MouseButton1Click:Connect(function()
		UILib.closeModal()
	end)

	local listHolder = Instance.new("Frame")
	listHolder.Name = "ListHolder"
	listHolder.Size = UDim2.new(1, -8, 0, 0)
	listHolder.AutomaticSize = Enum.AutomaticSize.Y
	listHolder.BackgroundTransparency = 1
	listHolder.LayoutOrder = 1
	listHolder.Parent = content
	UILib.list(listHolder, { Padding = UDim.new(0, 10) })

	local tabs = {
		{ Id = "upgrades", Label = "⚡ Améliorations", Color = C.Green },
		{ Id = "passes", Label = "👑 Game Passes", Color = C.Gold },
		{ Id = "boosts", Label = "🚀 Boosts", Color = C.Orange },
	}
	local tabButtons = {}
	local currentTab = "upgrades"

	local function renderTab(tabId: string)
		currentTab = tabId
		refreshers = {}
		for _, child in ipairs(listHolder:GetChildren()) do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end
		for _, tabButton in pairs(tabButtons) do
			tabButton.BackgroundColor3 = C.PanelLight
			tabButton.TextColor3 = C.TextDim
		end
		if tabButtons[tabId] then
			tabButtons[tabId].BackgroundColor3 = C.Purple
			tabButtons[tabId].TextColor3 = C.Text
		end

		if tabId == "upgrades" then
			for index, upgradeId in ipairs(UPGRADE_ORDER) do
				if GameConfig.Upgrades[upgradeId] then
					table.insert(refreshers, buildUpgradeCard(listHolder, upgradeId, index))
				end
			end
		elseif tabId == "passes" then
			for index, passId in ipairs(GameConfig.GamePassOrder) do
				local pass = GameConfig.GamePasses[passId]
				if pass then
					local card = UILib.card(listHolder, {
						Name = "Pass_" .. passId,
						Size = UDim2.new(1, -8, 0, 92),
						Color = C.Card,
						LayoutOrder = index,
					})
					local iconBox = UILib.panel(card, {
						Size = UDim2.fromOffset(62, 62),
						Position = UDim2.fromOffset(12, 15),
						Color = C.Panel,
						Radius = UIConfig.Radius.Medium,
						StrokeColor = pass.Color,
						StrokeTransparency = 0.3,
					})
					local icon = UILib.label(iconBox, pass.Icon, {
						Size = UDim2.fromScale(1, 1),
						Font = UIConfig.FontTitle,
						TextScaled = true,
					})
					icon.Name = "Icon"
					UILib.padding(iconBox, 8)

					UILib.label(card, pass.Name, {
						Size = UDim2.new(1, -300, 0, 22),
						Position = UDim2.fromOffset(86, 12),
						Font = UIConfig.FontBold,
						TextSize = 15,
						Color = C.Text,
						TextXAlignment = Enum.TextXAlignment.Left,
					})
					UILib.label(card, pass.Desc, {
						Size = UDim2.new(1, -300, 0, 40),
						Position = UDim2.fromOffset(86, 34),
						Font = UIConfig.FontSmall,
						TextSize = 11,
						Color = C.TextDim,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextWrapped = true,
					})

					local buyButton = UILib.button(card, pass.Price or "R$ --", {
						Size = UDim2.fromOffset(200, 52),
						Position = UDim2.new(1, -214, 0.5, 0),
						AnchorPoint = Vector2.new(0, 0.5),
						Color = pass.Color,
						TextColor = C.TextDark,
						Gradient = { pass.Color, pass.Color:Lerp(C.White, 0.35) },
					})

					buyButton.MouseButton1Click:Connect(function()
						if (pass.Id or 0) <= 0 then
							UILib.toast("Game Pass non configuré (ID à renseigner dans GameConfig).", C.Red, "⚙️")
							return
						end
						MarketplaceService:PromptGamePassPurchase(Players.LocalPlayer, pass.Id)
					end)

					local function refresh()
						local owned = ClientState.profile.gamePasses and ClientState.profile.gamePasses[passId]
						if owned then
							buyButton.Text = "POSSÉDÉ ✅"
							buyButton.BackgroundColor3 = C.PanelLight
							buyButton.TextColor3 = C.Green
						else
							buyButton.Text = pass.Price or "R$ --"
							buyButton.BackgroundColor3 = pass.Color
							buyButton.TextColor3 = C.TextDark
						end
					end
					table.insert(refreshers, refresh)
				end
			end
		elseif tabId == "boosts" then
			for index, productId in ipairs(GameConfig.DeveloperProductOrder) do
				local product = GameConfig.DeveloperProducts[productId]
				if product then
					local card = UILib.card(listHolder, {
						Name = "Product_" .. productId,
						Size = UDim2.new(1, -8, 0, 92),
						Color = C.Card,
						LayoutOrder = index,
					})
					local iconBox = UILib.panel(card, {
						Size = UDim2.fromOffset(62, 62),
						Position = UDim2.fromOffset(12, 15),
						Color = C.Panel,
						Radius = UIConfig.Radius.Medium,
						StrokeColor = C.Orange,
						StrokeTransparency = 0.3,
					})
					local icon = UILib.label(iconBox, product.Icon, {
						Size = UDim2.fromScale(1, 1),
						Font = UIConfig.FontTitle,
						TextScaled = true,
					})
					icon.Name = "Icon"
					UILib.padding(iconBox, 8)

					UILib.label(card, product.Name, {
						Size = UDim2.new(1, -300, 0, 22),
						Position = UDim2.fromOffset(86, 12),
						Font = UIConfig.FontBold,
						TextSize = 15,
						Color = C.Text,
						TextXAlignment = Enum.TextXAlignment.Left,
					})
					UILib.label(card, product.Desc, {
						Size = UDim2.new(1, -300, 0, 40),
						Position = UDim2.fromOffset(86, 34),
						Font = UIConfig.FontSmall,
						TextSize = 11,
						Color = C.TextDim,
						TextXAlignment = Enum.TextXAlignment.Left,
						TextWrapped = true,
					})

					local buyButton = UILib.button(card, product.Price or "R$ --", {
						Size = UDim2.fromOffset(200, 52),
						Position = UDim2.new(1, -214, 0.5, 0),
						AnchorPoint = Vector2.new(0, 0.5),
						Color = C.Orange,
						TextColor = C.TextDark,
					})
					buyButton.MouseButton1Click:Connect(function()
						if (product.Id or 0) <= 0 then
							UILib.toast("Developer Product non configuré (ID à renseigner).", C.Red, "⚙️")
							return
						end
						MarketplaceService:PromptProductPurchase(Players.LocalPlayer, product.Id)
					end)
				end
			end
		end
	end

	for _, tab in ipairs(tabs) do
		local button = UILib.button(tabBar, tab.Label, {
			Size = UDim2.fromOffset(190, 42),
			Color = C.PanelLight,
			Radius = UIConfig.Radius.Medium,
			TextSize = 14,
		})
		tabButtons[tab.Id] = button
		button.MouseButton1Click:Connect(function()
			renderTab(tab.Id)
		end)
	end

	renderTab(currentTab)

	return function()
		for _, refresh in ipairs(refreshers) do
			pcall(refresh)
		end
	end
end

return ShopUI
