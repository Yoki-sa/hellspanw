--[[
	GlitchText
	A label with chromatic aberration: two tinted ghost copies (accent and its
	complementary hue) sit a pixel either side of the main text, and every few
	seconds the whole thing tears, jitters and corrupts a few glyphs.
]]

local Util = import("core/Util")
local Anim = import("core/Anim")

local GlitchText = {}
GlitchText.__index = GlitchText

local NOISE = { "#", "%", "&", "/", "\\", "?", "!", "<", ">", "=", "+", "*" }

local function complement(color)
	local h, s, v = color:ToHSV()
	return Color3.fromHSV((h + 0.5) % 1, s, math.max(v, 0.75))
end

local function corrupt(text)
	if #text < 2 then
		return text
	end
	local chars = string.split(text, "")
	for _ = 1, math.random(1, 2) do
		local i = math.random(1, #chars)
		if chars[i] ~= " " then
			chars[i] = NOISE[math.random(1, #NOISE)]
		end
	end
	return table.concat(chars)
end

--[[
	props: Text, Font, TextSize, Parent, Position, AnchorPoint, ZIndex,
	       Color (theme key, default "Text")
]]
function GlitchText.new(library, props)
	local self = setmetatable({}, GlitchText)
	self.Library = library
	self.Text = props.Text or ""
	self.Enabled = true
	self._nextBurst = os.clock() + 1.5 + math.random() * 3
	self._burstEnd = 0
	self._lastJitter = 0
	self._dirty = false

	local z = props.ZIndex or 1
	local theme = library.Theme

	self.Instance = Util.create("Frame", {
		Name = "GlitchText",
		BackgroundTransparency = 1,
		AutomaticSize = Enum.AutomaticSize.X,
		Size = UDim2.fromOffset(0, props.TextSize + 6),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		ZIndex = z,
		Parent = props.Parent,
	})

	local function layer(name, zindex, auto)
		return Util.passive(Util.create("TextLabel", {
			Name = name,
			BackgroundTransparency = 1,
			FontFace = props.Font,
			TextSize = props.TextSize,
			Text = self.Text,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			AutomaticSize = auto and Enum.AutomaticSize.X or Enum.AutomaticSize.None,
			Size = auto and UDim2.new(0, 0, 1, 0) or UDim2.fromScale(1, 1),
			ZIndex = zindex,
			Parent = self.Instance,
		}))
	end

	self.Red = layer("ShiftA", z, false)
	self.Cyan = layer("ShiftB", z, false)
	self.Main = layer("Main", z + 1, true)
	self.Red.Position = UDim2.fromOffset(-1, 0)
	self.Cyan.Position = UDim2.fromOffset(1, 0)
	self.Red.TextTransparency = 0.5
	self.Cyan.TextTransparency = 0.55

	theme:Bind(self.Main, { TextColor3 = props.Color or "Text" })
	theme:Bind(self.Red, { TextColor3 = "Accent" })
	theme:Bind(self.Cyan, {
		TextColor3 = function(p)
			return complement(p.Accent)
		end,
	})

	self._unbind = Anim.frame(function(_, now)
		self:_update(now)
	end)
	return self
end

function GlitchText:_restore()
	self.Main.Position = UDim2.new()
	self.Red.Position = UDim2.fromOffset(-1, 0)
	self.Cyan.Position = UDim2.fromOffset(1, 0)
	self.Main.Text = self.Text
	self.Red.Text = self.Text
	self.Cyan.Text = self.Text
	self.Red.TextTransparency = 0.5
	self.Cyan.TextTransparency = 0.55
	self._dirty = false
end

function GlitchText:_update(now)
	if not self.Enabled or not self.Instance.Visible then
		if self._dirty then
			self:_restore()
		end
		return
	end
	if now >= self._nextBurst then
		self._burstEnd = now + 0.14 + math.random() * 0.22
		self._nextBurst = now + 2.5 + math.random() * 5
	end
	if now < self._burstEnd then
		if now - self._lastJitter < 0.045 then
			return
		end
		self._lastJitter = now
		self._dirty = true
		local shift = math.random(1, 4)
		self.Red.Position = UDim2.fromOffset(-shift, math.random(-1, 1))
		self.Cyan.Position = UDim2.fromOffset(shift + math.random(0, 1), math.random(-1, 1))
		self.Main.Position = UDim2.fromOffset(math.random(-1, 1), 0)
		self.Red.TextTransparency = 0.15
		self.Cyan.TextTransparency = 0.2
		local text = math.random() < 0.4 and corrupt(self.Text) or self.Text
		self.Main.Text = text
		self.Red.Text = math.random() < 0.5 and corrupt(self.Text) or text
		self.Cyan.Text = text
	elseif self._dirty then
		self:_restore()
	end
end

function GlitchText:Burst(duration)
	self._burstEnd = os.clock() + (duration or 0.3)
end

function GlitchText:SetText(text)
	self.Text = tostring(text)
	self:_restore()
end

function GlitchText:SetFont(font)
	for _, label in { self.Main, self.Red, self.Cyan } do
		label.FontFace = font
	end
end

function GlitchText:SetEnabled(enabled)
	self.Enabled = enabled
	self.Red.Visible = enabled
	self.Cyan.Visible = enabled
	if not enabled then
		self:_restore()
	end
end

function GlitchText:Destroy()
	if self._unbind then
		self._unbind()
	end
	self.Instance:Destroy()
end

return GlitchText
