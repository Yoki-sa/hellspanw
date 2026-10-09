--[[
	Tabbox
	A groupbox whose header is a row of tabs, each with its own controls.

		local tb = tab:AddRightTabbox()
		local a = tb:AddTab("Chams")
		local b = tb:AddTab("Glow")
		a:AddToggle(...)
]]

local Util = import("core/Util")
local Anim = import("core/Anim")
local Motion = import("core/Motion")
local Style = import("components/Style")
local Container = import("components/Container")
local Groupbox = import("components/Groupbox")

local Tabbox = {}
Tabbox.__index = Tabbox

local Page = {}
Page.__index = Page
Container.mixin(Page)

function Tabbox.new(tab, column, opts)
	opts = opts or {}
	local self = setmetatable({}, Tabbox)
	self.Library = tab.Library
	self.Window = tab.Window
	self.Tab = tab
	self.Name = opts.Name or "Tabbox"
	self.Pages = {}
	self.Active = nil

	local library = self.Library
	local outer, header, body = Groupbox.shell(library, "Tabbox")
	self.Instance = outer
	self.Header = header
	self.Body = body

	self.Strip = Util.create("Frame", {
		Name = "Strip",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -16, 1, -1),
		ZIndex = 2,
		Parent = header,
	})
	Util.list(self.Strip, { Direction = Enum.FillDirection.Horizontal })

	self.Indicator = Util.passive(Util.create("Frame", {
		Name = "Indicator",
		BorderSizePixel = 0,
		BackgroundColor3 = Color3.new(1, 1, 1),
		Position = UDim2.new(0, 8, 1, -2),
		Size = UDim2.new(0, 0, 0, 2),
		ZIndex = 3,
		Parent = header,
	}))
	library.Theme:Bind(Util.gradient(self.Indicator), { Color = "AccentGradient" })

	self._spring = Motion.spring(0, { Frequency = 5, Damping = 0.8 }, function(x)
		local count = math.max(#self.Pages, 1)
		self.Indicator.Position = UDim2.new(x / count, 8 - x / count * 16, 1, -2)
	end)

	outer.LayoutOrder = tab:_order()
	outer.Parent = column
	return self
end

function Tabbox:_layout()
	local count = #self.Pages
	for _, page in self.Pages do
		page.Button.Size = UDim2.new(1 / count, 0, 1, 0)
	end
	self.Indicator.Size = UDim2.new(1 / count, -16 / count, 0, 2)
	if self.Active then
		self._spring:SetTarget(table.find(self.Pages, self.Active) - 1, true)
	end
end

function Tabbox:AddTab(name)
	local library = self.Library
	local page = setmetatable({}, Page)
	page.Library = library
	page.Window = self.Window
	page.Tabbox = self
	page.Name = name
	page.Elements = {}

	local button = Style.hitbox({
		Name = name,
		Size = UDim2.new(1, 0, 1, 0),
		ZIndex = 2,
		Parent = self.Strip,
	})
	button.LayoutOrder = #self.Pages + 1
	page.Button = button
	page.Label = Style.label(library, {
		Text = string.upper(name),
		Weight = "Bold",
		TextSize = Style.Small,
		Color = false,
		XAlign = Enum.TextXAlignment.Center,
		Truncate = true,
		ZIndex = 2,
		Parent = button,
	})
	page.List = Groupbox.content(self.Body)
	page.List.Visible = false

	button.Activated:Connect(function()
		self:Select(page)
	end)
	button.MouseEnter:Connect(function()
		if self.Active ~= page then
			Anim.tween(page.Label, { TextColor3 = library.Theme:Get("TextDim") }, 0.12)
		end
	end)
	button.MouseLeave:Connect(function()
		if self.Active ~= page then
			Anim.tween(page.Label, { TextColor3 = library.Theme:Get("TextMuted") }, 0.12)
		end
	end)
	library.Theme.Changed:Connect(function()
		page.Label.TextColor3 = library.Theme:Get(self.Active == page and "Text" or "TextMuted")
	end)

	table.insert(self.Pages, page)
	self:_layout()
	if not self.Active then
		self:Select(page, true)
	else
		page.Label.TextColor3 = library.Theme:Get("TextMuted")
	end
	return page
end

function Tabbox:Select(page, instant)
	local theme = self.Library.Theme
	self.Active = page
	for _, other in self.Pages do
		local active = other == page
		other.List.Visible = active
		Anim.tween(other.Label, { TextColor3 = theme:Get(active and "Text" or "TextMuted") }, instant and 0 or 0.15)
	end
	self._spring:SetTarget(table.find(self.Pages, page) - 1, instant)
end

function Tabbox:_reveal() end

-- returns how many controls match across every page
function Tabbox:_filter(query)
	if Util.trim(query) == "" then
		self:_clearFilter()
		return 0
	end
	local total, activeShown, firstHit = 0, 0, nil
	for _, page in self.Pages do
		local shown = Container.Methods._filter(page, query)
		total += shown
		if page == self.Active then
			activeShown = shown
		end
		if shown > 0 and not firstHit then
			firstHit = page
		end
	end
	if activeShown == 0 and firstHit then
		self:Select(firstHit, true)
	end
	self.Instance.Visible = total > 0
	return total
end

function Tabbox:_clearFilter()
	for _, page in self.Pages do
		for _, element in page.Elements do
			element:_filter("")
		end
	end
	self.Instance.Visible = true
end

function Tabbox:Destroy()
	self._spring:Destroy()
	for _, page in self.Pages do
		for _, element in table.clone(page.Elements) do
			element:Destroy()
		end
	end
	self.Instance:Destroy()
end

return Tabbox
