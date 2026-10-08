--[[
	MobileButton
	Touch devices have no toggle key, so they get a draggable sigil button
	that opens and closes every window. A tap toggles; a drag moves it.
]]

local Util = import("core/Util")
local Anim = import("core/Anim")
local Input = import("core/Input")
local Maid = import("core/Maid")
local Glow = import("fx/Glow")

local MobileButton = {}
MobileButton.__index = MobileButton

local SIZE = 46

function MobileButton.new(library, layer)
	local self = setmetatable({}, MobileButton)
	self.Library = library
	self.Maid = Maid.new()
	local theme = library.Theme

	local button = Util.create("ImageButton", {
		Name = "Toggle",
		AutoButtonColor = false,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(18, 120),
		Size = UDim2.fromOffset(SIZE, SIZE),
		ZIndex = 30,
		Parent = layer,
	})
	self.Maid:Give(button)
	theme:Bind(button, { BackgroundColor3 = "Panel" })
	Util.corner(button, SIZE // 2)
	theme:Bind(Util.stroke(button), { Color = "Accent" })
	Glow.attach(library, button, { Spread = 14, Strength = 0.45, ZIndex = 29 })
	local scale = Util.create("UIScale", { Scale = library.Scale, Parent = button })
	self.UIScale = scale

	local logo = Util.passive(Util.create("ImageLabel", {
		Name = "Logo",
		BackgroundTransparency = 1,
		Image = library.Assets:Texture("logo"),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(SIZE - 10, SIZE - 10),
		ZIndex = 31,
		Parent = button,
	}))
	theme:Bind(logo, { ImageColor3 = "Text" })

	local origin, moved
	self.Maid:Give((Input.drag(button, {
		onStart = function()
			origin = Vector2.new(button.Position.X.Offset, button.Position.Y.Offset)
			moved = false
		end,
		onMove = function(_, delta)
			if delta.Magnitude > 6 then
				moved = true
			end
			local viewport = Util.viewport()
			local target = origin + delta
			button.Position = UDim2.fromOffset(
				math.clamp(target.X, 0, viewport.X - SIZE),
				math.clamp(target.Y, 0, viewport.Y - SIZE)
			)
		end,
		onEnd = function()
			if not moved then
				library:Toggle()
				Anim.tween(logo, { Rotation = logo.Rotation + 180 }, 0.35, Enum.EasingStyle.Back)
			end
		end,
	})))
	return self
end

function MobileButton:SetScale(scale)
	self.UIScale.Scale = scale
end

function MobileButton:Destroy()
	self.Maid:Destroy()
end

return MobileButton
