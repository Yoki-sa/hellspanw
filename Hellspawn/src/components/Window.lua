--[[
	Window
	The main ImGui-style frame.

	┌─ thorn spikes ─────────────────────────────────────────────┐
	│ ◉ Hellspawn        // subtitle             [search]   – ×  │ topbar
	├────────────┬───────────────────────────────────────────────┤
	│  MODULES   │  Heading                                       │
	│ ▌⌖ Combat  │  ┌ GROUP ──────────┐  ┌ GROUP ──────────┐      │
	│  ◎ Visuals │  │ [■] toggle      │  │ ───────●─── 90  │      │
	│            │  └─────────────────┘  └─────────────────┘      │
	│  ◍ user    │                                                │
	├────────────┴───────────────────────────────────────────────┤
	│ ✦ hellspawn v1.0.0                   fps 144 · 32ms · time │ statusbar
	└────────────────────────────────────────────────────────────┘

	Effects: CRT power-on/off, film grain + scratches, vignette, scanlines,
	embers, halftone print, chromatic glitch title, breathing neon halo.
	Dragging is spring-smoothed and never blocks game input.
]]

local Env = import("core/Env")
local Util = import("core/Util")
local Anim = import("core/Anim")
local Input = import("core/Input")
local Maid = import("core/Maid")
local Motion = import("core/Motion")
local Glow = import("fx/Glow")
local GlitchText = import("fx/GlitchText")
local Embers = import("fx/Embers")
local Scramble = import("fx/Scramble")
local Style = import("components/Style")
local Tab = import("components/Tab")

local Window = {}
Window.__index = Window

local TOPBAR = Style.Topbar
local STATUS = Style.Statusbar
local SIDEBAR = Style.Sidebar
local USER = 56
local TAB_BUTTON = 32
local TAB_GAP = 2

local LINE_FADE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.55, 0.35),
	NumberSequenceKeypoint.new(1, 1),
})

function Window.new(library, opts)
	opts = Util.defaults(opts, {
		Title = "Hellspawn",
		Subtitle = nil,
		Width = 720,
		Height = 500,
		MinWidth = 600,
		MinHeight = 400,
		ToggleKey = Enum.KeyCode.RightShift,
		Resizable = true,
		Center = true,
		ShowUser = true,
		Background = nil,
		BackgroundTransparency = 0.92,
	})
	if typeof(opts.Size) == "UDim2" then
		opts.Width, opts.Height = opts.Size.X.Offset, opts.Size.Y.Offset
	elseif typeof(opts.Size) == "Vector2" then
		opts.Width, opts.Height = opts.Size.X, opts.Size.Y
	end

	local self = setmetatable({}, Window)
	self.Library = library
	self.Options = opts
	self.Tabs = {}
	self.ActiveTab = nil
	self.Size = Vector2.new(math.max(opts.Width, opts.MinWidth), math.max(opts.Height, opts.MinHeight))
	self.Visible = false
	self.Minimized = false
	self.ToggleKey = opts.ToggleKey
	self.Query = ""
	self.Maid = Maid.new()
	self._animToken = 0
	self._clipMode = "top"

	self:_build()
	self:_bindDrag()
	self:_bindResize()
	self:_bindKeys()
	self:_bindEffects()
	return self
end

----------------------------------------------------------------------
-- construction
----------------------------------------------------------------------

function Window:_build()
	local library = self.Library
	local theme = library.Theme
	local assets = library.Assets
	local opts = self.Options
	local viewport = Util.viewport()
	local scale = library.Scale

	local position = opts.Position
	local start
	if typeof(position) == "UDim2" then
		start = Vector2.new(position.X.Offset, position.Y.Offset)
	elseif typeof(position) == "Vector2" then
		start = position
	else
		start = (viewport - self.Size * scale) / 2
	end
	self.Position = start

	local root = Util.create("Frame", {
		Name = "Window",
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(self.Size.X, self.Size.Y),
		Position = UDim2.fromOffset(start.X, start.Y),
		Visible = false,
		Parent = library.Layers.Windows,
	})
	self.Root = root
	self.Maid:Give(root)
	self.UIScale = Util.create("UIScale", { Scale = scale, Parent = root })

	-- drop shadow
	local shadowMeta = assets:Meta("shadow")
	self.Shadow = Util.passive(Util.create("ImageLabel", {
		Name = "Shadow",
		BackgroundTransparency = 1,
		Image = assets:Texture("shadow"),
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.2,
		ScaleType = Enum.ScaleType.Slice,
		SliceCenter = Rect.new(shadowMeta.Pad, shadowMeta.Pad, shadowMeta.Size - shadowMeta.Pad, shadowMeta.Size - shadowMeta.Pad),
		SliceScale = 1,
		Size = UDim2.new(1, shadowMeta.Pad * 2, 1, shadowMeta.Pad * 2),
		Position = UDim2.fromOffset(-shadowMeta.Pad, -shadowMeta.Pad + 10),
		ZIndex = 0,
		Parent = root,
	}))

	-- breathing neon halo around the whole frame
	self.Halo = Glow.attach(library, root, { Wide = true, Spread = 30, Strength = 0.16, ZIndex = 0 })

	self:_buildSpikes(root)

	-- CRT flash line (outside the clip so it can draw while the body is closed)
	self.Flash = Util.passive(Util.create("Frame", {
		Name = "Flash",
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(0, 0, 0, 2),
		BorderSizePixel = 0,
		Visible = false,
		ZIndex = 6,
		Parent = root,
	}))
	theme:Bind(self.Flash, { BackgroundColor3 = "Text" })
	local flashBeam = Util.passive(Util.create("ImageLabel", {
		Name = "Beam",
		BackgroundTransparency = 1,
		Image = assets:Texture("beam"),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.new(1, 40, 0, 40),
		ImageTransparency = 0.1,
		ZIndex = 6,
		Parent = self.Flash,
	}))
	theme:Bind(flashBeam, { ImageColor3 = "Accent" })

	local clip = Util.create("Frame", {
		Name = "Clip",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		ZIndex = 1,
		Parent = root,
	})
	self.Clip = clip

	local body = Util.create("Frame", {
		Name = "Body",
		BorderSizePixel = 0,
		Active = true, -- clicks on the window never reach the game
		ClipsDescendants = true,
		ZIndex = 1,
		Parent = clip,
	})
	theme:Bind(body, { BackgroundColor3 = "Background" })
	self.Body = body
	self:_layoutClip("top")

	self:_buildBackdrop(body)
	self:_buildTopbar(body)
	self:_buildSidebar(body)
	self:_buildPages(body)
	self:_buildStatusbar(body)
	self:_buildOverlays(body)
