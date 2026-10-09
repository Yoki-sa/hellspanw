--[[
	Hellspawn — full showcase with working features

	Every visual in here is drawn to match the menu: same fonts, the theme's
	colours (switch the theme and the ESP, crosshair and HUD follow), native
	UIShadow neon, thorn sprites and the sigil iconography.

	  Combat    aimbot (camera / mouse), triggerbot, FOV crown, crosshair, target HUD
	  Visuals   ESP (corner/full boxes, names, distance, health, skeleton, tracers,
	            off-screen thorn arrows), chams, world lighting + "Hellspawn grade"
	  Movement  walk speed, jump power, infinite jump, noclip, flight
	  Misc      spectate, teleport, anti-AFK, rejoin, notifications

	Everything is restored when you press Unload in the settings tab.
]]

local Hellspawn = loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_NAME/Hellspawn/main/dist/Hellspawn.lua"))()

----------------------------------------------------------------------
-- environment
----------------------------------------------------------------------

local clone = cloneref or function(object)
	return object
end
local function service(name)
	return clone(game:GetService(name))
end

local Players = service("Players")
local RunService = service("RunService")
local UserInputService = service("UserInputService")
local Lighting = service("Lighting")
local TeleportService = service("TeleportService")
local Workspace = service("Workspace")

local LocalPlayer = Players.LocalPlayer
local Flags, Toggles, Options = Hellspawn.Flags, Hellspawn.Toggles, Hellspawn.Options
local Theme, Assets = Hellspawn.Theme, Hellspawn.Assets

-- executor input (UNC); features that need them explain themselves if missing
local clickMouse = mouse1click
	or (mouse1press and mouse1release and function()
		mouse1press()
		task.wait(0.03)
		mouse1release()
	end)
local moveMouse = mousemoverel

local connections = {}
local function bind(signal, fn)
	local connection = signal:Connect(fn)
	table.insert(connections, connection)
	return connection
end

local function camera()
	return Workspace.CurrentCamera
end

local rgb = Color3.fromRGB

----------------------------------------------------------------------
-- window + controls
----------------------------------------------------------------------

local Window = Hellspawn:CreateWindow({
	Title = "Hellspawn",
	Subtitle = "// narcissist build · " .. os.date("%d.%m.%y"),
	Theme = "Hellspawn",
	ToggleKey = Enum.KeyCode.RightShift,
	Width = 760,
	Height = 540,
})

local Combat = Window:AddTab({ Name = "Combat", Icon = "crosshair", Description = "// aim assistance & triggers" })
local Visuals = Window:AddTab({ Name = "Visuals", Icon = "eye", Description = "// see what hides behind the walls" })
local Movement = Window:AddTab({ Name = "Movement", Icon = "bolt", Description = "// bend the rules of the body" })
local Misc = Window:AddTab({ Name = "Misc", Icon = "spider", Description = "// odds, ends and other horrors" })

-- Combat ---------------------------------------------------------------

local Aim = Combat:AddLeftGroupbox("Aimbot")
Aim:AddToggle("aim_enabled", { Text = "Enabled", Tooltip = "Hold the key to lock onto the closest target inside the FOV." })
	:AddKeybind("aim_key", { Default = "MB2", Mode = "Hold", Text = "Aimbot" })
Aim:AddDropdown("aim_part", { Text = "Hitbox", Values = { "Head", "Torso", "HumanoidRootPart" }, Default = "Head" })
Aim:AddDropdown("aim_method", {
	Text = "Method",
	Values = { "Camera", "Mouse" },
	Default = "Camera",
	Tooltip = "Mouse moves the real cursor (mousemoverel) for games that lock the camera.",
})
Aim:AddSlider("aim_fov", { Text = "FOV radius", Min = 20, Max = 500, Default = 140, Suffix = "px" })
Aim:AddSlider("aim_smooth", { Text = "Smoothing", Min = 0, Max = 0.95, Increment = 0.01, Default = 0.45 })
Aim:AddSlider("aim_prediction", { Text = "Prediction", Min = 0, Max = 0.3, Increment = 0.005, Default = 0, Suffix = "s" })
Aim:AddDropdown("aim_checks", {
	Text = "Checks",
	Values = { "Team", "Wall", "Alive", "Forcefield" },
	Multi = true,
	Default = { "Team", "Alive", "Forcefield" },
})
Aim:AddToggle("aim_sticky", { Text = "Sticky target", Tooltip = "Keep the same target until it dies or leaves the FOV." })

local Trigger = Combat:AddRightGroupbox("Triggerbot", { Icon = "skull" })
Trigger:AddToggle("trigger", { Text = "Enabled", Risky = true })
	:AddKeybind("trigger_key", { Default = Enum.KeyCode.T, Text = "Triggerbot" })
Trigger:AddSlider("trigger_delay", { Text = "Reaction", Min = 0, Max = 400, Default = 60, Suffix = "ms" })
Trigger:AddSlider("trigger_rate", { Text = "Cooldown", Min = 50, Max = 1000, Default = 140, Suffix = "ms" })
Trigger:AddLabel("<font color=\"#8d8a92\">fires when the crosshair rests on a valid target; uses the aimbot's checks</font>")

local Overlay = Combat:AddRightTabbox()
local FovPage = Overlay:AddTab("FOV")
FovPage:AddToggle("fov_show", { Text = "Draw FOV", Default = true })
	:AddColorPicker("fov_color", { Default = rgb(226, 22, 60), Transparency = 0.92 })
FovPage:AddToggle("fov_thorns", { Text = "Crown of thorns", Default = true, Tooltip = "Thorns orbit the FOV circle." })
FovPage:AddSlider("fov_spin", { Text = "Spin", Min = 0, Max = 3, Increment = 0.1, Default = 0.4, Compact = true })
local CrossPage = Overlay:AddTab("Crosshair")
CrossPage:AddToggle("cross_show", { Text = "Crosshair" }):AddColorPicker("cross_color", { Default = rgb(236, 231, 222) })
CrossPage:AddDropdown("cross_style", { Text = "Style", Values = { "sigil", "crosshair", "cross", "thorns", "eye" }, Default = "sigil" })
CrossPage:AddSlider("cross_size", { Text = "Size", Min = 8, Max = 64, Default = 22, Suffix = "px", Compact = true })
CrossPage:AddSlider("cross_spin", { Text = "Spin", Min = 0, Max = 3, Increment = 0.1, Default = 0, Compact = true })
local HudPage = Overlay:AddTab("HUD")
HudPage:AddToggle("hud_show", { Text = "Target HUD", Default = true, Tooltip = "Card under the crosshair with the current target." })
HudPage:AddSlider("hud_offset", { Text = "Offset", Min = 60, Max = 400, Default = 170, Suffix = "px", Compact = true })

-- Visuals --------------------------------------------------------------

local EspBox = Visuals:AddLeftGroupbox("Players", { Icon = "user" })
EspBox:AddToggle("esp_enabled", { Text = "Enabled", Default = true }):AddKeybind("esp_key", { Text = "ESP" })
EspBox:AddDropdown("esp_style", {
	Text = "Style",
	Values = { "Graveyard", "Neon" },
	Default = "Graveyard",
	Tooltip = "Graveyard: pixel-art bones, thorned vines and roses. Neon: the menu's own glow.",
})
local GraveStyle = EspBox:AddDependencyBox()
GraveStyle:AddToggle("esp_tint", { Text = "Tint pixel art", Tooltip = "Blend the bones and vines toward the theme accent." })
GraveStyle:SetupDependencies({ { Options.esp_style, "Graveyard" } })
local NeonStyle = EspBox:AddDependencyBox()
NeonStyle:AddToggle("esp_theme", {
	Text = "Follow theme colours",
	Default = true,
	Tooltip = "Draw everything in the menu's palette. Turn off to use the pickers.",
})
NeonStyle:SetupDependencies({ { Options.esp_style, "Neon" } })
EspBox:AddToggle("esp_box", { Text = "Boxes", Default = true })
	:AddColorPicker("esp_box_color", { Default = rgb(226, 22, 60) })
local BoxStyle = EspBox:AddDependencyBox()
BoxStyle:AddDropdown("esp_box_style", { Text = "Box style", Values = { "Corner", "Full" }, Default = "Corner" })
BoxStyle:SetupDependencies({ { Toggles.esp_box, true }, { Options.esp_style, "Neon" } })
EspBox:AddToggle("esp_name", { Text = "Names", Default = true })
	:AddColorPicker("esp_name_color", { Default = rgb(236, 231, 222) })
EspBox:AddToggle("esp_distance", { Text = "Distance", Default = true })
EspBox:AddToggle("esp_health", { Text = "Health bar", Default = true })
EspBox:AddToggle("esp_skeleton", { Text = "Skeleton", Default = true })
	:AddColorPicker("esp_skeleton_color", { Default = rgb(236, 231, 222) })
EspBox:AddToggle("esp_tracer", { Text = "Tracers" })
	:AddColorPicker("esp_tracer_color", { Default = rgb(226, 22, 60) })
