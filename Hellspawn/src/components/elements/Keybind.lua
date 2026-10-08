--[[
	Keybind
	ImGui key picker. Click to listen, press a key or mouse button to bind,
	Backspace clears, Escape cancels. Right-click to pick the mode:
		Toggle  press flips the state
		Hold    state is on while held
		Always  always on
	Attached to a toggle it drives that toggle directly (SyncToggleState).

		toggle:AddKeybind("aim_key", { Default = "MB2", Mode = "Hold" })
		box:AddKeybind("panic", { Text = "Panic", Default = Enum.KeyCode.End, Callback = fn })
]]

local Util = import("core/Util")
local Anim = import("core/Anim")
local Input = import("core/Input")
local Signal = import("core/Signal")
local Glow = import("fx/Glow")
local Style = import("components/Style")
local Element = import("components/Element")

local Keybind = Element.extend("Keybind")

local MODES = { "Toggle", "Hold", "Always" }
local MOUSE_ALIASES = {
	MB1 = Enum.UserInputType.MouseButton1,
	MB2 = Enum.UserInputType.MouseButton2,
	MB3 = Enum.UserInputType.MouseButton3,
	LMB = Enum.UserInputType.MouseButton1,
	RMB = Enum.UserInputType.MouseButton2,
	MMB = Enum.UserInputType.MouseButton3,
}

function Keybind.parse(key)
	if key == nil or key == "None" or key == "" then
		return nil
	end
	if typeof(key) == "EnumItem" then
		return key
	end
	if type(key) == "string" then
		if MOUSE_ALIASES[key] then
			return MOUSE_ALIASES[key]
		end
		local ok, code = pcall(function()
			return Enum.KeyCode[key]
		end)
		if ok and code then
			return code
		end
		local okType, kind = pcall(function()
			return Enum.UserInputType[key]
		end)
		if okType and kind then
			return kind
		end
	end
	return nil
end

local function matches(key, io)
	if key == nil then
		return false
	end
	if key.EnumType == Enum.KeyCode then
		return io.UserInputType == Enum.UserInputType.Keyboard and io.KeyCode == key
	end
	return io.UserInputType == key
end

function Keybind.new(container, flag, opts, host)
	flag, opts = Element.args(flag, opts)
	local self = setmetatable({}, Keybind)
	Element.init(self, container, flag, opts, {
		Text = host and host.Text or "Keybind",
		Mode = "Toggle",
		SyncToggleState = host ~= nil and host.Kind == "Toggle",
		NoUI = false,
	})
	local o = self.Options
	self.Value = Keybind.parse(o.Default)
	self.Mode = table.find(MODES, o.Mode) and o.Mode or "Toggle"
	self.Toggled = false
	self.Held = false
	self.Picking = false
	self.Pressed = Signal.new()
	self.StateChanged = Signal.new()
	self.HostToggle = (host and host.Kind == "Toggle") and host or nil

	local library = self.Library
	local theme = self.Theme

	local button = Util.create("TextButton", {
		Name = "Keybind",
		AutoButtonColor = false,
		RichText = true,
		Text = "",
		FontFace = Style.font(library, "Regular"),
		TextSize = Style.Tiny,
		BorderSizePixel = 0,
		Size = UDim2.fromOffset(34, 14),
		ZIndex = 3,
	})
	-- width follows the text (no AutomaticSize: the glow fallback is a
	-- scale-sized child and would make it grow without bound)
	button:GetPropertyChangedSignal("TextBounds"):Connect(function()
		button.Size = UDim2.fromOffset(math.max(22, math.ceil(button.TextBounds.X) + 10), 14)
	end)
	Util.corner(button, 2)
	theme:Bind(button, { BackgroundColor3 = "Surface" })
	self.Stroke = Util.stroke(button)
	self.Button = button
	self.Hitbox = button
	self.Glow = Glow.attach(library, button, { Spread = 7, Strength = 0 })

	if host then
		button.LayoutOrder = #host.Addons:GetChildren()
		button.Parent = host.Addons
		self:_mount(button, host)
	else
		local row = Util.create("Frame", {
			Name = "KeybindRow",
			BackgroundTransparency = 1,
			Size = UDim2.new(1, 0, 0, Style.Row),
		})
		self.Label = Style.label(library, {
			Text = self.Text,
			Weight = "Medium",
			Color = "TextDim",
			Size = UDim2.new(1, -70, 1, 0),
			Truncate = true,
			Parent = row,
		})
		button.AnchorPoint = Vector2.new(1, 0.5)
		button.Position = UDim2.fromScale(1, 0.5)
		button.Parent = row
		self:_mount(row)
	end

	self.Maid:Give((Input.hover(button, function(state)
		self.Hovered = state
		self:_paint()
	end)))
	self.Maid:Give(button.Activated:Connect(function()
		if not self.Disabled and not self.Picking then
			self:_beginPicking()
		end
	end))
	self.Maid:Give(button.MouseButton2Click:Connect(function()
		if not self.Disabled then
			self:_openModes()
		end
	end))

	self.Maid:Give(Input.Began:Connect(function(io)
		self:_onBegan(io)
	end))
	self.Maid:Give(Input.Ended:Connect(function(io)
		if self.Mode == "Hold" and matches(self.Value, io) and self.Held then
			self.Held = false
			self:_stateChanged()
		end
	end))

	if self.HostToggle then
		self.Toggled = self.HostToggle.Value
		self.Maid:Give(self.HostToggle.Changed:Connect(function(value)
			if self.Mode == "Toggle" then
				self.Toggled = value
				library:_keybindsChanged()
			end
		end))
	end

	library:_registerKeybind(self)
	self.Maid:Give(function()
		library:_unregisterKeybind(self)
	end)
	if self.Flag then
		library.Flags[self.Flag] = self.Value
	end
	self:_render()
	self:_paint(true)
	return self
