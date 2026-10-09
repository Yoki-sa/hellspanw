--[[
	Graveyard pack: ivory bones, a grinning skull, thorned wine-dark vines,
	blood roses and a bone-tipped thorn.
]]

local Pixel = import("render/Pixel")

return function(kit)
	local recipe, rotated = kit.recipe, kit.rotated
	local BONE = kit.Palettes.Bone
	local VINE = {
		o = "120609",
		st = "5a1a26", stL = "8a2a3a", stD = "34101a",
		lf = "2f4f22", lfL = "5a8a35", lfD = "1b3014",
		th = "d9ccb0", thL = "f6eedc", thD = "a8977a",
		rs = "b3122e", rsL = "e8344f", rsD = "6a0a1a",
	}
	local VINE_SHADE = {
		st = { light = "stL", dark = "stD" },
		lf = { light = "lfL", dark = "lfD" },
		th = { light = "thL", dark = "thD" },
		rs = { light = "rsL", dark = "rsD" },
	}

	recipe("px_bone", 1, 42, 14, function()
		local grid = kit.boneGrid()
		grid:shade(kit.BONE_SHADE)
		-- hairline cracks so it reads as old bone, not a dumbbell
		for _, cell in { { 15, 6 }, { 16, 6 }, { 17, 7 }, { 27, 7 }, { 28, 6 } } do
			grid:set(cell[1], cell[2], "s")
		end
		grid:outline("o")
		return grid:bake(BONE)
	end)

	recipe("px_skull", 1, 16, 16, function()
		return Pixel.fromRows(kit.SKULL_ROWS):bake(BONE)
	end)

	recipe("px_ribs", 2, 24, 25, function()
		local grid = kit.ribsGrid()
		grid:shade(kit.BONE_SHADE)
		kit.notchSpine(grid, "d")
		grid:outline("o")
		return grid:bake(BONE)
	end)

	recipe("px_pelvis", 2, 26, 17, function()
		local grid = kit.pelvisGrid()
		grid:shade(kit.BONE_SHADE)
		kit.fossa(grid, "s")
		grid:outline("o")
		return grid:bake(BONE)
	end)

	-- one vertebra; tiles vertically into a spine (health bar)
	recipe("px_vertebra", 2, 12, 7, function()
		local grid = Pixel.new(12, 7)
		grid:fill(function(x, y)
			return Pixel.ellipse(x, y, 6, 3, 3.1, 2.1)
				or Pixel.segment(x, y, 1.6, 2.4, 10.4, 2.4, 0.8)
				or Pixel.segment(x, y, 6, 4.2, 6, 6.2, 0.7)
		end, "b")
		grid:shade(kit.BONE_SHADE)
		grid:set(5, 2, "d")
		grid:set(6, 2, "d")
		grid:outline("o")
		return grid:bake(BONE)
	end)

	-- thorned vine, seamless along X
	local function vineGrid()
		local grid = Pixel.new(24, 12)
		grid.WrapX = true
		local function stemY(x)
			return 6 + 1.6 * math.sin(2 * math.pi * x / 24)
		end
		grid:fill(function(x, y)
			return math.abs(y - stemY(x)) <= 1.0
		end, "st")
		grid:fill(function(x, y)
			local ax, ay = rotated(x, y, 7, stemY(7) + 2.8, 0.55)
			local bx, by = rotated(x, y, 15.5, stemY(15.5) - 2.8, -0.55)
			return Pixel.ellipse(ax, ay, 7, stemY(7) + 2.8, 3.0, 1.45) or Pixel.ellipse(bx, by, 15.5, stemY(15.5) - 2.8, 3.0, 1.45)
		end, "lf", false)
		for _, thorn in { { 2.5, -1 }, { 11.5, 1 }, { 18.5, -1 } } do
			local tx, dir = thorn[1], thorn[2]
			local base = stemY(tx) + dir * 0.6
			grid:fill(function(x, y)
				return Pixel.triangle(x, y, tx - 1.6, base, tx + 1.4, base, tx + 1.8, base + dir * 3.6)
			end, "th", false)
		end
		grid:fill(function(x, y)
			return Pixel.ellipse(x, y, 22, stemY(22) + 2.3, 1.35, 1.35)
		end, "rs", false)
		grid:shade(VINE_SHADE)
		grid:outline("o")
		return grid
	end

	recipe("px_vine_h", 2, 24, 12, function()
		return vineGrid():bake(VINE)
	end)

	recipe("px_vine_v", 2, 12, 24, function()
		return vineGrid():transpose():bake(VINE)
	end)

	-- blood rose with two leaves (box corners)
	recipe("px_rose", 1, 16, 16, function()
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

	-- curved thorn pointing up: wine-dark base hardening into a bone tip
	recipe("px_thorn", 2, 11, 22, function()
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
end
