--[[
	Divider
	A strand of thorn vine (or a plain hairline) between controls, optionally
	with a caption set into it.

		box:AddDivider()
		box:AddDivider({ Text = "advanced" })
		box:AddDivider({ Style = "line" })
]]

local Util = import("core/Util")
local Style = import("components/Style")
local Element = import("components/Element")

local Divider = Element.extend("Divider")

local FADE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 1),
	NumberSequenceKeypoint.new(0.15, 0.2),
	NumberSequenceKeypoint.new(0.85, 0.2),
	NumberSequenceKeypoint.new(1, 1),
})

function Divider.new(container, opts)
	if type(opts) == "string" then
		opts = { Text = opts }
	end
	local self = setmetatable({}, Divider)
	Element.init(self, container, nil, opts, { Text = "", Style = "vine" })
	local library = self.Library
	local theme = self.Theme
	local useVine = self.Options.Style == "vine" and library.Assets:Has("vine")

	local root = Util.create("Frame", {
		Name = "Divider",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 12),
	})

	local function strand(position, size)
		local line
		if useVine then
			local meta = library.Assets:Meta("vine")
			line = Util.create("ImageLabel", {
				Name = "Vine",
				BackgroundTransparency = 1,
				Image = library.Assets:Texture("vine"),
				ScaleType = Enum.ScaleType.Tile,
				TileSize = UDim2.fromOffset(meta.Width / 2, meta.Height / 2),
				AnchorPoint = Vector2.new(0, 0.5),
				Position = position,
				Size = UDim2.new(size.X.Scale, size.X.Offset, 0, meta.Height / 2),
				Parent = root,
			})
			theme:Bind(line, { ImageColor3 = "BorderLight" })
		else
			line = Util.create("Frame", {
				Name = "Line",
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = position,
				Size = UDim2.new(size.X.Scale, size.X.Offset, 0, 1),
				Parent = root,
			})
			theme:Bind(line, { BackgroundColor3 = "BorderLight" })
		end
		Util.passive(line)
		Util.gradient(line, { Transparency = FADE })
		return line
	end

	if self.Text ~= "" then
		local caption = Style.label(library, {
			Text = string.upper(self.Text),
			Weight = "Bold",
			TextSize = Style.Tiny,
			Color = "TextMuted",
			XAlign = Enum.TextXAlignment.Center,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.new(0, 0, 1, 0),
			AutoSize = Enum.AutomaticSize.X,
			Parent = root,
		})
		self.Label = caption
		local gap = 8
		local function layout()
			local width = caption.AbsoluteSize.X / (library.Scale or 1)
			local half = width / 2 + gap
			self._left.Size = UDim2.new(0.5, -half, self._left.Size.Y.Scale, self._left.Size.Y.Offset)
			self._right.Size = UDim2.new(0.5, -half, self._right.Size.Y.Scale, self._right.Size.Y.Offset)
			self._right.Position = UDim2.new(0.5, half, 0.5, 0)
		end
		self._left = strand(UDim2.fromScale(0, 0.5), UDim2.new(0.5, -40, 0, 0))
		self._right = strand(UDim2.new(0.5, 40, 0.5, 0), UDim2.new(0.5, -40, 0, 0))
		self.Maid:Give(caption:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout))
		layout()
	else
		strand(UDim2.fromScale(0, 0.5), UDim2.fromScale(1, 0))
	end

	self:_mount(root)
	return self
end

function Divider:SetValue() end

function Divider:_serialize()
	return nil
end

return Divider