local TracerStyle = EspBox:AddDependencyBox()
TracerStyle:AddDropdown("esp_tracer_origin", { Text = "Tracer origin", Values = { "Bottom", "Center", "Mouse" }, Default = "Bottom" })
TracerStyle:SetupDependencies({ { Toggles.esp_tracer, true } })
EspBox:AddToggle("esp_arrows", { Text = "Off-screen thorns", Default = true, Tooltip = "Thorns around the screen point at players you can't see." })
EspBox:AddToggle("esp_skip_team", { Text = "Skip teammates", Default = true })
EspBox:AddToggle("esp_team_color", { Text = "Use team colours" })
EspBox:AddSlider("esp_max_distance", { Text = "Max distance", Min = 50, Max = 5000, Default = 2500, Suffix = " studs" })

local ChamsBox = Visuals:AddRightGroupbox("Chams", { Icon = "drop" })
ChamsBox:AddToggle("chams", { Text = "Enabled" })
ChamsBox:AddLabel("Fill"):AddColorPicker("chams_fill", { Default = rgb(226, 22, 60), Transparency = 0.6 })
ChamsBox:AddLabel("Outline"):AddColorPicker("chams_outline", { Default = rgb(255, 255, 255), Transparency = 0 })
ChamsBox:AddDropdown("chams_depth", { Text = "Depth", Values = { "Through walls", "Visible only" }, Default = "Through walls" })
ChamsBox:AddParagraph({ Title = "note", Content = "Roblox renders at most <b>31</b> highlights at once." })

local WorldBox = Visuals:AddRightGroupbox("World", { Icon = "moon" })
WorldBox:AddToggle("fullbright", { Text = "Fullbright" })
WorldBox:AddToggle("no_fog", { Text = "Remove fog" })
WorldBox:AddToggle("time_override", { Text = "Override time" })
local TimeBox = WorldBox:AddDependencyBox()
TimeBox:AddSlider("clock_time", { Text = "Clock", Min = 0, Max = 24, Default = 0, Increment = 0.25, Suffix = "h", Compact = true })
TimeBox:SetupDependencies({ { Toggles.time_override, true } })
WorldBox:AddToggle("ambient_override", { Text = "Ambient tint" })
	:AddColorPicker("ambient_color", { Default = rgb(70, 8, 18) })
WorldBox:AddToggle("grade", { Text = "Hellspawn grade", Tooltip = "Colour-grades the world toward the menu's accent." })
local GradeBox = WorldBox:AddDependencyBox()
GradeBox:AddSlider("grade_strength", { Text = "Strength", Min = 0, Max = 100, Default = 45, Suffix = "%", Compact = true })
GradeBox:SetupDependencies({ { Toggles.grade, true } })

-- Movement -------------------------------------------------------------

local Body = Movement:AddLeftGroupbox("Body")
Body:AddToggle("speed", { Text = "Walk speed" }):AddKeybind("speed_key", { Text = "Speed" })
Body:AddSlider("speed_value", { Text = "Speed", Min = 16, Max = 200, Default = 32, Compact = true })
Body:AddToggle("jump", { Text = "Jump power" })
Body:AddSlider("jump_value", { Text = "Power", Min = 50, Max = 300, Default = 80, Compact = true })
Body:AddToggle("infinite_jump", { Text = "Infinite jump" })
Body:AddToggle("noclip", { Text = "Noclip", Risky = true }):AddKeybind("noclip_key", { Default = Enum.KeyCode.N, Text = "Noclip" })

local Flight = Movement:AddRightGroupbox("Flight", { Icon = "flame" })
Flight:AddToggle("fly", { Text = "Fly" }):AddKeybind("fly_key", { Default = Enum.KeyCode.F, Text = "Fly" })
Flight:AddSlider("fly_speed", { Text = "Speed", Min = 5, Max = 250, Default = 60, Compact = true })
Flight:AddDropdown("fly_mode", { Text = "Mode", Values = { "Velocity", "CFrame" }, Default = "Velocity" })
Flight:AddLabel("<font color=\"#8d8a92\">WASD to move · Space up · Ctrl down</font>")

-- Misc -----------------------------------------------------------------

local People = Misc:AddLeftGroupbox("Players")
People:AddDropdown("target_player", { Text = "Target", SpecialType = "Player", ExcludeLocalPlayer = true, AllowNull = true, Placeholder = "nobody" })
People:AddToggle("spectate", { Text = "Spectate target" })
local peopleButtons = People:AddButton({ Text = "Teleport", DoubleClick = true, Risky = true })
local copyName = peopleButtons:AddButton({ Text = "Copy name" })
local targetStatus = People:AddLabel("")

local Server = Misc:AddRightGroupbox("Server", { Icon = "globe" })
Server:AddToggle("anti_afk", { Text = "Anti-AFK", Default = true, Tooltip = "Stops the idle kick after 20 minutes." })
local rejoinButton = Server:AddButton({ Text = "Rejoin", DoubleClick = true })
local jobButton = rejoinButton:AddButton({ Text = "Copy job id" })
local serverStatus = Server:AddLabel("")

local Whispers = Misc:AddRightGroupbox("Notifications", { Icon = "info" })
Whispers:AddButton({
	Text = "Info",
	Callback = function()
		Hellspawn:Notify({ Title = "Whisper", Content = "Something moved in the dark.", Type = "info" })
	end,
}):AddButton({
	Text = "Success",
	Callback = function()
		Hellspawn:Notify({ Title = "Bound", Content = "The ritual is complete.", Type = "success" })
	end,
})
Whispers:AddButton({
	Text = "Warning",
	Callback = function()
		Hellspawn:Notify({ Title = "Careful", Content = "It knows your name now.", Type = "warning" })
	end,
}):AddButton({
	Text = "Error",
	Callback = function()
		Hellspawn:Notify({ Title = "Severed", Content = "The thread snapped.", Type = "danger", Duration = 6 })
	end,
})

local Sigil = Misc:AddLeftGroupbox("Sigil", { Icon = "eye" })
Sigil:AddImage({ Image = "logoLarge", Height = 110, Color = "Text", Caption = "it sees you too" })

----------------------------------------------------------------------
-- shared helpers
----------------------------------------------------------------------

local function getCharacter(player)
	local character = player and player.Character
	if not character then
		return nil
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root) then
		return nil
	end
	return character, humanoid, root
end

local function isTeammate(player)
	if player.Neutral or LocalPlayer.Neutral then
		return false
	end
	return player.Team ~= nil and player.Team == LocalPlayer.Team
end

-- viewport space: matches GetMouseLocation and our IgnoreGuiInset layer
local function toScreen(position)
	local point = camera():WorldToViewportPoint(position)
	return Vector2.new(point.X, point.Y), point.Z > 0, point.Z
end

local function aimOrigin()
	if UserInputService.MouseBehavior == Enum.MouseBehavior.LockCenter then
		return camera().ViewportSize / 2
	end
	return UserInputService:GetMouseLocation()
end

local function hitPart(character)
	local name = Flags.aim_part
	if name == "Torso" then
		return character:FindFirstChild("UpperTorso") or character:FindFirstChild("Torso")
	end
	return character:FindFirstChild(name) or character:FindFirstChild("HumanoidRootPart")
end

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

local function lineOfSight(part, character)
	local origin = camera().CFrame.Position
	local filter = { character }
	if LocalPlayer.Character then
		table.insert(filter, LocalPlayer.Character)
	end
	rayParams.FilterDescendantsInstances = filter
	return Workspace:Raycast(origin, part.Position - origin, rayParams) == nil
end

-- returns the aim part if `player` passes the aimbot's checks
local function validTarget(player, skipWall)
	local character, humanoid = getCharacter(player)
	if not character or player == LocalPlayer then
		return nil
	end
	local checks = Options.aim_checks.Value
	if checks.Alive and humanoid.Health <= 0 then
		return nil
	end
	if checks.Team and isTeammate(player) then
		return nil
	end
	if checks.Forcefield and character:FindFirstChildOfClass("ForceField") then
		return nil
	end
	local part = hitPart(character)
	if not part then
		return nil
	end
	if checks.Wall and not skipWall and not lineOfSight(part, character) then
		return nil
	end
	return part
end

-- every colour comes from the theme unless the user opted out
local function themed(pickerFlag, themeKey)
	if Toggles.esp_theme.Value or not Options[pickerFlag] then
		return Theme:Get(themeKey)
	end
	return Options[pickerFlag].Value
end

----------------------------------------------------------------------
-- drawing kit: GUI primitives styled like the menu
----------------------------------------------------------------------

local layer = Hellspawn:CreateLayer(9000) -- under the menu (9990+)
local fontBold = Assets:Font("Body", Enum.FontWeight.Bold)
local fontBody = Assets:Font("Body", Enum.FontWeight.Medium)

local function make(className, props)
	local instance = Instance.new(className)
	for key, value in props do
		if key ~= "Parent" then
			instance[key] = value
		end
	end
	if className ~= "UIStroke" and className ~= "UICorner" and className ~= "UIGradient" and className ~= "UIShadow" then
		pcall(function()
			instance.Active = false
			instance.Interactable = false
		end)
	end
	instance.Parent = props.Parent
	return instance
end

local function stroke(parent, thickness, color, transparency)
	return make("UIStroke", {
		Thickness = thickness,
		Color = color or Color3.new(0, 0, 0),
		Transparency = transparency or 0,
		ApplyStrokeMode = Enum.ApplyStrokeMode.Border,
		Parent = parent,
	})
end

