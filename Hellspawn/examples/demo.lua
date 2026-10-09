--[[
	Hellspawn — full showcase with working features

	Every visual in here belongs to the menu's world: the library's pixel-art
	sprite packs (bones, hellfire, wicker and chains, flesh and eyes), or the
	menu's own look (theme colours, native UIShadow neon, thorns and sigils).
	Each ESP style is one entry in SKINS, so adding your own is a table away.

	  Combat    aimbot (camera / mouse), triggerbot, six FOV styles, a pixel pentagram
	            crosshair, four target HUDs (tombstone, scroll, card, minimal)
	  Visuals   ESP in four pixel-art styles (Graveyard, Inferno, Ritual, Eldritch)
	            or Neon: boxes, names, distance, health, skeleton, tracers,
	            off-screen markers; chams, world lighting + "Hellspawn grade"
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
FovPage:AddDropdown("fov_style", {
	Text = "Style",
	Values = { "Ritual", "Thorns", "Fangs", "Chains", "Eyes", "Neon" },
	Default = "Ritual",
	Tooltip = "Ritual circle, crown of thorns, a jaw that bites on lock, iron chains, or a ring of eyes that watch your target.",
})
FovPage:AddSlider("fov_spin", { Text = "Spin", Min = 0, Max = 3, Increment = 0.1, Default = 0.4, Compact = true })
local CrossPage = Overlay:AddTab("Crosshair")
CrossPage:AddToggle("cross_show", { Text = "Crosshair", Default = true }):AddColorPicker("cross_color", { Default = rgb(236, 231, 222) })
CrossPage:AddDropdown("cross_style", {
	Text = "Style",
	Values = { "pentagram", "sigil", "crosshair", "cross", "thorns", "eye" },
	Default = "pentagram",
	Tooltip = "pentagram is pixel art: its size snaps to whole multiples of 31px.",
})
CrossPage:AddSlider("cross_size", { Text = "Size", Min = 8, Max = 96, Default = 31, Suffix = "px", Compact = true })
CrossPage:AddSlider("cross_spin", { Text = "Spin", Min = 0, Max = 3, Increment = 0.1, Default = 0, Compact = true })
local HudPage = Overlay:AddTab("HUD")
HudPage:AddToggle("hud_show", { Text = "Target HUD", Default = true, Tooltip = "Card under the crosshair with the current target." })
HudPage:AddDropdown("hud_style", { Text = "Style", Values = { "Tombstone", "Scroll", "Card", "Minimal" }, Default = "Tombstone" })
HudPage:AddSlider("hud_offset", { Text = "Offset", Min = 60, Max = 400, Default = 170, Suffix = "px", Compact = true })

-- Visuals --------------------------------------------------------------

local EspBox = Visuals:AddLeftGroupbox("Players", { Icon = "user" })
EspBox:AddToggle("esp_enabled", { Text = "Enabled", Default = true }):AddKeybind("esp_key", { Text = "ESP" })
EspBox:AddDropdown("esp_style", {
	Text = "Style",
	Values = { "Graveyard", "Inferno", "Ritual", "Eldritch", "Neon" },
	Default = "Graveyard",
	Tooltip = "Pixel art: Graveyard (bones, vines, roses), Inferno (charred bones, hellfire), Ritual (wicker effigy, chains, candles), Eldritch (sinew, eyes, tentacles). Neon: the menu's own glow.",
})
local PixelStyle = EspBox:AddDependencyBox()
PixelStyle:AddToggle("esp_tint", { Text = "Tint pixel art", Tooltip = "Blend the sprites toward the theme accent." })
PixelStyle:AddToggle("esp_particles", { Text = "Particles", Default = true, Tooltip = "Falling petals, embers, candle sparks or blood, depending on the style." })
PixelStyle:SetupDependencies({
	{
		Options.esp_style,
		function(style)
			return style ~= "Neon"
		end,
	},
})
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
-- pixel kit: the library's pixel-art sprite packs, drawn Pixelated
----------------------------------------------------------------------

local fontPixel = Font.fromEnum(Enum.Font.Arcade)
local fontGothic = Assets:Font("Display")
local WHITE = Color3.new(1, 1, 1)
local BLOOD = rgb(255, 46, 66)

-- the sprite each label shows right now, so animations only write on change
local showing = setmetatable({}, { __mode = "k" })

local function setImage(image, name)
	if showing[image] ~= name then
		showing[image] = name
		image.Image = Assets:Texture(name)
	end
end

local function sprite(name, parent, zindex, anchor)
	local image = make("ImageLabel", {
		BackgroundTransparency = 1,
		ResampleMode = Enum.ResamplerMode.Pixelated,
		AnchorPoint = anchor or Vector2.new(0.5, 0.5),
		Visible = false,
		ZIndex = zindex or 1,
		Parent = parent,
	})
	if name then
		setImage(image, name)
	end
	return image
end

local function tiled(name, parent, zindex, anchor)
	local image = sprite(name, parent, zindex, anchor or Vector2.zero)
	image.ScaleType = Enum.ScaleType.Tile
	return image
end

local function bloom(parent, size, zindex)
	return make("ImageLabel", {
		BackgroundTransparency = 1,
		Image = Assets:Texture("bloom"),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.fromScale(0.5, 0.5),
		Size = size,
		ImageTransparency = 0.7,
		Visible = false,
		ZIndex = zindex or 1,
		Parent = parent,
	})
end

-- one frame of an animation: a single name, or a list played at `fps`
local function pick(frames, fps, t)
	if type(frames) == "string" then
		return frames
	end
	return frames[math.floor(t * (fps or 0)) % #frames + 1]
end

-- pixel size of a sprite
local function dims(name)
	local meta = Assets:Meta(name)
	if meta then
		return meta.Width, meta.Height
	end
	return 16, 16
end

-- deterministic noise in [0, 1)
local function hash(n)
	return (math.sin(n * 12.9898) * 43758.5453) % 1
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

-- where a pupil sits inside its eye: toward `target`, at most `reach` px
local function gaze(center, target, reach)
	local delta = target - center
	if delta.Magnitude < 1 then
		return center
	end
	return center + delta.Unit * math.min(reach, delta.Magnitude * 0.08 + reach * 0.4)
end

local function frames(prefix, count)
	local list = {}
	for i = 1, count do
		list[i] = prefix .. i
	end
	return list
end

--[[
	ESP skins. Every pixel style is the same rig with different sprites:
		Frame     tiles crawling around the box (H along top/bottom, V along the sides)
		Corner    a sprite blooming on each corner
		Limb      stretched between joints (R6 limbs get two, meeting at the elbow/knee)
		Head      Face is the sprite region that covers the head; Eyes light up on lock
		Chest     ribcage (+ an Overlay drawn behind it); Hips the pelvis
		Spine     the health column, tiled; Back shows what's been lost
		Marker    off-screen pointer, Tracer the line from the screen edge, Tag the name icon
]]
local SKINS = {
	Graveyard = {
		Frame = { H = "px_vine_h", V = "px_vine_v" },
		Corner = { Image = "px_rose", Tilt = true },
		Limb = "px_bone",
		Head = { Image = "px_skull", Face = { 0, 0, 16, 16 }, Scale = 1.25, Eyes = { Vector2.new(5, 7.5), Vector2.new(11, 7.5) }, EyeColor = BLOOD },
		Chest = { Image = "px_ribs" },
		Hips = "px_pelvis",
		Spine = { Fill = "px_vertebra", Low = BLOOD },
		Marker = { Image = "px_thorn", Bloom = BLOOD, BloomAt = 0.75 },
		Tracer = { Image = "px_vine_h" },
		Tag = { Image = "px_skull" },
		Particles = { From = "top", Dir = 1, Travel = 70, Speed = 0.32, Sway = 7, Count = 5, Colors = { rgb(200, 16, 46), rgb(122, 8, 24), rgb(255, 64, 88) } },
		Ink = rgb(246, 238, 220), Dim = rgb(168, 151, 122), Outline = rgb(26, 18, 14), Hot = BLOOD,
	},
	Inferno = {
		-- side flames are rotated so every tongue licks outward
		Frame = { H = frames("px_fire_h", 3), V = frames("px_fire_v", 3), Fps = 9, Flip = { 0, 180, 0, 0 } },
		Corner = { Image = frames("px_brimstone", 2), Fps = 5, Bloom = rgb(255, 106, 20) },
		Limb = "px_char_bone",
		Head = { Image = "px_demon_skull", Face = { 3, 5, 16, 16 }, Scale = 1.25, Eyes = { Vector2.new(8, 12.5), Vector2.new(14, 12.5) }, EyeColor = rgb(255, 226, 120) },
		Chest = { Image = "px_char_ribs" },
		Hips = "px_char_pelvis",
		Spine = { Fill = "px_magma", Low = rgb(90, 40, 30) },
		Marker = { Image = frames("px_fireball", 2), Fps = 8, Bloom = rgb(255, 106, 20) },
		Tracer = { Image = frames("px_fire_h", 3), Fps = 9 },
		Tag = { Image = "px_demon_skull" },
		Particles = { From = "box", Dir = -1, Travel = 48, Speed = 0.7, Sway = 4, Count = 9, Colors = { rgb(255, 242, 184), rgb(255, 180, 58), rgb(255, 106, 20), rgb(208, 42, 10) } },
		Ink = rgb(255, 214, 150), Dim = rgb(214, 112, 58), Outline = rgb(42, 8, 2), Hot = rgb(255, 230, 140),
	},
	Ritual = {
		Frame = { H = "px_chain_h", V = "px_chain_v" },
		Corner = { Image = frames("px_candle", 2), Fps = 6, Anchor = Vector2.new(0.5, 0.82), Bloom = rgb(255, 150, 40), BloomAt = 0.22 },
		Limb = "px_stick",
		Head = { Image = "px_goat_skull", Face = { 5, 3, 12, 15 }, Scale = 1.15, Eyes = { Vector2.new(8.4, 10), Vector2.new(13.6, 10) }, EyeColor = BLOOD },
		Chest = { Image = "px_wicker_ribs" },
		Hips = "px_wicker_pelvis",
		Spine = { Fill = "px_bead" },
		Marker = { Image = "px_nail", Bloom = rgb(200, 16, 46) },
		Tracer = { Image = "px_chain_h" },
		Tag = { Image = frames("px_candle", 2), Fps = 6 },
		Particles = { From = "corners", Dir = -1, Travel = 26, Speed = 0.9, Sway = 2, Count = 8, Colors = { rgb(255, 242, 184), rgb(255, 180, 58), rgb(120, 112, 106) } },
		Ink = rgb(236, 220, 186), Dim = rgb(176, 132, 80), Outline = rgb(22, 13, 6), Hot = BLOOD,
	},
	Eldritch = {
		Frame = { H = frames("px_tentacle_h", 3), V = frames("px_tentacle_v", 3), Fps = 5 },
		-- the corner eyes and the head watch your crosshair
		Corner = { Image = "px_eye", Pupil = "px_pupil" },
		Limb = "px_sinew",
		Head = { Image = "px_eye", Face = { 1.4, 1.4, 13.2, 13.2 }, Scale = 1.2, Pupil = "px_pupil" },
		Chest = { Image = "px_flesh_ribs", Overlay = "px_heart" },
		Hips = "px_flesh_pelvis",
		Spine = { Fill = "px_eye_open", Back = "px_eye_shut" },
		Marker = { Image = frames("px_tendril", 2), Fps = 4, Bloom = rgb(168, 72, 126) },
		Tracer = { Image = frames("px_tentacle_h", 3), Fps = 5 },
		Tag = { Image = "px_eye_open", Blink = "px_eye_shut" },
		Particles = { From = "bottom", Dir = 1, Travel = 30, Speed = 0.45, Sway = 0, Gravity = true, Count = 6, Colors = { rgb(110, 10, 30), rgb(176, 24, 44) } },
		Ink = rgb(247, 190, 204), Dim = rgb(176, 96, 136), Outline = rgb(30, 4, 14), Hot = rgb(232, 64, 90),
	},
}

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
local CORNER_TILT = { -14, 10, -8, 13 }
local MAX_PARTICLES = 9

local chamsFolder = Instance.new("Folder")
chamsFolder.Name = "\0"
chamsFolder.Parent = Hellspawn.Env.guiParent(chamsFolder)

local Esp = {}
Esp.__index = Esp
local esps = {}
local lockedTarget = nil -- the aimbot's current target (marked by its ESP)

function Esp.new(player)
	local self = setmetatable({ Player = player, Grown = 0 }, Esp)
	-- desync the animations between players
	self.Phase = hash(#player.Name + (player.UserId % 977)) * 10
	self.Root = make("Frame", {
		Name = player.Name,
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
		Parent = layer,
	})
	self:_buildNeon()
	self:_buildPixel()
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

-- pixel styles: one rig, skinned from SKINS ------------------------------

function Esp:_buildPixel()
	local root = self.Root
	local p = { Limbs = {} }
	self.Px = p

	-- frame edges crawl clockwise from the top-left corner
	p.Edges = {
		tiled(nil, root, 1, Vector2.new(0, 0.5)), -- top, grows right
		tiled(nil, root, 1, Vector2.new(0.5, 0)), -- right, grows down
		tiled(nil, root, 1, Vector2.new(1, 0.5)), -- bottom, grows left
		tiled(nil, root, 1, Vector2.new(0.5, 1)), -- left, grows up
	}
	p.Corners, p.CornerPupils, p.CornerBlooms = {}, {}, {}
	for i = 1, 4 do
		p.CornerBlooms[i] = bloom(root, UDim2.fromOffset(40, 40), 1)
		p.Corners[i] = sprite(nil, root, 2)
		p.CornerPupils[i] = sprite("px_pupil", root, 3)
	end

	p.Chest = sprite(nil, root, 3)
	p.Overlay = sprite(nil, root, 4) -- over the ribs (a beating heart)
	p.Hips = sprite(nil, root, 3)
	p.Head = sprite(nil, root, 4)
	p.Pupil = sprite("px_pupil", root, 5)
	p.Eyes = {}
	for i = 1, 2 do
		local eye = make("Frame", {
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(3, 3),
			Visible = false,
			ZIndex = 5,
			Parent = root,
		})
		p.Eyes[i] = { Frame = eye, Glow = neon(eye, 8, 0.15) }
	end

	-- health column: what's been lost behind, the living part clipped on top
	p.SpineBack = tiled(nil, root, 2)
	p.SpineClip = make("Frame", {
		BackgroundTransparency = 1,
		ClipsDescendants = true,
		AnchorPoint = Vector2.new(0, 1),
		Visible = false,
		ZIndex = 3,
		Parent = root,
	})
	p.SpineFill = tiled(nil, p.SpineClip, 3, Vector2.new(0, 1))
	p.SpineFill.Position = UDim2.fromScale(0, 1)
	p.SpineFill.Visible = true
	p.SpineText = make("TextLabel", {
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

	p.Tag = make("Frame", {
		BackgroundTransparency = 1,
		AnchorPoint = Vector2.new(0.5, 1),
		Size = UDim2.fromOffset(240, 22),
		Visible = false,
		ZIndex = 4,
		Parent = root,
	})
	p.Name = make("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = fontPixel,
		TextSize = 16,
		TextStrokeTransparency = 0,
		Size = UDim2.fromScale(1, 1),
		ZIndex = 4,
		Parent = p.Tag,
	})
	p.TagIcon = sprite(nil, p.Tag, 4, Vector2.new(1, 0.5))
	p.TagIcon.Visible = true

	p.Distance = make("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = fontPixel,
		TextSize = 12,
		TextStrokeTransparency = 0.1,
		AnchorPoint = Vector2.new(0.5, 0),
		Size = UDim2.fromOffset(120, 14),
		Visible = false,
		ZIndex = 4,
		Parent = root,
	})

	p.Tracer = tiled(nil, root, 1, Vector2.new(0.5, 0.5))
	p.Marker = sprite(nil, root, 3)
	p.MarkerBloom = bloom(p.Marker, UDim2.fromScale(2.1, 1.05), 2)
	p.MarkerBloom.Position = UDim2.fromScale(0.5, 0.3)
	p.MarkerBloom.Visible = true

	p.Particles = {}
	for i = 1, MAX_PARTICLES do
		p.Particles[i] = make("Frame", {
			BorderSizePixel = 0,
			AnchorPoint = Vector2.new(0.5, 0.5),
			Visible = false,
			ZIndex = 5,
			Parent = root,
		})
	end
end

function Esp:_hideBones()
	local p = self.Px
	for _, limb in p.Limbs do
		limb.Visible = false
	end
	p.Head.Visible = false
	p.Pupil.Visible = false
	p.Chest.Visible = false
	p.Overlay.Visible = false
	p.Hips.Visible = false
	for _, eye in p.Eyes do
		eye.Frame.Visible = false
	end
end

function Esp:_hidePixel()
	local p = self.Px
	for i = 1, 4 do
		p.Edges[i].Visible = false
		p.Corners[i].Visible = false
		p.CornerPupils[i].Visible = false
		p.CornerBlooms[i].Visible = false
	end
	self:_hideBones()
	p.SpineBack.Visible = false
	p.SpineClip.Visible = false
	p.SpineText.Visible = false
	p.Tag.Visible = false
	p.Distance.Visible = false
	p.Tracer.Visible = false
	p.Marker.Visible = false
	for _, dot in p.Particles do
		dot.Visible = false
	end
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
	self:_hidePixel()
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
		Time = now + self.Phase,
	}
	frame.Left = frame.CenterX - frame.Width / 2
	frame.Right = frame.CenterX + frame.Width / 2

	if frame.OnScreen then
		self.Grown = math.min(1, self.Grown + dt * 1.8)
	else
		self.Grown = 0
	end

	local skin = SKINS[Flags.esp_style]
	if skin then
		self:_hideNeon()
		self:_drawPixel(frame, skin)
	else
		self:_hidePixel()
		self:_drawNeon(frame)
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
				local pulse = 0.5 + 0.5 * math.sin(f.Time * 4)
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

-- the skeleton: limbs, ribcage, pelvis and the head sprite
function Esp:_drawBones(f, skin, tint)
	local p = self.Px
	local character, humanoid = f.Character, f.Humanoid
	local limbName = skin.Limb
	local _, limbHeight = dims(limbName)
	local girth = limbHeight / 14 -- sprites are drawn at the bone's pixel scale
	local used = 0
	local function limb(a, b, thickness)
		used += 1
		local image = p.Limbs[used]
		if not image then
			image = sprite(nil, self.Root, 3)
			p.Limbs[used] = image
		end
		setImage(image, limbName)
		placeAlong(image, a, b, thickness * girth, 1.12)
		image.ImageColor3 = tint
	end
	local function upright(image, name, part, upper, lower, widthScale)
		local top, bottom, width, ok = partAxis(part, upper, lower)
		if ok then
			setImage(image, name)
			placeUpright(image, top, bottom, math.max(width * widthScale, 6))
			image.ImageColor3 = tint
		else
			image.Visible = false
		end
	end
	local chest, hips = skin.Chest.Image, skin.Hips

	if humanoid.RigType == Enum.HumanoidRigType.R6 then
		for _, name in LIMBS_R6 do
			local part = character:FindFirstChild(name)
			if part then
				-- each R6 limb gets two bones meeting at the elbow / knee
				local top, bottom, width, ok = partAxis(part, part.Size.Y * 0.47, -part.Size.Y * 0.47)
				if ok then
					local joint = (top + bottom) / 2
					local thickness = math.clamp(width * 0.8, 4, 20)
					limb(top, joint, thickness)
					limb(joint, bottom, thickness)
				end
			end
		end
		local torso = character:FindFirstChild("Torso")
		if torso then
			local h = torso.Size.Y / 2
			upright(p.Chest, chest, torso, h * 1.05, -h * 0.35, 1.15)
			upright(p.Hips, hips, torso, -h * 0.3, -h * 1.15, 1.05)
		else
			p.Chest.Visible = false
			p.Hips.Visible = false
		end
	else
		for _, name in LIMBS_R15 do
			local part = character:FindFirstChild(name)
			if part then
				local top, bottom, width, ok = partAxis(part, part.Size.Y / 2, -part.Size.Y / 2)
				if ok then
					limb(top, bottom, math.clamp(width * 0.9, 4, 18))
				end
			end
		end
		local upper = character:FindFirstChild("UpperTorso")
		local lower = character:FindFirstChild("LowerTorso")
		if upper then
			upright(p.Chest, chest, upper, upper.Size.Y * 0.55, -upper.Size.Y * 0.62, 1.12)
		else
			p.Chest.Visible = false
		end
		if lower then
			local w = lower.Size.X
			upright(p.Hips, hips, lower, w * 0.3, -w * 0.38, 1.1)
		else
			p.Hips.Visible = false
		end
	end
	for i = used + 1, #p.Limbs do
		p.Limbs[i].Visible = false
	end

	-- something lives in the ribcage (it beats faster on the locked target)
	local overlay = skin.Chest.Overlay
	p.Overlay.Visible = overlay ~= nil and p.Chest.Visible
	if p.Overlay.Visible then
		local size = p.Chest.Size.X.Offset
		local rate = f.Locked and 11 or 6.5
		local beat = math.max(0, math.sin(f.Time * rate)) ^ 6 + 0.5 * math.max(0, math.sin(f.Time * rate - 0.9)) ^ 8
		local side = size * 0.42 * (1 + 0.18 * beat)
		-- on their left, which is our right while they face the camera
		local offset = rotate2(Vector2.new(size * 0.1, -p.Chest.Size.Y.Offset * 0.08), p.Chest.Rotation)
		setImage(p.Overlay, overlay)
		p.Overlay.Position = p.Chest.Position + UDim2.fromOffset(offset.X, offset.Y)
		p.Overlay.Size = UDim2.fromOffset(side, side)
		p.Overlay.Rotation = p.Chest.Rotation
		p.Overlay.ImageColor3 = tint
	end

	-- the head: Face is the part of the sprite that sits over the head
	local spec = skin.Head
	local head = f.Head
	local headTop, headBottom, headOk
	if head then
		local size = head.Size.Y * spec.Scale
		local top, bottom, _, ok = partAxis(head, size / 2, -size / 2)
		headTop, headBottom, headOk = top, bottom, ok
	end
	if not headOk then
		p.Head.Visible = false
		p.Pupil.Visible = false
		for _, eye in p.Eyes do
			eye.Frame.Visible = false
		end
		return
	end
	local face = spec.Face
	local w, h = dims(spec.Image)
	local side = (headBottom - headTop).Magnitude
	local pixel = side / face[4]
	local rotation = math.deg(math.atan2(headBottom.Y - headTop.Y, headBottom.X - headTop.X)) - 90
	local center = (headTop + headBottom) / 2
	local faceCenter = Vector2.new(face[1] + face[3] / 2, face[2] + face[4] / 2)
	local function at(spritePoint)
		return center + rotate2((spritePoint - faceCenter) * pixel, rotation)
	end
	local middle = at(Vector2.new(w / 2, h / 2))
	setImage(p.Head, spec.Image)
	p.Head.Position = UDim2.fromOffset(middle.X, middle.Y)
	p.Head.Size = UDim2.fromOffset(w * pixel, h * pixel)
	p.Head.Rotation = rotation
	p.Head.ImageColor3 = tint
	p.Head.Visible = true

	-- a pupil that stares at your crosshair (and dilates when you lock on)
	p.Pupil.Visible = spec.Pupil ~= nil
	if spec.Pupil then
		local look = gaze(middle, aimOrigin(), 2.6 * pixel)
		if f.Locked then
			look += Vector2.new(math.sin(f.Time * 37), math.cos(f.Time * 29)) * pixel * 0.35
		end
		local size = 8 * pixel * (f.Locked and 1.25 or 1)
		p.Pupil.Position = UDim2.fromOffset(look.X, look.Y)
		p.Pupil.Size = UDim2.fromOffset(size, size)
		p.Pupil.ImageColor3 = tint
	end

	-- the sockets catch fire on the aimbot's target
	for i, eye in p.Eyes do
		local point = spec.Eyes and spec.Eyes[i]
		local visible = f.Locked and point ~= nil
		eye.Frame.Visible = visible
		if visible then
			local spot = at(point)
			local flicker = 0.75 + 0.25 * math.sin(f.Time * 18 + i)
			local size = math.max(2, pixel * 1.9)
			eye.Frame.Position = UDim2.fromOffset(spot.X, spot.Y)
			eye.Frame.Size = UDim2.fromOffset(size, size)
			eye.Frame.BackgroundColor3 = spec.EyeColor
			eye.Frame.BackgroundTransparency = 1 - flicker
			if eye.Glow then
				eye.Glow.Color = spec.EyeColor
			end
		end
	end
end

function Esp:_drawPixel(f, skin)
	local p = self.Px
	local player = self.Player
	local t = f.Time
	local tint = WHITE
	if Toggles.esp_tint.Value then
		tint = tint:Lerp(Theme:Get("Accent"), 0.45)
	end

	if not f.OnScreen then
		self:_hidePixel()
		if Toggles.esp_arrows.Value then
			local at, rotation = offscreenPlacement(f.RootPart)
			if at then
				local marker = skin.Marker
				local name = pick(marker.Image, marker.Fps, t)
				local w, h = dims(name)
				local pulse = 0.5 + 0.5 * math.sin(t * 3)
				setImage(p.Marker, name)
				p.Marker.Position = UDim2.fromOffset(at.X, at.Y)
				p.Marker.Size = UDim2.fromOffset(w * 2, h * 2)
				p.Marker.Rotation = rotation
				p.Marker.ImageColor3 = tint
				p.Marker.ImageTransparency = math.clamp(f.Distance / Flags.esp_max_distance, 0, 0.5)
				p.MarkerBloom.Position = UDim2.fromScale(0.5, marker.BloomAt or 0.3)
				p.MarkerBloom.ImageColor3 = marker.Bloom
				p.MarkerBloom.ImageTransparency = 0.62 + 0.25 * pulse
				p.Marker.Visible = true
			end
		end
		return
	end
	p.Marker.Visible = false

	local left, right, top, bottom = f.Left, f.Right, f.Top, f.Bottom
	local width, height = f.Width, f.Height
	local scale = height >= 260 and 2 or 1
	local showBox = Toggles.esp_box.Value
	local hot = skin.Hot

	-- the frame grows around the box, then the corners bloom
	local frame = skin.Frame
	local hName = pick(frame.H, frame.Fps, t)
	local vName = pick(frame.V, frame.Fps, t + 0.37)
	local hw, hh = dims(hName)
	local vw, vh = dims(vName)
	local hThick, vThick = hh * scale, vw * scale
	local reach = easeOut(self.Grown)
	local blossom = easeOut((self.Grown - 0.55) / 0.45)
	local edges = {
		{ left, top, width * reach, hThick, hName, hw, hh },
		{ right, top, vThick, height * reach, vName, vw, vh },
		{ right, bottom, width * reach, hThick, hName, hw, hh },
		{ left, bottom, vThick, height * reach, vName, vw, vh },
	}
	local edgeTint = f.Locked and tint:Lerp(hot, 0.35) or tint
	for i, edge in p.Edges do
		edge.Visible = showBox
		if showBox then
			local e = edges[i]
			setImage(edge, e[5])
			edge.Position = UDim2.fromOffset(e[1], e[2])
			edge.Size = UDim2.fromOffset(e[3], e[4])
			edge.TileSize = UDim2.fromOffset(e[6] * scale, e[7] * scale)
			edge.Rotation = frame.Flip and frame.Flip[i] or 0
			edge.ImageColor3 = edgeTint
		end
	end

	local corner = skin.Corner
	local corners = { Vector2.new(left, top), Vector2.new(right, top), Vector2.new(right, bottom), Vector2.new(left, bottom) }
	local aim = aimOrigin()
	for i, image in p.Corners do
		local visible = showBox and blossom > 0.01
		image.Visible = visible
		p.CornerBlooms[i].Visible = visible and corner.Bloom ~= nil
		p.CornerPupils[i].Visible = visible and corner.Pupil ~= nil
		if visible then
			local name = pick(corner.Image, corner.Fps, t + i * 0.29)
			local w, h = dims(name)
			local px = scale * blossom
			local at = corners[i]
			setImage(image, name)
			image.AnchorPoint = corner.Anchor or Vector2.new(0.5, 0.5)
			image.Position = UDim2.fromOffset(at.X, at.Y)
			image.Size = UDim2.fromOffset(w * px, h * px)
			image.Rotation = corner.Tilt and (CORNER_TILT[i] + math.sin(t * 1.3 + i) * 4) or 0
			image.ImageColor3 = tint
			-- where the sprite's centre actually is, given its anchor
			local anchor = image.AnchorPoint
			local middle = at + Vector2.new((0.5 - anchor.X) * w * px, (0.5 - anchor.Y) * h * px)
			if corner.Bloom then
				local glow = p.CornerBlooms[i]
				local flameY = middle.Y + ((corner.BloomAt or 0.5) - 0.5) * h * px
				local size = math.max(w, h) * px * 2.2
				glow.Position = UDim2.fromOffset(middle.X, flameY)
				glow.Size = UDim2.fromOffset(size, size)
				glow.ImageColor3 = corner.Bloom
				glow.ImageTransparency = 0.6 + 0.15 * math.sin(t * 7 + i * 2)
			end
			if corner.Pupil then
				local pupil = p.CornerPupils[i]
				local look = gaze(middle, aim, 2.4 * px)
				pupil.Position = UDim2.fromOffset(look.X, look.Y)
				pupil.Size = UDim2.fromOffset(8 * px, 8 * px)
				pupil.ImageColor3 = tint
			end
		end
	end

	if Toggles.esp_skeleton.Value and f.Distance < 700 then
		self:_drawBones(f, skin, tint)
	else
		self:_hideBones()
	end

	-- health column: living tiles on top, lost ones dimmed (or swapped) behind
	local spine = skin.Spine
	local humanoid = f.Humanoid
	local fraction = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
	local showHealth = Toggles.esp_health.Value
	p.SpineBack.Visible = showHealth
	p.SpineClip.Visible = showHealth
	if showHealth then
		local sw, sh = dims(spine.Fill)
		local x = left - (showBox and vThick / 2 or 0) - sw - 3
		setImage(p.SpineBack, spine.Back or spine.Fill)
		setImage(p.SpineFill, spine.Fill)
		p.SpineBack.Position = UDim2.fromOffset(x, top)
		p.SpineBack.Size = UDim2.fromOffset(sw, height)
		p.SpineBack.TileSize = UDim2.fromOffset(sw, sh)
		p.SpineBack.ImageColor3 = spine.Back and tint or rgb(90, 84, 76)
		p.SpineBack.ImageTransparency = spine.Back and 0 or 0.55
		p.SpineClip.Position = UDim2.fromOffset(x, bottom)
		p.SpineClip.Size = UDim2.fromOffset(sw, height * fraction)
		p.SpineFill.Size = UDim2.fromOffset(sw, height)
		p.SpineFill.TileSize = UDim2.fromOffset(sw, sh)
		p.SpineFill.ImageColor3 = spine.Low and spine.Low:Lerp(tint, fraction) or tint
		p.SpineText.Visible = fraction < 0.999
		if p.SpineText.Visible then
			p.SpineText.Position = UDim2.fromOffset(x - 2, bottom - height * fraction)
			p.SpineText.Text = tostring(math.floor(humanoid.Health + 0.5))
			p.SpineText.TextColor3 = hot:Lerp(skin.Ink, fraction)
			p.SpineText.TextStrokeColor3 = skin.Outline
		end
	else
		p.SpineText.Visible = false
	end

	p.Tag.Visible = Toggles.esp_name.Value
	if p.Tag.Visible then
		local tag = skin.Tag
		local name = pick(tag.Image, tag.Fps, t)
		if tag.Blink and (t * 0.45) % 1 < 0.05 then
			name = tag.Blink
		end
		local w, h = dims(name)
		setImage(p.TagIcon, name)
		p.Tag.Position = UDim2.fromOffset(f.CenterX, top - (showBox and hThick / 2 or 0) - 2)
		p.Name.Text = string.lower(player.DisplayName)
		p.Name.TextColor3 = skin.Ink
		p.Name.TextStrokeColor3 = skin.Outline
		p.TagIcon.Size = UDim2.fromOffset(w, h)
		p.TagIcon.Position = UDim2.new(0.5, -(p.Name.TextBounds.X / 2) - 4, 0.5, 0)
		p.TagIcon.ImageColor3 = f.Locked and hot or tint
	end
	p.Distance.Visible = Toggles.esp_distance.Value
	if p.Distance.Visible then
		p.Distance.Position = UDim2.fromOffset(f.CenterX, bottom + (showBox and hThick / 2 or 0) + 2)
		p.Distance.Text = string.format("%dm", math.floor(f.Distance + 0.5))
		p.Distance.TextColor3 = skin.Dim
		p.Distance.TextStrokeColor3 = skin.Outline
	end

	if Toggles.esp_tracer.Value then
		local tracer = skin.Tracer
		local name = pick(tracer.Image, tracer.Fps, t)
		local w, h = dims(name)
		local origin = Flags.esp_tracer_origin
		local viewport = f.Viewport
		local from = origin == "Mouse" and aim
			or (origin == "Center" and viewport / 2)
			or Vector2.new(viewport.X / 2, viewport.Y - 6)
		local to = Vector2.new(f.CenterX, bottom + (showBox and hThick / 2 or 0))
		setImage(p.Tracer, name)
		placeAlong(p.Tracer, from, to, h)
		p.Tracer.TileSize = UDim2.fromOffset(w, h)
		p.Tracer.ImageColor3 = tint
	else
		p.Tracer.Visible = false
	end

	-- embers, petals, candle sparks or blood: pure functions of time, no state
	local fx = skin.Particles
	local count = (fx and Toggles.esp_particles.Value and self.Grown > 0.8) and fx.Count or 0
	for i, dot in p.Particles do
		dot.Visible = i <= count
		if i <= count then
			local seed = i * 7.31 + self.Phase
			local clock = t * fx.Speed + hash(seed)
			local life = clock % 1
			local cycle = math.floor(clock)
			local rx, ry = hash(seed + cycle * 3.7), hash(seed * 1.3 + cycle * 1.1)
			local x, y
			if fx.From == "top" then
				x, y = left + width * rx, top
			elseif fx.From == "bottom" then
				x, y = left + width * rx, bottom
			elseif fx.From == "corners" then
				local c = corners[(i - 1) % 4 + 1]
				x, y = c.X + (rx - 0.5) * 4 * scale, c.Y - 12 * scale
			else
				x, y = left + width * rx, top + height * (0.25 + 0.75 * ry)
			end
			local travel = fx.Travel * scale * (fx.Gravity and life * life or life)
			local size = (ry > 0.6 and 3 or 2) * scale
			dot.Position = UDim2.fromOffset(x + math.sin(life * 6 + seed) * fx.Sway, y + fx.Dir * travel)
			dot.Size = UDim2.fromOffset(size, size)
			dot.BackgroundColor3 = fx.Colors[(i + cycle) % #fx.Colors + 1]
			dot.BackgroundTransparency = life ^ 2.2
		end
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
-- FOV, crosshair and target HUD
----------------------------------------------------------------------

-- scoped in a block: Luau allows at most 200 locals per function
local updateOverlays
do
	-- the FOV disc and its neon ring (shared by every style)
	-- FOV pieces sit under the ESP (ZIndex < 1); the crosshair and HUD above it
	local fov = make("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, ZIndex = -2, Parent = layer })
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

	-- ring transparency per style (missing = no ring), and which keep the halo
	local FOV_RING = { Neon = 0, Thorns = 0, Fangs = 0.25, Eyes = 0.7 }
	local FOV_HALO = { Neon = true, Thorns = true }

	-- Thorns: the menu's spikes orbiting the ring
	local thorns = {}
	for i = 1, 8 do
		thorns[i] = make("ImageLabel", {
			BackgroundTransparency = 1,
			Image = Assets:Texture("spike"),
			AnchorPoint = Vector2.new(0.5, 0.5),
			Size = UDim2.fromOffset(5, 15),
			Visible = false,
			ZIndex = -1,
			Parent = layer,
		})
	end

	-- Ritual: a turning summoning circle (its outer ring sits at r = 60.4 of 128px)
	local ritualCircle = sprite("px_ritual_circle", layer, -1)
	local RITUAL_RING = 60.4 / 128

	-- Fangs, Chains and Eyes draw from pools sized to the circumference
	local pools = { Fangs = {}, Chains = {}, Eyes = {}, Pupils = {} }
	local function pooled(list, i, name, zindex)
		local image = list[i]
		if not image then
			image = sprite(name, layer, zindex)
			list[i] = image
		end
		image.Visible = true
		return image
	end
	local function hideFrom(list, first)
		for i = first, #list do
			list[i].Visible = false
		end
	end

	local function drawFov(now, origin, radius, focus, locked)
		local show = Toggles.fov_show.Value
		local style = Flags.fov_style
		local color = Toggles.esp_theme.Value and Theme:Get("Accent") or Options.fov_color.Value
		local spin = now * Flags.fov_spin

		fov.Visible = show
		if show then
			fov.Position = UDim2.fromOffset(origin.X, origin.Y)
			fov.Size = UDim2.fromOffset(radius * 2, radius * 2)
			fov.BackgroundColor3 = color
			fov.BackgroundTransparency = Options.fov_color.Transparency
			fovStroke.Color = style == "Fangs" and rgb(110, 10, 30) or color
			fovStroke.Thickness = style == "Fangs" and 2 or 1.5
			fovStroke.Transparency = FOV_RING[style] or 1
			fovHaloStroke.Color = color
			fovHaloStroke.Transparency = FOV_HALO[style] and (0.8 + 0.08 * math.sin(now * 2)) or 1
		end

		for i, thorn in thorns do
			local visible = show and style == "Thorns"
			thorn.Visible = visible
			if visible then
				local angle = spin + (i - 1) * math.pi / 4
				local at = origin + Vector2.new(math.cos(angle), math.sin(angle)) * (radius + 7)
				thorn.Position = UDim2.fromOffset(at.X, at.Y)
				thorn.Rotation = math.deg(angle) + 90
				thorn.ImageColor3 = color
			end
		end

		-- the circle flares while the aimbot holds someone
		ritualCircle.Visible = show and style == "Ritual"
		if ritualCircle.Visible then
			local size = radius / RITUAL_RING
			ritualCircle.Position = UDim2.fromOffset(origin.X, origin.Y)
			ritualCircle.Size = UDim2.fromOffset(size, size)
			ritualCircle.Rotation = math.deg(spin) % 360
			ritualCircle.ImageTransparency = locked and 0.15 * math.sin(now * 9) ^ 2 or 0.45 + 0.08 * math.sin(now * 2)
		end

		-- a jaw: every fifth tooth is a canine, and it bites on lock
		local fangs = 0
		if show and style == "Fangs" then
			fangs = math.clamp(math.floor(2 * math.pi * radius / 18), 8, 56)
			local bite = locked and (0.5 + 0.5 * math.sin(now * 12)) or 0
			for i = 1, fangs do
				local fang = pooled(pools.Fangs, i, "px_fang", -1)
				local angle = spin + (i - 1) * 2 * math.pi / fangs
				local k = i % 5 == 1 and 2 or 1
				local length = 14 * k
				local at = origin + Vector2.new(math.cos(angle), math.sin(angle)) * (radius - length * 0.3 - bite * 6)
				fang.Position = UDim2.fromOffset(at.X, at.Y)
				fang.Size = UDim2.fromOffset(8 * k, length)
				fang.Rotation = math.deg(angle) + 90 -- tip toward the centre
			end
		end
		hideFrom(pools.Fangs, fangs + 1)

		-- iron links, counter-rotating; they rattle on lock
		local links = 0
		if show and style == "Chains" then
			local k = radius >= 260 and 2 or 1
			links = math.clamp(math.floor(2 * math.pi * radius / (16 * k)), 8, 120)
			local length = 2 * math.pi * radius / links
			for i = 1, links do
				local link = pooled(pools.Chains, i, "px_chain_h", -1)
				local angle = -spin + (i - 0.5) * 2 * math.pi / links
				local rattle = locked and math.sin(now * 31 + i * 1.7) * 1.5 or 0
				local at = origin + Vector2.new(math.cos(angle), math.sin(angle)) * (radius + rattle)
				link.Position = UDim2.fromOffset(at.X, at.Y)
				link.Size = UDim2.fromOffset(length + 0.6, 8 * k)
				link.Rotation = math.deg(angle) + 90
			end
		end
		hideFrom(pools.Chains, links + 1)

		-- a ring of eyes that all watch your target (or you, when there's none)
		local eyes = 0
		if show and style == "Eyes" then
			local k = radius >= 90 and 2 or 1
			eyes = math.clamp(math.floor(2 * math.pi * radius / (34 * k)), 5, 16)
			for i = 1, eyes do
				local eye = pooled(pools.Eyes, i, "px_eye", -1)
				local pupil = pooled(pools.Pupils, i, "px_pupil", 0)
				local angle = spin + (i - 1) * 2 * math.pi / eyes
				local at = origin + Vector2.new(math.cos(angle), math.sin(angle)) * radius
				local blink = (now * 0.23 + hash(i * 3.1)) % 1
				local open = blink < 0.035 and math.abs(blink / 0.035 * 2 - 1) or 1
				eye.Position = UDim2.fromOffset(at.X, at.Y)
				eye.Size = UDim2.fromOffset(16 * k, 16 * k * math.max(open, 0.12))
				pupil.Visible = open > 0.6
				if pupil.Visible then
					local look = gaze(at, focus, 2.4 * k)
					local size = 8 * k * (locked and 1.2 or 1)
					pupil.Position = UDim2.fromOffset(look.X, look.Y)
					pupil.Size = UDim2.fromOffset(size, size)
				end
			end
		end
		hideFrom(pools.Eyes, eyes + 1)
		hideFrom(pools.Pupils, eyes + 1)
	end

	-- crosshair: the icon set, or the pixel pentagram ----------------------------

	local crosshair = make("ImageLabel", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0.5), Visible = false, ZIndex = 10, Parent = layer })
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

	local function drawCrosshair(now, origin, locked)
		crosshair.Visible = Toggles.cross_show.Value
		if not crosshair.Visible then
			return
		end
		local pentagram = Flags.cross_style == "pentagram"
		if crossStyle ~= Flags.cross_style then
			crossStyle = Flags.cross_style
			if pentagram then
				crosshair.Image = Assets:Texture("px_pentagram")
				crosshair.ImageRectOffset = Vector2.zero
				crosshair.ImageRectSize = Vector2.zero
				crosshair.ResampleMode = Enum.ResamplerMode.Pixelated
			else
				Assets:ApplyIcon(crosshair, crossStyle)
				crosshair.ResampleMode = Enum.ResamplerMode.Default
			end
		end
		local size = Flags.cross_size
		local color = Toggles.esp_theme.Value and Theme:Get("Text") or Options.cross_color.Value
		if pentagram then
			-- whole multiples of the 31px sprite keep every pixel square
			size = 31 * math.max(1, math.floor(size / 31 + 0.5))
			color = Toggles.esp_theme.Value and WHITE or Options.cross_color.Value
		end
		local pulse = locked and (0.5 + 0.5 * math.sin(now * 10)) or 0
		crosshair.Position = UDim2.fromOffset(origin.X, origin.Y)
		crosshair.Size = UDim2.fromOffset(size, size)
		crosshair.Rotation = (now * Flags.cross_spin * 90) % 360
		crosshair.ImageColor3 = color
		crosshairBloom.ImageColor3 = pentagram and BLOOD or Theme:Get("Accent")
		crosshairBloom.ImageTransparency = 0.75 - 0.3 * pulse
	end

	-- target HUD -----------------------------------------------------------------

	-- a tiled pixel health bar; returns the bar and a setter for the fill
	local function pixelBar(parent, position, size, k)
		local back = tiled("px_bar_back", parent, 2)
		back.Position = position
		back.Size = size
		back.TileSize = UDim2.fromOffset(4 * k, 6 * k)
		back.Visible = true
		local clip = make("Frame", { BackgroundTransparency = 1, ClipsDescendants = true, Size = UDim2.fromScale(1, 1), ZIndex = 3, Parent = back })
		local fill = tiled("px_bar_fill", clip, 3)
		fill.TileSize = back.TileSize
		fill.Visible = true
		return back, function(fraction)
			fraction = math.max(fraction, 0.001)
			clip.Size = UDim2.fromScale(fraction, 1)
			fill.Size = UDim2.fromScale(1 / fraction, 1) -- stays bar-wide so the tiles don't slide
		end
	end

	-- Card: themed with Theme:Bind so it recolours on its own
	local card = make("Frame", { AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(236, 58), Visible = false, ZIndex = 10, Parent = layer })
	Theme:Bind(card, { BackgroundColor3 = "Panel" })
	make("UICorner", { CornerRadius = UDim.new(0, 2), Parent = card })
	Theme:Bind(stroke(card, 1, Color3.new()), { Color = "Border" })
	local cardGlow = Hellspawn:AttachGlow(card, { Spread = 18, Strength = 0.18, Wide = true })
	local cardCrown = make("Frame", { BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.new(1, 0, 0, 2), Parent = card })
	Theme:Bind(make("UIGradient", { Parent = cardCrown }), { Color = "AccentGradient" })
	Hellspawn:AttachGlow(cardCrown, { Spread = 8, Strength = 0.5 })
	local cardAvatar = make("ImageLabel", {
		BorderSizePixel = 0,
		Position = UDim2.fromOffset(10, 12),
		Size = UDim2.fromOffset(34, 34),
		Parent = card,
	})
	Theme:Bind(cardAvatar, { BackgroundColor3 = "Surface" })
	make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = cardAvatar })
	Theme:Bind(stroke(cardAvatar, 1, Color3.new()), { Color = "Accent" })
	local cardName = make("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = fontBold,
		TextSize = 13,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(54, 9),
		Size = UDim2.new(1, -64, 0, 16),
		Parent = card,
	})
	Theme:Bind(cardName, { TextColor3 = "Text" })
	local cardInfo = make("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = fontBody,
		TextSize = 10,
		RichText = true,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(54, 25),
		Size = UDim2.new(1, -64, 0, 12),
		Parent = card,
	})
	Theme:Bind(cardInfo, { TextColor3 = "TextDim" })
	local cardBar = make("Frame", { BorderSizePixel = 0, Position = UDim2.new(0, 54, 0, 42), Size = UDim2.new(1, -64, 0, 4), Parent = card })
	Theme:Bind(cardBar, { BackgroundColor3 = "Surface" })
	local cardFill = make("Frame", { BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), Parent = cardBar })
	Theme:Bind(make("UIGradient", { Parent = cardFill }), { Color = "AccentGradient" })
	Hellspawn:AttachGlow(cardFill, { Spread = 6, Strength = 0.45 })

	-- Tombstone: a 9-sliced pixel headstone with engraved lettering
	local ENGRAVE, ENGRAVE_LIGHT = rgb(28, 29, 33), rgb(150, 152, 158)
	local tomb = sprite("px_tombstone", layer, 10, Vector2.new(0.5, 0))
	tomb.ScaleType = Enum.ScaleType.Slice
	tomb.SliceCenter = Rect.new(7, 15, 25, 28)
	tomb.SliceScale = 2
	tomb.Size = UDim2.fromOffset(204, 116)
	local tombSkull = sprite("px_skull", tomb, 2, Vector2.new(0.5, 0))
	tombSkull.Position = UDim2.new(0.5, 0, 0, 9)
	tombSkull.Size = UDim2.fromOffset(16, 16)
	tombSkull.Visible = true
	local function engraved(size, y, inset)
		return make("TextLabel", {
			BackgroundTransparency = 1,
			FontFace = fontPixel,
			TextSize = size,
			TextColor3 = ENGRAVE,
			TextStrokeColor3 = ENGRAVE_LIGHT,
			TextStrokeTransparency = 0.72,
			TextTruncate = Enum.TextTruncate.AtEnd,
			Position = UDim2.fromOffset(inset, y),
			Size = UDim2.new(1, -inset * 2, 0, size),
			ZIndex = 2,
			Parent = tomb,
		})
	end
	local tombHeader = engraved(10, 30, 16)
	local tombName = engraved(16, 42, 18)
	local tombInfo = engraved(11, 61, 18)
	local _, tombHealth = pixelBar(tomb, UDim2.fromOffset(22, 80), UDim2.new(1, -44, 0, 12), 2)

	-- Scroll: parchment with a blackletter name and a wax seal
	local INK, INK_FADED = rgb(58, 30, 12), rgb(112, 74, 36)
	local scroll = sprite("px_scroll", layer, 10, Vector2.new(0.5, 0))
	scroll.ScaleType = Enum.ScaleType.Slice
	scroll.SliceCenter = Rect.new(10, 5, 38, 19)
	scroll.SliceScale = 2
	scroll.Size = UDim2.fromOffset(268, 84)
	local scrollName = make("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = fontGothic,
		TextSize = 24,
		TextColor3 = INK,
		TextXAlignment = Enum.TextXAlignment.Left,
		TextTruncate = Enum.TextTruncate.AtEnd,
		Position = UDim2.fromOffset(26, 11),
		Size = UDim2.new(1, -96, 0, 26),
		ZIndex = 2,
		Parent = scroll,
	})
	local scrollInfo = make("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = fontPixel,
		TextSize = 11,
		TextColor3 = INK_FADED,
		TextXAlignment = Enum.TextXAlignment.Left,
		Position = UDim2.fromOffset(28, 40),
		Size = UDim2.new(1, -96, 0, 12),
		ZIndex = 2,
		Parent = scroll,
	})
	local _, scrollHealth = pixelBar(scroll, UDim2.fromOffset(28, 57), UDim2.new(1, -100, 0, 6), 1)
	local seal = make("Frame", {
		BorderSizePixel = 0,
		BackgroundColor3 = rgb(92, 6, 18),
		AnchorPoint = Vector2.new(0.5, 0.5),
		Position = UDim2.new(1, -44, 0.5, 0),
		Size = UDim2.fromOffset(36, 36),
		ZIndex = 2,
		Parent = scroll,
	})
	make("UICorner", { CornerRadius = UDim.new(0.5, 0), Parent = seal })
	stroke(seal, 2, rgb(52, 2, 10))
	local sealGlow = neon(seal, 14, 0.85) -- native UIShadow neon under the wax
	if sealGlow then
		sealGlow.Color = BLOOD
	end
	local sealMark = sprite("px_pentagram", seal, 3)
	sealMark.Position = UDim2.fromScale(0.5, 0.5)
	sealMark.Size = UDim2.fromOffset(31, 31)
	sealMark.Visible = true

	-- Minimal: a name over a thin neon bar
	local minimal = make("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(240, 36), Visible = false, ZIndex = 10, Parent = layer })
	local minimalName = make("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = fontBold,
		TextSize = 13,
		TextStrokeTransparency = 0.4,
		Size = UDim2.new(1, 0, 0, 16),
		Parent = minimal,
	})
	Theme:Bind(minimalName, { TextColor3 = "Text" })
	local minimalBar = make("Frame", { BorderSizePixel = 0, AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 19), Size = UDim2.fromOffset(120, 2), Parent = minimal })
	Theme:Bind(minimalBar, { BackgroundColor3 = "Surface" })
	local minimalFill = make("Frame", { BorderSizePixel = 0, BackgroundColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(1, 1), Parent = minimalBar })
	Theme:Bind(make("UIGradient", { Parent = minimalFill }), { Color = "AccentGradient" })
	Hellspawn:AttachGlow(minimalFill, { Spread = 6, Strength = 0.6 })
	local minimalInfo = make("TextLabel", {
		BackgroundTransparency = 1,
		FontFace = fontBody,
		TextSize = 10,
		TextStrokeTransparency = 0.5,
		Position = UDim2.fromOffset(0, 24),
		Size = UDim2.new(1, 0, 0, 12),
		Parent = minimal,
	})
	Theme:Bind(minimalInfo, { TextColor3 = "TextDim" })

	local hudPlayer, hudSince = nil, 0

	local function drawHud(now, origin, target, locked)
		local character, humanoid, rootPart = getCharacter(target)
		local style = Flags.hud_style
		local show = Toggles.hud_show.Value and character ~= nil
		card.Visible = show and style == "Card"
		tomb.Visible = show and style == "Tombstone"
		scroll.Visible = show and style == "Scroll"
		minimal.Visible = show and style == "Minimal"
		if not show then
			hudPlayer = nil
			return
		end
		if hudPlayer ~= target then
			hudPlayer = target
			hudSince = now
			cardAvatar.Image = string.format("rbxthumb://type=AvatarHeadShot&id=%d&w=150&h=150", target.UserId)
			cardGlow:Flash(0.7, 0.6)
		end
		local fraction = math.clamp(humanoid.Health / math.max(humanoid.MaxHealth, 1), 0, 1)
		local distance = math.floor((rootPart.Position - camera().CFrame.Position).Magnitude + 0.5)
		local health = math.floor(humanoid.Health + 0.5)
		-- every new target rises into place
		local rise = 14 * (1 - easeOut((now - hudSince) / 0.3))
		local position = UDim2.fromOffset(origin.X, origin.Y + Flags.hud_offset + rise)

		if style == "Card" then
			card.Position = position
			cardName.Text = target.DisplayName .. (locked and "  ·  locked" or "")
			cardInfo.Text = string.format("%d / %d hp  ·  %dm  ·  @%s", health, math.floor(humanoid.MaxHealth + 0.5), distance, target.Name)
			cardFill.Size = UDim2.fromScale(fraction, 1)
		elseif style == "Tombstone" then
			tomb.Position = position
			tombHeader.Text = locked and "marked for death" or "here lies"
			tombName.Text = string.lower(target.DisplayName)
			tombName.TextColor3 = locked and rgb(150, 8, 24) or ENGRAVE
			tombInfo.Text = string.format("%d hp   %dm", health, distance)
			tombHealth(fraction)
		elseif style == "Scroll" then
			scroll.Position = position
			scrollName.Text = target.DisplayName
			scrollInfo.Text = string.format("%d hp   %dm", health, distance)
			scrollHealth(fraction)
			if sealGlow then
				sealGlow.Transparency = locked and (0.25 + 0.3 * math.sin(now * 8) ^ 2) or 0.85
			end
			sealMark.Rotation = locked and math.sin(now * 3) * 8 or 0
		else
			minimal.Position = position
			minimalName.Text = target.DisplayName .. (locked and "  ·  locked" or "")
			minimalInfo.Text = string.format("%d hp  ·  %dm", health, distance)
			minimalFill.Size = UDim2.fromScale(fraction, 1)
		end
	end

	function updateOverlays(now)
		local origin = aimOrigin()
		local radius = Flags.aim_fov

		-- the aimbot's lock, else the closest valid player inside the FOV
		local target = lockedTarget
		if not target then
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
		local locked = target ~= nil and target == lockedTarget

		-- what the FOV eyes stare at: the target's head, or you
		local focus = origin
		local character = getCharacter(target)
		if character then
			local head = character:FindFirstChild("Head") or character:FindFirstChild("HumanoidRootPart")
			local point, visible = toScreen(head.Position)
			if visible then
				focus = point
			end
		end

		drawFov(now, origin, radius, focus, locked)
		drawCrosshair(now, origin, locked)
		drawHud(now, origin, target, locked)
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
