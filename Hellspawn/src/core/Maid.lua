--[[
	Maid
	Owns anything that needs cleaning up: connections, instances, threads,
	callbacks or objects with :Destroy() / :Disconnect().
]]

local Maid = {}
Maid.__index = Maid

local function cleanup(task_)
	local kind = typeof(task_)
	if kind == "RBXScriptConnection" then
		task_:Disconnect()
	elseif kind == "Instance" then
		task_:Destroy()
	elseif kind == "function" then
		task_()
	elseif kind == "thread" then
		if coroutine.status(task_) ~= "dead" then
			pcall(task.cancel, task_)
		end
	elseif kind == "table" then
		if type(task_.Destroy) == "function" then
			task_:Destroy()
		elseif type(task_.Disconnect) == "function" then
			task_:Disconnect()
		end
	end
end

function Maid.new()
	return setmetatable({ _tasks = {}, _named = {} }, Maid)
end

function Maid:Give(task_)
	table.insert(self._tasks, task_)
	return task_
end

-- Named slot: replacing a task cleans the previous one
function Maid:Set(name, task_)
	local previous = self._named[name]
	if previous ~= nil and previous ~= task_ then
		self._named[name] = nil
		cleanup(previous)
	end
	self._named[name] = task_
	return task_
end

function Maid:Clean(name)
	local existing = self._named[name]
	if existing ~= nil then
		self._named[name] = nil
		cleanup(existing)
	end
end

function Maid:Destroy()
	local named = self._named
	self._named = {}
	for _, task_ in named do
		pcall(cleanup, task_)
	end
	local tasks = self._tasks
	self._tasks = {}
	for i = #tasks, 1, -1 do
		pcall(cleanup, tasks[i])
	end
end

Maid.DoCleaning = Maid.Destroy

return Maid
