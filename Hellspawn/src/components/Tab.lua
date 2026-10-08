--[[
	Tab
	A sidebar entry plus its page. The active tab gets a dry-brush blood smear
	behind its label, a neon-tube flicker on its icon, and the page arrives
	with a scan sweep while its headings decode.
]]

local Util = import("core/Util")
local Anim = import("core/Anim")
local Input = import("core/Input")
local Scramble = import("fx/Scramble")
local Style = import("components/Style")
local Groupbox = import("components/Groupbox")
local Tabbox = import("components/Tabbox")

local Tab = {}
Tab.__index = Tab

local BUTTON = 32
local HEADER = 54

function Tab.new(window, opts)
	if type(opts) == "string" then
		opts = { Name = opts }
	end
	opts = Util.defaults(opts, { Name = "Tab", Icon = nil, Description = nil, Columns = 2 })
	local self = setmetatable({}, Tab)
	self.Window = window
	self.Library = window.Library
	self.Name = opts.Name
	self.Description = opts.Description or ("// " .. string.lower(opts.Name))
	self.Icon = opts.Icon or string.lower(opts.Name)
	self.Boxes = {}
	self.Active = false
	self.Hovered = false

	self:_buildButton()
	self:_buildPage(opts.Columns)
	return self
end

function Tab:_order()
	self._counter = (self._counter or 0) + 1
	return self._counter
end

function Tab:_buildButton()
	local library = self.Library
	local theme = library.Theme
	local window = self.Window

	local button = Style.hitbox({
		Name = self.Name,
		Size = UDim2.new(1, 0, 0, BUTTON),
		ZIndex = 4,
	})
	button.LayoutOrder = #window.Tabs + 1
	self.Button = button

	self.Smear = Util.passive(Util.create("ImageLabel", {
		Name = "Smear",
		BackgroundTransparency = 1,
		Image = library.Assets:Texture("smear"),
		ImageTransparency = 1,
		Position = UDim2.fromOffset(-6, 1),
		Size = UDim2.new(1, 18, 1, -2),
		ZIndex = 4,
		Parent = button,
	}))
	theme:Bind(self.Smear, { ImageColor3 = "Accent" })

	local iconHolder = Util.passive(Util.create("Frame", {
		Name = "IconHolder",
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 12, 0.5, 0),
		Size = UDim2.fromOffset(16, 16),
		ZIndex = 5,
		Parent = button,
	}))
	self.Bloom = Util.passive(Util.create("ImageLabel", {
		Name = "Bloom",
		BackgroundTransparency = 1,
		Image = library.Assets:Texture("bloom"),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(34, 34),
		ImageTransparency = 1,
		ZIndex = 5,
		Parent = iconHolder,
	}))
	theme:Bind(self.Bloom, { ImageColor3 = "Accent" })
	self.IconImage = Style.icon(library, {
		Icon = self.Icon,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 6,
		Parent = iconHolder,
	})

	self.Label = Style.label(library, {
		Text = self.Name,
		Weight = "Medium",
		Color = false,
		Position = UDim2.fromOffset(36, 0),
		Size = UDim2.new(1, -40, 1, 0),
		Truncate = true,
		ZIndex = 6,
		Parent = button,
	})

	-- search hit counter
	self.Badge = Style.label(library, {
		Name = "Badge",
		Text = "",
		Weight = "Bold",
		TextSize = Style.Tiny,
		Color = false,
		XAlign = Enum.TextXAlignment.Right,
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(28, 14),
		ZIndex = 6,
		Parent = button,
	})
	self.Badge.Visible = false

	Input.hover(button, function(state)
		self.Hovered = state
		self:_paint()
	end)
	button.Activated:Connect(function()
		window:SelectTab(self)
	end)
	-- state-driven colours (icon, label) are repainted on theme change
	window.Maid:Give(theme.Changed:Connect(function()
		self:_paint(true)
	end))

	button.Parent = window.TabList
	self:_paint(true)
end

