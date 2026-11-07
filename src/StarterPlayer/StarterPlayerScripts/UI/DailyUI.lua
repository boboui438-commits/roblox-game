--!strict
--[[
	DailyUI  |  StarterPlayer.StarterPlayerScripts.UI.DailyUI
	------------------------------------------------------------------
	Récompenses quotidiennes : 7 jours, série, cooldown de 20 h.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local Formulas = require(Modules:WaitForChild("Formulas"))
local Net = require(Modules:WaitForChild("Net"))

local UIConfig = require(script.Parent.UIConfig)
local UILib = require(script.Parent.UILib)
local ClientState = require(script.Parent.Parent.Controllers.ClientState)

local DailyUI = {}

local C = UIConfig.Colors

function DailyUI.show(ctx)
	local frame, content = UILib.showModal(ctx.screenGui, "daily", "📅 RÉCOMPENSE QUOTIDIENNE", { Size = UDim2.fromOffset(700, 520) })
	UILib.clearContent(content)

	local infoLabel = UILib.label(content, "", {
		Size = UDim2.new(1, -8, 0, 40),
		Font = UIConfig.FontBold,
		TextSize = 14,
		Color = C.Text,
		TextWrapped = true,
		LayoutOrder = 0,
	})
	infoLabel.Name = "Info"

	local gridHolder = Instance.new("Frame")
	gridHolder.Name = "Days"
	gridHolder.Size = UDim2.new(1, -8, 0, 220)
	gridHolder.BackgroundTransparency = 1
	gridHolder.LayoutOrder = 1
	gridHolder.Parent = content
	UILib.grid(gridHolder, UDim2.fromOffset(148, 100), UDim2.fromOffset(8, 8))

	local dayCards = {}
	for dayIndex, reward in ipairs(GameConfig.DailyRewards) do
		local card = UILib.card(gridHolder, {
			Name = "Day" .. dayIndex,
			Size = UDim2.fromOffset(148, 100),
			Color = C.Card,
			LayoutOrder = dayIndex,
			StrokeColor = C.Gold,
			StrokeTransparency = 0.6,
		})

		UILib.label(card, "JOUR " .. dayIndex, {
			Size = UDim2.new(1, 0, 0, 20),
			Position = UDim2.fromOffset(0, 8),
			Font = UIConfig.FontBold,
			TextSize = 12,
			Color = C.Gold,
		})

		UILib.label(card, "🪙 " .. Formulas.formatNumber(reward.Coins), {
			Size = UDim2.new(1, 0, 0, 22),
			Position = UDim2.fromOffset(0, 32),
			Font = UIConfig.FontTitle,
			TextSize = 16,
			Color = C.Text,
		})

		local extraText = ""
		if reward.BoostMinutes then
			extraText = string.format("🚀 boost %dmin", reward.BoostMinutes)
		elseif reward.FreeEgg then
			extraText = "🥚 œuf offert"
		end
		UILib.label(card, extraText, {
			Size = UDim2.new(1, -8, 0, 16),
			Position = UDim2.fromOffset(0, 56),
			Font = UIConfig.FontSmall,
			TextSize = 10,
			Color = C.Orange,
		})

		local statusLabel = UILib.label(card, "", {
			Size = UDim2.new(1, 0, 0, 20),
			Position = UDim2.fromOffset(0, 74),
			Font = UIConfig.FontBold,
			TextSize = 11,
			Color = C.Green,
		})
		statusLabel.Name = "Status"

		dayCards[dayIndex] = { Card = card, Status = statusLabel }
	end

	local claimButton = UILib.button(content, "RÉCLAMER", {
		Name = "Claim",
		Size = UDim2.new(1, -8, 0, 58),
		Color = C.Green,
		TextColor = C.TextDark,
		Radius = UIConfig.Radius.Large,
		LayoutOrder = 2,
		Gradient = { C.Green, Color3.fromRGB(70, 220, 130) },
	})
	claimButton.MouseButton1Click:Connect(function()
		Net.event("ClaimDaily"):FireServer()
	end)

	local streakLabel = UILib.label(content, "", {
		Size = UDim2.new(1, -8, 0, 26),
		Font = UIConfig.FontSmall,
		TextSize = 12,
		Color = C.TextDim,
		LayoutOrder = 3,
	})
	streakLabel.Name = "Streak"

	local function refresh()
		local profile = ClientState.profile
		local daily = profile.daily or { lastClaim = 0, streak = 0, dayIndex = 1 }
		local remaining = math.max(0, GameConfig.DailyResetSeconds - (os.time() - (daily.lastClaim or 0)))
		local available = remaining <= 0

		claimButton.Text = available and "RÉCLAMER MA RÉCOMPENSE" or ("⏳ DANS " .. Formulas.formatTime(remaining))
		claimButton.BackgroundColor3 = available and C.Green or C.PanelLight
		claimButton.TextColor3 = available and C.TextDark or C.TextDim

		for dayIndex, data in pairs(dayCards) do
			local isCurrent = dayIndex == (daily.dayIndex or 1)
			local claimed = dayIndex < (daily.dayIndex or 1)
			data.Status.Text = claimed and "✅ réclamé" or (isCurrent and (available and "👉 à réclamer" or "⏳ bientôt") or "🔒 à venir")
			data.Status.TextColor3 = claimed and C.TextDim or (isCurrent and C.Gold or C.TextDim)
			data.Card.BackgroundColor3 = isCurrent and C.PanelLight or C.Card
			data.Card:FindFirstChildOfClass("UIStroke").Transparency = isCurrent and 0.2 or 0.7
		end

		infoLabel.Text = available
			and "Ta récompense est prête ! Reviens tous les jours pour garder ta série."
			or "Tu as déjà réclamé aujourd'hui. Reviens plus tard pour le jour suivant !"
		streakLabel.Text = string.format("🔥 Série actuelle : %d jour(s)  •  Total réclamé : %s fois", daily.streak or 0, Formulas.formatNumber((profile.stats and profile.stats.dailies) or 0))
	end

	refresh()
	return refresh
end

return DailyUI
