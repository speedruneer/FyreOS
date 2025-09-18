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

_G.vfs = {}

_G.__root = root
_G.__fs   = fs

---@param self table
---@param path string
vfs.resolvePath = function(self, path)
    if not path or path == "" then return nil end

    local node = _G.__root  -- start from root
    -- remove leading/trailing slashes, split by "/"
    local parts = {}
    for part in path:gmatch("[^/]+") do
        table.insert(parts, part)
    end

    for _, part in ipairs(parts) do
        if not node.__children then
            return nil, "Not a directory: " .. part
        end
        node = node.__children[part]
        if not node then
            return nil, "Path not found: " .. part
        end
    end

    return node
end

vfs.getPermissions = function(self, file)
    local out = {r=false,w=false,v=false}
    local c1 = file.__perm:sub(1, 1)
    if c1 == "?" or c1 == "r" or (c1 == "-" and _G.is_su) then out.r = true end
    local c2 = file.__perm:sub(2, 2)
    if c1 == "?" or c1 == "w" or (c2 == "-" and _G.is_su) then out.w = true end
    local c3 = file.__perm:sub(3, 3)
    if c1 == "?" or c1 == "v" or (c3 == "-" and _G.is_su) then out.v = true end
    return out
end

vfs.open = function(vfsAPI, path, mode)
    local f, err = vfsAPI:resolvePath(path)
    if not f then
        print(err)
        return
    end
    local perms = vfsAPI:getPermissions(f)
    if mode == "r" then
        if perms.r then
            local fileHandler = {}
            fileHandler.__children = fileHandler
            fileHandler.close = function(self)
                self = nil
            end
            fileHandler.read = f.read or function() error("Invalid File Handler") end
            return fileHandler
        else
            error("Invalid Permissions", 0)
        end
    end
    if mode == "w" then
        if perms.w then
            local fileHandler = {}
            fileHandler.__children = fileHandler
            fileHandler.close = function(self)
                self = nil
            end
            fileHandler.write = f.write or function() error("Invalid File Handler") end
            return fileHandler
        else
            error("Invalid Permissions", 0)
        end
    end
    error("Invalid mode: " .. mode)
end