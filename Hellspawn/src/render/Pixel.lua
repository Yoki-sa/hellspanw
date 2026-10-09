--[[
	Pixel
	A tiny pixel-art workshop. Sprites are either hand-authored as ASCII rows
	or built from shapes sampled at low resolution, then finished the way a
	pixel artist would: a dark outline around the silhouette and top-left
	lighting (light on edges facing up/left, shadow on edges facing
	down/right). Rendered in Roblox with ResampleMode = Pixelated.

		local grid = Pixel.new(40, 14)
		grid:fill(function(x, y) return insideBone(x, y) end, "b")
		grid:shade({ b = { light = "w", dark = "s" } })
		grid:outline("o")
		return grid:bake(PALETTE)       -- has :encode() for the asset loader
]]

local Png = import("render/Png")

local Pixel = {}
Pixel.__index = Pixel

local EMPTY = false

function Pixel.new(width, height)
	return setmetatable({
		Width = width,
		Height = height,
		Cells = table.create(width * height, EMPTY),
		WrapX = false,
		WrapY = false,
	}, Pixel)
end

-- rows: array of equal-length strings; legend maps chars to palette keys
-- ("." is always empty)
function Pixel.fromRows(rows, legend)
	local grid = Pixel.new(#rows[1], #rows)
	for y, row in rows do
		assert(#row == grid.Width, "Pixel.fromRows: row " .. y .. " has the wrong width")
		for x = 1, #row do
			local char = string.sub(row, x, x)
			if char ~= "." then
				grid.Cells[(y - 1) * grid.Width + x] = (legend and legend[char]) or char
			end
		end
	end
	return grid
end

function Pixel:_index(x, y)
	local w, h = self.Width, self.Height
	if self.WrapX then
		x %= w
	end
	if self.WrapY then
		y %= h
	end
	if x < 0 or y < 0 or x >= w or y >= h then
		return nil
	end
	return y * w + x + 1
end

function Pixel:get(x, y)
	local index = self:_index(x, y)
	return index and self.Cells[index] or EMPTY
end

function Pixel:set(x, y, key)
	local index = self:_index(x, y)
	if index then
		self.Cells[index] = key
	end
end

-- Paints every cell whose centre satisfies fn(x, y)
function Pixel:fill(fn, key, overwrite)
	for y = 0, self.Height - 1 do
		for x = 0, self.Width - 1 do
			if fn(x + 0.5, y + 0.5) then
				local index = y * self.Width + x + 1
				if overwrite ~= false or self.Cells[index] == EMPTY then
					self.Cells[index] = key
				end
			end
		end
	end
	return self
end

function Pixel:clear(fn)
	return self:fill(fn, EMPTY)
end

--[[
	Top-left lighting. materials = { [key] = { light = key2, dark = key3, deep = key4? } }
	A cell is "exposed" toward a side when that neighbour is empty or
	belongs to a different material.
]]
function Pixel:shade(materials)
	local original = table.clone(self.Cells)
	local function at(x, y)
		local index = self:_index(x, y)
		return index and original[index] or EMPTY
	end
	for y = 0, self.Height - 1 do
		for x = 0, self.Width - 1 do
			local key = original[y * self.Width + x + 1]
			local spec = key and materials[key]
			if spec then
				local up = at(x, y - 1) ~= key
				local left = at(x - 1, y) ~= key
				local down = at(x, y + 1) ~= key
				local right = at(x + 1, y) ~= key
				local result = key
				if (down and right) and spec.deep then
					result = spec.deep
				elseif down or right then
					result = spec.dark or key
				elseif up or left then
					result = spec.light or key
				end
				self.Cells[y * self.Width + x + 1] = result
			end
		end
	end
	return self
end

-- Dark keyline around the silhouette (4-neighbourhood; 8 with `diagonal`)
function Pixel:outline(key, diagonal)
	local original = table.clone(self.Cells)
	local function filled(x, y)
		local index = self:_index(x, y)
		return index ~= nil and original[index] ~= EMPTY
	end
	for y = 0, self.Height - 1 do
		for x = 0, self.Width - 1 do
			if original[y * self.Width + x + 1] == EMPTY then
				local touch = filled(x - 1, y) or filled(x + 1, y) or filled(x, y - 1) or filled(x, y + 1)
				if not touch and diagonal then
					touch = filled(x - 1, y - 1) or filled(x + 1, y - 1) or filled(x - 1, y + 1) or filled(x + 1, y + 1)
				end
				if touch then
					self.Cells[y * self.Width + x + 1] = key
				end
			end
		end
	end
	return self
end

function Pixel:mirrorX()
	local out = Pixel.new(self.Width, self.Height)
	for y = 0, self.Height - 1 do
		for x = 0, self.Width - 1 do
			out.Cells[y * self.Width + x + 1] = self.Cells[y * self.Width + (self.Width - 1 - x) + 1]
		end
	end
	return out
end

function Pixel:transpose()
	local out = Pixel.new(self.Height, self.Width)
	out.WrapX, out.WrapY = self.WrapY, self.WrapX
	for y = 0, self.Height - 1 do
		for x = 0, self.Width - 1 do
			out.Cells[x * out.Width + y + 1] = self.Cells[y * self.Width + x + 1]
		end
	end
	return out
end

-- Copies non-empty cells of `other` onto this grid at (ox, oy)
function Pixel:paste(other, ox, oy)
	for y = 0, other.Height - 1 do
		for x = 0, other.Width - 1 do
			local key = other.Cells[y * other.Width + x + 1]
			if key ~= EMPTY then
				self:set(ox + x, oy + y, key)
			end
		end
	end
	return self
end

local function parseColor(value)
	if type(value) == "table" then
		return value[1], value[2], value[3], value[4] or 255
	end
	local hex = string.gsub(value, "#", "")
	local r = tonumber(string.sub(hex, 1, 2), 16)
	local g = tonumber(string.sub(hex, 3, 4), 16)
	local b = tonumber(string.sub(hex, 5, 6), 16)
	local a = #hex >= 8 and tonumber(string.sub(hex, 7, 8), 16) or 255
	return r, g, b, a
end

-- palette: key -> "RRGGBB[AA]" or {r, g, b, a}
function Pixel:toPixels(palette)
	local w, h = self.Width, self.Height
	local out = buffer.create(w * h * 4)
	local cache = {}
	for i = 1, w * h do
		local key = self.Cells[i]
		if key ~= EMPTY then
			local color = cache[key]
			if not color then
				local spec = palette[key]
				assert(spec, "Pixel: no palette colour for '" .. tostring(key) .. "'")
				color = { parseColor(spec) }
				cache[key] = color
			end
			local off = (i - 1) * 4
			buffer.writeu8(out, off, color[1])
			buffer.writeu8(out, off + 1, color[2])
			buffer.writeu8(out, off + 2, color[3])
			buffer.writeu8(out, off + 3, color[4])
		end
	end
	return out
end

-- Freezes the grid with a palette into something the asset loader can encode
function Pixel:bake(palette)
	local grid = self
	return {
		Width = grid.Width,
		Height = grid.Height,
		encode = function()
			return Png.encode(grid.Width, grid.Height, grid:toPixels(palette))
		end,
	}
end

-- shape helpers (pixel units, sample at cell centres)
function Pixel.ellipse(x, y, cx, cy, rx, ry)
	local dx, dy = (x - cx) / rx, (y - cy) / ry
	return dx * dx + dy * dy <= 1
end

function Pixel.ring(x, y, cx, cy, rx, ry, thickness)
	local dx, dy = (x - cx) / rx, (y - cy) / ry
	local k = math.sqrt(dx * dx + dy * dy)
	return math.abs(k - 1) * math.min(rx, ry) <= thickness
end

function Pixel.segment(x, y, ax, ay, bx, by, radius)
	local pax, pay, bax, bay = x - ax, y - ay, bx - ax, by - ay
	local h = math.clamp((pax * bax + pay * bay) / (bax * bax + bay * bay), 0, 1)
	local dx, dy = pax - bax * h, pay - bay * h
	return dx * dx + dy * dy <= radius * radius
end

function Pixel.triangle(x, y, ax, ay, bx, by, cx, cy)
	local function side(px, py, qx, qy, rx, ry)
		return (px - rx) * (qy - ry) - (qx - rx) * (py - ry)
	end
	local d1 = side(x, y, ax, ay, bx, by)
	local d2 = side(x, y, bx, by, cx, cy)
	local d3 = side(x, y, cx, cy, ax, ay)
	local negative = d1 < 0 or d2 < 0 or d3 < 0
	local positive = d1 > 0 or d2 > 0 or d3 > 0
	return not (negative and positive)
end

return Pixel
