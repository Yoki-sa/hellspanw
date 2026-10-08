--[[
	Ripple
	Expanding ring of light from the click point. The container should clip
	its descendants so the ripple stays inside the element.
]]

local Util = import("core/Util")
local Anim = import("core/Anim")

local Ripple = {}

function Ripple.spawn(library, container, point, color, opts)
	if not library.Settings.Animations or not library.Assets:Has("circle") then
		return
	end
	opts = opts or {}
	local scale = library.Scale or 1
	local origin = container.AbsolutePosition
	local size = container.AbsoluteSize / scale
	local local_ = (point - origin) / scale
	local reach = math.sqrt(size.X * size.X + size.Y * size.Y) * 2

	local ring = Util.passive(Util.create("ImageLabel", {
		Name = "Ripple",
		BackgroundTransparency = 1,
		Image = library.Assets:Texture(opts.Hollow and "ring" or "circle"),
		ImageColor3 = color or library.Theme:Get("Accent"),
		ImageTransparency = opts.Transparency or 0.72,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(local_.X, local_.Y),
		Size = UDim2.fromOffset(4, 4),
		ZIndex = opts.ZIndex or (container.ZIndex + 1),
		Parent = container,
	}))
	Anim.tween(ring, {
		Size = UDim2.fromOffset(reach, reach),
		ImageTransparency = 1,
	}, opts.Time or 0.6, Enum.EasingStyle.Quart)
	task.delay((opts.Time or 0.6) + 0.05, function()
		ring:Destroy()
	end)
end

return Ripple
