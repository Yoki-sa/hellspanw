--[[
	Dropdown
	Single or multi select. The list unfurls in the popup layer (never clipped
	by scrolling), gets a search box automatically when it grows long, and can
	track live player/team lists.

		box:AddDropdown("part", { Text = "Hitbox", Values = { "Head", "Torso" }, Default = "Head" })
		box:AddDropdown("ignore", { Text = "Ignore", Values = {...}, Multi = true, Default = { "Team" } })
		box:AddDropdown("target", { Text = "Target", SpecialType = "Player" })
]]

local Env = import("core/Env")
local Util = import("core/Util")
local Anim = import("core/Anim")
local Input = import("core/Input")
local Style = import("components/Style")
local Element = import("components/Element")

local Dropdown = Element.extend("Dropdown")

local ITEM = 20
local LABEL = 17

function Dropdown.new(container, flag, opts)
	flag, opts = Element.args(flag, opts)
	local self = setmetatable({}, Dropdown)
	Element.init(self, container, flag, opts, {
		Text = "Dropdown",
		Values = {},
		Multi = false,
		AllowNull = false,
		MaxVisible = 8,
		Placeholder = "none",
	})
	local o = self.Options
	self.Multi = o.Multi
	self.Values = table.clone(o.Values)
	self.Value = self.Multi and {} or nil
	self.Open = false

	local library = self.Library
	local hasLabel = self.Text ~= "" and o.HideLabel ~= true
	local top = hasLabel and LABEL or 0

	local root = Util.create("Frame", {
		Name = "Dropdown",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, top + Style.Box),
	})

	if hasLabel then
		self.Label = Style.label(library, {
			Text = self.Text,
			Weight = "Medium",
			Color = false,
			Size = UDim2.new(1, 0, 0, 14),
			Truncate = true,
			Parent = root,
		})
	end

	local box, stroke = Style.surface(library, {
		Class = "TextButton",
		Name = "Box",
		Position = UDim2.fromOffset(0, top),
		Parent = root,
	})
	self.Box = box
	self.Stroke = stroke
	self.Hitbox = box

	self.Display = Style.label(library, {
		Name = "Display",
		Color = false,
		Position = UDim2.fromOffset(8, 0),
		Size = UDim2.new(1, -30, 1, 0),
		Truncate = true,
		Parent = box,
	})

	self.Chevron = Style.icon(library, {
		Name = "Chevron",
		Icon = "chevron",
		AnchorPoint = Vector2.new(1, 0.5),
		Position = UDim2.new(1, -8, 0.5, 0),
		Size = UDim2.fromOffset(10, 10),
		Parent = box,
	})

	self.Maid:Give((Input.hover(box, function(state)
		self.Hovered = state
		self:_paint()
	end)))

	self.Maid:Give(box.Activated:Connect(function()
		if self.Disabled then
			return
		end
		if self.Open then
			self:Close()
		else
			self:OpenList()
		end
	end))

	if o.SpecialType then
		self:_bindSpecial(o.SpecialType)
	end

	self:_mount(root)
	self:_applyDefault(o.Default)
	self:_paint(true)
	return self
end

function Dropdown:_bindSpecial(kind)
	local Players = Env.service("Players")
	local function refresh()
		local list = {}
		if kind == "Player" then
			for _, player in Players:GetPlayers() do
				if not (self.Options.ExcludeLocalPlayer and player == Players.LocalPlayer) then
					table.insert(list, player.Name)
				end
			end
		elseif kind == "Team" then
			for _, team in Env.service("Teams"):GetTeams() do
				table.insert(list, team.Name)
			end
		end
		table.sort(list, function(a, b)
			return string.lower(a) < string.lower(b)
		end)
		self:SetValues(list)
	end
	if kind == "Player" then
		self.Maid:Give(Players.PlayerAdded:Connect(refresh))
		self.Maid:Give(Players.PlayerRemoving:Connect(function()
			task.defer(refresh)
		end))
	elseif kind == "Team" then
		local Teams = Env.service("Teams")
		self.Maid:Give(Teams.ChildAdded:Connect(refresh))
		self.Maid:Give(Teams.ChildRemoved:Connect(function()
			task.defer(refresh)
		end))
	end
	refresh()
end

function Dropdown:_applyDefault(default)
	if self.Multi then
		local set = {}
		if type(default) == "table" then
			for key, value in default do
				if type(key) == "number" then
					set[value] = true
				elseif value then
					set[key] = true
				end
			end
		elseif default ~= nil then
			set[default] = true
		end
		self.Value = set
	else
		if type(default) == "number" then
			default = self.Values[default]
		end
		if default == nil and not self.Options.AllowNull then
			default = self.Values[1]
		end
		self.Value = default
	end
	if self.Flag then
		self.Library.Flags[self.Flag] = self.Value
	end
	self:_render()
end

function Dropdown:_displayText()
	if self.Multi then
		local picked = {}
		for _, value in self.Values do
			if self.Value[value] then
				table.insert(picked, tostring(value))
			end
		end
		if #picked == 0 then
			return nil
		end
		return table.concat(picked, ", ")
	end
	if self.Value == nil then
		return nil
	end
	return tostring(self.Value)
