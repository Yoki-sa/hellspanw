--[[
	Toggle
	ImGui checkbox: a small square that floods with the accent gradient and
	lights up with a neon halo when enabled. Supports inline addons.

		local t = box:AddToggle("esp", { Text = "ESP", Default = true, Callback = fn })
		t:AddKeybind("esp_key", { Default = Enum.KeyCode.E })
		t:AddColorPicker("esp_color", { Default = Color3.new(1, 0, 0) })
]]

local Util = import("core/Util")
local Anim = import("core/Anim")
local Input = import("core/Input")
local Glow = import("fx/Glow")
local Style = import("components/Style")
local Element = import("components/Element")
local Addons = import("components/Addons")

local Toggle = Element.extend("Toggle")
Addons.install(Toggle)

local BOX = 12

function Toggle.new(container, flag, opts)
	flag, opts = Element.args(flag, opts)
	local self = setmetatable({}, Toggle)
	Element.init(self, container, flag, opts, {
		Text = "Toggle",
		Default = false,
		Risky = false,
	})
	self.Value = self.Options.Default == true
	local library = self.Library
	local theme = self.Theme

	local row = Style.hitbox({ Name = "Toggle", Size = UDim2.new(1, 0, 0, Style.Row) })
	self.Hitbox = row

	-- decorative: the whole row is the click target
	local box = Util.passive(Util.create("Frame", {
		Name = "Box",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(BOX, BOX),
		BorderSizePixel = 0,
		Parent = row,
	}))
	Util.corner(box, 2)
	theme:Bind(box, { BackgroundColor3 = "Surface" })
	self.Box = box
	self.BoxStroke = Util.stroke(box)
	self.Glow = Glow.attach(library, box, { Spread = 9, Strength = 0 })

	local fill = Util.create("Frame", {
		Name = "Fill",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(self.Value and 1 or 0.35, self.Value and 1 or 0.35),
		BackgroundColor3 = Color3.new(1, 1, 1),
		BackgroundTransparency = self.Value and 0 or 1,
		BorderSizePixel = 0,
		Parent = box,
	})
	Util.corner(fill, 2)
	local gradient = Util.gradient(fill, { Rotation = 90 })
	theme:Bind(gradient, { Color = "AccentGradient" })
	self.Fill = fill

	self.Check = Style.icon(library, {
		Name = "Check",
		Icon = "check",
		Size = UDim2.fromOffset(8, 8),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Color = "OnAccent",
		Transparency = self.Value and 0 or 1,
		Parent = fill,
	})

	self.Label = Style.label(library, {
		Text = self.Text,
		Weight = "Medium",
		Color = false,
		Position = UDim2.fromOffset(BOX + 8, 0),
		Size = UDim2.new(1, -(BOX + 8), 1, 0),
		Truncate = true,
		Parent = row,
	})

	self.Addons = Addons.frame(row, 3)
	Addons.reserve(self, self.Label, BOX + 8)

	self.Maid:Give((Input.hover(row, function(state)
		self.Hovered = state
		self:_paint()
	end)))

	self.Maid:Give(row.Activated:Connect(function()
		if self.Disabled then
			return
		end
		self:SetValue(not self.Value)
	end))

	self:_mount(row)
	if self.Flag then
		library.Flags[self.Flag] = self.Value
	end
	self:_paint(true)
	return self
end

function Toggle:_paint(instant)
	local theme = self.Theme
	local on = self.Value
	local time = instant and 0 or 0.18
	local labelKey = self.Disabled and "TextMuted" or ((on or self.Hovered) and "Text" or "TextDim")
	if self.Options.Risky and not self.Disabled then
		labelKey = "Error"
	end
	local strokeKey = on and "Accent" or (self.Hovered and not self.Disabled and "AccentDark" or "BorderLight")

	Anim.tween(self.Label, { TextColor3 = theme:Get(labelKey) }, time)
	Anim.tween(self.BoxStroke, { Color = theme:Get(strokeKey) }, time)
	Anim.tween(self.Fill, {
		BackgroundTransparency = on and (self.Disabled and 0.5 or 0) or 1,
		Size = on and UDim2.fromScale(1, 1) or UDim2.fromScale(0.35, 0.35),
	}, instant and 0 or 0.22, Enum.EasingStyle.Back)
	Anim.tween(self.Check, { ImageTransparency = on and 0 or 1 }, time)
	Glow.set(self.Glow, (on and not self.Disabled) and 0.55 or (self.Hovered and 0.12 or 0), instant and 0 or 0.25)
end

function Toggle:SetValue(value)
	value = value == true
	if value == self.Value then
		return
	end
	self.Value = value
	self:_paint()
	if value and self.Library.Settings.Animations then
		Glow.flash(self.Glow, 0.95, 0.45)
	end
	self:_emit(value)
end

function Toggle:Toggle()
	self:SetValue(not self.Value)
end

function Toggle:_deserialize(data)
	self:SetValue(data == true)
end

return Toggle
