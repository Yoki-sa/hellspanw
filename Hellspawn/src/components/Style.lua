--[[
	Style
	Shared metrics and small factories so every control lines up on the same
	grid. Sizes are in unscaled pixels; the global UIScale handles DPI.
]]

local Util = import("core/Util")

local Style = {
	Row = 18, -- toggle / label / keybind rows
	Box = 22, -- dropdown, input, button height
	Gap = 6, -- spacing between controls
	Pad = 10, -- groupbox inner padding
	Text = 12,
	Small = 11,
	Tiny = 10,
	Topbar = 44,
	Statusbar = 22,
	Sidebar = 172,
}

local WEIGHTS = {
	Regular = Enum.FontWeight.Regular,
	Medium = Enum.FontWeight.Medium,
	Bold = Enum.FontWeight.Bold,
}

function Style.font(library, weight, role)
	return library.Assets:Font(role or "Body", WEIGHTS[weight or "Regular"] or weight)
end

--[[
	Passive text label bound to a theme colour.
	props: Text, Size, Position, AnchorPoint, Color (theme key), Weight,
	       TextSize, XAlign, YAlign, Wrap, Rich, ZIndex, Parent, Name, Role
]]
function Style.label(library, props)
	local label = Util.create("TextLabel", {
		Name = props.Name or "Label",
		BackgroundTransparency = 1,
		Text = props.Text or "",
		FontFace = Style.font(library, props.Weight, props.Role),
		TextSize = props.TextSize or Style.Text,
		TextXAlignment = props.XAlign or Enum.TextXAlignment.Left,
		TextYAlignment = props.YAlign or Enum.TextYAlignment.Center,
		TextWrapped = props.Wrap == true,
		TextTruncate = props.Truncate and Enum.TextTruncate.AtEnd or Enum.TextTruncate.None,
		RichText = props.Rich == true,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		AutomaticSize = props.AutoSize or Enum.AutomaticSize.None,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
	Util.passive(label)
	-- Color = false: the owner paints this label itself (state-driven colour)
	if props.Color ~= false then
		library.Theme:Bind(label, { TextColor3 = props.Color or "Text" })
	end
	return label
end

-- Invisible full-size button used as a click target
function Style.hitbox(props)
	return Util.create("TextButton", {
		Name = props.Name or "Hitbox",
		BackgroundTransparency = 1,
		Text = "",
		AutoButtonColor = false,
		Size = props.Size or UDim2.fromScale(1, 1),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		ZIndex = props.ZIndex or 1,
		Parent = props.Parent,
	})
end

-- Tinted icon image (from the atlas or any asset)
function Style.icon(library, props)
	local image = Util.create("ImageLabel", {
		Name = props.Name or "Icon",
		BackgroundTransparency = 1,
		Size = props.Size or UDim2.fromOffset(14, 14),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		ZIndex = props.ZIndex or 1,
		Rotation = props.Rotation or 0,
		ImageTransparency = props.Transparency or 0,
		Parent = props.Parent,
	})
	Util.passive(image)
	library.Assets:ApplyIcon(image, props.Icon)
	if props.Color then
		library.Theme:Bind(image, { ImageColor3 = props.Color })
	end
	return image
end

-- 1px framed surface used by inputs, dropdowns, buttons
function Style.surface(library, props)
	local frame = Util.create(props.Class or "Frame", {
		Name = props.Name or "Surface",
		BorderSizePixel = 0,
		Size = props.Size or UDim2.new(1, 0, 0, Style.Box),
		Position = props.Position or UDim2.new(),
		AnchorPoint = props.AnchorPoint or Vector2.zero,
		ZIndex = props.ZIndex or 1,
		ClipsDescendants = props.Clip == true,
		Parent = props.Parent,
	})
	if frame:IsA("GuiButton") then
		frame.AutoButtonColor = false
		frame.Text = ""
	end
	library.Theme:Bind(frame, { BackgroundColor3 = props.Fill or "Surface" })
	local stroke = Util.stroke(frame, { Thickness = 1 })
	library.Theme:Bind(stroke, { Color = props.Stroke or "Border" })
	Util.corner(frame, props.Radius or 2)
	return frame, stroke
end

return Style
