--[[
	KeybindList
	Floating list of every bound key and whether it is currently active.
]]

local Util = import("core/Util")
local Style = import("components/Style")
local Floating = import("overlays/Floating")

local KeybindList = {}
KeybindList.__index = KeybindList

local WIDTH = 190
local ROW = 18

function KeybindList.new(library, layer)
	local self = setmetatable({}, KeybindList)
	self.Library = library
	self.Rows = {}

	local viewport = Util.viewport()
	local frame, maid, scale = Floating.panel(library, {
		Name = "Keybinds",
		Position = Vector2.new(16, math.floor(viewport.Y * 0.38)),
		Size = UDim2.fromOffset(WIDTH, 0),
		AutoSize = Enum.AutomaticSize.Y,
		Parent = layer,
	})
	self.Frame = frame
	self.Maid = maid
	self.UIScale = scale
	frame.Visible = false

	local column = Util.create("Frame", {
		Name = "Column",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		ZIndex = 16,
		Parent = frame,
	})
	Util.padding(column, 6, 10, 8, 10)
	Util.list(column, { Padding = 2 })

	local header = Util.create("Frame", {
		Name = "Header",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, ROW + 2),
		LayoutOrder = 0,
		ZIndex = 16,
		Parent = column,
	})
	Style.icon(library, {
		Icon = "keyboard",
		AnchorPoint = Vector2.new(0, 0.5),
		Position = UDim2.fromScale(0, 0.5),
		Size = UDim2.fromOffset(13, 13),
		Color = "Accent",
		ZIndex = 17,
		Parent = header,
	})
	Style.label(library, {
		Text = "KEYBINDS",
		Weight = "Bold",
		TextSize = Style.Small,
		Color = "Text",
		Position = UDim2.fromOffset(20, 0),
		Size = UDim2.new(1, -20, 1, 0),
		ZIndex = 17,
		Parent = header,
	})
	self.Column = column
	self.Empty = Style.label(library, {
		Name = "Empty",
		Text = "nothing bound",
		TextSize = Style.Tiny,
		Color = "TextMuted",
		Size = UDim2.new(1, 0, 0, ROW),
		ZIndex = 17,
		Parent = column,
	})
	self.Empty.LayoutOrder = 1
	return self
end

function KeybindList:Refresh()
	local library = self.Library
	local theme = library.Theme
	for _, row in self.Rows do
		row:Destroy()
	end
	table.clear(self.Rows)

	local shown = 0
	for index, keybind in library.Keybinds do
		if keybind.Value ~= nil and not keybind.Options.NoUI then
			shown += 1
			local active = keybind:GetState()
			local row = Util.create("Frame", {
				Name = "Bind",
				BackgroundTransparency = 1,
				Size = UDim2.new(1, 0, 0, ROW),
				LayoutOrder = index + 1,
				ZIndex = 16,
				Parent = self.Column,
			})
			local dot = Util.passive(Util.create("Frame", {
				Name = "Dot",
				BorderSizePixel = 0,
				AnchorPoint = Vector2.new(0, 0.5),
				Position = UDim2.new(0, 2, 0.5, 0),
				Size = UDim2.fromOffset(4, 4),
				BackgroundColor3 = theme:Get(active and "Accent" or "TextMuted"),
				ZIndex = 17,
				Parent = row,
			}))
			Util.corner(dot, 2)
			local name = Style.label(library, {
				Text = keybind.Text,
				TextSize = Style.Small,
				Color = false,
				Position = UDim2.fromOffset(14, 0),
				Size = UDim2.new(1, -70, 1, 0),
				Truncate = true,
				ZIndex = 17,
				Parent = row,
			})
			name.TextColor3 = theme:Get(active and "Text" or "TextDim")
			local key = Style.label(library, {
				Text = string.format("[%s] %s", Util.keyName(keybind.Value), string.lower(keybind.Mode)),
				TextSize = Style.Tiny,
				Color = false,
				XAlign = Enum.TextXAlignment.Right,
				AnchorPoint = Vector2.new(1, 0),
				Position = UDim2.fromScale(1, 0),
				Size = UDim2.new(0, 70, 1, 0),
				ZIndex = 17,
				Parent = row,
			})
			key.TextColor3 = theme:Get(active and "Accent" or "TextMuted")
			table.insert(self.Rows, row)
		end
	end
	self.Empty.Visible = shown == 0
end

function KeybindList:SetVisible(visible)
	self.Frame.Visible = visible
	if visible then
		self:Refresh()
	end
end

function KeybindList:SetScale(scale)
	self.UIScale.Scale = scale
end

function KeybindList:Destroy()
	self.Maid:Destroy()
end

return KeybindList
