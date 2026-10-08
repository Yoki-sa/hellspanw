--[[
	Slider
	Thin ImGui track with a gradient fill, a glowing spark riding the fill's
	edge and spring-smoothed motion. Double-click the value to type one in.

		box:AddSlider("fov", { Text = "FOV", Min = 0, Max = 360, Default = 90, Rounding = 0, Suffix = "°" })
		box:AddSlider("smooth", { Text = "Smoothing", Min = 0, Max = 1, Increment = 0.05 })
]]

local Util = import("core/Util")
local Anim = import("core/Anim")
local Input = import("core/Input")
local Motion = import("core/Motion")
local Glow = import("fx/Glow")
local Style = import("components/Style")
local Element = import("components/Element")

local Slider = Element.extend("Slider")

local TRACK = 6

function Slider.new(container, flag, opts)
	flag, opts = Element.args(flag, opts)
	local self = setmetatable({}, Slider)
	Element.init(self, container, flag, opts, {
		Text = "Slider",
		Min = 0,
		Max = 100,
		Rounding = 0,
		Suffix = "",
		Prefix = "",
		Compact = false,
	})
	local o = self.Options
	assert(o.Max > o.Min, "Slider Max must be greater than Min")
	self.Min, self.Max = o.Min, o.Max
	self.Increment = o.Increment
	self.Decimals = o.Increment and Util.decimalsOf(o.Increment) or o.Rounding
	self.Value = self:_clean(o.Default or o.Min)
	self.Dragging = false

	local library = self.Library
	local theme = self.Theme
	local compact = o.Compact
	local trackY = compact and 6 or 20
	local height = compact and 18 or 32

	local row = Util.create("Frame", {
		Name = "Slider",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height),
	})

	-- geometry: stacked (label over track) or compact (label | track | value)
	local geometry = compact
			and {
				label = UDim2.new(0.36, 0, 1, 0),
				value = { UDim2.new(1, 0, 0, 2), UDim2.fromOffset(54, 14) },
				trackX = UDim.new(0.38, 0),
				trackW = UDim.new(0.62, -60),
			}
		or {
			label = UDim2.new(1, -90, 0, 14),
			value = { UDim2.fromScale(1, 0), UDim2.fromOffset(88, 14) },
			trackX = UDim.new(0, 0),
			trackW = UDim.new(1, 0),
		}

	self.Label = Style.label(library, {
		Text = self.Text,
		Weight = "Medium",
		Color = false,
		Size = geometry.label,
		Truncate = true,
		Parent = row,
	})

	self.ValueButton = Util.create("TextButton", {
		Name = "Value",
		BackgroundTransparency = 1,
		AutoButtonColor = false,
		RichText = true,
		Text = "",
		FontFace = Style.font(library, "Regular"),
		TextSize = Style.Small,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = geometry.value[1],
		Size = geometry.value[2],
		ZIndex = 2,
		Parent = row,
	})
	theme:Bind(self.ValueButton, { TextColor3 = "Text" })

	local track = Util.create("Frame", {
		Name = "Track",
		BorderSizePixel = 0,
		Position = UDim2.new(geometry.trackX, UDim.new(0, trackY)),
		Size = UDim2.new(geometry.trackW, UDim.new(0, TRACK)),
		Parent = row,
	})
	Util.corner(track, 2)
	theme:Bind(track, { BackgroundColor3 = "Surface" })
	self.TrackStroke = Util.stroke(track)
	self.Track = track

	local fill = Util.create("Frame", {
		Name = "Fill",
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.fromScale(0, 1),
		Parent = track,
	})
	Util.corner(fill, 2)
	theme:Bind(Util.gradient(fill), { Color = "AccentGradient" })
	self.Fill = fill
	self.Glow = Glow.attach(library, fill, { Spread = 7, Strength = 0.28 })

	local head = Util.passive(Util.create("Frame", {
		Name = "Head",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(18, 18),
		ZIndex = 3,
		Parent = track,
	}))
	self.Spark = Util.passive(Util.create("ImageLabel", {
		Name = "Spark",
		BackgroundTransparency = 1,
		Image = library.Assets:Texture("spark"),
		Size = UDim2.fromScale(1, 1),
		ImageTransparency = 0.45,
		ZIndex = 3,
		Parent = head,
	}))
	theme:Bind(self.Spark, { ImageColor3 = "Accent" })
	self.Needle = Util.passive(Util.create("Frame", {
		Name = "Needle",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(2, TRACK + 4),
		BorderSizePixel = 0,
		ZIndex = 4,
		Parent = head,
	}))
	theme:Bind(self.Needle, { BackgroundColor3 = "Text" })
	self.Head = head

	local hit = Style.hitbox({
		Name = "Hit",
		Position = UDim2.new(geometry.trackX, UDim.new(0, trackY - 7)),
		Size = UDim2.new(geometry.trackW, UDim.new(0, TRACK + 14)),
		ZIndex = 5,
		Parent = row,
	})
	self.Hitbox = hit

	self.Spring = Motion.spring(self:_fraction(), { Frequency = 7, Damping = 1, Epsilon = 0.0005 }, function(f)
		fill.Size = UDim2.fromScale(f, 1)
		head.Position = UDim2.fromScale(f, 0.5)
	end)
	self.Maid:Give(self.Spring)
	self.Spring:SetTarget(self:_fraction(), true)

	self.Maid:Give((Input.hover(hit, function(state)
		self.Hovered = state
		self:_paint()
	end)))

	local function fromPosition(position)
		local abs = track.AbsolutePosition
		local width = math.max(track.AbsoluteSize.X, 1)
		local rel = math.clamp((position.X - abs.X) / width, 0, 1)
		self:SetValue(self.Min + rel * (self.Max - self.Min))
	end

	self.Maid:Give((Input.drag(hit, {
		canStart = function()
			return not self.Disabled
		end,
		onStart = function(position)
			self.Dragging = true
			self:_paint()
			fromPosition(position)
		end,
		onMove = function(position)
			fromPosition(position)
		end,
		onEnd = function()
			self.Dragging = false
			self:_paint()
		end,
	})))

	-- double-click the value to type an exact number
	local lastClick = 0
	self.Maid:Give(self.ValueButton.Activated:Connect(function()
		if self.Disabled then
			return
		end
		local now = os.clock()
		if now - lastClick < 0.35 then
			self:_beginEdit()
		end
		lastClick = now
	end))

	self:_mount(row)
	if self.Flag then
		library.Flags[self.Flag] = self.Value
	end
	self:_render()
	self:_paint(true)
	return self