end

function Keybind:_render()
	if self.Picking then
		self.Button.Text = "..."
		return
	end
	local muted = Util.toHex(self.Theme:Get("TextMuted"))
	local name = self.Value and Util.keyName(self.Value) or "none"
	self.Button.Text = string.format("<font color=\"#%s\">[</font>%s<font color=\"#%s\">]</font>", muted, Util.escape(name), muted)
end

function Keybind:_paint(instant)
	local theme = self.Theme
	local time = instant and 0 or 0.15
	local active = self:GetState() and self.Value ~= nil
	local textKey = self.Picking and "Accent" or (self.Disabled and "TextMuted" or ((self.Hovered or active) and "Text" or "TextDim"))
	Anim.tween(self.Button, { TextColor3 = theme:Get(textKey) }, time)
	Anim.tween(self.Stroke, {
		Color = theme:Get(self.Picking and "Accent" or (self.Hovered and "AccentDark" or "Border")),
	}, time)
	Glow.set(self.Glow, self.Picking and 0.5 or 0, instant and 0 or 0.2)
	self:_render()
end

function Keybind:_beginPicking()
	self.Picking = true
	self.Library._picking = self
	self:_paint()
	local pulse = Anim.frame(function(_, now)
		self.Button.TextTransparency = 0.25 + 0.25 * math.sin(now * 10)
	end)
	local connection
	local done = false
	local function finish(newKey, cancelled)
		if done then
			return
		end
		done = true
		if connection then
			connection:Disconnect()
		end
		pulse()
		self.Button.TextTransparency = 0
		self.Picking = false
		-- released a frame later so the bound key can't also trigger menu hotkeys
		task.defer(function()
			if self.Library._picking == self then
				self.Library._picking = nil
			end
		end)
		if not cancelled then
			self:SetValue(newKey)
		end
		self:_paint()
	end
	-- wait a frame so the click that opened the picker isn't captured
	task.defer(function()
		if done then
			return
		end
		connection = Input.Began:Connect(function(io)
			local kind = io.UserInputType
			if kind == Enum.UserInputType.Keyboard then
				if io.KeyCode == Enum.KeyCode.Escape then
					finish(nil, true)
				elseif io.KeyCode == Enum.KeyCode.Backspace or io.KeyCode == Enum.KeyCode.Delete then
					finish(nil, false)
				else
					finish(io.KeyCode, false)
				end
			elseif kind == Enum.UserInputType.MouseButton1
				or kind == Enum.UserInputType.MouseButton2
				or kind == Enum.UserInputType.MouseButton3
			then
				finish(kind, false)
			end
		end)
	end)
	self.Maid:Set("picking", function()
		finish(nil, true)
	end)
end