end

function Dropdown:_render()
	local text = self:_displayText()
	self.Display.Text = text or self.Options.Placeholder
	self:_paint(true)
end

function Dropdown:_paint(instant)
	local theme = self.Theme
	local time = instant and 0 or 0.15
	local active = self.Hovered or self.Open
	if self.Label then
		Anim.tween(self.Label, {
			TextColor3 = theme:Get(self.Disabled and "TextMuted" or (active and "Text" or "TextDim")),
		}, time)
	end
	local empty = self:_displayText() == nil
	Anim.tween(self.Display, {
		TextColor3 = theme:Get((self.Disabled or empty) and "TextMuted" or "Text"),
	}, time)
	Anim.tween(self.Stroke, {
		Color = theme:Get(self.Open and "Accent" or ((self.Hovered and not self.Disabled) and "AccentDark" or "Border")),
	}, time)
	Anim.tween(self.Box, {
		BackgroundColor3 = theme:Get((active and not self.Disabled) and "SurfaceHover" or "Surface"),
	}, time)
	Anim.tween(self.Chevron, {
		ImageColor3 = theme:Get(self.Open and "Accent" or "TextMuted"),
		Rotation = self.Open and 180 or 0,
	}, instant and 0 or 0.22)
end

function Dropdown:_isSelected(value)
	if self.Multi then
		return self.Value[value] == true
	end
	return self.Value == value
end

function Dropdown:OpenList()
	if self.Open then
		return
	end
	local library = self.Library
	local theme = self.Theme
	local o = self.Options
	local searchable = o.Searchable
	if searchable == nil then
		searchable = #self.Values > o.MaxVisible
	end
	local searchHeight = searchable and 26 or 0

	local function heightFor(count)
		return searchHeight + math.max(1, math.min(count, o.MaxVisible)) * ITEM + 8
	end

	self.Open = true
	self:_paint()

	local popup = library.Popups:Open({
		Owner = self.Box,
		Height = heightFor(#self.Values),
		OnClose = function()
			self.Open = false
			self._popup = nil
			self._items = nil
			self:_paint()
		end,
	})
	self._popup = popup
	local content = popup.Content

	local list = Util.create("ScrollingFrame", {
		Name = "List",
		BackgroundTransparency = 1,
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(0, searchHeight),
		Size = UDim2.new(1, 0, 1, -searchHeight),
		CanvasSize = UDim2.new(),
		AutomaticCanvasSize = Enum.AutomaticSize.Y,
		ScrollBarThickness = 2,
		ScrollingDirection = Enum.ScrollingDirection.Y,
		ElasticBehavior = Enum.ElasticBehavior.Never,
		ZIndex = 11,
		Parent = content,
	})
	theme:Bind(list, { ScrollBarImageColor3 = "Accent" })
	-- inset frame instead of UIPadding on the scrolling frame (see Tab.lua)
	local rows = Util.create("Frame", {
		Name = "Rows",
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(4, 4),
		Size = UDim2.new(1, -8, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 11,
		Parent = list,
	})
	Util.list(rows)
	Util.padding(rows, 0, 0, 4, 0)

	local items = {}
	self._items = items

	local function paintItem(item, instant)
		local selected = self:_isSelected(item.Value)
		local time = instant and 0 or 0.12
		Anim.tween(item.Text, {
			TextColor3 = theme:Get(selected and "Accent" or (item.Hovered and "Text" or "TextDim")),
		}, time)
		Anim.tween(item.Button, { BackgroundTransparency = item.Hovered and 0 or 1 }, time)
		if item.Mark then
			Anim.tween(item.Mark, { ImageTransparency = selected and 0 or 1 }, time)
		end
		if item.Check then
			Anim.tween(item.Check, { BackgroundTransparency = selected and 0 or 1 }, time)
		end
	end

	for index, value in self.Values do
		local button = Util.create("TextButton", {
			Name = "Item",
			AutoButtonColor = false,
			Text = "",
			BorderSizePixel = 0,
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, ITEM),
			LayoutOrder = index,
			ZIndex = 11,
			Parent = rows,
		})
		theme:Bind(button, { BackgroundColor3 = "SurfaceHover" })
		Util.corner(button, 2)

		local item = { Value = value, Button = button, Hovered = false }
		if self.Multi then
			local check = Util.passive(Util.create("Frame", {
				Name = "Check",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 6, 0.5, 0),
				Size = UDim2.fromOffset(8, 8),
				BorderSizePixel = 0,
				ZIndex = 12,
				Parent = button,
			}))
			theme:Bind(check, { BackgroundColor3 = "Accent" })
			local checkStroke = Util.stroke(check)
			theme:Bind(checkStroke, { Color = "BorderLight" })
			item.Check = check
		else
			item.Mark = Style.icon(library, {
				Name = "Mark",
				Icon = "sigil",
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 5, 0.5, 0),
				Size = UDim2.fromOffset(10, 10),
				Color = "Accent",
				ZIndex = 12,
				Parent = button,
			})
		end
		item.Text = Style.label(library, {
			Text = tostring(value),
			Color = false,
			Position = UDim2.fromOffset(22, 0),
			Size = UDim2.new(1, -26, 1, 0),
			Truncate = true,
			ZIndex = 12,
			Parent = button,
		})

		button.MouseEnter:Connect(function()
			item.Hovered = true
			paintItem(item)
		end)
		button.MouseLeave:Connect(function()
			item.Hovered = false
			paintItem(item)
		end)
		button.Activated:Connect(function()
			if self.Multi then
				self:_toggleMulti(value)
				for _, other in items do
					paintItem(other)
				end
			else
				if self.Value == value and self.Options.AllowNull then
					self:SetValue(nil)
				else
					self:SetValue(value)
				end
				popup.Close()
			end
		end)
		paintItem(item, true)
		table.insert(items, item)
	end

	if searchable then
		local frame = Style.surface(library, {
			Name = "Search",
			Position = UDim2.fromOffset(4, 4),
			Size = UDim2.new(1, -8, 0, 20),
			ZIndex = 11,
			Parent = content,
		})
		Style.icon(library, {
			Icon = "search",
			AnchorPoint = Vector2.new(0, 0.5),
			Position = UDim2.new(0, 6, 0.5, 0),
			Size = UDim2.fromOffset(10, 10),
			Color = "TextMuted",
			ZIndex = 12,
			Parent = frame,
		})
		local search = Util.create("TextBox", {
			Name = "Query",
			BackgroundTransparency = 1,
			ClearTextOnFocus = false,
			PlaceholderText = "search...",
			Text = "",
			FontFace = Style.font(library, "Regular"),
			TextSize = Style.Small,
			TextXAlignment = Enum.TextXAlignment.Left,
			Position = UDim2.fromOffset(22, 0),
			Size = UDim2.new(1, -26, 1, 0),
			ZIndex = 12,
			Parent = frame,
		})
		theme:Bind(search, { TextColor3 = "Text", PlaceholderColor3 = "TextMuted" })
		search:GetPropertyChangedSignal("Text"):Connect(function()
			local shown = 0
			for _, item in items do
				local visible = Util.matches(search.Text, tostring(item.Value))
				item.Button.Visible = visible
				if visible then
					shown += 1
				end
			end
			popup:SetHeight(heightFor(shown))
		end)
		task.defer(function()
			if search.Parent then
				search:CaptureFocus()
			end
		end)
	end

	-- scroll the selection into view
	if not self.Multi and self.Value ~= nil then
		local index = table.find(self.Values, self.Value)
		if index and index > o.MaxVisible then
			list.CanvasPosition = Vector2.new(0, (index - o.MaxVisible) * ITEM)
		end
	end
