--[[
	Motion
	Physically based springs for anything that should feel alive: the tab
	indicator, smooth window dragging, slider fills, notification stacks.

	A single RenderStepped connection drives every active spring; springs that
	come to rest unregister themselves, so idle UI costs nothing.

		local spring = Motion.spring(0, { Frequency = 5, Damping = 0.8 }, function(value)
			frame.Position = UDim2.fromOffset(value, 0)
		end)
		spring:SetTarget(120)
]]

local Env = import("core/Env")

local Motion = {}

local RunService = Env.service("RunService")

local active = {}
local connection = nil
local SUBSTEP = 1 / 240

local function magnitude(value)
	if type(value) == "number" then
		return math.abs(value)
	end
	return value.Magnitude
end

local function zeroLike(value)
	if type(value) == "number" then
		return 0
	end
	return value * 0
end

local function step(dt)
	dt = math.min(dt, 0.1)
	-- snapshot: callbacks may start or stop other springs mid-iteration
	for spring in table.clone(active) do
		if active[spring] then
			spring:_step(dt)
		end
	end
	if next(active) == nil and connection then
		connection:Disconnect()
		connection = nil
	end
end

local function track(spring)
	active[spring] = true
	if not connection then
		connection = RunService.RenderStepped:Connect(step)
	end
end

local Spring = {}
Spring.__index = Spring

--[[
	value      initial value (number or Vector2/Vector3)
	opts       Frequency (Hz, default 4), Damping (ratio, default 1),
	           Epsilon (rest threshold, default 0.001)
	onUpdate   called with the new value each frame while moving
]]
function Motion.spring(value, opts, onUpdate)
	opts = opts or {}
	return setmetatable({
		Position = value,
		Velocity = zeroLike(value),
		Target = value,
		Frequency = opts.Frequency or 4,
		Damping = opts.Damping or 1,
		Epsilon = opts.Epsilon or 0.001,
		_onUpdate = onUpdate,
		_destroyed = false,
	}, Spring)
end

function Spring:_step(dt)
	local w = self.Frequency * 2 * math.pi
	local zeta = self.Damping
	local steps = math.max(1, math.ceil(dt / SUBSTEP))
	local h = dt / steps
	local p, v, t = self.Position, self.Velocity, self.Target
	for _ = 1, steps do
		local accel = (t - p) * (w * w) - v * (2 * zeta * w)
		v += accel * h
		p += v * h
	end
	self.Position, self.Velocity = p, v
	if magnitude(t - p) < self.Epsilon and magnitude(v) < self.Epsilon * 10 then
		self.Position = t
		self.Velocity = zeroLike(t)
		active[self] = nil
	end
	if self._onUpdate then
		self._onUpdate(self.Position)
	end
end

function Spring:SetTarget(target, instant)
	if self._destroyed then
		return
	end
	self.Target = target
	if instant then
		self.Position = target
		self.Velocity = zeroLike(target)
		active[self] = nil
		if self._onUpdate then
			self._onUpdate(target)
		end
		return
	end
	track(self)
end

-- Kick the spring with extra velocity (great for "bounce" feedback)
function Spring:Impulse(velocity)
	self.Velocity += velocity
	track(self)
end

function Spring:IsMoving()
	return active[self] == true
end

function Spring:Destroy()
	self._destroyed = true
	active[self] = nil
end

Motion.Spring = Spring

-- Halts every spring (used on unload)
function Motion.stopAll()
	table.clear(active)
	if connection then
		connection:Disconnect()
		connection = nil
	end
end

return Motion
