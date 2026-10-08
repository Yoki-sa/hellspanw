--[[
	Textures
	Recipes for every bitmap the library uses. Nothing is downloaded: each
	texture is painted procedurally, encoded to PNG, cached on disk and loaded
	through getcustomasset. Bump a recipe's `Version` when you change it.

	Most textures are white masks tinted at runtime with ImageColor3, so a
	single file serves every theme.
]]

local Canvas = import("render/Canvas")
local Sdf = import("render/Sdf")
local Rng = import("render/Rng")
local Noise = import("render/Noise")
local Icons = import("render/Icons")

local sqrt, abs, max, min, clamp, floor = math.sqrt, math.abs, math.max, math.min, math.clamp, math.floor
local sin, cos, pi = math.sin, math.cos, math.pi
local smoothstep, gaussian = Sdf.smoothstep, Sdf.gaussian

local Textures = {}

-- Global cache generation; bumping it regenerates every file.
Textures.Generation = 1

-- Geometry the UI needs to slice/tile textures correctly
Textures.Meta = {
	glow = { Size = 64, Pad = 24 },
	glowWide = { Size = 128, Pad = 56 },
	shadow = { Size = 128, Pad = 52 },
	icons = { Cell = 48, Columns = 8 },
	scanlines = { Width = 4, Height = 3 },
	checker = { Size = 16 },
	vine = { Width = 128, Height = 24 },
	noise = { Size = 128, Frames = 3 },
	scratches = { Size = 256 },
	halftone = { Width = 192, Height = 64 },
}

----------------------------------------------------------------------
-- helpers
----------------------------------------------------------------------

-- Paints a normalised-space SDF (x right, y down) onto a square canvas,
-- only evaluating the pixels inside the normalised bbox.
local function painter(canvas, extent)
	local size = canvas.Width
	local unit = 2 * extent / size
	local function toPx(n)
		return (n / extent + 1) * 0.5 * size
	end
	return function(fn, bbox, opts)
		opts = opts or {}
		local bounds = bbox and { toPx(bbox[1]) - 2, toPx(bbox[2]) - 2, toPx(bbox[3]) + 2, toPx(bbox[4]) + 2 }
		canvas:sdf(function(px, py)
			return fn((px / size * 2 - 1) * extent, (py / size * 2 - 1) * extent) / unit
		end, { bounds = bounds, alpha = opts.alpha, lum = opts.lum, mode = opts.mode, soft = opts.soft })
	end, unit, toPx
end

local function bboxOf(verts, pad)
	local x0, y0, x1, y1 = math.huge, math.huge, -math.huge, -math.huge
	for i = 1, #verts, 2 do
		x0, x1 = min(x0, verts[i]), max(x1, verts[i])
		y0, y1 = min(y0, verts[i + 1]), max(y1, verts[i + 1])
	end
	pad = pad or 0
	return { x0 - pad, y0 - pad, x1 + pad, y1 + pad }
end

-- Concave thorn polygon growing from (px, py) along normal (nx, ny)
local function thorn(px, py, nx, ny, length, base, curl, sink)
	local tx, ty = -ny, nx
	local tipx = px + nx * length + tx * curl * length
	local tipy = py + ny * length + ty * curl * length
	local blx, bly = px - tx * base - nx * sink, py - ty * base - ny * sink
	local brx, bry = px + tx * base - nx * sink, py + ty * base - ny * sink
	local pull = base * 0.38
	local mlx, mly = (blx + tipx) * 0.5 + tx * pull, (bly + tipy) * 0.5 + ty * pull
	local mrx, mry = (brx + tipx) * 0.5 - tx * pull, (bry + tipy) * 0.5 - ty * pull
	return { blx, bly, mlx, mly, tipx, tipy, mrx, mry, brx, bry }, tipx, tipy
end