-- small native neon (UIShadow) under a *solid* primitive
local function neon(parent, blur, transparency)
	local ok, shadow = pcall(Instance.new, "UIShadow")
	if not ok or not shadow then
		return nil
	end
	shadow.BlurRadius = UDim.new(0, blur)
	shadow.Spread = UDim2.fromOffset(2, 2)
	shadow.Transparency = transparency
	shadow.Parent = parent
	return shadow
end

local function line(parent, thickness)
	local frame = make("Frame", {
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(0, thickness),
		Visible = false,
		Parent = parent,
	})
	return frame
end

local function placeLine(frame, a, b, thickness)
	local delta = b - a
	frame.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
	frame.Size = UDim2.fromOffset(delta.Magnitude, thickness)
	frame.Rotation = math.deg(math.atan2(delta.Y, delta.X))
	frame.Visible = true
end

local function paintNeon(frame, glow, color, glowAlpha)
	frame.BackgroundColor3 = color
	if glow then
		glow.Color = color
		glow.Transparency = 1 - glowAlpha * ((Hellspawn.Settings.Glow and Hellspawn.Settings.GlowIntensity) or 0)
	end
end

----------------------------------------------------------------------
-- graveyard kit: the library's pixel-art sprite pack, drawn Pixelated
----------------------------------------------------------------------

local fontPixel = Font.fromEnum(Enum.Font.Arcade)
local BONE_INK = rgb(246, 238, 220)
local BONE_SHADE = rgb(168, 151, 122)
local BLOOD = rgb(255, 46, 66)

local function sprite(name, parent, zindex, anchor)
	return make("ImageLabel", {
		BackgroundTransparency = 1,
		Image = Assets:Texture(name),
		ResampleMode = Enum.ResamplerMode.Pixelated,
		AnchorPoint = anchor or Vector2.new(0.5, 0.5),
		Visible = false,
		ZIndex = zindex or 1,
		Parent = parent,
	})
end

local function tiled(name, parent, zindex, anchor)
	local image = sprite(name, parent, zindex, anchor or Vector2.zero)
	image.ScaleType = Enum.ScaleType.Tile
	return image
end

-- a horizontal sprite stretched from a to b
local function placeAlong(image, a, b, thickness, overshoot)
	local delta = b - a
	image.Position = UDim2.fromOffset((a.X + b.X) / 2, (a.Y + b.Y) / 2)
	image.Size = UDim2.fromOffset(delta.Magnitude * (overshoot or 1), thickness)
	image.Rotation = math.deg(math.atan2(delta.Y, delta.X))
	image.Visible = true
end

-- an upright sprite whose vertical axis runs from `top` to `bottom`
local function placeUpright(image, top, bottom, width, stretch)
	local delta = bottom - top
	image.Position = UDim2.fromOffset((top.X + bottom.X) / 2, (top.Y + bottom.Y) / 2)
	image.Size = UDim2.fromOffset(width, delta.Magnitude * (stretch or 1))
	image.Rotation = math.deg(math.atan2(delta.Y, delta.X)) - 90
	image.Visible = true
end

-- screen axis of a part between two offsets (studs) along its up vector,
-- plus its projected width; `ok` is false if either end is behind us
local function partAxis(part, upper, lower)
	local cf, size = part.CFrame, part.Size
	local top, a = toScreen(cf.Position + cf.UpVector * upper)
	local bottom, b = toScreen(cf.Position + cf.UpVector * lower)
	local left = toScreen(cf.Position - cf.RightVector * (size.X / 2))
	local right = toScreen(cf.Position + cf.RightVector * (size.X / 2))
	return top, bottom, (right - left).Magnitude, a and b
end

local function rotate2(v, degrees)
	local r = math.rad(degrees)
	local c, s = math.cos(r), math.sin(r)
	return Vector2.new(v.X * c - v.Y * s, v.X * s + v.Y * c)
end

local function easeOut(t)
	return 1 - (1 - math.clamp(t, 0, 1)) ^ 3
end

----------------------------------------------------------------------
-- ESP
----------------------------------------------------------------------

local NEON_BONES_R15 = {
	{ "Head", "UpperTorso" }, { "UpperTorso", "LowerTorso" },
	{ "UpperTorso", "LeftUpperArm" }, { "LeftUpperArm", "LeftLowerArm" }, { "LeftLowerArm", "LeftHand" },
	{ "UpperTorso", "RightUpperArm" }, { "RightUpperArm", "RightLowerArm" }, { "RightLowerArm", "RightHand" },
	{ "LowerTorso", "LeftUpperLeg" }, { "LeftUpperLeg", "LeftLowerLeg" }, { "LeftLowerLeg", "LeftFoot" },
	{ "LowerTorso", "RightUpperLeg" }, { "RightUpperLeg", "RightLowerLeg" }, { "RightLowerLeg", "RightFoot" },
}
local NEON_BONES_R6 = {
	{ "Head", "Torso" }, { "Torso", "Left Arm" }, { "Torso", "Right Arm" }, { "Torso", "Left Leg" }, { "Torso", "Right Leg" },
}
local LIMBS_R15 = {
	"LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm",
	"LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg",
}
local LIMBS_R6 = { "Left Arm", "Right Arm", "Left Leg", "Right Leg" }
local ROSE_TILT = { -14, 10, -8, 13 }
-- eye sockets of the 16x16 skull sprite, relative to its centre
local SKULL_EYES = { Vector2.new(-3.5, -1) / 16, Vector2.new(3.5, -1) / 16 }

local chamsFolder = Instance.new("Folder")
chamsFolder.Name = "\0"
chamsFolder.Parent = Hellspawn.Env.guiParent(chamsFolder)

local Esp = {}
Esp.__index = Esp
local esps = {}
local lockedTarget = nil -- the aimbot's current target (marked by its ESP)

function Esp.new(player)
	local self = setmetatable({ Player = player, Grown = 0, Hidden = 0 }, Esp)
	self.Root = make("Frame", {
		Name = player.Name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = layer,
	})
	self:_buildNeon()
	self:_buildGrave()
	return self
end

-- neon style: the menu's own look ----------------------------------------

function Esp:_buildNeon()
	local root = self.Root
	local n = { Bones = {} }
	self.Neon = n

	n.Box = make("Frame", { BackgroundTransparency = 1, Visible = false, Parent = root })
	n.BoxStroke = stroke(n.Box, 1, Color3.new(1, 1, 1))
	local keyline = make("Frame", {
		BackgroundTransparency = 1,
		Position = UDim2.fromOffset(-1, -1),
		Size = UDim2.new(1, 2, 1, 2),
		Parent = n.Box,
	})
	stroke(keyline, 1, Color3.new(0, 0, 0), 0.35)
	if Assets:Has("glow") then
		local meta = Assets:Meta("glow")
		n.BoxGlow = make("ImageLabel", {
			BackgroundTransparency = 1,
			Image = Assets:Texture("glow"),
			ScaleType = Enum.ScaleType.Slice,
			SliceCenter = Rect.new(meta.Pad, meta.Pad, meta.Size - meta.Pad, meta.Size - meta.Pad),
			SliceScale = 10 / meta.Pad,
			Position = UDim2.fromOffset(-10, -10),
			Size = UDim2.new(1, 20, 1, 20),
			Parent = n.Box,
		})
	end

	n.Corners = {}
	for i = 1, 8 do
		local arm = make("Frame", { BorderSizePixel = 0, Visible = false, Parent = root })
		stroke(arm, 1, Color3.new(0, 0, 0), 0.45)
		n.Corners[i] = { Frame = arm, Glow = neon(arm, 6, 0.5) }
	end

	n.Tag = make("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(220, 16),
		Visible = false,
		Parent = root,
	})
	n.Name = make("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = fontBold,
		TextSize = 13,
		TextStrokeTransparency = 0.35,
		Size = UDim2.fromScale(1, 1),
		Parent = n.Tag,
	})
	n.Sigil = make("ImageLabel", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.fromOffset(9, 9),
		Parent = n.Tag,
	})
	Assets:ApplyIcon(n.Sigil, "sigil")

	n.Distance = make("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = fontBody,
		TextSize = 11,
		TextStrokeTransparency = 0.45,
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(120, 14),
		Visible = false,
		Parent = root,
	})

	n.Health = make("Frame", {
		BackgroundColor3 = Color3.new(0, 0, 0),
		BackgroundTransparency = 0.35,
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(1, 0),
		Visible = false,
		Parent = root,
	})
	n.HealthFill = make("Frame", {
		BorderSizePixel = 0,
		AnchorPoint = Vector2.new(0, 1),
		Position = UDim2.fromScale(0, 1),
		Size = UDim2.fromScale(1, 1),
		Parent = n.Health,
	})
	n.HealthGlow = neon(n.HealthFill, 5, 0.6)
	n.HealthText = make("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = fontBody,
		TextSize = 10,
		TextStrokeTransparency = 0.4,
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.fromOffset(30, 12),
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = false,
		Parent = root,
	})

	n.Tracer = line(root, 1.5)
	n.TracerGlow = neon(n.Tracer, 6, 0.55)

	n.Arrow = make("ImageLabel", {
		BackgroundTransparency = 1,
		Image = Assets:Texture("spike"),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(9, 26),
		Visible = false,
		Parent = root,
	})
	n.ArrowBloom = make("ImageLabel", {
		BackgroundTransparency = 1,
		Image = Assets:Texture("bloom"),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = UDim2.fromOffset(34, 34),
		ImageTransparency = 0.7,
		Parent = n.Arrow,
	})
end

