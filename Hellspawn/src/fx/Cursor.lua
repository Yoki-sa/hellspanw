--[[
	Cursor
	ImGui menus draw their own pointer: games that hide the system cursor
	(first-person shooters) still need one while the menu is open. This draws
	a themed arrow with a soft bloom and a short ember trail, and only takes
	over the system icon while it is actually needed.
]]

local Env = import("core/Env")
local Util = import("core/Util")
local Anim = import("core/Anim")
local Input = import("core/Input")

local Cursor = {}
Cursor.__index = Cursor

local UIS = Env.service("UserInputService")
local SIZE = 22
local TIP = Vector2.new(3, 2) / 32 * SIZE
local TRAIL = 7

function Cursor.new(library, layer)
	local self = setmetatable({}, Cursor)
	self.Library = library
	self.Overriding = false
	self._gameIcon = UIS.MouseIconEnabled
	self._history = {}

	self.Holder = Util.passive(Util.create("Frame", {
		Name = "Cursor",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 50,
		Parent = layer,
	}))

	self.Trail = {}
	for i = 1, TRAIL do
		local dot = Util.passive(Util.create("ImageLabel", {
			Name = "Trail" .. i,
			BackgroundTransparency = 1,
			Image = library.Assets:Texture("spark"),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(10 - i, 10 - i),
			ImageTransparency = 0.35 + i * 0.09,
			ZIndex = 50,
			Parent = self.Holder,
		}))
		library.Theme:Bind(dot, { ImageColor3 = "Accent" })
		self.Trail[i] = dot
	end

	self.Bloom = Util.passive(Util.create("ImageLabel", {
		Name = "Bloom",
		BackgroundTransparency = 1,
		Image = library.Assets:Texture("bloom"),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(46, 46),
		ImageTransparency = 0.78,
		ZIndex = 51,
		Parent = self.Holder,
	}))
	library.Theme:Bind(self.Bloom, { ImageColor3 = "Accent" })

	self.Arrow = Util.passive(Util.create("ImageLabel", {
		Name = "Arrow",
		BackgroundTransparency = 1,
		Image = library.Assets:Texture("cursor"),
		Size = UDim2.fromOffset(SIZE, SIZE),
		ZIndex = 52,
		Parent = self.Holder,
	}))
	library.Theme:Bind(self.Arrow, { ImageColor3 = "Text" })

	self._unbind = Anim.frame(function()
		self:_update()
	end)
	return self
end

function Cursor:_setOverride(state)
	if state == self.Overriding then
		return
	end
	self.Overriding = state
	if state then
		self._gameIcon = UIS.MouseIconEnabled
		UIS.MouseIconEnabled = false
	else
		UIS.MouseIconEnabled = self._gameIcon
	end
end

function Cursor:_update()
	local library = self.Library
	if not self.Overriding then
		self._gameIcon = UIS.MouseIconEnabled
	end
	local want = library.Settings.Cursor
		and library.Assets:Has("cursor")
		and library:AnyWindowVisible()
		and (library:IsMouseOverUI() or not self._gameIcon)
		and not Input.touchEnabled()

	self:_setOverride(want == true)
	self.Holder.Visible = want == true
	if not want then
		table.clear(self._history)
		return
	end

	local mouse = Input.mouse()
	self.Arrow.Position = UDim2.fromOffset(mouse.X - TIP.X, mouse.Y - TIP.Y)
	self.Bloom.Position = UDim2.fromOffset(mouse.X + 4, mouse.Y + 6)

	table.insert(self._history, 1, mouse)
	if #self._history > TRAIL * 2 then
		table.remove(self._history)
	end
	for i, dot in self.Trail do
		local point = self._history[math.min(i * 2, #self._history)] or mouse
		dot.Position = UDim2.fromOffset(point.X, point.Y)
		dot.Visible = library.Settings.Animations and (point - mouse).Magnitude > 2
	end
end

function Cursor:Destroy()
	self._unbind()
	self:_setOverride(false)
	self.Holder:Destroy()
end

return Cursor
