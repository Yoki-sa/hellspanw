--[[
	Anim
	TweenService helpers plus a shared frame ticker.

	Anim.tween(instance, props, time?, style?, direction?)
	Anim.frame(fn) -> unbind     -- fn(dt, clock) every rendered frame
	Anim.Speed                   -- global multiplier; 0 disables tweening
]]

local Env = import("core/Env")

local Anim = {}

local TweenService = Env.service("TweenService")
local RunService = Env.service("RunService")

Anim.Speed = 1

local infoCache = {}

function Anim.info(time, style, direction)
	style = style or Enum.EasingStyle.Quint
	direction = direction or Enum.EasingDirection.Out
	local key = string.format("%.3f|%s|%s", time, style.Name, direction.Name)
	local info = infoCache[key]
	if not info then
		info = TweenInfo.new(time, style, direction)
		infoCache[key] = info
	end
	return info
end

function Anim.tween(instance, props, time, style, direction)
	time = time or 0.22
	local speed = Anim.Speed
	if speed <= 0 or time <= 0 then
		for key, value in props do
			instance[key] = value
		end
		return nil
	end
	local tween = TweenService:Create(instance, Anim.info(time / speed, style, direction), props)
	tween:Play()
	return tween
end

function Anim.fast(instance, props)
	return Anim.tween(instance, props, 0.12, Enum.EasingStyle.Quad)
end

function Anim.slow(instance, props)
	return Anim.tween(instance, props, 0.45, Enum.EasingStyle.Quint)
end

function Anim.set(instance, props)
	for key, value in props do
		instance[key] = value
	end
end

-- Shared per-frame ticker -------------------------------------------------

local callbacks = {}
local tickConnection = nil

local function tick(dt)
	local now = os.clock()
	for _, entry in table.clone(callbacks) do
		if entry.alive then
			local ok, err = pcall(entry.fn, dt, now)
			if not ok then
				entry.alive = false
				warn("[Hellspawn] frame callback disabled after error: " .. tostring(err))
			end
		end
	end
	for i = #callbacks, 1, -1 do
		if not callbacks[i].alive then
			table.remove(callbacks, i)
		end
	end
	if #callbacks == 0 and tickConnection then
		tickConnection:Disconnect()
		tickConnection = nil
	end
end

function Anim.frame(fn)
	local entry = { fn = fn, alive = true }
	table.insert(callbacks, entry)
	if not tickConnection then
		tickConnection = RunService.RenderStepped:Connect(tick)
	end
	return function()
		entry.alive = false
	end
end

-- Drops every frame callback (used on unload)
function Anim.stopAll()
	for _, entry in callbacks do
		entry.alive = false
	end
	table.clear(callbacks)
	if tickConnection then
		tickConnection:Disconnect()
		tickConnection = nil
	end
end

-- Runs fn(alpha) from 0 → 1 over `time` seconds with an easing curve.
-- Returns a cancel function.
function Anim.run(time, fn, easing, onDone)
	local start = os.clock()
	local unbind
	unbind = Anim.frame(function()
		local alpha = math.clamp((os.clock() - start) / math.max(time, 1e-3), 0, 1)
		fn(easing and easing(alpha) or alpha)
		if alpha >= 1 then
			unbind()
			if onDone then
				onDone()
			end
		end
	end)
	return unbind
end

Anim.ease = {
	outQuint = function(t)
		return 1 - (1 - t) ^ 5
	end,
	outCubic = function(t)
		return 1 - (1 - t) ^ 3
	end,
	inOutSine = function(t)
		return -(math.cos(math.pi * t) - 1) / 2
	end,
	outBack = function(t)
		local c1 = 1.70158
		local c3 = c1 + 1
		return 1 + c3 * (t - 1) ^ 3 + c1 * (t - 1) ^ 2
	end,
}

return Anim
