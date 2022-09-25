shell.run("wget https://github.com/64-Tesseract/computercraft-scripts/raw/master/packages.lua /packages.lua")

packages = {
    {"packages.lua", "https://github.com/64-Tesseract/computercraft-scripts/raw/master/packages.lua"},
    {"remman.lua", "https://github.com/64-Tesseract/computercraft-scripts/raw/master/remman.lua", "autorun"},
    {"miner2.lua", "https://github.com/64-Tesseract/computercraft-scripts/raw/master/miner2.lua"},
    {"redman.lua", "https://github.com/64-Tesseract/computercraft-scripts/raw/master/redman.lua", "autorun"}
}


f = io.open("/.packages", "w")

for _, pp in pairs(packages) do
    write(pp[1] .. " Y/n ? ")
    yn = io.read()
    if yn ~= "n" and yn ~= "N" then
        f:write(table.concat(pp, " ") .. "\n")
    end
end

f:flush()
f:close()

shell.run("packages", "upgrade")

shell.run("reboot")
