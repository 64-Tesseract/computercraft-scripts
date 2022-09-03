args = {...}

if table.maxn(args) < 1 or table.maxn(args) > 2 then
    error("terminal.lua <send channel> [listen channel]")
end

local modem = peripheral.find("modem")

if modem == nil then
    error("No modem found")
end

local listenChannel = tonumber(args[2]) or os.computerID()
local sendChannel = tonumber(args[1])

local xSize, ySize = term.getSize()
local textSize = ySize - 4

local commsText = listenChannel .. " -> " .. sendChannel
local commsOffset = math.floor((xSize - string.len(commsText)) / 2)

local messageHistory = {}
local scroll = 0
local sending = ""

function render ()
    term.clear()
    term.setCursorPos(commsOffset, 1)
    write(commsText)
    
    for m = 1, math.min(textSize, table.maxn(messageHistory)) do
        term.setCursorPos(1, ySize - m - 1)
        write(messageHistory[m + scroll])
    end
    
    term.setCursorPos(1, ySize)
    write("> " .. sending .. "_")
end

function addMessage (msg)
    while true do
        line = string.sub(msg, 1, xSize)
        msg = string.sub(msg, xSize + 1, string.len(msg))
        
        table.insert(messageHistory, 1, line)
        
        if msg == "" then break end
        msg = "    " .. msg
    end
end

function tryScroll (dir)
    if dir == -1 then
        if scroll + textSize < table.maxn(messageHistory) then scroll = scroll + 1 end
    elseif dir == 1 then
        if scroll > 0 then scroll = scroll - 1 end
    end
end

function processEvents ()
    while true do
        e = {os.pullEvent()}
        
        if e[1] == "char" then
            sending = sending .. e[2]
        elseif e[1] == "key" then
            key = keys.getName(e[2])
            if key == "backspace" then
                sending = string.sub(sending, 1, string.len(sending) - 1)
            elseif key == "enter" or key == "return" then
                addMessage(sending)
                modem.transmit(sendChannel, listenChannel, sending)
                sending = ""
            end
        elseif e[1] == "mouse_scroll" then
            tryScroll(e[2])
        elseif e[1] == "modem_message" then
            if e[3] == listenChannel then
                addMessage(e[5])
            end
        end
        
        render()
    end
end

modem.open(listenChannel)
processEvents()