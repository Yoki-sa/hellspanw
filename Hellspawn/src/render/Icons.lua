--[[
	Icons
	Every icon is a signed distance function over normalised space
	(x right, y down, design area [-1, 1]). They are rasterised once into a
	single atlas by the texture builder, so they stay crisp at any tint and
	cost one image request total.

	Add your own: Icons.Shapes.myIcon = function(x, y) return distance end
]]

local Sdf = import("render/Sdf")

local circle, box, segment, polygon, polyline = Sdf.circle, Sdf.box, Sdf.segment, Sdf.polygon, Sdf.polyline
local vesica, vesicaV, smin, polar, rotate = Sdf.vesica, Sdf.vesicaV, Sdf.smin, Sdf.polar, Sdf.rotate
local abs, min, max = math.abs, math.min, math.max

local STROKE = 0.1

local Icons = {}
local S = {}
Icons.Shapes = S

-- Pre-built vertex lists (allocated once, not per pixel)
local SIGIL = {
	0, -1, 0.06, -0.3, 0.14, -0.14, 0.3, -0.06, 0.66, 0, 0.3, 0.06, 0.14, 0.14, 0.06, 0.3,
	0, 1, -0.06, 0.3, -0.14, 0.14, -0.3, 0.06, -0.66, 0, -0.3, -0.06, -0.14, -0.14, -0.06, -0.3,
}
local BOLT = { 0.22, -1, -0.62, 0.14, -0.06, 0.14, -0.26, 1, 0.62, -0.2, 0.06, -0.2 }
local THORN = { 0.42, -0.14, 0.66, -0.02, 0.9, 0.36, 0.6, 0.1, 0.44, 0.14 }
local CHECK = { -0.62, 0.02, -0.2, 0.46, 0.66, -0.48 }
local CHEVRON = { -0.52, -0.24, 0, 0.26, 0.52, -0.24 }
local NOSE = { 0, 0.08, -0.1, 0.3, 0.1, 0.3 }
local WARN = { 0, -0.86, 0.92, 0.76, -0.92, 0.76 }
local DROP_TIP = { 0, -1, 0.5, 0.1, -0.5, 0.1 }
local BLADE = { -0.15, -0.17, 0.95, -0.11, 1.32, 0.02, 0.95, 0.13, -0.15, 0.17 }
local FOLDER = { -0.9, -0.62, -0.25, -0.62, -0.1, -0.44, 0.9, -0.44, 0.9, 0.7, -0.9, 0.7 }
local FLOPPY = { -0.82, -0.82, 0.52, -0.82, 0.82, -0.52, 0.82, 0.82, -0.82, 0.82 }
local FLAME_OUT = { 0.02, -1, 0.42, -0.42, 0.62, 0.1, 0.5, 0.56, 0.1, 0.86, -0.42, 0.66, -0.62, 0.2, -0.44, -0.2, -0.2, -0.02 }
local FLAME_IN = { 0.04, -0.12, 0.28, 0.25, 0.22, 0.6, -0.08, 0.66, -0.26, 0.42, -0.12, 0.2 }
local CODE_L = { -0.32, -0.5, -0.82, 0, -0.32, 0.5 }
local CODE_R = { 0.32, -0.5, 0.82, 0, 0.32, 0.5 }
local SPIDER_LEGS = {
	{ 0.1, -0.2, 0.46, -0.62, 0.6, -0.98 },
	{ 0.14, -0.08, 0.6, -0.34, 0.95, -0.5 },
	{ 0.14, 0.06, 0.62, 0.1, 0.96, 0.4 },
	{ 0.1, 0.16, 0.46, 0.46, 0.66, 0.96 },
}
local TAG = { -0.86, -0.86, 0.06, -0.86, 0.9, 0.0, 0.06, 0.86, -0.86, 0.86 }
-- spiked collar under the rabbit's jaw
local COLLAR = {}
for i = -1, 1 do
	local bx = -0.08 + i * 0.26
	COLLAR[#COLLAR + 1] = { bx - 0.09, 0.8, bx + 0.09, 0.8, bx + i * 0.08, 1.06 }
end

local function ring(d, t)
	return abs(d) - (t or STROKE)
end

S.sigil = function(x, y)
	return polygon(x, y, SIGIL)
end

S.crosshair = function(x, y)
	local d = ring(circle(x, y, 0, 0, 0.56), 0.085)
	d = min(d, segment(x, y, 0, -0.98, 0, -0.3, 0.085))
	d = min(d, segment(x, y, 0, 0.3, 0, 0.98, 0.085))
	d = min(d, segment(x, y, -0.98, 0, -0.3, 0, 0.085))
	d = min(d, segment(x, y, 0.3, 0, 0.98, 0, 0.085))
	return min(d, circle(x, y, 0, 0, 0.11))
end

S.eye = function(x, y)
	local lens = vesica(x, y, 0, 0, 0.98, 0.56)
	local outline = ring(lens, 0.085)
	local iris = max(ring(circle(x, y, 0, 0, 0.34), 0.075), lens)
	return min(outline, iris, circle(x, y, 0, 0, 0.15))
end

S.skull = function(x, y)
	local d = min(circle(x, y, 0, -0.2, 0.66), box(x, y, 0, 0.42, 0.38, 0.3, 0.12))
	local holes = min(circle(x, y, -0.26, -0.14, 0.18), circle(x, y, 0.26, -0.14, 0.18), polygon(x, y, NOSE))
	d = max(d, -holes)
	local gaps = min(
		segment(x, y, -0.13, 0.5, -0.13, 0.9, 0.04),
		segment(x, y, 0.13, 0.5, 0.13, 0.9, 0.04),
		segment(x, y, 0, 0.52, 0, 0.9, 0.04)
	)
	return max(d, -gaps)
end

S.rabbit = function(x, y)
	local ex1, ey1 = rotate(x + 0.3, y + 0.36, 0.42)
	local ex2, ey2 = rotate(x - 0.08, y + 0.42, -0.08)
	local ears = min(Sdf.ellipse(ex1, ey1, 0, 0, 0.17, 0.52), Sdf.ellipse(ex2, ey2, 0, 0, 0.16, 0.56))
	local head = smin(circle(x, y, 0.0, 0.42, 0.42), circle(x, y, 0.3, 0.56, 0.27), 0.12)
	local d = smin(head, ears, 0.1)
	for _, spike in COLLAR do
		d = min(d, polygon(x, y, spike))
	end
	return max(d, -circle(x, y, 0.16, 0.33, 0.085))
end

S.gear = function(x, y)
	local rx, ry = polar(x, y, 8)
	local d = min(circle(x, y, 0, 0, 0.6), box(rx, ry, 0.72, 0, 0.2, 0.15, 0.04))
	return max(d, -circle(x, y, 0, 0, 0.24))
end

S.user = function(x, y)
	local head = circle(x, y, 0, -0.42, 0.32)
	local body = max(circle(x, y, 0, 0.98, 0.72), y - 0.86)
	return min(head, body)
end

S.knife = function(x, y)
	local u, v = rotate(x, y, math.pi / 4)
	local d = polygon(u, v, BLADE)
	d = min(d, segment(u, v, -0.24, -0.36, -0.24, 0.36, 0.07))
	d = min(d, segment(u, v, -0.34, 0, -1.02, 0, 0.11))
	return min(d, circle(u, v, -1.12, 0, 0.13))
end

S.bolt = function(x, y)
	return polygon(x, y, BOLT)
end

S.thorns = function(x, y)
	local d = ring(circle(x, y, 0, 0, 0.48), 0.085)
	local rx, ry = polar(x, y, 7)
	return min(d, polygon(rx, ry, THORN))
end

S.spider = function(x, y)
	local d = min(circle(x, y, 0, 0.3, 0.3), circle(x, y, 0, -0.14, 0.19))
	local ax = abs(x)
	for _, leg in SPIDER_LEGS do
		d = min(d, segment(ax, y, leg[1], leg[2], leg[3], leg[4], 0.07), segment(ax, y, leg[3], leg[4], leg[5], leg[6], 0.06))
	end
	return d
end

S.cross = function(x, y)
	return min(box(x, y, 0, 0.06, 0.12, 0.94, 0.02), box(x, y, 0, -0.36, 0.6, 0.12, 0.02))
end

S.drop = function(x, y)
	return smin(circle(x, y, 0, 0.32, 0.55), polygon(x, y, DROP_TIP), 0.12)
end

S.flame = function(x, y)
	return max(polygon(x, y, FLAME_OUT), -polygon(x, y, FLAME_IN))
end

S.moon = function(x, y)
	return max(circle(x, y, 0, 0, 0.78), -circle(x, y, 0.38, -0.28, 0.64))
end

S.globe = function(x, y)
	local outer = circle(x, y, 0, 0, 0.84)
	local d = ring(outer, 0.08)
	d = min(d, ring(vesicaV(x, y, 0, 0, 0.38, 0.84), 0.07))
	d = min(d, max(abs(y) - 0.07, outer))
	d = min(d, max(abs(abs(y) - 0.44) - 0.06, outer))
	return d
end

S.check = function(x, y)
	return polyline(x, y, CHECK, 0.13)
end

S.chevron = function(x, y)
	return polyline(x, y, CHEVRON, 0.12)
end

S.close = function(x, y)
	return min(segment(x, y, -0.55, -0.55, 0.55, 0.55, 0.11), segment(x, y, -0.55, 0.55, 0.55, -0.55, 0.11))
end

S.minus = function(x, y)
	return segment(x, y, -0.6, 0, 0.6, 0, 0.11)
end

S.plus = function(x, y)
	return min(segment(x, y, -0.6, 0, 0.6, 0, 0.11), segment(x, y, 0, -0.6, 0, 0.6, 0.11))
end

S.search = function(x, y)
	return min(ring(circle(x, y, -0.16, -0.16, 0.46), 0.1), segment(x, y, 0.2, 0.2, 0.72, 0.72, 0.13))
end

S.info = function(x, y)
	local d = ring(circle(x, y, 0, 0, 0.84), 0.08)
	d = min(d, circle(x, y, 0, -0.38, 0.1))
	return min(d, segment(x, y, 0, -0.08, 0, 0.42, 0.09))
end

S.warning = function(x, y)
	local d = ring(polygon(x, y, WARN), 0.075)
	d = min(d, segment(x, y, 0, -0.3, 0, 0.18, 0.08))
	return min(d, circle(x, y, 0, 0.44, 0.085))
end

S.success = function(x, y)
	return min(ring(circle(x, y, 0, 0, 0.84), 0.08), polyline(x * 1.6, y * 1.6, CHECK, 0.13) / 1.6)
end

S.error = function(x, y)
	local d = ring(circle(x, y, 0, 0, 0.84), 0.08)
	return min(d, segment(x, y, -0.32, -0.32, 0.32, 0.32, 0.09), segment(x, y, -0.32, 0.32, 0.32, -0.32, 0.09))
end

S.keyboard = function(x, y)
	local d = ring(box(x, y, 0, 0, 0.92, 0.56, 0.14), 0.075)
	for row = 0, 1 do
		for col = -2, 2 do
			d = min(d, box(x, y, col * 0.3, -0.2 + row * 0.24, 0.07, 0.06, 0.02))
		end
	end
	return min(d, box(x, y, 0, 0.3, 0.42, 0.06, 0.03))
end

S.list = function(x, y)
	local d = math.huge
	for i = -1, 1 do
		d = min(d, circle(x, y, -0.66, i * 0.5, 0.11), segment(x, y, -0.34, i * 0.5, 0.78, i * 0.5, 0.09))
	end
	return d
end

S.copy = function(x, y)
	local back = ring(box(x, y, -0.18, -0.18, 0.5, 0.5, 0.1), 0.075)
	local front = box(x, y, 0.2, 0.2, 0.5, 0.5, 0.1)
	return min(max(back, -(front - 0.14)), ring(front, 0.075))
end

S.folder = function(x, y)
	return ring(polygon(x, y, FOLDER), 0.08)
end

S.save = function(x, y)
	local body = polygon(x, y, FLOPPY)
	local d = ring(body, 0.075)
	d = min(d, ring(box(x, y, -0.06, -0.54, 0.38, 0.2, 0.02), 0.07))
	return min(d, ring(box(x, y, 0, 0.38, 0.5, 0.3, 0.04), 0.07))
end

S.lock = function(x, y)
	local shackle = max(ring(circle(x, y, 0, -0.3, 0.38), 0.09), y + 0.1)
	shackle = min(shackle, segment(x, y, -0.38, -0.3, -0.38, -0.05, 0.09), segment(x, y, 0.38, -0.3, 0.38, -0.05, 0.09))
	local body = box(x, y, 0, 0.36, 0.64, 0.46, 0.1)
	return min(shackle, max(body, -circle(x, y, 0, 0.3, 0.11)))
end

S.code = function(x, y)
	return min(polyline(x, y, CODE_L, 0.1), polyline(x, y, CODE_R, 0.1), segment(x, y, 0.16, -0.78, -0.16, 0.78, 0.08))
end

S.tag = function(x, y)
	return min(ring(polygon(x, y, TAG), 0.08), circle(x, y, -0.42, 0, 0.13))
end

S.star = function(x, y)
	-- tiny four-point sparkle for bullets and markers
	return polygon(x * 1.1, y * 1.1, SIGIL) / 1.1
end

S.grip = function(x, y)
	local d = math.huge
	for i = 0, 2 do
		local o = 0.9 - i * 0.55
		d = min(d, segment(x, y, o, 0.9, 0.9, o, 0.08))
	end
	return d
end

S.pin = function(x, y)
	return min(ring(circle(x, y, 0, -0.28, 0.44), 0.1), segment(x, y, 0, 0.16, 0, 0.98, 0.09))
end

S.hourglass = function(x, y)
	local d = min(segment(x, y, -0.6, -0.86, 0.6, -0.86, 0.08), segment(x, y, -0.6, 0.86, 0.6, 0.86, 0.08))
	local glass = max(abs(x) - (abs(y) * 0.55 + 0.06), abs(y) - 0.8)
	return min(d, ring(glass, 0.07), max(glass, -y + 0.35))
end

-- Order defines atlas placement; append new names at the end to keep caches valid
Icons.Order = {
	"sigil", "crosshair", "eye", "skull", "rabbit", "gear", "user", "knife",
	"bolt", "thorns", "spider", "cross", "drop", "flame", "moon", "globe",
	"check", "chevron", "close", "minus", "plus", "search", "info", "warning",
	"success", "error", "keyboard", "list", "copy", "folder", "save", "lock",
	"code", "tag", "star", "grip", "pin", "hourglass",
}

-- Friendly aliases people tend to reach for
Icons.Aliases = {
	aim = "crosshair", combat = "crosshair", target = "crosshair",
	visuals = "eye", esp = "eye", view = "eye",
	player = "user", players = "user", person = "user",
	settings = "gear", config = "save", configs = "save",
	movement = "bolt", speed = "bolt",
	misc = "spider", exploits = "spider",
	theme = "drop", themes = "drop", blood = "drop",
	world = "globe", rage = "flame", fire = "flame",
	keybinds = "keyboard", scripts = "code", danger = "skull",
	x = "close", ok = "check", notification = "info",
}

function Icons.resolve(name)
	if not name then
		return nil
	end
	name = string.lower(name)
	if S[name] then
		return name
	end
	return Icons.Aliases[name]
end

return Icons
