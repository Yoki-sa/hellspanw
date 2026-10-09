--[[
	Container
	Mixin giving groupboxes and tabbox pages their Add* API.
	Containers provide: Library, Window, List (frame), Elements (array).
]]

local Util = import("core/Util")
local Toggle = import("components/elements/Toggle")
local Slider = import("components/elements/Slider")
local Button = import("components/elements/Button")
local Dropdown = import("components/elements/Dropdown")
local ColorPicker = import("components/elements/ColorPicker")
local Keybind = import("components/elements/Keybind")
local Textbox = import("components/elements/Textbox")
local Label = import("components/elements/Label")
local Paragraph = import("components/elements/Paragraph")
local Divider = import("components/elements/Divider")
local Image = import("components/elements/Image")

local Container = {}

local Methods = {}
Container.Methods = Methods

function Methods:_order()
	self._layoutCounter = (self._layoutCounter or 0) + 1
	return self._layoutCounter
end

function Methods:AddToggle(flag, opts)
	return Toggle.new(self, flag, opts)
end
Methods.AddCheckbox = Methods.AddToggle

function Methods:AddSlider(flag, opts)
	return Slider.new(self, flag, opts)
end

function Methods:AddButton(opts, callback)
	if type(opts) == "string" then
		opts = { Text = opts, Callback = callback }
	end
	return Button.new(self, opts)
end

function Methods:AddDropdown(flag, opts)
	return Dropdown.new(self, flag, opts)
end

function Methods:AddColorPicker(flag, opts)
	return ColorPicker.new(self, flag, opts)
end
Methods.AddColorpicker = Methods.AddColorPicker

function Methods:AddKeybind(flag, opts)
	return Keybind.new(self, flag, opts)
end
Methods.AddKeyPicker = Methods.AddKeybind

function Methods:AddInput(flag, opts)
	return Textbox.new(self, flag, opts)
end
Methods.AddTextbox = Methods.AddInput

function Methods:AddLabel(opts)
	return Label.new(self, opts)
end

function Methods:AddParagraph(opts)
	return Paragraph.new(self, opts)
end

function Methods:AddDivider(opts)
	return Divider.new(self, opts)
end

function Methods:AddImage(opts)
	return Image.new(self, opts)
end

-- Nested container shown only while its dependencies hold (lazy import: it
-- mixes this module in, so a top-level import would be circular)
function Methods:AddDependencyBox()
	return import("components/DependencyBox").new(self)
end

-- Vertical breathing room
function Methods:AddBlank(height)
	local spacer = Util.create("Frame", {
		Name = "Blank",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, height or 6),
		LayoutOrder = self:_order(),
		Parent = self.List,
	})
	return spacer
end

-- Hides controls whose text doesn't match; returns how many stayed visible
function Methods:_filter(query)
	local shown = 0
	for _, element in self.Elements do
		if element:_filter(query) then
			shown += 1
		end
	end
	return shown
end

function Container.mixin(class)
	for name, fn in Methods do
		class[name] = fn
	end
end

return Container
