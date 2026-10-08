--[[
	Noise
	Tileable value noise + fractal sums. Used to give generated textures the
	uneven, hand-made edges seen in screen prints and dry brush strokes.
]]

local Noise = {}
Noise.__index = Noise

local floor = math.floor

local function fade(t)
	return t * t * (3 - 2 * t)
end

-- period: lattice cells before the pattern repeats (makes textures tile seamlessly)
function Noise.new(rng, period)
	period = period or 64
	local values = table.create(period * period, 0)
	for i = 1, period * period do
		values[i] = rng:next()
	end
	return setmetatable({ _v = values, _p = period }, Noise)
end

function Noise:_at(ix, iy)
	local p = self._p
	return self._v[(iy % p) * p + (ix % p) + 1]
end

-- 2D value noise in [0, 1]
function Noise:sample(x, y)
	local ix, iy = floor(x), floor(y)
	local fx, fy = fade(x - ix), fade(y - iy)
	local a = self:_at(ix, iy)
	local b = self:_at(ix + 1, iy)
	local c = self:_at(ix, iy + 1)
	local d = self:_at(ix + 1, iy + 1)
	local top = a + (b - a) * fx
	local bottom = c + (d - c) * fx
	return top + (bottom - top) * fy
end

-- 1D convenience
function Noise:line(x)
	return self:sample(x, 0.5)
end

-- fractal brownian motion, normalised to [0, 1]
function Noise:fbm(x, y, octaves)
	local sum, amp, norm, freq = 0, 1, 0, 1
	for _ = 1, octaves or 4 do
		sum += self:sample(x * freq, y * freq) * amp
		norm += amp
		amp *= 0.5
		freq *= 2
	end
	return sum / norm
end

return Noise