end

function Window:_buildSpikes(root)
	local library = self.Library
	local assets = library.Assets
	self.Spikes = {}
	if not assets:Has("spike") then
		return
	end
	local corners = {
		{ 0, 0, 315 },
		{ 1, 0, 45 },
		{ 1, 1, 135 },
		{ 0, 1, 225 },
	}
	local fan = { { -24, 12 }, { 0, 19 }, { 24, 10 }, { -48, 7 }, { 46, 7 } }
	for _, corner in corners do
		for _, spec in fan do
			local angle = corner[3] + spec[1]
			local length = spec[2]
			local rad = math.rad(angle)
			local dx, dy = math.sin(rad), -math.cos(rad)
			local reach = length / 2 - 3
			local spike = Util.passive(Util.create("ImageLabel", {
				Name = "Spike",
				BackgroundTransparency = 1,
				Image = assets:Texture("spike"),
				AnchorPoint = Vector2.new(0.5, 0.5),
				Rotation = angle,
				Position = UDim2.new(corner[1], dx * reach, corner[2], dy * reach),
				Size = UDim2.fromOffset(length / 3, length),
				ImageTransparency = 0.05,
				ZIndex = 0,
				Parent = root,
			}))
			library.Theme:Bind(spike, { ImageColor3 = "BorderLight" })
			table.insert(self.Spikes, { image = spike, length = length, dx = dx, dy = dy, corner = corner })
		end
	end
end

function Window:_buildBackdrop(body)
	local library = self.Library
	local assets = library.Assets
	local theme = library.Theme
	local opts = self.Options

	if opts.Background then
		local image, offset, size = assets:Image(opts.Background)
		self.BackgroundImage = Util.passive(Util.create("ImageLabel", {
			Name = "Art",
			BackgroundTransparency = 1,
			Image = image,
			ImageRectOffset = offset or Vector2.zero,
			ImageRectSize = size or Vector2.zero,
			ScaleType = Enum.ScaleType.Crop,
			ImageTransparency = opts.BackgroundTransparency,
			Size = UDim2.fromScale(1, 1),
			ZIndex = 1,
			Parent = body,
		}))
	end

	self.Vignette = Util.passive(Util.create("ImageLabel", {
		Name = "Vignette",
		BackgroundTransparency = 1,
		Image = assets:Texture("vignette"),
		ImageColor3 = Color3.new(0, 0, 0),
		ImageTransparency = 0.3,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = body,
	}))

	-- big faded sigil watermark in the content corner
	local sigil = Util.passive(Util.create("ImageLabel", {
		Name = "Sigil",
		BackgroundTransparency = 1,
		Image = assets:Texture("logoLarge"),
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, 60, 1, 40),
		Size = UDim2.fromOffset(300, 300),
		ImageTransparency = 0.965,
		Rotation = -12,
		ZIndex = 1,
		Parent = body,
	}))
	theme:Bind(sigil, { ImageColor3 = "Text" })

	self.EmberLayer = Util.passive(Util.create("Frame", {
		Name = "Embers",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 1,
		Parent = body,
	}))
	if assets:Has("spark") then
		self.Embers = Embers.new(library, self.EmberLayer, { Count = 20 })
		self.Maid:Give(self.Embers)
	end
end

