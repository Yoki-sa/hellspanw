--[[
	PixelArt
	Hand-tuned pixel sprites, each with its own palette (they are meant to
	read as a different medium layered over the game, not as part of the
	themed UI). Draw them with ResampleMode = Pixelated.

	Packs (render/pixel/*):
		Graveyard  bones, skull, ribcage, pelvis, vertebrae, thorned vines, roses
		Inferno    charred bones, horned skull, animated fire, brimstone, magma
		Ritual     wicker effigy, goat skull, chains, candles, rosary, nails, pentagram
		Eldritch   sinew, eyes that can look around, beating heart, writhing tentacles
		Hud        ritual circle, fangs, tombstone, scroll, pixel bars

	Each pack is a function(kit) that registers recipes; kit carries the
	shared silhouettes (bone, skull, ribs, pelvis) so packs can re-skin them.
]]

local Pixel = import("render/Pixel")
local Rng = import("render/Rng")

local PixelArt = {}

local Recipes = {}
PixelArt.Recipes = Recipes
PixelArt.Meta = {}

local kit = { Pixel = Pixel, Rng = Rng }

function kit.recipe(name, version, width, height, build)
	PixelArt.Meta[name] = { Width = width, Height = height }
	table.insert(Recipes, {
		Name = name,
		Version = version,
		Pixel = true,
		Build = function()
			local baked = build()
			assert(baked.Width == width and baked.Height == height, "PixelArt: " .. name .. " size mismatch")
			return baked
		end,
	})
end

-- distance to an ellipse outline (first-order approximation, in pixels)
function kit.ellipseDistance(x, y, cx, cy, rx, ry)
	local dx, dy = x - cx, y - cy
	local f = (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry) - 1
	local gx, gy = 2 * dx / (rx * rx), 2 * dy / (ry * ry)
	local g = math.sqrt(gx * gx + gy * gy)
	if g < 1e-6 then
		return math.huge
	end
	return math.abs(f) / g
end

function kit.rotated(x, y, cx, cy, angle)
	local c, s = math.cos(angle), math.sin(angle)
	local dx, dy = x - cx, y - cy
	return cx + dx * c + dy * s, cy - dx * s + dy * c
end

-- true when (x, y) lies within `radius(t)` of a quadratic bezier a→c→b
function kit.nearCurve(x, y, ax, ay, cx, cy, bx, by, radius, steps)
	steps = steps or 24
	for i = 0, steps do
		local t = i / steps
		local u = 1 - t
		local px = u * u * ax + 2 * u * t * cx + t * t * bx
		local py = u * u * ay + 2 * u * t * cy + t * t * by
		local r = type(radius) == "function" and radius(t) or radius
		local dx, dy = x - px, y - py
		if dx * dx + dy * dy <= r * r then
			return true
		end
	end
	return false
end

-- shading recipes shared by every bone-like material
kit.BONE_SHADE = { b = { light = "w", dark = "s", deep = "d" } }

-- Silhouettes ------------------------------------------------------------

-- long bone with knobbed ends (42x14, material "b")
function kit.boneGrid()
	local grid = Pixel.new(42, 14)
	grid:fill(function(x, y)
		for _, knob in { { 5.5, 4.6 }, { 5.5, 9.4 }, { 36.5, 4.6 }, { 36.5, 9.4 } } do
			if Pixel.ellipse(x, y, knob[1], knob[2], 3.3, 3.1) then
				return true
			end
		end
		return x >= 6 and x <= 36 and y >= 5 and y <= 9
	end, "b")
	return grid
end

kit.SKULL_ROWS = {
	"................",
	".....oooooo.....",
	"...oowwwwwboo...",
	"..owwwwwwwwbbo..",
	".owwwwwwwwwwbso.",
	".owwwwwwwwwbbso.",
	".owdkkdwwdkkdso.",
	".owkkkkwwkkkkso.",
	".obdkkdwwdkkdso.",
	".obbddbkkbddsso.",
	"..obbbbkkbbbso..",
	"..oobbbbbbbsoo..",
	"...owkwkwkwko...",
	"...obwbwbwbwo...",
	"....osssssso....",
	".....oooooo.....",
}

-- ribcage (24x25): spine, clavicles, five pairs of drooping ribs
function kit.ribsGrid()
	local grid = Pixel.new(24, 25)
	grid:fill(function(x, y)
		if x >= 11 and x <= 13 and y >= 1 and y <= 24 then
			return true
		end
		if Pixel.segment(x, y, 2.4, 4.2, 11, 2.6, 0.95) or Pixel.segment(x, y, 21.6, 4.2, 13, 2.6, 0.95) then
			return true
		end
		for k = 0, 4 do
			local top = 5.4 + k * 3.2
			local ry = 4.6 - k * 0.25
			local cy = top + ry
			local rx = 10.4 - k * 1.15
			if y <= cy + 1.2 and math.abs(x - 12) >= 1.5 and kit.ellipseDistance(x, y, 12, cy, rx, ry) <= 0.72 then
				return true
			end
		end
		return false
	end, "b")
	return grid
end

-- notches down the spine, applied after shading
function kit.notchSpine(grid, key)
	for y = 3, 23, 3 do
		grid:set(11, y, key)
		grid:set(12, y, key)
	end
end

-- pelvis (26x17): iliac wings, sacrum, pubic ring with obturator holes
function kit.pelvisGrid()
	local grid = Pixel.new(26, 17)
	local rotated, ellipseDistance = kit.rotated, kit.ellipseDistance
	grid:fill(function(x, y)
		local ax, ay = rotated(x, y, 6.6, 5.4, 0.42)
		local bx, by = rotated(x, y, 19.4, 5.4, -0.42)
		return Pixel.ellipse(ax, ay, 6.6, 5.4, 5.6, 3.7)
			or Pixel.ellipse(bx, by, 19.4, 5.4, 5.6, 3.7)
			or Pixel.ellipse(x, y, 13, 6.2, 2.7, 4.3)
			or ellipseDistance(x, y, 13, 11.4, 5.4, 3.4) <= 0.95
	end, "b")
	grid:clear(function(x, y)
		return Pixel.ellipse(x, y, 13, 11.4, 4.5, 2.5) and math.abs(x - 13) > 0.9
	end)
	return grid
end

-- the inner shading of the iliac wings, applied after shading
function kit.fossa(grid, key)
	local rotated, ellipseDistance = kit.rotated, kit.ellipseDistance
	grid:fill(function(x, y)
		local ax, ay = rotated(x, y, 6.9, 5.2, 0.42)
		local bx, by = rotated(x, y, 19.1, 5.2, -0.42)
		return grid:get(math.floor(x), math.floor(y)) ~= false
			and (ellipseDistance(ax, ay, 6.9, 5.2, 3.4, 1.9) <= 0.45 or ellipseDistance(bx, by, 19.1, 5.2, 3.4, 1.9) <= 0.45)
	end, key)
end

-- scatters glowing cracks over a material (deterministic per seed)
function kit.cracks(grid, onKey, crackKey, hotKey, seed, count)
	local rng = Rng.new(seed)
	local cells = {}
	for y = 0, grid.Height - 1 do
		for x = 0, grid.Width - 1 do
			if grid:get(x, y) == onKey then
				table.insert(cells, { x, y })
			end
		end
	end
	for _ = 1, count do
		if #cells == 0 then
			break
		end
		local start = cells[rng:int(1, #cells)]
		local x, y = start[1], start[2]
		for step = 1, rng:int(2, 4) do
			if grid:get(x, y) ~= false and grid:get(x, y) ~= "o" then
				grid:set(x, y, step == 2 and hotKey or crackKey)
			end
			x += rng:sign()
			if rng:next() < 0.4 then
				y += rng:sign()
			end
		end
	end
end

function kit.merge(...)
	local out = {}
	for i = 1, select("#", ...) do
		for key, value in select(i, ...) do
			out[key] = value
		end
	end
	return out
end

-- Palettes -----------------------------------------------------------------

kit.Palettes = {
	Bone = { o = "1a120e", w = "f6eedc", b = "dccdb0", s = "a8977a", d = "6a5a48", k = "21180f" },
	Char = {
		o = "0b0504", w = "8a6a5c", b = "56423a", s = "382a24", d = "1e1410", k = "ff7a1c",
		e = "ff5a10", E = "ffd27a",
	},
	Wood = {
		o = "160d06", w = "d3a66c", b = "a87842", s = "74502a", d = "4a3018", k = "120a04",
		t = "d8c49a", tL = "efe2c0", tD = "9a8458",
	},
	Flesh = {
		o = "1e050b", w = "f7a3ad", b = "d0566a", s = "93283f", d = "5c1226", k = "16030a", v = "6e0a1e",
	},
	Iron = { o = "0b0b0d", w = "d6d9e0", b = "8f939e", s = "5d616b", d = "393b42", r = "8a4220", R = "5a2a12" },
	Fire = { o = "2a0602", f1 = "7a1006", f2 = "d02a0a", f3 = "ff6a14", f4 = "ffb43a", f5 = "fff2b8" },
	Blood = { o = "160205", r = "c8102e", rL = "ff4058", rD = "6a0614" },
}

-- Packs --------------------------------------------------------------------

for _, pack in { "Graveyard", "Inferno", "Ritual", "Eldritch", "Hud" } do
	import("render/pixel/" .. pack)(kit)
end

return PixelArt
