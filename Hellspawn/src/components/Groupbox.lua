--[[
	Groupbox
	ImGui child window: a framed panel with a sigil-marked header, targeting
	brackets on its top corners and an accent underline. Click the header to
	collapse it.
]]

local Util = import("core/Util")
local Anim = import("core/Anim")
local Input = import("core/Input")
local Scramble = import("fx/Scramble")
local Style = import("components/Style")
local Container = import("components/Container")

local Groupbox = {}
Groupbox.__index = Groupbox
Container.mixin(Groupbox)

local HEADER = 26

local UNDERLINE_FADE = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.55, 0.65),
	NumberSequenceKeypoint.new(1, 1),
})

-- Two-armed corner bracket, drawn with 1px frames
function Groupbox.bracket(library, parent, corner, size)
	size = size or 7
	local holder = Util.passive(Util.create("Frame", {
		Name = "Bracket" .. corner,
		BackgroundTransparency = 1,
		Size = UDim2.fromOffset(size, size),
		AnchorPoint = Vector2.new(corner == "TR" and 1 or 0, 0),
		Position = corner == "TR" and UDim2.new(1, 0, 0, 0) or UDim2.new(),
		ZIndex = 4,
		Parent = parent,
	}))
	local horizontal = Util.passive(Util.create("Frame", {
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 1),
		ZIndex = 4,
		Parent = holder,
	}))
	local vertical = Util.passive(Util.create("Frame", {
		BorderSizePixel = 0,
		Size = UDim2.new(0, 1, 1, 0),
		Position = corner == "TR" and UDim2.new(1, -1, 0, 0) or UDim2.new(),
		ZIndex = 4,
		Parent = holder,
	}))
	library.Theme:Bind(horizontal, { BackgroundColor3 = "Accent" })
	library.Theme:Bind(vertical, { BackgroundColor3 = "Accent" })
	return holder
end

--[[
	Builds the shared groupbox shell (used by Tabbox too).
	Returns outer frame, header frame, body frame (layout target).
]]
function Groupbox.shell(library, name)
	local theme = library.Theme
	local outer = Util.create("Frame", {
		Name = name or "Groupbox",
		BorderSizePixel = 0,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
	})
	theme:Bind(outer, { BackgroundColor3 = "Panel" })
	theme:Bind(Util.stroke(outer), { Color = "Border" })
	Util.corner(outer, 2)
	Util.list(outer)

	local header = Util.create("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, HEADER),
		LayoutOrder = 1,
		Parent = outer,
	})
	Groupbox.bracket(library, header, "TL")
	Groupbox.bracket(library, header, "TR")

	local underline = Util.passive(Util.create("Frame", {
		Name = "Underline",
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = UDim2.new(0, 8, 1, -1),
		Size = UDim2.new(1, -16, 0, 1),
		Parent = header,
	}))
	theme:Bind(Util.gradient(underline, { Transparency = UNDERLINE_FADE }), { Color = "AccentGradient" })

	local body = Util.create("Frame", {
		Name = "Body",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = 2,
		Parent = outer,
	})
	return outer, header, body
end

function Groupbox.content(parent)
	local content = Util.create("Frame", {
		Name = "Content",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		Parent = parent,
	})
	Util.padding(content, 8, 10, 10, 10)
	Util.list(content, { Padding = Style.Gap })
	return content
end

function Groupbox.new(tab, column, opts)
	if type(opts) == "string" then
		opts = { Name = opts }
	end
	opts = Util.defaults(opts, { Name = "Group", Collapsible = true, Collapsed = false })
	local self = setmetatable({}, Groupbox)
	self.Library = tab.Library
	self.Window = tab.Window
	self.Tab = tab
	self.Name = opts.Name
	self.Elements = {}
	self.Collapsed = false

	local library = self.Library
	local outer, header, body = Groupbox.shell(library, "Groupbox")
	self.Instance = outer
	self.Header = header

	Style.icon(library, {
		Name = "Sigil",
		Icon = opts.Icon or "sigil",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.new(0, 10, 0.5, 0),
		Size = UDim2.fromOffset(10, 10),
		Color = "Accent",
		Parent = header,
	})
	self.Title = Style.label(library, {
		Name = "Title",
		Text = string.upper(self.Name),
		Weight = "Bold",
		TextSize = Style.Small,
		Color = "Text",
		Position = UDim2.fromOffset(26, 0),
		Size = UDim2.new(1, -52, 1, 0),
		Truncate = true,
		Parent = header,
	})

	self.List = Groupbox.content(body)
	self.Body = body

	if opts.Collapsible then
		self.Chevron = Style.icon(library, {
			Name = "Chevron",
			Icon = "chevron",
			AnchorPoint = Vector2.new(1, 0.5),
			Position = UDim2.new(1, -10, 0.5, 0),
			Size = UDim2.fromOffset(9, 9),
			Color = "TextMuted",
			Parent = header,
		})
		local hit = Style.hitbox({ Name = "Collapse", ZIndex = 3, Parent = header })
		Input.hover(hit, function(state)
			Anim.tween(self.Chevron, {
				ImageColor3 = library.Theme:Get(state and "Accent" or "TextMuted"),
			}, 0.15)
		end)
		hit.Activated:Connect(function()
			self:SetCollapsed(not self.Collapsed)
		end)
	end

	outer.LayoutOrder = tab:_order()
	outer.Parent = column
	if opts.Collapsed then
		self:SetCollapsed(true, true)
	end
	return self
end

function Groupbox:SetCollapsed(collapsed, instant)
	self.Collapsed = collapsed
	self.List.Visible = not collapsed
	if self.Chevron then
		Anim.tween(self.Chevron, { Rotation = collapsed and -90 or 0 }, instant and 0 or 0.2)
	end
end

function Groupbox:SetTitle(text)
	self.Name = tostring(text)
	self.Title.Text = string.upper(self.Name)
end

function Groupbox:_reveal()
	Scramble.play(self.Title, string.upper(self.Name), {
		Duration = 0.35,
		Enabled = self.Library.Settings.Animations,
	})
end

-- returns how many controls match (a matching title counts every control)
function Groupbox:_filter(query)
	if Util.trim(query) == "" then
		self:_clearFilter()
		return 0
	end
	if Util.matches(query, self.Name) then
		self:_clearFilter()
		self.List.Visible = true
		return math.max(1, #self.Elements)
	end
	local shown = Container.Methods._filter(self, query)
	self.Instance.Visible = shown > 0
	if shown > 0 and self.Collapsed then
		self.List.Visible = true
	end
	return shown
end

function Groupbox:_clearFilter()
	for _, element in self.Elements do
		element:_filter("")
	end
	self.Instance.Visible = true
	self.List.Visible = not self.Collapsed
end

function Groupbox:Destroy()
	for _, element in table.clone(self.Elements) do
		element:Destroy()
	end
	self.Instance:Destroy()
end

return Groupbox