function Window:_buildTopbar(body)
	local library = self.Library
	local theme = library.Theme
	local assets = library.Assets
	local opts = self.Options

	local topbar = Util.create("Frame", {
		Name = "Topbar",
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, TOPBAR),
		ZIndex = 3,
		Parent = body,
	})
	theme:Bind(topbar, { BackgroundColor3 = "Panel" })
	self.Topbar = topbar

	if assets:Has("halftone") then
		local halftone = Util.passive(Util.create("ImageLabel", {
			Name = "Halftone",
			BackgroundTransparency = 1,
			Image = assets:Texture("halftone"),
			AnchorPoint = Vector2.new(1, 0),
			Position = UDim2.fromScale(1, 0),
			Size = UDim2.new(0, 340, 1, 0),
			Rotation = 180,
			ImageTransparency = 0.9,
			ZIndex = 3,
			Parent = topbar,
		}))
		theme:Bind(halftone, { ImageColor3 = "Accent" })
	end

	-- emblem
	local emblem = Util.passive(Util.create("Frame", {
		Name = "Emblem",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(34, 34),
		ZIndex = 4,
		Parent = topbar,
	}))
	self.LogoBloom = Util.passive(Util.create("ImageLabel", {
		Name = "Bloom",
		BackgroundTransparency = 1,
		Image = assets:Texture("bloom"),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(70, 70),
		ImageTransparency = 0.78,
		ZIndex = 4,
		Parent = emblem,
	}))
	theme:Bind(self.LogoBloom, { ImageColor3 = "Accent" })
	self.Logo = Util.passive(Util.create("ImageLabel", {
		Name = "Logo",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 5,
		Parent = emblem,
	}))
	if opts.Logo then
		assets:ApplyIcon(self.Logo, opts.Logo)
	else
		self.Logo.Image = assets:Texture("logo")
	end
	theme:Bind(self.Logo, { ImageColor3 = "Text" })

	-- title + subtitle
	self.Title = GlitchText.new(library, {
		Text = opts.Title,
		Font = library.Assets:Font("Display"),
		TextSize = 25,
		Position = UDim2.fromOffset(52, 1),
		ZIndex = 4,
		Parent = topbar,
	})
	self.Maid:Give(self.Title)
	self.Subtitle = Style.label(library, {
		Name = "Subtitle",
		Text = opts.Subtitle or ("// v" .. library.Version),
		TextSize = Style.Tiny,
		Color = "TextMuted",
		Position = UDim2.fromOffset(53, 27),
		Size = UDim2.new(0, 260, 0, 12),
		Truncate = true,
		ZIndex = 4,
		Parent = topbar,
	})

	-- search
	local search, searchStroke = Style.surface(library, {
		Name = "Search",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -66, 0.5, 0),
		Size = UDim2.fromOffset(186, 24),
		Fill = "Background",
		ZIndex = 4,
		Parent = topbar,
	})
	self.Search = search
	local searchGlow = Glow.attach(library, search, { Spread = 9, Strength = 0, ZIndex = 4 })
	Style.icon(library, {
		Icon = "search",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 8, 0.5, 0),
		Size = UDim2.fromOffset(11, 11),
		Color = "TextMuted",
		ZIndex = 5,
		Parent = search,
	})
	local query = Util.create("TextBox", {
		Name = "Query",
		BackgroundTransparency = 1,
		ClearTextOnFocus = false,
		PlaceholderText = "search...",
		Text = "",
		FontFace = Style.font(library, "Regular"),
		TextSize = Style.Small,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(25, 0),
		Size = UDim2.new(1, -46, 1, 0),
		ClipsDescendants = true,
		ZIndex = 5,
		Parent = search,
	})
	theme:Bind(query, { TextColor3 = "Text", PlaceholderColor3 = "TextMuted" })
	self.QueryBox = query
	local clear = Util.create("ImageButton", {
		Name = "Clear",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -6, 0.5, 0),
		Size = UDim2.fromOffset(10, 10),
		Visible = false,
		ZIndex = 6,
		Parent = search,
	})
	assets:ApplyIcon(clear, "close")
	theme:Bind(clear, { ImageColor3 = "TextMuted" })
	clear.Activated:Connect(function()
		query.Text = ""
	end)
	query.Focused:Connect(function()
		Anim.tween(searchStroke, { Color = theme:Get("Accent") }, 0.15)
		Glow.set(searchGlow, 0.4)
	end)
	query.FocusLost:Connect(function()
		Anim.tween(searchStroke, { Color = theme:Get("Border") }, 0.15)
		Glow.set(searchGlow, 0)
	end)
	query:GetPropertyChangedSignal("Text"):Connect(function()
		clear.Visible = query.Text ~= ""
		self:_search(query.Text)
	end)

	-- window buttons
	local function control(name, icon, x, hoverKey, onClick)
		local button = Util.create("ImageButton", {
			Name = name,
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, x, 0.5, 0),
			Size = UDim2.fromOffset(22, 22),
			ZIndex = 5,
			Parent = topbar,
		})
		local image = Style.icon(library, {
			Icon = icon,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Position = UDim2.fromScale(0.5, 0.5),
			Size = UDim2.fromOffset(11, 11),
			ZIndex = 6,
			Parent = button,
		})
		image.ImageColor3 = theme:Get("TextMuted")
		Input.hover(button, function(state)
			Anim.tween(image, { ImageColor3 = theme:Get(state and hoverKey or "TextMuted") }, 0.15)
		end)
		button.Activated:Connect(onClick)
		self.Maid:Give(theme.Changed:Connect(function()
			image.ImageColor3 = theme:Get("TextMuted")
		end))
		return button
	end
	self.MinimizeButton = control("Minimize", "minus", -36, "Text", function()
		self:SetMinimized(not self.Minimized)
	end)
	self.CloseButton = control("Close", "close", -10, "Accent", function()
		self:SetVisible(false)
		library:Notify({
			Title = "Hidden",
			Content = "Press " .. Util.keyName(self.ToggleKey) .. " to bring the menu back.",
			Duration = 3,
		})
	end)

	-- accent rule with a travelling glint
	local line = Util.passive(Util.create("Frame", {
		Name = "Rule",
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = UDim2.new(0, 0, 1, -1),
		Size = UDim2.new(1, 0, 0, 1),
		ZIndex = 5,
		Parent = topbar,
	}))
	theme:Bind(Util.gradient(line, { Transparency = LINE_FADE }), { Color = "AccentGradient" })
	self.Glint = Util.passive(Util.create("ImageLabel", {
		Name = "Glint",
		BackgroundTransparency = 1,
		Image = assets:Texture("beam"),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0.2, 0, 1, 0),
		Size = UDim2.new(0.35, 0, 0, 18),
		ImageTransparency = 0.45,
		ZIndex = 5,
		Parent = topbar,
	}))
	theme:Bind(self.Glint, { ImageColor3 = "Accent" })
