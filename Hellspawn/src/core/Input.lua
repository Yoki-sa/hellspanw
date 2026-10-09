--[[
	Input
	Mouse/touch helpers that never fight the game for input:
	  • dragging tracks UserInputService globally instead of a full-screen
	    catcher, so nothing outside the menu is ever blocked
	  • releases that get swallowed (alt-tab, focus loss) are detected and
	    recovered from
	  • hover state self-corrects when the UI moves out from under a still mouse
]]

local Env = import("core/Env")
local Signal = import("core/Signal")
local Maid = import("core/Maid")

local Input = {}

local UIS = Env.service("UserInputService")
local GuiService = Env.service("GuiService")

local MOUSE_TYPES = {
	[Enum.UserInputType.MouseButton1] = true,
	[Enum.UserInputType.MouseButton2] = true,
	[Enum.UserInputType.MouseButton3] = true,
	[Enum.UserInputType.MouseMovement] = true,
	[Enum.UserInputType.MouseWheel] = true,
}

Input.Service = UIS
-- optional fn(point, handle) -> true to swallow a press (set by the library)
Input.blocker = nil
Input.Began = Signal.new() -- (InputObject, gameProcessed)
Input.Ended = Signal.new()
Input.Changed = Signal.new()

local maid = Maid.new()
-- every hover/drag tracker, so unloading can tear down stragglers
local trackers = {}

local function track(tracker, gui)
	trackers[tracker] = true
	tracker:Give(gui.Destroying:Connect(function()
		tracker:Destroy()
	end))
	tracker:Give(function()
		trackers[tracker] = nil
	end)
	return tracker
end
maid:Give(UIS.InputBegan:Connect(function(io, processed)
	Input.Began:FireSync(io, processed)
end))
maid:Give(UIS.InputEnded:Connect(function(io, processed)
	Input.Ended:FireSync(io, processed)
end))
maid:Give(UIS.InputChanged:Connect(function(io, processed)
	Input.Changed:FireSync(io, processed)
end))

function Input.destroy()
	Input.blocker = nil
	for tracker in table.clone(trackers) do
		tracker:Destroy()
	end
	maid:Destroy()
	Input.Began:DisconnectAll()
	Input.Ended:DisconnectAll()
	Input.Changed:DisconnectAll()
end

--[[
	Two coordinate spaces exist in Roblox and mixing them is the classic
	"everything is 58px off" bug:

	  screen space    GetMouseLocation(); also Position offsets inside our
	                  ScreenGuis, which all use IgnoreGuiInset = true
	  absolute space  GuiObject.AbsolutePosition and InputObject.Position;
	                  always measured from *below* the top-bar inset, even
	                  when IgnoreGuiInset is on

	  screen = absolute + GuiService:GetGuiInset()

	Hit tests compare against AbsolutePosition, so they use absolute space.
	Placing frames (popups, tooltips, cursor) uses screen space.
]]
function Input.inset()
	local topLeft = GuiService:GetGuiInset()
	return topLeft
end

-- Mouse in screen space (for positioning things under the cursor)
function Input.mouse()
	return UIS:GetMouseLocation()
end

-- Mouse in absolute space (for comparing with AbsolutePosition)
function Input.pointer()
	return UIS:GetMouseLocation() - Input.inset()
end

-- Absolute-space position of any input object
function Input.position(io)
	if io == nil or MOUSE_TYPES[io.UserInputType] then
		return Input.pointer()
	end
	return Vector2.new(io.Position.X, io.Position.Y)
end

-- Converts an absolute-space point to screen space
function Input.toScreen(point)
	return point + Input.inset()
end

function Input.isPress(io)
	local t = io.UserInputType
	return t == Enum.UserInputType.MouseButton1 or t == Enum.UserInputType.Touch
end

function Input.isMove(io)
	local t = io.UserInputType
	return t == Enum.UserInputType.MouseMovement or t == Enum.UserInputType.Touch
end

function Input.isTyping()
	return UIS:GetFocusedTextBox() ~= nil
end

function Input.touchEnabled()
	return UIS.TouchEnabled and not UIS.KeyboardEnabled
