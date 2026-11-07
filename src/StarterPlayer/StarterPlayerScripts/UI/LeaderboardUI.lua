--!strict
--[[
	LeaderboardUI  |  StarterPlayer.StarterPlayerScripts.UI.LeaderboardUI
	------------------------------------------------------------------
	Classement du serveur (temps réel) et classement mondial
	(OrderedDataStore, top 25).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local Formulas = require(Modules:WaitForChild("Formulas"))
local Net = require(Modules:WaitForChild("Net"))
local GameConfig = require(Modules:WaitForChild("GameConfig"))

local UIConfig = require(script.Parent.UIConfig)
local UILib = require(script.Parent.UILib)
local ClientState = require(script.Parent.Parent.Controllers.ClientState)

local LeaderboardUI = {}

local C = UIConfig.Colors

local function buildRow(parent: Instance, entry, layoutOrder: number, isPlayer: boolean)
	local medal = "▫️"
	if isPlayer and entry.Rank == 1 then
		medal = "🥇"
	elseif isPlayer and entry.Rank == 2 then
		medal = "🥈"
	elseif isPlayer and entry.Rank == 3 then
		medal = "🥉"
	end

	local isMe = entry.UserId == Players.LocalPlayer.UserId
	local row = UILib.card(parent, {
		Size = UDim2.new(1, -8, 0, 52),
		Color = (isPlayer and entry.Rank and entry.Rank <= 3) and C.PanelLight or C.Card,
		LayoutOrder = layoutOrder,
		StrokeColor = isMe and C.Gold or C.Stroke,
		StrokeTransparency = isMe and 0.1 or 0.75,
	})

	UILib.label(row, string.format("%s #%d", medal, entry.Rank or layoutOrder), {
		Size = UDim2.fromOffset(74, 52),
		Position = UDim2.fromOffset(6, 0),
		Font = UIConfig.FontBold,
		TextSize = 15,
		Color = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	UILib.label(row, (entry.Name or "???") .. (isMe and "  (toi)" or ""), {
		Size = UDim2.new(1, -420, 0, 52),
		Position = UDim2.fromOffset(84, 0),
		Font = UIConfig.FontBold,
		TextSize = 14,
		Color = isMe and C.Gold or C.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
	})

	-- Comparaison de puissance (uniquement pour les autres joueurs du serveur)
	if isPlayer and not isMe then
		local compareButton = UILib.button(row, "⚖️", {
			Size = UDim2.fromOffset(40, 34),
			Position = UDim2.new(1, -340, 0.5, 0),
			AnchorPoint = Vector2.new(0, 0.5),
			Color = C.PanelLight,
			Radius = UIConfig.Radius.Small,
			TextSize = 16,
		})
		compareButton.MouseButton1Click:Connect(function()
			Net.event("ComparePower"):FireServer(entry.UserId)
		end)
	end

	UILib.label(row, Formulas.formatNumber(entry.Power or 0) .. " ⚡", {
		Size = UDim2.fromOffset(170, 52),
		Position = UDim2.new(1, -290, 0, 0),
		Font = UIConfig.FontTitle,
		TextSize = 16,
		Color = C.Gold,
		TextXAlignment = Enum.TextXAlignment.Right,
	})

	if isPlayer and entry.Rebirths then
		UILib.label(row, string.format("🔄 %d", entry.Rebirths), {
			Size = UDim2.fromOffset(84, 52),
			Position = UDim2.new(1, -96, 0, 0),
			Font = UIConfig.FontBold,
			TextSize = 13,
			Color = C.Pink,
			TextXAlignment = Enum.TextXAlignment.Right,
		})
	end

	return row
end

function LeaderboardUI.show(ctx)
	local frame, content = UILib.showModal(ctx.screenGui, "ranks", "🏆 CLASSEMENT", { Size = UDim2.fromOffset(760, 560) })
	UILib.clearContent(content)

	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, -8, 0, 44)
	header.BackgroundTransparency = 1
	header.LayoutOrder = 0
	header.Parent = content
	UILib.list(header, { Padding = UDim.new(0, 8), HorizontalAlignment = Enum.HorizontalAlignment.Left })

	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.Size = UDim2.new(1, -8, 0, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.BackgroundTransparency = 1
	holder.LayoutOrder = 1
	holder.Parent = content
	UILib.list(holder, { Padding = UDim.new(0, 6) })

	local currentTab = "server"

	local function render()
		for _, child in ipairs(holder:GetChildren()) do
			if not child:IsA("UIListLayout") then
				child:Destroy()
			end
		end

		local list = currentTab == "server" and ClientState.serverLeaderboard or ClientState.globalLeaderboard
		if not list or #list == 0 then
			local emptyText = currentTab == "server"
				and "Aucun joueur classé pour le moment… Absorbe des objets !"
				or "Classement mondial en cours de chargement… (il se remplit au fil des parties)"
			local empty = UILib.label(holder, emptyText, {
				Size = UDim2.new(1, -8, 0, 100),
				Font = UIConfig.FontBold,
				TextSize = 14,
				Color = C.TextDim,
				TextWrapped = true,
				LayoutOrder = 1,
			})
			empty.Name = "Empty"
			return
		end

		for index, entry in ipairs(list) do
			if index > GameConfig.Misc.LeaderboardTop then
				break
			end
			buildRow(holder, entry, index, currentTab == "server")
		end
	end

	local function makeTab(tabId: string, label: string, color: Color3)
		local button = UILib.button(header, label, {
			Size = UDim2.fromOffset(190, 42),
			Color = C.PanelLight,
			Radius = UIConfig.Radius.Medium,
			TextSize = 14,
		})
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

	local serverTab = makeTab("server", "🏠 Ce serveur", C.Blue)
	makeTab("global", "🌐 Mondial", C.Gold)
	serverTab.BackgroundColor3 = C.Blue
	serverTab.TextColor3 = C.Text

	render()

	-- Rafraîchissement des données (RemoteFunction, throttlé)
	local lastFetch = 0
	task.spawn(function()
		if os.clock() - lastFetch > 15 then
			lastFetch = os.clock()
			local global, server = Net.func("GetLeaderboards"):InvokeServer()
			if type(global) == "table" then
				ClientState.globalLeaderboard = global
			end
			if type(server) == "table" then
				ClientState.serverLeaderboard = server
			end
			if frame.Visible then
				render()
			end
		end
	end)

	ClientState.Signals.Leaderboard:Connect(function()
		if frame.Visible then
			render()
		end
	end)

	-- Pas de reconstruction périodique : la liste se met à jour via le
	-- signal Leaderboard (toutes les 8 s) pour ne pas casser le scroll.
	return function() end
end

return LeaderboardUI
