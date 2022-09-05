shell.run("wget https://github.com/64-Tesseract/computercraft-scripts/raw/master/packages.lua /packages.lua")

packages = {
    {"miner2.lua", "https://github.com/64-Tesseract/computercraft-scripts/raw/master/miner2.lua"}
}


f = io.open("/.packages", "w")

f:write("remman.lua https://github.com/64-Tesseract/computercraft-scripts/raw/master/remman.lua\n")

for _, pp in pairs(packages) do
    write(pp[1] .. " Y/n ? ")
    yn = io.read()
    if yn ~= "n" and yn ~= "N" then
        f:write(pp[1] .. " " .. pp[2] .. "\n")
    end
end

f:flush()
f:close()

shell.run("packages upgrade")

if not fs.exists("/startup") then fs.makeDir("/startup") end
f = io.open("/startup/remman.lua", "w")
f:write("shell.run(\"bg /remman.lua\")")
f:flush()
f:close()

shell.run("reboot")
