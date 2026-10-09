--[[
	Paragraph
	A titled block of wrapped text with an accent spine.

		box:AddParagraph({ Title = "Notice", Content = "Silent aim is client-side only." })
]]

local Util = import("core/Util")
local Style = import("components/Style")
local Element = import("components/Element")

local Paragraph = Element.extend("Paragraph")

function Paragraph.new(container, opts)
	local self = setmetatable({}, Paragraph)
	Element.init(self, container, nil, opts, {
		Title = "Paragraph",
		Content = "",
	})
	local library = self.Library
	local theme = self.Theme
	self.Text = self.Options.Title

	local root = Util.create("Frame", {
		Name = "Paragraph",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	Util.padding(root, 2, 0, 2, 10)
	Util.list(root, { Padding = 3 })

	-- zero-size anchor keeps the spine out of the list layout's flow
	local anchor = Util.create("Frame", {
		Name = "SpineAnchor",
		BackgroundTransparency = 1,
		Size = UDim2.new(),
		LayoutOrder = 0,
		Parent = root,
	})
	local spine = Util.passive(Util.create("Frame", {
		Name = "Spine",
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = UDim2.fromOffset(-10, 1),
		Size = UDim2.fromOffset(2, 0),
		Parent = anchor,
	}))
	theme:Bind(Util.gradient(spine, { Rotation = 90 }), { Color = "AccentGradient" })
	self.Spine = spine

	self.TitleLabel = Style.label(library, {
		Name = "Title",
		Text = self.Options.Title,
		Weight = "Bold",
		Color = "Text",
		Size = UDim2.new(1, 0, 0, 14),
		Parent = root,
	})
	self.TitleLabel.LayoutOrder = 1
	self.Body = Style.label(library, {
		Name = "Body",
		Text = self.Options.Content,
		Color = "TextDim",
		TextSize = Style.Small,
		Wrap = true,
		Rich = true,
		YAlign = Enum.TextYAlignment.Top,
		Size = UDim2.new(1, 0, 0, 0),
		AutoSize = Enum.AutomaticSize.Y,
		Parent = root,
	})
	self.Body.LayoutOrder = 2

	-- spine height follows the content
	local function resize()
		local scale = library.Scale or 1
		spine.Size = UDim2.fromOffset(2, root.AbsoluteSize.Y / scale - 4)
	end
	self.Maid:Give(root:GetPropertyChangedSignal("AbsoluteSize"):Connect(resize))

	self:_mount(root)
	return self
end

function Paragraph:SetTitle(text)
	self.Text = tostring(text)
	self.TitleLabel.Text = self.Text
end

function Paragraph:SetContent(text)
	self.Body.Text = tostring(text)
end

function Paragraph:SetValue(text)
	self:SetContent(text)
end

function Paragraph:_searchText()
	return self.Options.Title .. " " .. self.Body.Text
end

function Paragraph:_serialize()
	return nil
end

return Paragraph