function Esp:_hideNeon()
	local n = self.Neon
	n.Box.Visible = false
	for _, corner in n.Corners do
		corner.Frame.Visible = false
	end
	n.Tag.Visible = false
	n.Distance.Visible = false
	n.Health.Visible = false
	n.HealthText.Visible = false
	n.Tracer.Visible = false
	n.Arrow.Visible = false
	for _, bone in n.Bones do
		bone.Visible = false
	end
end

-- graveyard style: pixel bones, thorned vines, blood roses ----------------

function Esp:_buildGrave()
	local root = self.Root
	local g = { Bones = {} }
	self.Grave = g

	-- vines crawl clockwise from the top-left corner
	g.Vines = {
		tiled("px_vine_h", root, 1, Vector2.new(0, 0.5)), -- top, grows right
		tiled("px_vine_v", root, 1, Vector2.new(0.5, 0)), -- right, grows down
		tiled("px_vine_h", root, 1, Vector2.new(1, 0.5)), -- bottom, grows left
		tiled("px_vine_v", root, 1, Vector2.new(0.5, 1)), -- left, grows up
	}
	g.Roses = {}
	for i = 1, 4 do
		g.Roses[i] = sprite("px_rose", root, 2)
	end

	g.Skull = sprite("px_skull", root, 4)
	g.Ribs = sprite("px_ribs", root, 3)
	g.Pelvis = sprite("px_pelvis", root, 3)
	g.Eyes = {}
	for i = 1, 2 do
		local eye = make("Frame", {
			BorderSizePixel = 0,
			BackgroundColor3 = BLOOD,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(3, 3),
			Visible = false,
			ZIndex = 5,
			Parent = root,
		})
		local glow = neon(eye, 8, 0.15)
		if glow then
			glow.Color = BLOOD
		end
		g.Eyes[i] = eye
	end

	-- spine health bar: dim vertebrae behind, living ones clipped on top
	g.Spine = tiled("px_vertebra", root, 2)
	g.Spine.ImageTransparency = 0.55
	g.Spine.ImageColor3 = rgb(90, 84, 76)
	g.SpineClip = make("Frame", {
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		AnchorPoint = Vector2.new(0, 1),
		Visible = false,
		ZIndex = 3,
		Parent = root,
	})
	g.SpineFill = tiled("px_vertebra", g.SpineClip, 3, Vector2.new(0, 1))
	g.SpineFill.Position = UDim2.fromScale(0, 1)
	g.SpineFill.Visible = true
	g.SpineText = make("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = fontPixel,
		TextSize = 12,
		TextStrokeTransparency = 0.2,
		AnchorPoint = Vector2.new(1, 0.5),
		Size = UDim2.fromOffset(34, 12),
		TextXAlignment = Enum.TextXAlignment.Right,
		Visible = false,
		ZIndex = 4,
		Parent = root,
	})

	g.Tag = make("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(240, 18),
		Visible = false,
		ZIndex = 4,
		Parent = root,
	})
	g.Name = make("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = fontPixel,
		TextSize = 16,
		TextColor3 = BONE_INK,
		TextStrokeTransparency = 0,
		TextStrokeColor3 = rgb(26, 18, 14),
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
		Parent = g.Tag,
	})
	g.TagSkull = sprite("px_skull", g.Tag, 4, Vector2.new(1, 0.5))
	g.TagSkull.Size = UDim2.fromOffset(16, 16)
	g.TagSkull.Visible = true

	g.Distance = make("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = fontPixel,
		TextSize = 12,
		TextColor3 = BONE_SHADE,
		TextStrokeTransparency = 0.1,
		TextStrokeColor3 = rgb(26, 18, 14),
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(120, 14),
		Visible = false,
		ZIndex = 4,
		Parent = root,
	})

	g.Tracer = tiled("px_vine_h", root, 1, Vector2.new(0.5, 0.5))
	g.Thorn = sprite("px_thorn", root, 3)
	g.Thorn.Size = UDim2.fromOffset(22, 44)
	g.ThornBloom = make("ImageLabel", {
		BackgroundTransparency = 1,
		Image = Assets:Texture("bloom"),
		ImageColor3 = BLOOD,
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.75),
		Size = UDim2.fromOffset(46, 46),
		ImageTransparency = 0.7,
		ZIndex = 2,
		Parent = g.Thorn,
	})
end

function Esp:_hideBones()
	local g = self.Grave
	for _, bone in g.Bones do
		bone.Visible = false
	end
	g.Skull.Visible = false
	g.Ribs.Visible = false
	g.Pelvis.Visible = false
	for _, eye in g.Eyes do
		eye.Visible = false
	end
end

function Esp:_hideGrave()
	local g = self.Grave
	for _, vine in g.Vines do
		vine.Visible = false
	end
	for _, rose in g.Roses do
		rose.Visible = false
	end
	self:_hideBones()
	g.Spine.Visible = false
	g.SpineClip.Visible = false
	g.SpineText.Visible = false
	g.Tag.Visible = false
	g.Distance.Visible = false
	g.Tracer.Visible = false
	g.Thorn.Visible = false
end

-- shared ----------------------------------------------------------------

function Esp:_chams(character, show)
	if not show then
		if self.Highlight then
			self.Highlight.Enabled = false
		end
		return
	end
	local highlight = self.Highlight
	if not highlight then
		highlight = Instance.new("Highlight")
		highlight.Parent = chamsFolder
		self.Highlight = highlight
	end
	highlight.Adornee = character
	highlight.Enabled = true
	highlight.FillColor = themed("chams_fill", "Accent")
	highlight.FillTransparency = Options.chams_fill.Transparency
	highlight.OutlineColor = themed("chams_outline", "Text")
	highlight.OutlineTransparency = Options.chams_outline.Transparency
	highlight.DepthMode = Flags.chams_depth == "Visible only" and Enum.HighlightDepthMode.Occluded or Enum.HighlightDepthMode.AlwaysOnTop
end

function Esp:_hideAll()
	self:_hideNeon()
	self:_hideGrave()
end

-- points from the screen centre toward a player we can't see
local function offscreenPlacement(rootPart)
	local cam = camera()
	local relative = cam.CFrame:PointToObjectSpace(rootPart.Position)
	local direction = Vector2.new(relative.X, -relative.Y)
	if direction.Magnitude <= 0 then
		return nil
	end
	direction = direction.Unit
	local viewport = cam.ViewportSize
	local radius = math.min(viewport.X, viewport.Y) * 0.36
	return viewport / 2 + direction * radius, math.deg(math.atan2(direction.Y, direction.X)) + 90
end

function Esp:Update(now, dt)
	local player = self.Player
	local character, humanoid, rootPart = getCharacter(player)
	local usable = character ~= nil
		and humanoid.Health > 0
		and not (Toggles.esp_skip_team.Value and isTeammate(player))

	self:_chams(character, usable and Toggles.chams.Value)
	if not (Toggles.esp_enabled.Value and usable) then
		self:_hideAll()
		self.Grown = 0
		return
	end

	local cam = camera()
	local distance = (rootPart.Position - cam.CFrame.Position).Magnitude
	if distance > Flags.esp_max_distance then
		self:_hideAll()
		self.Grown = 0
		return
	end

	-- 2D box from the head top to the feet, stable on any rig
	local head = character:FindFirstChild("Head")
	local topWorld = head and (head.Position + Vector3.new(0, head.Size.Y * 0.6, 0)) or (rootPart.Position + Vector3.new(0, 2.6, 0))
	local legs = humanoid.RigType == Enum.HumanoidRigType.R6 and 2 or humanoid.HipHeight
	local bottomWorld = rootPart.Position - Vector3.new(0, rootPart.Size.Y / 2 + legs + 0.1, 0)
	local top, topVisible = toScreen(topWorld)
	local bottom, bottomVisible = toScreen(bottomWorld)
	local viewport = cam.ViewportSize
	local height = bottom.Y - top.Y

	local frame = {
		Character = character,
		Humanoid = humanoid,
		RootPart = rootPart,
		Head = head,
		Distance = distance,
		Locked = lockedTarget == player,
		OnScreen = topVisible
			and bottomVisible
			and height > 2
			and top.X > -50 and top.X < viewport.X + 50
			and bottom.Y > -50 and top.Y < viewport.Y + 50,
		Top = top.Y,
		Bottom = bottom.Y,
		Height = height,
		Width = height * 0.58,
		CenterX = (top.X + bottom.X) / 2,
		Viewport = viewport,
		Now = now,
	}
	frame.Left = frame.CenterX - frame.Width / 2
	frame.Right = frame.CenterX + frame.Width / 2

	if frame.OnScreen then
		self.Grown = math.min(1, self.Grown + dt * 1.8)
	else
		self.Grown = 0
	end

	if Flags.esp_style == "Neon" then
		self:_hideGrave()
		self:_drawNeon(frame)
	else
		self:_hideNeon()
		self:_drawGrave(frame)
	end
end

