--[[
	Addons
	Toggles and labels can host compact inline controls on their right edge
	(keybinds, colour pickers), ImGui style:  [■] Aimbot      [RMB] [▆]
]]

local Util = import("core/Util")

local Addons = {}

function Addons.frame(parent, zindex)
	local frame = Util.create("Frame", {
		Name = "Addons",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.new(0, 0, 1, 0),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = zindex or 2,
		Parent = parent,
	})
	Util.list(frame, {
		Direction = Enum.FillDirection.Horizontal,
		HAlign = Enum.HorizontalAlignment.Right,
		VAlign = Enum.VerticalAlignment.Center,
		Padding = 4,
	})
	return frame
end

-- Keeps a label from running underneath the addon strip
function Addons.reserve(element, label, leftInset)
	local function update()
		local scale = element.Library.Scale or 1
		local width = element.Addons.AbsoluteSize.X / scale
		label.Size = UDim2.new(1, -(leftInset + width + (width > 0 and 6 or 0)), 1, 0)
	end
	element.Maid:Give(element.Addons:GetPropertyChangedSignal("AbsoluteSize"):Connect(update))
	update()
end

function Addons.install(class)
	function class:AddKeybind(flag, opts)
		local Keybind = import("components/elements/Keybind")
		return Keybind.new(self.Container, flag, opts, self)
	end

	function class:AddColorPicker(flag, opts)
		local ColorPicker = import("components/elements/ColorPicker")
		return ColorPicker.new(self.Container, flag, opts, self)
	end
end

return Addons
