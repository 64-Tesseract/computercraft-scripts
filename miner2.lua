args = {...}

command = nil
replyChain = nil
chatBroadcast = {{"modem", "2"}, {"chat", true}}

useless = {
    "minecraft:stone",
    "minecraft:cobblestone",
    "minecraft:diorite",
    "minecraft:andesite",
    "minecraft:granite",
    "minecraft:dirt",
    "minecraft:gravel",
    "minecraft:netherrack",
    "allure:root_item"
}

angles = {{1, 0}, {0, 1}, {-1, 0}, {0, -1}}
pos = {1, 1}
dir = 1
orientation = 1
running = true
waitForLoop = true

function turn (lr)
    if lr == 1 then
        turtle.turnLeft()
    elseif lr == -1 then
        turtle.turnRight()
    else
        return
    end
    
    dir = mod2(dir + lr, 4)
end

function move ()
    if willMoveOOR() then
        logMsg("Tried to move out of range")
        return false
    end
    
    if turtle.forward() then
        pos = getMovePos()
        return true
    end
    
    logMsg("Cannot move")
    return false
end

function willMoveOOR ()
    movePos = getMovePos()
    
    return movePos[1] < 1 or movePos[1] > radius or movePos[2] < 1 or movePos[2] > radius
end

function getMovePos (lr)
    rot = getRot(lr)
    return {pos[1] + rot[1], pos[2] + rot[2]}
end

function getRot (lr)
    if lr == nil then
        lr = 0
    end
    return angles[mod2(dir + lr, 4) + 1]
end

function mod2 (val, max)
    while val >= max do
        val = val - max
    end
    while val < 0 do
        val = val + max
    end
    return val
end

function dropUseless ()
    logMsg("Emptying useless")
    emptiedAny = false
    for slot = 1, 16 do
        turtle.select(slot)
        item = turtle.getItemDetail()
        
        if item ~= nil then
            if tableContains(useless, item.name) then
                turtle.dropDown()
                emptiedAny = true
            end
        end
    end
    return emptiedAny
end

function tableContains (tbl, val)
    index = 1
    while true do
        if tbl[index] == nil then
            return false
        end
        
        if tbl[index] == val then
            return true
        end
        
        index = index + 1
    end
end

function refuelAny ()
    for slot = 1, 16 do
        turtle.select(slot)
        count = turtle.getItemCount()
        if count > 1 and turtle.refuel(count - 1) then
            return true
        end
    end
    return false
end

function hasSpace ()
    for slot = 1, 16 do
        turtle.select(slot)
        if turtle.getItemCount() == 0 then
            return true
        end
    end
    
    return false
end

function deposit ()
    keepItems = {["minecraft:coal"] = 1, ["minecraft:charcoal"] = 1}
    
    for slot = 1, 16 do
        turtle.select(slot)
        item = turtle.getItemDetail()
        if item ~= nil then
            if keepItems[item.name] == 1 then
                keepItems[item.name] = 0
            elseif not turtle.dropUp() then
                return false
            end
        end
    end
    return true
end

function dist (a, b)
    return math.sqrt((a[1] - b[1]) ^ 2 + (a[2] - b[2]) ^ 2)
end

function turnTo (toDir)
    toDir = mod2(toDir, 4)
    while dir ~= toDir do
        if dir == mod2(toDir - 1, 4) then
            turn(1)
        else
            turn(-1)
        end
    end
end

function moveTo (toPos)
    while pos[1] ~= toPos[1] or pos[2] ~= toPos[2] do
        moving = false
        for a = 1, 3 do
            lr = a % 3 - 1
            if dist(getMovePos(lr), toPos) < dist(pos, toPos) then
                turn(lr)
                if move() then
                    moving = true
                    break
                end
            end
        end
        if not moving then
            turn(1)
        end
    end
end

