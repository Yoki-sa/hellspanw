# H E L L S P A W N

An ImGui-styled interface library for Roblox executors: dark, gritty, and built almost entirely from scratch.

Every texture is **painted at runtime** by a built-in software rasteriser (signed-distance shapes encoded to PNG by a pure-Luau encoder), cached to your workspace folder and loaded through `getcustomasset`. Nothing is uploaded to Roblox, so nothing can be moderated. Fonts (UnifrakturMaguntia, Pirata One, JetBrains Mono, all SIL OFL) are fetched once from their open-source repos and turned into Roblox font families on the fly.

```
 ✦ thorn-eye sigil      chromatic glitch title        [search...]   – ×
┌────────────┬────────────────────────────────────────────────────────┐
│  MODULES   │  Combat                                         ⌖      │
│ ▌⌖ Combat  │  // aim assistance & triggers ~~~thorn vine~~~         │
│  ◎ Visuals │  ┌ ✦ AIMBOT ───────────┐  ┌ ✦ TRIGGERBOT ───────┐       │
│  ϟ Movement│  │ [■] Enabled   [RMB] │  │ [■] Enabled     [T] │       │
│  ✱ Misc    │  │ Field of view  120° │  │ Delay          80ms │       │
│  ⚙ Settings│  │ ━━━━━━━●─────────── │  │ ━━●──────────────── │       │
│            │  └─────────────────────┘  └─────────────────────┘       │
│ ◍ Tester   │                                                        │
├────────────┴────────────────────────────────────────────────────────┤
│ ✦ hellspawn v1.0.0 · executor · RShift to hide   fps 144 · 32ms · … │
└─────────────────────────────────────────────────────────────────────┘
```

## Features

**Controls:** toggle · slider (drag, double-click to type, compact mode) · button (ripple, two-step confirm, side-by-side rows) · dropdown (single/multi, auto search, live player/team lists) · colour picker (HSV square, hue + alpha rails, hex, rainbow, copy/paste) · keybind (toggle/hold/always, mouse buttons, inline on toggles) · text input (numeric, finished-only) · label · paragraph · divider · image · groupbox (collapsible) · tabbox · dependency box

**Effects:**
- **CRT power-on/off** when the window opens or closes: a hot line stretches across, then the picture unfolds.
- **Neon glows built on Roblox's native `UIShadow`.** Each accent element gets a hot core plus a wide bloom that follows its corners. The window's soft drop shadow is a blurred `UIShadow` too, and one intensity setting dims every glow. Clients without `UIShadow` fall back to generated glow images.
- **Animated film grain**, celluloid scratches (off by default), vignette, scanlines and a halftone print strip.
- **Chromatic-aberration title** that tears and corrupts glyphs every few seconds.
- **Embers** drifting up behind the content.
- **Dry-brush blood smear** behind the active tab, plus a neon-tube flicker on its icon and a scan sweep across the page.
- **Decoding text** on headings, notifications and confirmations.
- **Spring physics** on dragging, the tab indicator, sliders and toasts.
- **Thorn spikes** fanning from the window corners, an eye logo that blinks, and a travelling glint on the accent rule.
- **Custom cursor** with an ember trail while you're over the menu (handy in first-person games).
- **Boot screen**: the thorn eye opens while textures are forged.

**Systems:** 7 live-switchable themes plus custom themes and colour overrides · JSON configs with autoload · search across every tab, with hit counts in the sidebar · tooltips · watermark · keybind list · notifications · UI scale · mobile toggle button · clean unload (re-executing replaces the old instance)

**It never blocks the game:** dragging tracks `UserInputService` globally instead of covering the screen. Popups close on outside clicks without a fullscreen catcher, and while one is open nothing behind it reacts to presses or hover. Decorative layers are `Interactable = false`, keybinds ignore input while you're typing, and mouse binds don't fire while you're clicking the menu.

## Quick start

Host `dist/Hellspawn.lua` somewhere raw (a GitHub repo, a gist) and load it:

