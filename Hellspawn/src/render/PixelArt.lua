--[[
	PixelArt
	The "graveyard" sprite pack: bones, skull, ribcage, pelvis, vertebrae,
	thorned vines, a rose and a thorn. Unlike the rest of the library these
	keep their own hand-picked palettes (ivory bone, wine-dark vines, blood
	roses) — they're meant to look like a different medium layered over the
	game. Draw them with ResampleMode = Pixelated.
]]

local Pixel = import("render/Pixel")

local PixelArt = {}

local BONE = {
	o = "1a120e", -- keyline
	w = "f6eedc", -- lit edge
	b = "dccdb0", -- body
	s = "a8977a", -- shade
	d = "6a5a48", -- deep shade / socket rim
	k = "21180f", -- socket / gaps
}

local VINE = {
	o = "120609",
	st = "5a1a26", stL = "8a2a3a", stD = "34101a",
	lf = "2f4f22", lfL = "5a8a35", lfD = "1b3014",
	th = "d9ccb0", thL = "f6eedc", thD = "a8977a",
	rs = "b3122e", rsL = "e8344f", rsD = "6a0a1a",
}

local BONE_SHADE = { b = { light = "w", dark = "s", deep = "d" } }
local VINE_SHADE = {
	st = { light = "stL", dark = "stD" },
	lf = { light = "lfL", dark = "lfD" },
	th = { light = "thL", dark = "thD" },
	rs = { light = "rsL", dark = "rsD" },
}

-- distance to an ellipse outline (first-order approximation, in pixels)
local function ellipseDistance(x, y, cx, cy, rx, ry)
	local dx, dy = x - cx, y - cy
	local f = (dx * dx) / (rx * rx) + (dy * dy) / (ry * ry) - 1
	local gx, gy = 2 * dx / (rx * rx), 2 * dy / (ry * ry)
	local g = math.sqrt(gx * gx + gy * gy)
	if g < 1e-6 then
		return math.huge
	end
	return math.abs(f) / g
end

local function rotated(x, y, cx, cy, angle)
	local c, s = math.cos(angle), math.sin(angle)
	local dx, dy = x - cx, y - cy
	return cx + dx * c + dy * s, cy - dx * s + dy * c
end

PixelArt.Meta = {
	px_bone = { Width = 42, Height = 14 },
	px_skull = { Width = 16, Height = 16 },
	px_ribs = { Width = 24, Height = 25 },
	px_pelvis = { Width = 26, Height = 17 },
	px_vertebra = { Width = 12, Height = 7 },
	px_vine_h = { Width = 24, Height = 12 },
	px_vine_v = { Width = 12, Height = 24 },
	px_rose = { Width = 16, Height = 16 },
	px_thorn = { Width = 11, Height = 22 },
}

local Recipes = {}
PixelArt.Recipes = Recipes
local function recipe(name, version, build)
	table.insert(Recipes, { Name = name, Version = version, Build = build, Pixel = true })
end

-- Long bone, knobbed at both ends (drawn horizontally, stretch along X)
recipe("px_bone", 1, function()
	local grid = Pixel.new(42, 14)
	grid:fill(function(x, y)
		for _, knob in { { 5.5, 4.6 }, { 5.5, 9.4 }, { 36.5, 4.6 }, { 36.5, 9.4 } } do
			if Pixel.ellipse(x, y, knob[1], knob[2], 3.3, 3.1) then
				return true
			end
		end
		return x >= 6 and x <= 36 and y >= 5 and y <= 9
	end, "b")
	grid:shade(BONE_SHADE)
	-- a few hairline cracks so it reads as old bone, not a dumbbell
	for _, cell in { { 15, 6 }, { 16, 6 }, { 17, 7 }, { 27, 7 }, { 28, 6 } } do
		grid:set(cell[1], cell[2], "s")
	end
	grid:outline("o")
	return grid:bake(BONE)
end)

recipe("px_skull", 1, function()
	local grid = Pixel.fromRows({
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
	})
	return grid:bake(BONE)
end)

-- Ribcage: segmented spine, clavicles and five pairs of drooping ribs
recipe("px_ribs", 2, function()
	local grid = Pixel.new(24, 25)
	grid:fill(function(x, y)
		if x >= 11 and x <= 13 and y >= 1 and y <= 24 then
			return true -- spine
		end
		if Pixel.segment(x, y, 2.4, 4.2, 11, 2.6, 0.95) or Pixel.segment(x, y, 21.6, 4.2, 13, 2.6, 0.95) then
			return true -- clavicles
		end
		for k = 0, 4 do
			local top = 5.4 + k * 3.2
			local ry = 4.6 - k * 0.25
			local cy = top + ry
			local rx = 10.4 - k * 1.15
			if y <= cy + 1.2 and math.abs(x - 12) >= 1.5 and ellipseDistance(x, y, 12, cy, rx, ry) <= 0.72 then
				return true
			end
		end
		return false
	end, "b")
	grid:shade(BONE_SHADE)
	for y = 3, 23, 3 do -- vertebra notches
		grid:set(11, y, "d")
		grid:set(12, y, "d")
	end
	grid:outline("o")
	return grid:bake(BONE)
end)
-- Pelvis: flared iliac wings, sacrum, pubic ring with the obturator holes
recipe("px_pelvis", 2, function()
	local grid = Pixel.new(26, 17)
	grid:fill(function(x, y)
		local ax, ay = rotated(x, y, 6.6, 5.4, 0.42)
		local bx, by = rotated(x, y, 19.4, 5.4, -0.42)
		return Pixel.ellipse(ax, ay, 6.6, 5.4, 5.6, 3.7)
			or Pixel.ellipse(bx, by, 19.4, 5.4, 5.6, 3.7)
			or Pixel.ellipse(x, y, 13, 6.2, 2.7, 4.3)
			or ellipseDistance(x, y, 13, 11.4, 5.4, 3.4) <= 0.95
	end, "b")
	grid:clear(function(x, y)
		local inner = Pixel.ellipse(x, y, 13, 11.4, 4.5, 2.5)
		return inner and math.abs(x - 13) > 0.9
	end)
	grid:shade(BONE_SHADE)
	-- iliac fossa shading inside each wing
	grid:fill(function(x, y)
		local ax, ay = rotated(x, y, 6.9, 5.2, 0.42)
		local bx, by = rotated(x, y, 19.1, 5.2, -0.42)
		return ellipseDistance(ax, ay, 6.9, 5.2, 3.4, 1.9) <= 0.45 or ellipseDistance(bx, by, 19.1, 5.2, 3.4, 1.9) <= 0.45
	end, "s")
	grid:outline("o")
	return grid:bake(BONE)
end)

