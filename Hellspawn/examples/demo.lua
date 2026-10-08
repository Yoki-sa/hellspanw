--[[
	Hellspawn — full showcase
	Paste into your executor. Every control is wired to flags only; hook your
	own features where the comments say so.
]]

local Hellspawn = loadstring(game:HttpGet("https://raw.githubusercontent.com/YOUR_NAME/Hellspawn/main/dist/Hellspawn.lua"))()

local Window = Hellspawn:CreateWindow({
	Title = "Hellspawn",
	Subtitle = "// narcissist build · " .. os.date("%d.%m.%y"),
	Theme = "Hellspawn", -- Hellspawn · Rabbit · Narcissist · Thorns · Venom · Abyss · Reliquary
	ToggleKey = Enum.KeyCode.RightShift,
	Width = 740,
	Height = 520,
})

local Combat = Window:AddTab({ Name = "Combat", Icon = "crosshair", Description = "// aim assistance & triggers" })
local Visuals = Window:AddTab({ Name = "Visuals", Icon = "eye", Description = "// see what hides behind the walls" })
local Movement = Window:AddTab({ Name = "Movement", Icon = "bolt", Description = "// bend the rules of the body" })
local Misc = Window:AddTab({ Name = "Misc", Icon = "spider", Description = "// odds, ends and other horrors" })

----------------------------------------------------------------------
-- Combat
----------------------------------------------------------------------
local Aim = Combat:AddLeftGroupbox("Aimbot")
local aimToggle = Aim:AddToggle("aim_enabled", { Text = "Enabled", Tooltip = "Locks onto the closest valid target." })
aimToggle:AddKeybind("aim_key", { Default = "MB2", Mode = "Hold", Text = "Aimbot" })
Aim:AddSlider("aim_fov", { Text = "Field of view", Min = 10, Max = 360, Default = 120, Suffix = "°" })
Aim:AddSlider("aim_smooth", { Text = "Smoothing", Min = 0, Max = 1, Increment = 0.01, Default = 0.35 })
Aim:AddDropdown("aim_part", { Text = "Hitbox", Values = { "Head", "UpperTorso", "HumanoidRootPart" }, Default = "Head" })
Aim:AddDropdown("aim_checks", {
	Text = "Checks",
	Values = { "Team", "Wall", "Alive", "Forcefield" },
	Multi = true,
	Default = { "Team", "Alive" },
})
Aim:AddToggle("aim_fov_circle", { Text = "Draw FOV circle" })
	:AddColorPicker("aim_fov_color", { Default = Color3.fromRGB(226, 22, 60), Transparency = 0.2 })

local Trigger = Combat:AddRightGroupbox("Triggerbot")
Trigger:AddToggle("trigger", { Text = "Enabled", Risky = true })
	:AddKeybind("trigger_key", { Default = Enum.KeyCode.T, Text = "Triggerbot" })
Trigger:AddSlider("trigger_delay", { Text = "Delay", Min = 0, Max = 500, Default = 80, Suffix = "ms" })
Trigger:AddInput("trigger_target", { Text = "Priority target", Placeholder = "username", Finished = true })
Trigger:AddDivider({ Text = "silent" })
Trigger:AddToggle("silent", { Text = "Silent aim" })
Trigger:AddSlider("silent_chance", { Text = "Hit chance", Min = 0, Max = 100, Default = 100, Suffix = "%" })

local Mods = Combat:AddRightTabbox()
local Gun = Mods:AddTab("Gun")
Gun:AddToggle("no_recoil", { Text = "No recoil" })
Gun:AddToggle("no_spread", { Text = "No spread" })
Gun:AddSlider("fire_rate", { Text = "Fire rate", Min = 1, Max = 10, Default = 1, Increment = 0.5, Suffix = "x" })
local Melee = Mods:AddTab("Melee")
Melee:AddToggle("reach", { Text = "Reach" })
Melee:AddSlider("reach_distance", { Text = "Distance", Min = 1, Max = 25, Default = 8, Suffix = " studs" })

----------------------------------------------------------------------
-- Visuals
----------------------------------------------------------------------
local Esp = Visuals:AddLeftGroupbox("Players", { Icon = "user" })
Esp:AddToggle("esp_box", { Text = "Boxes", Default = true })
	:AddColorPicker("esp_box_color", { Default = Color3.fromRGB(240, 236, 228) })
-- only shown while "Boxes" is enabled
local BoxStyle = Esp:AddDependencyBox()
BoxStyle:AddDropdown("esp_box_style", { Text = "Box style", Values = { "Full", "Corner", "3D" }, Default = "Corner" })
BoxStyle:AddSlider("esp_box_thickness", { Text = "Thickness", Min = 1, Max = 4, Default = 1, Suffix = "px", Compact = true })
BoxStyle:SetupDependencies({ { Hellspawn.Toggles.esp_box, true } })
Esp:AddToggle("esp_name", { Text = "Names" })
Esp:AddToggle("esp_health", { Text = "Health bar" })
Esp:AddToggle("esp_tracer", { Text = "Tracers" })
	:AddColorPicker("esp_tracer_color", { Default = Color3.fromRGB(226, 22, 60) })
