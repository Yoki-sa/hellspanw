--[[
	Canvas
	A tiny software rasteriser. Pixels hold coverage (alpha) plus luminance, so a
	texture is usually a white mask that the UI tints with ImageColor3, but
	sprites can also carry dark regions (outlines, vignettes, grain).

	Storage is two f32 buffers:
		A = alpha        (0 → transparent)
		D = "darkness"   (0 → white). Stored inverted so a fresh, zeroed
		                  buffer is already a white canvas.

	All loops call Canvas.yield (if set) once per row, letting the asset loader
	spread heavy work across frames instead of freezing the client.
]]

local Png = import("render/Png")
local Sdf = import("render/Sdf")

local Canvas = {}
Canvas.__index = Canvas

-- Optional cooperative-yield hook (installed by the asset loader)
Canvas.yield = nil

local readf32, writef32 = buffer.readf32, buffer.writef32
local max, min, floor, clamp, sqrt = math.max, math.min, math.floor, math.clamp, math.sqrt

local function pause()
	local hook = Canvas.yield
	if hook then
		hook()
	end
end

function Canvas.new(width, height)
	return setmetatable({
		Width = width,
		Height = height,
		A = buffer.create(width * height * 4),
		D = buffer.create(width * height * 4),
	}, Canvas)
end

local function blend(A, D, off, sa, sl, mode)
	if mode == "over" then
		if sa <= 0 then
			return
		end
		local da = readf32(A, off)
		local oa = sa + da * (1 - sa)
		if da <= 0 then
			writef32(D, off, 1 - sl)
		elseif oa > 0 then
			local dl = 1 - readf32(D, off)
			writef32(D, off, 1 - (sl * sa + dl * da * (1 - sa)) / oa)
		end
		writef32(A, off, oa)
	elseif mode == "max" then
		if sa > readf32(A, off) then
			writef32(A, off, sa)
			writef32(D, off, 1 - sl)
		end
	elseif mode == "erase" then
		if sa > 0 then
			writef32(A, off, readf32(A, off) * (1 - sa))
		end
	elseif mode == "add" then
		if sa > 0 then
			writef32(A, off, min(1, readf32(A, off) + sa))
		end
	elseif mode == "multiply" then
		writef32(A, off, readf32(A, off) * sa)
	elseif mode == "set" then
		writef32(A, off, sa)
		writef32(D, off, 1 - sl)
	end
end

Canvas.blend = blend

function Canvas:_bounds(bounds)
	local w, h = self.Width, self.Height
	if not bounds then
		return 0, 0, w - 1, h - 1
	end
	local x0 = max(0, floor(bounds[1]))
	local y0 = max(0, floor(bounds[2]))
	local x1 = min(w - 1, floor(bounds[3]))
	local y1 = min(h - 1, floor(bounds[4]))
	return x0, y0, x1, y1
end

--[[
	Evaluates fn(x, y) at every pixel centre inside `bounds`. fn returns
	alpha [, luminance]; returning nil leaves the pixel untouched.
]]
function Canvas:shade(fn, opts)
	opts = opts or {}
	local mode = opts.mode or "over"
	local A, D, w = self.A, self.D, self.Width
	local x0, y0, x1, y1 = self:_bounds(opts.bounds)
	for y = y0, y1 do
		local row = y * w
		for x = x0, x1 do
			local a, l = fn(x + 0.5, y + 0.5)
			if a then
				blend(A, D, (row + x) * 4, a, l or 1, mode)
			end
		end
		pause()
	end
	return self
end

--[[
	Rasterises a signed distance field given in pixel units.
	opts.alpha   opacity multiplier (default 1)
	opts.lum     luminance 0..1 (default 1 = white)
	opts.soft    edge softness in pixels (default 1 = crisp anti-aliasing)
	opts.mode    blend mode (default "over")
	opts.bounds  {x0, y0, x1, y1} pixel rectangle to evaluate
]]
function Canvas:sdf(fn, opts)
	opts = opts or {}
	local alpha = opts.alpha or 1
	local lum = opts.lum or 1
	local soft = opts.soft or 1
	local mode = opts.mode or "over"
	local A, D, w = self.A, self.D, self.Width
	local x0, y0, x1, y1 = self:_bounds(opts.bounds)
	for y = y0, y1 do
		local row = y * w
		local py = y + 0.5
		for x = x0, x1 do
			local d = fn(x + 0.5, py)
			local cov = clamp(0.5 - d / soft, 0, 1)
			if cov > 0 or mode == "set" or mode == "multiply" then
				blend(A, D, (row + x) * 4, cov * alpha, lum, mode)
			end
		end
		pause()
	end
	return self
end

