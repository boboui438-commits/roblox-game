--!strict
--[[
	AchievementsUI  |  StarterPlayer.StarterPlayerScripts.UI.AchievementsUI
	------------------------------------------------------------------
	Liste des 24 succès avec progression et récompense.
	(l'octroi est entièrement serveur, l'UI ne fait qu'afficher)
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Modules = ReplicatedStorage:WaitForChild("Modules")
local GameConfig = require(Modules:WaitForChild("GameConfig"))
local Formulas = require(Modules:WaitForChild("Formulas"))

local UIConfig = require(script.Parent.UIConfig)
local UILib = require(script.Parent.UILib)
local ClientState = require(script.Parent.Parent.Controllers.ClientState)

local AchievementsUI = {}

local C = UIConfig.Colors

local function getStatValue(profile, statName: string): number
	if statName == "rebirths" then
		return profile.rebirths or 0
	elseif statName == "bestPower" then
		return math.max(profile.bestPower or 0, profile.power or 0)
	elseif statName == "maxWorld" then
		return profile.maxWorld or 1
	elseif statName == "streak" then
		return (profile.daily and profile.daily.streak) or 0
	end
	return (profile.stats and profile.stats[statName]) or 0
end

function AchievementsUI.show(ctx)
	local frame, content = UILib.showModal(ctx.screenGui, "achievements", "🏅 SUCCÈS", { Size = UDim2.fromOffset(780, 580) })
	UILib.clearContent(content)

	local summary = UILib.card(content, {
		Name = "Summary",
		Size = UDim2.new(1, -8, 0, 56),
		Color = C.Card,
		LayoutOrder = 0,
	})
	local summaryLabel = UILib.label(summary, "", {
		Size = UDim2.new(1, -24, 1, 0),
		Position = UDim2.fromOffset(12, 0),
		Font = UIConfig.FontBold,
		TextSize = 14,
		Color = C.Green,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
	summaryLabel.Name = "Text"

	local holder = Instance.new("Frame")
	holder.Name = "Holder"
	holder.Size = UDim2.new(1, -8, 0, 0)
	holder.AutomaticSize = Enum.AutomaticSize.Y
	holder.BackgroundTransparency = 1
	holder.LayoutOrder = 1
	holder.Parent = content
	UILib.list(holder, { Padding = UDim.new(0, 6) })

	local rows = {}

	for index, achievementId in ipairs(GameConfig.AchievementOrder) do
		local achievement = GameConfig.Achievements[achievementId]
		if achievement then
			local row = UILib.card(holder, {
				Name = "Ach_" .. achievementId,
				Size = UDim2.new(1, -8, 0, 62),
				Color = C.Card,
				LayoutOrder = index,
			})

			local icon = UILib.label(row, achievement.Icon, {
				Size = UDim2.fromOffset(46, 46),
				Position = UDim2.fromOffset(10, 8),
				Font = UIConfig.FontTitle,
				TextScaled = true,
			})
			icon.Name = "Icon"

			local name = UILib.label(row, achievement.Name, {
				Size = UDim2.new(1, -300, 0, 20),
				Position = UDim2.fromOffset(64, 8),
				Font = UIConfig.FontBold,
				TextSize = 14,
				Color = C.Text,
				TextXAlignment = Enum.TextXAlignment.Left,
			})
			name.Name = "Name"

			local desc = UILib.label(row, achievement.Desc, {
				Size = UDim2.new(1, -300, 0, 16),
				Position = UDim2.fromOffset(64, 26),
				Font = UIConfig.FontSmall,
				TextSize = 11,
				Color = C.TextDim,
				TextXAlignment = Enum.TextXAlignment.Left,
			})
			desc.Name = "Desc"

			local barHolder, barFill = UILib.bar(row, {
				Size = UDim2.new(0, 200, 0, 6),
				Position = UDim2.fromOffset(64, 46),
				Color = C.Green,
			})
			barHolder.Name = "Progress"

			local progressLabel = UILib.label(row, "", {
				Size = UDim2.new(1, -320, 0, 16),
				Position = UDim2.new(0, 274, 0, 42),
				Font = UIConfig.FontSmall,
				TextSize = 10,
				Color = C.TextDim,
				TextXAlignment = Enum.TextXAlignment.Left,
			})
			progressLabel.Name = "ProgressText"

			local reward = UILib.label(row, "🏆 +" .. Formulas.formatNumber(achievement.Reward), {
				Size = UDim2.fromOffset(160, 62),
				Position = UDim2.new(1, -170, 0, 0),
				Font = UIConfig.FontTitle,
				TextSize = 15,
				Color = C.Gold,
				TextXAlignment = Enum.TextXAlignment.Right,
			})
			reward.Name = "Reward"

			table.insert(rows, {
				Achievement = achievement,
				Row = row,
				Fill = barFill,
				ProgressLabel = progressLabel,
				Icon = icon,
				Name = name,
			})
		end
	end

	local function refresh()
		local profile = ClientState.profile
		local unlockedCount = 0
		for _, data in ipairs(rows) do
			local value = getStatValue(profile, data.Achievement.Stat)
			local unlocked = profile.achievements and profile.achievements[data.Achievement.Id]
			local progress = math.min(value, data.Achievement.Goal)
			if unlocked then
				unlockedCount = unlockedCount + 1
			end

			UILib.setBar(data.Fill, progress / data.Achievement.Goal)
			data.Fill.BackgroundColor3 = unlocked and C.Gold or C.Green
			data.ProgressLabel.Text = string.format("%s / %s", Formulas.formatNumber(progress), Formulas.formatNumber(data.Achievement.Goal))
			data.Row.BackgroundColor3 = unlocked and C.PanelLight or C.Card
			data.Name.TextColor3 = unlocked and C.Gold or C.Text
			data.Row:FindFirstChild("Reward").TextColor3 = unlocked and C.Green or C.Gold
		end
		summaryLabel.Text = string.format("🏅 %d / %d succès débloqués  •  continue comme ça !", unlockedCount, #rows)
	end

	refresh()
	return refresh
end

return AchievementsUI
