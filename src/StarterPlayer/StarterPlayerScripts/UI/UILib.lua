--!strict
--[[
	UILib  |  StarterPlayer.StarterPlayerScripts.UI.UILib
	------------------------------------------------------------------
	Petite bibliothèque de composants UI (aucune dépendance externe).
	Tout est construit à la main : coins arrondis, dégradés, contours,
	boutons avec survol/clic animés, barres de progression, toasts,
	modales, listes défilantes.

	Utilisation typique :
		UILib.label(parent, "Texte", { Size = UDim2.fromScale(1, 0.2) })
		local button = UILib.button(parent, "CLIQUE", { Color = ... })
		button.MouseButton1Click:Connect(fn)
]]

local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local UIConfig = require(script.Parent.UIConfig)

local UILib = {}

local C = UIConfig.Colors
local EASE = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
local EASE_IN = TweenInfo.new(0.4, Enum.EasingStyle.Back, Enum.EasingDirection.Out)

-- ============================================================
-- PRIMITIVES
-- ============================================================
function UILib.create(className: string, props: { [string]: any }, parent: Instance?): any
	local instance = Instance.new(className)
	for key, value in pairs(props or {}) do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	if parent then
		instance.Parent = parent
	end
	if props and props.Parent then
		instance.Parent = props.Parent
	end
	return instance
end

function UILib.corner(instance: Instance, radius: UDim?): UICorner
	local corner = Instance.new("UICorner")
	corner.CornerRadius = radius or UIConfig.Radius.Medium
	corner.Parent = instance
	return corner
end

function UILib.stroke(instance: Instance, color: Color3?, thickness: number?, transparency: number?): UIStroke
	local stroke = Instance.new("UIStroke")
	stroke.Color = color or C.Stroke
	stroke.Thickness = thickness or 1.5
	stroke.Transparency = transparency or 0
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = instance
	return stroke
end

function UILib.gradient(instance: Instance, colorA: Color3, colorB: Color3, rotation: number?): UIGradient
	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(colorA, colorB)
	gradient.Rotation = rotation or 90
	gradient.Parent = instance
	return gradient
end

function UILib.padding(instance: Instance, top: number, bottom: number?, left: number?, right: number?): UIPadding
	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, top)
	padding.PaddingBottom = UDim.new(0, bottom or top)
	padding.PaddingLeft = UDim.new(0, left or top)
	padding.PaddingRight = UDim.new(0, right or left or top)
	padding.Parent = instance
	return padding
end

function UILib.tween(instance: Instance, props: { [string]: any }, info: TweenInfo?): Tween
	local tween = TweenService:Create(instance, info or EASE, props)
	tween:Play()
	return tween
end

function UILib.playClick(soundKey: string?)
	local key = soundKey or "click"
	local soundId = "rbxasset://sounds/clickfast.wav"
	if key == "pop" then
		soundId = "rbxasset://sounds/electronicpingshort.wav"
	end
	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = 0.25
	sound.PlaybackSpeed = key == "pop" and 1.3 or 1
	sound.Parent = SoundService
	sound:Play()
	task.delay(1, function()
		sound:Destroy()
	end)
end

-- ============================================================
-- TEXTE
-- ============================================================
function UILib.label(parent: Instance, text: string, opts: { [string]: any }?): TextLabel
	local options = opts or {}
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = options.BackgroundTransparency or 1
	label.BackgroundColor3 = options.Background or C.Panel
	label.Size = options.Size or UDim2.fromScale(1, 1)
	label.Position = options.Position or UDim2.fromScale(0, 0)
	label.AnchorPoint = options.AnchorPoint or Vector2.new(0, 0)
	label.Font = options.Font or UIConfig.FontBody
	label.Text = text
	label.TextColor3 = options.Color or C.Text
	label.TextSize = options.TextSize or 16
	label.TextScaled = options.TextScaled == true
	label.TextWrapped = options.TextWrapped == true
	label.TextXAlignment = options.TextXAlignment or Enum.TextXAlignment.Center
	label.TextYAlignment = options.TextYAlignment or Enum.TextYAlignment.Center
	label.RichText = options.RichText == true
	label.ZIndex = options.ZIndex or 1
	if options.Stroke then
		label.TextStrokeTransparency = 0.4
		label.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
	end
	label.Parent = parent
	return label
