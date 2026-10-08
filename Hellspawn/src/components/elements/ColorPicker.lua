--[[
	ColorPicker
	HSV square, hue rail, optional alpha rail, hex entry, rainbow mode and a
	shared colour clipboard. Works inline (on a toggle/label) or as a row.

		toggle:AddColorPicker("esp_color", { Default = Color3.fromRGB(226, 22, 60), Transparency = 0 })
		box:AddColorPicker("sky", { Text = "Sky tint", Default = Color3.new(0, 0, 0) })
]]

local Env = import("core/Env")
local Util = import("core/Util")
local Anim = import("core/Anim")
local Input = import("core/Input")
local Glow = import("fx/Glow")
local Style = import("components/Style")
local Element = import("components/Element")

local ColorPicker = Element.extend("ColorPicker")

local SV = 156
local RAIL = 12
local PAD = 8
local HEADER = 24

local function checker(library, parent, zindex)
	local meta = library.Assets:Meta("checker")
	return Util.passive(Util.create("ImageLabel", {
		Name = "Checker",
		BackgroundTransparency = 1,
		Image = library.Assets:Texture("checker"),
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(meta.Size / 2, meta.Size / 2),
		Size = UDim2.fromScale(1, 1),
		ZIndex = zindex,
		Parent = parent,
	}))
end

function ColorPicker.new(container, flag, opts, host)
	flag, opts = Element.args(flag, opts)
	local self = setmetatable({}, ColorPicker)
	Element.init(self, container, flag, opts, {
		Text = host and host.Text or "Color",
		Default = Color3.fromRGB(255, 255, 255),
	})
	local o = self.Options
	self.Value = o.Default
	self.HasAlpha = o.Transparency ~= nil
	self.Transparency = o.Transparency or 0
	self.Hue, self.Sat, self.Val = o.Default:ToHSV()
	self.Rainbow = false
	self.Open = false

	local library = self.Library
	local theme = self.Theme

	local swatch = Util.create("TextButton", {
		Name = "Swatch",
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(26, 12),
		ZIndex = 3,
	})
	Util.corner(swatch, 2)
	checker(library, swatch, 3)
	local color = Util.create("Frame", {
		Name = "Color",
		BorderSizePixel = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
		Parent = swatch,
	})
	Util.corner(color, 2)
	Util.passive(color)
	local stroke = Util.stroke(swatch)
	theme:Bind(stroke, { Color = "BorderLight" })
	self.Swatch = swatch
	self.SwatchColor = color
	self.SwatchStroke = stroke
	self.Glow = Glow.attach(library, swatch, { Spread = 7, Strength = 0.22, Color = self.Value })
	self.Hitbox = swatch

	self.Maid:Give((Input.hover(swatch, function(state)
		self.Hovered = state
		self:_paint()
	end)))
	self.Maid:Give(swatch.Activated:Connect(function()
		if self.Disabled then
			return
		end
		if self.Open then
			self:Close()
		else
			self:OpenPicker()
		end
	end))

	if host then
		swatch.LayoutOrder = 10 + #host.Addons:GetChildren()
		swatch.Parent = host.Addons
		self:_mount(swatch, host)
	else
		local row = Util.create("Frame", {
			Name = "ColorPicker",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, Style.Row),
		})
		self.Label = Style.label(library, {
			Text = self.Text,
			Weight = "Medium",
			Color = "TextDim",
			Size = UDim2.new(1, -36, 1, 0),
			Truncate = true,
			Parent = row,
		})
		swatch.AnchorPoint = Vector2.new(1, 0.5)
		swatch.Position = UDim2.fromScale(1, 0.5)
		swatch.Parent = row
		self:_mount(row)
	end

	self.Maid:Give(library.RainbowTick:Connect(function(hue)
		if self.Rainbow then
			self.Hue = hue
			self:_commit(true)
		end
	end))

	if self.Flag then
		library.Flags[self.Flag] = self.Value
	end
	self:_paint(true)
	return self
