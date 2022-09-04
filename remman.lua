-- Config
local useChannel = 256
local chatWhitelist = {"64_Tesseract", "IEATDIRT52"}

local modem = peripheral.find("modem")
local chat = peripheral.find("chatBox")

if not modem and not chat then error("No modems attached") end

if modem then modem.open(256) end


-- CUSTOM EVENTS
-- "comms_receive"
-- 2: replyChain
-- 3: data
--
-- "comms_send"
-- 2: data
-- 3: destination

function eventLoop ()
    while true do
        local event = {os.pullEvent()}
        local eventType = event[1]

        if eventType == "modem_message" then
            if event[5].destination[2] == tostring(os.computerID()) or event[5].destination[2] == os.computerLabel() then
                table.remove(event[5].destination, 1)
                parseComms(event[5].replyChain, event[5].data, event[5].destination)
            end

        elseif eventType == "chat" then
            if contains(chatWhitelist, event[2]) then
                -- Split chat arguments by spaces
                local args = {}
                for arg in string.gmatch(event[3], "[^%s]+") do
                    table.insert(args, arg)
                end

                -- First chat argument is destination, check if this computer is targeted
                if args[1] == tostring(os.computerID()) or (os.computerLabel() and args[1] == os.computerLabel()) then
                    table.remove(args, 1)
                    parseComms({{"chat", event[5] or event[2]}}, args, {})
                end
            end

        elseif eventType == "comms_send" then
            send_message({}, event[2], event[3])
        end
    end
end


function parseComms (replyChain, data, destination)
    if table.maxn(destination) ~= 0 then  -- There are more destinations to forward to
        sendMessage(replyChain, data, destination)

    else  -- No more destinations means this is the targeted computer
        if data[1] == "to" then  -- Player forwarding commands ("0 to 1 to 2")
            local nextComputer = data.cmd[2]  -- Getting destination from "to ID"
            table.remove(data, 1)  -- Remove "to" command
            table.remove(data, 1)  -- Remove destination from data
            sendMessage(replyChain, data, {{"modem", nextComputer}})

        elseif data[1] == "info" then  -- Print info about computer
            local info = {id=os.computerID(), label=os.computerLabel(), processes={}}

            local position = gps.locate()
            if position then
                local pos
                pos.x, pos.y, pos.z = position
                info.position = pos
            end

            if turtle then info.fuel = turtle.getFuelLevel() end

            for p = 1,multishell.getCount() do
                table.insert(info.processes, multishell.getTitle(p))
            end

            sendMessage({}, info, replyChain)

        else  -- Command unknown, pass data as event
            os.queueEvent("comms_receive", replyChain, data)
        end
    end
end


function sendMessage (replyChain, data, destination)
    print("Sending message")
    print("Destination: " .. stringifyTable(destination))
    if destination[1][1] == "chat" then
        if chat then
            local message = stringifyTable(data)
            local prefix = os.computerLabel() and (os.computerLabel() .. " (" .. tostring(os.computerID() .. ")")) or tostring(os.computerID())
            if destination[1][2] == true then
                for _, player in ipairs(chatWhitelist) do
                    chat.sendMessageToPlayer(message, player, prefix)
                end
            else
                chat.sendMessageToPlayer(message, destination[1][2], prefix)
            end
        else
            io.stderr:write("Cannot send chat message!")
        end

    elseif destination[1][1] == "modem" then
        if modem then
            table.insert(replyChain, 1, {"modem", tostring(os.computerID)})
            modem.transmit(useChannel, useChannel, {replyChain=replyChain, data=data, destination=destination})
        else
            io.stderr:write("Cannot send modem message!")
        end
    end
end


function stringifyTable (table, tab)
    if tab == nil then tab = 0 end
    local message = ""

    for key, val in pairs(table) do
        message = message .. "\n:"
        for t = 1,tab do message = message .. "    " end

        message = message .. key .. " =" .. (type(val) == "table" and stringifyTable(val, tab + 1) or " " .. tostring(val))
    end

    return message
end


function contains (table, value)
    for _, v in pairs(table) do
        if value == v then return true end
    end

    return false
end


multishell.setTitle(multishell.getCurrent(), "RemCommsMan")
eventLoop()
