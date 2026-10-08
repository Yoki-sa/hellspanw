--[[
	Embers
	Sparks drifting up through the window like ash over a fire. Pooled image
	labels, a single frame callback, and nothing at all while hidden.
]]

local Util = import("core/Util")
local Anim = import("core/Anim")

local Embers = {}
Embers.__index = Embers

--[[
	container: frame the sparks live in (should be clipped by an ancestor)
	opts.Count (default 22), opts.Color (theme key, default "Accent")
]]
function Embers.new(library, container, opts)
	opts = opts or {}
	local self = setmetatable({}, Embers)
	self.Library = library
	self.Container = container
	self.Enabled = true
	self.Particles = {}
	self._spawnClock = 0

	local count = opts.Count or 22
	local texture = library.Assets:Texture("spark")
	for i = 1, count do
		local image = Util.passive(Util.create("ImageLabel", {
			Name = "Ember" .. i,
			BackgroundTransparency = 1,
			Image = texture,
			ImageTransparency = 1,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(6, 6),
			ZIndex = container.ZIndex,
			Parent = container,
		}))
		library.Theme:Bind(image, { ImageColor3 = opts.Color or "Accent" })
		self.Particles[i] = { image = image, alive = false }
	end

	self._unbind = Anim.frame(function(dt)
		self:_step(dt)
	end)
	return self
end

function Embers:_spawn(p)
	local size = self.Container.AbsoluteSize / (self.Library.Scale or 1)
	if size.X < 10 or size.Y < 10 then
		return
	end
	p.alive = true
	p.x = math.random() * size.X
	p.y = size.Y + 4
	p.speed = 14 + math.random() * 34
	p.life = 0
	p.maxLife = 3 + math.random() * 4.5
	p.phase = math.random() * math.pi * 2
	p.sway = 6 + math.random() * 14
	p.freq = 0.6 + math.random() * 1.4
	p.peak = 0.25 + math.random() * 0.55
	local px = 3 + math.random() * 6
	p.image.Size = UDim2.fromOffset(px, px)
end

function Embers:_step(dt)
	local visible = self.Enabled and self.Container.Visible and self.Container.AbsoluteSize.X > 0
	if not visible then
		if not self._parked then
			self._parked = true
			for _, p in self.Particles do
				p.alive = false
				p.image.ImageTransparency = 1
			end
		end
		return
	end
	self._parked = false

	-- stagger spawns so sparks don't arrive in waves
	self._spawnClock += dt
	local interval = 0.22
	while self._spawnClock > interval do
		self._spawnClock -= interval
		for _, p in self.Particles do
			if not p.alive then
				if math.random() < 0.6 then
					self:_spawn(p)
				end
				break
			end
		end
	end

	for _, p in self.Particles do
		if p.alive then
			p.life += dt
			local t = p.life / p.maxLife
			if t >= 1 then
				p.alive = false
				p.image.ImageTransparency = 1
			else
				p.y -= p.speed * dt
				local x = p.x + math.sin(p.phase + p.life * p.freq) * p.sway
				-- fade in fast, flicker, fade out slow
				local envelope = math.min(t * 6, 1) * (1 - t) ^ 1.4
				local flicker = 0.75 + 0.25 * math.sin(p.life * 23 + p.phase)
				p.image.Position = UDim2.fromOffset(x, p.y)
				p.image.ImageTransparency = 1 - p.peak * envelope * flicker
			end
		end
	end
end

function Embers:SetEnabled(enabled)
	self.Enabled = enabled
end

function Embers:Destroy()
	self._unbind()
	for _, p in self.Particles do
		p.image:Destroy()
	end
	table.clear(self.Particles)
end

return Embers
