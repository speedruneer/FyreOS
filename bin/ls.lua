coroutine.yield(true)
local args = {...}
if args[1] then
    print(table.concat(fs.list(args[1]), "\n"))
else
    print(table.concat(fs.list(cwd), "\n"))
end
coroutine.yield("die")