function saveSession ()
    f = io.open("miner.session", "w")
    f.write(f, radius .. " " .. targetDepth .. " " .. depth)
    f.close(f)
end

function loadSession ()
    if not fs.exists("miner.session") then
        error("Cannot find session to resume from")
    end
    
    f = io.open("miner.session", "r")
    sessionargs = {}
    for arg in string.gmatch(f.read(f), "[^ ]+") do
        table.insert(sessionargs, arg)
    end
    f.close(f)
    
    radius = tonumber(sessionargs[1]) or error("Corrupted session data (radius)")
    targetDepth = tonumber(sessionargs[2]) or error("Corrupted session data (target depth)")
    depth = tonumber(sessionargs[3]) or error("Corrupted session data (starting depth)")
end

function main ()
    while running do
        if depth ~= 0 then
            turtle.select(1)
            for height = 1, depth do
                turtle.digDown()
                turtle.down()
            end
        end
        orientation = 1
        
        while running do
            turtle.select(1)
            
            block, infront = turtle.inspect()
            if block and not tableContains(useless, infront.name) then
                if not hasSpace() then
                    if not dropUseless() then
                        logMsg({status="returning to offload"})
                        break
                    end
                end
            end
            
            if turtle.getFuelLevel() <= depth + radius * 2 then
                if not refuelAny() then
                    logMsg({status="low on fuel"})
                    running = false
                    break
                end
            end
            
            turtle.select(1)
            if turtle.detect() and not turtle.dig() then
                logMsg({status="cannot break block"})
                running = false
                break
            end
            move()
            
            turnDir = 0
            if pos[2] == radius then
                turnDir = -1
            elseif pos[2] == 1 then
                turnDir = 1
            end
            turnDir = turnDir * orientation
            
            turn(turnDir)
            
            oor = getMovePos()
            if oor[1] > radius or oor[1] < 1 then
                turn(turnDir)
                
                if depth + 1 == targetDepth then
                    logMsg({status="reached bottom"})
                    running = false
                    saveSession()
                    break
                end
                
                dropUseless()
                turtle.digDown()
                turtle.down()
                depth = depth + 1
                
                saveSession()
                
                orientation = orientation * -1
            end
        end
        
        if depth ~= 0 then
            for height = 1, depth do
                turtle.digUp()
                turtle.up()
            end
        end
        
        dropUseless()
        moveTo({1, 1})
        turnTo(1)
        if not deposit() then
            logMsg({status="cannot offload"})
            running = false
            break
        end
    end
    
    logMsg({status="finished", pos={x=pos[1], z=pos[2]}})
    waitForLoop = false
end

function getLocalInput ()
    local text = io.read()
    command = {}
    for arg in string.gmatch(text, "[^%s]+") do
        table.insert(command, arg)
    end
end

function getRemoteInput ()
    _, replyChain, command = os.pullEvent("comms_receive")
end

function parseCommands ()
    if modem then modem.open(listenChannel) end
    while true do
        parallel.waitForAny(getLocalInput, getRemoteInput)
        
        if command[0] == "stop" then
            logMsg({status="stopping"})
            -- saveSession()
            running = false
        elseif command[0] == "pos" then
            logMsg({position={x=pos[1], z=pos[2], level=depth}})
        end

        command = nil
        replyChain = nil
    end
    
    while waitForLoop do
        sleep(1)
    end
end

function logMsg (msg)
    os.queueEvent("comms_send", msg, replyChain or chatBroadcast)
end

if args[1] ~= "resume" then
    radius = tonumber(args[1])
    targetDepth = tonumber(args[2])
    depth = tonumber(args[3]) or 0
else
    loadSession()
end

if radius == nil or targetDepth == nil or depth == nil then
    error("miner.lua <radius> <target depth> [starting depth]\n      ... resume")
end

logMsg({status="starting", radius=radius, targetDepth=targetDepth, startingDepth=depth})
parallel.waitForAny(main, parseCommands)