end

function ColorPicker:_paint(instant)
	local time = instant and 0 or 0.15
	self.SwatchColor.BackgroundColor3 = self.Value
	self.SwatchColor.BackgroundTransparency = self.Transparency
	Glow.setColor(self.Glow, self.Value)
	Anim.tween(self.SwatchStroke, {
		Transparency = self.Disabled and 0.6 or 0,
	}, time)
	Glow.set(self.Glow, self.Disabled and 0 or ((self.Hovered or self.Open) and 0.5 or 0.22), instant and 0 or 0.2)
	if self._sync then
		self._sync()
	end
end

-- Applies HSV/alpha state → Value, repaints, notifies.
-- `exact` keeps a caller-supplied colour bit-for-bit (no HSV round trip).
function ColorPicker:_commit(fromRainbow, exact)
	self.Value = exact or Color3.fromHSV(self.Hue, self.Sat, self.Val)
	self:_paint(true)
	if fromRainbow then
		local now = os.clock()
		if now - (self._lastRainbowEmit or 0) < 1 / 30 then
			return
		end
		self._lastRainbowEmit = now
	end
	self:_emit(self.Value, self.Transparency)
end

function ColorPicker:OpenPicker()
	local library = self.Library
	local theme = self.Theme
	local width = PAD + SV + 8 + RAIL + (self.HasAlpha and (8 + RAIL) or 0) + PAD
	local height = HEADER + SV + 8 + 20 + PAD

	self.Open = true
	local popup = library.Popups:Open({
		Owner = self.Swatch,
		Width = width,
		Height = height,
		Align = "right",
		OnClose = function()
			self.Open = false
			self._sync = nil
			self._popup = nil
			self:_paint()
		end,
	})
	self._popup = popup
	local content = popup.Content

	Style.label(library, {
		Text = self.Text,
		Weight = "Bold",
		TextSize = Style.Small,
		Color = "Text",
		Position = UDim2.fromOffset(PAD, 5),
		Size = UDim2.new(1, -PAD * 2 - 60, 0, 14),
		Truncate = true,
		ZIndex = 12,
		Parent = content,
	})
	local readout = Style.label(library, {
		Name = "Readout",
		Color = "TextMuted",
		TextSize = Style.Tiny,
		XAlign = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -PAD, 0, 5),
		Size = UDim2.fromOffset(80, 14),
		ZIndex = 12,
		Parent = content,
	})

	-- saturation / value square
	local square = Util.create("Frame", {
		Name = "SV",
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(PAD, HEADER),
		Size = UDim2.fromOffset(SV, SV),
		ZIndex = 12,
		Parent = content,
	})
	local whiteFade = Util.passive(Util.create("Frame", {
		Name = "White",
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 13,
		Parent = square,
	}))
	Util.gradient(whiteFade, { Transparency = NumberSequence.new(0, 1) })
	local blackFade = Util.passive(Util.create("Frame", {
		Name = "Black",
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(0, 0, 0),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 14,
		Parent = square,
	}))
	Util.gradient(blackFade, { Transparency = NumberSequence.new(1, 0), Rotation = 90 })
	local squareStroke = Util.stroke(square)
	theme:Bind(squareStroke, { Color = "Border" })

	local svCursor = Util.passive(Util.create("ImageLabel", {
		Name = "Cursor",
		BackgroundTransparency = 1,
		Image = library.Assets:Texture("ring"),
		ImageColor3 = Color3.new(1, 1, 1),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(12, 12),
		ZIndex = 16,
		Parent = square,
	}))
	Util.passive(Util.create("ImageLabel", {
		Name = "Shade",
		BackgroundTransparency = 1,
		Image = library.Assets:Texture("ring"),
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.4,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(15, 15),
		ZIndex = 15,
		Parent = svCursor,
	}))

	local function rail(name, x)
		local frame = Util.create("Frame", {
			Name = name,
			BorderSizePixel = 0,
			BackgroundColor3 = Color3.new(1, 1, 1),
			Position = UDim2.fromOffset(x, HEADER),
			Size = UDim2.fromOffset(RAIL, SV),
			ZIndex = 12,
			Parent = content,
		})
		local railStroke = Util.stroke(frame)
		theme:Bind(railStroke, { Color = "Border" })
		local cursor = Util.passive(Util.create("Frame", {
			Name = "Cursor",
			BorderSizePixel = 0,
			BackgroundColor3 = Color3.new(1, 1, 1),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.new(1, 4, 0, 3),
			ZIndex = 16,
			Parent = frame,
		}))
		local cursorStroke = Util.stroke(cursor)
		cursorStroke.Color = Color3.new(0, 0, 0)
		cursorStroke.Transparency = 0.3
		return frame, cursor
	end

	local hueRail, hueCursor = rail("Hue", PAD + SV + 8)
	Util.gradient(hueRail, { Color = Util.hueSequence(), Rotation = 90 })

	local alphaRail, alphaCursor, alphaFill
	if self.HasAlpha then
		alphaRail, alphaCursor = rail("Alpha", PAD + SV + 8 + RAIL + 8)
		alphaRail.BackgroundTransparency = 1
		checker(library, alphaRail, 12)
		alphaFill = Util.passive(Util.create("Frame", {
			Name = "Fill",
			BorderSizePixel = 0,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 13,
			Parent = alphaRail,
		}))
		Util.gradient(alphaFill, { Transparency = NumberSequence.new(0, 1), Rotation = 90 })
	end

	-- bottom row: hex · rainbow · copy · paste
	local rowY = HEADER + SV + 8
	local hexFrame = Style.surface(library, {
		Name = "Hex",
		Position = UDim2.fromOffset(PAD, rowY),
		Size = UDim2.fromOffset(86, 20),
		ZIndex = 12,
		Parent = content,
	})
	local hexBox = Util.create("TextBox", {
		Name = "Input",
		BackgroundTransparency = 1,
		ClearTextOnFocus = false,
		Text = "",
		FontFace = Style.font(library, "Regular"),
		TextSize = Style.Small,
		Position = UDim2.fromOffset(6, 0),
		Size = UDim2.new(1, -12, 1, 0),
		TextXAlignment = Enum.TextXAlignment.Left,
		ZIndex = 13,
		Parent = hexFrame,
	})
	theme:Bind(hexBox, { TextColor3 = "Text" })

	local buttons = {}
	local function iconButton(icon, index, tooltip, onClick)
		local button = Style.surface(library, {
			Class = "TextButton",
			Name = icon,
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.new(1, -PAD - (index - 1) * 24, 0, rowY),
			Size = UDim2.fromOffset(20, 20),
			ZIndex = 12,
			Parent = content,
		})
		local image = Style.icon(library, {
			Icon = icon,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(11, 11),
			Color = "TextDim",
			ZIndex = 13,
			Parent = button,
		})
		button.Activated:Connect(onClick)
		self.Maid:Set("tip_" .. icon, library:_attachTooltip(button, tooltip))
		buttons[icon] = image
		return button, image
	end

	iconButton("tag", 1, "paste colour", function()
		local clip = library.ColorClipboard
		if clip then
			self:SetValue(clip.Value, clip.Transparency)
		end
	end)
	iconButton("copy", 2, "copy colour", function()
		library.ColorClipboard = { Value = self.Value, Transparency = self.Transparency }
		Env.copy("#" .. Util.toHex(self.Value))
		library:Notify({ Title = "Colour copied", Content = "#" .. Util.toHex(self.Value), Duration = 1.6, Type = "info" })
	end)
	local _, rainbowIcon = iconButton("flame", 3, "rainbow", function()
		self:SetRainbow(not self.Rainbow)
	end)

	-- live sync of every visual in the popup
	self._sync = function()
		local hueColor = Color3.fromHSV(self.Hue, 1, 1)
		square.BackgroundColor3 = hueColor
		svCursor.Position = UDim2.fromScale(self.Sat, 1 - self.Val)
		hueCursor.Position = UDim2.fromScale(0.5, self.Hue)
		if alphaFill then
			alphaFill.BackgroundColor3 = self.Value
			alphaCursor.Position = UDim2.fromScale(0.5, self.Transparency)
		end
		if not hexBox:IsFocused() then
			hexBox.Text = "#" .. Util.toHex(self.Value)
		end
		local r, g, b = math.floor(self.Value.R * 255 + 0.5), math.floor(self.Value.G * 255 + 0.5), math.floor(self.Value.B * 255 + 0.5)
		readout.Text = string.format("%d %d %d", r, g, b) .. (self.HasAlpha and string.format(" · %d%%", math.floor((1 - self.Transparency) * 100 + 0.5)) or "")
		rainbowIcon.ImageColor3 = theme:Get(self.Rainbow and "Accent" or "TextDim")
	end
	self._sync()

	local function dragArea(target, apply)
		local hit = Style.hitbox({ Name = "Hit", ZIndex = 17, Parent = target })
		Input.drag(hit, {
			onStart = function(position)
				apply(position)
			end,
			onMove = function(position)
				apply(position)
			end,
		})
	end

	local function relative(target, position)
		local abs, size = target.AbsolutePosition, target.AbsoluteSize
		return math.clamp((position.X - abs.X) / size.X, 0, 1), math.clamp((position.Y - abs.Y) / size.Y, 0, 1)
	end

	dragArea(square, function(position)
		local x, y = relative(square, position)
		self.Sat, self.Val = x, 1 - y
		self:_commit()
	end)
	dragArea(hueRail, function(position)
		local _, y = relative(hueRail, position)
		self.Hue = math.min(y, 0.9999)
		self.Rainbow = false
		self:_commit()
	end)
	if alphaRail then
		dragArea(alphaRail, function(position)
			local _, y = relative(alphaRail, position)
			self.Transparency = Util.round(y, 3)
			self:_commit()
		end)
	end

	hexBox.FocusLost:Connect(function()
		local parsed = Util.fromHex(hexBox.Text)
		if parsed then
			self:SetValue(parsed)
		end
		if self._sync then
			self._sync()
		end
	end)
