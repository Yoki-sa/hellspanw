--[[
	Glow
	Neon is never a flat stroke here: every glowing edge is a 9-sliced, hollow
	shadow image hugging its target. The texture is transparent inside, so a
	halo can sit above or below the element without tinting what it wraps.

	Each halo has a "strength" (0..1). The visible opacity is
	strength × library glow intensity, so a single setting dims every neon
	edge in the interface at once.
]]

local Util = import("core/Util")
local Anim = import("core/Anim")

local Glow = {}

local registry = {} -- [ImageLabel] = { strength, library }

local function opacityFor(entry)
	local settings = entry.library.Settings
	local intensity = settings.Glow and settings.GlowIntensity or 0
	return math.clamp(entry.strength * intensity, 0, 1)
end

--[[
	opts:
		Color      theme key / function / Color3 (default "Glow")
		Spread     halo size in px (default 14)
		Strength   initial strength 0..1 (default 0.5)
		Wide       use the softer, wider texture
		ZIndex     defaults to the target's ZIndex
]]
function Glow.attach(library, target, opts)
	opts = opts or {}
	local assets = library.Assets
	local name = opts.Wide and "glowWide" or "glow"
	local meta = assets:Meta(name)
	local spread = opts.Spread or 14

	local image = Util.create("ImageLabel", {
		Name = "Glow",
		BackgroundTransparency = 1,
		Image = assets:Texture(name),
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(meta.Pad, meta.Pad, meta.Size - meta.Pad, meta.Size - meta.Pad),
		SliceScale = spread / meta.Pad,
		Size = UDim2.new(1, spread * 2, 1, spread * 2),
		Position = UDim2.fromOffset(-spread, -spread),
		ZIndex = opts.ZIndex or target.ZIndex,
		ImageTransparency = 1,
	})
	Util.passive(image)

	local color = opts.Color or "Glow"
	if typeof(color) == "Color3" then
		image.ImageColor3 = color
	else
		library.Theme:Bind(image, { ImageColor3 = color })
	end

	local entry = { strength = opts.Strength or 0.5, library = library }
	registry[image] = entry
	image.ImageTransparency = 1 - opacityFor(entry)
	image.Destroying:Connect(function()
		registry[image] = nil
	end)
	image.Parent = target
	return image
end

-- Animates a halo to a new strength
function Glow.set(image, strength, time)
	local entry = image and registry[image]
	if not entry then
		return
	end
	entry.strength = strength
	local target = 1 - opacityFor(entry)
	if time == 0 then
		image.ImageTransparency = target
	else
		Anim.tween(image, { ImageTransparency = target }, time or 0.25, Enum.EasingStyle.Quad)
	end
end

function Glow.get(image)
	local entry = registry[image]
	return entry and entry.strength or 0
end

-- Quick bright flash that settles back to the current strength
function Glow.flash(image, peak, time)
	local entry = image and registry[image]
	if not entry then
		return
	end
	image.ImageTransparency = 1 - math.clamp(peak * (entry.library.Settings.GlowIntensity or 1), 0, 1)
	Anim.tween(image, { ImageTransparency = 1 - opacityFor(entry) }, time or 0.5, Enum.EasingStyle.Quad)
end

-- Re-applies opacity after the intensity setting changes
function Glow.refresh(library)
	for image, entry in registry do
		if entry.library == library then
			image.ImageTransparency = 1 - opacityFor(entry)
		end
	end
end

--[[
	Neon tube start-up flicker: a burst of rapid on/off steps before the halo
	settles. Purely cosmetic, cancels itself if the halo is destroyed.
]]
function Glow.flicker(image, strength)
	local entry = image and registry[image]
	if not entry then
		return
	end
	entry.strength = strength
	local pattern = { 0.9, 0.05, 0.7, 0.1, 0.0, 0.85, 0.25, 1 }
	task.spawn(function()
		for _, k in pattern do
			if not registry[image] then
				return
			end
			image.ImageTransparency = 1 - opacityFor(entry) * k
			task.wait(0.03 + math.random() * 0.03)
		end
		if registry[image] then
			image.ImageTransparency = 1 - opacityFor(entry)
		end
	end)
end

return Glow
