-- Simple URL-based package/script manager (WIP)
-- Stores only file names & their URLs, can download specific files or update all of them

args = {...}
packages = {}


if not fs.exists("/startup") then fs.makeDir("/startup") end
if not fs.exists("/startup/run-packages.lua") then
    print("First run, setting up autorun")
    f = io.open("/startup/run-packages.lua", "w")
    f:write("shell.run(\"/packages.lua runauto\")")
    f:flush()
    f:close()
end


if fs.exists("/.packages") then
    for line in io.lines("/.packages") do
        pkg = {}
        for text in string.gmatch(line, "[^%s]+") do table.insert(pkg, text) end
        if #pkg ~= 0 then table.insert(packages, pkg) end
    end
end


function savePackages ()
    f = io.open("/.packages", "w")
    for _, pp in pairs(packages) do
        f:write(table.concat(pp, " ") .. "\n")
    end

    f:flush()
    f:close()
end


cmd = args[1]
table.remove(args, 1)

if cmd == "add" then
    if #args ~= 0 then
        for _, url in pairs(args) do
            exists = false

            for _, pp in pairs(packages) do
                if pp[2] == url then
                    io.stderr:write("Package \"" .. pp[1] .. "\" is already installed\n")
                    exists = true
                    break
                end
            end

            if not exists then
                name = string.match(url, "[^/]+.lua$")
                print("Adding package \"" .. name .. "\"")
                table.insert(packages, {name, url})
            end
        end

        savePackages()
        return
    end

elseif cmd == "del" then
    if #args ~= 0 then
        for _, name in pairs(args) do
            exists = false

            for i, pp in pairs(packages) do
                if pp[1] == name then
                    print("Removing package \"" .. name .. "\"")
                    fs.delete("/" .. name)
                    exists = true
                    packages[i] = nil
                    break
                end
            end

            if not exists then
                io.stderr:write("Package \"" .. name .. "\" is not installed\n")
            end
        end

        savePackages()
        return
    end

elseif cmd == "list" then
    print("Packages (" .. #packages .. "):")
    for _, pp in pairs(packages) do
        if pp[3] == "autorun" then star = "*" else star = " " end
        print(star .. pp[1])
    end

    return

elseif cmd == "upgrade" then
    specific = #args ~= 0

    for _, pp in pairs(packages) do
        download = false

        if specific then
            for _, name in pairs(args) do
                if pp[1] == name then
                    download = true
                    break
                end
            end
        end

        if not specific or download then
            if fs.exists("/" .. pp[1]) then
                write("Upgrading file \"" .. pp[1] .. "\"... ")
                fs.delete("/" .. pp[1])
            else
                write("Downloading file \"" .. pp[1] .. "\"... ")
            end

            req = http.get(pp[2])
            code = req.getResponseCode()
            if code >= 200 and code < 300 then
                f = io.open("/" .. pp[1], "w")
                f:write(req.readAll())
                f:close()
                print("Downloaded successfuly")
            else
                io.stderr:write("Got error code " .. tostring(code) .. "\n")
            end

            req:close()
        end
    end

    return

elseif cmd == "autorun" or cmd == "unautorun" then
    if #args ~= 0 then
        setAutorun = cmd == "autorun"

        for _, name in pairs(args) do
            exists = false

            for _, pp in pairs(packages) do
                if pp[1] == name then
                    if setAutorun then
                        if pp[3] ~= "autorun" then
                            table.insert(pp, "autorun")
                        else
                            print("Package \"" .. name .. "\" is already set to autorun")
                        end
                    else
                        if pp[3] == "autorun" then
                            table.remove(pp, 3)
                        else
                            print("Package \"" .. name .. "\" is not set to autorun")
                        end
                    end

                    exists = true
                    break
                end
            end

            if not exists then
                io.stderr:write("Package \"" .. name .. "\" is not installed\n")
            end
        end

        savePackages()
        return
    end

elseif cmd == "runauto" then
    for _, pp in pairs(packages) do
        if pp[3] == "autorun" then
            print("Autorunning " .. pp[1])
            shell.openTab("/" .. pp[1])
        end
    end

    return
end


print("Usage:")
print("    add <url> [...]")
print("    del <name> [...]")
print("    list")
print("    upgrade [name] [...]")
print("    autorun [name] [...]")
print("    unautorun [name] [...]")
