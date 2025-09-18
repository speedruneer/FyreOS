---@class vfs
local vfs = {}

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