--!strict
--[[
	PetsUI  |  StarterPlayer.StarterPlayerScripts.UI.PetsUI
	------------------------------------------------------------------
	Écran "Pets & Œufs" :

	  ONGLET ŒUFS
	    • tous les œufs : prix, prérequis, probabilités de rareté
	    • boutons "Ouvrir" et "Ouvrir ×3" (le serveur débite et tire)

	  ONGLET INVENTAIRE
	    • emplacements équipés (X/Y)
	    • "Équiper les meilleurs" / "Retirer tout"
	    • liste des pets : rareté, niveau, multiplicateur, état
	    • boutons Équiper / Retirer / Fusionner (3 identiques)
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local Formulas = require(Modules:WaitForChild("Formulas"))
local Net = require(Modules:WaitForChild("Net"))

local UIConfig = require(script.Parent.UIConfig)
local UILib = require(script.Parent.UILib)
local ClientState = require(script.Parent.Parent.Controllers.ClientState)

local PetsUI = {}

local C = UIConfig.Colors

local function rarityChip(parent: Instance, rarityName: string, layoutOrder: number?)
	local rarity = GameConfig.Rarities[rarityName] or GameConfig.Rarities.Common
	local chip = UILib.panel(parent, {
		Size = UDim2.fromOffset(84, 22),
		Color = rarity.Color,
		Radius = UIConfig.Radius.Pill,
		Stroke = false,
		LayoutOrder = layoutOrder or 1,
	})
	local label = UILib.label(chip, rarity.Name, {
		Size = UDim2.fromScale(1, 1),
		Font = UIConfig.FontBold,
		TextSize = 11,
		Color = C.TextDark,
	})
	label.Name = "Text"
	UILib.padding(chip, 0, 0, 4, 4)
	return chip
end

-- ============================================================
-- ONGLET ŒUFS
-- ============================================================
local function buildEggCard(parent: Instance, eggId: string, layoutOrder: number)
	local egg = GameConfig.Eggs[eggId]
	local card = UILib.card(parent, {
		Name = "Egg_" .. eggId,
		Size = UDim2.new(1, -8, 0, 168),
		Color = C.Card,
		LayoutOrder = layoutOrder,
	})

	local eggCircle = UILib.panel(card, {
		Size = UDim2.fromOffset(84, 84),
		Position = UDim2.fromOffset(14, 14),
		Color = C.Panel,
		Radius = UIConfig.Radius.Pill,
		StrokeColor = egg.Color,
		StrokeThickness = 3,
	})
	local emoji = UILib.label(eggCircle, egg.Emoji, {
		Size = UDim2.fromScale(1, 1),
		Font = UIConfig.FontTitle,
		TextScaled = true,
	})
	emoji.Name = "Emoji"
	UILib.padding(eggCircle, 10)

	local title = UILib.label(card, egg.Name, {
		Size = UDim2.new(1, -320, 0, 24),
		Position = UDim2.fromOffset(112, 12),
		Font = UIConfig.FontTitle,
		TextSize = 18,
		Color = egg.Color,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	title.Name = "Title"

	local priceText = (egg.Price and egg.Price > 0) and ("🪙 " .. Formulas.formatNumber(egg.Price)) or "GRATUIT (1 fois)"
	local requirement = ""
	if egg.MinRebirth and egg.MinRebirth > 0 then
		requirement = string.format("  •  🔄 %d rebirth requis", egg.MinRebirth)
	end

	local subtitle = UILib.label(card, priceText .. requirement, {
		Size = UDim2.new(1, -320, 0, 18),
		Position = UDim2.fromOffset(112, 38),
		Font = UIConfig.FontBold,
		TextSize = 12,
		Color = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	subtitle.Name = "Price"

	-- Probabilités
	local oddsHolder = Instance.new("Frame")
	oddsHolder.Name = "Odds"
	oddsHolder.Size = UDim2.new(1, -140, 0, 0)
	oddsHolder.Position = UDim2.fromOffset(112, 60)
	oddsHolder.AutomaticSize = Enum.AutomaticSize.Y
	oddsHolder.BackgroundTransparency = 1
	oddsHolder.Parent = card
	UILib.list(oddsHolder, { Padding = UDim.new(0, 4), HorizontalAlignment = Enum.HorizontalAlignment.Left })
	local oddsGrid = Instance.new("UIGridLayout")
	oddsGrid.CellSize = UDim2.fromOffset(112, 26)
	oddsGrid.CellPadding = UDim2.fromOffset(6, 6)
	oddsGrid.FillDirection = Enum.FillDirection.Horizontal
	oddsGrid.SortOrder = Enum.SortOrder.LayoutOrder
	oddsGrid.Parent = oddsHolder
	local listLayout = oddsHolder:FindFirstChildOfClass("UIListLayout")
	if listLayout then
		listLayout:Destroy()
	end
	oddsHolder.Size = UDim2.new(1, -140, 0, 60)

	for index, entry in ipairs(Formulas.eggDisplayOdds(eggId)) do
		local rarity = GameConfig.Rarities[entry.Rarity]
		local chip = UILib.panel(oddsHolder, {
			Size = UDim2.fromOffset(112, 26),
			Color = rarity.Color,
			Radius = UIConfig.Radius.Small,
			Stroke = false,
			LayoutOrder = index,
		})
		local chance = entry.Chance
		local text = string.format("%s %s", rarity.Name:sub(1, 3), chance >= 10 and string.format("%.0f%%", chance) or string.format("%.2f%%", chance))
		local label = UILib.label(chip, text, {
			Size = UDim2.fromScale(1, 1),
			Font = UIConfig.FontBold,
			TextSize = 10,
			Color = C.TextDark,
		})
		label.Name = "Text"
		UILib.padding(chip, 0, 0, 3, 3)
	end

	local openButton = UILib.button(card, "OUVRIR", {
		Name = "Open",
		Size = UDim2.fromOffset(150, 48),
		Position = UDim2.new(1, -164, 0, 40),
		Color = C.Green,
		TextColor = C.TextDark,
		Radius = UIConfig.Radius.Medium,
		Gradient = { C.Green, Color3.fromRGB(70, 220, 130) },
	})
	openButton.MouseButton1Click:Connect(function()
		Net.event("OpenEgg"):FireServer(eggId, 1)
		UILib.playClick("pop")
	end)

	local openThreeButton = UILib.button(card, "OUVRIR ×3", {
		Name = "Open3",
		Size = UDim2.fromOffset(150, 40),
		Position = UDim2.new(1, -164, 0, 96),
		Color = C.Purple,
		TextColor = C.Text,
		Radius = UIConfig.Radius.Medium,
		TextSize = 14,
	})
	openThreeButton.MouseButton1Click:Connect(function()
		Net.event("OpenEgg"):FireServer(eggId, 3)
		UILib.playClick("pop")
	end)

	local function refresh()
		local profile = ClientState.profile
		local price = egg.Price or 0
		local isFree = egg.FreeOnePerPlayer and not (profile.freeEggsTaken and profile.freeEggsTaken[eggId])
		local canAfford = isFree or (profile.coins or 0) >= price
		openButton.BackgroundColor3 = canAfford and C.Green or C.PanelLight
		openButton.TextColor3 = canAfford and C.TextDark or C.TextDim
		openButton.Text = isFree and "GRATUIT" or ("🪙 " .. Formulas.formatNumber(price))
		openThreeButton.Visible = not isFree
		openThreeButton.BackgroundColor3 = ((profile.coins or 0) >= price * 3) and C.Purple or C.PanelLight
		openThreeButton.Text = "×3  🪙 " .. Formulas.formatNumber(price * 3)
		openButton.TextScaled = false
	end

	refresh()
	return refresh
end

-- ============================================================
-- ONGLET INVENTAIRE
-- ============================================================
local function buildPetRow(parent: Instance, pet, layoutOrder: number)
	local info = GameConfig.Pets[pet.id]
	if not info then
		return nil
	end
	local rarity = GameConfig.Rarities[info.Rarity]

	local card = UILib.card(parent, {
		Name = "Pet_" .. pet.uid,
		Size = UDim2.new(1, -8, 0, 76),
		Color = C.Card,
		LayoutOrder = layoutOrder,
		StrokeColor = rarity.Color,
		StrokeTransparency = 0.55,
	})

	local iconBox = UILib.panel(card, {
		Size = UDim2.fromOffset(52, 52),
		Position = UDim2.fromOffset(12, 12),
		Color = rarity.Color:Lerp(C.Panel, 0.65),
		Radius = UIConfig.Radius.Medium,
		StrokeColor = rarity.Color,
		StrokeTransparency = 0.3,
	})
	local emoji = UILib.label(iconBox, info.Emoji, {
		Size = UDim2.fromScale(1, 1),
		Font = UIConfig.FontTitle,
		TextScaled = true,
	})
	emoji.Name = "Emoji"
	UILib.padding(iconBox, 8)

	local name = UILib.label(card, info.Name, {
		Size = UDim2.new(1, -360, 0, 20),
		Position = UDim2.fromOffset(74, 9),
		Font = UIConfig.FontBold,
		TextSize = 14,
		Color = rarity.Color,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	name.Name = "Name"

	local power = Formulas.petPower(pet.id, pet.level)
	local detail = UILib.label(card, string.format("Niveau %d  •  ×%s puissance", pet.level or 1, string.format("%.2f", power)), {
		Size = UDim2.new(1, -360, 0, 18),
		Position = UDim2.fromOffset(74, 30),
		Font = UIConfig.FontSmall,
		TextSize = 11,
		Color = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	detail.Name = "Detail"

	local chipHolder = Instance.new("Frame")
	chipHolder.Name = "Chips"
	chipHolder.Size = UDim2.fromOffset(100, 20)
	chipHolder.Position = UDim2.fromOffset(74, 50)
	chipHolder.BackgroundTransparency = 1
	chipHolder.Parent = card
	rarityChip(chipHolder, info.Rarity)

	local equipped = ClientState.isEquipped(pet.uid)
	local equipButton = UILib.button(card, equipped and "RETIRER" or "ÉQUIPER", {
		Name = "Equip",
		Size = UDim2.fromOffset(120, 40),
		Position = UDim2.new(1, -252, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Color = equipped and C.PanelLight or C.Green,
		TextColor = equipped and C.TextDim or C.TextDark,
		Radius = UIConfig.Radius.Medium,
		TextSize = 13,
	})
	equipButton.MouseButton1Click:Connect(function()
		if ClientState.isEquipped(pet.uid) then
			Net.event("UnequipPet"):FireServer(pet.uid)
		else
			Net.event("EquipPet"):FireServer(pet.uid)
		end
	end)

	-- Fusion : 3 identiques du même niveau
	local sameLevelCount = ClientState.countPetId(pet.id, pet.level)
	local canFuse = sameLevelCount >= GameConfig.Misc.FuseCount and (pet.level or 1) < GameConfig.Misc.MaxPetLevel
	local fuseButton = UILib.button(card, string.format("FUSIONNER (%d/%d)", sameLevelCount, GameConfig.Misc.FuseCount), {
		Name = "Fuse",
		Size = UDim2.fromOffset(120, 40),
		Position = UDim2.new(1, -126, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Color = canFuse and C.Purple or C.PanelLight,
		TextColor = canFuse and C.Text or C.TextDim,
		Radius = UIConfig.Radius.Medium,
		TextSize = 11,
	})
	fuseButton.MouseButton1Click:Connect(function()
		Net.event("FusePet"):FireServer(pet.id)
	end)

	return card
end

-- ============================================================
-- AFFICHAGE
-- ============================================================
function PetsUI.show(ctx, initialTab: string?)
	local frame, content = UILib.showModal(ctx.screenGui, "pets", "🐾 PETS & ŒUFS", { Size = UDim2.fromOffset(800, 560) })
	UILib.clearContent(content)

	local currentTab = initialTab or "eggs"
	local inventorySignature = ""

	-- En-tête : tabs + emplacements
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, -8, 0, 46)
	header.BackgroundTransparency = 1
	header.LayoutOrder = 0
	header.Parent = content
	UILib.list(header, { Padding = UDim.new(0, 6), HorizontalAlignment = Enum.HorizontalAlignment.Left })

	local slotLabel = UILib.label(header, "3/3 pets équipés", {
		Size = UDim2.fromOffset(200, 42),
		Position = UDim2.fromOffset(0, 0),
		Font = UIConfig.FontBold,
		TextSize = 13,
		Color = C.Green,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	slotLabel.Name = "Slots"
	slotLabel.LayoutOrder = 5

	local bestButton = UILib.button(header, "✨ MEILLEURS", {
		Size = UDim2.fromOffset(160, 42),
		Color = C.Purple,
		Radius = UIConfig.Radius.Medium,
		TextSize = 13,
	})
	bestButton.LayoutOrder = 4
	bestButton.MouseButton1Click:Connect(function()
		Net.event("EquipBestPets"):FireServer()
	end)

	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.Size = UDim2.new(1, -8, 0, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.BackgroundTransparency = 1
	holder.LayoutOrder = 1
	holder.Parent = content
	UILib.list(holder, { Padding = UDim.new(0, 10) })

	local eggRefreshers = {}

	local function render()
		eggRefreshers = {}
		for _, child in ipairs(holder:GetChildren()) do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end

		if currentTab == "eggs" then
			for index, eggId in ipairs(GameConfig.EggOrder) do
				table.insert(eggRefreshers, buildEggCard(holder, eggId, index))
			end
		else
			local profile = ClientState.profile
			local pets = {}
			for _, pet in ipairs(profile.pets or {}) do
				table.insert(pets, pet)
			end
			table.sort(pets, function(a, b)
				local aInfo = GameConfig.Pets[a.id]
				local bInfo = GameConfig.Pets[b.id]
				local aOrder = aInfo and GameConfig.Rarities[aInfo.Rarity].Order or 0
				local bOrder = bInfo and GameConfig.Rarities[bInfo.Rarity].Order or 0
				if aOrder ~= bOrder then
					return aOrder > bOrder
				end
				if (a.level or 1) ~= (b.level or 1) then
					return (a.level or 1) > (b.level or 1)
				end
				return (aInfo and aInfo.Mult or 0) > (bInfo and bInfo.Mult or 0)
			end)

			if #pets == 0 then
				local empty = UILib.label(holder, "Aucun pet… Ouvre un œuf dans l'onglet Œufs ! 🥚", {
					Size = UDim2.new(1, -8, 0, 80),
					Font = UIConfig.FontBold,
					TextSize = 15,
					Color = C.TextDim,
					TextWrapped = true,
					LayoutOrder = 1,
				})
				empty.Name = "Empty"
			else
				for index, pet in ipairs(pets) do
					buildPetRow(holder, pet, index)
				end
			end
		end

		local profile = ClientState.profile
		slotLabel.Text = string.format("%d/%d pets équipés", #(profile.equipped or {}), ClientState.getPetSlots())
		slotLabel.TextColor3 = #(profile.equipped or {}) >= ClientState.getPetSlots() and C.Gold or C.Green

		-- signature : évite de reconstruire la liste à chaque mise à jour
		local signatureParts = { tostring(#(profile.pets or {})), tostring(#(profile.equipped or {})) }
		for _, uid in ipairs(profile.equipped or {}) do
			table.insert(signatureParts, uid)
		end
		inventorySignature = table.concat(signatureParts, "|")
	end

	local function makeTab(tabId: string, label: string, color: Color3, order: number)
		local button = UILib.button(header, label, {
			Size = UDim2.fromOffset(170, 42),
			Color = C.PanelLight,
			Radius = UIConfig.Radius.Medium,
			TextSize = 14,
		})
		button.LayoutOrder = order
		button:SetAttribute("TabId", tabId)
		button.MouseButton1Click:Connect(function()
			currentTab = tabId
			for _, sibling in ipairs(header:GetChildren()) do
				if sibling:IsA("TextButton") and sibling:GetAttribute("TabId") then
					sibling.BackgroundColor3 = C.PanelLight
					sibling.TextColor3 = C.TextDim
				end
			end
			button.BackgroundColor3 = color
			button.TextColor3 = C.Text
			render()
		end)
		return button
	end

	local eggsTab = makeTab("eggs", "🥚 Œufs", C.Orange, 1)
	local petsTab = makeTab("pets", "🐾 Inventaire", C.Purple, 2)
	if currentTab == "eggs" then
		eggsTab.BackgroundColor3 = C.Orange
		eggsTab.TextColor3 = C.Text
	else
		petsTab.BackgroundColor3 = C.Purple
		petsTab.TextColor3 = C.Text
	end

	render()

	return function()
		if currentTab == "eggs" then
			for _, refresh in ipairs(eggRefreshers) do
				pcall(refresh)
			end
			local profile = ClientState.profile
			slotLabel.Text = string.format("%d/%d pets équipés", #(profile.equipped or {}), ClientState.getPetSlots())
		else
			local profile = ClientState.profile
			local signatureParts = { tostring(#(profile.pets or {})), tostring(#(profile.equipped or {})) }
			for _, uid in ipairs(profile.equipped or {}) do
				table.insert(signatureParts, uid)
			end
			if table.concat(signatureParts, "|") ~= inventorySignature then
				render()
			end
		end
	end
end

return PetsUI
