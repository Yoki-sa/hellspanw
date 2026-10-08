--[[
	Glow
	Neon edges are drawn with Roblox's native UIShadow: two stacked shadows
	per element in the accent colour, a tight hot core plus a wide soft bloom.
	UIShadow follows UICorner and rotation, isn't a GuiObject (so it never
	disturbs AutomaticSize or layouts), and always renders *below* its parent.

	On clients without UIShadow, a 9-sliced glow image is used instead.

	Every glow has a "strength" (0..1). Visible opacity is
	strength × the library's glow intensity, so one setting dims every neon
	edge at once.

		local glow = Glow.attach(library, frame, { Spread = 12, Strength = 0.5 })
		Glow.set(glow, 0.8)         -- animate strength
		Glow.flash(glow, 1, 0.4)    -- quick burst that settles back
]]

local Util = import("core/Util")
local Anim = import("core/Anim")

local Glow = {}

local registry = {} -- [handle] = true

local native = nil
function Glow.native()
	if native == nil then
		local ok, shadow = pcall(Instance.new, "UIShadow")
		native = ok and shadow ~= nil
		if ok and shadow then
			shadow:Destroy()
		end
	end
	return native
end

-- core + bloom; blur/spread are fractions of the requested spread
local LAYERS = {
	{ Blur = 0.3, Grow = 0.08, Weight = 0.9 },
	{ Blur = 1.0, Grow = 0.35, Weight = 0.55 },
}

local Handle = {}
Handle.__index = Handle

local function intensity(library)
	local settings = library.Settings
	return settings.Glow and (settings.GlowIntensity or 1) or 0
end

function Handle:_opacity()
	return math.clamp(self.Strength * intensity(self.Library), 0, 1)
end

function Handle:_apply(time, override)
	local opacity = override or self:_opacity()
	for _, layer in self.Layers do
		local value = 1 - math.clamp(opacity * layer.Weight, 0, 1)
		local prop = layer.Native and "Transparency" or "ImageTransparency"
		if time == 0 then
			layer.Instance[prop] = value
		else
			Anim.tween(layer.Instance, { [prop] = value }, time or 0.25, Enum.EasingStyle.Quad)
		end
	end
end

--[[
	opts:
		Color      theme key / function / Color3 (default "Glow")
		Spread     glow reach in px (default 14)
		Strength   initial strength 0..1 (default 0.5)
		Offset     UDim2 shadow offset (native only)
		Wide       softer, wider falloff
]]
function Glow.attach(library, target, opts)
	opts = opts or {}
	local spread = opts.Spread or 14
	local handle = setmetatable({
		Library = library,
		Target = target,
		Strength = opts.Strength or 0.5,
		Layers = {},
	}, Handle)
	local color = opts.Color or "Glow"

	local function paint(instance, prop)
		if typeof(color) == "Color3" then
			instance[prop] = color
		else
			library.Theme:Bind(instance, { [prop] = color })
		end
	end

	if Glow.native() then
		local wide = opts.Wide and 1.6 or 1
		for index, layer in LAYERS do
			local grow = math.floor(spread * layer.Grow * wide + 0.5)
			local shadow = Instance.new("UIShadow")
			shadow.BlurRadius = UDim.new(0, math.max(2, math.floor(spread * layer.Blur * wide + 0.5)))
			shadow.Spread = UDim2.fromOffset(grow * 2, grow * 2)
			shadow.Offset = opts.Offset or UDim2.new()
			shadow.ZIndex = -index
			shadow.Transparency = 1
			paint(shadow, "Color")
			shadow.Parent = target
			table.insert(handle.Layers, { Instance = shadow, Weight = layer.Weight, Native = true })
		end
	else
		local name = opts.Wide and "glowWide" or "glow"
		local meta = library.Assets:Meta(name)
		local image = Util.passive(Util.create("ImageLabel", {
			Name = "Glow",
			BackgroundTransparency = 1,
			Image = library.Assets:Texture(name),
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(meta.Pad, meta.Pad, meta.Size - meta.Pad, meta.Size - meta.Pad),
			SliceScale = spread / meta.Pad,
			Size = UDim2.new(1, spread * 2, 1, spread * 2),
			Position = UDim2.fromOffset(-spread, -spread),
			ZIndex = target.ZIndex,
			ImageTransparency = 1,
		}))
		paint(image, "ImageColor3")
		image.Parent = target
		table.insert(handle.Layers, { Instance = image, Weight = 1, Native = false })
	end

	registry[handle] = true
	target.Destroying:Connect(function()
		registry[handle] = nil
	end)
	handle:_apply(0)
	return handle
