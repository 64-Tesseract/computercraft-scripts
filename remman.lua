-- Universal remote communications manager - can interface with modem, local terminal, & chat box
-- Should run in the background with `bg`
-- Communication chain is passed in modem packets, so returned values are passed back to origin
-- Messages are received/sent with OS event queue
-- To return a message to origin, pass the reply chain as the destination

-- CUSTOM EVENTS
-- "comms_receive"
-- 2: replyChain
-- 3: data
--
-- "comms_send"
-- 2: data
-- 3: destination

-- Config
local useChannel = settings.get("remman.channel", 256)

local modem = peripheral.wrap(settings.get("remman.modemside", "")) or peripheral.find("modem")
local chat = peripheral.wrap(settings.get("remman.chatside", "")) or peripheral.find("chatBox")

if not modem and not chat then
    io.stderr:write("No modem nor chatbox attached!\n")
    return
end

if modem then modem.open(useChannel) end


function eventLoop ()
    while true do
        local event = {os.pullEvent()}
        local eventType = event[1]

        if eventType == "modem_message" then
            -- Ensure correct format is sent, otherwise arbitrary communication could crash the script
            if event[5].destination and event[5].replyChain and event[5].data and event[3] == useChannel then
                -- All modems receive the modem message which is the filtered manually, as destination may be its label
                if event[5].destination[1][2] == tostring(os.computerID()) or (os.computerLabel() and event[5].destination[1][2] == os.computerLabel()) then
                    table.remove(event[5].destination, 1)
                    parseComms(event[5].replyChain, event[5].data, event[5].destination)
                end
            end

        elseif eventType == "chat" then
            -- if contains(chatWhitelist, event[2]) then
            -- Split chat arguments by spaces
            local args = {}
            for arg in string.gmatch(event[3], "[^%s]+") do
                table.insert(args, arg)
            end

            -- First chat argument is destination, check if this computer is targeted
            if args[1] == tostring(os.computerID()) or (os.computerLabel() and args[1] == os.computerLabel()) then
                table.remove(args, 1)
                -- parseComms({{"chat", (not event[5]) or event[2]}}, args, {})
                parseComms({{"chat", event[5] and event[2] or nil}}, args, {})
            end
            -- end

        elseif eventType == "comms_send" then
            sendMessage({}, event[2], event[3])
        end
    end
end


function termInput ()
    while true do
        local text = io.read()
        local args = {}
        for arg in string.gmatch(text, "[^%s]+") do
            table.insert(args, arg)
        end

        parseComms({{"term"}}, args, {})
    end
end


function parseComms (replyChain, data, destination)
    if table.maxn(destination) ~= 0 then  -- There are more destinations to forward to
        sendMessage(replyChain, data, destination)

    else  -- No more destinations means this is the targeted computer
        if data[1] == "to" then  -- Player forwarding commands ("0 to 1 to 2")
            local nextComputer = data[2]  -- Getting destination ID from "to ID"
            table.remove(data, 1)  -- Remove "to" command
            table.remove(data, 1)  -- Remove destination from data
            sendMessage(replyChain, data, {{"modem", nextComputer}})

        elseif data[1] == "term" then  -- Sending data to a terminal
            table.remove(data, 1)  -- Remove "term" command
            sendMessage(replyChain, data, {{"term"}})  -- Set term to destination & send

        elseif data[1] == "info" then  -- Print info about computer
            local info = {id=os.computerID(), label=os.computerLabel(), processes={}}

            if modem then  -- Only get GPS is modem is attached
                local position = {gps.locate()}
                if position[1] then
                    local pos = {}
                    pos.x, pos.y, pos.z = table.unpack(position)
                    info.position = pos
                end
            end

            -- Only get fuel if is turtle
            if turtle then info.fuel = turtle.getFuelLevel() end

            for p = 1,multishell.getCount() do  -- List running programs
                table.insert(info.processes, multishell.getTitle(p))
            end

            sendMessage({}, info, replyChain)

        elseif data[1] == "exec" then  -- Start new process
            table.remove(data, 1)  -- Remove "exec" command
            processID = shell.openTab(table.unpack(data))  -- Run remaining arguments
            sendMessage({}, {id=processID}, replyChain)

        else  -- Command unknown, pass data as event
            os.queueEvent("comms_receive", replyChain, data)
        end
    end
end


function sendMessage (replyChain, data, destination)
    if destination[1][1] == "chat" then  -- Destination type is chat, send a chat message
        if chat then
            local message = textutils.serialize(data)
            local prefix = os.computerLabel() and (os.computerLabel() .. " (" .. tostring(os.computerID() .. ")")) or tostring(os.computerID())
            if not destination[1][2] then  -- Player == nil so request was public, send reply to all in whitelist
                -- for _, player in ipairs(chatWhitelist) do
                chat.sendMessage(message, prefix)
                -- end
            else  -- Request was private, send only to requesting player
                chat.sendMessageToPlayer(message, destination[1][2], "$" .. prefix)
            end
        else
            io.stderr:write("Cannot send chat message!\n")
        end

    elseif destination[1][1] == "modem" then  -- Destination type is modem, send a packet
        if modem then
            -- Add self to reply chain
            table.insert(replyChain, 1, {"modem", tostring(os.computerID())})
            modem.transmit(useChannel, useChannel, {replyChain=replyChain, data=data, destination=destination})
        else
            io.stderr:write("Cannot send modem message!\n")
        end

    elseif destination[1][1] == "term" then
        -- Destination type is terminal, print the data
        print(textutils.serialize(data))
        print()
    end
end


function contains (table, value)
    for _, v in pairs(table) do
        if value == v then return true end
    end

    return false
end


multishell.setTitle(multishell.getCurrent(), "RemMan 1.3")
parallel.waitForAny(eventLoop, termInput)
