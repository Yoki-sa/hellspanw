--[[
	H E L L S P A W N
	ImGui-styled interface library for Roblox executors.

		local Hellspawn = loadstring(game:HttpGet(URL))()
		local Window = Hellspawn:CreateWindow({ Title = "Hellspawn", Subtitle = "// build 666" })
		local Combat = Window:AddTab({ Name = "Combat", Icon = "crosshair" })
		local Aim = Combat:AddLeftGroupbox("Aimbot")
		Aim:AddToggle("aim", { Text = "Enabled", Callback = print })

	Everything visual is generated at runtime: textures are painted by a
	built-in rasteriser and cached through getcustomasset, fonts are fetched
	from open-source repositories. See README.md for the full API.
]]

local Env = import("core/Env")
local Util = import("core/Util")
local Signal = import("core/Signal")
local Maid = import("core/Maid")
local Anim = import("core/Anim")
local Motion = import("core/Motion")
local Input = import("core/Input")
local Theme = import("theme/Theme")
local Assets = import("assets/Assets")
local Icons = import("render/Icons")
local Glow = import("fx/Glow")
local Cursor = import("fx/Cursor")
local Window = import("components/Window")
local Popups = import("overlays/Popups")
local Notifications = import("overlays/Notifications")
local Tooltip = import("overlays/Tooltip")
local Watermark = import("overlays/Watermark")
local KeybindList = import("overlays/KeybindList")
local Intro = import("overlays/Intro")
local MobileButton = import("overlays/MobileButton")
local Config = import("managers/Config")

local Library = {}
Library.__index = Library

local DEFAULT_SETTINGS = {
	Animations = true,
	Glow = true,
	GlowIntensity = 1,
	Embers = true,
	Grain = true,
	Scratches = true,
	Scanlines = true,
	Vignette = true,
	Glitch = true,
	Cursor = true,
	SmoothDrag = true,
	Tooltips = true,
	UnlockMouse = true,
}

local function randomName()
	local ok, guid = pcall(function()
		return Env.service("HttpService"):GenerateGUID(false)
	end)
	if ok and type(guid) == "string" then
		return string.lower(string.sub(string.gsub(guid, "-", ""), 1, 12))
	end
	return "hs" .. math.random(100000, 999999)
end

function Library.new()
	-- re-executing the script replaces the previous instance cleanly
	local previous = Env.genv.__HELLSPAWN
	if type(previous) == "table" and type(previous.Unload) == "function" then
		pcall(previous.Unload, previous)
	end

	local self = setmetatable({}, Library)
	self.Version = VERSION
	self.Folder = "Hellspawn"
	self.Flags = {}
	self.Options = {}
	self.Toggles = {}
	self.Keybinds = {}
	self.Windows = {}
	self.Settings = table.clone(DEFAULT_SETTINGS)
	self.Scale = 1
	self.Executor = Env.executor()
	self.Env = Env
	self.Icons = table.clone(Icons.Order)
	self.Booted = false
	self.Maid = Maid.new()
	self.SettingChanged = Signal.new()
	self.Unloaded = Signal.new()
	self.RainbowTick = Signal.new()
	self.RainbowHue = 0
	self.Theme = Theme.new("Hellspawn")
	self.Assets = Assets.new(self.Folder)
	self.Config = Config.new(self)
	Env.genv.__HELLSPAWN = self
	return self
end

----------------------------------------------------------------------
-- boot
----------------------------------------------------------------------

function Library:_buildLayers()
	local function layer(order)
		local gui = Util.create("ScreenGui", {
			Name = randomName(),
			IgnoreGuiInset = true,
			ResetOnSpawn = false,
			ZIndexBehavior = Enum.ZIndexBehavior.Sibling,
			DisplayOrder = order,
		})
		pcall(function()
			gui.ScreenInsets = Enum.ScreenInsets.None
		end)
		gui.Parent = Env.guiParent(gui)
		self.Maid:Give(gui)
		return gui
	end
	self.Layers = {
		Windows = layer(9990),
		Overlay = layer(9991),
		Popups = layer(9992),
		Top = layer(9993),
	}
	-- a zero-size modal button frees the mouse in first-person games while open
	self.Unlocker = Util.create("TextButton", {
		Name = randomName(),
		BackgroundTransparency = 1,
		Text = "",
		Size = UDim2.new(),
		Modal = true,
		Visible = false,
		Parent = self.Layers.Windows,
	})
end

