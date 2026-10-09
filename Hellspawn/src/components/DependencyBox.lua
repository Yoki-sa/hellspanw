--[[
	DependencyBox
	A nested container that only shows while its dependencies hold — the
	ImGui "if (checkbox) { ... }" pattern.

		local box = group:AddDependencyBox()
		box:AddSlider("esp_thickness", { Text = "Thickness", Min = 1, Max = 4 })
		box:SetupDependencies({
			{ Hellspawn.Toggles.esp_box, true },          -- toggle must be on
			{ Hellspawn.Options.esp_mode, "Corner" },      -- dropdown must equal value
		})
]]

local Util = import("core/Util")
local Maid = import("core/Maid")
local Style = import("components/Style")
local Container = import("components/Container")

local DependencyBox = {}
DependencyBox.__index = DependencyBox
Container.mixin(DependencyBox)

function DependencyBox.new(parent)
	local self = setmetatable({}, DependencyBox)
	self.Library = parent.Library
	self.Window = parent.Window
	self.Parent = parent
	self.Elements = {}
	self.Dependencies = {}
	self.Maid = Maid.new()
	self.Satisfied = true

	local frame = Util.create("Frame", {
		Name = "DependencyBox",
		BackgroundTransparency = 1,
		Size = UDim2.new(1, 0, 0, 0),
		AutomaticSize = Enum.AutomaticSize.Y,
		LayoutOrder = parent:_order(),
		Parent = parent.List,
	})
	Util.list(frame, { Padding = Style.Gap })
	self.Instance = frame
	self.List = frame
	self.Maid:Give(frame)

	-- participates in search like any control
	table.insert(parent.Elements, self)
	return self
end

local function holds(element, expected)
	local value = element.Value
	if type(expected) == "function" then
		return expected(value) == true
	end
	if element.Multi and type(value) == "table" then
		return value[expected] == true
	end
	return value == expected
end

function DependencyBox:Update()
	local ok = true
	for _, dependency in self.Dependencies do
		if not holds(dependency[1], dependency[2]) then
			ok = false
			break
		end
	end
	self.Satisfied = ok
	self:_applyVisibility()
end

function DependencyBox:_applyVisibility()
	self.Instance.Visible = self.Satisfied and not self._filtered
end

function DependencyBox:SetupDependencies(dependencies)
	self.Maid:Clean("watch")
	local watch = Maid.new()
	self.Dependencies = dependencies
	for _, dependency in dependencies do
		local element = dependency[1]
		assert(type(element) == "table" and element.Changed, "DependencyBox: dependency must be a control")
		watch:Give(element.Changed:Connect(function()
			self:Update()
		end))
	end
	self.Maid:Set("watch", watch)
	self:Update()
end

-- search: visible when any child matches
function DependencyBox:_filter(query)
	if query == "" then
		for _, element in self.Elements do
			element:_filter("")
		end
		self._filtered = false
	else
		local shown = Container.Methods._filter(self, query)
		self._filtered = shown == 0
	end
	self:_applyVisibility()
	return not self._filtered and self.Satisfied
end

function DependencyBox:Destroy()
	for _, element in table.clone(self.Elements) do
		element:Destroy()
	end
	self.Maid:Destroy()
	local index = table.find(self.Parent.Elements, self)
	if index then
		table.remove(self.Parent.Elements, index)
	end
end

return DependencyBox
