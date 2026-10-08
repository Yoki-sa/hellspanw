--[[
	Textbox
	Single-line input with a neon focus ring.

		box:AddInput("name", { Text = "Target", Placeholder = "username", Finished = true, Callback = fn })
		box:AddInput("delay", { Text = "Delay (ms)", Numeric = true, Default = "150" })
]]

local Anim = import("core/Anim")
local Util = import("core/Util")
local Input = import("core/Input")
local Glow = import("fx/Glow")
local Style = import("components/Style")
local Element = import("components/Element")

local Textbox = Element.extend("Input")

local LABEL = 17

function Textbox.new(container, flag, opts)
	flag, opts = Element.args(flag, opts)
	local self = setmetatable({}, Textbox)
	Element.init(self, container, flag, opts, {
		Text = "Input",
		Default = "",
		Placeholder = "...",
		Numeric = false,
		Finished = false,
		ClearTextOnFocus = false,
		MaxLength = 0,
	})
	local o = self.Options
	self.Value = tostring(o.Default)
	self.Focused = false

	local library = self.Library
	local theme = self.Theme
	local hasLabel = self.Text ~= "" and o.HideLabel ~= true
	local top = hasLabel and LABEL or 0

	local root = Util.create("Frame", {
		Name = "Input",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, top + Style.Box),
	})
	if hasLabel then
		self.Label = Style.label(library, {
			Text = self.Text,
			Weight = "Medium",
			Color = false,
			Size = UDim2.new(1, 0, 0, 14),
			Truncate = true,
			Parent = root,
		})
	end

	local frame, stroke = Style.surface(library, {
		Name = "Field",
		Position = UDim2.fromOffset(0, top),
		Parent = root,
	})
	self.Field = frame
	self.Stroke = stroke
	self.Glow = Glow.attach(library, frame, { Spread = 9, Strength = 0 })

	local box = Util.create("TextBox", {
		Name = "Box",
		BackgroundTransparency = 1,
		ClearTextOnFocus = o.ClearTextOnFocus,
		Text = self.Value,
		PlaceholderText = o.Placeholder,
		FontFace = Style.font(library, "Regular"),
		TextSize = Style.Text,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -16, 1, 0),
		ClipsDescendants = true,
		ZIndex = 2,
		Parent = frame,
	})
	theme:Bind(box, { TextColor3 = "Text", PlaceholderColor3 = "TextMuted" })
	self.Box = box
	self.Hitbox = frame

	self.Maid:Give((Input.hover(frame, function(state)
		self.Hovered = state
		self:_paint()
	end)))

	self.Maid:Give(box.Focused:Connect(function()
		self.Focused = true
		self:_paint()
	end))

	self.Maid:Give(box:GetPropertyChangedSignal("Text"):Connect(function()
		local text = box.Text
		local cleaned = text
		if o.Numeric then
			cleaned = string.gsub(cleaned, "[^%d%.%-]", "")
		end
		if o.MaxLength > 0 and #cleaned > o.MaxLength then
			cleaned = string.sub(cleaned, 1, o.MaxLength)
		end
		if cleaned ~= text then
			box.Text = cleaned
			return
		end
		if not o.Finished then
			self:_commit(cleaned)
		end
	end))

	self.Maid:Give(box.FocusLost:Connect(function(enter)
		self.Focused = false
		self:_paint()
		if o.Finished then
			if enter then
				self:_commit(box.Text)
			else
				box.Text = self.Value -- abandoned edit
			end
		end
	end))

	self:_mount(root)
	if self.Flag then
		library.Flags[self.Flag] = self.Value
	end
	self:_paint(true)
	return self
end

function Textbox:_commit(text)
	if text == self.Value then
		return
	end
	self.Value = text
	self:_emit(text)
end

function Textbox:_paint(instant)
	local theme = self.Theme
	local time = instant and 0 or 0.15
	if self.Label then
		Anim.tween(self.Label, {
			TextColor3 = theme:Get(self.Disabled and "TextMuted" or ((self.Hovered or self.Focused) and "Text" or "TextDim")),
		}, time)
	end
	Anim.tween(self.Stroke, {
		Color = theme:Get(self.Focused and "Accent" or ((self.Hovered and not self.Disabled) and "AccentDark" or "Border")),
	}, time)
	Glow.set(self.Glow, self.Focused and 0.42 or 0, instant and 0 or 0.2)
	self.Box.TextEditable = not self.Disabled
end

function Textbox:SetValue(text)
	text = tostring(text or "")
	self.Box.Text = text
	self:_commit(text)
end

function Textbox:_deserialize(data)
	if data ~= nil then
		self:SetValue(data)
	end
end

return Textbox
