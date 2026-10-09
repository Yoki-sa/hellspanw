--[[
	Settings
	Builds a ready-made settings tab: theme + accent, scale, menu key, HUD
	toggles, every visual effect, the config manager and an unload button.

		window:AddSettingsTab()
]]

local Env = import("core/Env")
local Util = import("core/Util")

local Settings = {}

local EFFECTS = {
	{ "Animations", "Animations", "Tweens, springs, decode text and the CRT power-on." },
	{ "Glow", "Neon glow", "UIShadow neon behind every accent." },
	{ "Embers", "Embers", "Sparks drifting up behind the content." },
	{ "Grain", "Film grain", "Animated noise over the whole window." },
	{ "Scratches", "Scratches", "Celluloid dust and hairline scratches." },
	{ "Scanlines", "Scanlines", "Faint CRT raster lines." },
	{ "Vignette", "Vignette", "Darkened window corners." },
	{ "Glitch", "Glitch title", "Chromatic aberration and tearing on the title." },
	{ "SmoothDrag", "Smooth drag", "Spring-smoothed window dragging." },
}

function Settings.build(window, opts)
	opts = opts or {}
	local library = window.Library
	local theme = library.Theme
	local config = library.Config
	local syncing = false

	local tab = window:AddTab({
		Name = opts.Name or "Settings",
		Icon = opts.Icon or "gear",
		Description = opts.Description or "// interface, effects & configs",
	})

	------------------------------------------------------------------
	-- interface
	------------------------------------------------------------------
	local ui = tab:AddLeftGroupbox("Interface", { Icon = "drop" })

	local themeDropdown = ui:AddDropdown("hs_theme", {
		Text = "Theme",
		Values = theme.Order,
		Default = theme.Name,
		NoSave = true,
		Tooltip = "Palettes re-tint the whole interface live.",
		Callback = function(name)
			if syncing then
				return
			end
			theme.Overrides.Accent = nil
			library:SetTheme(name)
		end,
	})

	local accentPicker = ui:AddLabel("Accent colour"):AddColorPicker("hs_accent", {
		Default = theme:Get("Accent"),
		NoSave = true,
		Callback = function(color)
			if syncing then
				return
			end
			theme:SetOverride("Accent", color)
		end,
	})

	ui:AddButton({
		Text = "Reset colours",
		Callback = function()
			theme:ClearOverrides()
		end,
	})

	ui:AddSlider("hs_scale", {
		Text = "Interface scale",
		Min = 70,
		Max = 150,
		Increment = 5,
		Default = math.floor(library.Scale * 100 + 0.5),
		Suffix = "%",
		Callback = function(value)
			library:SetScale(value / 100)
		end,
	})

	ui:AddLabel("Menu key"):AddKeybind("hs_menu_key", {
		Default = window.ToggleKey,
		NoUI = true,
		ChangedCallback = function(key)
			if key then
				window:SetToggleKey(key)
			end
		end,
	})

	ui:AddDivider()

	ui:AddToggle("hs_watermark", {
		Text = "Watermark",
		Default = false,
		Callback = function(value)
			library:SetWatermarkVisible(value)
		end,
	})
	ui:AddToggle("hs_keybind_list", {
		Text = "Keybind list",
		Default = false,
		Callback = function(value)
			library:SetKeybindListVisible(value)
		end,
	})
	ui:AddToggle("hs_tooltips", {
		Text = "Tooltips",
		Default = library.Settings.Tooltips,
		Callback = function(value)
			library:SetSetting("Tooltips", value)
		end,
	})
	ui:AddToggle("hs_cursor", {
		Text = "Custom cursor",
		Default = library.Settings.Cursor,
		Tooltip = "Draws a themed pointer over the menu (useful in first-person games).",
		Callback = function(value)
			library:SetSetting("Cursor", value)
		end,
	})
	ui:AddToggle("hs_unlock", {
		Text = "Free mouse while open",
		Default = library.Settings.UnlockMouse,
		Callback = function(value)
			library:SetSetting("UnlockMouse", value)
		end,
	})

	------------------------------------------------------------------
	-- effects
	------------------------------------------------------------------
	local fx = tab:AddRightGroupbox("Effects", { Icon = "flame" })
	for _, entry in EFFECTS do
		local key, label, tip = entry[1], entry[2], entry[3]
		fx:AddToggle("hs_fx_" .. string.lower(key), {
			Text = label,
			Default = library.Settings[key],
			Tooltip = tip,
			Callback = function(value)
				library:SetSetting(key, value)
			end,
		})
	end
	fx:AddSlider("hs_glow_intensity", {
		Text = "Glow intensity",
		Min = 0,
		Max = 150,
		Increment = 5,
		Default = math.floor(library.Settings.GlowIntensity * 100 + 0.5),
		Suffix = "%",
		Callback = function(value)
			library:SetSetting("GlowIntensity", value / 100)
		end,
	})

	------------------------------------------------------------------
	-- configs
	------------------------------------------------------------------
	local cfg = tab:AddLeftGroupbox("Configs", { Icon = "save" })
	local nameBox = cfg:AddInput("hs_config_name", { Text = "Config name", Placeholder = "name..." })
	local list = cfg:AddDropdown("hs_config_list", {
		Text = "Saved",
		Values = config:List(),
		AllowNull = true,
		Placeholder = "no configs",
	})
	local autoload = cfg:AddLabel("")
	config:SetIgnore({ "hs_config_name", "hs_config_list" })

	local function refresh()
		list:SetValues(config:List())
		local current = config:GetAutoload()
		autoload:SetText(current and ("autoload: <b>" .. Util.escape(current) .. "</b>") or "autoload: none")
	end

	local function report(ok, err, success)
		if ok then
			library:Notify({ Title = "Config", Content = success, Type = "success", Duration = 2.5 })
		else
			library:Notify({ Title = "Config", Content = tostring(err), Type = "error", Duration = 3.5 })
		end
	end

	cfg:AddButton({
		Text = "Save",
		Callback = function()
			local name = Util.trim(nameBox.Value)
			local ok, err = config:Save(name)
			report(ok, err, "saved <b>" .. Util.escape(name) .. "</b>")
			refresh()
		end,
	}):AddButton({
		Text = "Load",
		Callback = function()
			local name = list.Value
			local ok, err = config:Load(name)
			report(ok, err, "loaded <b>" .. Util.escape(tostring(name)) .. "</b>")
		end,
	})
	cfg:AddButton({
		Text = "Overwrite",
		DoubleClick = true,
		Callback = function()
			local name = list.Value
			local ok, err = config:Save(name)
			report(ok, err, "overwrote <b>" .. Util.escape(tostring(name)) .. "</b>")
		end,
	}):AddButton({
		Text = "Delete",
		DoubleClick = true,
		Risky = true,
		Callback = function()
			local name = list.Value
			local ok, err = config:Delete(name)
			report(ok, err, "deleted <b>" .. Util.escape(tostring(name)) .. "</b>")
			refresh()
		end,
	})
	cfg:AddButton({
		Text = "Refresh",
		Callback = refresh,
	}):AddButton({
		Text = "Autoload",
		Tooltip = "Load the selected config automatically next time.",
		Callback = function()
			local ok = config:SetAutoload(list.Value or "")
			report(ok, "could not write autoload", list.Value and ("autoload set to <b>" .. Util.escape(list.Value) .. "</b>") or "autoload cleared")
			refresh()
		end,
	})
	refresh()

	------------------------------------------------------------------
	-- about
	------------------------------------------------------------------
	local about = tab:AddRightGroupbox("Hellspawn", { Icon = "eye" })
	about:AddParagraph({
		Title = "v" .. library.Version,
		Content = string.format(
			"executor: %s\nfiles: %s · custom assets: %s\ntextures are forged locally and cached in <i>%s/cache</i>.",
			Util.escape(library.Executor),
			Env.canFiles and "yes" or "no",
			Env.canAssets and "yes" or "no",
			Util.escape(library.Folder)
		),
	})
	about:AddButton({
		Text = "Clear asset cache",
		DoubleClick = true,
		Tooltip = "Deletes cached textures/fonts; they are rebuilt on the next run.",
		Callback = function()
			local removed = library.Assets:ClearCache()
			library:Notify({ Title = "Cache", Content = removed .. " files removed. Re-run the script to rebuild.", Duration = 3 })
		end,
	})
	about:AddButton({
		Text = "Unload",
		DoubleClick = true,
		Risky = true,
		Callback = function()
			library:Unload()
		end,
	})

	-- keep theme controls truthful when the palette changes elsewhere (configs, API)
	local connection = theme.Changed:Connect(function()
		syncing = true
		if #themeDropdown.Values ~= #theme.Order then
			themeDropdown:SetValues(theme.Order)
		end
		if themeDropdown.Value ~= theme.Name then
			themeDropdown:SetValue(theme.Name)
		end
		-- skip when the picker itself caused the change (keeps its hue stable)
		if accentPicker.Value ~= theme:Get("Accent") then
			accentPicker:SetValue(theme:Get("Accent"))
		end
		syncing = false
	end)
	library.Maid:Give(connection)

	return tab
end

return Settings
