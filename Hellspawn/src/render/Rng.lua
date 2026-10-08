--[[
	Rng
	Deterministic Park–Miller PRNG. Every product stays below 2^53, so results
	are bit-identical on every Luau VM. That matters because generated textures
	are cached on disk and must come out the same on every machine.
]]

local Rng = {}
Rng.__index = Rng

local MOD = 2147483647

function Rng.new(seed)
	seed = math.floor(math.abs(seed or 1)) % MOD
	if seed == 0 then
		seed = 1
	end
	return setmetatable({ _state = seed, _spare = nil }, Rng)
end

-- Uniform float in [0, 1)
function Rng:next()
	self._state = (self._state * 48271) % MOD
	return (self._state - 1) / (MOD - 1)
end

function Rng:range(min, max)
	return min + (max - min) * self:next()
end

function Rng:int(min, max)
	return math.min(max, min + math.floor(self:next() * (max - min + 1)))
end

function Rng:sign()
	return self:next() < 0.5 and -1 or 1
end

-- Standard normal sample (Box–Muller, caches the spare value)
function Rng:gauss()
	local spare = self._spare
	if spare then
		self._spare = nil
		return spare
	end
	local u = math.max(self:next(), 1e-9)
	local v = self:next()
	local mag = math.sqrt(-2 * math.log(u))
	self._spare = mag * math.sin(2 * math.pi * v)
	return mag * math.cos(2 * math.pi * v)
end

function Rng:pick(list)
	return list[self:int(1, #list)]
end

return Rng
