--[[
	Theme
	Live theming. Instances bind properties to palette keys once; switching
	theme (or tweaking a single colour) re-tints the whole interface with a
	short colour tween.

		theme:Bind(frame, { BackgroundColor3 = "Panel" })
		theme:Bind(label, { TextColor3 = function(p) return p.Text:Lerp(p.Accent, 0.2) end })
		theme:Set("Narcissist")
		theme:SetOverride("Accent", Color3.fromRGB(255, 0, 90))
]]

local Signal = import("core/Signal")
local Util = import("core/Util")
local Anim = import("core/Anim")
local Themes = import("theme/Themes")

local Theme = {}
Theme.__index = Theme

local function toSequence(value)
	if typeof(value) == "ColorSequence" then
		return value
	end
	if type(value) == "table" then
		if #value == 1 then
			return ColorSequence.new(value[1])
		end
		local keys = {}
		for i, color in value do
			keys[i] = ColorSequenceKeypoint.new((i - 1) / (#value - 1), color)
		end
		return ColorSequence.new(keys)
	end
	if typeof(value) == "Color3" then
		return ColorSequence.new(value)
	end
	return nil
end

-- Fills derived keys so components can rely on every key existing
local function resolve(base, overrides)
	local p = {}
	for key, value in base do
		p[key] = value
	end
	for key, value in overrides do
		p[key] = value
	end
	if overrides.Accent and not overrides.AccentGradient then
		p.AccentGradient = nil -- custom accent: rebuild a matching gradient
	end

	p.Shadow = p.Shadow or Color3.new(0, 0, 0)
	p.Glow = p.Glow or p.Accent
	p.AccentLight = p.AccentLight or Util.lighten(p.Accent, 0.12)
	p.AccentDark = p.AccentDark or p.Accent:Lerp(p.Background, 0.62)
	p.AccentSoft = p.Accent:Lerp(p.Panel, 0.86)
	p.AccentGradient = toSequence(p.AccentGradient) or ColorSequence.new(p.AccentLight, p.Accent:Lerp(p.AccentDark, 0.3))
	p.OnAccent = Util.luminance(p.Accent) > 0.6 and p.Background or Color3.new(1, 1, 1)
	p.Grain = p.Grain or 0.09
	p.Scratches = p.Scratches or 0.07
	return p
end

function Theme.new(defaultName)
	local self = setmetatable({}, Theme)
	self.Registry = {}
	self.Order = {}
	self.Overrides = {}
	self.Changed = Signal.new()
	self._binds = {}
	self._watch = {}
	for _, name in Themes.Order do
		self:Register(name, Themes[name])
	end
	self:Set(defaultName or "Hellspawn", true)
	return self
end

function Theme:Register(name, palette)
	assert(type(name) == "string", "Theme:Register expects a name")
	assert(type(palette) == "table" and palette.Accent, "Theme palette needs at least an Accent")
	local base = self.Registry.Hellspawn
	local filled = {}
	if base then
		for key, value in base do
			filled[key] = value
		end
	end
	for key, value in palette do
		filled[key] = value
	end
	self.Registry[name] = filled
	if not table.find(self.Order, name) then
		table.insert(self.Order, name)
	end
end

function Theme:Resolve(key)
	if type(key) == "function" then
		return key(self.Current)
	end
	local value = self.Current[key]
	if value == nil then
		error("[Hellspawn] unknown theme key: " .. tostring(key), 2)
	end
	return value
end

function Theme:Get(key)
	return self.Current[key]
end

function Theme:Bind(instance, map)
	local entry = self._binds[instance]
	if not entry then
		entry = {}
		self._binds[instance] = entry
		self._watch[instance] = instance.Destroying:Connect(function()
			self:Unbind(instance)
		end)
	end
	for prop, key in map do
		entry[prop] = key
		instance[prop] = self:Resolve(key)
	end
	return instance
end

function Theme:Unbind(instance)
	self._binds[instance] = nil
	local watch = self._watch[instance]
	if watch then
		watch:Disconnect()
		self._watch[instance] = nil
	end
end

function Theme:_applyAll(instant)
	for instance, map in self._binds do
		for prop, key in map do
			local ok, value = pcall(self.Resolve, self, key)
			if ok then
				local kind = typeof(value)
				if instant or (kind ~= "Color3" and kind ~= "number") or not instance.Parent then
					instance[prop] = value
				else
					Anim.tween(instance, { [prop] = value }, 0.35, Enum.EasingStyle.Quad)
				end
			end
		end
	end
end

function Theme:Set(name, instant)
	local base = self.Registry[name]
	if not base then
		warn("[Hellspawn] unknown theme '" .. tostring(name) .. "'")
		return false
	end
	self.Name = name
	self.Current = resolve(base, self.Overrides)
	self:_applyAll(instant)
	self.Changed:FireSync(self.Current, instant)
	return true
end

function Theme:Refresh(instant)
	return self:Set(self.Name, instant)
end

function Theme:SetOverride(key, value, instant)
	self.Overrides[key] = value
	self:Refresh(instant)
end

function Theme:ClearOverrides(instant)
	table.clear(self.Overrides)
	self:Refresh(instant)
end

-- Serialisable snapshot (name + overrides as hex)
function Theme:Export()
	local overrides = {}
	for key, value in self.Overrides do
		if typeof(value) == "Color3" then
			overrides[key] = Util.toHex(value)
		end
	end
	return { Name = self.Name, Overrides = overrides }
end

function Theme:Import(data, instant)
	if type(data) ~= "table" then
		return false
	end
	table.clear(self.Overrides)
	if type(data.Overrides) == "table" then
		for key, hex in data.Overrides do
			local color = Util.fromHex(hex)
			if color then
				self.Overrides[key] = color
			end
		end
	end
	if not self:Set(data.Name or self.Name, instant) then
		return self:Refresh(instant)
	end
	return true
end

function Theme:Destroy()
	for _, watch in self._watch do
		watch:Disconnect()
	end
	table.clear(self._watch)
	table.clear(self._binds)
	self.Changed:DisconnectAll()
end

return Theme
