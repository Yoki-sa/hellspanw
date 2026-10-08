--[[
	Element
	Base class for every control. Handles flag registration, callbacks,
	visibility/disabled state, tooltips, search filtering, theming hooks and
	config (de)serialisation, so each control only implements its own look
	and behaviour.

	Subclasses implement:
		:_paint(instant)        restyle for current state + theme
		:SetValue(value)
		:_serialize() / :_deserialize(data)   (optional, defaults to Value)
]]

local Util = import("core/Util")
local Signal = import("core/Signal")
local Maid = import("core/Maid")

local Element = {}
Element.__index = Element

function Element.extend(kind)
	local class = setmetatable({}, { __index = Element })
	class.__index = class
	class.Kind = kind
	return class
end

-- Supports both AddX("flag", { ... }) and AddX({ Flag = "flag", ... })
function Element.args(flag, opts)
	if type(flag) == "table" then
		return flag.Flag or flag.Idx, flag
	end
	return flag, opts or {}
end

function Element.init(self, container, flag, opts, defaults)
	opts = Util.defaults(opts, defaults or {})
	self.Container = container
	self.Library = container.Library
	self.Window = container.Window
	self.Theme = self.Library.Theme
	self.Assets = self.Library.Assets
	self.Flag = flag
	self.Options = opts
	self.Text = opts.Text or opts.Title or opts.Name or flag or ""
	self.Callback = opts.Callback
	self.Changed = Signal.new()
	self.Maid = Maid.new()
	self.Disabled = opts.Disabled == true
	self.Visible = opts.Visible ~= false
	self.Hovered = false
	self._filtered = false
	return self
end

--[[
	Attaches the element's root instance.
	host: when given, the instance is an addon living inside another element
	      (no own row in the container).
]]
function Element:_mount(instance, host)
	self.Instance = instance
	self.Host = host
	self.Maid:Give(instance)
	if not host then
		instance.LayoutOrder = self.Container:_order()
		instance.Parent = self.Container.List
		table.insert(self.Container.Elements, self)
	end
	if self.Flag then
		self.Library:_registerOption(self.Flag, self)
	end
	self.Maid:Give(self.Theme.Changed:Connect(function(_, instant)
		self:_paint(instant)
	end))
	if self.Options.Tooltip then
		self:SetTooltip(self.Options.Tooltip)
	end
	self:_applyVisibility()
end

function Element:_paint() end

function Element:_applyVisibility()
	if self.Instance then
		self.Instance.Visible = self.Visible and not self._filtered
	end
end

-- Pushes a value out: flag table, Changed signal and user callback
function Element:_emit(value, ...)
	if self.Flag then
		self.Library.Flags[self.Flag] = value
	end
	self.Changed:Fire(value, ...)
	if self.Callback then
		task.spawn(Util.safeCall, self.Callback, value, ...)
	end
	self.Library:_elementChanged(self)
end

function Element:OnChanged(fn)
	return self.Changed:Connect(fn)
end

function Element:GetValue()
	return self.Value
end

function Element:SetVisible(visible)
	self.Visible = visible ~= false
	self:_applyVisibility()
end

function Element:SetDisabled(disabled)
	self.Disabled = disabled == true
	self:_paint()
end

function Element:SetText(text)
	self.Text = tostring(text)
	if self.Label then
		self.Label.Text = self.Text
	end
end

function Element:SetTooltip(text)
	if not text then
		self.Maid:Clean("tooltip")
		return
	end
	local target = self.Hitbox or self.Instance
	self.Maid:Set("tooltip", self.Library:_attachTooltip(target, text))
end

-- Search support: matched against label text plus anything extra a control adds
function Element:_searchText()
	return self.Text
end

function Element:_filter(query)
	self._filtered = not Util.matches(query, self:_searchText())
	self:_applyVisibility()
	return not self._filtered
end

function Element:_serialize()
	return self.Value
end

function Element:_deserialize(data)
	self:SetValue(data)
end

function Element:Destroy()
	if self._destroyed then
		return
	end
	self._destroyed = true
	if self.Flag then
		self.Library:_unregisterOption(self.Flag, self)
	end
	local list = self.Container and self.Container.Elements
	if list then
		local index = table.find(list, self)
		if index then
			table.remove(list, index)
		end
	end
	self.Changed:DisconnectAll()
	self.Maid:Destroy()
end

return Element