end

function Window:_buildSidebar(body)
	local library = self.Library
	local theme = library.Theme
	local opts = self.Options
	local userHeight = opts.ShowUser and USER or 0

	local sidebar = Util.create("Frame", {
		Name = "Sidebar",
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, TOPBAR),
		Size = UDim2.new(0, SIDEBAR, 1, -(TOPBAR + STATUS)),
		ZIndex = 3,
		Parent = body,
	})
	theme:Bind(sidebar, { BackgroundColor3 = "Panel" })
	self.Sidebar = sidebar

	local edge = Util.passive(Util.create("Frame", {
		Name = "Edge",
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.fromScale(1, 0),
		Size = UDim2.new(0, 1, 1, 0),
		ZIndex = 4,
		Parent = sidebar,
	}))
	theme:Bind(edge, { BackgroundColor3 = "Border" })

	Style.label(library, {
		Name = "Caption",
		Text = "MODULES",
		Weight = "Bold",
		TextSize = Style.Tiny,
		Color = "TextMuted",
		Position = UDim2.fromOffset(16, 8),
		Size = UDim2.new(1, -32, 0, 14),
		ZIndex = 4,
		Parent = sidebar,
	})

	local scroller = Util.create("ScrollingFrame", {
		Name = "Tabs",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 28),
		Size = UDim2.new(1, 0, 1, -(28 + userHeight + 8)),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 0,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ZIndex = 4,
		Parent = sidebar,
	})
	self.TabScroller = scroller

	local list = Util.create("Frame", {
		Name = "List",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 4,
		Parent = scroller,
	})
	Util.list(list, { Padding = TAB_GAP })
	Util.padding(list, 0, 10, 0, 8)
	self.TabList = list

	local indicator = Util.passive(Util.create("Frame", {
		Name = "Indicator",
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, 7),
		Size = UDim2.fromOffset(3, 18),
		ZIndex = 7,
		Parent = scroller,
	}))
	theme:Bind(indicator, { BackgroundColor3 = "Accent" })
	Glow.attach(library, indicator, { Spread = 10, Strength = 0.7, ZIndex = 7 })
	self.Indicator = indicator
	self.IndicatorSpring = Motion.spring(7, { Frequency = 5.5, Damping = 0.72 }, function(y)
		indicator.Position = UDim2.fromOffset(0, y)
	end)
	self.Maid:Give(self.IndicatorSpring)

	if opts.ShowUser then
		self:_buildUserCard(sidebar, userHeight)
	end
end

function Window:_buildUserCard(sidebar, height)
	local library = self.Library
	local theme = library.Theme
	local Players = Env.service("Players")
	local player = Players.LocalPlayer

	if library.Assets:Has("vine") then
		local meta = library.Assets:Meta("vine")
		local vine = Util.passive(Util.create("ImageLabel", {
			Name = "Vine",
			BackgroundTransparency = 1,
			Image = library.Assets:Texture("vine"),
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(meta.Width / 2, meta.Height / 2),
			AnchorPoint = Vector2.new(0, 1),
			Position = UDim2.new(0, 10, 1, -height),
			Size = UDim2.new(1, -20, 0, meta.Height / 2),
			ZIndex = 4,
			Parent = sidebar,
		}))
		theme:Bind(vine, { ImageColor3 = "BorderLight" })
		Util.gradient(vine, {
			Transparency = NumberSequence.new({
				NumberSequenceKeypoint.new(0, 1),
				NumberSequenceKeypoint.new(0.2, 0.2),
				NumberSequenceKeypoint.new(0.8, 0.2),
				NumberSequenceKeypoint.new(1, 1),
			}),
		})
	end

	local card = Util.create("Frame", {
		Name = "User",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, height),
		ZIndex = 4,
		Parent = sidebar,
	})

	local avatar = Util.passive(Util.create("ImageLabel", {
		Name = "Avatar",
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 14, 0.5, 0),
		Size = UDim2.fromOffset(30, 30),
		Image = player and string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", player.UserId) or "",
		ZIndex = 5,
		Parent = card,
	}))
	theme:Bind(avatar, { BackgroundColor3 = "Surface" })
	Util.corner(avatar, 15)
	local ring = Util.stroke(avatar, { Thickness = 1 })
	theme:Bind(ring, { Color = "Accent" })
	local avatarGlow = Util.passive(Util.create("ImageLabel", {
		Name = "Glow",
		BackgroundTransparency = 1,
		Image = library.Assets:Texture("bloom"),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(0, 29, 0.5, 0),
		Size = UDim2.fromOffset(58, 58),
		ImageTransparency = 0.8,
		ZIndex = 4,
		Parent = card,
	}))
	theme:Bind(avatarGlow, { ImageColor3 = "Accent" })

	Style.label(library, {
		Name = "Name",
		Text = player and player.DisplayName or "unknown",
		Weight = "Bold",
		Color = "Text",
		Position = UDim2.fromOffset(52, 12),
		Size = UDim2.new(1, -72, 0, 14),
		Truncate = true,
		ZIndex = 5,
		Parent = card,
	})
	Style.label(library, {
		Name = "Handle",
		Text = player and ("@" .. player.Name) or "",
		TextSize = Style.Tiny,
		Color = "TextMuted",
		Position = UDim2.fromOffset(52, 28),
		Size = UDim2.new(1, -72, 0, 12),
		Truncate = true,
		ZIndex = 5,
		Parent = card,
	})
	self.StatusDot = Util.passive(Util.create("Frame", {
		Name = "Pulse",
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -14, 0.5, 0),
		Size = UDim2.fromOffset(5, 5),
		ZIndex = 5,
		Parent = card,
	}))
	Util.corner(self.StatusDot, 3)
	theme:Bind(self.StatusDot, { BackgroundColor3 = "Accent" })
	self.StatusGlow = Glow.attach(library, self.StatusDot, { Spread = 6, Strength = 0.6, ZIndex = 5 })
