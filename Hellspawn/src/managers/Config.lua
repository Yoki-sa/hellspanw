--[[
	Config
	JSON configs stored under <folder>/configs/<name>.json. Every flagged
	control serialises itself; theme name + colour overrides ride along.

		library.Config:Save("legit")
		library.Config:Load("legit")
		library.Config:SetAutoload("legit")
]]

local Env = import("core/Env")

local Config = {}
Config.__index = Config

local FORMAT = 1

function Config.new(library)
	local self = setmetatable({}, Config)
	self.Library = library
	self.Folder = library.Folder .. "/configs"
	self.Ignore = {} -- [flag] = true: never saved (e.g. the config name box)
	return self
end

local function sanitize(name)
	name = tostring(name or "")
	name = string.gsub(name, "[^%w_%- ]", "")
	name = string.match(name, "^%s*(.-)%s*$")
	return name
end

function Config:_path(name)
	return string.format("%s/%s.json", self.Folder, name)
end

function Config:SetIgnore(flags)
	for _, flag in flags do
		self.Ignore[flag] = true
	end
end

function Config:Serialize()
	local library = self.Library
	local flags = {}
	for flag, option in library.Options do
		if not self.Ignore[flag] and not option.Options.NoSave then
			local ok, value = pcall(option._serialize, option)
			if ok and value ~= nil then
				flags[flag] = { Kind = option.Kind, Value = value }
			end
		end
	end
	return {
		Format = FORMAT,
		Library = library.Version,
		Place = game.PlaceId,
		Theme = library.Theme:Export(),
		Flags = flags,
	}
end

function Config:Apply(data)
	if type(data) ~= "table" or type(data.Flags) ~= "table" then
		return false, "malformed config"
	end
	local library = self.Library
	if data.Theme and not self.Ignore.__theme then
		library.Theme:Import(data.Theme)
	end
	local failures = 0
	for flag, entry in data.Flags do
		local option = library.Options[flag]
		if option and not self.Ignore[flag] and type(entry) == "table" then
			local ok = pcall(option._deserialize, option, entry.Value)
			if not ok then
				failures += 1
			end
		end
	end
	return true, failures
end

function Config:Save(name)
	name = sanitize(name)
	if name == "" then
		return false, "enter a config name"
	end
	if not Env.canFiles then
		return false, "this executor has no file access"
	end
	local HttpService = Env.service("HttpService")
	local ok, json = pcall(HttpService.JSONEncode, HttpService, self:Serialize())
	if not ok then
		return false, "could not encode config"
	end
	Env.ensureFolder(self.Folder)
	if not Env.write(self:_path(name), json) then
		return false, "write failed"
	end
	return true
end

function Config:Load(name)
	name = sanitize(name)
	if name == "" then
		return false, "pick a config"
	end
	local raw = Env.read(self:_path(name))
	if not raw then
		return false, "config '" .. name .. "' not found"
	end
	local HttpService = Env.service("HttpService")
	local ok, data = pcall(HttpService.JSONDecode, HttpService, raw)
	if not ok then
		return false, "config is corrupted"
	end
	return self:Apply(data)
end

function Config:Delete(name)
	name = sanitize(name)
	if name == "" then
		return false, "pick a config"
	end
	if not Env.exists(self:_path(name)) then
		return false, "config not found"
	end
	return Env.remove(self:_path(name))
end

function Config:List()
	local names = {}
	for _, file in Env.list(self.Folder) do
		local name = string.match(file, "([^/\\]+)%.json$")
		if name then
			table.insert(names, name)
		end
	end
	table.sort(names, function(a, b)
		return string.lower(a) < string.lower(b)
	end)
	return names
end

function Config:SetAutoload(name)
	name = sanitize(name)
	if name == "" then
		Env.remove(self.Folder .. "/autoload.txt")
		return true
	end
	return Env.write(self.Folder .. "/autoload.txt", name)
end

function Config:GetAutoload()
	local name = Env.read(self.Folder .. "/autoload.txt")
	if name and name ~= "" then
		return sanitize(name)
	end
	return nil
end

function Config:LoadAutoload()
	local name = self:GetAutoload()
	if not name then
		return false
	end
	local ok, err = self:Load(name)
	if ok then
		self.Library:Notify({ Title = "Config", Content = "autoloaded <b>" .. name .. "</b>", Type = "success", Duration = 3 })
	else
		self.Library:Notify({ Title = "Autoload failed", Content = tostring(err), Type = "error", Duration = 4 })
	end
	return ok
end

return Config
