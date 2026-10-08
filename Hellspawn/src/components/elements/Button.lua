--[[
	Button
	Framed button with a ripple from the click point and a neon flash.
	DoubleClick turns it into a two-step confirm ("are you sure?").
	Chain :AddButton() to place buttons side by side on one row.

		box:AddButton({ Text = "Rejoin", Callback = fn })
		box:AddButton({ Text = "Wipe config", DoubleClick = true, Risky = true, Callback = fn })
			:AddButton({ Text = "Copy", Callback = fn2 })
]]

local Util = import("core/Util")
local Anim = import("core/Anim")
local Input = import("core/Input")
local Glow = import("fx/Glow")
local Ripple = import("fx/Ripple")
local Scramble = import("fx/Scramble")
local Style = import("components/Style")
local Element = import("components/Element")

local Button = Element.extend("Button")

local GAP = 6

local function build(self, parent)
	local library = self.Library
	local theme = self.Theme

	local button, stroke = Style.surface(library, {
		Class = "TextButton",
		Name = "Button",
		Size = UDim2.new(1, 0, 0, Style.Box),
		Clip = true,
		Parent = parent,
	})
	self.Button = button
	self.Stroke = stroke
	self.Hitbox = button
	self.Glow = Glow.attach(library, button, { Spread = 10, Strength = 0 })
	-- the glow lives outside the clipped button, so mount it on the holder
	self.Glow.Parent = parent

	self.Label = Style.label(library, {
		Text = self.Text,
		Weight = "Medium",
		Color = false,
		XAlign = Enum.TextXAlignment.Center,
		Truncate = true,
		Size = UDim2.new(1, -12, 1, 0),
		Position = UDim2.fromOffset(6, 0),
		ZIndex = 3,
		Parent = button,
	})

	self.Maid:Give((Input.hover(button, function(state)
		self.Hovered = state
		self:_paint()
	end)))

	self.Maid:Give(button.InputBegan:Connect(function(io)
		if Input.isPress(io) and not self.Disabled then
			Ripple.spawn(library, button, Input.position(io), theme:Get("Accent"), { ZIndex = 2 })
		end
	end))

	self.Maid:Give(button.Activated:Connect(function()
		self:_click()
	end))
end

function Button.new(container, opts, parentButton)
	if type(opts) == "string" then
		opts = { Text = opts }
	end
	local self = setmetatable({}, Button)
	Element.init(self, container, nil, opts, {
		Text = "Button",
		DoubleClick = false,
		Risky = false,
	})
	self.Siblings = { self }
	self._confirming = false

	if parentButton then
		-- joins an existing row
		self.Row = parentButton.Row
		self.Root = parentButton.Root or parentButton
		table.insert(self.Root.Siblings, self)
		local holder = Util.create("Frame", {
			Name = "Cell",
			BackgroundTransparency = 1,
			LayoutOrder = #self.Root.Siblings,
			Parent = self.Row,
		})
		self.Cell = holder
		build(self, holder)
		self.Instance = holder
		self.Host = self.Root
		self.Maid:Give(holder)
		self.Maid:Give(self.Theme.Changed:Connect(function(_, instant)
			self:_paint(instant)
		end))
		if self.Options.Tooltip then
			self:SetTooltip(self.Options.Tooltip)
		end
		self.Root:_layoutRow()
		self:_paint(true)
		return self
	end

	local row = Util.create("Frame", {
		Name = "ButtonRow",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, Style.Box),
	})
	Util.list(row, { Direction = Enum.FillDirection.Horizontal, Padding = GAP })
	self.Row = row
	local holder = Util.create("Frame", {
		Name = "Cell",
		BackgroundTransparency = 1,
		LayoutOrder = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = row,
	})
	self.Cell = holder
	build(self, holder)
	self:_mount(row)
	self:_layoutRow()
	self:_paint(true)
	return self
end

function Button:_layoutRow()
	local siblings = self.Siblings
	local count = #siblings
	local share = (GAP * (count - 1)) / count
	for _, sibling in siblings do
		sibling.Cell.Size = UDim2.new(1 / count, -share, 1, 0)
	end
end

function Button:AddButton(opts)
	return Button.new(self.Container, opts, self.Root or self)
end

function Button:_paint(instant)
	local theme = self.Theme
	local time = instant and 0 or 0.15
	local labelKey
	if self.Disabled then
		labelKey = "TextMuted"
	elseif self._confirming or self.Options.Risky then
		labelKey = self._confirming and "Accent" or "Error"
	else
		labelKey = self.Hovered and "Text" or "TextDim"
	end
	Anim.tween(self.Label, { TextColor3 = theme:Get(labelKey) }, time)
	Anim.tween(self.Button, {
		BackgroundColor3 = theme:Get((self.Hovered and not self.Disabled) and "SurfaceHover" or "Surface"),
	}, time)
	local strokeKey = self._confirming and "Accent" or ((self.Hovered and not self.Disabled) and "AccentDark" or "Border")
	Anim.tween(self.Stroke, { Color = theme:Get(strokeKey) }, time)
	Glow.set(self.Glow, self._confirming and 0.45 or 0, instant and 0 or 0.2)
end

function Button:_fire()
	Glow.flash(self.Glow, 0.8, 0.5)
	self.Library:_elementChanged(self)
	if self.Callback then
		task.spawn(Util.safeCall, self.Callback)
	end
	self.Changed:Fire()
end

function Button:_click()
	if self.Disabled then
		return
	end
	if not self.Options.DoubleClick then
		self:_fire()
		return
	end
	if self._confirming then
		self._confirming = false
		self.Maid:Clean("confirm")
		Scramble.play(self.Label, self.Text, { Duration = 0.25 })
		self:_paint()
		self:_fire()
		return
	end
	self._confirming = true
	self:_paint()
	Scramble.play(self.Label, self.Options.ConfirmText or "are you sure?", { Duration = 0.3 })
	self.Maid:Set("confirm", task.delay(2.2, function()
		if self._confirming then
			self._confirming = false
			Scramble.play(self.Label, self.Text, { Duration = 0.25 })
			self:_paint()
		end
	end))
end

function Button:SetText(text)
	self.Text = tostring(text)
	Scramble.cancel(self.Label)
	self.Label.Text = self.Text
end

function Button:SetValue() end

function Button:_serialize()
	return nil
end

return Button
