--[[
	Label
	Wrapped text row (RichText allowed). Like toggles, labels can host
	keybinds and colour pickers on their right edge.

		box:AddLabel("Status: <b>idle</b>")
		box:AddLabel({ Text = "Chams colour" }):AddColorPicker("chams", { Default = Color3.new(1, 0, 0) })
]]

local Util = import("core/Util")
local Style = import("components/Style")
local Element = import("components/Element")
local Addons = import("components/Addons")

local Label = Element.extend("Label")
Addons.install(Label)

function Label.new(container, opts)
	if type(opts) == "string" then
		opts = { Text = opts }
	end
	local self = setmetatable({}, Label)
	Element.init(self, container, nil, opts, {
		Text = "",
		Wrap = true,
		Color = "TextDim",
	})
	local library = self.Library

	local row = Util.create("Frame", {
		Name = "Label",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, Style.Row),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	self.Label = Style.label(library, {
		Text = self.Text,
		Color = self.Options.Color,
		Rich = true,
		Wrap = self.Options.Wrap,
		YAlign = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, Style.Row),
		AutoSize = Enum.AutomaticSize.Y,
		Parent = row,
	})
	Util.padding(self.Label, 2, 0, 2, 0)
	self.Addons = Addons.frame(row, 3)
	self.Addons.AnchorPoint = Vector2.new(1, 0)
	self.Addons.Position = UDim2.fromScale(1, 0)
	self.Addons.Size = UDim2.new(0, 0, 0, Style.Row)

	-- shrink the text column whenever addons appear
	local function reserve()
		local width = self.Addons.AbsoluteSize.X / (library.Scale or 1)
		self.Label.Size = UDim2.new(1, -(width > 0 and width + 6 or 0), 0, Style.Row)
	end
	self.Maid:Give(self.Addons:GetPropertyChangedSignal("AbsoluteSize"):Connect(reserve))

	self:_mount(row)
	return self
end

function Label:SetText(text)
	self.Text = tostring(text)
	self.Label.Text = self.Text
end

function Label:SetValue(text)
	self:SetText(text)
end

function Label:_serialize()
	return nil
end

return Label
