--[[
	Ritual pack: a wicker-man effigy (twine-bound sticks, wicker ribs), a goat
	skull, iron chains, blood candles with flickering flames, rosary beads and
	a rusted nail.
]]

local Pixel = import("render/Pixel")

return function(kit)
	local recipe = kit.recipe
	local BONE, WOOD, IRON, FIRE = kit.Palettes.Bone, kit.Palettes.Wood, kit.Palettes.Iron, kit.Palettes.Fire
	local TWINE_SHADE = kit.merge(kit.BONE_SHADE, { t = { light = "tL", dark = "tD" } })

	-- twine-bound stick (limbs)
	recipe("px_stick", 1, 42, 10, function()
		local grid = Pixel.new(42, 10)
		grid:fill(function(x, y)
			return Pixel.segment(x, y, 3, 5, 39, 5, 2.05) or Pixel.ellipse(x, y, 21, 2.9, 1.7, 1.2)
		end, "b")
		grid:fill(function(x, y)
			return ((x >= 9 and x <= 13) or (x >= 28 and x <= 32)) and math.abs(y - 5) <= 2.7
		end, "t")
		grid:shade(TWINE_SHADE)
		for y = 0, 9 do
			for x = 0, 41 do
				if grid:get(x, y) == "t" and (x + y) % 2 == 0 then
					grid:set(x, y, "tD")
				end
			end
		end
		grid:outline("o")
		return grid:bake(WOOD)
	end)

	-- goat skull with hooked horns
	recipe("px_goat_skull", 1, 22, 26, function()
		local grid = Pixel.new(22, 26)
		local function horn(x, y, flip)
			if flip then
				x = 22 - x
			end
			return kit.nearCurve(x, y, 7.4, 5.8, 2.0, -1.5, 0.9, 6.2, function(t)
				return 1.8 * (1 - t) + 0.5
			end)
		end
		grid:fill(function(x, y)
			return horn(x, y, false) or horn(x, y, true)
		end, "h")
		grid:fill(function(x, y)
			return Pixel.ellipse(x, y, 11, 9, 5.6, 5.2)
				or Pixel.triangle(x, y, 6, 11, 16, 11, 13.4, 22)
				or Pixel.triangle(x, y, 6, 11, 13.4, 22, 8.6, 22)
				or Pixel.ellipse(x, y, 11, 22, 2.4, 1.7)
		end, "b")
		grid:shade(kit.merge(kit.BONE_SHADE, { h = { light = "hL", dark = "hD" } }))
		grid:fill(function(x, y)
			return Pixel.ellipse(x, y, 8.4, 10, 1.5, 2.0) or Pixel.ellipse(x, y, 13.6, 10, 1.5, 2.0)
		end, "k")
		for _, cell in { { 10, 16 }, { 11, 16 }, { 10, 17 }, { 11, 17 }, { 10, 18 } } do
			grid:set(cell[1], cell[2], "k")
		end
		grid:outline("o")
		return grid:bake(kit.merge(BONE, { h = "5a4a3a", hL = "8a7660", hD = "2e2418" }))
	end)

	recipe("px_wicker_ribs", 1, 24, 25, function()
		local grid = kit.ribsGrid()
		grid:shade(kit.BONE_SHADE)
		kit.notchSpine(grid, "t")
		grid:outline("o")
		return grid:bake(WOOD)
	end)

	recipe("px_wicker_pelvis", 1, 26, 17, function()
		local grid = kit.pelvisGrid()
		grid:shade(kit.BONE_SHADE)
		kit.fossa(grid, "s")
		grid:set(12, 6, "t")
		grid:set(13, 6, "t")
		grid:set(12, 8, "t")
		grid:set(13, 8, "t")
		grid:outline("o")
		return grid:bake(WOOD)
	end)

	-- iron chain, seamless along X: a link seen flat, then one edge-on
	local function chainGrid()
		local grid = Pixel.new(16, 8)
		grid.WrapX = true
		grid:fill(function(x, y)
			return kit.ellipseDistance(x, y, 4.5, 4, 3.7, 2.7) <= 0.62 or Pixel.segment(x, y, 8.2, 4, 16.8, 4, 1.05)
		end, "b")
		grid:shade(kit.BONE_SHADE)
		grid:outline("o")
		return grid
	end
	recipe("px_chain_h", 1, 16, 8, function()
		return chainGrid():bake(IRON)
	end)
	recipe("px_chain_v", 1, 8, 16, function()
		return chainGrid():transpose():bake(IRON)
	end)

	-- blood candle, flame leaning left/right across two frames
	for frame = 1, 2 do
		local lean = frame == 1 and -0.8 or 0.8
		recipe("px_candle" .. frame, 1, 10, 20, function()
			local grid = Pixel.new(10, 20)
			grid:fill(function(x, y)
				return x >= 3 and x < 7 and y >= 9
			end, "c")
			for _, drip in { { 2, 9 }, { 2, 10 }, { 2, 11 }, { 7, 10 }, { 7, 11 }, { 7, 12 }, { 7, 13 } } do
				grid:set(drip[1], drip[2], "c")
			end
			grid:shade({ c = { light = "cL", dark = "cD" } })
			grid:set(4, 8, "wk")
			grid:set(4, 7, "wk")
			for y = 0, 7 do
				for x = 0, 9 do
					local px, py = x + 0.5, y + 0.5
					local cx = 4.5 + lean * (1 - py / 7)
					local d = ((px - cx) / 1.7) ^ 2 + ((py - 4.6) / 2.9) ^ 2
					if d <= 1 then
						grid:set(x, y, d < 0.25 and "f5" or (d < 0.6 and "f4" or "f3"))
					end
				end
			end
			grid:outline("o")
			return grid:bake(kit.merge(FIRE, { o = "120406", c = "6e0a16", cL = "a01a2a", cD = "34040a", wk = "1a0f08" }))
		end)
	end

	-- rosary bead on its thread (health tile, tiles vertically)
	recipe("px_bead", 1, 10, 8, function()
		local grid = Pixel.new(10, 8)
		grid:fill(function(x, y)
			return x >= 4 and x < 5
		end, "tr")
		grid:fill(function(x, y)
			return Pixel.ellipse(x, y, 5, 4, 2.9, 2.9)
		end, "b")
		grid:shade(kit.BONE_SHADE)
		grid:outline("o")
		return grid:bake({ o = "0e0204", w = "e45a6a", b = "8a1426", s = "561020", d = "300810", tr = "b8a070" })
	end)

	-- rusted iron nail pointing up (off-screen marker)
	recipe("px_nail", 1, 9, 24, function()
		local grid = Pixel.new(9, 24)
		grid:fill(function(x, y)
			return (x >= 3 and x < 6 and y >= 4 and y < 21)
				or Pixel.triangle(x, y, 4.5, 0, 2.8, 5, 6.2, 5)
				or (x >= 1 and x < 8 and y >= 21)
		end, "b")
		grid:shade(kit.BONE_SHADE)
		for _, spot in { { 4, 9, "r" }, { 3, 13, "R" }, { 5, 16, "r" }, { 4, 17, "R" }, { 2, 22, "r" } } do
			grid:set(spot[1], spot[2], spot[3])
		end
		grid:outline("o")
		return grid:bake(IRON)
	end)
end
