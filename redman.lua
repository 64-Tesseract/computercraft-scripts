sideKey = {"top", "bottom", "left", "right", "front", "back"}

rules = {}

if not fs.exists("/.redman") then io.open("/.redman", "w"):close() end
f = io.open("/.redman", "r")

for line in f:lines() do
    rule = {}
    for nums in string.gmatch(line, "[^%s]+") do
        r = {}

        for num in string.gmatch(nums, ".") do
            table.insert(r, sideKey[tonumber(num)])
        end

        table.insert(rule, r)
    end

    table.insert(rule, true)
    table.insert(rules, rule)
end


-- Time left enabled in ticks (-1 is disabled, 0 is instant change from input)
sides = {top=-1, bottom=-1, left=-1, right=-1, front=-1, back=-1}


function redstoneLoop ()
    while true do
        for _, ruleset in pairs(rules) do
            inputs, outputs, active = table.unpack(ruleset)

            if active then
                for _, sideIn in pairs(inputs) do
                    if redstone.getInput(sideIn) and sides[sideIn] == -3 then
                        for _, sideOut in pairs(outputs) do
                            sides[sideOut] = math.max(sides[sideOut], 0)
                        end
                        break
                    end
                end
            end
        end

        for side, val in pairs(sides) do
            redstone.setOutput(side, val >= 0)
            if val > -3 then sides[side] = val - 1 end
        end

        sleep(0)
    end
end


function remoteLoop ()
    while true do
        _, replyChain, command = os.pullEvent("comms_receive")
        id = tonumber(command[2])

        if command[1] == "redstone" then
            os.queueEvent("comms_send", rules, replyChain)

        elseif isRule(id, replyChain) then
            if command[1] == "pulse" then
                if rules[id][3] == false then
                    os.queueEvent("comms_send", {status="error", reason="locked"}, replyChain)
                else
                    for _, sideOut in pairs(rules[id][2]) do
                        sides[sideOut] = 20
                    end

                    os.queueEvent("comms_send", {status="success"}, replyChain)
                end

            elseif command[1] == "lock" then
                rules[id][3] = false
                os.queueEvent("comms_send", {status="success"}, replyChain)

            elseif command[1] == "unlock" then
                rules[id][3] = true
                os.queueEvent("comms_send", {status="success"}, replyChain)
            end
        end
    end
end


function isRule (id, replyChain)
    if rules[id] == nil then
        os.queueEvent("comms_send", {status="error", reason="no such rule"}, replyChain)
        return false
    end

    return true
end


multishell.setTitle(multishell.getCurrent(), "RedMan 0.7")
parallel.waitForAny(redstoneLoop, remoteLoop)