end

function Window:_buildPages(body)
	local library = self.Library
	local theme = library.Theme
	local pages = Util.create("Frame", {
		Name = "Pages",
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		Position = UDim2.fromOffset(SIDEBAR, TOPBAR),
		Size = UDim2.new(1, -SIDEBAR, 1, -(TOPBAR + STATUS)),
		ZIndex = 2,
		Parent = body,
	})
	self.Pages = pages

	self.Sweep = Util.passive(Util.create("ImageLabel", {
		Name = "Sweep",
		BackgroundTransparency = 1,
		Image = library.Assets:Texture("beam"),
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, -0.1),
		Size = UDim2.new(1, 0, 0, 28),
		ImageTransparency = 1,
		ZIndex = 9,
		Parent = pages,
	}))
	theme:Bind(self.Sweep, { ImageColor3 = "Accent" })
end

function Window:_buildStatusbar(body)
	local library = self.Library
	local theme = library.Theme
	local status = Util.create("Frame", {
		Name = "Statusbar",
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, STATUS),
		ZIndex = 3,
		Parent = body,
	})
	theme:Bind(status, { BackgroundColor3 = "Panel" })
	local rule = Util.passive(Util.create("Frame", {
		Name = "Rule",
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
		ZIndex = 4,
		Parent = status,
	}))
	theme:Bind(rule, { BackgroundColor3 = "Border" })

	Style.icon(library, {
		Icon = "sigil",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(9, 9),
		Color = "Accent",
		ZIndex = 4,
		Parent = status,
	})
	self.StatusLeft = Style.label(library, {
		Name = "Left",
		Rich = true,
		TextSize = Style.Tiny,
		Color = "TextDim",
		Position = UDim2.fromOffset(27, 0),
		Size = UDim2.new(0.5, -27, 1, 0),
		Truncate = true,
		ZIndex = 4,
		Parent = status,
	})
	self.StatusRight = Style.label(library, {
		Name = "Right",
		Rich = true,
		TextSize = Style.Tiny,
		Color = "TextDim",
		XAlign = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -24, 0, 0),
		Size = UDim2.new(0.5, -24, 1, 0),
		ZIndex = 4,
		Parent = status,
	})

	if self.Options.Resizable then
		local grip = Util.create("ImageButton", {
			Name = "Grip",
			BackgroundTransparency = 1,
			AutoButtonColor = false,
			AnchorPoint = Vector2.new(1, 1),
			Position = UDim2.new(1, -3, 1, -3),
			Size = UDim2.fromOffset(12, 12),
			ZIndex = 8,
			Parent = status,
		})
		library.Assets:ApplyIcon(grip, "grip")
		grip.ImageColor3 = theme:Get("TextMuted")
		Input.hover(grip, function(state)
			Anim.tween(grip, { ImageColor3 = theme:Get(state and "Accent" or "TextMuted") }, 0.15)
		end)
		self.Grip = grip
	end
	self:_renderStatus(0, 0)
end