function Library:_buildOverlays()
	self.Popups = Popups.new(self, self.Layers.Popups)
	self.Notifications = Notifications.new(self, self.Layers.Overlay)
	self.Tooltip = Tooltip.new(self, self.Layers.Top)
	self.Watermark = Watermark.new(self, self.Layers.Overlay)
	self.KeybindList = KeybindList.new(self, self.Layers.Overlay)
	self.Cursor = Cursor.new(self, self.Layers.Top)
	if Input.touchEnabled() then
		self.MobileButton = MobileButton.new(self, self.Layers.Overlay)
	end

	self.Maid:Give(Anim.frame(function(dt)
		self.RainbowHue = (self.RainbowHue + dt * 0.12) % 1
		self.RainbowTick:FireSync(self.RainbowHue)
	end))
	self.Maid:Give(self.Theme.Changed:Connect(function()
		self:_keybindsChanged()
	end))
end

--[[
	First window boot: builds layers, plays the intro while textures are
	forged and fonts are fetched, then builds the shared overlays. Yields.
]]
function Library:_boot(opts)
	if self.Booted then
		return
	end
	self.Booted = true
	opts = opts or {}
	self:_buildLayers()

	local intro
	if opts.Intro ~= false then
		local ok, result = pcall(Intro.new, self, self.Layers.Top, { Title = opts.IntroTitle or opts.Title })
		if ok then
			intro = result
			intro:Play()
		else
			warn("[Hellspawn] intro failed: " .. tostring(result))
		end
	end

	local progress = self.Assets.Progress:Connect(function(fraction, label)
		if intro then
			intro:SetProgress(fraction, label)
		end
	end)
	local ok, err = pcall(self.Assets.Load, self.Assets, { Fonts = opts.CustomFonts ~= false })
	if not ok then
		warn("[Hellspawn] asset loading failed, continuing with fallbacks: " .. tostring(err))
	end
	progress:Disconnect()

	if intro then
		intro:RefreshFonts()
		intro:Finish()
	end
	self:_buildOverlays()
end

----------------------------------------------------------------------
-- windows
----------------------------------------------------------------------

--[[
	opts (all optional):
		Title, Subtitle, Width, Height, MinWidth, MinHeight, Position (Vector2)
		ToggleKey (Enum.KeyCode, default RightShift), Resizable, ShowUser
		Theme (name), Accent (Color3), Scale (number), Folder (string)
		Intro (bool), CustomFonts (bool), Settings ({ Embers = false, ... })
		Background (icon name / asset id / URL) + BackgroundTransparency
		Logo (icon name / asset id / URL)
]]
function Library:CreateWindow(opts)
	opts = opts or {}
	if not self.Booted then
		if opts.Folder then
			self.Folder = opts.Folder
			self.Assets.Folder = opts.Folder
			self.Config.Folder = opts.Folder .. "/configs"
		end
		if opts.Scale then
			self.Scale = opts.Scale
		end
	end
	if type(opts.Settings) == "table" then
		for key, value in opts.Settings do
			self.Settings[key] = value
		end
		Anim.Speed = self.Settings.Animations and 1 or 0
	end
	if opts.Theme then
		self.Theme:Set(opts.Theme, true)
	end
	if opts.Accent then
		self.Theme:SetOverride("Accent", opts.Accent, true)
	end

	self:_boot(opts)
	local window = Window.new(self, opts)
	table.insert(self.Windows, window)
	if opts.Visible ~= false then
		window:SetVisible(true)
	end
	return window
end

function Library:AnyWindowVisible()
	for _, window in self.Windows do
		if window.Visible then
			return true
		end
	end
	return false
end

function Library:IsMouseOverUI()
	for _, window in self.Windows do
		if window:IsMouseOver() then
			return true
		end
	end
	local popup = self.Popups and self.Popups.Current
	if popup and Input.within(popup.Root) then
		return true
	end
	return false
end

function Library:Toggle()
	local show = not self:AnyWindowVisible()
	for _, window in self.Windows do
		window:SetVisible(show)
	end
end

function Library:_visibilityChanged()
	local any = self:AnyWindowVisible()
	if self.Unlocker then
		self.Unlocker.Visible = any and self.Settings.UnlockMouse
	end
	if not any and self.Tooltip then
		self.Tooltip:_hide()
	end
end

----------------------------------------------------------------------
-- settings / theme / scale
----------------------------------------------------------------------

function Library:SetSetting(key, value)
	self.Settings[key] = value
	if key == "Animations" then
		Anim.Speed = value and 1 or 0
	elseif key == "Glow" or key == "GlowIntensity" then
		Glow.refresh(self)
	end
	self:_visibilityChanged()
	self.SettingChanged:Fire(key, value)
end

