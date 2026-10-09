--[[
	Util
	Instance construction, colour maths, number formatting and other small
	helpers shared by every component.
]]

local Util = {}

----------------------------------------------------------------------
-- instances
----------------------------------------------------------------------

--[[
	Util.create("Frame", { Size = ..., Parent = ... , child1, child2 })
	Array entries in the props table are parented to the new instance.
	Parent is always assigned last so the instance is fully built first.
]]
function Util.create(className, props)
	local instance = Instance.new(className)
	local parent = nil
	if props then
		for key, value in props do
			if key == "Parent" then
				parent = value
			elseif type(key) == "number" then
				value.Parent = instance
			else
				instance[key] = value
			end
		end
	end
	if parent then
		instance.Parent = parent
	end
	return instance
end

-- Marks an instance as purely decorative: never steals clicks or hover.
function Util.passive(instance)
	if instance:IsA("GuiObject") then
		instance.Active = false
		instance.Selectable = false
		pcall(function()
			instance.Interactable = false
		end)
	end
	return instance
end

function Util.corner(parent, radius)
	return Util.create("UICorner", { CornerRadius = UDim.new(0, radius or 3), Parent = parent })
end

function Util.stroke(parent, props)
	props = props or {}
	local stroke = Util.create("UIStroke", {
		Color = props.Color or Color3.new(1, 1, 1),
		Thickness = props.Thickness or 1,
		Transparency = props.Transparency or 0,
		ApplyStrokeMode = props.Mode or Enum.ApplyStrokeMode.Border,
		LineJoinMode = props.Join or Enum.LineJoinMode.Miter,
		Parent = parent,
	})
	return stroke
end

function Util.padding(parent, top, right, bottom, left)
	right = right or top
	bottom = bottom or top
	left = left or right
	return Util.create("UIPadding", {
		PaddingTop = UDim.new(0, top),
		PaddingRight = UDim.new(0, right),
		PaddingBottom = UDim.new(0, bottom),
		PaddingLeft = UDim.new(0, left),
		Parent = parent,
	})
end

function Util.list(parent, props)
	props = props or {}
	return Util.create("UIListLayout", {
		FillDirection = props.Direction or Enum.FillDirection.Vertical,
		SortOrder = Enum.SortOrder.LayoutOrder,
		Padding = UDim.new(0, props.Padding or 0),
		HorizontalAlignment = props.HAlign or Enum.HorizontalAlignment.Left,
		VerticalAlignment = props.VAlign or Enum.VerticalAlignment.Top,
		Parent = parent,
	})
end

function Util.gradient(parent, props)
	props = props or {}
	return Util.create("UIGradient", {
		Color = props.Color or ColorSequence.new(Color3.new(1, 1, 1)),
		Transparency = props.Transparency or NumberSequence.new(0),
		Rotation = props.Rotation or 0,
		Offset = props.Offset or Vector2.zero,
		Parent = parent,
	})
end

----------------------------------------------------------------------
-- tables
----------------------------------------------------------------------

-- Returns a copy of opts with any missing keys filled from defaults
function Util.defaults(opts, defaults)
	local out = {}
	if opts then
		for key, value in opts do
			out[key] = value
		end
	end
	for key, value in defaults do
		if out[key] == nil then
			out[key] = value
		end
	end
	return out
end

function Util.deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local out = {}
	for k, v in value do
		out[k] = Util.deepCopy(v)
	end
	return out
end

function Util.count(tbl)
	local n = 0
	for _ in tbl do
		n += 1
	end
	return n
end

----------------------------------------------------------------------
-- numbers
----------------------------------------------------------------------

function Util.round(value, decimals)
	local m = 10 ^ (decimals or 0)
	return math.floor(value * m + 0.5) / m
end

function Util.snap(value, step)
	if not step or step <= 0 then
		return value
	end
	return math.floor(value / step + 0.5) * step
end

function Util.format(value, decimals)
	decimals = decimals or 0
	if decimals <= 0 then
		return tostring(math.floor(value + 0.5))
	end
	return string.format("%." .. decimals .. "f", value)
end

function Util.decimalsOf(step)
	if not step or step >= 1 then
		return 0
	end
	local text = tostring(step)
	local dot = string.find(text, ".", 1, true)
	if not dot then
		return 0
	end
	return #text - dot
end

function Util.lerp(a, b, t)
	return a + (b - a) * t
end

function Util.map(value, inMin, inMax, outMin, outMax)
	if inMax == inMin then
		return outMin
	end
	return outMin + (value - inMin) / (inMax - inMin) * (outMax - outMin)
end

----------------------------------------------------------------------
-- colours
----------------------------------------------------------------------

function Util.mix(a, b, t)
	return a:Lerp(b, t)
end

function Util.lighten(color, amount)
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, math.clamp(s - amount * 0.35, 0, 1), math.clamp(v + amount, 0, 1))
end

function Util.darken(color, amount)
	local h, s, v = color:ToHSV()
	return Color3.fromHSV(h, s, math.clamp(v - amount, 0, 1))