function Window:_buildOverlays(body)
	local library = self.Library
	local theme = library.Theme
	local assets = library.Assets

	local noise = assets:Meta("noise")
	self.Grain = Util.passive(Util.create("ImageLabel", {
		Name = "Grain",
		BackgroundTransparency = 1,
		Image = assets:Texture("noise1"),
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(noise.Size, noise.Size),
		Size = UDim2.new(1, noise.Size, 1, noise.Size),
		ImageTransparency = 1 - theme:Get("Grain"),
		ZIndex = 20,
		Parent = body,
	}))

	local scratchMeta = assets:Meta("scratches")
	self.Scratches = Util.passive(Util.create("ImageLabel", {
		Name = "Scratches",
		BackgroundTransparency = 1,
		Image = assets:Texture("scratches"),
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(scratchMeta.Size, scratchMeta.Size),
		Size = UDim2.new(1, scratchMeta.Size, 1, scratchMeta.Size),
		ImageTransparency = 1 - theme:Get("Scratches"),
		ZIndex = 21,
		Parent = body,
	}))

	local lines = assets:Meta("scanlines")
	self.Scanlines = Util.passive(Util.create("ImageLabel", {
		Name = "Scanlines",
		BackgroundTransparency = 1,
		Image = assets:Texture("scanlines"),
		ImageColor3 = Color3.new(0, 0, 0),
		ScaleType = Enum.ScaleType.Tile,
		TileSize = UDim2.fromOffset(lines.Width, lines.Height),
		Size = UDim2.fromScale(1, 1),
		ImageTransparency = 0.82,
		ZIndex = 22,
		Parent = body,
	}))

	self.Maid:Give(theme.Changed:Connect(function(palette)
		self.Grain.ImageTransparency = 1 - palette.Grain
		self.Scratches.ImageTransparency = 1 - palette.Scratches
	end))

	-- skeet-style gradient crown line on the very top edge
	local crown = Util.passive(Util.create("Frame", {
		Name = "Crown",
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Size = UDim2.new(1, 0, 0, 2),
		ZIndex = 30,
		Parent = body,
	}))
	theme:Bind(Util.gradient(crown), { Color = "AccentGradient" })
	Glow.attach(library, crown, { Spread = 8, Strength = 0.35, ZIndex = 30 })

	-- crisp outline + faint inner bevel
	local outline = Util.passive(Util.create("Frame", {
		Name = "Outline",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(1, 1),
		Size = UDim2.new(1, -2, 1, -2),
		ZIndex = 31,
		Parent = body,
	}))
	theme:Bind(Util.stroke(outline), { Color = "BorderLight" })
	local bevel = Util.passive(Util.create("Frame", {
		Name = "Bevel",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(2, 2),
		Size = UDim2.new(1, -4, 1, -4),
		ZIndex = 31,
		Parent = body,
	}))
	local bevelStroke = Util.stroke(bevel)
	bevelStroke.Color = Color3.new(1, 1, 1)
	bevelStroke.Transparency = 0.96
end

----------------------------------------------------------------------
-- layout helpers
----------------------------------------------------------------------

-- "top": normal; "center": body centred in a vertically scaled clip (CRT)
function Window:_layoutClip(mode, fraction)
	local clip, body = self.Clip, self.Body
	self._clipMode = mode
	if mode == "center" then
		clip.AnchorPoint = Vector2.new(0, 0.5)
		clip.Position = UDim2.fromScale(0, 0.5)
		clip.Size = UDim2.new(1, 0, fraction or 1, 0)
		body.AnchorPoint = Vector2.new(0, 0.5)
		body.Position = UDim2.fromScale(0, 0.5)
	else
		clip.AnchorPoint = Vector2.zero
		clip.Position = UDim2.new()
		clip.Size = UDim2.fromScale(1, 1)
		body.AnchorPoint = Vector2.zero
		body.Position = UDim2.new()
	end
	body.Size = UDim2.new(1, 0, 0, self.Size.Y)
end

function Window:_clampPosition(position)
	local viewport = Util.viewport()
	local scale = self.Library.Scale
	local width = self.Size.X * scale
	return Vector2.new(
		math.clamp(position.X, -width + 120, viewport.X - 120),
		math.clamp(position.Y, 0, viewport.Y - TOPBAR * scale)
	)
end

function Window:SetPosition(position, instant)
	position = self:_clampPosition(position)
	self.Position = position
	if not self._moveSpring then
		self._moveSpring = Motion.spring(position, { Frequency = 9, Damping = 0.92, Epsilon = 0.05 }, function(p)
			self.Root.Position = UDim2.fromOffset(math.floor(p.X + 0.5), math.floor(p.Y + 0.5))
		end)
		self.Maid:Give(self._moveSpring)
	end
	local smooth = self.Library.Settings.SmoothDrag and self.Library.Settings.Animations
	self._moveSpring:SetTarget(position, instant or not smooth)
end

function Window:SetSize(size)
	local opts = self.Options
	local viewport = Util.viewport() / self.Library.Scale
	size = Vector2.new(
		math.clamp(size.X, opts.MinWidth, math.max(opts.MinWidth, viewport.X - 20)),
		math.clamp(size.Y, opts.MinHeight, math.max(opts.MinHeight, viewport.Y - 20))
	)
	self.Size = size
	self.Root.Size = UDim2.fromOffset(size.X, self.Minimized and TOPBAR or size.Y)
	self.Body.Size = UDim2.new(1, 0, 0, size.Y)
end

----------------------------------------------------------------------
-- behaviour
----------------------------------------------------------------------

function Window:_bindDrag()
	local startPosition
	self.Maid:Give((Input.drag(self.Topbar, {
		canStart = function(io)
			local point = Input.position(io)
			if Input.within(self.Search, point) then
				return false
			end
			if Input.within(self.MinimizeButton, point) or Input.within(self.CloseButton, point) then
				return false
			end
			return true
		end,
		onStart = function()
			startPosition = self.Position
			self.Library.Popups:Close()
			self.Dragging = true
		end,
		onMove = function(_, delta)
			self:SetPosition(startPosition + delta)
		end,
		onEnd = function()
			self.Dragging = false
		end,
	})))
end

function Window:_bindResize()
	if not self.Grip then
		return
	end
	local startSize
	self.Maid:Give((Input.drag(self.Grip, {
		canStart = function()
			return not self.Minimized
		end,
		onStart = function()
			startSize = self.Size
			self.Library.Popups:Close()
		end,
		onMove = function(_, delta)
			self:SetSize(startSize + delta / self.Library.Scale)
		end,
	})))
end

function Window:_bindKeys()
	self.Maid:Give(Input.Began:Connect(function(io)
		if io.UserInputType ~= Enum.UserInputType.Keyboard or io.KeyCode ~= self.ToggleKey then
			return
		end
		if Input.isTyping() or self.Library._picking then
			return
		end
		self:Toggle()
	end))
