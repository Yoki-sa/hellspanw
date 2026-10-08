--[[
	Themes
	Built-in palettes. Every theme is dark-first; accents are tuned to glow
	against near-black without blowing out text contrast.

	Keys a palette may define (missing derived keys are computed):
		Background, Panel, Surface, SurfaceHover, SurfaceActive
		Border, BorderLight
		Text, TextDim, TextMuted
		Accent, AccentGradient (list of Color3 or ColorSequence)
		Success, Warning, Error
		Grain, Scratches  (overlay opacities 0..1)
]]

local rgb = Color3.fromRGB

local Themes = {}

Themes.Hellspawn = {
	Description = "fresh blood on charred black",
	Background = rgb(9, 9, 11),
	Panel = rgb(14, 14, 17),
	Surface = rgb(21, 21, 25),
	SurfaceHover = rgb(28, 28, 33),
	SurfaceActive = rgb(36, 36, 42),
	Border = rgb(32, 32, 38),
	BorderLight = rgb(48, 48, 56),
	Text = rgb(236, 231, 222),
	TextDim = rgb(146, 142, 150),
	TextMuted = rgb(84, 82, 90),
	Accent = rgb(226, 22, 60),
	Success = rgb(112, 210, 142),
	Warning = rgb(232, 172, 72),
	Error = rgb(240, 56, 80),
	Grain = 0.09,
	Scratches = 0.07,
}

Themes.Rabbit = {
	Description = "bone white, nothing else",
	Background = rgb(6, 6, 6),
	Panel = rgb(11, 11, 11),
	Surface = rgb(18, 18, 18),
	SurfaceHover = rgb(26, 26, 26),
	SurfaceActive = rgb(34, 34, 34),
	Border = rgb(30, 30, 30),
	BorderLight = rgb(52, 52, 52),
	Text = rgb(242, 240, 235),
	TextDim = rgb(150, 148, 144),
	TextMuted = rgb(82, 81, 79),
	Accent = rgb(240, 236, 228),
	AccentGradient = { rgb(255, 255, 255), rgb(196, 192, 184) },
	Success = rgb(205, 230, 210),
	Warning = rgb(235, 215, 170),
	Error = rgb(235, 90, 90),
	Grain = 0.12,
	Scratches = 0.09,
}

Themes.Narcissist = {
	Description = "chromatic aberration, admired in the mirror",
	Background = rgb(10, 9, 13),
	Panel = rgb(15, 14, 20),
	Surface = rgb(22, 21, 29),
	SurfaceHover = rgb(30, 28, 39),
	SurfaceActive = rgb(39, 36, 50),
	Border = rgb(34, 32, 44),
	BorderLight = rgb(52, 49, 66),
	Text = rgb(236, 234, 245),
	TextDim = rgb(146, 142, 162),
	TextMuted = rgb(84, 80, 98),
	Accent = rgb(176, 150, 255),
	AccentGradient = { rgb(255, 72, 112), rgb(255, 176, 72), rgb(96, 255, 214), rgb(80, 140, 255), rgb(196, 96, 255) },
	Success = rgb(120, 230, 200),
	Warning = rgb(255, 196, 110),
	Error = rgb(255, 84, 120),
	Grain = 0.1,
	Scratches = 0.05,
}

Themes.Thorns = {
	Description = "rusted iron and old parchment",
	Background = rgb(12, 10, 8),
	Panel = rgb(18, 15, 12),
	Surface = rgb(26, 22, 18),
	SurfaceHover = rgb(34, 29, 23),
	SurfaceActive = rgb(43, 36, 29),
	Border = rgb(38, 32, 26),
	BorderLight = rgb(58, 49, 39),
	Text = rgb(234, 221, 196),
	TextDim = rgb(152, 138, 116),
	TextMuted = rgb(90, 80, 66),
	Accent = rgb(214, 98, 42),
	Success = rgb(160, 196, 110),
	Warning = rgb(230, 180, 80),
	Error = rgb(220, 70, 50),
	Grain = 0.11,
	Scratches = 0.1,
}

Themes.Venom = {
	Description = "something toxic glowing in the dark",
	Background = rgb(7, 9, 8),
	Panel = rgb(11, 14, 12),
	Surface = rgb(17, 21, 18),
	SurfaceHover = rgb(23, 29, 25),
	SurfaceActive = rgb(30, 38, 32),
	Border = rgb(27, 34, 29),
	BorderLight = rgb(42, 52, 45),
	Text = rgb(226, 238, 224),
	TextDim = rgb(134, 152, 136),
	TextMuted = rgb(74, 88, 77),
	Accent = rgb(146, 255, 64),
	Success = rgb(146, 255, 64),
	Warning = rgb(240, 220, 80),
	Error = rgb(255, 80, 90),
	Grain = 0.08,
	Scratches = 0.06,
}

Themes.Abyss = {
	Description = "cold light from very far down",
	Background = rgb(6, 8, 12),
	Panel = rgb(10, 13, 19),
	Surface = rgb(15, 19, 27),
	SurfaceHover = rgb(21, 26, 37),
	SurfaceActive = rgb(28, 34, 47),
	Border = rgb(25, 31, 43),
	BorderLight = rgb(40, 48, 64),
	Text = rgb(224, 232, 244),
	TextDim = rgb(132, 144, 164),
	TextMuted = rgb(72, 82, 100),
	Accent = rgb(64, 170, 255),
	Success = rgb(96, 220, 180),
	Warning = rgb(240, 196, 96),
	Error = rgb(255, 84, 104),
	Grain = 0.08,
	Scratches = 0.05,
}

Themes.Reliquary = {
	Description = "gilded bones in a dark chapel",
	Background = rgb(10, 9, 7),
	Panel = rgb(15, 14, 11),
	Surface = rgb(22, 20, 16),
	SurfaceHover = rgb(30, 27, 21),
	SurfaceActive = rgb(39, 35, 27),
	Border = rgb(36, 32, 25),
	BorderLight = rgb(56, 50, 38),
	Text = rgb(238, 230, 210),
	TextDim = rgb(156, 146, 122),
	TextMuted = rgb(92, 85, 70),
	Accent = rgb(214, 178, 94),
	AccentGradient = { rgb(250, 224, 150), rgb(214, 178, 94), rgb(150, 112, 50) },
	Success = rgb(170, 210, 130),
	Warning = rgb(240, 190, 90),
	Error = rgb(220, 80, 70),
	Grain = 0.1,
	Scratches = 0.08,
}

Themes.Order = { "Hellspawn", "Rabbit", "Narcissist", "Thorns", "Venom", "Abyss", "Reliquary" }

-- Keys a user can edit from the theme manager
Themes.EditableKeys = {
	"Accent", "Background", "Panel", "Surface", "Border", "Text", "TextDim",
}

return Themes
