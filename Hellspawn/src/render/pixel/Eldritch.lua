--[[
	Eldritch pack: sinew limbs, bloodshot eyes with separate pupils (so they
	can look around), a flesh ribcage with a heart that can beat, writhing
	tentacles (three frames) and a curling tendril.
]]

local Pixel = import("render/Pixel")

return function(kit)
	local recipe = kit.recipe
	local FLESH = kit.merge(kit.Palettes.Flesh, { t = "f2d6c6", tD = "c09a88" })
	local TENT = { o = "12040e", w = "eab4cc", b = "7a2a5a", bL = "a8487e", bD = "4a1438" }
	local EYE = { o = "1e050b", w = "f2e8d8", s = "c8b8a6", d = "8a7868", v = "b0182c" }
	local IRIS = { i = "b8142e", iL = "e8405a", iD = "6a0818", p = "0a0204", h = "ffffff" }
	local TENT_SHADE = { b = { light = "bL", dark = "bD" } }

	-- a muscle spindle with pale tendons and fibres running along it
	recipe("px_sinew", 1, 42, 12, function()
		local grid = Pixel.new(42, 12)
		grid:fill(function(x, y)
			if x < 2 or x > 40 then
				return false
			end
			local half = 0.8 + 3.6 * math.sin(math.pi * (x - 2) / 38) ^ 0.85
			return math.abs(y - 6) <= half
		end, "b")
		grid:fill(function(x, y)
			return grid:get(math.floor(x), math.floor(y)) == "b" and (x < 7 or x > 35)
		end, "t")
		grid:shade(kit.merge(kit.BONE_SHADE, { t = { dark = "tD" } }))
		for y = 0, 11, 2 do
			for x = 0, 41 do
				if grid:get(x, y) == "b" then
					grid:set(x, y, "s")
				end
			end
		end
		grid:outline("o")
		return grid:bake(FLESH)
	end)

	-- bloodshot eyeball, no pupil (pupils are separate so they can move)
	recipe("px_eye", 1, 16, 16, function()
		local grid = Pixel.new(16, 16)
		grid:fill(function(x, y)
			return Pixel.ellipse(x, y, 8, 8, 6.6, 6.6)
		end, "w")
		grid:shade({ w = { dark = "s", deep = "d" } })
		grid:fill(function(x, y)
			return grid:get(math.floor(x), math.floor(y)) ~= false
				and (kit.nearCurve(x, y, 2.2, 6, 4, 7.6, 5.2, 6.8, 0.45)
					or kit.nearCurve(x, y, 13.6, 9.5, 11.8, 9, 10.8, 10.2, 0.45)
					or kit.nearCurve(x, y, 7, 13.8, 7.6, 12, 6.4, 11.2, 0.45))
		end, "v")
		grid:outline("o")
		return grid:bake(EYE)
	end)

	recipe("px_pupil", 1, 8, 8, function()
		local grid = Pixel.new(8, 8)
		grid:fill(function(x, y)
			return Pixel.ellipse(x, y, 4, 4, 3.3, 3.3)
		end, "i")
		grid:shade({ i = { light = "iL", dark = "iD" } })
		grid:fill(function(x, y)
			return Pixel.ellipse(x, y, 4, 4, 0.9, 2.6)
		end, "p")
		grid:set(2, 2, "h")
		grid:outline("p")
		return grid:bake(IRIS)
	end)

	recipe("px_flesh_ribs", 1, 24, 25, function()
		local grid = kit.ribsGrid()
		grid:shade(kit.BONE_SHADE)
		kit.notchSpine(grid, "v")
		grid:outline("o")
		return grid:bake(FLESH)
	end)

	recipe("px_flesh_pelvis", 1, 26, 17, function()
		local grid = kit.pelvisGrid()
		grid:shade(kit.BONE_SHADE)
		kit.fossa(grid, "v")
		grid:outline("o")
		return grid:bake(FLESH)
	end)

	recipe("px_heart", 2, 14, 14, function()
		local grid = Pixel.new(14, 14)
		grid:fill(function(x, y)
			return Pixel.ellipse(x, y, 4.8, 6.2, 3.6, 3.4)
				or Pixel.ellipse(x, y, 9.4, 5.8, 3.4, 3.2)
				or Pixel.triangle(x, y, 1.4, 7, 12.8, 7, 7.2, 13.2)
				or Pixel.segment(x, y, 5.6, 0.8, 5.6, 3.2, 0.9)
				or Pixel.segment(x, y, 8.6, 0.6, 9.2, 3, 0.8)
		end, "b")
		grid:shade(kit.BONE_SHADE)
		grid:fill(function(x, y)
			return grid:get(math.floor(x), math.floor(y)) ~= false and kit.nearCurve(x, y, 4, 9, 7, 8, 9, 11, 0.45)
		end, "v")
		grid:outline("o")
		-- deeper than the flesh so it reads against the ribs
		return grid:bake(kit.merge(FLESH, { w = "ff5a6e", b = "c0142e", s = "7a0a1e", d = "40040e", v = "4a0410" }))
	end)

	-- writhing tentacle with pale suckers, seamless along X, three frames
	local function tentacleGrid(phase)
		local grid = Pixel.new(24, 12)
		grid.WrapX = true
		local function stemY(x)
			return 6 + 1.9 * math.sin(2 * math.pi * x / 24 + phase)
		end
		grid:fill(function(x, y)
			return math.abs(y - stemY(x)) <= 1.55
		end, "b")
		grid:shade(TENT_SHADE)
		for _, sx in { 2, 8, 14, 20 } do
			local y = math.floor(stemY(sx + 0.5) + 1.2)
			grid:set(sx, y, "w")
			grid:set(sx + 1, y, "w")
		end
		grid:outline("o")
		return grid
	end
	for frame = 1, 3 do
		local phase = (frame - 1) * 2.1
		recipe("px_tentacle_h" .. frame, 1, 24, 12, function()
			return tentacleGrid(phase):bake(TENT)
		end)
		recipe("px_tentacle_v" .. frame, 1, 12, 24, function()
			return tentacleGrid(phase):transpose():bake(TENT)
		end)
	end

	-- small eyes for the health column: open, and shut
	recipe("px_eye_open", 1, 12, 10, function()
		local grid = Pixel.new(12, 10)
		grid:fill(function(x, y)
			return Pixel.ellipse(x, y, 6, 5, 5.2, 3.1)
		end, "w")
		grid:fill(function(x, y)
			return Pixel.ellipse(x, y, 6, 5, 1.9, 1.9)
		end, "i")
		grid:fill(function(x, y)
			return Pixel.ellipse(x, y, 6, 5, 0.7, 1.4)
		end, "p")
		grid:outline("o")
		return grid:bake(kit.merge(EYE, IRIS))
	end)

	recipe("px_eye_shut", 1, 12, 10, function()
		local grid = Pixel.new(12, 10)
		grid:fill(function(x, y)
			return kit.nearCurve(x, y, 1, 4.6, 6, 7.4, 11, 4.6, 0.75)
		end, "d")
		for _, lash in { { 3, 7 }, { 6, 8 }, { 9, 7 } } do
			grid:set(lash[1], lash[2], "o")
		end
		grid:outline("o")
		return grid:bake(EYE)
	end)

	-- tendril tip curling upward (off-screen marker), two frames
	for frame = 1, 2 do
		local phase = frame == 1 and 0 or 2.6
		recipe("px_tendril" .. frame, 1, 11, 24, function()
			local grid = Pixel.new(11, 24)
			grid:fill(function(x, y)
				local t = y / 23
				local half = 0.55 + 3.0 * t ^ 1.1
				local center = 5.5 + math.sin(t * 4 + phase) * 1.7 * (1 - t)
				return math.abs(x - center) <= half
			end, "b")
			grid:shade(TENT_SHADE)
			for y = 6, 22, 4 do
				for x = 0, 10 do
					if grid:get(x, y) ~= false and grid:get(x + 1, y) == false then
						grid:set(x, y, "w")
						break
					end
				end
			end
			grid:outline("o")
			return grid:bake(TENT)
		end)
	end
end
