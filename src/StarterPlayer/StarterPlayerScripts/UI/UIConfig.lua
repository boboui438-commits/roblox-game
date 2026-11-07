--!strict
--[[
	UIConfig  |  StarterPlayer.StarterPlayerScripts.UI.UIConfig
	------------------------------------------------------------------
	Thème visuel unique du jeu (couleurs, polices, tailles).
	Toute l'interface lit ce module → changer une couleur ici la change
	partout.
]]

local UIConfig = {}

-- Polices (natives Roblox : aucun asset à importer)
UIConfig.FontTitle = Enum.Font.FredokaOne
UIConfig.FontBold = Enum.Font.GothamBlack
UIConfig.FontBody = Enum.Font.GothamMedium
UIConfig.FontSmall = Enum.Font.Gotham

-- Palette
UIConfig.Colors = {
	Background = Color3.fromRGB(13, 15, 28),
	Panel = Color3.fromRGB(22, 25, 44),
	PanelLight = Color3.fromRGB(32, 36, 62),
	Card = Color3.fromRGB(38, 42, 72),
	CardHover = Color3.fromRGB(50, 56, 92),
	Stroke = Color3.fromRGB(70, 80, 130),

	Gold = Color3.fromRGB(255, 210, 74),
	Green = Color3.fromRGB(109, 255, 160),
	Blue = Color3.fromRGB(89, 198, 255),
	Purple = Color3.fromRGB(180, 123, 255),
	Pink = Color3.fromRGB(255, 109, 209),
	Red = Color3.fromRGB(255, 96, 96),
	Orange = Color3.fromRGB(255, 160, 70),
	Cyan = Color3.fromRGB(90, 255, 235),

	Text = Color3.fromRGB(240, 245, 255),
	TextDim = Color3.fromRGB(165, 175, 205),
	TextDark = Color3.fromRGB(20, 22, 40),

	Transparent = Color3.fromRGB(0, 0, 0),
	White = Color3.fromRGB(255, 255, 255),
}

-- Rayons
UIConfig.Radius = {
	Small = UDim.new(0, 8),
	Medium = UDim.new(0, 14),
	Large = UDim.new(0, 20),
	Pill = UDim.new(1, 0),
}

-- Position des éléments du HUD (ancrage)
UIConfig.Layout = {
	HudTopLeft = UDim2.new(0, 16, 0, 12),
	HudTopRight = UDim2.new(1, -16, 0, 12),
	ButtonsRight = UDim2.new(1, -14, 0, 120),
	BottomCenter = UDim2.new(0.5, 0, 1, -18),
}

-- Tailles des modales
UIConfig.ModalSize = UDim2.new(0, 720, 0, 520)
UIConfig.ModalSizeSmall = UDim2.new(0, 560, 0, 430)

-- Couleurs par rareté (remplies par UIController depuis GameConfig)
UIConfig.RarityColors = {}

-- Utilitaire : couleur → hex string (pour les remotes)
function UIConfig.toHex(color: Color3): string
	return string.format("%02x%02x%02x", math.floor(color.R * 255 + 0.5), math.floor(color.G * 255 + 0.5), math.floor(color.B * 255 + 0.5))
end

function UIConfig.fromHex(hex: string): Color3
	local r = tonumber(string.sub(hex, 1, 2), 16) or 255
	local g = tonumber(string.sub(hex, 3, 4), 16) or 255
	local b = tonumber(string.sub(hex, 5, 6), 16) or 255
	return Color3.fromRGB(r, g, b)
end

return UIConfig
