--[[
	Notifications
	Toasts that spring in from the right edge, decode their title, drain a
	glowing fuse along the bottom and collapse out of the stack when done.
	Hover pauses the fuse; click dismisses.

		library:Notify({ Title = "Loaded", Content = "Welcome back.", Duration = 4, Type = "success" })
		library:Notify("Short message")
]]

local Util = import("core/Util")
local Anim = import("core/Anim")
local Input = import("core/Input")
local Motion = import("core/Motion")
local Glow = import("fx/Glow")
local Scramble = import("fx/Scramble")
local Style = import("components/Style")

local Notifications = {}
Notifications.__index = Notifications

local WIDTH = 290
local LIMIT = 6

local TYPES = {
	info = { Icon = "info", Color = "Accent" },
	success = { Icon = "success", Color = "Success" },
	warning = { Icon = "warning", Color = "Warning" },
	error = { Icon = "error", Color = "Error" },
	danger = { Icon = "skull", Color = "Error" },
}

function Notifications.new(library, layer)
	local self = setmetatable({}, Notifications)
	self.Library = library
	self.Active = {}
	self._order = 0

	-- not passive: toasts inside must stay clickable (Active=false lets the
	-- empty holder area pass clicks through to the game)
	self.Holder = Util.create("Frame", {
		Name = "Notifications",
		BackgroundTransparency = 1,
		Active = false,
		AnchorPoint = Vector2.new(1, 1),
		Position = UDim2.new(1, -18, 1, -18),
		Size = UDim2.new(0, WIDTH, 1, -36),
		ZIndex = 20,
		Parent = layer,
	})
	self.Scale = Util.create("UIScale", { Scale = library.Scale, Parent = self.Holder })
	Util.list(self.Holder, {
		Padding = 8,
		VAlign = Enum.VerticalAlignment.Bottom,
		HAlign = Enum.HorizontalAlignment.Right,
	})
	return self
end

function Notifications:SetScale(scale)
	self.Scale.Scale = scale
end

