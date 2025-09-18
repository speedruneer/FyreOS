coroutine.yield(true)

local CTRL_DOWN = false
local input = ""
_G.cwd = cwd or "/"  -- fallback if you haven't set a cwd yet

while true do
    term.clearLine()
    local x, y = term.getCursorPos()
    term.setCursorPos(1, y)
    write("root " .. cwd .. "$ " .. input)

    local event, key = coroutine.yield("ask_input")

    if event == "key" then
        if key == keys.leftCtrl then
            CTRL_DOWN = true
        elseif key == keys.c and CTRL_DOWN then
            coroutine.yield("die")
        elseif key == keys.backspace then
            input = input:sub(1, math.max(0, #input - 1))
        elseif key == keys.enter then
            print()
            local cmd = input:match("^%S+")
            if cmd == "exit" then
                print("Exiting Shell")
                coroutine.yield("die")
            end
            if cmd then
                local path = "/bin/" .. cmd .. ".lua"
                local file = fs.open(path, "r")
                if file then
                    local code = file.readAll()
                    file.close()
                    os.queueEvent("new_process", 1, path, 1, "/")
                    input = ""
                    term.clearLine()
                    local x, y = term.getCursorPos()
                    term.setCursorPos(1, y)
                    write("root " .. cwd .. "$ " .. input)
                else
                    print("command not found: " .. cmd)
                end
            end
        end
    elseif event == "key_up" and key == keys.leftCtrl then
        CTRL_DOWN = false
    elseif event == "char" then
        input = input .. key
    end
end

coroutine.yield("die")
