--[[
	Env
	Normalises the executor environment. Every UNC / sUNC function the library
	touches is resolved here once, with graceful fallbacks, so the rest of the
	code never has to care which executor it runs on.
]]

local Env = {}

local function pick(...)
	for i = 1, select("#", ...) do
		local candidate = select(i, ...)
		if type(candidate) == "function" then
			return candidate
		end
	end
	return nil
end

-- Some executors expose libraries as tables; guard every lookup.
local function field(tbl, key)
	if type(tbl) == "table" then
		return tbl[key]
	end
	return nil
end

local G = (type(getgenv) == "function" and getgenv()) or _G or {}
Env.genv = G

Env.cloneref = pick(cloneref) or function(object)
	return object
end

Env.gethui = pick(gethui, get_hidden_gui, field(syn, "gethui"))
Env.protectgui = pick(protectgui, protect_gui, field(syn, "protect_gui"))
Env.writefile = pick(writefile)
Env.readfile = pick(readfile)
Env.appendfile = pick(appendfile)
Env.isfile = pick(isfile)
Env.isfolder = pick(isfolder)
Env.makefolder = pick(makefolder)
Env.listfiles = pick(listfiles)
Env.delfile = pick(delfile)
Env.getcustomasset = pick(getcustomasset, getsynasset, field(syn, "getcustomasset"))
Env.request = pick(request, http_request, field(syn, "request"), field(http, "request"), field(fluxus, "request"))
Env.setclipboard = pick(setclipboard, toclipboard, set_clipboard, field(Clipboard, "set"))
Env.identifyexecutor = pick(identifyexecutor, getexecutorname)
Env.iswindowactive = pick(isrbxactive, iswindowactive)

Env.canFiles = Env.writefile ~= nil
	and Env.readfile ~= nil
	and Env.isfile ~= nil
	and Env.isfolder ~= nil
	and Env.makefolder ~= nil
Env.canAssets = Env.canFiles and Env.getcustomasset ~= nil

local serviceCache = {}
function Env.service(name)
	local cached = serviceCache[name]
	if cached then
		return cached
	end
	local service = Env.cloneref(game:GetService(name))
	serviceCache[name] = service
	return service
end

function Env.executor()
	if not Env.identifyexecutor then
		return "Unknown"
	end
	local ok, name, version = pcall(Env.identifyexecutor)
	if not ok or type(name) ~= "string" then
		return "Unknown"
	end
	if type(version) == "string" and version ~= "" then
		return name .. " " .. version
	end
	return name
end

-- Binary-safe GET with every fallback we know of. Returns body or nil, err.
function Env.httpGet(url)
	if Env.request then
		local ok, response = pcall(Env.request, { Url = url, Method = "GET" })
		if ok and type(response) == "table" then
			local status = response.StatusCode or (response.Success and 200) or 0
			if status >= 200 and status < 300 and type(response.Body) == "string" then
				return response.Body
			end
		end
	end
	local ok, body = pcall(function()
		return game:HttpGet(url, true)
	end)
	if ok and type(body) == "string" and #body > 0 then
		return body
	end
	return nil, "request failed: " .. tostring(url)
end

function Env.ensureFolder(path)
	if not Env.canFiles then
		return false
	end
	local current = ""
	for part in string.gmatch(path, "[^/\\]+") do
		current = current == "" and part or (current .. "/" .. part)
		local exists = false
		pcall(function()
			exists = Env.isfolder(current)
		end)
		if not exists then
			pcall(Env.makefolder, current)
		end
	end
	return true
end

function Env.read(path)
	if not Env.canFiles then
		return nil
	end
	local ok, exists = pcall(Env.isfile, path)
	if not ok or not exists then
		return nil
	end
	local readOk, content = pcall(Env.readfile, path)
	if readOk then
		return content
	end
	return nil
end

function Env.write(path, content)
	if not Env.canFiles then
		return false
	end
	local folder = string.match(path, "^(.*)[/\\][^/\\]+$")
	if folder then
		Env.ensureFolder(folder)
	end
	return (pcall(Env.writefile, path, content))
end

function Env.exists(path)
	if not Env.canFiles then
		return false
	end
	local ok, exists = pcall(Env.isfile, path)
	return ok and exists == true
end

function Env.list(folder)
	if not (Env.canFiles and Env.listfiles) then
		return {}
	end
	local ok, files = pcall(Env.listfiles, folder)
	if not ok or type(files) ~= "table" then
		return {}
	end
	return files
end

function Env.remove(path)
	if Env.delfile then
		return (pcall(Env.delfile, path))
	end
	return false
end

-- getcustomasset wrapper; returns "" when unsupported so Image props stay valid
function Env.asset(path)
	if not Env.canAssets then
		return ""
	end
	local ok, id = pcall(Env.getcustomasset, path)
	if ok and type(id) == "string" then
		return id
	end
	return ""
end

function Env.copy(text)
	if Env.setclipboard then
		return (pcall(Env.setclipboard, text))
	end
	return false
end

-- Finds the safest place to parent UI: gethui > protected CoreGui > PlayerGui
function Env.guiParent(gui)
	if Env.gethui then
		local ok, hui = pcall(Env.gethui)
		if ok and typeof(hui) == "Instance" then
			return hui
		end
	end
	if Env.protectgui then
		pcall(Env.protectgui, gui)
	end
	local ok, core = pcall(function()
		local coreGui = Env.service("CoreGui")
		-- probe write access; plain LocalScripts cannot parent here
		local probe = Instance.new("Folder")
		probe.Parent = coreGui
		probe:Destroy()
		return coreGui
	end)
	if ok and core then
		return core
	end
	local players = Env.service("Players")
	return players.LocalPlayer:WaitForChild("PlayerGui")
end

return Env
