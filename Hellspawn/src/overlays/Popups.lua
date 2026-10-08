--[[
	Popups
	Floating panels (dropdown lists, colour pickers, context menus) that live
	in their own top layer so scrolling frames never clip them.

	Only one popup is open at a time. It closes when you click elsewhere,
	press Escape, or when its owner moves (scroll, drag) or disappears.
	Outside-click detection listens to UserInputService instead of covering
	the screen, so the game keeps receiving every click.
]]

local Util = import("core/Util")
local Anim = import("core/Anim")
local Input = import("core/Input")
local Maid = import("core/Maid")
local Glow = import("fx/Glow")

local Popups = {}
Popups.__index = Popups

function Popups.new(library, layer)
	local self = setmetatable({}, Popups)
	self.Library = library
	self.Layer = layer
	self.Current = nil
	self.Maid = Maid.new()

	self.Maid:Give(Input.Began:Connect(function(io)
		local current = self.Current
		if not current then
			return
		end
		local kind = io.UserInputType
		if kind == Enum.UserInputType.Keyboard then
			if io.KeyCode == Enum.KeyCode.Escape then
				self:Close()
			end
			return
		end
		if kind ~= Enum.UserInputType.MouseButton1 and kind ~= Enum.UserInputType.MouseButton2 and kind ~= Enum.UserInputType.Touch then
			return
		end
		local point = Input.position(io)
		if Input.within(current.Root, point) then
			return
		end
		if current.Owner and Input.within(current.Owner, point) then
			return -- the owner toggles itself
		end
		self:Close()
	end))
	return self
end

--[[
	spec:
		Owner     GuiObject the popup hangs from
		Width     unscaled width (defaults to the owner's width)
		Height    unscaled height
		Offset    gap from the owner (default 4)
		Align     "left" (default) | "right"
		OnClose   called once when the popup closes
	Returns a handle: { Content, SetHeight(h), Close() }
]]
function Popups:Open(spec)
	self:Close(true)
	local library = self.Library
	local theme = library.Theme
	local scale = library.Scale or 1
	local owner = spec.Owner
	local width = spec.Width or (owner.AbsoluteSize.X / scale)
	local height = spec.Height or 100

	local root = Util.create("Frame", {
		Name = "Popup",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(width, height),
		ZIndex = 10,
		Parent = self.Layer,
	})
	Util.create("UIScale", { Scale = scale, Parent = root })

	local shadowMeta = library.Assets:Meta("shadow")
	local shadow = Util.passive(Util.create("ImageLabel", {
		Name = "Shadow",
		BackgroundTransparency = 1,
		Image = library.Assets:Texture("shadow"),
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.45,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(shadowMeta.Pad, shadowMeta.Pad, shadowMeta.Size - shadowMeta.Pad, shadowMeta.Size - shadowMeta.Pad),
		SliceScale = 0.45,
		Size = UDim2.new(1, 48, 0, 48),
		Position = UDim2.fromOffset(-24, -18),
		ZIndex = 9,
		Parent = root,
	}))

	local clip = Util.create("Frame", {
		Name = "Clip",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(-1, -1),
		Size = UDim2.new(1, 2, 0, 0),
		ZIndex = 10,
		Parent = root,
	})

	local panel = Util.create("Frame", {
		Name = "Panel",
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.fromOffset(width, height),
		ZIndex = 10,
		Active = true,
		Parent = clip,
	})
	theme:Bind(panel, { BackgroundColor3 = "Panel" })
	local stroke = Util.stroke(panel)
	theme:Bind(stroke, { Color = "BorderLight" })
	Util.corner(panel, 2)

	-- accent hairline on top, like the window
	local hairline = Util.passive(Util.create("Frame", {
		Name = "Hairline",
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 0, 1),
		ZIndex = 14,
		Parent = panel,
	}))
	theme:Bind(Util.gradient(hairline, {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0),
			NumberSequenceKeypoint.new(0.7, 0.6),
			NumberSequenceKeypoint.new(1, 1),
		}),
	}), { Color = "AccentGradient" })

	local glow = Glow.attach(library, root, { Spread = 16, Strength = 0.12, Wide = true, ZIndex = 9 })

	local handle = {
		Root = root,
		Content = panel,
		Owner = owner,
		OnClose = spec.OnClose,
		Height = height,
		Width = width,
		_glow = glow,
		_shadow = shadow,
	}

	local function place()
		local ownerPos, ownerSize = owner.AbsolutePosition, owner.AbsoluteSize
		local viewport = Util.viewport()
		local gap = (spec.Offset or 4) * scale
		local h = handle.Height * scale
		local w = handle.Width * scale
		local x = spec.Align == "right" and (ownerPos.X + ownerSize.X - w) or ownerPos.X
		local y = ownerPos.Y + ownerSize.Y + gap
		if y + h > viewport.Y - 6 then
			y = math.max(6, ownerPos.Y - h - gap)
		end
		x = math.clamp(x, 6, math.max(6, viewport.X - w - 6))
		root.Position = UDim2.fromOffset(math.floor(x), math.floor(y))
	end
	place()

	function handle.SetHeight(_, newHeight, instant)
		handle.Height = newHeight
		root.Size = UDim2.fromOffset(handle.Width, newHeight)
		panel.Size = UDim2.fromOffset(handle.Width, newHeight)
		Anim.tween(clip, { Size = UDim2.new(1, 2, 0, newHeight + 2) }, instant and 0 or 0.16)
		place()
	end

	function handle.Close()
		if self.Current == handle then
			self:Close()
		end
	end

	-- unfurl
	Anim.tween(clip, { Size = UDim2.new(1, 2, 0, height + 2) }, 0.22, Enum.EasingStyle.Quint)

	-- close when the owner moves (scrolling, dragging) or vanishes
	local anchor = owner.AbsolutePosition
	handle._watch = Anim.frame(function()
		if self.Current ~= handle then
			return
		end
		if not Util.isShown(owner) or (owner.AbsolutePosition - anchor).Magnitude > 2 then
			self:Close()
		end
	end)

	handle._clip = clip
	self.Current = handle
	return handle
end

function Popups:IsOpen(owner)
	return self.Current ~= nil and (owner == nil or self.Current.Owner == owner)
end

function Popups:Close(instant)
	local current = self.Current
	if not current then
		return
	end
	self.Current = nil
	current._watch()
	if current.OnClose then
		task.spawn(Util.safeCall, current.OnClose)
	end
	local root = current.Root
	if instant or not self.Library.Settings.Animations then
		root:Destroy()
		return
	end
	Anim.tween(current._clip, { Size = UDim2.new(1, 2, 0, 0) }, 0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Anim.tween(current._shadow, { ImageTransparency = 1 }, 0.12)
	Glow.set(current._glow, 0, 0.12)
	task.delay(0.14, function()
		root:Destroy()
	end)
end

function Popups:Destroy()
	self:Close(true)
	self.Maid:Destroy()
end

return Popups