function Esp:_drawNeon(f)
	local n = self.Neon
	local player = self.Player
	local accent = themed("esp_box_color", "Accent")
	if Toggles.esp_team_color.Value and player.Team then
		accent = player.TeamColor.Color
	end
	if f.Locked then
		accent = Theme:Get("Text") -- the locked target turns bone white
	end

	if not f.OnScreen then
		self:_hideNeon()
		if Toggles.esp_arrows.Value then
			local at, rotation = offscreenPlacement(f.RootPart)
			if at then
				local pulse = 0.5 + 0.5 * math.sin(f.Now * 4 + #player.Name)
				n.Arrow.Position = UDim2.fromOffset(at.X, at.Y)
				n.Arrow.Rotation = rotation
				n.Arrow.ImageColor3 = accent
				n.ArrowBloom.ImageColor3 = accent
				n.Arrow.ImageTransparency = math.clamp(f.Distance / Flags.esp_max_distance, 0, 0.6)
				n.ArrowBloom.ImageTransparency = 0.6 + 0.25 * pulse
				n.Arrow.Visible = true
			end
		end
		return
	end
	n.Arrow.Visible = false

	local left, right, top, bottom = f.Left, f.Right, f.Top, f.Bottom
	local width, height = f.Width, f.Height
	local glowAlpha = f.Locked and 0.9 or 0.55

	local showBox = Toggles.esp_box.Value
	local corner = Flags.esp_box_style == "Corner"
	n.Box.Visible = showBox and not corner
	if n.Box.Visible then
		n.Box.Position = UDim2.fromOffset(left, top)
		n.Box.Size = UDim2.fromOffset(width, height)
		n.BoxStroke.Color = accent
		if n.BoxGlow then
			n.BoxGlow.ImageColor3 = accent
			n.BoxGlow.ImageTransparency = 1 - glowAlpha * 0.6
		end
	end
	local arm = math.clamp(math.min(width, height) * 0.24, 4, 40)
	local spec = {
		{ left, top, arm, 2 }, { left, top, 2, arm },
		{ right - arm, top, arm, 2 }, { right - 2, top, 2, arm },
		{ left, bottom - 2, arm, 2 }, { left, bottom - arm, 2, arm },
		{ right - arm, bottom - 2, arm, 2 }, { right - 2, bottom - arm, 2, arm },
	}
	for i, piece in n.Corners do
		local visible = showBox and corner
		piece.Frame.Visible = visible
		if visible then
			local s = spec[i]
			piece.Frame.Position = UDim2.fromOffset(s[1], s[2])
			piece.Frame.Size = UDim2.fromOffset(s[3], s[4])
			paintNeon(piece.Frame, piece.Glow, accent, glowAlpha)
		end
	end

	n.Tag.Visible = Toggles.esp_name.Value
	if n.Tag.Visible then
		n.Tag.Position = UDim2.fromOffset(f.CenterX, top - 3)
		n.Name.Text = player.DisplayName
		n.Name.TextColor3 = themed("esp_name_color", "Text")
		n.Sigil.ImageColor3 = accent
		n.Sigil.Position = UDim2.new(0.5, -(n.Name.TextBounds.X / 2) - 4, 0.5, 0)
	end
	n.Distance.Visible = Toggles.esp_distance.Value
	if n.Distance.Visible then
		n.Distance.Position = UDim2.fromOffset(f.CenterX, bottom + 3)
		n.Distance.Text = string.format("%dm", math.floor(f.Distance + 0.5))
		n.Distance.TextColor3 = Theme:Get("TextDim")
	end

	n.Health.Visible = Toggles.esp_health.Value
	if n.Health.Visible then
		local humanoid = f.Humanoid
		local fraction = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
		local color = Toggles.esp_theme.Value and Theme:Get("Error"):Lerp(accent, fraction)
			or Theme:Get("Error"):Lerp(Theme:Get("Success"), fraction)
		n.Health.Position = UDim2.fromOffset(left - 4, top - 1)
		n.Health.Size = UDim2.fromOffset(3, height + 2)
		n.HealthFill.Size = UDim2.fromScale(1, fraction)
		paintNeon(n.HealthFill, n.HealthGlow, color, 0.55)
		n.HealthText.Visible = fraction < 0.999
		if n.HealthText.Visible then
			n.HealthText.Position = UDim2.fromOffset(left - 7, top + height * (1 - fraction))
			n.HealthText.Text = tostring(math.floor(humanoid.Health + 0.5))
			n.HealthText.TextColor3 = color
		end
	else
		n.HealthText.Visible = false
	end

	if Toggles.esp_tracer.Value then
		local origin = Flags.esp_tracer_origin
		local viewport = f.Viewport
		local from = origin == "Mouse" and aimOrigin()
			or (origin == "Center" and viewport / 2)
			or Vector2.new(viewport.X / 2, viewport.Y - 2)
		placeLine(n.Tracer, from, Vector2.new(f.CenterX, bottom), 1.5)
		paintNeon(n.Tracer, n.TracerGlow, Toggles.esp_theme.Value and accent or Options.esp_tracer_color.Value, glowAlpha)
	else
		n.Tracer.Visible = false
	end

	local character, humanoid = f.Character, f.Humanoid
	local bones = humanoid.RigType == Enum.HumanoidRigType.R6 and NEON_BONES_R6 or NEON_BONES_R15
	local showBones = Toggles.esp_skeleton.Value and f.Distance < 600
	local boneColor = themed("esp_skeleton_color", "Text")
	for i, pair in bones do
		local bone = n.Bones[i]
		if not bone then
			bone = line(self.Root, 1)
			n.Bones[i] = bone
		end
		local a = showBones and character:FindFirstChild(pair[1])
		local b = showBones and character:FindFirstChild(pair[2])
		if a and b then
			local pa, va = toScreen(a.Position)
			local pb, vb = toScreen(b.Position)
			if va and vb then
				placeLine(bone, pa, pb, 1)
				bone.BackgroundColor3 = boneColor
				bone.BackgroundTransparency = 0.15
			else
				bone.Visible = false
			end
		else
			bone.Visible = false
		end
	end
	for i = #bones + 1, #n.Bones do
		n.Bones[i].Visible = false
	end
end

function Esp:_drawBones(f, tint)
	local g = self.Grave
	local character, humanoid = f.Character, f.Humanoid
	local used = 0
	local function bone(a, b, thickness)
		used += 1
		local image = g.Bones[used]
		if not image then
			image = sprite("px_bone", self.Root, 3)
			g.Bones[used] = image
		end
		placeAlong(image, a, b, thickness, 1.12)
		image.ImageColor3 = tint
	end
	local function upright(image, part, upper, lower, widthScale, stretch)
		local top, bottom, width, ok = partAxis(part, upper, lower)
		if ok then
			placeUpright(image, top, bottom, math.max(width * widthScale, 6), stretch)
			image.ImageColor3 = tint
		else
			image.Visible = false
		end
	end

	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		for _, name in LIMBS_R6 do
			local part = character:FindFirstChild(name)
			if part then
				-- each R6 limb gets two bones meeting at the elbow / knee
				local top, bottom, width, ok = partAxis(part, part.Size.Y * 0.47, -part.Size.Y * 0.47)
				if ok then
					local joint = (top + bottom) / 2
					local thickness = math.clamp(width * 0.8, 4, 20)
					bone(top, joint, thickness)
					bone(joint, bottom, thickness)
				end
			end
		end
		local torso = character:FindFirstChild("Torso")
		if torso then
			local h = torso.Size.Y / 2
			upright(g.Ribs, torso, h * 1.05, -h * 0.35, 1.15)
			upright(g.Pelvis, torso, -h * 0.3, -h * 1.15, 1.05)
		else
			g.Ribs.Visible = false
			g.Pelvis.Visible = false
		end
	else
		for _, name in LIMBS_R15 do
			local part = character:FindFirstChild(name)
			if part then
				local top, bottom, width, ok = partAxis(part, part.Size.Y / 2, -part.Size.Y / 2)
				if ok then
					bone(top, bottom, math.clamp(width * 0.9, 4, 18))
				end
			end
		end
		local upper = character:FindFirstChild("UpperTorso")
		local lower = character:FindFirstChild("LowerTorso")
		if upper then
			upright(g.Ribs, upper, upper.Size.Y * 0.55, -upper.Size.Y * 0.62, 1.12)
		else
			g.Ribs.Visible = false
		end
		if lower then
			local w = lower.Size.X
			upright(g.Pelvis, lower, w * 0.3, -w * 0.38, 1.1)
		else
			g.Pelvis.Visible = false
		end
	end
	for i = used + 1, #g.Bones do
		g.Bones[i].Visible = false
	end

	-- skull, and the eyes catch fire on the aimbot's target
	local head = f.Head
	local skullTop, skullBottom, skullOk
	if head then
		local size = head.Size.Y * 1.25
		local top, bottom, _, ok = partAxis(head, size / 2, -size / 2)
		skullTop, skullBottom, skullOk = top, bottom, ok
	end
	if skullOk then
		local side = (skullBottom - skullTop).Magnitude
		placeUpright(g.Skull, skullTop, skullBottom, side)
		g.Skull.ImageColor3 = tint
		local center = (skullTop + skullBottom) / 2
		for i, eye in g.Eyes do
			eye.Visible = f.Locked
			if f.Locked then
				local offset = rotate2(SKULL_EYES[i] * side, g.Skull.Rotation)
				local flicker = 0.75 + 0.25 * math.sin(f.Now * 18 + i)
				eye.Position = UDim2.fromOffset(center.X + offset.X, center.Y + offset.Y)
				eye.Size = UDim2.fromOffset(math.max(2, side * 0.12), math.max(2, side * 0.12))
				eye.BackgroundTransparency = 1 - flicker
			end
		end
	else
		g.Skull.Visible = false
		for _, eye in g.Eyes do
			eye.Visible = false
		end
	end
end

function Esp:_drawGrave(f)
	local g = self.Grave
	local player = self.Player
	local tint = Color3.new(1, 1, 1)
	if Toggles.esp_tint.Value then
		tint = tint:Lerp(Theme:Get("Accent"), 0.45)
	end

	if not f.OnScreen then
		self:_hideGrave()
		if Toggles.esp_arrows.Value then
			local at, rotation = offscreenPlacement(f.RootPart)
			if at then
				local pulse = 0.5 + 0.5 * math.sin(f.Now * 3 + #player.Name)
				g.Thorn.Position = UDim2.fromOffset(at.X, at.Y)
				g.Thorn.Rotation = rotation
				g.Thorn.ImageColor3 = tint
				g.Thorn.ImageTransparency = math.clamp(f.Distance / Flags.esp_max_distance, 0, 0.5)
				g.ThornBloom.ImageTransparency = 0.62 + 0.25 * pulse
				g.Thorn.Visible = true
			end
		end
		return
	end
	g.Thorn.Visible = false

	local left, right, top, bottom = f.Left, f.Right, f.Top, f.Bottom
	local width, height = f.Width, f.Height
	local scale = height >= 260 and 2 or 1
	local thick = 12 * scale
	local showBox = Toggles.esp_box.Value

	-- vines crawl around the box, then the roses bloom
	local reach = easeOut(self.Grown)
	local bloom = easeOut((self.Grown - 0.55) / 0.45)
	local vines = g.Vines
	local placements = {
		{ left, top, width * reach, thick, 24, 12 },
		{ right, top, thick, height * reach, 12, 24 },
		{ right, bottom, width * reach, thick, 24, 12 },
		{ left, bottom, thick, height * reach, 12, 24 },
	}
	for i, vine in vines do
		vine.Visible = showBox
		if showBox then
			local p = placements[i]
			vine.Position = UDim2.fromOffset(p[1], p[2])
			vine.Size = UDim2.fromOffset(p[3], p[4])
			vine.TileSize = UDim2.fromOffset(p[5] * scale, p[6] * scale)
			vine.ImageColor3 = f.Locked and tint:Lerp(BLOOD, 0.35) or tint
		end
	end
	local corners = { { left, top }, { right, top }, { right, bottom }, { left, bottom } }
	for i, rose in g.Roses do
		rose.Visible = showBox and bloom > 0.01
		if rose.Visible then
			local size = 16 * scale * bloom
			rose.Position = UDim2.fromOffset(corners[i][1], corners[i][2])
			rose.Size = UDim2.fromOffset(size, size)
			rose.Rotation = ROSE_TILT[i] + math.sin(f.Now * 1.3 + i) * 4
			rose.ImageColor3 = tint
		end
	end

	if Toggles.esp_skeleton.Value and f.Distance < 700 then
		self:_drawBones(f, tint)
	else
		self:_hideBones()
	end

	-- vertebrae health: bone white when healthy, soaked red when not
	local humanoid = f.Humanoid
	local fraction = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
	local showHealth = Toggles.esp_health.Value
	g.Spine.Visible = showHealth
	g.SpineClip.Visible = showHealth
	if showHealth then
		local x = left - (showBox and thick / 2 or 0) - 15
		g.Spine.Position = UDim2.fromOffset(x, top)
		g.Spine.Size = UDim2.fromOffset(12, height)
		g.Spine.TileSize = UDim2.fromOffset(12, 7)
		g.SpineClip.Position = UDim2.fromOffset(x, bottom)
		g.SpineClip.Size = UDim2.fromOffset(12, height * fraction)
		g.SpineFill.Size = UDim2.fromOffset(12, height)
		g.SpineFill.TileSize = UDim2.fromOffset(12, 7)
		g.SpineFill.ImageColor3 = BLOOD:Lerp(tint, fraction)
		g.SpineText.Visible = fraction < 0.999
		if g.SpineText.Visible then
			g.SpineText.Position = UDim2.fromOffset(x - 2, bottom - height * fraction)
			g.SpineText.Text = tostring(math.floor(humanoid.Health + 0.5))
			g.SpineText.TextColor3 = BLOOD:Lerp(BONE_INK, fraction)
		end
	else
		g.SpineText.Visible = false
	end

	g.Tag.Visible = Toggles.esp_name.Value
	if g.Tag.Visible then
		g.Tag.Position = UDim2.fromOffset(f.CenterX, top - (showBox and thick / 2 or 0) - 2)
		g.Name.Text = string.lower(player.DisplayName)
		g.TagSkull.Position = UDim2.new(0.5, -(g.Name.TextBounds.X / 2) - 4, 0.5, 0)
		g.TagSkull.ImageColor3 = f.Locked and BLOOD or tint
	end
	g.Distance.Visible = Toggles.esp_distance.Value
	if g.Distance.Visible then
		g.Distance.Position = UDim2.fromOffset(f.CenterX, bottom + (showBox and thick / 2 or 0) + 2)
		g.Distance.Text = string.format("%dm", math.floor(f.Distance + 0.5))
	end

	if Toggles.esp_tracer.Value then
		local origin = Flags.esp_tracer_origin
		local viewport = f.Viewport
		local from = origin == "Mouse" and aimOrigin()
			or (origin == "Center" and viewport / 2)
			or Vector2.new(viewport.X / 2, viewport.Y - 6)
		local to = Vector2.new(f.CenterX, bottom + (showBox and thick / 2 or 0))
		placeAlong(g.Tracer, from, to, 12)
		g.Tracer.TileSize = UDim2.fromOffset(24, 12)
		g.Tracer.ImageColor3 = tint
	else
		g.Tracer.Visible = false
	end
end

function Esp:Destroy()
	self.Root:Destroy()
	if self.Highlight then
		self.Highlight:Destroy()
	end
end

local function track(player)
	if player ~= LocalPlayer and not esps[player] then
		esps[player] = Esp.new(player)
	end
end
for _, player in Players:GetPlayers() do
	track(player)
end
bind(Players.PlayerAdded, track)
bind(Players.PlayerRemoving, function(player)
	local esp = esps[player]
	if esp then
		esp:Destroy()
		esps[player] = nil
	end
	if lockedTarget == player then
		lockedTarget = nil
	end
end)

----------------------------------------------------------------------
-- FOV crown, crosshair and target HUD
----------------------------------------------------------------------

local fov = make("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, Parent = layer })
make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = fov })
local fovStroke = stroke(fov, 1.5, Color3.new(1, 1, 1))
local fovHalo = make("Frame", {
	BackgroundTransparency = 1,
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.new(1, 6, 1, 6),
	Parent = fov,
})
make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = fovHalo })
local fovHaloStroke = stroke(fovHalo, 5, Color3.new(1, 1, 1), 0.82)
local thorns = {}
for i = 1, 8 do
	thorns[i] = make("ImageLabel", {
		BackgroundTransparency = 1,
		Image = Assets:Texture("spike"),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Size = UDim2.fromOffset(5, 15),
		Visible = false,
		Parent = layer,
	})
