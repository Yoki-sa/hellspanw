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
	opts: Name, Position (Vector2), Size (UDim2), AutoSize (Enum.AutomaticSize),
	      Parent (layer)
	Returns frame, maid
]]
function Floating.panel(library, opts)
	local theme = library.Theme
	local maid = Maid.new()

	local frame = Util.create("Frame", {
		Name = opts.Name or "Panel",
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(opts.Position.X, opts.Position.Y),
		Size = opts.Size or UDim2.new(),
		AutomaticSize = opts.AutoSize or Enum.AutomaticSize.None,
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
	Glow.attach(library, crown, { Spread = 7, Strength = 0.4, ZIndex = 18 })
	Glow.attach(library, frame, { Spread = 16, Strength = 0.08, Wide = true, ZIndex = 14 })

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

return Floating