-- One vertebra; tiles vertically into a spine (used as a health bar)
recipe("px_vertebra", 2, function()
	local grid = Pixel.new(12, 7)
	grid:fill(function(x, y)
		return Pixel.ellipse(x, y, 6, 3, 3.1, 2.1)
			or Pixel.segment(x, y, 1.6, 2.4, 10.4, 2.4, 0.8)
			or Pixel.segment(x, y, 6, 4.2, 6, 6.2, 0.7)
	end, "b")
	grid:shade(BONE_SHADE)
	grid:set(5, 2, "d")
	grid:set(6, 2, "d")
	grid:outline("o")
	return grid:bake(BONE)
end)
-- Thorned vine, seamless along X
local function vineGrid()
	local grid = Pixel.new(24, 12)
	grid.WrapX = true
	local function stemY(x)
		return 6 + 1.6 * math.sin(2 * math.pi * x / 24)
	end
	grid:fill(function(x, y)
		return math.abs(y - stemY(x)) <= 1.0
	end, "st")
	-- leaves: tilted ellipses, one above and one below the stem
	grid:fill(function(x, y)
		local ax, ay = rotated(x, y, 7, stemY(7) + 2.8, 0.55)
		local bx, by = rotated(x, y, 15.5, stemY(15.5) - 2.8, -0.55)
		return Pixel.ellipse(ax, ay, 7, stemY(7) + 2.8, 3.0, 1.45) or Pixel.ellipse(bx, by, 15.5, stemY(15.5) - 2.8, 3.0, 1.45)
	end, "lf", false)
	-- bone-white thorns: little triangles hooked forward off the stem
	for _, thorn in { { 2.5, -1 }, { 11.5, 1 }, { 18.5, -1 } } do
		local tx, dir = thorn[1], thorn[2]
		local base = stemY(tx) + dir * 0.6
		grid:fill(function(x, y)
			return Pixel.triangle(x, y, tx - 1.6, base, tx + 1.4, base, tx + 1.8, base + dir * 3.6)
		end, "th", false)
	end	-- a blood bud
	grid:fill(function(x, y)
		return Pixel.ellipse(x, y, 22, stemY(22) + 2.3, 1.35, 1.35)
	end, "rs", false)
	grid:shade(VINE_SHADE)
	grid:outline("o")
	return grid
end

recipe("px_vine_h", 2, function()
	return vineGrid():bake(VINE)
end)

recipe("px_vine_v", 2, function()
	return vineGrid():transpose():bake(VINE)
end)

-- Blood rose with two leaves (sits on the box corners)
recipe("px_rose", 1, function()
	local grid = Pixel.new(16, 16)
	grid:fill(function(x, y)
		local ax, ay = rotated(x, y, 3.6, 11.4, 0.6)
		local bx, by = rotated(x, y, 12.4, 11.4, -0.6)
		return Pixel.ellipse(ax, ay, 3.6, 11.4, 3.0, 1.4) or Pixel.ellipse(bx, by, 12.4, 11.4, 3.0, 1.4)
	end, "lf")
	grid:fill(function(x, y)
		return Pixel.ellipse(x, y, 8, 7.4, 4.6, 4.3)
	end, "rs")
	grid:shade(VINE_SHADE)
	-- petal swirl
	grid:fill(function(x, y)
		local angle = math.atan2(y - 7.4, x - 8)
		local radius = math.sqrt((x - 8) ^ 2 + (y - 7.4) ^ 2)
		local spiral = (angle + math.pi) / (2 * math.pi) * 2.6 + 0.8
		return radius < 4 and math.abs(radius - spiral) < 0.45
	end, "rsD")
	grid:set(8, 7, "rsL")
	grid:set(7, 6, "rsL")
	grid:outline("o")
	return grid:bake(VINE)
end)

-- Curved thorn pointing up: wine-dark base hardening into a bone tip
recipe("px_thorn", 2, function()
	local grid = Pixel.new(11, 22)
	local function inside(x, y)
		local t = (y - 0.5) / 20
		local half = 0.3 + 3.6 * t ^ 1.35
		local center = 5.2 + 2.4 * (1 - t) ^ 2.2
		return math.abs(x - center) <= half and y < 21.5
	end
	grid:fill(inside, "st")
	grid:fill(function(x, y)
		return inside(x, y) and y < 8
	end, "th")
	grid:shade(VINE_SHADE)
	grid:outline("o")
	return grid:bake(VINE)
end)
return PixelArt