end

local crosshair = make("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, Parent = layer })
local crosshairBloom = make("ImageLabel", {
	BackgroundTransparency = 1,
	Image = Assets:Texture("bloom"),
	AnchorPoint = Vector2.new(0.5, 0.5),
	Position = UDim2.fromScale(0.5, 0.5),
	Size = UDim2.fromScale(2.4, 2.4),
	ImageTransparency = 0.75,
	Parent = crosshair,
})
local crossStyle = nil

-- Target HUD card: themed with Theme:Bind so it recolours on its own
local hud = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(236, 58), Visible = false, Parent = layer })
Theme:Bind(hud, { BackgroundColor3 = "Panel" })
make("UICorner", { CornerRadius = UDim.new(0, 2), Parent = hud })
Theme:Bind(stroke(hud, 1, Color3.new()), { Color = "Border" })
local hudGlow = Hellspawn:AttachGlow(hud, { Spread = 18, Strength = 0.18, Wide = true })
local hudCrown = make("Frame", { BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 0, 0, 2), Parent = hud })
Theme:Bind(make("UIGradient", { Parent = hudCrown }), { Color = "AccentGradient" })
Hellspawn:AttachGlow(hudCrown, { Spread = 8, Strength = 0.5 })
local hudAvatar = make("ImageLabel", {
	BorderSizePixel = 0,
	Position = UDim2.fromOffset(10, 12),
	Size = UDim2.fromOffset(34, 34),
	Parent = hud,
})
Theme:Bind(hudAvatar, { BackgroundColor3 = "Surface" })
make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = hudAvatar })
Theme:Bind(stroke(hudAvatar, 1, Color3.new()), { Color = "Accent" })
local hudName = make("TextLabel", {
	BackgroundTransparency = 1,
	FontFace = fontBold,
	TextSize = 13,
	TextXAlignment = Enum.TextXAlignment.Left,
	TextTruncate = Enum.TextTruncate.AtEnd,
	Position = UDim2.fromOffset(54, 9),
	Size = UDim2.new(1, -64, 0, 16),
	Parent = hud,
})
Theme:Bind(hudName, { TextColor3 = "Text" })
local hudInfo = make("TextLabel", {
	BackgroundTransparency = 1,
	FontFace = fontBody,
	TextSize = 10,
	RichText = true,
	TextXAlignment = Enum.TextXAlignment.Left,
	Position = UDim2.fromOffset(54, 25),
	Size = UDim2.new(1, -64, 0, 12),
	Parent = hud,
})
Theme:Bind(hudInfo, { TextColor3 = "TextDim" })
local hudBar = make("Frame", { BorderSizePixel = 0, Position = UDim2.new(0, 54, 0, 42), Size = UDim2.new(1, -64, 0, 4), Parent = hud })
Theme:Bind(hudBar, { BackgroundColor3 = "Surface" })
local hudFill = make("Frame", { BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), Parent = hudBar })
Theme:Bind(make("UIGradient", { Parent = hudFill }), { Color = "AccentGradient" })
Hellspawn:AttachGlow(hudFill, { Spread = 6, Strength = 0.45 })
local hudPlayer = nil

