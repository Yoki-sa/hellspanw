--[[
	Floating
	Small draggable HUD panels (watermark, keybind list). Each has the same
	accent crown line and neon halo as the main window.
]]

local Util = import("core/Util")
local Input = import("core/Input")
local Maid = import("core/Maid")
local Glow = import("fx/Glow")

local Floating = {}

--[[
	opts: Name, Position (Vector2), Size (UDim2), Parent (layer)
	Returns frame, maid, uiscale. The frame is fixed-size: call
	Floating.follow(frame, content, axis) to size it from an auto-sized child.
]]
function Floating.panel(library, opts)
	local theme = library.Theme
	local maid = Maid.new()

	local frame = Util.create("Frame", {
		Name = opts.Name or "Panel",
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(opts.Position.X, opts.Position.Y),
		Size = opts.Size or UDim2.new(),
		Active = true,
		ZIndex = 15,
		Parent = opts.Parent,
	})
	maid:Give(frame)
	theme:Bind(frame, { BackgroundColor3 = "Panel" })
	theme:Bind(Util.stroke(frame), { Color = "Border" })
	Util.corner(frame, 2)
	local scale = Util.create("UIScale", { Scale = library.Scale, Parent = frame })

	local crown = Util.passive(Util.create("Frame", {
		Name = "Crown",
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 0, 2),
		ZIndex = 18,
		Parent = frame,
	}))
	theme:Bind(Util.gradient(crown), { Color = "AccentGradient" })
	Glow.attach(library, crown, { Spread = 7, Strength = 0.4 })
	Glow.attach(library, frame, { Spread = 16, Strength = 0.08, Wide = true })

	-- drag anywhere on the panel
	local origin
	maid:Give((Input.drag(frame, {
		onStart = function()
			origin = Vector2.new(frame.Position.X.Offset, frame.Position.Y.Offset)
		end,
		onMove = function(_, delta)
			local viewport = Util.viewport()
			local size = frame.AbsoluteSize
			local target = origin + delta
			target = Vector2.new(
				math.clamp(target.X, 0, math.max(0, viewport.X - size.X)),
				math.clamp(target.Y, 0, math.max(0, viewport.Y - size.Y))
			)
			frame.Position = UDim2.fromOffset(target.X, target.Y)
		end,
	})))

	return frame, maid, scale
end

--[[
	Sizes `frame` along `axis` ("X" or "Y") to match an AutomaticSize child.
	(AutomaticSize on the panel itself would fight its scale-sized crown
	line and halo and grow without bound.)
]]
function Floating.follow(frame, content, axis, scaleObject, padding)
	padding = padding or 0
	local function update()
		local scale = scaleObject and scaleObject.Scale or 1
		local size = content.AbsoluteSize / (scale > 0 and scale or 1)
		local current = frame.Size
		if axis == "X" then
			frame.Size = UDim2.new(0, math.ceil(size.X) + padding, current.Y.Scale, current.Y.Offset)
		else
			frame.Size = UDim2.new(current.X.Scale, current.X.Offset, 0, math.ceil(size.Y) + padding)
		end
	end
	update()
	return content:GetPropertyChangedSignal("AbsoluteSize"):Connect(update)
end

return Floating