function Tab:_buildPage(columns)
	local library = self.Library
	local theme = library.Theme
	local window = self.Window

	local page = Util.create("Frame", {
		Name = self.Name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Visible = false,
		ZIndex = 2,
		Parent = window.Pages,
	})
	self.Page = page

	local header = Util.create("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, HEADER),
		ZIndex = 2,
		Parent = page,
	})
	self.Heading = Style.label(library, {
		Name = "Heading",
		Text = self.Name,
		Role = "Gothic",
		TextSize = 26,
		Color = "Text",
		Position = UDim2.fromOffset(16, 6),
		Size = UDim2.new(1, -90, 0, 30),
		Truncate = true,
		ZIndex = 2,
		Parent = header,
	})
	self.Caption = Style.label(library, {
		Name = "Caption",
		Text = self.Description,
		TextSize = Style.Tiny,
		Color = "TextMuted",
		Position = UDim2.fromOffset(17, 34),
		Size = UDim2.new(1, -90, 0, 12),
		Truncate = true,
		ZIndex = 2,
		Parent = header,
	})
	Style.icon(library, {
		Name = "Watermark",
		Icon = self.Icon,
		AnchorPoint = Vector2.new(1, 0),
		Position = UDim2.new(1, -18, 0, 8),
		Size = UDim2.fromOffset(36, 36),
		Color = "Accent",
		Transparency = 0.86,
		ZIndex = 2,
		Parent = header,
	})
	local rule
	if library.Assets:Has("vine") then
		local meta = library.Assets:Meta("vine")
		rule = Util.create("ImageLabel", {
			Name = "Rule",
			BackgroundTransparency = 1,
			Image = library.Assets:Texture("vine"),
			ScaleType = Enum.ScaleType.Tile,
			TileSize = UDim2.fromOffset(meta.Width / 2, meta.Height / 2),
			Position = UDim2.new(0, 14, 1, -8),
			Size = UDim2.new(1, -28, 0, meta.Height / 2),
			ZIndex = 2,
			Parent = header,
		})
		theme:Bind(rule, { ImageColor3 = "BorderLight" })
	else
		rule = Util.create("Frame", {
			Name = "Rule",
			BorderSizePixel = 0,
			Position = UDim2.new(0, 14, 1, -2),
			Size = UDim2.new(1, -28, 0, 1),
			ZIndex = 2,
			Parent = header,
		})
		theme:Bind(rule, { BackgroundColor3 = "BorderLight" })
	end
	Util.passive(rule)
	Util.gradient(rule, {
		Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 0.1),
			NumberSequenceKeypoint.new(0.7, 0.5),
			NumberSequenceKeypoint.new(1, 1),
		}),
	})

	local scroller = Util.create("ScrollingFrame", {
		Name = "Scroller",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, HEADER),
		Size = UDim2.new(1, 0, 1, -HEADER),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 3,
		ScrollBarImageTransparency = 0.25,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		VerticalScrollBarInset = Enum.ScrollBarInset.ScrollBar,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		ZIndex = 2,
		Parent = page,
	})
	theme:Bind(scroller, { ScrollBarImageColor3 = "Accent" })
	self.Scroller = scroller

	-- the inset lives on this frame, not as UIPadding on the ScrollingFrame:
	-- scrolling frames don't shrink scale-sized children for padding, which
	-- pushed the right column past the window edge
	local holder = Util.create("Frame", {
		Name = "Columns",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(14, 6),
		Size = UDim2.new(1, -28, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 2,
		Parent = scroller,
	})
	Util.padding(holder, 0, 0, 14, 0)
	Util.list(holder, { Direction = Enum.FillDirection.Horizontal, Padding = 10 })

	local function column(name, order, width)
		local frame = Util.create("Frame", {
			Name = name,
			BackgroundTransparency = 1,
			Size = width,
			AutomaticSize = Enum.AutomaticSize.Y,
			LayoutOrder = order,
			ZIndex = 2,
			Parent = holder,
		})
		Util.list(frame, { Padding = 10 })
		return frame
	end

	if columns == 1 then
		self.Left = column("Left", 1, UDim2.new(1, 0, 0, 0))
		self.Right = self.Left
	else
		self.Left = column("Left", 1, UDim2.new(0.5, -5, 0, 0))
		self.Right = column("Right", 2, UDim2.new(0.5, -5, 0, 0))
	end
end

function Tab:_paint(instant)
	local theme = self.Library.Theme
	local time = instant and 0 or 0.2
	local labelKey = self.Active and "Text" or (self.Hovered and "Text" or "TextDim")
	if self.Matches == 0 and not self.Hovered then
		labelKey = "TextMuted" -- searching, nothing here
	end
	self.Badge.TextColor3 = theme:Get((self.Matches or 0) > 0 and "Accent" or "TextMuted")
	Anim.tween(self.Label, {
		TextColor3 = theme:Get(labelKey),
		Position = UDim2.fromOffset((self.Hovered and not self.Active) and 39 or 36, 0),
	}, time)
	Anim.tween(self.IconImage, {
		ImageColor3 = theme:Get(self.Active and "Accent" or (self.Hovered and "TextDim" or "TextMuted")),
	}, time)
	Anim.tween(self.Smear, {
		ImageTransparency = self.Active and 0.62 or (self.Hovered and 0.93 or 1),
	}, instant and 0 or 0.3)
	if not self.Active then
		Anim.tween(self.Bloom, { ImageTransparency = 1 }, time)
	end
end

function Tab:_setActive(active, instant)
	local library = self.Library
	self.Active = active
	self.Page.Visible = active
	self:_paint(instant)
	if not active then
		return
	end

	local animate = library.Settings.Animations and not instant
	if animate then
		-- neon tube start-up on the icon bloom
		task.spawn(function()
			for _, k in { 0.35, 0.95, 0.5, 1, 0.7, 0.92, 0.65 } do
				if not self.Active then
					return
				end
				self.Bloom.ImageTransparency = k
				task.wait(0.035 + math.random() * 0.03)
			end
		end)
		-- page slides up a few pixels while headings decode
		self.Page.Position = UDim2.fromOffset(0, 10)
		Anim.tween(self.Page, { Position = UDim2.new() }, 0.35, Enum.EasingStyle.Quint)
		Scramble.play(self.Heading, self.Name, { Duration = 0.4 })
		for _, box in self.Boxes do
			box:_reveal()
		end
	else
		self.Bloom.ImageTransparency = 0.65
		self.Page.Position = UDim2.new()
	end
end

function Tab:Select()
	self.Window:SelectTab(self)
end

function Tab:_column(side)
	if side == "Right" or side == 2 then
		return self.Right
	end
	return self.Left
end

function Tab:AddGroupbox(opts)
	if type(opts) == "string" then
		opts = { Name = opts }
	end
	opts = opts or {}
	local box = Groupbox.new(self, self:_column(opts.Side), opts)
	table.insert(self.Boxes, box)
	return box
end

function Tab:AddLeftGroupbox(name, opts)
	opts = opts or {}
	opts.Name = name
	opts.Side = "Left"
	return self:AddGroupbox(opts)
end

function Tab:AddRightGroupbox(name, opts)
	opts = opts or {}
	opts.Name = name
	opts.Side = "Right"
	return self:AddGroupbox(opts)
end

function Tab:AddTabbox(opts)
	opts = opts or {}
	local box = Tabbox.new(self, self:_column(opts.Side), opts)
	table.insert(self.Boxes, box)
	return box
end

function Tab:AddLeftTabbox(name)
	return self:AddTabbox({ Name = name, Side = "Left" })
end

function Tab:AddRightTabbox(name)
	return self:AddTabbox({ Name = name, Side = "Right" })
end

-- returns the number of matching controls on this page
function Tab:_filter(query)
	local total = 0
	for _, box in self.Boxes do
		total += box:_filter(query)
	end
	return total
end

-- sidebar badge: match count while searching, nil when not searching
function Tab:_setMatches(count)
	self.Matches = count
	if count == nil then
		self.Badge.Visible = false
	else
		self.Badge.Visible = true
		self.Badge.Text = tostring(count)
	end
	self:_paint()
end

function Tab:SetName(name)
	self.Name = tostring(name)
	self.Label.Text = self.Name
	self.Heading.Text = self.Name
end

function Tab:Destroy()
	for _, box in self.Boxes do
		box:Destroy()
	end
	self.Button:Destroy()
	self.Page:Destroy()
end

return Tab