```lua
local Hellspawn = loadstring(game:HttpGet("https://raw.githubusercontent.com/YOU/Hellspawn/main/dist/Hellspawn.lua"))()

local Window = Hellspawn:CreateWindow({
	Title = "Hellspawn",
	Subtitle = "// my script",
	Theme = "Hellspawn",
	ToggleKey = Enum.KeyCode.RightShift,
})

local Combat = Window:AddTab({ Name = "Combat", Icon = "crosshair" })
local Aim = Combat:AddLeftGroupbox("Aimbot")

Aim:AddToggle("aim", { Text = "Enabled", Callback = function(on) print("aim", on) end })
	:AddKeybind("aim_key", { Default = "MB2", Mode = "Hold" })
Aim:AddSlider("fov", { Text = "FOV", Min = 10, Max = 360, Default = 120, Suffix = "°" })

Window:AddSettingsTab()           -- themes, effects, configs, unload
Hellspawn.Config:LoadAutoload()   -- call after building every control
```

You can also paste the whole of `dist/Hellspawn.lua` above your script instead of loading it. See [examples/demo.lua](examples/demo.lua) for a complete showcase.

## API

### Library

| member | description |
|---|---|
| `:CreateWindow(opts)` | Boots the library on the first call (intro, textures, fonts) and returns a Window. Yields. |
| `:Notify(opts \| text, duration?)` | `{ Title, Content, Duration = 4, Type = "info" \| "success" \| "warning" \| "error" \| "danger", Icon }` |
| `:SetTheme(name)` / `:SetAccent(color)` / `:RegisterTheme(name, palette)` | Theming (see below). |
| `:SetScale(n)` | Interface scale, `0.5` to `2`. |
| `:SetSetting(key, value)` | Toggles an effect or behaviour (see *Settings*). |
| `:SetWatermarkVisible(bool)` / `:SetWatermark(text?)` | HUD watermark; `nil` restores the live readout. |
| `:SetKeybindListVisible(bool)` | Floating list of bound keys. |
| `:Toggle()` | Shows or hides every window. |
| `:OnUnload(fn)` / `:Unload()` | Cleanup hook / tear everything down. |
| `.Flags[flag]` | Current value of every flagged control. |
| `.Options[flag]` / `.Toggles[flag]` | Control objects (Linoria-style). |
| `.Config` | Config manager (see *Configs*). |
| `.Theme` | Theme manager (`:Bind`, `:Get`, `:SetOverride`, `.Changed`). |
| `.Icons` | Names of every built-in icon. |

### Window

`CreateWindow` options: `Title`, `Subtitle`, `Width = 720`, `Height = 500`, `MinWidth`, `MinHeight`, `Position` (Vector2), `ToggleKey`, `Resizable = true`, `ShowUser = true`, `Theme`, `Accent`, `Scale`, `Folder = "Hellspawn"`, `Intro = true`, `CustomFonts = true`, `Settings = { ... }`, `Background` (icon / asset id / URL), `BackgroundTransparency = 0.92`, `Logo`.

| method | |
|---|---|
| `:AddTab({ Name, Icon, Description, Columns = 2 })` | also `:AddTab("Name", "icon")` |
| `:AddSettingsTab(opts?)` | prebuilt settings page |
| `:SelectTab(tab)` · `:SetVisible(bool)` · `:Toggle()` · `:SetMinimized(bool)` | |
| `:SetTitle(text)` · `:SetSubtitle(text)` · `:SetToggleKey(key)` · `:SetSize(Vector2)` · `:SetPosition(Vector2)` | |

### Tab

`:AddLeftGroupbox(name, opts?)`, `:AddRightGroupbox(name, opts?)`, `:AddGroupbox({ Name, Side, Icon, Collapsible, Collapsed })`, `:AddLeftTabbox()`, `:AddRightTabbox()`, `:Select()`.

Tabbox: `local tb = tab:AddRightTabbox(); local page = tb:AddTab("Chams")`. A page takes every `Add*` method below.

