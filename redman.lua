sideKey = {"top", "bottom", "left", "right", "front", "back"}

rules = {}


function decodeSides (nums)
    s = {}
    for num in string.gmatch(nums, ".") do
        table.insert(s, sideKey[tonumber(num)])
    end

    return s
end


if not fs.exists("/.redman") then io.open("/.redman", "w"):close() end
f = io.open("/.redman", "r")

for line in f:lines() do
    rule = {}
    words = {}

    for word in string.gmatch(line, "[^%s]+") do
        table.insert(words, word)
    end

    rule.inputs = decodeSides(words[2])
    rule.outputs = decodeSides(words[3])
    rule.enabled = true

    rules[words[1]] = rule
end

f:close()


-- Time left enabled in ticks (-1 is disabled, 0 is instant change from input)
sides = {top=-1, bottom=-1, left=-1, right=-1, front=-1, back=-1}


function redstoneLoop ()
    while true do
        for _, ruleSet in pairs(rules) do
            inputs = ruleSet.inputs
            outputs = ruleSet.outputs
            enabled = ruleSet.enabled

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
        name = command[2] or "main"

        if command[1] == "redstone" then
            os.queueEvent("comms_send", rules, replyChain)

        elseif isRule(name, replyChain) then
            if command[1] == "pulse" then
                if rules[name].enabled == false then
                    os.queueEvent("comms_send", {status="error", reason="locked"}, replyChain)
                else
                    for _, sideOut in pairs(rules[name].outputs) do
                        sides[sideOut] = 20
                    end

                    os.queueEvent("comms_send", {status="success"}, replyChain)
                end

            elseif command[1] == "lock" then
                rules[name].enabled = false
                os.queueEvent("comms_send", {status="success"}, replyChain)

            elseif command[1] == "unlock" then
                rules[name].enabled = true
                os.queueEvent("comms_send", {status="success"}, replyChain)
            end
        end
    end
end


function isRule (name, replyChain)
    if rules[name] == nil then
        os.queueEvent("comms_send", {status="error", reason="no such rule"}, replyChain)
        return false
    end

    return true
end


multishell.setTitle(multishell.getCurrent(), "RedMan 0.9")
parallel.waitForAny(redstoneLoop, remoteLoop)
