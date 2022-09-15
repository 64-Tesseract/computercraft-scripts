-- Redstone route manager, outputs based on configurable rules to sides based on inputs
-- Reads from `.redman` in format:
--     NAME INPUTS OUTPUTS
-- NAME is a customizable ID, "main" is used in processing if no args provided
-- INPUTS & OUTPUTS are numbers 1-6, all input sides must be powered for outputs to turn on
-- For example, left & right need to be on for front & back to be enabled:
--     main 34 56
-- Each rule can be remotely pulsed (with `remman.lua`), & locked/unlocked which disallows it to be output

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
            if ruleSet.enabled then
                active = true

                for _, sideIn in pairs(ruleSet.inputs) do
                    if not redstone.getInput(sideIn) or sides[sideIn] ~= -3 then
                        active = false
                        break
                    end
                end

                if active then
                    for _, sideOut in pairs(ruleSet.outputs) do
                        sides[sideOut] = math.max(sides[sideOut], 0)
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

        if command[1] == "rules" then
            os.queueEvent("comms_send", rules, replyChain)

        elseif command[1] == "sides" then
            os.queueEvent("comms_send", sides, replyChain)

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


multishell.setTitle(multishell.getCurrent(), "RedMan 1.1")
parallel.waitForAny(redstoneLoop, remoteLoop)