end

-- Animates a glow to a new strength
function Glow.set(handle, strength, time)
	if not handle then
		return
	end
	handle.Strength = strength
	handle:_apply(time)
end

function Glow.get(handle)
	return handle and handle.Strength or 0
end

-- Recolours a glow that was given a fixed Color3
function Glow.setColor(handle, color)
	if not handle then
		return
	end
	for _, layer in handle.Layers do
		layer.Instance[layer.Native and "Color" or "ImageColor3"] = color
	end
end

-- Quick bright burst that settles back to the current strength
function Glow.flash(handle, peak, time)
	if not handle or intensity(handle.Library) <= 0 then
		return
	end
	handle:_apply(0, math.clamp(peak * intensity(handle.Library), 0, 1))
	handle:_apply(time or 0.5)
end

-- Neon tube start-up flicker before settling at `strength`
function Glow.flicker(handle, strength)
	if not handle then
		return
	end
	handle.Strength = strength
	task.spawn(function()
		for _, k in { 0.9, 0.05, 0.7, 0.1, 0.0, 0.85, 0.25, 1 } do
			if not registry[handle] then
				return
			end
			handle:_apply(0, handle:_opacity() * k)
			task.wait(0.03 + math.random() * 0.03)
		end
		if registry[handle] then
			handle:_apply(0)
		end
	end)
end

-- Re-applies opacity after the intensity setting changes
function Glow.refresh(library)
	for handle in registry do
		if handle.Library == library then
			handle:_apply(0)
		end
	end
end

--[[
	Soft drop shadow under a frame (black UIShadow, or a sliced image on old
	clients). Returns an object with :SetTransparency(t, time).
		opts: Blur (px, default 30), Offset (Vector2, default 0,10),
		      Grow (px each side, default 6), Transparency (default 0.35)
]]
function Glow.dropShadow(library, target, opts)
	opts = opts or {}
	local offset = opts.Offset or Vector2.new(0, 10)
	local grow = opts.Grow or 6
	local shadow = { Native = Glow.native(), Base = opts.Transparency or 0.35 }
	if shadow.Native then
		local instance = Instance.new("UIShadow")
		instance.Color = Color3.new(0, 0, 0)
		instance.BlurRadius = UDim.new(0, opts.Blur or 30)
		instance.Offset = UDim2.fromOffset(offset.X, offset.Y)
		instance.Spread = UDim2.fromOffset(grow * 2, grow * 2)
		instance.Transparency = shadow.Base
		instance.ZIndex = -10
		instance.Parent = target
		shadow.Instance = instance
	else
		local meta = library.Assets:Meta("shadow")
		local reach = opts.Blur or 30
		shadow.Instance = Util.passive(Util.create("ImageLabel", {
			Name = "Shadow",
			BackgroundTransparency = 1,
			Image = library.Assets:Texture("shadow"),
			ImageColor3 = Color3.new(0, 0, 0),
			ImageTransparency = shadow.Base,
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(meta.Pad, meta.Pad, meta.Size - meta.Pad, meta.Size - meta.Pad),
			SliceScale = reach / meta.Pad,
			Size = UDim2.new(1, (reach + grow) * 2, 1, (reach + grow) * 2),
			Position = UDim2.fromOffset(-(reach + grow) + offset.X, -(reach + grow) + offset.Y),
			ZIndex = 0,
			Parent = target,
		}))
	end

	-- t: 0 = base darkness, 1 = invisible
	function shadow.SetTransparency(_, t, time)
		local value = shadow.Base + (1 - shadow.Base) * t
		local prop = shadow.Native and "Transparency" or "ImageTransparency"
		if time == 0 then
			shadow.Instance[prop] = value
		else
			Anim.tween(shadow.Instance, { [prop] = value }, time or 0.3)
		end
	end
	return shadow
end

function Glow.destroy(handle)
	if not handle then
		return
	end
	registry[handle] = nil
	for _, layer in handle.Layers do
		layer.Instance:Destroy()
	end
	table.clear(handle.Layers)
end

return Glow
