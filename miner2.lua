-- Simple, local-coordinate-based miner that interfaces with `remman.lua`
-- Mines a square (starting back-left) determined by the "diameter", down "depth" blocks
-- Also deposits items to a container just above its starting position
-- Will automatically return back to its start pos if its fuel gets low or it can't mine a block
-- Will stop the program only at its start pos if it has no fuel or can't deposit its items
-- Can be stopped & its local position queried via terminal, modem, or chat (see `remman.lua`)

args = {...}

command = nil
replyChain = nil
chatBroadcast = {{"modem", "minercontroller"}, {"chat"}}

canRefuel = true

useless = {
    "minecraft:stone",
    "minecraft:cobblestone",
    "minecraft:diorite",
    "minecraft:andesite",
    "minecraft:granite",
    "minecraft:dirt",
    "minecraft:gravel",
    "minecraft:netherrack",
    "minecraft:tuff",
    "minecraft:cobbled_deepslate",
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
        logMsg({status="error", reason="moving out of range"})
        return false
    end
    
    if turtle.forward() then
        pos = getMovePos()
        return true
    end
    
    logMsg({status="error", reason="cannot move"})
    return false
end

function willMoveOOR ()
    movePos = getMovePos()
    
    return movePos[1] < 1 or movePos[1] > diameter or movePos[2] < 1 or movePos[2] > diameter
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
    -- logMsg({status="emptying useless"})
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
        if count > 1 and turtle.refuel(count / 2) then
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
    keepItems = {["minecraft:coal"] = true, ["minecraft:charcoal"] = true, ["minecraft:blaze_rod"] = true}
    
    for slot = 1, 16 do
        turtle.select(slot)
        item = turtle.getItemDetail()
        if item ~= nil then
            if keepItems[item.name] then
                keepItems[item.name] = false
            elseif not turtle.dropUp() then
                return false
            end
        end
    end

    return true
end

function withdrawFuel ()
    fuel = "minecraft:blaze_rod"
    chest = peripheral.wrap("top")

    if chest then
        fuelItem = chest.getItemDetail(1)
        if fuelItem and fuelItem.name == fuel then
            toTake = 64

            for slot = 1, 16 do
                turtle.select(slot)
                item = turtle.getItemDetail()
                if item and item.name == fuel then
                    toTake = toTake - item.count
                    break
                end
            end

            turtle.suckUp(math.min(fuelItem.count, toTake))
            return true
        end
    end

    return false
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
    f.write(f, diameter .. " " .. targetDepth .. " " .. depth)
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
    
    diameter = tonumber(sessionargs[1]) or error("Corrupted session data (diameter)")
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
                        logMsg({status="returning", reason="offloading"})
                        break
                    end
                end
            end
            
            if turtle.getFuelLevel() <= depth + diameter * 2 then
                if not refuelAny() then
                    if canRefuel then
                        logMsg({status="returning", reason="low fuel"})
                    else
                        logMsg({status="finishing", reason="low fuel"})
                        running = false
                    end
                    break
                end
            end
            
            turtle.select(1)
            if turtle.detect() and not turtle.dig() then
                logMsg({status="finishing", reason="cannot break"})
                running = false
                break
            end
            move()
            
            turnDir = 0
            if pos[2] == diameter then
                turnDir = -1
            elseif pos[2] == 1 then
                turnDir = 1
            end
            turnDir = turnDir * orientation
            
            turn(turnDir)
            
            oor = getMovePos()
            if oor[1] > diameter or oor[1] < 1 then
                turn(turnDir)
                
                if depth + 1 == targetDepth then
                    logMsg({status="finishing", reason="done"})
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

        refuelAny()
        if canRefuel and not withdrawFuel() then
            logMsg({status="error", reason="cannot withdraw fuel"})
            running = false
        end

        if not deposit() then
            logMsg({status="error", reason="cannot offload"})
            running = false
        end
    end
    
    logMsg({status="finished"})
    waitForLoop = false
end

function parseCommands ()
    while true do
        _, replyChain, command = os.pullEvent("comms_receive")
        
        if command[1] == "stop" then
            logMsg({status="finishing", reason="command"})
            -- saveSession()
            running = false
        elseif command[1] == "pos" then
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
    diameter = tonumber(args[1])
    targetDepth = tonumber(args[2])
    depth = tonumber(args[3]) or 0
else
    loadSession()
end

if diameter == nil or targetDepth == nil or depth == nil then
    error("miner.lua <diameter> <target depth> [starting depth]\n      ... resume")
end

logMsg({status="starting", diameter=diameter, targetDepth=targetDepth, startingDepth=depth})
parallel.waitForAny(main, parseCommands)
