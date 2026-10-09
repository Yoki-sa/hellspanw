--[[
	Watermark
	Draggable HUD strip:  ✦ hellspawn │ name │ 144 fps │ 32 ms │ 23:04:11
	library:SetWatermark("custom text") replaces the dynamic content;
	library:SetWatermark(nil) restores it.
]]

local Env = import("core/Env")
local Util = import("core/Util")
local Anim = import("core/Anim")
local Style = import("components/Style")
local Floating = import("overlays/Floating")

local Watermark = {}
Watermark.__index = Watermark

function Watermark.new(library, layer)
	local self = setmetatable({}, Watermark)
	self.Library = library
	self.Custom = nil

	local frame, maid, scale = Floating.panel(library, {
		Name = "Watermark",
		Position = Vector2.new(16, 16),
		Size = UDim2.fromOffset(200, 24),
		Parent = layer,
	})
	self.Frame = frame
	self.Maid = maid
	self.UIScale = scale
	frame.Visible = false

	local row = Util.create("Frame", {
		Name = "Row",
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(0, 1),
		AutomaticSize = Enum.AutomaticSize.X,
		ZIndex = 16,
		Parent = frame,
	})
	Util.padding(row, 0, 10, 0, 8)
	Util.list(row, {
		Direction = Enum.FillDirection.Horizontal,
		VAlign = Enum.VerticalAlignment.Center,
		Padding = 6,
	})

	local icon = Style.icon(library, {
		Icon = "sigil",
		Size = UDim2.fromOffset(10, 10),
		Color = "Accent",
		ZIndex = 17,
		Parent = row,
	})
	icon.LayoutOrder = 1
	self.Label = Style.label(library, {
		Name = "Text",
		Rich = true,
		TextSize = Style.Small,
		Color = "TextDim",
		Size = UDim2.fromOffset(0, 24),
		AutoSize = Enum.AutomaticSize.X,
		ZIndex = 17,
		Parent = row,
	})
	self.Label.LayoutOrder = 2
	maid:Give(Floating.follow(frame, row, "X", scale))

	local frames, clock = 0, 0
	maid:Give(Anim.frame(function(dt)
		frames += 1
		clock += dt
		if clock >= 0.5 then
			self:_render(frames / clock)
			frames, clock = 0, 0
		end
	end))
	self:_render(0)
	return self
end

function Watermark:_render(fps)
	if not self.Frame.Visible then
		return
	end
	local library = self.Library
	if self.Custom then
		self.Label.Text = self.Custom
		return
	end
	local theme = library.Theme
	local text = Util.toHex(theme:Get("Text"))
	local muted = Util.toHex(theme:Get("TextMuted"))
	local accent = Util.toHex(theme:Get("Accent"))
	local player = Env.service("Players").LocalPlayer
	local sep = string.format(" <font color=\"#%s\">|</font> ", muted)
	self.Label.Text = table.concat({
		string.format("<font color=\"#%s\">hell</font><font color=\"#%s\">spawn</font>", text, accent),
		Util.escape(player and player.Name or "?"),
		string.format("<font color=\"#%s\">%d</font> fps", text, math.floor(fps + 0.5)),
		string.format("<font color=\"#%s\">%d</font> ms", text, library:GetPing()),
		os.date("%H:%M:%S"),
	}, sep)
end

function Watermark:SetText(text)
	self.Custom = text
	self:_render(0)
end

function Watermark:SetVisible(visible)
	self.Frame.Visible = visible
	self:_render(0)
end

function Watermark:SetScale(scale)
	self.UIScale.Scale = scale
end

function Watermark:Destroy()
	self.Maid:Destroy()
end

return Watermark