end

function UILib.title(parent: Instance, text: string, opts: { [string]: any }?): TextLabel
	local options = opts or {}
	options.Font = options.Font or UIConfig.FontTitle
	options.TextScaled = options.TextScaled == nil and true or options.TextScaled
	options.Color = options.Color or C.Gold
	options.Stroke = options.Stroke ~= false
	return UILib.label(parent, text, options)
end

-- ============================================================
-- BOUTONS
-- ============================================================
function UILib.button(parent: Instance, text: string, opts: { [string]: any }?): TextButton
	local options = opts or {}
	local button = Instance.new("TextButton")
	button.Name = options.Name or "Button"
	button.Size = options.Size or UDim2.fromOffset(200, 56)
	button.Position = options.Position or UDim2.fromScale(0, 0)
	button.AnchorPoint = options.AnchorPoint or Vector2.new(0, 0)
	button.BackgroundColor3 = options.Color or C.Card
	button.BackgroundTransparency = options.BackgroundTransparency or 0
	button.AutoButtonColor = false
	button.Font = options.Font or UIConfig.FontBold
	button.Text = text
	button.TextColor3 = options.TextColor or C.Text
	button.TextSize = options.TextSize or 18
	button.TextScaled = options.TextScaled == true
	button.TextWrapped = options.TextWrapped == true
	button.BorderSizePixel = 0
	button.ZIndex = options.ZIndex or 5
	button.LayoutOrder = options.LayoutOrder or 0
	button.Parent = parent

	UILib.corner(button, options.Radius or UIConfig.Radius.Medium)

	if options.Gradient then
		UILib.gradient(button, options.Gradient[1], options.Gradient[2], options.GradientRotation)
	end
	if options.StrokeColor then
		UILib.stroke(button, options.StrokeColor, options.StrokeThickness or 2)
	end

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = button

	local baseColor = button.BackgroundColor3

	button.MouseEnter:Connect(function()
		UILib.tween(scale, { Scale = 1.05 }, EASE_IN)
		if options.HoverColor then
			UILib.tween(button, { BackgroundColor3 = options.HoverColor })
		else
			UILib.tween(button, { BackgroundColor3 = baseColor:Lerp(Color3.fromRGB(255, 255, 255), 0.12) })
		end
	end)
	button.MouseLeave:Connect(function()
		UILib.tween(scale, { Scale = 1 }, EASE)
		UILib.tween(button, { BackgroundColor3 = baseColor }, EASE)
	end)
	button.MouseButton1Down:Connect(function()
		UILib.tween(scale, { Scale = 0.94 }, TweenInfo.new(0.08))
	end)
	button.MouseButton1Up:Connect(function()
		UILib.tween(scale, { Scale = 1.05 }, TweenInfo.new(0.1))
	end)
	if options.Silent ~= true then
		button.MouseButton1Click:Connect(function()
			UILib.playClick(options.Sound or "click")
		end)
	end

	return button
end

