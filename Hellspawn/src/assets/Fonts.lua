--[[
	Fonts
	Downloads open-licensed TTFs, caches them in the workspace folder and
	assembles Roblox font-family JSON files so they can be used through
	Font.new(getcustomasset(...)). Every role has a built-in fallback.

	Roles:
		Display  – blackletter title (UnifrakturMaguntia, OFL)
		Gothic   – headings          (Pirata One, OFL)
		Body     – everything else   (JetBrains Mono, OFL)
]]

local Env = import("core/Env")

local Fonts = {}

local GOOGLE = "https://raw.githubusercontent.com/google/fonts/main/ofl/"
local JETBRAINS = "https://raw.githubusercontent.com/JetBrains/JetBrainsMono/master/fonts/ttf/"

Fonts.Families = {
	Display = {
		Name = "UnifrakturMaguntia",
		Faces = {
			{ Name = "Regular", Weight = 400, Url = GOOGLE .. "unifrakturmaguntia/UnifrakturMaguntia-Book.ttf" },
		},
		Fallback = "GrenzeGotisch",
	},
	Gothic = {
		Name = "PirataOne",
		Faces = {
			{ Name = "Regular", Weight = 400, Url = GOOGLE .. "pirataone/PirataOne-Regular.ttf" },
		},
		Fallback = "GrenzeGotisch",
	},
	Body = {
		Name = "JetBrainsMono",
		Faces = {
			{ Name = "Regular", Weight = 400, Url = JETBRAINS .. "JetBrainsMono-Regular.ttf" },
			{ Name = "Medium", Weight = 500, Url = JETBRAINS .. "JetBrainsMono-Medium.ttf" },
			{ Name = "Bold", Weight = 700, Url = JETBRAINS .. "JetBrainsMono-Bold.ttf" },
		},
		Fallback = "RobotoMono",
	},
}

Fonts.Roles = { "Display", "Gothic", "Body" }

local FALLBACKS = {
	GrenzeGotisch = function()
		return Font.fromEnum(Enum.Font.GrenzeGotisch).Family
	end,
	RobotoMono = function()
		return "rbxasset://fonts/families/RobotoMono.json"
	end,
}

function Fonts.fallbackFamily(role)
	local def = Fonts.Families[role]
	local resolver = def and FALLBACKS[def.Fallback]
	local ok, family = pcall(resolver or FALLBACKS.RobotoMono)
	if ok and type(family) == "string" then
		return family
	end
	return "rbxasset://fonts/families/SourceSansPro.json"
end

-- TrueType ("\0\1\0\0" / "true") or OpenType ("OTTO") magic
local function looksLikeFont(data)
	if type(data) ~= "string" or #data < 1024 then
		return false
	end
	local magic = string.sub(data, 1, 4)
	return magic == "\0\1\0\0" or magic == "true" or magic == "OTTO"
end

function Fonts.faceCount()
	local n = 0
	for _, role in Fonts.Roles do
		n += #Fonts.Families[role].Faces
	end
	return n
end

--[[
	Resolves every role to a family string. Yields while downloading.
	onFace(label) is called after each face so a loader can show progress.
]]
function Fonts.load(folder, onFace)
	local families = {}
	local HttpService = Env.service("HttpService")
	local fontFolder = folder .. "/fonts"
	if Env.canAssets then
		Env.ensureFolder(fontFolder)
	end

	for _, role in Fonts.Roles do
		local def = Fonts.Families[role]
		local faces = {}
		for _, face in def.Faces do
			if Env.canAssets then
				local path = string.format("%s/%s-%s.ttf", fontFolder, def.Name, face.Name)
				if not Env.exists(path) then
					local body = Env.httpGet(face.Url)
					if looksLikeFont(body) then
						Env.write(path, body)
					end
				end
				if Env.exists(path) then
					local id = Env.asset(path)
					if id ~= "" then
						table.insert(faces, { name = face.Name, weight = face.Weight, style = "normal", assetId = id })
					end
				end
			end
			if onFace then
				onFace(def.Name .. " " .. face.Name)
			end
		end

		if #faces > 0 then
			local jsonPath = string.format("%s/%s.json", fontFolder, def.Name)
			local ok, json = pcall(HttpService.JSONEncode, HttpService, { name = def.Name, faces = faces })
			if ok and Env.write(jsonPath, json) then
				local family = Env.asset(jsonPath)
				if family ~= "" then
					families[role] = family
				end
			end
		end
		families[role] = families[role] or Fonts.fallbackFamily(role)
	end
	return families
end

return Fonts