function Keybind:_openModes()
	local library = self.Library
	local theme = self.Theme
	local popup = library.Popups:Open({
		Owner = self.Button,
		Width = 92,
		Height = #MODES * 20 + 8,
		Align = "right",
	})
	local list = Util.create("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 11,
		Parent = popup.Content,
	})
	Util.list(list)
	Util.padding(list, 4, 4, 4, 4)
	for index, mode in MODES do
		local item = Util.create("TextButton", {
			Name = mode,
			AutoButtonColor = false,
			Text = "",
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Size = UDim2.new(1, 0, 0, 20),
			LayoutOrder = index,
			ZIndex = 11,
			Parent = list,
		})
		theme:Bind(item, { BackgroundColor3 = "SurfaceHover" })
		Util.corner(item, 2)
		local label = Style.label(library, {
			Text = string.lower(mode),
			Color = false,
			Position = UDim2.fromOffset(8, 0),
			Size = UDim2.new(1, -8, 1, 0),
			ZIndex = 12,
			Parent = item,
		})
		label.TextColor3 = theme:Get(self.Mode == mode and "Accent" or "TextDim")
		item.MouseEnter:Connect(function()
			item.BackgroundTransparency = 0
		end)
		item.MouseLeave:Connect(function()
			item.BackgroundTransparency = 1
		end)
		item.Activated:Connect(function()
			self:SetMode(mode)
			popup.Close()
		end)
	end
end

function Keybind:_onBegan(io)
	if self.Picking or self.Value == nil or self.Disabled then
		return
	end
	if not matches(self.Value, io) then
		return
	end
	if Input.isTyping() then
		return
	end
	local isMouse = self.Value.EnumType == Enum.UserInputType
	if isMouse and self.Library:IsMouseOverUI() then
		return -- clicking the menu shouldn't fire mouse binds
	end
	self.Pressed:Fire()
	if self.Mode == "Toggle" then
		if self.HostToggle and self.Options.SyncToggleState then
			self.HostToggle:SetValue(not self.HostToggle.Value)
			self.Toggled = self.HostToggle.Value
		else
			self.Toggled = not self.Toggled
		end
		self:_stateChanged()
	elseif self.Mode == "Hold" then
		self.Held = true
		self:_stateChanged()
	end
end

function Keybind:_stateChanged()
	local state = self:GetState()
	if self.HostToggle and self.Options.SyncToggleState and self.Mode == "Hold" then
		self.HostToggle:SetValue(state)
	end
	self.StateChanged:Fire(state)
	if self.Callback then
		task.spawn(Util.safeCall, self.Callback, state)
	end
	self.Library:_keybindsChanged()
	self:_paint()
end

function Keybind:GetState()
	if self.Mode == "Always" then
		return true
	elseif self.Mode == "Hold" then
		return self.Held
	end
	return self.Toggled
end

function Keybind:IsDown()
	return Input.isDown(self.Value)
end

function Keybind:OnClick(fn)
	return self.Pressed:Connect(fn)
end

function Keybind:SetValue(key, mode)
	if type(key) == "table" then
		key, mode = key[1], key[2]
	end
	local parsed = Keybind.parse(key)
	if mode and table.find(MODES, mode) then
		self.Mode = mode
	end
	self.Value = parsed
	self.Held = false
	if self.Flag then
		self.Library.Flags[self.Flag] = parsed
	end
	self.Changed:Fire(parsed)
	if self.Options.ChangedCallback then
		task.spawn(Util.safeCall, self.Options.ChangedCallback, parsed)
	end
	self.Library:_elementChanged(self)
	self.Library:_keybindsChanged()
	self:_paint()
end

function Keybind:SetMode(mode)
	if not table.find(MODES, mode) then
		return
	end
	self.Mode = mode
	self.Held = false
	self:_stateChanged()
end

function Keybind:_searchText()
	return self.Text .. " " .. (self.Value and Util.keyName(self.Value) or "")
end

function Keybind:_serialize()
	return {
		Key = self.Value and self.Value.Name or "None",
		Mode = self.Mode,
	}
end

function Keybind:_deserialize(data)
	if type(data) ~= "table" then
		return
	end
	self:SetValue(data.Key, data.Mode)
end

function Keybind:Destroy()
	self.Pressed:DisconnectAll()
	self.StateChanged:DisconnectAll()
	Element.Destroy(self)
end

return Keybind