function Notifications:Push(opts)
	if type(opts) == "string" then
		opts = { Content = opts }
	end
	opts = Util.defaults(opts, { Title = "hellspawn", Content = "", Duration = 4, Type = "info" })
	local library = self.Library
	local theme = library.Theme
	local kind = TYPES[string.lower(opts.Type)] or TYPES.info
	local colorKey = opts.Color or kind.Color
	local hasBody = opts.Content ~= nil and opts.Content ~= ""

	self._order += 1
	local slot = Util.create("Frame", {
		Name = "Toast",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = self._order,
		ZIndex = 20,
		Parent = self.Holder,
	})

	local card = Util.create("TextButton", {
		Name = "Card",
		AutoButtonColor = false,
		Text = "",
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Position = UDim2.fromOffset(WIDTH + 40, 0),
		ZIndex = 20,
		Parent = slot,
	})
	theme:Bind(card, { BackgroundColor3 = "Panel" })
	Util.corner(card, 2)
	local stroke = Util.stroke(card)
	theme:Bind(stroke, { Color = "Border" })
	local glow = Glow.attach(library, card, { Spread = 14, Strength = 0.18, Color = colorKey, ZIndex = 19 })

	-- text column (drives the card's automatic height)
	local content = Util.create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 21,
		Parent = card,
	})
	Util.padding(content, 9, 12, 14, 14)
	Util.list(content, { Padding = 3 })

	local titleRow = Util.create("Frame", {
		Name = "TitleRow",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 16),
		LayoutOrder = 1,
		ZIndex = 21,
		Parent = content,
	})
	Style.icon(library, {
		Icon = opts.Icon or kind.Icon,
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(14, 14),
		Color = colorKey,
		ZIndex = 22,
		Parent = titleRow,
	})
	local title = Style.label(library, {
		Name = "Title",
		Text = opts.Title,
		Weight = "Bold",
		Color = "Text",
		Position = UDim2.fromOffset(22, 0),
		Size = UDim2.new(1, -22, 1, 0),
		Truncate = true,
		ZIndex = 22,
		Parent = titleRow,
	})

	if hasBody then
		local body = Style.label(library, {
			Name = "Body",
			Text = opts.Content,
			TextSize = Style.Small,
			Color = "TextDim",
			Wrap = true,
			Rich = true,
			YAlign = Enum.TextYAlignment.Top,
			Size = UDim2.new(1, 0, 0, 0),
			AutoSize = Enum.AutomaticSize.Y,
			ZIndex = 22,
			Parent = content,
		})
		body.LayoutOrder = 2
		Util.padding(body, 0, 0, 0, 22)
	end

	-- decorations sized to the card (scale-sized, so they never feed back into it)
	local decor = Util.passive(Util.create("Frame", {
		Name = "Decor",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 22,
		Parent = card,
	}))
	local spine = Util.passive(Util.create("Frame", {
		Name = "Spine",
		BorderSizePixel = 0,
		Size = UDim2.new(0, 2, 1, 0),
		ZIndex = 22,
		Parent = decor,
	}))
	theme:Bind(spine, { BackgroundColor3 = colorKey })
	local fuse = Util.passive(Util.create("Frame", {
		Name = "Fuse",
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.new(1, 0, 0, 2),
		ZIndex = 23,
		Parent = decor,
	}))
	theme:Bind(fuse, { BackgroundColor3 = colorKey })
	local spark = Util.passive(Util.create("ImageLabel", {
		Name = "Spark",
		BackgroundTransparency = 1,
		Image = library.Assets:Texture("spark"),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(1, 0.5),
		Size = UDim2.fromOffset(16, 16),
		ZIndex = 24,
		Parent = fuse,
	}))
	theme:Bind(spark, { ImageColor3 = colorKey })

	local entry = { Slot = slot, Card = card, Closing = false }
	table.insert(self.Active, entry)

	-- spring in from the right
	local slide = Motion.spring(WIDTH + 40, { Frequency = 3.2, Damping = 0.78 }, function(x)
		card.Position = UDim2.fromOffset(x, 0)
	end)
	slide:SetTarget(0, not library.Settings.Animations)
	Scramble.play(title, opts.Title, { Duration = 0.45, Enabled = library.Settings.Animations })
	Glow.flash(glow, 0.7, 0.8)

	local hovered = false
	Input.hover(card, function(state)
		hovered = state
		Anim.tween(stroke, { Color = theme:Get(state and "BorderLight" or "Border") }, 0.15)
	end)

	local remaining = opts.Duration
	local total = math.max(opts.Duration, 0.1)
	local unbind
	local function close()
		if entry.Closing then
			return
		end
		entry.Closing = true
		unbind()
		slide:SetTarget(WIDTH + 40, not library.Settings.Animations)
		task.delay(0.22, function()
			local height = slot.AbsoluteSize.Y / (library.Scale or 1)
			slot.AutomaticSize = Enum.AutomaticSize.None
			slot.Size = UDim2.new(1, 0, 0, height)
			Anim.tween(slot, { Size = UDim2.new(1, 0, 0, 0) }, 0.2, Enum.EasingStyle.Quad)
			task.delay(0.22, function()
				slide:Destroy()
				slot:Destroy()
				local index = table.find(self.Active, entry)
				if index then
					table.remove(self.Active, index)
				end
			end)
		end)
		if opts.OnClose then
			task.spawn(Util.safeCall, opts.OnClose)
		end
	end
	entry.Close = close

	unbind = Anim.frame(function(dt)
		if not hovered then
			remaining -= dt
		end
		fuse.Size = UDim2.new(math.clamp(remaining / total, 0, 1), 0, 0, 2)
		if remaining <= 0 then
			close()
		end
	end)
	card.Activated:Connect(close)

	-- keep the stack tidy: oldest toasts leave first
	local open = 0
	for i = #self.Active, 1, -1 do
		local other = self.Active[i]
		if not other.Closing then
			open += 1
			if open > LIMIT then
				other.Close()
			end
		end
	end
	return entry
end

function Notifications:Clear()
	for _, entry in table.clone(self.Active) do
		entry.Close()
	end
end

function Notifications:Destroy()
	self.Holder:Destroy()
end

return Notifications