local function quadratic(ax, ay, cx, cy, bx, by, steps, out)
	out = out or {}
	for i = 0, steps do
		local t = i / steps
		local u = 1 - t
		out[#out + 1] = u * u * ax + 2 * u * t * cx + t * t * bx
		out[#out + 1] = u * u * ay + 2 * u * t * cy + t * t * by
	end
	return out
end

-- Glow falloff shared by the neon textures: a hot inner edge plus a wide bloom
local function neon(d, pad)
	return 0.62 * gaussian(d, pad * 0.12) + 0.38 * gaussian(d, pad * 0.38)
end

----------------------------------------------------------------------
-- recipes
----------------------------------------------------------------------

local Recipes = {}
Textures.Recipes = Recipes

local function recipe(name, version, build)
	Recipes[#Recipes + 1] = { Name = name, Version = version, Build = build }
end

-- Hollow neon halo for 9-slicing around any rectangle. Transparent inside, so
-- it can sit above or below its target without tinting it.
local function buildGlow(size, pad, radius)
	local c = Canvas.new(size, size)
	local half = size / 2
	local core = half - pad
	c:shade(function(x, y)
		local d = Sdf.box(x, y, half, half, core, core, radius)
		if d <= 0 then
			return 0
		end
		return neon(d, pad)
	end)
	return c
end

recipe("glow", 2, function()
	local m = Textures.Meta.glow
	return buildGlow(m.Size, m.Pad, 4)
end)

recipe("glowWide", 2, function()
	local m = Textures.Meta.glowWide
	return buildGlow(m.Size, m.Pad, 6)
end)

-- Solid-core soft drop shadow
recipe("shadow", 1, function()
	local m = Textures.Meta.shadow
	local c = Canvas.new(m.Size, m.Size)
	local half = m.Size / 2
	local core = half - m.Pad
	c:shade(function(x, y)
		local d = Sdf.box(x, y, half, half, core, core, 8)
		if d <= 0 then
			return 1, 0
		end
		return gaussian(d, m.Pad * 0.42), 0
	end)
	return c
end)

-- Radial bloom (stretched behind titles, cursor, logo)
recipe("bloom", 1, function()
	local c = Canvas.new(64, 64)
	c:shade(function(x, y)
		local dx, dy = x - 32, y - 32
		local r = sqrt(dx * dx + dy * dy)
		return gaussian(r, 9) * 0.7 + gaussian(r, 16) * 0.3 - (r > 31 and 1 or 0)
	end)
	return c
end)

-- Small hot particle (embers, slider sparks)
recipe("spark", 1, function()
	local c = Canvas.new(32, 32)
	c:shade(function(x, y)
		local dx, dy = x - 16, y - 16
		local r = sqrt(dx * dx + dy * dy)
		return clamp(gaussian(r, 2.2) + gaussian(r, 6) * 0.45, 0, 1)
	end)
	return c
end)

recipe("circle", 1, function()
	local c = Canvas.new(64, 64)
	c:sdf(function(x, y)
		return Sdf.circle(x, y, 32, 32, 30)
	end)
	return c
end)

recipe("ring", 1, function()
	local c = Canvas.new(64, 64)
	c:sdf(function(x, y)
		return abs(Sdf.circle(x, y, 32, 32, 28)) - 2.4
	end)
	return c
end)

-- Horizontal light beam: underlines, scan sweeps, slider heads
recipe("beam", 1, function()
	local c = Canvas.new(128, 32)
	c:shade(function(x, y)
		local u = x / 128
		local fadeX = sin(u * pi) ^ 0.7
		return (gaussian(y - 16, 2) * 0.75 + gaussian(y - 16, 6) * 0.35) * fadeX
	end)
	return c
end)

-- Film grain frames (cycled for animated grain)
for frame = 1, Textures.Meta.noise.Frames do
	recipe("noise" .. frame, 1, function()
		local size = Textures.Meta.noise.Size
		local c = Canvas.new(size, size)
		local rng = Rng.new(9001 + frame * 7919)
		c:shade(function()
			local a = rng:next() ^ 2.6
			return a, rng:next() < 0.55 and 1 or 0
		end, { mode = "set" })
		return c
	end)
end

-- Scratched celluloid: hairline scratches, dust and the odd hair
recipe("scratches", 1, function()
	local size = Textures.Meta.scratches.Size
	local c = Canvas.new(size, size)
	local rng = Rng.new(1313)

	local function wrapped(points, radius, alpha, lum)
		local x0, x1, y0, y1 = math.huge, -math.huge, math.huge, -math.huge
		for _, p in points do
			x0, x1 = min(x0, p[1]), max(x1, p[1])
			y0, y1 = min(y0, p[2]), max(y1, p[2])
		end
		for ox = -1, 1 do
			for oy = -1, 1 do
				local sx, sy = ox * size, oy * size
				if x1 + sx >= -2 and x0 + sx <= size + 2 and y1 + sy >= -2 and y0 + sy <= size + 2 then
					local shifted = table.create(#points)
					for i, p in points do
						shifted[i] = { p[1] + sx, p[2] + sy }
					end
					c:brush(shifted, radius, alpha, lum, "max", 0.6)
				end
			end
		end
	end

	-- long vertical-ish scratches
	for _ = 1, 16 do
		local x, y = rng:range(0, size), rng:range(0, size)
		local len = rng:range(size * 0.2, size * 0.75)
		local ang = math.rad(90 + rng:range(-14, 14))
		local bend = rng:range(-0.12, 0.12) * len
		local pts = {}
		for s = 0, 10 do
			local t = s / 10
			pts[#pts + 1] = {
				x + cos(ang) * len * t + sin(t * pi) * bend,
				y + sin(ang) * len * t,
			}
		end
		local r0 = rng:range(0.3, 0.65)
		wrapped(pts, function(t)
			return r0 * (0.35 + 0.65 * sin(t * pi))
		end, rng:range(0.3, 0.8), 1)
	end

	-- short nicks in random directions
	for _ = 1, 26 do
		local x, y = rng:range(0, size), rng:range(0, size)
		local len = rng:range(4, 18)
		local ang = rng:range(0, 2 * pi)
		wrapped({ { x, y }, { x + cos(ang) * len, y + sin(ang) * len } }, rng:range(0.3, 0.55), rng:range(0.25, 0.7), 1)
	end

	-- hairs: smooth random walks
	for _ = 1, 3 do
		local x, y = rng:range(0, size), rng:range(0, size)
		local ang = rng:range(0, 2 * pi)
		local pts = { { x, y } }
		for _ = 1, 36 do
			ang += rng:range(-0.35, 0.35)
			x += cos(ang) * 2.2
			y += sin(ang) * 2.2
			pts[#pts + 1] = { x, y }
		end
		wrapped(pts, 0.42, 0.55, 0)
	end

	-- dust
	for _ = 1, 300 do
		c:stamp(rng:range(0, size), rng:range(0, size), rng:range(0.25, 1.4), rng:range(0.2, 0.85), rng:next() < 0.7 and 1 or 0, "max", rng:range(0.3, 1))
	end
	return c
end)

-- Print-style halftone ramp (big dots → nothing)
recipe("halftone", 1, function()
	local m = Textures.Meta.halftone
	local c = Canvas.new(m.Width, m.Height)
	local cell = 6
	local k = 0.70710678
	c:shade(function(x, y)
		local intensity = (1 - x / m.Width) ^ 1.25
		local rx, ry = (x + y) * k, (y - x) * k
		local gx = (rx / cell) % 1 - 0.5
		local gy = (ry / cell) % 1 - 0.5
		local d = sqrt(gx * gx + gy * gy) * cell
		local r = cell * 0.66 * sqrt(intensity)
		return clamp(r - d + 0.5, 0, 1)
	end)
	return c
end)

-- Corner darkening
recipe("vignette", 1, function()
	local c = Canvas.new(128, 128)
	c:shade(function(x, y)
		local u, v = x / 64 - 1, y / 64 - 1
		local r = sqrt(u * u * 0.85 + v * v * 1.15)
		return smoothstep(0.42, 1.3, r) ^ 1.25, 0
	end)
	return c
end)

recipe("scanlines", 1, function()
	local m = Textures.Meta.scanlines
	local c = Canvas.new(m.Width, m.Height)
	c:shade(function(_, y)
		return y < 1 and 1 or 0, 0
	end, { mode = "set" })
	return c
end)

recipe("checker", 1, function()
	local size = Textures.Meta.checker.Size
	local c = Canvas.new(size, size)
	local half = size / 2
	c:shade(function(x, y)
		local odd = (floor(x / half) + floor(y / half)) % 2 == 1
		return 1, odd and 0.42 or 0.26
	end, { mode = "set" })
	return c
end)

-- Tileable thorn vine (crown-of-thorns divider)
recipe("vine", 1, function()
	local m = Textures.Meta.vine
	local c = Canvas.new(m.Width, m.Height)
	local mid = m.Height / 2
	local amp, period = 3.2, 64
	local function curveY(x)
		return mid + amp * sin(2 * pi * x / period)
	end
	local function slope(x)
		return amp * 2 * pi / period * cos(2 * pi * x / period)
	end
	-- stem: vertical distance corrected by slope ≈ true distance
	c:shade(function(x, y)
		local d = abs(y - curveY(x)) / sqrt(1 + slope(x) ^ 2) - 0.75
		return clamp(0.5 - d, 0, 1)
	end)
	-- thorns, alternating sides
	local count = 8
	for i = 0, count - 1 do
		local x = (i + 0.5) * (m.Width / count)
		local y = curveY(x)
		local s = slope(x)
		local len = sqrt(1 + s * s)
		local side = (i % 2 == 0) and -1 or 1
		local nx, ny = -s / len * side, 1 / len * side
		local poly = thorn(x, y, nx, ny, 6.5, 1.6, 0.35 * side, 0.6)
		local bounds = bboxOf(poly, 2)
		c:sdf(function(px, py)
			return Sdf.polygon(px, py, poly)
		end, { bounds = bounds })
	end
	return c
end)

-- A single curved spike (pointing up), used for decorative crowns
recipe("spike", 1, function()
	local c = Canvas.new(24, 72)
	local poly = quadratic(1.5, 72, 9.5, 36, 12.5, 1, 10)
	local right = quadratic(12.5, 1, 14.5, 36, 22.5, 72, 10)
	for i = 3, #right do
		poly[#poly + 1] = right[i]
	end
	c:sdf(function(x, y)
		return Sdf.polygon(x, y, poly)
	end)
	-- subtle inner highlight line for volume
	c:sdf(function(x, y)
		return Sdf.segment(x, y, 12.2, 8, 11, 66, 0.35)
	end, { alpha = 0.35, lum = 0.55 })
	return c
end)

-- Dry-brush smear for the active tab
recipe("smear", 1, function()
	local w, h = 256, 40
	local c = Canvas.new(w, h)
	local rng = Rng.new(4242)
	local noise = Noise.new(rng, 32)
	local rows = table.create(h)
	for y = 1, h do
		rows[y] = { reach = rng:range(0.5, 1.0), density = rng:range(0.55, 1) }
	end
	c:shade(function(x, y)
		local u, v = x / w, y / h
		local edge = 0.1 + 0.1 * noise:sample(u * 9, 3.5)
		local edgeB = 0.1 + 0.1 * noise:sample(u * 9, 17.5)
		local band = smoothstep(0, edge, v) * (1 - smoothstep(1 - edgeB, 1, v))
		local row = rows[floor(y) + 1]
		local dry = 1 - smoothstep(row.reach * 0.55, row.reach, u)
		local start = smoothstep(0, 0.035, u)
		local bristle = 0.65 + 0.35 * noise:fbm(u * 24, v * 2.5, 3)
		return clamp(band * dry * start * row.density * bristle * 1.15, 0, 1)
	end)
	return c
end)

-- Custom cursor: white arrow with a black keyline
recipe("cursor", 1, function()
	local c = Canvas.new(32, 32)
	local arrow = { 3, 2, 3, 24.5, 8.8, 19.4, 12.6, 28.2, 16.6, 26.4, 12.9, 17.8, 20.5, 17.8 }
	c:sdf(function(x, y)
		return Sdf.polygon(x, y, arrow) - 1.5
	end, { lum = 0 })
	c:sdf(function(x, y)
		return Sdf.polygon(x, y, arrow)
	end, { lum = 1 })
	return c
end)

-- The thorn eye sigil (library emblem)
local function buildLogo(size)
	local c = Canvas.new(size, size)
	local paint, unit, toPx = painter(c, 1.1)
	local rng = Rng.new(666)
	local W, H = 0.8, 0.42
	local weight = max(1, 230 / size)
	local detailed = size >= 128

	-- sketch passes of the lens outline
	local passes = detailed and 6 or 2
	for i = 1, passes do
		local w = W + (i == 1 and 0 or rng:range(-0.035, 0.035))
		local h = H + (i == 1 and 0 or rng:range(-0.04, 0.04))
		local ox = i == 1 and 0 or rng:range(-0.02, 0.02)
		local oy = i == 1 and 0 or rng:range(-0.025, 0.025)
		local rot = i == 1 and 0 or rng:range(-0.045, 0.045)
		local t = (i == 1 and 0.014 or rng:range(0.006, 0.012)) * weight
		local alpha = i == 1 and 1 or rng:range(0.45, 0.85)
		paint(function(u, v)
			local x, y = Sdf.rotate(u - ox, v - oy, rot)
			return abs(Sdf.vesica(x, y, 0, 0, w, h)) - t
		end, { -w - 0.12, -h - 0.12, w + 0.12, h + 0.12 }, { alpha = alpha })
	end

	-- swooping under-lid that curls up on the right
	if true then
		local k = (W * W - H * H) / (2 * H)
		local R = k + H
		local pts = {}
		for i = 0, 22 do
			local t = i / 22
			local x = -0.62 + t * 1.55
			local y
			if x <= W - 0.02 then
				y = -k + sqrt(max(R * R - x * x, 0)) + 0.13
			else
				local over = x - (W - 0.02)
				y = 0.13 - over * 1.4
			end
			pts[#pts + 1] = { toPx(x), toPx(y) }
		end
		local thick = 0.012 * weight / unit
		c:brush(pts, function(t)
			return thick * (0.25 + sin(t * pi) * 0.95)
		end, 0.9, 1, "max", 0.5)
	end

	-- thorns around the lid
	local k = (W * W - H * H) / (2 * H)
	local R = k + H
	local spots = {}
	for _, x in { -0.6, -0.33, -0.05, 0.24, 0.52 } do
		local s = sqrt(R * R - x * x)
		spots[#spots + 1] = { x, k - s, x / R, -s / R, 0.2 + 0.1 * (1 - abs(x)) }
	end
	for _, x in { -0.4, -0.08, 0.28 } do
		local s = sqrt(R * R - x * x)
		spots[#spots + 1] = { x, -k + s + 0.13, x / R, s / R, 0.17 }
	end
	spots[#spots + 1] = { -W, 0, -1, 0, 0.24 }
	spots[#spots + 1] = { W, 0, 1, -0.15, 0.2 }

	for _, spot in spots do
		local len = spot[5] + rng:range(-0.03, 0.05)
		local curl = rng:range(-0.3, 0.3)
		local base = 0.055 + rng:range(0, 0.02)
		local poly, tipx, tipy = thorn(spot[1], spot[2], spot[3], spot[4], len, base, curl, 0.02)
		local bbox = bboxOf(poly, 0.03)
		if detailed then
			-- webbed fill + fan of strokes, like ink hatching
			paint(function(u, v)
				return Sdf.polygon(u, v, poly)
			end, bbox, { alpha = 0.55 })
			paint(function(u, v)
				return abs(Sdf.polygon(u, v, poly)) - 0.006 * weight
			end, bbox, { alpha = 0.9 })
			for f = 1, 3 do
				local t = f / 4
				local bx = poly[1] + (poly[9] - poly[1]) * t
				local by = poly[2] + (poly[10] - poly[2]) * t
				paint(function(u, v)
					return Sdf.segment(u, v, bx, by, tipx, tipy, 0.004 * weight)
				end, bbox, { alpha = 0.7 })
			end
		else
			paint(function(u, v)
				return Sdf.polygon(u, v, poly)
			end, bbox)
		end
	end

	-- four-point star pupil
	local star = {
		0, -0.4, 0.028, -0.07, 0.07, -0.028, 0.24, 0,
		0.07, 0.028, 0.028, 0.07, 0, 0.42, -0.028, 0.07,
		-0.07, 0.028, -0.24, 0, -0.07, -0.028, -0.028, -0.07,
	}
	paint(function(u, v)
		return Sdf.polygon(u, v, star) - 0.004 * weight
	end, bboxOf(star, 0.04))
	if detailed then
		paint(function(u, v)
			return abs(Sdf.box(u, v, 0, 0, 0.045, 0.045, 0.0)) - 0.006
		end, { -0.08, -0.08, 0.08, 0.08 }, { alpha = 0.8 })
		-- two distant pinprick eyes above
		paint(function(u, v)
			return min(Sdf.circle(u, v, -0.05, -0.9, 0.012), Sdf.circle(u, v, 0.05, -0.9, 0.012))
		end, { -0.1, -0.95, 0.1, -0.85 }, { alpha = 0.8 })
	end
	return c
end

recipe("logo", 4, function()
	return buildLogo(96)
end)

recipe("logoLarge", 3, function()
	return buildLogo(256)
end)

-- Icon atlas
recipe("icons", 3, function()
	local meta = Textures.Meta.icons
	local cell, cols = meta.Cell, meta.Columns
	local rows = math.ceil(#Icons.Order / cols)
	local c = Canvas.new(cell * cols, cell * rows)
	for index, name in Icons.Order do
		local col = (index - 1) % cols
		local row = (index - 1) // cols
		c:sdfNormalized(Icons.Shapes[name], { col * cell, row * cell, cell, cell }, { extent = 1.2 })
	end
	return c
end)

-- Where an icon lives inside the atlas
function Textures.iconRect(name)
	local meta = Textures.Meta.icons
	local index = table.find(Icons.Order, name)
	if not index then
		return nil
	end
	local col = (index - 1) % meta.Columns
	local row = (index - 1) // meta.Columns
	return col * meta.Cell, row * meta.Cell, meta.Cell
end

function Textures.find(name)
	for _, entry in Recipes do
		if entry.Name == name then
			return entry
		end
	end
	return nil
end

return Textures