local function updateOverlays(now)
	local origin = aimOrigin()
	local accent = Theme:Get("Accent")

	-- FOV circle with an orbiting crown of thorns
	local showFov = Toggles.fov_show.Value
	local radius = Flags.aim_fov
	fov.Visible = showFov
	if showFov then
		local color = Toggles.esp_theme.Value and accent or Options.fov_color.Value
		fov.Position = UDim2.fromOffset(origin.X, origin.Y)
		fov.Size = UDim2.fromOffset(radius * 2, radius * 2)
		fov.BackgroundColor3 = color
		fov.BackgroundTransparency = Options.fov_color.Transparency
		fovStroke.Color = color
		fovHaloStroke.Color = color
		fovHaloStroke.Transparency = 0.8 + 0.08 * math.sin(now * 2)
	end
	local spin = now * Flags.fov_spin
	for i, thorn in thorns do
		local visible = showFov and Toggles.fov_thorns.Value
		thorn.Visible = visible
		if visible then
			local angle = spin + (i - 1) * math.pi / 4
			local direction = Vector2.new(math.cos(angle), math.sin(angle))
			local at = origin + direction * (radius + 7)
			thorn.Position = UDim2.fromOffset(at.X, at.Y)
			thorn.Rotation = math.deg(angle) + 90
			thorn.ImageColor3 = fovStroke.Color
		end
	end

	-- crosshair
	crosshair.Visible = Toggles.cross_show.Value
	if crosshair.Visible then
		if crossStyle ~= Flags.cross_style then
			crossStyle = Flags.cross_style
			Assets:ApplyIcon(crosshair, crossStyle)
		end
		local color = Toggles.esp_theme.Value and Theme:Get("Text") or Options.cross_color.Value
		crosshair.Position = UDim2.fromOffset(origin.X, origin.Y)
		crosshair.Size = UDim2.fromOffset(Flags.cross_size, Flags.cross_size)
		crosshair.Rotation = (now * Flags.cross_spin * 90) % 360
		crosshair.ImageColor3 = color
		crosshairBloom.ImageColor3 = accent
	end

	-- target HUD follows the aimbot lock (or the closest valid target in the FOV)
	local target = lockedTarget
	if not target and Toggles.hud_show.Value then
		local best, bestDistance = nil, radius
		for player in esps do
			local part = validTarget(player, true)
			if part then
				local point, visible = toScreen(part.Position)
				local d = (point - origin).Magnitude
				if visible and d < bestDistance then
					best, bestDistance = player, d
				end
			end
		end
		target = best
	end
	local character, humanoid, rootPart = getCharacter(target)
	hud.Visible = Toggles.hud_show.Value and character ~= nil
	if hud.Visible then
		if hudPlayer ~= target then
			hudPlayer = target
			hudAvatar.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", target.UserId)
			hudGlow:Flash(0.7, 0.6)
		end
		local fraction = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
		local distance = (rootPart.Position - camera().CFrame.Position).Magnitude
		hud.Position = UDim2.fromOffset(origin.X, origin.Y + Flags.hud_offset)
		hudName.Text = target.DisplayName .. (target == lockedTarget and "  ·  locked" or "")
		hudInfo.Text = string.format(
			"%d / %d hp  ·  %dm  ·  @%s",
			math.floor(humanoid.Health + 0.5),
			math.floor(humanoid.MaxHealth + 0.5),
			math.floor(distance + 0.5),
			target.Name
		)
		hudFill.Size = UDim2.fromScale(fraction, 1)
	else
		hudPlayer = nil
	end
end

----------------------------------------------------------------------
-- aimbot + triggerbot
----------------------------------------------------------------------

local function closestTarget(origin, radius)
	local best, bestPart, bestDistance = nil, nil, radius
	for _, player in Players:GetPlayers() do
		local part = validTarget(player)
		if part then
			local point, visible = toScreen(part.Position)
			local distance = (point - origin).Magnitude
			if visible and distance <= bestDistance then
				best, bestPart, bestDistance = player, part, distance
			end
		end
	end
	return best, bestPart
end

local function aimStep(dt)
	if not Toggles.aim_enabled.Value then
		lockedTarget = nil
		return
	end
	local origin = aimOrigin()
	local radius = Flags.aim_fov
	local part
	if Toggles.aim_sticky.Value and lockedTarget then
		part = validTarget(lockedTarget)
		if part then
			local point, visible = toScreen(part.Position)
			if not visible or (point - origin).Magnitude > radius * 1.5 then
				part = nil
			end
		end
	end
	if not part then
		lockedTarget, part = closestTarget(origin, radius)
	end
	if not part then
		return
	end

	local aimAt = part.Position + part.AssemblyLinearVelocity * Flags.aim_prediction
	-- frame-rate independent smoothing: 0 snaps, 0.95 drifts
	local alpha = 1 - math.clamp(Flags.aim_smooth, 0, 0.98) ^ (dt * 60)
	if Flags.aim_method == "Mouse" and moveMouse then
		local point = toScreen(aimAt)
		local delta = (point - origin) * alpha
		moveMouse(delta.X, delta.Y)
	else
		local cam = camera()
		cam.CFrame = cam.CFrame:Lerp(CFrame.lookAt(cam.CFrame.Position, aimAt), alpha)
	end
end

local lastShot, shotPending = 0, false
local function triggerStep()
	if not Toggles.trigger.Value or shotPending or not clickMouse then
		return
	end
	if Hellspawn:IsMouseOverUI() or os.clock() - lastShot < Flags.trigger_rate / 1000 then
		return
	end
	local origin = aimOrigin()
	local ray = camera():ViewportPointToRay(origin.X, origin.Y)
	rayParams.FilterDescendantsInstances = { LocalPlayer.Character }
	local result = Workspace:Raycast(ray.Origin, ray.Direction * 2000, rayParams)
	if not result then
		return
	end
	local model = result.Instance:FindFirstAncestorOfClass("Model")
	local player = model and Players:GetPlayerFromCharacter(model)
	if not player or not validTarget(player, true) then
		return
	end
	shotPending = true
	task.delay(Flags.trigger_delay / 1000, function()
		shotPending = false
		if Toggles.trigger.Value then
			lastShot = os.clock()
			clickMouse()
		end
	end)
end

Toggles.trigger:OnChanged(function(on)
	if on and not clickMouse then
		Hellspawn:Notify({ Title = "Triggerbot", Content = "Your executor has no mouse1click; the triggerbot can't fire.", Type = "warning" })
	end
end)
Options.aim_method:OnChanged(function(method)
	if method == "Mouse" and not moveMouse then
		Hellspawn:Notify({ Title = "Aimbot", Content = "No mousemoverel on this executor; falling back to the camera.", Type = "warning" })
	end
end)

----------------------------------------------------------------------
-- movement
----------------------------------------------------------------------

local defaults = setmetatable({}, { __mode = "k" }) -- humanoid -> original stats
local function remember(humanoid)
	local saved = defaults[humanoid]
	if not saved then
		saved = { WalkSpeed = humanoid.WalkSpeed, JumpPower = humanoid.JumpPower, UseJumpPower = humanoid.UseJumpPower }
		defaults[humanoid] = saved
	end
	return saved
end

local function restoreStat(key)
	local _, humanoid = getCharacter(LocalPlayer)
	if humanoid and defaults[humanoid] then
		humanoid[key] = defaults[humanoid][key]
		if key == "JumpPower" then
			humanoid.UseJumpPower = defaults[humanoid].UseJumpPower
		end
	end
end

local noclipped = {}
local function restoreNoclip()
	for part in noclipped do
		if part.Parent then
			part.CanCollide = true
		end
	end
	table.clear(noclipped)
end

local function restoreFly()
	local _, humanoid, root = getCharacter(LocalPlayer)
	if humanoid then
		humanoid.PlatformStand = false
	end
	if root then
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

Toggles.speed:OnChanged(function(on)
	if not on then
		restoreStat("WalkSpeed")
	end
end)
Toggles.jump:OnChanged(function(on)
	if not on then
		restoreStat("JumpPower")
	end
end)
Toggles.noclip:OnChanged(function(on)
	if not on then
		restoreNoclip()
	end
end)
Toggles.fly:OnChanged(function(on)
	if not on then
		restoreFly()
	end
end)