--- Bouton d'icône rond (barre latérale du HUD)
function UILib.iconButton(parent: Instance, emoji: string, labelText: string, opts: { [string]: any }?): TextButton
	local options = opts or {}
	local holder = Instance.new("Frame")
	holder.Name = options.Name or ("IconButton_" .. labelText)
	holder.Size = options.Size or UDim2.fromOffset(84, 84)
	holder.BackgroundTransparency = 1
	holder.Parent = parent

	local button = UILib.button(holder, "", {
		Size = UDim2.fromOffset(66, 66),
		Position = UDim2.new(0.5, 0, 0, 0),
		AnchorPoint = Vector2.new(0.5, 0),
		Color = options.Color or C.Card,
		Radius = UIConfig.Radius.Large,
		StrokeColor = options.StrokeColor or C.Stroke,
		StrokeThickness = 2,
	})
	button.Name = "ClickArea"

	local emojiLabel = UILib.label(button, emoji, {
		Size = UDim2.fromScale(1, 1),
		Font = UIConfig.FontTitle,
		TextScaled = true,
		ZIndex = 6,
	})
	emojiLabel.Name = "Emoji"
	UILib.padding(button, 12)

	local caption = UILib.label(holder, labelText, {
		Position = UDim2.new(0.5, 0, 0, 66),
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(84, 16),
		Font = UIConfig.FontBold,
		TextScaled = true,
		Color = C.TextDim,
		ZIndex = 6,
	})
	caption.Name = "Caption"

	local scale = Instance.new("UIScale")
	scale.Parent = holder
	button.MouseEnter:Connect(function()
		UILib.tween(scale, { Scale = 1.1 }, EASE_IN)
		UILib.tween(caption, { TextColor3 = C.Gold })
	end)
	button.MouseLeave:Connect(function()
		UILib.tween(scale, { Scale = 1 }, EASE)
		UILib.tween(caption, { TextColor3 = C.TextDim })
	end)

	local badge = UILib.label(button, "", {
		Position = UDim2.new(1, -6, 0, 4),
		AnchorPoint = Vector2.new(1, 0),
		Size = UDim2.fromOffset(26, 26),
		BackgroundTransparency = 1,
		Font = UIConfig.FontTitle,
		TextScaled = true,
		Color = C.Gold,
		ZIndex = 8,
	})
	badge.Name = "Badge"

	return button
end

-- ============================================================
-- CONTENEURS
-- ============================================================
function UILib.panel(parent: Instance, opts: { [string]: any }?): Frame
	local options = opts or {}
	local frame = Instance.new("Frame")
	frame.Name = options.Name or "Panel"
	frame.Size = options.Size or UDim2.fromScale(1, 1)
	frame.Position = options.Position or UDim2.fromScale(0, 0)
	frame.AnchorPoint = options.AnchorPoint or Vector2.new(0, 0)
	frame.BackgroundColor3 = options.Color or C.Panel
	frame.BackgroundTransparency = options.Transparency or 0
	frame.BorderSizePixel = 0
	frame.ZIndex = options.ZIndex or 1
	frame.LayoutOrder = options.LayoutOrder or 0
	frame.Parent = parent
	UILib.corner(frame, options.Radius or UIConfig.Radius.Large)
	if options.Stroke ~= false then
		UILib.stroke(frame, options.StrokeColor or C.Stroke, options.StrokeThickness or 1.5, options.StrokeTransparency or 0.2)
	end
	if options.Gradient then
		UILib.gradient(frame, options.Gradient[1], options.Gradient[2], options.GradientRotation)
	end
	return frame
end

function UILib.card(parent: Instance, opts: { [string]: any }?): Frame
	local options = opts or {}
	options.Color = options.Color or C.Card
	options.Radius = options.Radius or UIConfig.Radius.Medium
	return UILib.panel(parent, options)
end

function UILib.list(parent: Instance, props: { [string]: any }?): UIListLayout
	local layout = Instance.new("UIListLayout")
	layout.Padding = (props and props.Padding) or UDim.new(0, 8)
	layout.SortOrder = (props and props.SortOrder) or Enum.SortOrder.LayoutOrder
	layout.HorizontalAlignment = (props and props.HorizontalAlignment) or Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = (props and props.VerticalAlignment) or Enum.VerticalAlignment.Top
	layout.Parent = parent
	return layout
end