end

function Window:_bindEffects()
	local library = self.Library
	local settings = library.Settings
	local grainFrame, grainClock, scratchClock = 1, 0, 0
	local blinkAt = os.clock() + 5 + math.random() * 6
	local frames, statClock = 0, 0
	local noise = library.Assets:Meta("noise")
	local scratchSize = library.Assets:Meta("scratches").Size

	self.Maid:Give(Anim.frame(function(dt, now)
		frames += 1
		statClock += dt
		if statClock >= 0.5 then
			self:_renderStatus(frames / statClock)
			frames, statClock = 0, 0
		end
		if not self.Visible then
			return
		end

		-- film grain: cycle frames and jump the tile around
		if settings.Grain then
			grainClock += dt
			if grainClock > 1 / 18 then
				grainClock = 0
				grainFrame = grainFrame % noise.Frames + 1
				self.Grain.Image = library.Assets:Texture("noise" .. grainFrame)
				self.Grain.Position = UDim2.fromOffset(-math.random(0, noise.Size), -math.random(0, noise.Size))
			end
		end
		if settings.Scratches then
			scratchClock += dt
			if scratchClock > 0.11 then
				scratchClock = 0
				self.Scratches.Position = UDim2.fromOffset(-math.random(0, scratchSize), -math.random(0, scratchSize))
			end
		end

		-- breathing halo
		if settings.Glow then
			Glow.set(self.Halo, 0.13 + 0.07 * math.sin(now * 1.4), 0)
		end
		if self.StatusGlow then
			Glow.set(self.StatusGlow, 0.35 + 0.35 * (0.5 + 0.5 * math.sin(now * 3)), 0)
		end

		-- glint travelling along the accent rule
		local sweep = (math.sin(now * 0.55) + 1) / 2
		self.Glint.Position = UDim2.new(0.08 + sweep * 0.84, 0, 1, 0)

		-- the eye blinks now and then
		if settings.Animations and now >= blinkAt then
			blinkAt = now + 6 + math.random() * 9
			Anim.tween(self.Logo, { Size = UDim2.fromScale(1, 0.08) }, 0.07, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.09, function()
				Anim.tween(self.Logo, { Size = UDim2.fromScale(1, 1) }, 0.16, Enum.EasingStyle.Back)
			end)
		end
		self.LogoBloom.ImageTransparency = 0.8 - 0.06 * math.sin(now * 2.1)
	end))

	self:_applySettings()
	self.Maid:Give(library.SettingChanged:Connect(function()
		self:_applySettings()
	end))
end

function Window:_applySettings()
	local settings = self.Library.Settings
	self.Grain.Visible = settings.Grain
	self.Scratches.Visible = settings.Scratches
	self.Scanlines.Visible = settings.Scanlines
	self.Vignette.Visible = settings.Vignette
	if self.Embers then
		self.Embers:SetEnabled(settings.Embers)
	end
	self.Title:SetEnabled(settings.Glitch)
	self.UIScale.Scale = self.Library.Scale
	Glow.set(self.Halo, settings.Glow and 0.16 or 0, 0)
end

function Window:_renderStatus(fps)
	local library = self.Library
	local theme = library.Theme
	local text = Util.toHex(theme:Get("Text"))
	local muted = Util.toHex(theme:Get("TextMuted"))
	local executor = library.Executor or "unknown"
	self.StatusLeft.Text = string.format(
		"<font color=\"#%s\">hellspawn</font> v%s <font color=\"#%s\">·</font> %s <font color=\"#%s\">· %s to hide</font>",
		text,
		library.Version,
		muted,
		Util.escape(string.lower(executor)),
		muted,
		Util.escape(Util.keyName(self.ToggleKey))
	)
	local ping = library:GetPing()
	self.StatusRight.Text = string.format(
		"fps <font color=\"#%s\">%d</font> <font color=\"#%s\">·</font> <font color=\"#%s\">%d</font>ms <font color=\"#%s\">·</font> %s",
		text,
		math.floor((fps or 0) + 0.5),
		muted,
		text,
		ping,
		muted,
		os.date("%H:%M:%S")
	)
end

function Window:_search(query)
	self.Query = query
	if self.ActiveTab then
		self.ActiveTab:_filter(query)
	end
end

----------------------------------------------------------------------
-- visibility / animation
----------------------------------------------------------------------

function Window:_setSpikes(progress, instant)
	for index, spike in self.Spikes do
		local size = UDim2.fromOffset(spike.length / 3 * progress, spike.length * progress)
		local reach = (spike.length / 2 - 3) * progress
		local position = UDim2.new(spike.corner[1], spike.dx * reach, spike.corner[2], spike.dy * reach)
		if instant then
			spike.image.Size = size
			spike.image.Position = position
		else
			task.delay((index % 5) * 0.025, function()
				Anim.tween(spike.image, { Size = size, Position = position }, 0.35, Enum.EasingStyle.Back)
			end)
		end
	end
end