local function movementStep(dt)
	local character, humanoid, root = getCharacter(LocalPlayer)
	if not character then
		return
	end
	remember(humanoid)
	if Toggles.speed.Value then
		humanoid.WalkSpeed = Flags.speed_value
	end
	if Toggles.jump.Value then
		humanoid.UseJumpPower = true
		humanoid.JumpPower = Flags.jump_value
	end
	if Toggles.fly.Value then
		local cam = camera()
		local move = Vector3.zero
		if not UserInputService:GetFocusedTextBox() then
			local keys = {
				[Enum.KeyCode.W] = cam.CFrame.LookVector,
				[Enum.KeyCode.S] = -cam.CFrame.LookVector,
				[Enum.KeyCode.D] = cam.CFrame.RightVector,
				[Enum.KeyCode.A] = -cam.CFrame.RightVector,
				[Enum.KeyCode.Space] = Vector3.yAxis,
				[Enum.KeyCode.LeftControl] = -Vector3.yAxis,
			}
			for key, direction in keys do
				if UserInputService:IsKeyDown(key) then
					move += direction
				end
			end
		end
		if move.Magnitude > 0 then
			move = move.Unit
		end
		humanoid.PlatformStand = true
		if Flags.fly_mode == "CFrame" then
			root.AssemblyLinearVelocity = Vector3.zero
			root.CFrame += move * Flags.fly_speed * dt
		else
			root.AssemblyLinearVelocity = move * Flags.fly_speed
		end
	end
end

bind(RunService.Stepped, function()
	if not Toggles.noclip.Value then
		return
	end
	local character = LocalPlayer.Character
	if not character then
		return
	end
	for _, part in character:GetDescendants() do
		if part:IsA("BasePart") and part.CanCollide then
			part.CanCollide = false
			noclipped[part] = true
		end
	end
end)

bind(UserInputService.JumpRequest, function()
	if Toggles.infinite_jump.Value then
		local _, humanoid = getCharacter(LocalPlayer)
		if humanoid then
			humanoid:ChangeState(Enum.HumanoidStateType.Jumping)
		end
	end
end)

----------------------------------------------------------------------
-- world
----------------------------------------------------------------------

local LIGHTING_KEYS = { "Brightness", "ClockTime", "FogEnd", "FogStart", "GlobalShadows", "Ambient", "OutdoorAmbient" }
local lightingDefaults = {}
for _, key in LIGHTING_KEYS do
	lightingDefaults[key] = Lighting[key]
end
local atmospheres = {}
local grade = nil

local function restoreLighting(keys)
	for _, key in keys do
		pcall(function()
			Lighting[key] = lightingDefaults[key]
		end)
	end
end

Toggles.fullbright:OnChanged(function(on)
	if not on then
		restoreLighting({ "Brightness", "GlobalShadows", "OutdoorAmbient" })
	end
end)
Toggles.no_fog:OnChanged(function(on)
	if not on then
		restoreLighting({ "FogEnd", "FogStart" })
		for atmosphere, density in atmospheres do
			if atmosphere.Parent then
				atmosphere.Density = density
			end
		end
		table.clear(atmospheres)
	end
end)
Toggles.time_override:OnChanged(function(on)
	if not on then
		restoreLighting({ "ClockTime" })
	end
end)
Toggles.ambient_override:OnChanged(function(on)
	if not on then
		restoreLighting({ "Ambient", "OutdoorAmbient" })
	end
end)
Toggles.grade:OnChanged(function(on)
	if not on and grade then
		grade:Destroy()
		grade = nil
	end
end)

local function worldStep()
	if Toggles.fullbright.Value then
		Lighting.Brightness = 2
		Lighting.GlobalShadows = false
		Lighting.OutdoorAmbient = rgb(140, 140, 140)
	end
	if Toggles.no_fog.Value then
		Lighting.FogStart = 0
		Lighting.FogEnd = 1e6
		for _, child in Lighting:GetChildren() do
			if child:IsA("Atmosphere") then
				if atmospheres[child] == nil then
					atmospheres[child] = child.Density
				end
				child.Density = 0
			end
		end
	end
	if Toggles.time_override.Value then
		Lighting.ClockTime = Flags.clock_time
	end
	if Toggles.ambient_override.Value then
		Lighting.Ambient = Options.ambient_color.Value
		Lighting.OutdoorAmbient = Options.ambient_color.Value
	end
	if Toggles.grade.Value then
		if not grade or not grade.Parent then
			grade = Instance.new("ColorCorrectionEffect")
			grade.Name = "\0"
			grade.Parent = Lighting
		end
		-- pulls the whole world toward the theme's accent, like a film grade
		local strength = Flags.grade_strength / 100
		grade.TintColor = Color3.new(1, 1, 1):Lerp(Theme:Get("Accent"), strength * 0.4)
		grade.Saturation = -0.35 * strength
		grade.Contrast = 0.18 * strength
		grade.Brightness = -0.03 * strength
	end
end

----------------------------------------------------------------------
-- misc
----------------------------------------------------------------------

local function selectedTarget()
	local name = Flags.target_player
	return name and Players:FindFirstChild(name) or nil
end

local function applySpectate()
	local cam = camera()
	if Toggles.spectate.Value then
		local _, humanoid = getCharacter(selectedTarget())
		if humanoid then
			cam.CameraSubject = humanoid
			return
		end
	end
	local _, mine = getCharacter(LocalPlayer)
	if mine then
		cam.CameraSubject = mine
	end
end
Toggles.spectate:OnChanged(applySpectate)
Options.target_player:OnChanged(applySpectate)

peopleButtons.Callback = function()
	local _, _, targetRoot = getCharacter(selectedTarget())
	local _, _, myRoot = getCharacter(LocalPlayer)
	if targetRoot and myRoot then
		myRoot.CFrame = targetRoot.CFrame * CFrame.new(0, 0, 4)
	else
		Hellspawn:Notify({ Title = "Teleport", Content = "Pick a target with a character first.", Type = "warning" })
	end
end
copyName.Callback = function()
	local target = selectedTarget()
	if target and setclipboard then
		setclipboard(target.Name)
		Hellspawn:Notify({ Title = "Copied", Content = "@" .. target.Name, Duration = 2 })
	end
end
rejoinButton.Callback = function()
	if #Players:GetPlayers() <= 1 then
		TeleportService:Teleport(game.PlaceId, LocalPlayer)
	else
		TeleportService:TeleportToPlaceInstance(game.PlaceId, game.JobId, LocalPlayer)
	end
end
jobButton.Callback = function()
	if setclipboard then
		setclipboard(game.JobId)
		Hellspawn:Notify({ Title = "Copied", Content = "job id on your clipboard", Duration = 2 })
	end
end

bind(LocalPlayer.Idled, function()
	if Toggles.anti_afk.Value then
		local virtualUser = service("VirtualUser")
		virtualUser:CaptureController()
		virtualUser:ClickButton2(Vector2.new())
	end
end)

local statusClock = 0
local function statusStep(now)
	if now - statusClock < 0.5 then
		return
	end
	statusClock = now
	local target = selectedTarget()
	local character, humanoid = getCharacter(target)
	if character then
		targetStatus:SetText(string.format("%s · <b>%d</b> hp%s", target.DisplayName, math.floor(humanoid.Health + 0.5), Toggles.spectate.Value and " · watching" or ""))
	else
		targetStatus:SetText("no target selected")
	end
	serverStatus:SetText(string.format("players <b>%d</b> / %d  ·  ping %dms", #Players:GetPlayers(), Players.MaxPlayers, Hellspawn:GetPing()))
end

----------------------------------------------------------------------
-- frame loop
----------------------------------------------------------------------

-- every step is isolated: one failing feature can't take the others down
local failures = {}
local function safely(name, fn, ...)
	local ok, err = pcall(fn, ...)
	if not ok and not failures[name] then
		failures[name] = true
		warn("[Hellspawn demo] " .. name .. " failed: " .. tostring(err))
	end
end

local AIM_STEP = "HellspawnAim"
RunService:BindToRenderStep(AIM_STEP, Enum.RenderPriority.Camera.Value + 1, function(dt)
	safely("aimbot", aimStep, dt)
end)

bind(RunService.RenderStepped, function(dt)
	local now = os.clock()
	for _, esp in esps do
		safely("esp", esp.Update, esp, now, dt)
	end
	safely("overlays", updateOverlays, now)
end)

bind(RunService.Heartbeat, function(dt)
	safely("movement", movementStep, dt)
	safely("triggerbot", triggerStep)
	safely("world", worldStep)
	safely("status", statusStep, os.clock())
end)

----------------------------------------------------------------------
-- settings, autoload, cleanup
----------------------------------------------------------------------

Window:AddSettingsTab()
Hellspawn.Config:LoadAutoload()

Hellspawn:OnUnload(function()
	RunService:UnbindFromRenderStep(AIM_STEP)
	for _, connection in connections do
		connection:Disconnect()
	end
	for _, esp in esps do
		esp:Destroy()
	end
	chamsFolder:Destroy()
	restoreStat("WalkSpeed")
	restoreStat("JumpPower")
	restoreNoclip()
	restoreFly()
	restoreLighting(LIGHTING_KEYS)
	for atmosphere, density in atmospheres do
		if atmosphere.Parent then
			atmosphere.Density = density
		end
	end
	if grade then
		grade:Destroy()
	end
	local _, humanoid = getCharacter(LocalPlayer)
	if humanoid then
		camera().CameraSubject = humanoid
	end
end)

Hellspawn:Notify({
	Title = "Hellspawn",
	Content = "Loaded. Press <b>RShift</b> to hide the menu.",
	Type = "success",
	Duration = 5,
})