end

function Util.luminance(color)
	return 0.2126 * color.R + 0.7152 * color.G + 0.0722 * color.B
end

function Util.toHex(color)
	return string.format(
		"%02X%02X%02X",
		math.floor(color.R * 255 + 0.5),
		math.floor(color.G * 255 + 0.5),
		math.floor(color.B * 255 + 0.5)
	)
end

function Util.fromHex(hex)
	if type(hex) ~= "string" then
		return nil
	end
	hex = string.gsub(hex, "[^%x]", "")
	if #hex == 3 then
		hex = string.gsub(hex, "(%x)", "%1%1")
	end
	if #hex ~= 6 and #hex ~= 8 then
		return nil
	end
	local r = tonumber(string.sub(hex, 1, 2), 16)
	local g = tonumber(string.sub(hex, 3, 4), 16)
	local b = tonumber(string.sub(hex, 5, 6), 16)
	if not (r and g and b) then
		return nil
	end
	return Color3.fromRGB(r, g, b)
end

-- ColorSequence that sweeps the full hue wheel (top/left = red)
function Util.hueSequence()
	local keys = {}
	for i = 0, 6 do
		keys[#keys + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV((i / 6) % 1, 1, 1))
	end
	return ColorSequence.new(keys)
end

----------------------------------------------------------------------
-- text
----------------------------------------------------------------------

function Util.escape(text)
	text = string.gsub(tostring(text), "&", "&amp;")
	text = string.gsub(text, "<", "&lt;")
	text = string.gsub(text, ">", "&gt;")
	text = string.gsub(text, "\"", "&quot;")
	return text
end

function Util.trim(text)
	return string.match(text, "^%s*(.-)%s*$")
end

-- case-insensitive substring match, falling back to an ordered subsequence
-- for queries of three or more characters ("tgbt" finds "Trigger Bot")
function Util.matches(query, text)
	query = string.lower(Util.trim(query or ""))
	if query == "" then
		return true
	end
	text = string.lower(text or "")
	if string.find(text, query, 1, true) then
		return true
	end
	-- fuzzy (subsequence) matching only makes sense for short labels; on
	-- sentences almost any query would match
	if #query < 3 or #text > 40 then
		return false
	end
	local qi = 1
	for i = 1, #text do
		if string.sub(text, i, i) == string.sub(query, qi, qi) then
			qi += 1
			if qi > #query then
				return true
			end
		end
	end
	return false
end

local KEY_NAMES = {
	LeftShift = "LShift", RightShift = "RShift",
	LeftControl = "LCtrl", RightControl = "RCtrl",
	LeftAlt = "LAlt", RightAlt = "RAlt",
	LeftSuper = "LWin", RightSuper = "RWin",
	Return = "Enter", Backspace = "Bksp", CapsLock = "Caps",
	PageUp = "PgUp", PageDown = "PgDn", Insert = "Ins", Delete = "Del",
	MouseButton1 = "LMB", MouseButton2 = "RMB", MouseButton3 = "MMB",
	Minus = "-", Equals = "=", LeftBracket = "[", RightBracket = "]",
	Semicolon = ";", Quote = "'", Comma = ",", Period = ".", Slash = "/",
	BackSlash = "\\", Backquote = "`", Space = "Space", Tab = "Tab",
	Up = "Up", Down = "Down", Left = "Left", Right = "Right",
}
local DIGITS = { "Zero", "One", "Two", "Three", "Four", "Five", "Six", "Seven", "Eight", "Nine" }
for i, word in DIGITS do
	KEY_NAMES[word] = tostring(i - 1)
	KEY_NAMES["Keypad" .. word] = "Num" .. (i - 1)
end

function Util.keyName(key)
	if key == nil then
		return "None"
	end
	if type(key) == "string" then
		return KEY_NAMES[key] or key
	end
	return KEY_NAMES[key.Name] or key.Name
end

----------------------------------------------------------------------
-- misc
----------------------------------------------------------------------

function Util.safeCall(fn, ...)
	if type(fn) ~= "function" then
		return
	end
	local ok, err = xpcall(fn, debug.traceback, ...)
	if not ok then
		warn("[Hellspawn] callback error:\n" .. tostring(err))
	end
end

-- True when the object is parented under a layer and every ancestor is visible.
-- (Avoids IsDescendantOf(game): gethui() containers are not always inside it.)
function Util.isShown(gui)
	local node = gui
	while node do
		if node:IsA("LayerCollector") then
			return node.Enabled ~= false
		end
		if node:IsA("GuiObject") and not node.Visible then
			return false
		end
		node = node.Parent
	end
	return false
end

function Util.viewport()
	local camera = workspace.CurrentCamera
	if camera then
		return camera.ViewportSize
	end
	return Vector2.new(1920, 1080)
end

local guidCounter = 0
function Util.uid(prefix)
	guidCounter += 1
	return (prefix or "hs") .. "_" .. guidCounter .. "_" .. math.floor(os.clock() * 1000) % 100000
end

return Util
