-- Simple URL-based package/script manager (version 2.0)
-- Stores only file names & their URLs, can download specific files or update all of them
-- Also serves as autorun manager, installed or even untracked programs can be added

args = {...}
packages = settings.get("packages.packages", {})
autorun = settings.get("packages.autorun", {})

cmd = args[1]
table.remove(args, 1)

-- Ensure packages autorun manager is automatically started
if not fs.exists("/rom/autorun/run-packages.lua") then
    if not fs.exists("/startup") then fs.makeDir("/startup") end
    if not fs.exists("/startup/run-packages.lua") then
        print("First run, setting up autorun")
        f = io.open("/startup/run-packages.lua", "w")
        f:write("shell.run(\"packages runauto\")")
        f:flush()
        f:close()
    end
end

if cmd == "add" then
    if #args ~= 0 then
        for _, url in pairs(args) do
            nameLua = string.match(url, "[^/]+.lua$")
            name = string.match(nameLua, "^.*[^.lua]")

            if packages[name] then
                io.stderr:write("Package \"" .. pp[1] .. "\" is already installed\n")
            else
                print("Adding package \"" .. name .. "\"")
                packages[name] = url
            end
        end
    end

    settings.set("packages.packages", packages)
    settings.save()
    return

elseif cmd == "rem" or cmd == "del" then
    delete = cmd == "del"

    if #args ~= 0 then
        for _, name in pairs(args) do
            if packages[name] then
                if delete then
                    print("Deleting package \"" .. name .. "\"")
                    fs.delete("/" .. name)
                else
                    print("Removing package \"" .. name .. "\"")
                end

                packages[name] = nil
                autorun[name] = nil

            else
                io.stderr:write("Package \"" .. name .. "\" is not installed\n")
            end
        end
    end

    settings.set("packages.packages", packages)
    settings.save()
    return

elseif cmd == "list" then
    print("Packages:")
    for pp, _ in pairs(packages) do
        if autorun[pp] then star = "  * " else star = "    " end
        print(star .. pp)
    end
    print("(*=Autorun)")

    return

elseif cmd == "upgrade" then
    toDownload = {}

    if #args ~= 0 then
        for name, _ in pairs(args) do
            toDownload[name] = packages[name]
        end
    else
        toDownload = packages
    end

    for name, url in pairs(toDownload) do
        if fs.exists("/" .. name) then
            write("Upgrading file \"" .. pp[1] .. "\"... ")
            fs.delete("/" .. name)
        else
            write("Downloading file \"" .. name .. "\"... ")
        end

        req = http.get(url)
        code = req.getResponseCode()
        if code >= 200 and code < 300 then
            f = io.open("/" .. name, "w")
            f:write(req.readAll())
            f:close()
            print("Success")
        else
            io.stderr:write("Error " .. tostring(code) .. "\n")
        end

        req:close()
    end

    return

elseif cmd == "autorun" or cmd == "unautorun" then
    if #args ~= 0 then
        setAutorun = cmd == "autorun"

        for _, name in pairs(args) do
            if setAutorun then
                if autorun[name] then
                    io.stderr:write("\"" .. name .. "\" is already set to autorun\n")
                else
                    print("Setting autorun for \"" .. name .. "\"" .. (packages[name] and "" or " (not installed)"))
                    autorun[name] = true
                end
            else
                if autorun[name] then
                    print("Unsetting autorun for \"" .. name .. "\"")
                    autorun[name] = nil
                else
                    io.stderr:write("\"" .. name .. "\" is not set to autorun\n")
                end
            end
        end

        settings.set("packages.autorun", autorun)
        settings.save()
        return

    else
        print("Autorun:")
        for pp, _ in pairs(autorun) do
            if packages[pp] then star = "  * " else star = "    " end
            print(star .. pp)
        end
        print("(*=Installed)")

        return
    end

elseif cmd == "runauto" then
    for pp, _ in pairs(autorun) do
        print("Autorunning " .. pp)
        shell.openTab(pp)
    end

    return

elseif cmd == "help" then
    if args[1] then
        help = {help="Shows information about a command",
                add="Add a URL to download",
                rem="Remove a URL to download & unautorun it",
                del="Remove a URL to download, unautorun it, & delete the package",
                list="List tracked programs",
                upgrade="Download tracked or specific packages",
                autorun="Sets any program to run at startup in its own tab"}

        print(help[args[1]])
        return
    end
end


print("Usage:")
print("    help <command>")
print("    add <url> [...]")
print("    rem <name> [...]")
print("    del <name> [...]")
print("    list")
print("    upgrade <name> [...]")
print("    [un]autorun [name] [...]")