### Controls

Every container (groupbox, tabbox page, dependency box) has these. Flagged controls accept `("flag", opts)` or `({ Flag = "flag", ... })`. All controls support `Tooltip`, `Disabled`, `Visible`, `Callback`, and the methods `:SetValue`, `:OnChanged(fn)`, `:SetVisible`, `:SetDisabled`, `:SetTooltip`, `:Destroy`.

| method | options |
|---|---|
| `AddToggle(flag, o)` | `Text, Default, Risky` · returns a toggle with `:AddKeybind` / `:AddColorPicker` |
| `AddSlider(flag, o)` | `Text, Min, Max, Default, Rounding` (decimals) or `Increment, Prefix, Suffix, Compact, ShowMax, Format(fn)` · `:SetMin`, `:SetMax` |
| `AddButton(o)` | `Text, Callback, DoubleClick, ConfirmText, Risky` · chain `:AddButton(o)` for same-row buttons |
| `AddDropdown(flag, o)` | `Text, Values, Default, Multi, AllowNull, MaxVisible = 8, Searchable, Placeholder, SpecialType = "Player" \| "Team", ExcludeLocalPlayer` · `:SetValues`, `:AddValue`, `:GetActiveValues` |
| `AddColorPicker(flag, o)` | `Text, Default, Transparency` (number enables the alpha rail) · `.Value`, `.Transparency`, `:SetRainbow`, `:SetHSV` |
| `AddKeybind(flag, o)` | `Text, Default` (KeyCode, UserInputType, or `"MB1"`/`"MB2"`/`"MB3"`/key name)`, Mode = "Toggle" \| "Hold" \| "Always", SyncToggleState, NoUI, ChangedCallback` · `:GetState()`, `:IsDown()`, `.StateChanged`, `:OnClick(fn)`, `:SetMode` |
| `AddInput(flag, o)` | `Text, Default, Placeholder, Numeric, Finished, MaxLength, ClearTextOnFocus` |
| `AddLabel(text \| o)` | RichText allowed · `:SetText` · `:AddKeybind` / `:AddColorPicker` |
| `AddParagraph(o)` | `Title, Content` · `:SetTitle`, `:SetContent` |
| `AddDivider(o?)` | `Text, Style = "vine" \| "line"` |
| `AddImage(o)` | `Image` (icon name, asset id or URL)`, Height, Color, Caption, ScaleType` |
| `AddDependencyBox()` | nested container · `:SetupDependencies({ { control, expected }, ... })` where `expected` is a value, or a `fn(value) -> bool` |
| `AddBlank(height)` | spacer |

Keybinds attached to a toggle drive it. In **Toggle** mode a press flips the toggle; in **Hold** mode the toggle is on while the key is held. Right-click any keybind to change its mode, press Backspace while listening to clear it, and Escape to cancel.

### Themes

Built-in palettes: **Hellspawn** (crimson), **Rabbit** (bone white), **Narcissist** (chromatic rainbow), **Thorns** (rust and parchment), **Venom**, **Abyss**, **Reliquary** (gilded).

```lua
Hellspawn:RegisterTheme("Ichor", {
	Accent = Color3.fromRGB(255, 196, 0),
	AccentGradient = { Color3.fromRGB(255, 230, 120), Color3.fromRGB(200, 120, 0) }, -- optional
	Background = Color3.fromRGB(8, 7, 5),   -- any key you skip falls back to Hellspawn's
})
Hellspawn:SetTheme("Ichor")
Hellspawn:SetAccent(Color3.fromRGB(0, 200, 255)) -- override just the accent
```

Palette keys: `Background, Panel, Surface, SurfaceHover, SurfaceActive, Border, BorderLight, Text, TextDim, TextMuted, Accent, AccentGradient, Success, Warning, Error, Grain, Scratches`. Derived automatically: `AccentLight, AccentDark, AccentSoft, Glow, OnAccent`.