Esp:AddDropdown("esp_tracer_origin", { Text = "Tracer origin", Values = { "Bottom", "Center", "Mouse" }, Default = 1 })
Esp:AddSlider("esp_distance", { Text = "Max distance", Min = 50, Max = 5000, Default = 1500, Suffix = " studs" })

local Chams = Visuals:AddRightGroupbox("Chams", { Icon = "drop" })
Chams:AddToggle("chams", { Text = "Enabled" })
Chams:AddLabel("Fill"):AddColorPicker("chams_fill", { Default = Color3.fromRGB(176, 150, 255), Transparency = 0.5 })
Chams:AddLabel("Outline"):AddColorPicker("chams_outline", { Default = Color3.fromRGB(255, 255, 255) })
Chams:AddParagraph({
	Title = "note",
	Content = "Chams use Highlight instances, which the engine caps at <b>31</b> at once.",
})

local World = Visuals:AddRightGroupbox("World", { Icon = "moon" })
World:AddToggle("fullbright", { Text = "Fullbright" })
World:AddSlider("clock_time", { Text = "Clock time", Min = 0, Max = 24, Default = 0, Increment = 0.5, Suffix = "h" })
World:AddColorPicker("ambient", { Text = "Ambient", Default = Color3.fromRGB(20, 0, 8) })

----------------------------------------------------------------------
-- Movement
----------------------------------------------------------------------
local Body = Movement:AddLeftGroupbox("Body")
Body:AddSlider("walk_speed", { Text = "Walk speed", Min = 16, Max = 200, Default = 16 })
Body:AddSlider("jump_power", { Text = "Jump power", Min = 50, Max = 300, Default = 50 })
Body:AddToggle("infinite_jump", { Text = "Infinite jump" })
Body:AddToggle("noclip", { Text = "Noclip", Risky = true }):AddKeybind("noclip_key", { Default = Enum.KeyCode.N, Text = "Noclip" })

local Fly = Movement:AddRightGroupbox("Flight", { Icon = "flame" })
Fly:AddToggle("fly", { Text = "Fly" }):AddKeybind("fly_key", { Default = Enum.KeyCode.F, Text = "Fly" })
Fly:AddSlider("fly_speed", { Text = "Speed", Min = 1, Max = 250, Default = 60, Compact = true })
Fly:AddDropdown("fly_mode", { Text = "Mode", Values = { "Velocity", "CFrame", "BodyMover" }, Default = "Velocity" })

----------------------------------------------------------------------
-- Misc
----------------------------------------------------------------------
local People = Misc:AddLeftGroupbox("Players")
People:AddDropdown("target_player", { Text = "Target", SpecialType = "Player", AllowNull = true, Placeholder = "nobody" })
People:AddButton({
	Text = "Spectate",
	Callback = function()
		Hellspawn:Notify({ Title = "Spectate", Content = tostring(Hellspawn.Flags.target_player or "nobody selected") })
	end,
}):AddButton({
	Text = "Copy name",
	Callback = function()
		if setclipboard and Hellspawn.Flags.target_player then
			setclipboard(Hellspawn.Flags.target_player)
		end
	end,
})
local status = People:AddLabel("status: <font color=\"#8d8a92\">idle</font>")

local Sigil = Misc:AddLeftGroupbox("Sigil", { Icon = "eye" })
Sigil:AddImage({ Image = "logoLarge", Height = 110, Color = "Text", Caption = "it sees you too" })

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
Whispers:AddButton({
	Text = "Rejoin server",
	DoubleClick = true,
	Risky = true,
	Tooltip = "Click twice: teleports you back into this place.",
	Callback = function()
		game:GetService("TeleportService"):Teleport(game.PlaceId, game:GetService("Players").LocalPlayer)
	end,
})

----------------------------------------------------------------------
-- reacting to values
----------------------------------------------------------------------
Hellspawn.Options.aim_fov:OnChanged(function(value)
	status:SetText(string.format("status: fov set to <b>%d°</b>", value))
end)

Hellspawn.Options.aim_key.StateChanged:Connect(function(active)
	-- Hold mode: true while MB2 is held (and syncs the "Enabled" toggle)
end)

-- Read anywhere:
--   Hellspawn.Flags.aim_fov              -> number
--   Hellspawn.Toggles.esp_box.Value      -> boolean
--   Hellspawn.Options.aim_key:GetState() -> boolean
--   Hellspawn.Options.esp_box_color.Value / .Transparency

----------------------------------------------------------------------
-- settings tab, autoload, greeting
----------------------------------------------------------------------
Window:AddSettingsTab()
Hellspawn.Config:LoadAutoload()

Hellspawn:Notify({
	Title = "Hellspawn",
	Content = "Loaded. Press <b>" .. "RShift" .. "</b> to hide the menu.",
	Type = "success",
	Duration = 5,
})

Hellspawn:OnUnload(function()
	-- disconnect your own features here
end)
