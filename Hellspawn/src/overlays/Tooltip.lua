--[[
	Tooltip
	One shared tooltip that follows the cursor after a short hover delay.
]]

local Util = import("core/Util")
local Anim = import("core/Anim")
local Input = import("core/Input")
local Maid = import("core/Maid")
local Style = import("components/Style")

local Tooltip = {}
Tooltip.__index = Tooltip

local DELAY = 0.4
local MAX_WIDTH = 260

function Tooltip.new(library, layer)
	local self = setmetatable({}, Tooltip)
	self.Library = library
	self.Owner = nil

	local frame = Util.passive(Util.create("Frame", {
		Name = "Tooltip",
		BorderSizePixel = 0,
		AutomaticSize = Enum.AutomaticSize.XY,
		Size = UDim2.new(),
		Visible = false,
		ZIndex = 40,
		Parent = layer,
	}))
	library.Theme:Bind(frame, { BackgroundColor3 = "Panel" })
	library.Theme:Bind(Util.stroke(frame), { Color = "BorderLight" })
	Util.corner(frame, 2)
	Util.padding(frame, 5, 8, 5, 8)
	self.Scale = Util.create("UIScale", { Scale = library.Scale, Parent = frame })
	Util.create("UISizeConstraint", { MaxSize = Vector2.new(MAX_WIDTH, 10000), Parent = frame })

	local accent = Util.passive(Util.create("Frame", {
		Name = "Accent",
		BorderSizePixel = 0,
		Size = UDim2.new(0, 2, 1, 0),
		Position = UDim2.fromOffset(-8, 0),
		ZIndex = 41,
		Parent = frame,
	}))
	library.Theme:Bind(accent, { BackgroundColor3 = "Accent" })

	self.Text = Style.label(library, {
		Name = "Text",
		TextSize = Style.Small,
		Color = "TextDim",
		Wrap = true,
		Rich = true,
		Size = UDim2.new(),
		AutoSize = Enum.AutomaticSize.XY,
		ZIndex = 41,
		Parent = frame,
	})
	Util.create("UISizeConstraint", { MaxSize = Vector2.new(MAX_WIDTH - 16, 10000), Parent = self.Text })
	self.Frame = frame

	self._unbind = Anim.frame(function()
		if frame.Visible then
			local mouse = Input.mouse()
			local viewport = Util.viewport()
			local size = frame.AbsoluteSize
			local x = math.min(mouse.X + 16, viewport.X - size.X - 8)
			local y = mouse.Y + 18
			if y + size.Y > viewport.Y - 8 then
				y = mouse.Y - size.Y - 10
			end
			frame.Position = UDim2.fromOffset(x, y)
		end
	end)
	return self
end

function Tooltip:SetScale(scale)
	self.Scale.Scale = scale
end

function Tooltip:_show(owner, text)
	self.Owner = owner
	self.Text.Text = text
	self.Frame.Visible = true
end

function Tooltip:_hide(owner)
	if owner == nil or self.Owner == owner then
		self.Owner = nil
		self.Frame.Visible = false
	end
end

-- Returns a Maid that removes the tooltip binding
function Tooltip:Attach(target, text)
	local maid = Maid.new()
	local token = 0
	maid:Give((Input.hover(target, function(state)
		token += 1
		local mine = token
		if state then
			task.delay(DELAY, function()
				if mine == token and self.Library.Settings.Tooltips then
					self:_show(target, text)
				end
			end)
		else
			self:_hide(target)
		end
	end)))
	maid:Give(function()
		token += 1
		self:_hide(target)
	end)
	return maid
end

function Tooltip:Destroy()
	self._unbind()
	self.Frame:Destroy()
end

return Tooltip