end

function ColorPicker:Close()
	if self._popup then
		self._popup.Close()
	end
end

function ColorPicker:SetValue(color, transparency)
	if typeof(color) ~= "Color3" then
		return
	end
	local h, s, v = color:ToHSV()
	-- greys and black carry no hue; keep the old one so the rail doesn't jump
	if s > 0 and v > 0 then
		self.Hue = h
	end
	self.Sat, self.Val = s, v
	if transparency ~= nil and self.HasAlpha then
		self.Transparency = math.clamp(transparency, 0, 1)
	end
	self:_commit(false, color)
end

-- Linoria-compatible alias
ColorPicker.SetValueRGB = ColorPicker.SetValue

function ColorPicker:SetHSV(h, s, v)
	self.Hue, self.Sat, self.Val = h, s, v
	self:_commit()
end

function ColorPicker:SetRainbow(enabled)
	self.Rainbow = enabled == true
	self:_paint()
end

function ColorPicker:_serialize()
	return { Hex = Util.toHex(self.Value), Alpha = self.Transparency, Rainbow = self.Rainbow }
end

function ColorPicker:_deserialize(data)
	if type(data) ~= "table" then
		return
	end
	local color = Util.fromHex(data.Hex)
	if color then
		self:SetValue(color, data.Alpha)
	end
	self:SetRainbow(data.Rainbow == true)
end

function ColorPicker:Destroy()
	self:Close()
	Element.Destroy(self)
end

return ColorPicker
