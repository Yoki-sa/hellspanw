--[[
	Image
	Shows any image inside a groupbox: an atlas icon name, an rbxassetid, or a
	URL (downloaded once and cached through getcustomasset).

		box:AddImage({ Image = "https://example.com/art.png", Height = 140 })
		box:AddImage({ Image = "rabbit", Height = 48, Color = "Accent", Caption = "spiked" })
]]

local Util = import("core/Util")
local Style = import("components/Style")
local Element = import("components/Element")

local Image = Element.extend("Image")

function Image.new(container, opts)
	if type(opts) == "string" then
		opts = { Image = opts }
	end
	local self = setmetatable({}, Image)
	Element.init(self, container, nil, opts, {
		Image = "logoLarge",
		Height = 120,
		ScaleType = Enum.ScaleType.Fit,
		Transparency = 0,
	})
	local o = self.Options
	local library = self.Library
	self.Text = o.Caption or ""

	local root = Util.create("Frame", {
		Name = "Image",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, o.Height + (o.Caption and 16 or 0)),
	})

	local frame = Util.create("Frame", {
		Name = "Frame",
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, o.Height),
		ClipsDescendants = true,
		Parent = root,
	})
	library.Theme:Bind(frame, { BackgroundColor3 = "Background" })
	library.Theme:Bind(Util.stroke(frame), { Color = "Border" })
	Util.corner(frame, 2)

	self.ImageLabel = Util.passive(Util.create("ImageLabel", {
		Name = "Picture",
		BackgroundTransparency = 1,
		ScaleType = o.ScaleType,
		ImageTransparency = o.Transparency,
		Size = UDim2.fromScale(1, 1),
		Parent = frame,
	}))
	if o.Color then
		library.Theme:Bind(self.ImageLabel, { ImageColor3 = o.Color })
	end
	self:SetImage(o.Image)

	if o.Caption then
		self.Label = Style.label(library, {
			Text = o.Caption,
			TextSize = Style.Tiny,
			Color = "TextMuted",
			XAlign = Enum.TextXAlignment.Center,
			Position = UDim2.fromOffset(0, o.Height + 2),
			Size = UDim2.new(1, 0, 0, 14),
			Parent = root,
		})
	end

	self:_mount(root)
	return self
end

function Image:SetImage(source)
	self.Value = source
	local assets = self.Assets
	if source == "logo" or source == "logoLarge" then
		self.ImageLabel.Image = assets:Texture(source)
		self.ImageLabel.ImageRectOffset = Vector2.zero
		self.ImageLabel.ImageRectSize = Vector2.zero
		return
	end
	-- URL downloads can yield; keep construction instant
	task.spawn(function()
		assets:ApplyIcon(self.ImageLabel, source)
	end)
end

Image.SetValue = Image.SetImage

function Image:_serialize()
	return nil
end

return Image