function UILib.grid(parent: Instance, cellSize: UDim2, padding: UDim?, fillDirection: Enum.FillDirection?): UIGridLayout
	local layout = Instance.new("UIGridLayout")
	layout.CellSize = cellSize
	layout.CellPadding = padding or UDim2.fromOffset(8, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.FillDirection = fillDirection or Enum.FillDirection.Horizontal
	layout.Parent = parent
	return layout
end

--- Zone défilante verticale propre
function UILib.scroll(parent: Instance, opts: { [string]: any }?): ScrollingFrame
	local options = opts or {}
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = options.Name or "Scroll"
	scroll.Size = options.Size or UDim2.fromScale(1, 1)
	scroll.Position = options.Position or UDim2.fromScale(0, 0)
	scroll.CanvasSize = UDim2.fromOffset(0, 0)
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.ScrollBarThickness = 6
	scroll.ScrollBarImageColor3 = C.Stroke
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollingDirection = Enum.ScrollingDirection.Y
	scroll.Parent = parent
	UILib.padding(scroll, options.Padding or 6)
	UILib.list(scroll, { Padding = UDim.new(0, 10), HorizontalAlignment = Enum.HorizontalAlignment.Center })
	return scroll
end

-- ============================================================
-- BARRE DE PROGRESSION
-- ============================================================
function UILib.bar(parent: Instance, opts: { [string]: any }?): (Frame, Frame)
	local options = opts or {}
	local holder = Instance.new("Frame")
	holder.Name = "Bar"
	holder.Size = options.Size or UDim2.new(1, 0, 0, 14)
	holder.Position = options.Position or UDim2.fromScale(0, 0)
	holder.BackgroundColor3 = C.Background
	holder.BorderSizePixel = 0
	holder.ClipsDescendants = true
	holder.Parent = parent
	UILib.corner(holder, UIConfig.Radius.Pill)

	local fill = Instance.new("Frame")
	fill.Name = "Fill"
	fill.Size = UDim2.fromScale(options.Value or 0.5, 1)
	fill.BackgroundColor3 = options.Color or C.Green
	fill.BorderSizePixel = 0
	fill.Parent = holder
	UILib.corner(fill, UIConfig.Radius.Pill)
	if options.Gradient then
		UILib.gradient(fill, options.Gradient[1], options.Gradient[2], 0)
	else
		UILib.gradient(fill, (options.Color or C.Green), (options.Color or C.Green):Lerp(C.White, 0.35), 0)
	end

	return holder, fill
end

function UILib.setBar(fill: Frame, value: number)
	local clamped = math.clamp(value, 0, 1)
	UILib.tween(fill, { Size = UDim2.fromScale(clamped, 1) }, TweenInfo.new(0.3, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
end

-- ============================================================
-- MODALES
-- ============================================================
local openModal: Frame? = nil
local modalBackdrop: TextButton? = nil
local modalRegistry: { [string]: Frame } = {}

function UILib.closeModal()
	if modalBackdrop then
		local backdrop = modalBackdrop
		modalBackdrop = nil
		UILib.tween(backdrop, { BackgroundTransparency = 1 }, EASE)
		task.delay(0.2, function()
			backdrop:Destroy()
		end)
	end
	if openModal then
		local frame = openModal
		openModal = nil
		local scale = frame:FindFirstChildOfClass("UIScale")
		if scale then
			UILib.tween(scale, { Scale = 0.85 }, EASE)
		end
		UILib.tween(frame, { BackgroundTransparency = 1 }, EASE)
		task.delay(0.18, function()
			frame.Visible = false
		end)
	end
end

function UILib.getOpenModal(): Frame?
	return openModal
end

--- Crée (une seule fois) une modale et renvoie sa frame + son contenu.
function UILib.modal(screenGui: ScreenGui, id: string, titleText: string, opts: { [string]: any }?): (Frame, Frame)
	local existing = modalRegistry[id]
	if existing then
		return existing, existing:FindFirstChild("Content") :: Frame
	end

	local options = opts or {}

	local frame = Instance.new("Frame")
	frame.Name = "Modal_" .. id
	frame.Size = options.Size or UIConfig.ModalSize
	frame.Position = UDim2.fromScale(0.5, 0.5)
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = C.Panel
	frame.BorderSizePixel = 0
	frame.Visible = false
	frame.ZIndex = 20
	frame.Parent = screenGui
	UILib.corner(frame, UIConfig.Radius.Large)
	UILib.stroke(frame, C.Stroke, 2, 0)
	UILib.gradient(frame, C.Panel, C.Background, 90)

	local scale = Instance.new("UIScale")
	scale.Scale = 1
	scale.Parent = frame

	-- En-tête
	local header = Instance.new("Frame")
	header.Name = "Header"
	header.Size = UDim2.new(1, 0, 0, 62)
	header.BackgroundColor3 = C.PanelLight
	header.BorderSizePixel = 0
	header.ZIndex = 21
	header.Parent = frame
	local headerCorner = UILib.corner(header, UIConfig.Radius.Large)
	headerCorner.CornerRadius = UDim.new(0, 20)

	local headerMask = Instance.new("Frame")
	headerMask.Name = "Mask"
	headerMask.Size = UDim2.new(1, 0, 0.5, 0)
	headerMask.Position = UDim2.fromScale(0, 0.5)
	headerMask.BackgroundColor3 = C.PanelLight
	headerMask.BorderSizePixel = 0
	headerMask.ZIndex = 21
	headerMask.Parent = header

	UILib.title(header, titleText, {
		Size = UDim2.new(1, -120, 1, 0),
		Position = UDim2.fromOffset(20, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 22,
	})

	local closeButton = UILib.button(header, "✕", {
		Size = UDim2.fromOffset(40, 40),
		Position = UDim2.new(1, -50, 0.5, 0),
		AnchorPoint = Vector2.new(0, 0.5),
		Color = C.Red,
		Radius = UIConfig.Radius.Pill,
		ZIndex = 23,
	})
	closeButton.MouseButton1Click:Connect(function()
		UILib.closeModal()
	end)

	-- Contenu
	local content = Instance.new("ScrollingFrame")
	content.Name = "Content"
	content.Size = UDim2.new(1, -24, 1, -80)
	content.Position = UDim2.fromOffset(12, 70)
	content.BackgroundTransparency = 1
	content.BorderSizePixel = 0
	content.ScrollBarThickness = 6
	content.ScrollBarImageColor3 = C.Stroke
	content.CanvasSize = UDim2.fromOffset(0, 0)
	content.AutomaticCanvasSize = Enum.AutomaticSize.Y
	content.ScrollingDirection = Enum.ScrollingDirection.Y
	content.ZIndex = 21
	content.Parent = frame
	UILib.list(content, { Padding = UDim.new(0, 10) })

	modalRegistry[id] = frame
	return frame, content
end

--- Ouvre une modale (ferme automatiquement la précédente).
function UILib.showModal(screenGui: ScreenGui, id: string, titleText: string, opts: { [string]: any }?): (Frame, Frame)
	local frame, content = UILib.modal(screenGui, id, titleText, opts)
	-- La modale est déjà construite mais son contenu est reconstruit par l'appelant

	if openModal and openModal ~= frame then
		local previous = openModal
		openModal = nil
		local prevScale = previous:FindFirstChildOfClass("UIScale")
		if prevScale then
			UILib.tween(prevScale, { Scale = 0.9 }, EASE)
		end
		previous.Visible = false
	end

	if not modalBackdrop then
		local backdrop = Instance.new("TextButton")
		backdrop.Name = "ModalBackdrop"
		backdrop.Size = UDim2.fromScale(1, 1)
		backdrop.BackgroundColor3 = C.Background
		backdrop.BackgroundTransparency = 0.45
		backdrop.Text = ""
		backdrop.AutoButtonColor = false
		backdrop.ZIndex = 15
		backdrop.Parent = screenGui
		backdrop.MouseButton1Click:Connect(function()
			UILib.closeModal()
		end)
		modalBackdrop = backdrop
		UILib.tween(backdrop, { BackgroundTransparency = 0.45 }, EASE)
	end

	openModal = frame
	frame.Visible = true
	local scale = frame:FindFirstChildOfClass("UIScale")
	if scale then
		scale.Scale = 0.85
		UILib.tween(scale, { Scale = 1 }, EASE_IN)
	end
	frame.BackgroundTransparency = 0
	return frame, content
end

--- Vide le contenu d'une modale avant de le reconstruire.
function UILib.clearContent(content: Frame)
	for _, child in ipairs(content:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then
			child:Destroy()
		end
	end
end

-- ============================================================
-- TOASTS
-- ============================================================
local toastStack: Frame? = nil

function UILib.setToastStack(frame: Frame)
	toastStack = frame
	if not frame:FindFirstChildOfClass("UIListLayout") then
		UILib.list(frame, { Padding = UDim.new(0, 6) })
	end
end

function UILib.toast(text: string, color: Color3?, icon: string?)
	if not toastStack then
		return
	end
	local toast = Instance.new("Frame")
	toast.Name = "Toast"
	toast.Size = UDim2.fromOffset(340, 46)
	toast.BackgroundColor3 = C.PanelLight
	toast.BorderSizePixel = 0
	toast.BackgroundTransparency = 1
	toast.ZIndex = 30
	toast.Parent = toastStack
	UILib.corner(toast, UIConfig.Radius.Medium)
	local stroke = UILib.stroke(toast, color or C.Gold, 2, 1)

	local iconLabel = UILib.label(toast, icon or "✨", {
		Size = UDim2.fromOffset(36, 36),
		Position = UDim2.fromOffset(6, 5),
		Font = UIConfig.FontTitle,
		TextScaled = true,
		ZIndex = 31,
	})
	iconLabel.Name = "Icon"

	local textLabel = UILib.label(toast, text, {
		Size = UDim2.new(1, -50, 1, 0),
		Position = UDim2.fromOffset(46, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		TextWrapped = true,
		Font = UIConfig.FontBold,
		TextSize = 13,
		Color = color or C.Text,
		ZIndex = 31,
	})
	textLabel.Name = "Text"

	toast.BackgroundTransparency = 1
	stroke.Transparency = 1
	textLabel.TextTransparency = 1
	iconLabel.TextTransparency = 1
	UILib.tween(toast, { BackgroundTransparency = 0.1 }, EASE)
	UILib.tween(stroke, { Transparency = 0.2 }, EASE)
	UILib.tween(textLabel, { TextTransparency = 0 }, EASE)
	UILib.tween(iconLabel, { TextTransparency = 0 }, EASE)

	task.delay(4, function()
		if not toast.Parent then
			return
		end
		UILib.tween(toast, { BackgroundTransparency = 1, Size = UDim2.fromOffset(340, 0) }, TweenInfo.new(0.3))
		if toast:FindFirstChildOfClass("UIStroke") then
			UILib.tween(toast:FindFirstChildOfClass("UIStroke") :: UIStroke, { Transparency = 1 }, TweenInfo.new(0.25))
		end
		UILib.tween(textLabel, { TextTransparency = 1 }, TweenInfo.new(0.25))
		UILib.tween(iconLabel, { TextTransparency = 1 }, TweenInfo.new(0.25))
		task.delay(0.35, function()
			toast:Destroy()
		end)
	end)
end

-- ============================================================
-- UTILITAIRES D'ANIMATION
-- ============================================================
function UILib.pulse(instance: GuiObject, scaleAmount: number?)
	local scale = instance:FindFirstChildOfClass("UIScale")
	if not scale then
		scale = Instance.new("UIScale")
		scale.Parent = instance
	end
	local target = scaleAmount or 1.15
	scale.Scale = 1
	UILib.tween(scale, { Scale = target }, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.Out))
	task.delay(0.12, function()
		if scale.Parent then
			UILib.tween(scale, { Scale = 1 }, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out))
		end
	end)
end

function UILib.fadeIn(instance: GuiObject, duration: number?)
	instance.BackgroundTransparency = 1
	UILib.tween(instance, { BackgroundTransparency = 0 }, TweenInfo.new(duration or 0.25))
end

--- Compteur animé (puissance qui monte en douceur)
--- NOTE : on n'utilise pas TweenService ici car il ne fonctionne que sur
--- des Instances, pas sur des tables Lua.
function UILib.animateNumber(label: TextLabel, from: number, to: number, formatter, duration: number?)
	formatter = formatter or tostring
	local lifeTime = duration or 0.45
	task.spawn(function()
		local startTime = os.clock()
		while true do
			local elapsed = os.clock() - startTime
			local alpha = math.clamp(elapsed / lifeTime, 0, 1)
			-- easing "quad out"
			local eased = 1 - (1 - alpha) * (1 - alpha)
			if not label.Parent then
				return
			end
			label.Text = formatter(from + (to - from) * eased)
			if alpha >= 1 then
				label.Text = formatter(to)
				return
			end
			task.wait(0.03)
		end
	end)
end

return UILib