function Library:SetTheme(name)
	return self.Theme:Set(name)
end

function Library:SetAccent(color)
	self.Theme:SetOverride("Accent", color)
end

function Library:RegisterTheme(name, palette)
	self.Theme:Register(name, palette)
end

function Library:SetScale(scale)
	scale = math.clamp(scale, 0.5, 2)
	self.Scale = scale
	for _, window in self.Windows do
		window.UIScale.Scale = scale
	end
	for _, overlay in { self.Notifications, self.Tooltip, self.Watermark, self.KeybindList, self.MobileButton } do
		if overlay then
			overlay:SetScale(scale)
		end
	end
end

----------------------------------------------------------------------
-- overlays
----------------------------------------------------------------------

function Library:Notify(opts, duration)
	if type(opts) == "string" then
		opts = { Content = opts, Duration = duration }
	end
	if not self.Booted then
		self:_boot({ Intro = false })
	end
	return self.Notifications:Push(opts)
end

function Library:SetWatermarkVisible(visible)
	if self.Watermark then
		self.Watermark:SetVisible(visible)
	end
end

function Library:SetWatermark(text)
	if self.Watermark then
		self.Watermark:SetText(text)
	end
end

function Library:SetKeybindListVisible(visible)
	if self.KeybindList then
		self.KeybindList:SetVisible(visible)
	end
end

function Library:GetPing()
	local now = os.clock()
	if self._ping and now - (self._pingClock or 0) < 1 then
		return self._ping
	end
	self._pingClock = now
	local ping = 0
	local ok, value = pcall(function()
		return Env.service("Stats").Network.ServerStatsItem["Data Ping"]:GetValue()
	end)
	if ok and type(value) == "number" then
		ping = value
	else
		local okPlayer, seconds = pcall(function()
			return Env.service("Players").LocalPlayer:GetNetworkPing()
		end)
		if okPlayer and type(seconds) == "number" then
			ping = seconds * 2000
		end
	end
	self._ping = math.floor(ping + 0.5)
	return self._ping
end

----------------------------------------------------------------------
-- internal registries used by components
----------------------------------------------------------------------

function Library:_registerOption(flag, element)
	local existing = self.Options[flag]
	if existing and existing ~= element then
		warn(string.format("[Hellspawn] flag '%s' is used twice; the newer control wins", flag))
	end
	self.Options[flag] = element
	if element.Kind == "Toggle" then
		self.Toggles[flag] = element
	end
end

function Library:_unregisterOption(flag, element)
	if self.Options[flag] == element then
		self.Options[flag] = nil
		self.Toggles[flag] = nil
		self.Flags[flag] = nil
	end
end

function Library:_elementChanged() end

function Library:_attachTooltip(target, text)
	if not self.Tooltip then
		return nil
	end
	return self.Tooltip:Attach(target, text)
end

function Library:_registerKeybind(keybind)
	table.insert(self.Keybinds, keybind)
	self:_keybindsChanged()
end

function Library:_unregisterKeybind(keybind)
	local index = table.find(self.Keybinds, keybind)
	if index then
		table.remove(self.Keybinds, index)
	end
	self:_keybindsChanged()
end

-- batched: many binds can change in one frame
function Library:_keybindsChanged()
	if self._keybindRefreshQueued or not self.KeybindList then
		return
	end
	self._keybindRefreshQueued = true
	task.defer(function()
		self._keybindRefreshQueued = false
		if self.KeybindList and self.KeybindList.Frame.Visible then
			self.KeybindList:Refresh()
		end
	end)
end

----------------------------------------------------------------------
-- lifecycle
----------------------------------------------------------------------

function Library:OnUnload(fn)
	return self.Unloaded:Connect(fn)
end

function Library:Unload()
	if self._unloaded then
		return
	end
	self._unloaded = true
	self.Unloaded:Fire() -- user handlers run isolated; a bad one can't stop unloading

	for _, window in self.Windows do
		pcall(window.Destroy, window)
	end
	table.clear(self.Windows)
	for _, overlay in { self.Popups, self.Notifications, self.Tooltip, self.Watermark, self.KeybindList, self.Cursor, self.MobileButton } do
		if overlay then
			pcall(overlay.Destroy, overlay)
		end
	end
	self.Maid:Destroy()
	self.Theme:Destroy()
	self.SettingChanged:DisconnectAll()
	self.RainbowTick:DisconnectAll()
	Anim.stopAll()
	Motion.stopAll()
	Input.destroy()
	if Env.genv.__HELLSPAWN == self then
		Env.genv.__HELLSPAWN = nil
	end
end

return Library.new()