end

function Dropdown:Close()
	if self._popup then
		self._popup.Close()
	end
end

function Dropdown:_toggleMulti(value)
	local set = table.clone(self.Value)
	set[value] = (not set[value]) or nil
	self.Value = set
	self:_render()
	self:_emit(set)
end

function Dropdown:SetValue(value)
	if self.Multi then
		local set = {}
		if type(value) == "table" then
			for key, v in value do
				if type(key) == "number" then
					set[v] = true
				elseif v then
					set[key] = true
				end
			end
		end
		self.Value = set
		self:_render()
		self:_emit(set)
		return
	end
	if value ~= nil and not table.find(self.Values, value) then
		return
	end
	if value == nil and not self.Options.AllowNull then
		return
	end
	if self.Value == value then
		return
	end
	self.Value = value
	self:_render()
	self:_emit(value)
end

function Dropdown:SetValues(values)
	self.Values = table.clone(values)
	if self.Multi then
		for value in table.clone(self.Value) do
			if not table.find(self.Values, value) then
				self.Value[value] = nil
			end
		end
	elseif self.Value ~= nil and not table.find(self.Values, self.Value) then
		self.Value = (not self.Options.AllowNull) and self.Values[1] or nil
		self:_emit(self.Value)
	end
	if self.Open then
		self:Close()
	end
	self:_render()
end

function Dropdown:AddValue(value)
	if not table.find(self.Values, value) then
		local values = table.clone(self.Values)
		table.insert(values, value)
		self:SetValues(values)
	end
end

function Dropdown:GetActiveValues()
	if not self.Multi then
		return self.Value ~= nil and { self.Value } or {}
	end
	local out = {}
	for _, value in self.Values do
		if self.Value[value] then
			table.insert(out, value)
		end
	end
	return out
end

function Dropdown:_searchText()
	local parts = { self.Text }
	for _, value in self.Values do
		table.insert(parts, tostring(value))
	end
	return table.concat(parts, " ")
end

function Dropdown:_serialize()
	if self.Multi then
		return self:GetActiveValues()
	end
	return self.Value
end

function Dropdown:_deserialize(data)
	if self.Multi then
		self:SetValue(type(data) == "table" and data or {})
	elseif data ~= nil then
		self:SetValue(data)
	end
end

function Dropdown:Destroy()
	self:Close()
	Element.Destroy(self)
end

return Dropdown