--[[
	Rasterises a distance field expressed in normalised space, mapped onto the
	pixel rectangle rect = {x, y, w, h}. `extent` is the half-range of the
	normalised space visible in the rect (1.2 leaves a small margin around a
	[-1, 1] design).
]]
function Canvas:sdfNormalized(fn, rect, opts)
	opts = opts or {}
	local rx, ry, rw, rh = rect[1], rect[2], rect[3], rect[4]
	local extent = opts.extent or 1.2
	local unit = (2 * extent) / rw
	local alpha = opts.alpha or 1
	local lum = opts.lum or 1
	local soft = opts.soft or 1
	local mode = opts.mode or "over"
	local A, D, w = self.A, self.D, self.Width
	local x0, y0, x1, y1 = self:_bounds({ rx, ry, rx + rw - 1, ry + rh - 1 })
	for y = y0, y1 do
		local row = y * w
		local v = ((y + 0.5 - ry) / rh * 2 - 1) * extent * (rh / rw)
		for x = x0, x1 do
			local u = ((x + 0.5 - rx) / rw * 2 - 1) * extent
			local d = fn(u, v) / unit
			local cov = clamp(0.5 - d / soft, 0, 1)
			if cov > 0 then
				blend(A, D, (row + x) * 4, cov * alpha, lum, mode)
			end
		end
		pause()
	end
	return self
end

-- Round brush dab. hardness 1 = crisp disc, lower values feather out.
function Canvas:stamp(cx, cy, radius, alpha, lum, mode, hardness)
	alpha = alpha or 1
	lum = lum or 1
	mode = mode or "max"
	hardness = hardness or 1
	local feather = max(0.5, radius * (1 - hardness) + 0.5)
	local reach = radius + feather + 1
	local A, D, w, h = self.A, self.D, self.Width, self.Height
	local x0, x1 = max(0, floor(cx - reach)), min(w - 1, floor(cx + reach))
	local y0, y1 = max(0, floor(cy - reach)), min(h - 1, floor(cy + reach))
	for y = y0, y1 do
		local dy = y + 0.5 - cy
		for x = x0, x1 do
			local dx = x + 0.5 - cx
			local d = sqrt(dx * dx + dy * dy) - radius
			local cov = clamp(0.5 - d / feather, 0, 1)
			if cov > 0 then
				blend(A, D, ((y * w) + x) * 4, cov * alpha, lum, mode)
			end
		end
	end
end

-- Stamps a brush along a polyline of {x, y} points (pixel space).
function Canvas:brush(points, radius, alpha, lum, mode, spacing)
	spacing = spacing or 0.5
	for i = 1, #points - 1 do
		local a, b = points[i], points[i + 1]
		local dx, dy = b[1] - a[1], b[2] - a[2]
		local len = sqrt(dx * dx + dy * dy)
		local steps = max(1, math.ceil(len / spacing))
		for s = 0, steps - 1 do
			local t = s / steps
			local r = type(radius) == "function" and radius((i - 1 + t) / (#points - 1)) or radius
			self:stamp(a[1] + dx * t, a[2] + dy * t, r, alpha, lum, mode)
		end
	end
	local last = points[#points]
	local r = type(radius) == "function" and radius(1) or radius
	self:stamp(last[1], last[2], r, alpha, lum, mode)
end

-- Separable box blur on the alpha channel (3 passes ≈ gaussian)
function Canvas:blur(radius, passes)
	radius = floor(radius)
	if radius < 1 then
		return self
	end
	local w, h, A = self.Width, self.Height, self.A
	local tmp = table.create(max(w, h), 0)
	local size = radius * 2 + 1
	for _ = 1, passes or 3 do
		-- horizontal
		for y = 0, h - 1 do
			local row = y * w
			for x = 0, w - 1 do
				tmp[x + 1] = readf32(A, (row + x) * 4)
			end
			local sum = 0
			for k = -radius, radius do
				sum += tmp[clamp(k, 0, w - 1) + 1]
			end
			for x = 0, w - 1 do
				writef32(A, (row + x) * 4, sum / size)
				sum += tmp[min(x + radius + 1, w - 1) + 1] - tmp[max(x - radius, 0) + 1]
			end
			pause()
		end
		-- vertical
		for x = 0, w - 1 do
			for y = 0, h - 1 do
				tmp[y + 1] = readf32(A, (y * w + x) * 4)
			end
			local sum = 0
			for k = -radius, radius do
				sum += tmp[clamp(k, 0, h - 1) + 1]
			end
			for y = 0, h - 1 do
				writef32(A, (y * w + x) * 4, sum / size)
				sum += tmp[min(y + radius + 1, h - 1) + 1] - tmp[max(y - radius, 0) + 1]
			end
		end
		pause()
	end
	return self
end

function Canvas:get(x, y)
	local off = (y * self.Width + x) * 4
	return readf32(self.A, off), 1 - readf32(self.D, off)
end

function Canvas:toPixels()
	local w, h = self.Width, self.Height
	local A, D = self.A, self.D
	local out = buffer.create(w * h * 4)
	local writeu8 = buffer.writeu8
	for i = 0, w * h - 1 do
		local off = i * 4
		local a = clamp(readf32(A, off), 0, 1)
		local l = floor(clamp(1 - readf32(D, off), 0, 1) * 255 + 0.5)
		writeu8(out, off, l)
		writeu8(out, off + 1, l)
		writeu8(out, off + 2, l)
		writeu8(out, off + 3, floor(a * 255 + 0.5))
	end
	return out
end

function Canvas:encode()
	return Png.encode(self.Width, self.Height, self:toPixels())
end

Canvas.Sdf = Sdf

return Canvas