end

function Input.isDown(key)
	if key == nil then
		return false
	end
	if key.EnumType == Enum.KeyCode then
		return UIS:IsKeyDown(key)
	end
	if key.EnumType == Enum.UserInputType then
		return UIS:IsMouseButtonPressed(key)
	end
	return false
end

-- point is in absolute space (defaults to the mouse)
function Input.within(gui, point)
	point = point or Input.pointer()
	local pos, size = gui.AbsolutePosition, gui.AbsoluteSize
	return point.X >= pos.X and point.X <= pos.X + size.X and point.Y >= pos.Y and point.Y <= pos.Y + size.Y
end

--[[
	Robust hover tracking. fn(isHovered) fires on every change.
	Returns a Maid (destroy to stop) and a getter for the current state.
]]
function Input.hover(gui, fn)
	local hoverMaid = track(Maid.new(), gui)
	local hovered = false

	local function set(state)
		if hovered == state then
			return
		end
		hovered = state
		if state then
			hoverMaid:Set("watch", UIS.InputChanged:Connect(function(io)
				if io.UserInputType == Enum.UserInputType.MouseMovement and not Input.within(gui) then
					set(false)
				end
			end))
		else
			hoverMaid:Clean("watch")
		end
		fn(state)
	end

	hoverMaid:Give(gui.MouseEnter:Connect(function()
		-- controls hidden under an open popup don't light up through it
		if Input.blocker and Input.blocker(Input.pointer(), gui) then
			return
		end
		set(true)
	end))
	hoverMaid:Give(gui.MouseLeave:Connect(function()
		set(false)
	end))
	hoverMaid:Give(gui:GetPropertyChangedSignal("Visible"):Connect(function()
		if not gui.Visible then
			set(false)
		end
	end))
	hoverMaid:Give(function()
		hovered = false
	end)

	return hoverMaid, function()
		return hovered
	end
end

--[[
	Generic drag controller used by windows, sliders, pickers and resizers.
	handlers:
		canStart(io)            -> bool   (optional)
		onStart(origin, io)               (optional)
		onMove(position, delta, io)
		onEnd(position, io)               (optional)
]]
function Input.drag(handle, handlers)
	local dragMaid = track(Maid.new(), handle)
	local dragging = false
	local activeInput = nil
	local origin = Vector2.zero

	local function finish(io)
		if not dragging then
			return
		end
		dragging = false
		activeInput = nil
		dragMaid:Clean("move")
		dragMaid:Clean("release")
		if handlers.onEnd then
			handlers.onEnd(Input.position(io), io)
		end
	end

	dragMaid:Give(handle.InputBegan:Connect(function(io)
		if dragging or not Input.isPress(io) then
			return
		end
		-- InputBegan reaches objects hidden underneath other layers too, so
		-- presses that land on an open popup must not start drags behind it
		if Input.blocker and Input.blocker(Input.position(io), handle) then
			return
		end
		if handlers.canStart and not handlers.canStart(io) then
			return
		end
		dragging = true
		activeInput = io
		origin = Input.position(io)
		local isMouse = io.UserInputType == Enum.UserInputType.MouseButton1

		if handlers.onStart then
			handlers.onStart(origin, io)
		end

		dragMaid:Set("move", UIS.InputChanged:Connect(function(change)
			local kind = change.UserInputType
			if isMouse and kind == Enum.UserInputType.MouseMovement then
				if not UIS:IsMouseButtonPressed(Enum.UserInputType.MouseButton1) then
					finish(change) -- release was swallowed somewhere
					return
				end
			elseif not (kind == Enum.UserInputType.Touch and change == activeInput) then
				return
			end
			local position = Input.position(change)
			handlers.onMove(position, position - origin, change)
		end))

		dragMaid:Set("release", UIS.InputEnded:Connect(function(ended)
			if ended == activeInput or (isMouse and ended.UserInputType == Enum.UserInputType.MouseButton1) then
				finish(ended)
			end
		end))
	end))

	dragMaid:Give(function()
		dragging = false
	end)

	return dragMaid, function()
		return dragging
	end
end

return Input
