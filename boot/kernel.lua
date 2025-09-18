_G.is_su = false

local function formatTime(n, fmt)
    return os.date(fmt, n/1000)
end

local boot_time = os.date("%c")

local root = {
    __perm = "?xv", -- read write if su view
    __date = boot_time,
    __type = "directory",
    __children = {
        dev = {
            __type = "directory",
            __perm = "r?v", -- read not write view
            __date = boot_time,
            __children = {
                zero = {
                    __type = "file",
                    __date = boot_time,
                    __perm = "rxv", -- read not write view
                    --read = function(self, _) return 0 end,
                },
                random = {
                    __type = "file",
                    __date = boot_time,
                    __perm = "rxv", -- read not write view
                    --read = function(self, _) return math.random(0, 255) end,
                },
            },
        },
    },
}

local function AddFiles(path, parent)
    parent = parent or root  -- default to root
    parent.__children = parent.__children or {}

    local success, list = pcall(fs.list, path)
    if not success or not list then return end

    for _, name in ipairs(list) do
        local fullPath = path .. "/" .. name
        local isDir = fs.isDir(fullPath)
        local attr = fs.attributes(fullPath)
        if attr then
            local isRO = fs.isReadOnly(fullPath)
            local node = {
                __type = isDir and "directory" or "file",
                __date = formatTime(attr.created, "%c"),
                __perm = (isRO and "rx" or "??") .. "v",   -- default permissions
            }

            if isDir then
                node.__children = {}
                -- recursively add children
                AddFiles(fullPath, node)
            else
                -- optional: default read/write handlers for files
                node.read = function(self, n)
                    local f = fs.open(fullPath, "r")
                    if not f then return nil end
                    local data = f.read(n)
                    f.close()
                    return data
                end
                if not isRO then
                    node.write = function(self, data)
                        local f = fs.open(fullPath, "w")
                        if not f then return nil end
                        f.write(data)
                        f.close()
                    end
                end
            end

            parent.__children[name] = node
        end
    end
end


AddFiles("/", root)

_G.__root = root
_G.__fs   = fs

---@class process

_G.processes = {}
_G.processes.__index = _G.processes
---@param fn function
---@return number
_G.processes.new = function(self, fn, ...)
    local process = {}
    process.__index = process
    process._PID = #_G.processes + 1
    process.__type = "process"
    process.co = coroutine.create(fn)
    process.__args = {...}
    processes[process._PID] = process
    if not coroutine.resume(processes[process._PID].co, unpack{...}) then error("PROCESS CREATION FAILED") end
    return process._PID
end

_G.processes.step = function(self, PID, ...)
    if coroutine.status(self[PID].co) == "suspended" then
        local v = {coroutine.resume(self[PID].co, ...)}
        local o = {}
        for i = 2, #v do
            o[i-1] = v[i]
        end
        return unpack(o)
    end
end

function _G.processes:die(PID)
    -- Remove the process
    self[PID].co = nil
    self[PID] = nil

    -- Rebuild numeric indexes without touching non-numeric keys
    local temp = {}
    for k, v in pairs(self) do
        if type(k) == "number" then
            table.insert(temp, v)
        end
    end

    -- Clear old numeric entries
    for k, v in pairs(self) do
        if type(k) == "number" then
            self[k] = nil
        end
    end

    -- Reassign numeric entries in order
    for i, v in ipairs(temp) do
        self[i] = v
        self[i]._PID = i
    end
end

function table.find(tbl, elem)
    for i, v in ipairs(tbl) do
        if v == elem then
            return true, i
        end
    end
    return false, nil
end

local needInput = {}
local waitList = {}

while true do
    local eventData = {os.pullEventRaw()}
    for k, v in pairs(processes) do
        if type(v) == "table" and v.__type == "process" then
            if not waitList[v._PID] or waitList[v._PID] < os.clock() then
                if waitList[v._PID] then waitList[v._PID] = nil end
                if needInput[v._PID] then
                    local output = {processes:step(v._PID, unpack(eventData))}
                else
                    local output = {processes:step(v._PID)}
                end
                if output == "die" then
                    processes:die(v._PID)
                elseif output[1] == "ask_input" then
                    needInput[v._PID] = true
                elseif output[1] == "wait" then
                    waitList[v._PID] = os.clock() + output[2]
                else
                    needInput[v._PID] = nil
                end
            end
        end
    end
end