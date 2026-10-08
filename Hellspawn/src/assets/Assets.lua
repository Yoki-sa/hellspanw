--[[
	Assets
	Owns every texture and font the UI uses.

	Textures are painted by render/Textures, cached as PNGs under
	<folder>/cache and loaded with getcustomasset. Re-runs are instant because
	only missing (or version-bumped) files are regenerated. Executors without
	file/asset support still get a fully working UI: image-based effects
	simply switch off.
]]

local Env = import("core/Env")
local Signal = import("core/Signal")
local Canvas = import("render/Canvas")
local Textures = import("render/Textures")
local Icons = import("render/Icons")
local Fonts = import("assets/Fonts")

local Assets = {}
Assets.__index = Assets

function Assets.new(folder)
	local self = setmetatable({}, Assets)
	self.Folder = folder
	self.Textures = {}
	self.Families = {}
	self.Ready = false
	self.Progress = Signal.new() -- (fraction 0..1, label)
	self.Loaded = Signal.new()
	self._fonts = {}
	self._remote = {}
	for _, role in Fonts.Roles do
		self.Families[role] = Fonts.fallbackFamily(role)
	end
	return self
end

function Assets:_texturePath(recipe)
	return string.format("%s/cache/%s.g%d.v%d.png", self.Folder, recipe.Name, Textures.Generation, recipe.Version)
end

-- Removes cache files from older recipe versions
function Assets:_prune(valid)
	for _, file in Env.list(self.Folder .. "/cache") do
		local name = string.match(file, "([^/\\]+)$")
		if name and string.match(name, "%.png$") and not valid[name] then
			Env.remove(file)
		end
	end
end

--[[
	Generates / loads everything. Yields; spreads heavy work across frames.
	opts.Textures (default true), opts.Fonts (default true)
]]
function Assets:Load(opts)
	opts = opts or {}
	local textures = opts.Textures ~= false and Env.canAssets
	local fonts = opts.Fonts ~= false and Env.canAssets
	local recipes = Textures.Recipes
	local total = (textures and #recipes or 0) + (fonts and Fonts.faceCount() or 0)
	local done = 0

	local function advance(label)
		done += 1
		self.Progress:Fire(total > 0 and done / total or 1, label)
	end

	if textures then
		Env.ensureFolder(self.Folder .. "/cache")
		local budgetStart = os.clock()
		Canvas.yield = function()
			if os.clock() - budgetStart > 1 / 120 then
				task.wait()
				budgetStart = os.clock()
			end
		end

		local valid = {}
		for _, recipe in recipes do
			local path = self:_texturePath(recipe)
			valid[string.match(path, "([^/]+)$")] = true
			if not Env.exists(path) then
				local ok, png = pcall(function()
					return recipe.Build():encode()
				end)
				if ok then
					Env.write(path, png)
				else
					warn("[Hellspawn] texture '" .. recipe.Name .. "' failed: " .. tostring(png))
				end
			end
			if Env.exists(path) then
				self.Textures[recipe.Name] = Env.asset(path)
			end
			advance("forging " .. recipe.Name)
		end
		Canvas.yield = nil
		task.spawn(self._prune, self, valid)
	end

	if fonts then
		self.Families = Fonts.load(self.Folder, function(label)
			advance("summoning " .. label)
		end)
		table.clear(self._fonts)
	end

	self.Ready = true
	self.Progress:Fire(1, "ready")
	self.Loaded:Fire()
	return self
end

-- Builds a single recipe immediately (used by the intro for the logo)
function Assets:Preload(name)
	if not Env.canAssets or self.Textures[name] then
		return self.Textures[name] or ""
	end
	local recipe = Textures.find(name)
	if not recipe then
		return ""
	end
	local path = self:_texturePath(recipe)
	if not Env.exists(path) then
		local ok, png = pcall(function()
			return recipe.Build():encode()
		end)
		if ok then
			Env.write(path, png)
		end
	end
	if Env.exists(path) then
		self.Textures[name] = Env.asset(path)
	end
	return self.Textures[name] or ""
end

-- Deletes cached textures and fonts; returns how many files were removed
function Assets:ClearCache()
	local removed = 0
	for _, sub in { "cache", "fonts", "remote" } do
		for _, file in Env.list(self.Folder .. "/" .. sub) do
			if Env.remove(file) then
				removed += 1
			end
		end
	end
	return removed
end

function Assets:Texture(name)
	return self.Textures[name] or ""
end

function Assets:Has(name)
	local id = self.Textures[name]
	return id ~= nil and id ~= ""
end

function Assets:Meta(name)
	return Textures.Meta[name]
end

--[[
	Font for a role ("Display", "Gothic", "Body") and optional weight.
	Font objects are cached per role/weight.
]]
function Assets:Font(role, weight, style)
	weight = weight or Enum.FontWeight.Regular
	style = style or Enum.FontStyle.Normal
	local key = role .. "|" .. weight.Name .. "|" .. style.Name
	local font = self._fonts[key]
	if not font then
		local family = self.Families[role] or self.Families.Body
		local ok, result = pcall(Font.new, family, weight, style)
		font = ok and result or Font.fromEnum(Enum.Font.Code)
		self._fonts[key] = font
	end
	return font
end

-- Downloads an image from a URL into the cache and returns an asset id
function Assets:FromUrl(url)
	if self._remote[url] then
		return self._remote[url]
	end
	if not Env.canAssets then
		return ""
	end
	local hash = 0
	for i = 1, #url do
		hash = (hash * 31 + string.byte(url, i)) % 2147483647
	end
	local ext = string.match(url, "%.(%a%a%a%a?)$") or "png"
	local path = string.format("%s/remote/%x.%s", self.Folder, hash, string.lower(ext))
	if not Env.exists(path) then
		local body = Env.httpGet(url)
		if not body then
			return ""
		end
		Env.write(path, body)
	end
	local id = Env.asset(path)
	self._remote[url] = id
	return id
end

-- Resolves anything image-like: icon names, rbxassetid numbers/strings, URLs
function Assets:Image(source)
	if source == nil then
		return "", nil, nil
	end
	if type(source) == "number" then
		return "rbxassetid://" .. source, nil, nil
	end
	if string.match(source, "^rbxasset") or string.match(source, "^rbxthumb") then
		return source, nil, nil
	end
	if string.match(source, "^https?://") then
		return self:FromUrl(source), nil, nil
	end
	if tonumber(source) then
		return "rbxassetid://" .. source, nil, nil
	end
	local name = Icons.resolve(source)
	if name and self:Has("icons") then
		local x, y, cell = Textures.iconRect(name)
		return self.Textures.icons, Vector2.new(x, y), Vector2.new(cell, cell)
	end
	return "", nil, nil
end

-- Points an ImageLabel/ImageButton at an icon or image; returns success
function Assets:ApplyIcon(label, source)
	local image, offset, size = self:Image(source)
	label.Image = image
	label.ImageRectOffset = offset or Vector2.zero
	label.ImageRectSize = size or Vector2.zero
	return image ~= ""
end

return Assets
