--[[
	Intro
	Boot screen shown while textures are forged and fonts are fetched. The
	thorn eye opens, the name decodes, a fuse burns across with live status,
	then everything collapses into a line and blinks out.
	Purely decorative: never blocks the game's input.
]]

local Util = import("core/Util")
local Anim = import("core/Anim")
local Scramble = import("fx/Scramble")
local Style = import("components/Style")

local Intro = {}
Intro.__index = Intro

local MIN_TIME = 1.6

function Intro.new(library, layer, opts)
	opts = opts or {}
	local self = setmetatable({}, Intro)
	self.Library = library
	self.Started = os.clock()
	self.Progress = 0
	self.Title = opts.Title or "Hellspawn"

	local assets = library.Assets
	assets:Preload("bloom")
	assets:Preload("logoLarge")
	assets:Preload("spark")

	local root = Util.passive(Util.create("Frame", {
		Name = "Intro",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(360, 300),
		ZIndex = 60,
		Parent = layer,
	}))
	self.Root = root
	Util.create("UIScale", { Scale = library.Scale, Parent = root })

	self.Backdrop = Util.passive(Util.create("ImageLabel", {
		Name = "Backdrop",
		BackgroundTransparency = 1,
		Image = assets:Texture("bloom"),
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(900, 760),
		ZIndex = 60,
		Parent = root,
	}))
	self.Halo = Util.passive(Util.create("ImageLabel", {
		Name = "Halo",
		BackgroundTransparency = 1,
		Image = assets:Texture("bloom"),
		ImageTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(180, 92),
		Size = UDim2.fromOffset(300, 300),
		ZIndex = 61,
		Parent = root,
	}))
	library.Theme:Bind(self.Halo, { ImageColor3 = "Accent" })

	self.Logo = Util.passive(Util.create("ImageLabel", {
		Name = "Logo",
		BackgroundTransparency = 1,
		Image = assets:Texture("logoLarge"),
		ImageTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromOffset(180, 92),
		Size = UDim2.fromOffset(170, 0),
		ZIndex = 62,
		Parent = root,
	}))
	library.Theme:Bind(self.Logo, { ImageColor3 = "Text" })

	self.Name = Style.label(library, {
		Name = "Title",
		Text = "",
		Role = "Display",
		TextSize = 44,
		Color = "Text",
		XAlign = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 168),
		Size = UDim2.new(1, 0, 0, 46),
		ZIndex = 62,
		Parent = root,
	})
	self.Name.TextTransparency = 1

	self.Track = Util.passive(Util.create("Frame", {
		Name = "Track",
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0),
		Position = UDim2.fromOffset(180, 228),
		Size = UDim2.fromOffset(0, 1),
		ZIndex = 62,
		Parent = root,
	}))
	library.Theme:Bind(self.Track, { BackgroundColor3 = "BorderLight" })
	self.Fill = Util.passive(Util.create("Frame", {
		Name = "Fill",
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(0, 0, 0, 2),
		Position = UDim2.fromOffset(0, -1),
		ZIndex = 63,
		Parent = self.Track,
	}))
	library.Theme:Bind(Util.gradient(self.Fill), { Color = "AccentGradient" })
	self.Spark = Util.passive(Util.create("ImageLabel", {
		Name = "Spark",
		BackgroundTransparency = 1,
		Image = assets:Texture("spark"),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(22, 22),
		ZIndex = 64,
		Parent = self.Fill,
	}))
	library.Theme:Bind(self.Spark, { ImageColor3 = "Accent" })

	self.Status = Style.label(library, {
		Name = "Status",
		Text = "",
		TextSize = Style.Tiny,
		Color = "TextMuted",
		XAlign = Enum.TextXAlignment.Center,
		Position = UDim2.fromOffset(0, 238),
		Size = UDim2.new(1, 0, 0, 14),
		ZIndex = 62,
		Parent = root,
	})
	return self
end

function Intro:Play()
	local library = self.Library
	Anim.tween(self.Backdrop, { ImageTransparency = 0.3 }, 0.5)
	Anim.tween(self.Halo, { ImageTransparency = 0.8 }, 0.9)
	Anim.tween(self.Logo, { ImageTransparency = 0, Size = UDim2.fromOffset(170, 170) }, 0.7, Enum.EasingStyle.Back)
	Anim.tween(self.Track, { Size = UDim2.fromOffset(210, 1) }, 0.5, Enum.EasingStyle.Quint)
	task.delay(0.25, function()
		self.Name.TextTransparency = 0
		Scramble.play(self.Name, self.Title, { Duration = 0.9, Enabled = library.Settings.Animations })
	end)
	self._spin = Anim.frame(function(_, now)
		self.Halo.ImageTransparency = 0.78 + 0.06 * math.sin(now * 3)
		self.Logo.Rotation = math.sin(now * 0.8) * 2
	end)
end

function Intro:SetProgress(fraction, label)
	self.Progress = math.max(self.Progress, fraction)
	Anim.tween(self.Fill, { Size = UDim2.new(self.Progress, 0, 0, 2) }, 0.2, Enum.EasingStyle.Quad)
	if label then
		self.Status.Text = string.lower(label)
	end
end

-- Refreshes fonts after the real families have loaded
function Intro:RefreshFonts()
	self.Name.FontFace = self.Library.Assets:Font("Display")
	self.Status.FontFace = self.Library.Assets:Font("Body")
end

-- Yields until the outro has played
function Intro:Finish()
	self:SetProgress(1, "ready")
	local elapsed = os.clock() - self.Started
	if elapsed < MIN_TIME then
		task.wait(MIN_TIME - elapsed)
	end
	task.wait(0.2)
	-- the eye blinks shut, everything folds into the fuse line, then out
	Anim.tween(self.Logo, { Size = UDim2.fromOffset(170, 2), ImageTransparency = 0.4 }, 0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
	Anim.tween(self.Name, { TextTransparency = 1 }, 0.2)
	Anim.tween(self.Status, { TextTransparency = 1 }, 0.2)
	Anim.tween(self.Halo, { ImageTransparency = 1 }, 0.3)
	task.wait(0.18)
	Anim.tween(self.Track, { Size = UDim2.fromOffset(0, 1) }, 0.25, Enum.EasingStyle.Quint, Enum.EasingDirection.In)
	Anim.tween(self.Backdrop, { ImageTransparency = 1 }, 0.3)
	Anim.tween(self.Logo, { ImageTransparency = 1 }, 0.2)
	task.wait(0.28)
	self:Destroy()
end

function Intro:Destroy()
	if self._spin then
		self._spin()
	end
	if self.Root then
		self.Root:Destroy()
		self.Root = nil
	end
end

return Intro
