--[[
	Scramble
	"Decoding" text reveal: unrevealed characters cycle through noise glyphs
	and lock in from left to right. Used for headings, notifications and
	confirmations. Starting a new scramble on a label cancels the old one.
]]

local Anim = import("core/Anim")

local Scramble = {}

local GLYPHS = {}
for char in string.gmatch("!<>-_\\/[]{}=+*^?#$%&@~|;:", ".") do
	table.insert(GLYPHS, char)
end

-- strong keys on purpose: Roblox may recycle Instance userdata in weak
-- tables; finished or orphaned scrambles remove themselves
local running = {}

local function split(text)
	local chars = {}
	local ok = pcall(function()
		for _, code in utf8.codes(text) do
			table.insert(chars, utf8.char(code))
		end
	end)
	if not ok then
		chars = {}
		for i = 1, #text do
			chars[i] = string.sub(text, i, i)
		end
	end
	return chars
end

function Scramble.cancel(label)
	local stop = running[label]
	if stop then
		running[label] = nil
		stop()
	end
end

--[[
	opts.Duration (default 0.45), opts.Rate (glyph refresh per second, 30),
	opts.Enabled (false = set text immediately)
]]
function Scramble.play(label, text, opts)
	opts = opts or {}
	Scramble.cancel(label)
	text = tostring(text)
	if opts.Enabled == false or Anim.Speed <= 0 then
		label.Text = text
		return function() end
	end

	local chars = split(text)
	local count = #chars
	local duration = opts.Duration or math.clamp(0.18 + count * 0.025, 0.25, 0.8)
	local interval = 1 / (opts.Rate or 30)
	local start = os.clock()
	local lastSwap = 0
	local buffer = table.create(count, "")

	local unbind
	unbind = Anim.frame(function()
		if not label.Parent then
			unbind()
			running[label] = nil
			return
		end
		local now = os.clock()
		local t = (now - start) / duration
		if t >= 1 then
			label.Text = text
			unbind()
			running[label] = nil
			return
		end
		if now - lastSwap < interval then
			return
		end
		lastSwap = now
		local reveal = math.floor(t * t * count + 0.5)
		for i, char in chars do
			if i <= reveal or char == " " then
				buffer[i] = char
			else
				buffer[i] = GLYPHS[math.random(1, #GLYPHS)]
			end
		end
		label.Text = table.concat(buffer)
	end)

	running[label] = function()
		unbind()
		label.Text = text
	end
	return running[label]
end

return Scramble