function Window:SetVisible(visible)
	visible = visible ~= false
	if visible == self.Visible then
		return
	end
	self.Visible = visible
	self._animToken += 1
	local token = self._animToken
	local library = self.Library
	library.Popups:Close(true)
	library:_visibilityChanged()

	local root = self.Root
	local animate = library.Settings.Animations

	if visible then
		root.Visible = true
		if not animate or self.Minimized then
			self:_layoutClip("top")
			self.Flash.Visible = false
			self.Shadow.ImageTransparency = 0.2
			self:_setSpikes(1, true)
			return
		end
		-- CRT power-on: a hot line stretches across, then the picture opens
		self:_layoutClip("center", 0)
		self.Shadow.ImageTransparency = 1
		self:_setSpikes(0, true)
		self.Flash.Visible = true
		self.Flash.BackgroundTransparency = 0
		self.Flash.Size = UDim2.new(0, 0, 0, 2)
		Anim.tween(self.Flash, { Size = UDim2.new(1, 0, 0, 2) }, 0.16, Enum.EasingStyle.Quart)
		task.delay(0.15, function()
			if token ~= self._animToken then
				return
			end
			Anim.run(0.38, function(alpha)
				if token == self._animToken then
					self.Clip.Size = UDim2.new(1, 0, math.max(alpha, 0.004), 0)
				end
			end, Anim.ease.outQuint, function()
				if token == self._animToken then
					self:_layoutClip("top")
					self.Flash.Visible = false
				end
			end)
			Anim.tween(self.Flash, { BackgroundTransparency = 1 }, 0.3)
			Anim.tween(self.Shadow, { ImageTransparency = 0.2 }, 0.4)
			self:_setSpikes(1)
			self.Title:Burst(0.35)
			if self.ActiveTab then
				Scramble.play(self.ActiveTab.Heading, self.ActiveTab.Name, { Duration = 0.5 })
			end
		end)
	else
		if not animate or self.Minimized then
			root.Visible = false
			return
		end
		-- CRT power-off: collapse to a line, then to a dot
		self:_layoutClip("center", 1)
		Anim.run(0.2, function(alpha)
			if token == self._animToken then
				self.Clip.Size = UDim2.new(1, 0, math.max(1 - alpha, 0.004), 0)
			end
		end, function(t)
			return t * t
		end)
		Anim.tween(self.Shadow, { ImageTransparency = 1 }, 0.2)
		self:_setSpikes(0)
		task.delay(0.18, function()
			if token ~= self._animToken then
				return
			end
			self.Flash.Visible = true
			self.Flash.BackgroundTransparency = 0
			self.Flash.Size = UDim2.new(1, 0, 0, 2)
			Anim.tween(self.Flash, { Size = UDim2.new(0, 0, 0, 2), BackgroundTransparency = 0.3 }, 0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
			task.delay(0.15, function()
				if token == self._animToken then
					root.Visible = false
					self.Flash.Visible = false
					self:_layoutClip("top")
				end
			end)
		end)
	end
end

function Window:Toggle()
	self:SetVisible(not self.Visible)
end

function Window:SetMinimized(minimized)
	if minimized == self.Minimized then
		return
	end
	self.Minimized = minimized
	self.Library.Popups:Close()
	self:_layoutClip("top")
	local height = minimized and TOPBAR or self.Size.Y
	Anim.tween(self.Root, { Size = UDim2.fromOffset(self.Size.X, height) }, 0.32, Enum.EasingStyle.Quint)
	Anim.tween(self.MinimizeButton:FindFirstChild("Icon"), { Rotation = minimized and 90 or 0 }, 0.25)
end

function Window:SetTitle(title)
	self.Title:SetText(title)
end

function Window:SetSubtitle(text)
	self.Subtitle.Text = tostring(text)
end

function Window:SetToggleKey(key)
	self.ToggleKey = key
end

----------------------------------------------------------------------
-- tabs
----------------------------------------------------------------------

function Window:AddTab(opts, icon)
	if type(opts) == "string" then
		opts = { Name = opts, Icon = icon }
	end
	local tab = Tab.new(self, opts)
	table.insert(self.Tabs, tab)
	if not self.ActiveTab then
		self:SelectTab(tab, true)
	end
	return tab
end

function Window:SelectTab(tab, instant)
	if self.ActiveTab == tab then
		return
	end
	local previous = self.ActiveTab
	self.ActiveTab = tab
	self.Library.Popups:Close()
	if previous then
		previous:_setActive(false, instant)
		if self.Query ~= "" then
			previous:_filter("")
		end
	end
	tab:_setActive(true, instant)
	if self.Query ~= "" then
		tab:_filter(self.Query)
	end

	local index = table.find(self.Tabs, tab) or 1
	local y = (index - 1) * (TAB_BUTTON + TAB_GAP) + (TAB_BUTTON - 18) / 2
	self.IndicatorSpring:SetTarget(y, instant or not self.Library.Settings.Animations)

	if not instant and self.Library.Settings.Animations then
		local sweep = self.Sweep
		sweep.Position = UDim2.fromScale(0, 0)
		sweep.ImageTransparency = 0.35
		Anim.tween(sweep, { Position = UDim2.fromScale(0, 1.05), ImageTransparency = 0.9 }, 0.45, Enum.EasingStyle.Quad)
	end
end

function Window:AddSettingsTab(opts)
	local Settings = import("managers/Settings")
	return Settings.build(self, opts)
end

function Window:Notify(...)
	return self.Library:Notify(...)
end

function Window:IsMouseOver()
	return self.Visible and self.Root.Visible and Input.within(self.Root)
end

function Window:Destroy()
	for _, tab in self.Tabs do
		tab:Destroy()
	end
	table.clear(self.Tabs)
	self.Maid:Destroy()
end

return Window
