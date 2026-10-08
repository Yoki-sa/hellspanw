--[[
	Sdf
	Signed distance primitives used to rasterise icons, sigils and sprites.
	Negative = inside, positive = outside. Units are whatever space the caller
	works in (normalised [-1, 1] for icons, pixels for sprites).

	Polygon / lens formulas follow Inigo Quilez's well-known derivations.
]]

local Sdf = {}

local sqrt, abs, max, min, clamp = math.sqrt, math.abs, math.max, math.min, math.clamp
local cos, sin, atan2, floor, exp = math.cos, math.sin, math.atan2, math.floor, math.exp

function Sdf.circle(x, y, cx, cy, r)
	local dx, dy = x - cx, y - cy
	return sqrt(dx * dx + dy * dy) - r
end

function Sdf.ellipse(x, y, cx, cy, rx, ry)
	-- cheap approximation, good enough for anti-aliased icon work
	local dx, dy = (x - cx) / rx, (y - cy) / ry
	local k = sqrt(dx * dx + dy * dy)
	return (k - 1) * min(rx, ry)
end

function Sdf.box(x, y, cx, cy, hw, hh, r)
	r = r or 0
	local qx = abs(x - cx) - hw + r
	local qy = abs(y - cy) - hh + r
	local ox, oy = max(qx, 0), max(qy, 0)
	return sqrt(ox * ox + oy * oy) + min(max(qx, qy), 0) - r
end

function Sdf.segment(x, y, ax, ay, bx, by, r)
	local pax, pay = x - ax, y - ay
	local bax, bay = bx - ax, by - ay
	local denom = bax * bax + bay * bay
	local h = denom > 0 and clamp((pax * bax + pay * bay) / denom, 0, 1) or 0
	local dx, dy = pax - bax * h, pay - bay * h
	return sqrt(dx * dx + dy * dy) - (r or 0)
end

-- pts: flat array {x1, y1, x2, y2, ...}; open polyline with radius r
function Sdf.polyline(x, y, pts, r)
	local d = math.huge
	for i = 1, #pts - 3, 2 do
		local s = Sdf.segment(x, y, pts[i], pts[i + 1], pts[i + 2], pts[i + 3], 0)
		if s < d then
			d = s
		end
	end
	return d - (r or 0)
end

-- v: flat array of vertices, any winding, may be concave
function Sdf.polygon(x, y, v)
	local n = #v // 2
	local dx, dy = x - v[1], y - v[2]
	local d = dx * dx + dy * dy
	local s = 1
	local j = n
	for i = 1, n do
		local vix, viy = v[2 * i - 1], v[2 * i]
		local vjx, vjy = v[2 * j - 1], v[2 * j]
		local ex, ey = vjx - vix, vjy - viy
		local wx, wy = x - vix, y - viy
		local ee = ex * ex + ey * ey
		local h = ee > 0 and clamp((wx * ex + wy * ey) / ee, 0, 1) or 0
		local bx, by = wx - ex * h, wy - ey * h
		local bb = bx * bx + by * by
		if bb < d then
			d = bb
		end
		local c1 = y >= viy
		local c2 = y < vjy
		local c3 = ex * wy > ey * wx
		if (c1 and c2 and c3) or (not c1 and not c2 and not c3) then
			s = -s
		end
		j = i
	end
	return s * sqrt(d)
end

-- Almond / lens shape pointed along X. w = half width, h = half height (h < w)
function Sdf.vesica(x, y, cx, cy, w, h)
	local k = (w * w - h * h) / (2 * h)
	local r = k + h
	return max(Sdf.circle(x, y, cx, cy + k, r), Sdf.circle(x, y, cx, cy - k, r))
end

-- Lens pointed along Y
function Sdf.vesicaV(x, y, cx, cy, w, h)
	return Sdf.vesica(y, x, cy, cx, h, w)
end

function Sdf.ring(d, thickness)
	return abs(d) - thickness
end

function Sdf.union(...)
	return min(...)
end

function Sdf.intersect(...)
	return max(...)
end

function Sdf.subtract(a, b)
	return max(a, -b)
end

-- polynomial smooth min
function Sdf.smin(a, b, k)
	local h = clamp(0.5 + 0.5 * (b - a) / k, 0, 1)
	return b + (a - b) * h - k * h * (1 - h)
end

function Sdf.rotate(x, y, angle)
	local c, s = cos(angle), sin(angle)
	return x * c - y * s, x * s + y * c
end

-- Folds the plane into one of `count` angular sectors, returning local coords
-- where the sector is centred on the +X axis.
function Sdf.polar(x, y, count, offset)
	local step = 2 * math.pi / count
	local a = atan2(y, x) - (offset or 0)
	local sector = floor(a / step + 0.5)
	return Sdf.rotate(x, y, -(sector * step + (offset or 0)))
end

-- Anti-aliased coverage from a distance and the size of one pixel in the same units
function Sdf.coverage(d, pixel)
	return clamp(0.5 - d / pixel, 0, 1)
end

function Sdf.smoothstep(a, b, x)
	local t = clamp((x - a) / (b - a), 0, 1)
	return t * t * (3 - 2 * t)
end

function Sdf.gaussian(d, sigma)
	return exp(-(d * d) / (2 * sigma * sigma))
end

return Sdf