end

function Slider:_clean(value)
	value = tonumber(value) or self.Min
	value = math.clamp(value, self.Min, self.Max)
	if self.Increment then
		value = self.Min + Util.snap(value - self.Min, self.Increment)
		value = math.clamp(value, self.Min, self.Max)
	end
	return Util.round(value, self.Decimals)
end

function Slider:_fraction()
	return (self.Value - self.Min) / (self.Max - self.Min)
end

function Slider:_display()
	local o = self.Options
	if o.Format then
		local ok, text = pcall(o.Format, self.Value)
		if ok then
			return tostring(text)
		end
	end
	local muted = Util.toHex(self.Theme:Get("TextMuted"))
	local text = Util.escape(o.Prefix) .. Util.format(self.Value, self.Decimals)
	if o.Suffix ~= "" then
		text ..= string.format("<font color=\"#%s\">%s</font>", muted, Util.escape(o.Suffix))
	end
	if o.ShowMax then
		text ..= string.format("<font color=\"#%s\">/%s</font>", muted, Util.format(self.Max, self.Decimals))
	end
	return text
end

function Slider:_render()
	self.ValueButton.Text = self:_display()
end

function Slider:_paint(instant)
	local theme = self.Theme
	local time = instant and 0 or 0.15
	local active = self.Hovered or self.Dragging
	if self.Label then
		local key = self.Disabled and "TextMuted" or (active and "Text" or "TextDim")
		Anim.tween(self.Label, { TextColor3 = theme:Get(key) }, time)
	end
	Anim.tween(self.TrackStroke, { Color = theme:Get(active and not self.Disabled and "AccentDark" or "Border") }, time)
	Anim.tween(self.Spark, { ImageTransparency = self.Disabled and 1 or (self.Dragging and 0 or (active and 0.25 or 0.55)) }, time)
	Anim.tween(self.Fill, { BackgroundTransparency = self.Disabled and 0.6 or 0 }, time)
	Glow.set(self.Glow, self.Disabled and 0 or (self.Dragging and 0.5 or 0.25), instant and 0 or 0.2)
	self:_render()
end

function Slider:_beginEdit()
	if self._editing then
		return
	end
	self._editing = true
	local button = self.ValueButton
	local box = Util.create("TextBox", {
		Name = "Edit",
		BackgroundTransparency = 1,
		ClearTextOnFocus = false,
		Text = Util.format(self.Value, self.Decimals),
		FontFace = button.FontFace,
		TextSize = button.TextSize,
		TextXAlignment = Enum.TextXAlignment.Right,
		AnchorPoint = button.AnchorPoint,
		Position = button.Position,
		Size = button.Size,
		ZIndex = 6,
		Parent = button.Parent,
	})
	self.Theme:Bind(box, { TextColor3 = "Accent" })
	button.Visible = false
	box:CaptureFocus()
	box.FocusLost:Connect(function()
		local number = tonumber((string.gsub(box.Text, "[^%d%.%-]", "")))
		box:Destroy()
		button.Visible = true
		self._editing = false
		if number then
			self:SetValue(number)
		end
	end)
end

function Slider:SetValue(value)
	value = self:_clean(value)
	if value == self.Value then
		return
	end
	self.Value = value
	self.Spring:SetTarget(self:_fraction(), not self.Library.Settings.Animations)
	self:_render()
	self:_emit(value)
end

function Slider:SetMin(min)
	self.Min = min
	self.Value = self:_clean(self.Value)
	self.Spring:SetTarget(self:_fraction(), true)
	self:_render()
end

function Slider:SetMax(max)
	self.Max = max
	self.Value = self:_clean(self.Value)
	self.Spring:SetTarget(self:_fraction(), true)
	self:_render()
end

return Slider
