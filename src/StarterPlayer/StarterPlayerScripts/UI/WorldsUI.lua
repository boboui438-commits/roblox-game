--!strict
--[[
	WorldsUI  |  StarterPlayer.StarterPlayerScripts.UI.WorldsUI
	------------------------------------------------------------------
	Écran des mondes : 6 mondes + retour au lobby.
	Affiche les prérequis, la valeur des objets, l'œuf du monde et un
	bouton "VOYAGER" (validé côté serveur).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local Formulas = require(Modules:WaitForChild("Formulas"))
local Net = require(Modules:WaitForChild("Net"))

local UIConfig = require(script.Parent.UIConfig)
local UILib = require(script.Parent.UILib)
local ClientState = require(script.Parent.Parent.Controllers.ClientState)

local WorldsUI = {}

local C = UIConfig.Colors

function WorldsUI.show(ctx)
	local frame, content = UILib.showModal(ctx.screenGui, "worlds", "🌍 MONDES", { Size = UDim2.fromOffset(820, 580) })
	UILib.clearContent(content)

	local refreshers = {}

	-- Carte lobby
	local lobbyCard = UILib.card(content, {
		Name = "LobbyCard",
		Size = UDim2.new(1, -8, 0, 76),
		Color = C.Card,
		LayoutOrder = 0,
		StrokeColor = C.Blue,
		StrokeTransparency = 0.4,
	})
	local lobbyIcon = UILib.label(lobbyCard, "🏠", {
		Size = UDim2.fromOffset(52, 52),
		Position = UDim2.fromOffset(12, 12),
		Font = UIConfig.FontTitle,
		TextScaled = true,
	})
	local lobbyText = UILib.label(lobbyCard, "Lobby — le hub du jeu (autel, portails, classement)", {
		Size = UDim2.new(1, -260, 1, 0),
		Position = UDim2.fromOffset(74, 0),
		Font = UIConfig.FontBody,
		TextSize = 13,
		Color = C.TextDim,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
	})
	local lobbyButton = UILib.button(lobbyCard, "RETOUR AU LOBBY", {
		Size = UDim2.fromOffset(170, 46),
		Position = UDim2.new(1, -184, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Color = C.Blue,
		TextColor = C.TextDark,
		TextSize = 12,
	})
	lobbyButton.MouseButton1Click:Connect(function()
		Net.event("TravelWorld"):FireServer(0)
		UILib.closeModal()
	end)

	for index, world in ipairs(GameConfig.Worlds) do
		local card = UILib.card(content, {
			Name = "World" .. index,
			Size = UDim2.new(1, -8, 0, 96),
			Color = C.Card,
			LayoutOrder = index,
			StrokeColor = world.SkyColor,
			StrokeTransparency = 0.45,
		})

		local iconBox = UILib.panel(card, {
			Size = UDim2.fromOffset(64, 64),
			Position = UDim2.fromOffset(14, 16),
			Color = world.SkyColor:Lerp(C.Panel, 0.45),
			Radius = UIConfig.Radius.Medium,
			StrokeColor = world.SkyColor,
			StrokeThickness = 2,
		})
		UILib.label(iconBox, world.Emoji, {
			Size = UDim2.fromScale(1, 1),
			Font = UIConfig.FontTitle,
			TextScaled = true,
		})

		local name = UILib.label(card, string.format("%d. %s", index, world.Name), {
			Size = UDim2.new(1, -320, 0, 24),
			Position = UDim2.fromOffset(90, 12),
			Font = UIConfig.FontTitle,
			TextSize = 18,
			Color = world.SkyColor,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		name.Name = "Name"

		local detail = UILib.label(card, string.format(
			"Objets ×%s de valeur  •  œuf : %s %s",
			Formulas.formatNumber(world.ValueMult),
			GameConfig.Eggs[world.Egg] and GameConfig.Eggs[world.Egg].Emoji or "🥚",
			GameConfig.Eggs[world.Egg] and GameConfig.Eggs[world.Egg].Name or "—"
		), {
			Size = UDim2.new(1, -320, 0, 18),
			Position = UDim2.fromOffset(90, 36),
			Font = UIConfig.FontSmall,
			TextSize = 11,
			Color = C.TextDim,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		detail.Name = "Detail"

		local requirement = UILib.label(card, "", {
			Size = UDim2.new(1, -320, 0, 18),
			Position = UDim2.fromOffset(90, 54),
			Font = UIConfig.FontBold,
			TextSize = 11,
			Color = C.Gold,
			TextXAlignment = Enum.TextXAlignment.Left,
		})
		requirement.Name = "Requirement"

		local travelButton = UILib.button(card, "VOYAGER", {
			Size = UDim2.fromOffset(190, 50),
			Position = UDim2.new(1, -204, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Color = C.Green,
			TextColor = C.TextDark,
		})
		travelButton.MouseButton1Click:Connect(function()
			Net.event("TravelWorld"):FireServer(index)
			UILib.closeModal()
		end)

		local function refresh()
			local profile = ClientState.profile
			local unlocked = ClientState.isWorldUnlocked(index)
			local current = ClientState.getWorld() == index
			local requirements = {}
			if world.UnlockPower > 0 then
				table.insert(requirements, string.format("%s ⚡", Formulas.formatNumber(world.UnlockPower)))
			end
			if world.UnlockRebirth > 0 then
				table.insert(requirements, string.format("%d 🔄", world.UnlockRebirth))
			end
			requirement.Text = unlocked and "✅ Débloqué" or ("🔒 Requiert : " .. table.concat(requirements, " + "))
			requirement.TextColor3 = unlocked and C.Green or C.Gold

			if current then
				travelButton.Text = "📍 TU ES ICI"
				travelButton.BackgroundColor3 = C.PanelLight
				travelButton.TextColor3 = C.TextDim
			elseif unlocked then
				travelButton.Text = "VOYAGER"
				travelButton.BackgroundColor3 = C.Green
				travelButton.TextColor3 = C.TextDark
			else
				travelButton.Text = "VERROUILLÉ"
				travelButton.BackgroundColor3 = C.PanelLight
				travelButton.TextColor3 = C.TextDim
			end
		end
		refresh()
		table.insert(refreshers, refresh)
	end

	return function()
		for _, refresh in ipairs(refreshers) do
			pcall(refresh)
		end
	end
end

return WorldsUI
