--[[
	Hud pack: the inverted pentagram (crosshair / tag), a ritual circle for
	the FOV, fangs for the jaw ring, a tombstone and a scroll for 9-sliced
	target cards, and a pixel health bar.
]]

local Pixel = import("render/Pixel")

return function(kit)
	local recipe = kit.recipe
	local BLOOD, BONE = kit.Palettes.Blood, kit.Palettes.Bone

	-- star points of an inverted pentagram (one point straight down)
	local function starPoints(cx, cy, radius)
		local points = {}
		for k = 0, 4 do
			local angle = math.rad(90 + k * 72)
			points[k + 1] = { cx + math.cos(angle) * radius, cy + math.sin(angle) * radius }
		end
		return points
	end

	local function star(x, y, points, width)
		for k = 1, 5 do
			local a = points[k]
			local b = points[(k + 1) % 5 + 1]
			if Pixel.segment(x, y, a[1], a[2], b[1], b[2], width) then
				return true
			end
		end
		return false
	end

	recipe("px_pentagram", 2, 31, 31, function()
		local grid = Pixel.new(31, 31)
		local points = starPoints(15.5, 15.5, 13.4)
		grid:fill(function(x, y)
			local d = math.sqrt((x - 15.5) ^ 2 + (y - 15.5) ^ 2)
			return math.abs(d - 14.0) <= 0.55 or star(x, y, points, 0.5)
		end, "r")
		-- hot pixels where the star touches the circle
		for _, p in points do
			grid:set(math.floor(p[1]), math.floor(p[2]), "rL")
		end
		grid:outline("o")
		return grid:bake(BLOOD)
	end)
	-- the FOV ritual circle: double ring, pentagram, runes between the rings.
	-- 128px so it lands near 2x at the default FOV, like the ESP sprites
	recipe("px_ritual_circle", 2, 128, 128, function()
		local grid = Pixel.new(128, 128)
		local c = 64
		local points = starPoints(c, c, 49.6)
		grid:fill(function(x, y)
			local d = math.sqrt((x - c) ^ 2 + (y - c) ^ 2)
			return math.abs(d - 60.4) <= 0.75 or math.abs(d - 51.4) <= 0.75 or star(x, y, points, 0.7)
		end, "r")
		-- runes in the band between the rings, three alternating glyphs
		for k = 0, 19 do
			local angle = math.rad(k * 18 + 9)
			local gx, gy = c + math.cos(angle) * 55.9, c + math.sin(angle) * 55.9
			local tx, ty = -math.sin(angle), math.cos(angle) -- tangent
			local shape = k % 3
			grid:fill(function(x, y)
				local lx = (x - gx) * tx + (y - gy) * ty
				local ly = (x - gx) * math.cos(angle) + (y - gy) * math.sin(angle)
				if shape == 0 then
					return (math.abs(lx) <= 0.55 and math.abs(ly) <= 2.6) or (math.abs(ly + 0.8) <= 0.55 and math.abs(lx) <= 1.9)
				elseif shape == 1 then
					return math.abs(lx - ly * 0.7) <= 0.6 and math.abs(ly) <= 2.6 or (math.abs(ly - 2.1) <= 0.55 and math.abs(lx - 1) <= 1.3)
				end
				return math.abs(math.sqrt(lx * lx + ly * ly) - 1.9) <= 0.6 or (math.abs(lx) <= 0.5 and math.abs(ly) <= 0.5)
			end, "rL")
		end
		-- small circles where the star touches the inner ring
		for _, p in points do
			grid:fill(function(x, y)
				return math.abs(math.sqrt((x - p[1]) ^ 2 + (y - p[2]) ^ 2) - 2.6) <= 0.6
			end, "rL")
		end
		grid:outline("o")
		return grid:bake(BLOOD)
	end)
	-- a single fang pointing down (rotated around the FOV jaw ring)
	recipe("px_fang", 1, 8, 14, function()
		local grid = Pixel.new(8, 14)
		grid:fill(function(x, y)
			return Pixel.triangle(x, y, 0.8, 1.2, 7.2, 1.2, 4.2, 13.6) or Pixel.ellipse(x, y, 4, 1.4, 3.3, 1.5)
		end, "b")
		grid:shade(kit.BONE_SHADE)
		grid:outline("o")
		return grid:bake(kit.merge(BONE, { b = "e4d6aa", w = "fbf2d4", s = "b4a274" }))
	end)

	-- headstone for the 9-sliced target card (slice: 7, 15, 25, 28)
	recipe("px_tombstone", 2, 32, 36, function()
		local grid = Pixel.new(32, 36)
		grid:fill(function(x, y)
			return (x >= 2 and x < 30 and y >= 10 and y < 33) or Pixel.ellipse(x, y, 16, 10.5, 14, 9.6) and y < 12
				or (x >= 0 and x < 32 and y >= 32)
		end, "b")
		grid:shade({ b = { light = "w", dark = "s", deep = "d" } })
		-- a crack (kept inside the unstretched top-right slice) and some moss
		for _, cell in { { 26, 7 }, { 27, 8 }, { 27, 9 }, { 26, 10 }, { 27, 11 }, { 28, 12 } } do
			grid:set(cell[1], cell[2], "c")
		end
		for _, cell in { { 3, 30 }, { 4, 30 }, { 2, 31 }, { 3, 31 }, { 5, 31 }, { 27, 31 }, { 28, 31 }, { 28, 30 }, { 1, 32 }, { 30, 32 } } do
			grid:set(cell[1], cell[2], "m")
		end
		grid:set(4, 29, "mL")
		grid:set(28, 29, "mL")
		grid:outline("o")
		return grid:bake({
			o = "121214", w = "8e9096", b = "66686f", s = "47494f", d = "2c2d32",
			c = "1c1d21", m = "3a5a2a", mL = "5e8a3c",
		})
	end)

	-- parchment scroll with rolled ends (slice: 10, 5, 38, 19)
	recipe("px_scroll", 1, 48, 24, function()
		local grid = Pixel.new(48, 24)
		grid:fill(function(x, y)
			local wave = math.sin(x * 0.5) * 0.6
			return x >= 6 and x < 42 and y >= 3 + wave and y < 21 + wave
		end, "b")
		grid:fill(function(x, y)
			local inRoll = (x >= 1 and x < 8) or (x >= 40 and x < 47)
			return inRoll and y >= 1 and y < 23
		end, "r")
		grid:shade({
			b = { light = "w", dark = "s", deep = "d" },
			r = { light = "rL", dark = "rD" },
		})
		grid:outline("o")
		return grid:bake({
			o = "2a1a0c", w = "f6e6bc", b = "e0c890", s = "b89a60", d = "8a6a3a",
			r = "c8a468", rL = "ead2a0", rD = "7a5a2a",
		})
	end)

	-- pixel health bar tiles (tile along X)
	recipe("px_bar_fill", 1, 4, 6, function()
		local grid = Pixel.new(4, 6)
		grid:fill(function(_, y)
			return y < 1
		end, "rL")
		grid:fill(function(_, y)
			return y >= 1 and y < 4
		end, "r")
		grid:fill(function(_, y)
			return y >= 4 and y < 5
		end, "rD")
		grid:fill(function(_, y)
			return y >= 5
		end, "o")
		return grid:bake(BLOOD)
	end)

	recipe("px_bar_back", 1, 4, 6, function()
		local grid = Pixel.new(4, 6)
		grid:fill(function(_, y)
			return y < 1
		end, "s")
		grid:fill(function(_, y)
			return y >= 1 and y < 5
		end, "b")
		grid:fill(function(_, y)
			return y >= 5
		end, "o")
		return grid:bake({ o = "0e0b0c", b = "2a2224", s = "3a3034" })
	end)
end
