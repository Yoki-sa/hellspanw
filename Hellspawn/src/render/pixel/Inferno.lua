--[[
	Inferno pack: charred bones split by glowing embers, a horned demon skull
	with burning sockets, three-frame fire, brimstone, magma and fireballs.
]]

local Pixel = import("render/Pixel")

return function(kit)
	local recipe = kit.recipe
	local CHAR = kit.Palettes.Char
	local FIRE = kit.Palettes.Fire
	local HORN = { h = "4a0e0a", hL = "8a2a1a", hD = "220504" }

	recipe("px_char_bone", 2, 42, 14, function()
		local grid = kit.boneGrid()
		grid:shade(kit.BONE_SHADE)
		kit.cracks(grid, "b", "e", "E", 31, 6)
		grid:outline("o")
		return grid:bake(CHAR)
	end)

	recipe("px_char_ribs", 2, 24, 25, function()
		local grid = kit.ribsGrid()
		grid:shade(kit.BONE_SHADE)
		kit.notchSpine(grid, "d")
		kit.cracks(grid, "b", "e", "E", 47, 7)
		grid:outline("o")
		return grid:bake(CHAR)
	end)

	recipe("px_char_pelvis", 2, 26, 17, function()
		local grid = kit.pelvisGrid()
		grid:shade(kit.BONE_SHADE)
		kit.fossa(grid, "s")
		kit.cracks(grid, "b", "e", "E", 59, 5)
		grid:outline("o")
		return grid:bake(CHAR)
	end)

	-- skull with curling horns; sockets burn orange
	recipe("px_demon_skull", 2, 22, 21, function()
		local grid = Pixel.new(22, 21)
		local function horn(x, y, flip)
			if flip then
				x = 22 - x
			end
			return kit.nearCurve(x, y, 6.6, 9.2, 0.6, 6, 2.6, 0.6, function(t)
				return 1.9 * (1 - t) + 0.45
			end)
		end
		grid:fill(function(x, y)
			return horn(x, y, false) or horn(x, y, true)
		end, "h")
		grid:shade({ h = { light = "hL", dark = "hD" } })
		grid:outline("o")
		grid:paste(Pixel.fromRows(kit.SKULL_ROWS), 3, 5)
		return grid:bake(kit.merge(CHAR, HORN))
	end)

	-- fire tiles: flame tongues rising from the bottom edge, seamless along X
	local function flameHeight(x, phase)
		local k = 2 * math.pi / 24
		return 3.2
			+ 2.4 * (0.5 + 0.5 * math.sin(k * 2 * x + phase))
			+ 2.0 * (0.5 + 0.5 * math.sin(k * 3 * x - phase * 1.7 + 1.3))
			+ 1.6 * (0.5 + 0.5 * math.sin(k * 6 * x + phase * 2.3))
	end
	local function heat(r)
		if r < 0.18 then
			return "f5"
		elseif r < 0.42 then
			return "f4"
		elseif r < 0.66 then
			return "f3"
		elseif r < 0.86 then
			return "f2"
		end
		return "f1"
	end
	local function fireGrid(phase)
		local grid = Pixel.new(24, 14)
		grid.WrapX = true
		for y = 0, 13 do
			for x = 0, 23 do
				local r = (14 - (y + 0.5)) / flameHeight(x + 0.5, phase)
				if r <= 1 then
					grid:set(x, y, heat(r))
				end
			end
		end
		grid:outline("o")
		return grid
	end
	for frame = 1, 3 do
		local phase = (frame - 1) * 2.1
		recipe("px_fire_h" .. frame, 1, 24, 14, function()
			return fireGrid(phase):bake(FIRE)
		end)
		recipe("px_fire_v" .. frame, 1, 14, 24, function()
			return fireGrid(phase):transpose():bake(FIRE)
		end)
	end

	-- brimstone: a burning orb (corners), two frames
	for frame = 1, 2 do
		local lean = frame == 1 and -1.4 or 1.4
		recipe("px_brimstone" .. frame, 1, 16, 16, function()
			local grid = Pixel.new(16, 16)
			for y = 0, 15 do
				for x = 0, 15 do
					local px, py = x + 0.5, y + 0.5
					local d = math.sqrt((px - 8) ^ 2 + (py - 10.6) ^ 2)
					local flame = py < 10.6 and Pixel.triangle(px, py, 3.7, 10.4, 12.3, 10.4, 8 + lean, 1.0)
					if d <= 4.4 then
						grid:set(x, y, d < 1.5 and "f5" or (d < 2.8 and "f4" or "f3"))
					elseif flame then
						local t = (10.6 - py) / 9.6
						grid:set(x, y, t < 0.35 and "f3" or (t < 0.7 and "f2" or "f1"))
					end
				end
			end
			grid:outline("o")
			return grid:bake(FIRE)
		end)
	end

	-- magma rock with a glowing seam (health tile)
	recipe("px_magma", 2, 12, 7, function()
		local grid = Pixel.new(12, 7)
		grid:fill(function(x, y)
			return Pixel.ellipse(x, y, 6, 3.4, 5.1, 2.7)
		end, "b")
		grid:shade(kit.BONE_SHADE)
		for _, cell in { { 2, 3, "e" }, { 3, 3, "e" }, { 4, 4, "E" }, { 5, 4, "E" }, { 6, 3, "E" }, { 7, 3, "e" }, { 8, 4, "e" }, { 9, 3, "e" } } do
			grid:set(cell[1], cell[2], cell[3])
		end
		grid:outline("o")
		return grid:bake(CHAR)
	end)

	-- fireball comet pointing up (off-screen marker), two frames
	for frame = 1, 2 do
		local phase = frame == 1 and 0 or 2.4
		recipe("px_fireball" .. frame, 1, 12, 22, function()
			local grid = Pixel.new(12, 22)
			for y = 0, 21 do
				for x = 0, 11 do
					local px, py = x + 0.5, y + 0.5
					local d = math.sqrt((px - 6) ^ 2 + (py - 5.5) ^ 2)
					if d <= 3.7 then
						grid:set(x, y, d < 1.4 and "f5" or (d < 2.6 and "f4" or "f3"))
					elseif py > 5.5 then
						local t = (py - 5.5) / 16
						local half = 3.4 * math.max(0, 1 - t) ^ 1.2
						local center = 6 + math.sin(py * 0.7 + phase) * 0.9
						if math.abs(px - center) <= half then
							grid:set(x, y, t < 0.3 and "f3" or (t < 0.6 and "f2" or "f1"))
						end
					end
				end
			end
			grid:outline("o")
			return grid:bake(FIRE)
		end)
	end
end