To theme your own instances, use `Hellspawn.Theme:Bind(frame, { BackgroundColor3 = "Panel", ... })`.

### Settings

`Hellspawn:SetSetting(key, value)`, or pass `Settings = { ... }` to `CreateWindow`:

`Animations, Glow, GlowIntensity (0 to 1.5), Embers, Grain, Scratches, Scanlines, Vignette, Glitch, SmoothDrag, Cursor, Tooltips, UnlockMouse`. All are on by default except `Scratches`.

### Configs

```lua
Hellspawn.Config:Save("legit")       -- workspace/Hellspawn/configs/legit.json
Hellspawn.Config:Load("legit")
Hellspawn.Config:List()               -- { "legit", ... }
Hellspawn.Config:Delete("legit")
Hellspawn.Config:SetAutoload("legit")
Hellspawn.Config:LoadAutoload()
Hellspawn.Config:SetIgnore({ "some_flag" })   -- or NoSave = true on the control
```

Configs store every flagged control plus the theme name and colour overrides.

### Icons

`sigil crosshair eye skull rabbit gear user knife bolt thorns spider cross drop flame moon globe check chevron close minus plus search info warning success error keyboard list copy folder save lock code tag star grip pin hourglass`

Aliases also work: `aim, combat, visuals, esp, player, settings, movement, misc, theme, world, rage, keybinds, scripts, danger, …`. Any `rbxassetid`, number or URL works too.

## Executor support

Used when available, each with a fallback:

| function | used for | without it |
|---|---|---|
| `gethui` / `protectgui` / `cloneref` | hidden, protected GUI parent | CoreGui, then PlayerGui |
| `writefile readfile isfile isfolder makefolder listfiles delfile` | texture/font cache, configs | no cache, no configs |
| `getcustomasset` | generated textures and fonts | built-in fonts and no texture effects (the `UIShadow` glows still work) |
| `request` / `game:HttpGet` | fonts, URL images | built-in fonts |
| `setclipboard` | colour copy | — |
| `identifyexecutor` | status bar | "unknown" |
| `getgenv` | single instance across re-executions | `_G` |

The first run paints 23 textures, which takes well under a second. After that they load from `workspace/Hellspawn/cache`.

## Building from source

The library lives in `src/` as small modules (`import("core/Signal")` and so on). `build.ps1` bundles them into one loadstring-ready file:

```bash
powershell -ExecutionPolicy Bypass -File build.ps1
```

```
src/
  init.lua                 library object, boot, registries, unload
  core/                    Env (UNC layer) · Signal · Maid · Util · Anim · Motion (springs) · Input
  render/                  Png encoder · Canvas rasteriser · Sdf · Noise · Rng · Icons · Textures (recipes)
  assets/                  Assets (cache + getcustomasset) · Fonts (download + font families)
  theme/                   Themes (palettes) · Theme (live binding)
  fx/                      Glow · Ripple · Scramble · GlitchText · Embers · Cursor
  components/              Window · Tab · Groupbox · Tabbox · DependencyBox · Element · Container · Style · Addons
  components/elements/     Toggle · Slider · Button · Dropdown · ColorPicker · Keybind · Textbox · Label · Paragraph · Divider · Image
  overlays/                Popups · Notifications · Tooltip · Watermark · KeybindList · Floating · Intro · MobileButton
  managers/                Config · Settings
```

To add an icon, append an SDF function to `render/Icons.lua` (`Icons.Shapes.name = function(x, y) return distance end`, with the design in [-1, 1] and y pointing down), add its name to the end of `Icons.Order`, and bump the `icons` recipe version in `render/Textures.lua`.

## Credits

Fonts: [UnifrakturMaguntia](https://fonts.google.com/specimen/UnifrakturMaguntia), [Pirata One](https://fonts.google.com/specimen/Pirata+One) and [JetBrains Mono](https://www.jetbrains.com/lp/mono/), all under the SIL Open Font License. Everything else, including the textures, icons, PNG encoder and effects, is original to this project.
