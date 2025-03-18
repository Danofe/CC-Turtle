local modemSide = "left"
local chestSide = "below"
local fuelThreshold = 150
local mineDepth = 160
local branchInterval = 4
local branchLength = 10
local mainTunnelLength = 60

rednet.open(modemSide)

local initialX, initialY, initialZ = 0, 0, 0
local startX, startY, startZ = 0, 0, 0
local currentX, currentY, currentZ = 0, 0, 0
local currentDirection = 0
local lastX, lastY, lastZ = 0, 0, 0

local dbFile = "turtle_db.txt"
local turtleLabel = "Ahmed"

local function savePositionToDB()
    local file = fs.open(dbFile, "w")
    if file then
        file.writeLine(turtleLabel)
        file.writeLine(currentX)
        file.writeLine(currentY)
        file.writeLine(currentZ)
        file.close()
    else
        sendLog("Failed to save position to database!")
    end
end

local function loadPositionFromDB()
    if not fs.exists(dbFile) then
        local file = fs.open(dbFile, "w")
        if file then
            file.writeLine(turtleLabel)
            file.writeLine(currentX)
            file.writeLine(currentY)
            file.writeLine(currentZ)
            file.close()
        else
            sendLog("Failed to create database file!")
        end
    else
        local file = fs.open(dbFile, "r")
        if file then
            turtleLabel = file.readLine()
            currentX = tonumber(file.readLine())
            currentY = tonumber(file.readLine())
            currentZ = tonumber(file.readLine())
            file.close()
        else
            sendLog("Failed to read database file!")
        end
    end
end

local computerID = 3

local function sendLog(message)
    if computerID then
        rednet.send(computerID, message)
    end
    print(message)
end

local function updatePosition(dx, dy, dz)
    currentX = currentX + dx
    currentY = currentY + dy
    currentZ = currentZ + dz
    savePositionToDB()
    sendLog("Position: (" .. currentX .. ", " .. currentY .. ", " .. currentZ .. ")")
end

local function turnTo(targetDirection)
    while currentDirection ~= targetDirection do
        turtle.turnRight()
        currentDirection = (currentDirection + 1) % 4
        sendLog("Turned to direction: " .. currentDirection)
    end
end

local function moveForward()
    while not turtle.forward() do
        if turtle.detect() then
            turtle.dig()
            sendLog("Block detected. Digging...")
        else
            sendLog("Obstacle in the way. Waiting...")
            sleep(1)
        end
    end
    if currentDirection == 0 then
        updatePosition(1, 0, 0)
    elseif currentDirection == 1 then
        updatePosition(0, 0, 1)
    elseif currentDirection == 2 then
        updatePosition(-1, 0, 0)
    elseif currentDirection == 3 then
        updatePosition(0, 0, -1)
    end
end

local function moveUp()
    while not turtle.up() do
        if turtle.detectUp() then
            turtle.digUp()
            sendLog("Block above. Digging...")
        else
            sendLog("Obstacle above. Waiting...")
            sleep(1)
        end
    end
    updatePosition(0, 1, 0)
end

local function moveDown()
    while not turtle.down() do
        if turtle.detectDown() then
            turtle.digDown()
            sendLog("Block below. Digging...")
        else
            sendLog("Obstacle below. Waiting...")
            sleep(1)
        end
    end
    updatePosition(0, -1, 0)
end

local function ensureCoalInSlot1()
    if turtle.getItemCount(1) > 0 and turtle.getItemDetail(1).name == "minecraft:coal" then
        return true
    end

    for slot = 2, 16 do
        if turtle.getItemCount(slot) > 0 and turtle.getItemDetail(slot).name == "minecraft:coal" then
            turtle.select(slot)
            turtle.transferTo(1)
            sendLog("Moved coal to slot 1.")
            return true
        end
    end

    sendLog("No coal found in inventory!")
    return false
end

local function refuel()
    if turtle.getFuelLevel() < fuelThreshold then
        sendLog("Low fuel. Attempting to refuel...")
        if ensureCoalInSlot1() then
            turtle.select(1)
            if turtle.refuel(1) then
                sendLog("Refueled using coal in slot 1.")
                return true
            else
                sendLog("Failed to refuel! No coal available.")
                return false
            end
        else
            sendLog("No coal available to refuel! Stopping.")
            return false
        end
    end
    return true
end

local function returnToInitialPosition()
    sendLog("Returning to initial position...")
    while currentY > initialY do
        moveDown()
    end
    while currentY < initialY do
        moveUp()
    end
    if currentX > initialX then
        turnTo(2)
        while currentX > initialX do
            moveForward()
        end
    elseif currentX < initialX then
        turnTo(0)
        while currentX < initialX do
            moveForward()
        end
    end
    if currentZ > initialZ then
        turnTo(3)
        while currentZ > initialZ do
            moveForward()
        end
    elseif currentZ < initialZ then
        turnTo(1)
        while currentZ < initialZ do
            moveForward()
        end
    end
    turnTo(0)
    sendLog("Returned to initial position.")
end

local function isChestFull()
    turtle.select(1)
    if not turtle.drop(0) then
        sendLog("Chest is full. Waiting...")
        return true
    end
    return false
end

local function unloadInventory()
    sendLog("Inventory full. Returning to initial position to unload...")
    returnToInitialPosition()
    if isChestFull() then
        sendLog("Chest is full. Stopping.")
        return false
    end
    for slot = 1, 16 do
        turtle.select(slot)
        if turtle.getItemCount(slot) > 0 then
            turtle.drop()
            sendLog("Unloaded slot " .. slot)
        end
    end
    turtle.select(1)
    sendLog("Inventory unloaded.")
    return true
end

local function isInventoryFull()
    for slot = 1, 16 do
        if turtle.getItemCount(slot) == 0 then
            return false
        end
    end
    return true
end

local function mineBlock()
    if turtle.detect() then
        turtle.dig()
        sendLog("Mined block.")
    end
    if turtle.detectUp() then
        turtle.digUp()
        sendLog("Mined block above.")
    end
    if turtle.detectDown() then
        turtle.digDown()
        sendLog("Mined block below.")
    end
end

local function mineTunnel(length)
    for i = 1, length do
        if not refuel() then
            sendLog("Out of fuel. Stopping.")
            error("Out of fuel.")
        end
        mineBlock()
        moveForward()
        if isInventoryFull() then
            lastX, lastY, lastZ = currentX, currentY, currentZ
            if not unloadInventory() then
                sendLog("Chest is full. Stopping.")
                break
            end
            returnToLastMiningPosition()
        end
    end
end

local function mineBranch(length)
    turnTo(1)
    mineTunnel(length)
    turnTo(3)
    mineTunnel(length)
    turnTo(1)
end

local function mineDownToDepth(depth)
    sendLog("Mining down to depth " .. depth .. "...")
    for i = 1, depth do
        if not refuel() then
            sendLog("Out of fuel. Stopping.")
            error("Out of fuel.")
        end
        mineBlock()
        moveDown()
    end
    sendLog("Reached depth " .. depth .. ".")
end

local function returnToLastMiningPosition()
    sendLog("Returning to last mining position...")
    while currentY > lastY do
        moveDown()
    end
    while currentY < lastY do
        moveUp()
    end
    if currentX > lastX then
        turnTo(2)
        while currentX > lastX do
            moveForward()
        end
    elseif currentX < lastX then
        turnTo(0)
        while currentX < lastX do
            moveForward()
        end
    end
    if currentZ > lastZ then
        turnTo(3)
        while currentZ > lastZ do
            moveForward()
        end
    elseif currentZ < lastZ then
        turnTo(1)
        while currentZ < lastZ do
            moveForward()
        end
    end
    turnTo(0)
    sendLog("Returned to last mining position.")
end

local function startMining()
    sendLog("Starting mining operation...")
    initialX, initialY, initialZ = currentX, currentY, currentZ
    startX, startY, startZ = currentX, currentY, currentZ

    moveForward()
    sendLog("Moved forward one block before mining down.")

    mineDownToDepth(mineDepth)
    for i = 1, mainTunnelLength do
        mineTunnel(1)
        if i % branchInterval == 0 then
            mineBranch(branchLength)
        end
        sendLog("Mining cycle complete.")
        sleep(1)
    end
end

print("Turtle ready for commands...")
sendLog("Turtle is online.")

loadPositionFromDB()

while true do
    computerID, message = rednet.receive()

    if type(message) == "table" then
        if message.type == "command" then
            sendLog("Executing: " .. message.data)

            if message.data == "start" then
                startMining()
            elseif message.data == "stop" then
                sendLog("Stopping mining operation.")
                error("Stopped by command.")
            elseif message.data == "return" then
                returnToInitialPosition()
            else
                local func, err = load("return " .. message.data, "command", "t", _ENV)
                if not func then
                    func, err = load(message.data, "command", "t", _ENV)
                end

                if func then
                    local success, result = pcall(func)
                    if success then
                        sendLog("Success: " .. tostring(result or ""))
                    else
                        sendLog("Error: " .. result)
                    end
                else
                    sendLog("Invalid command: " .. err)
                end
            end

        elseif message.type == "file" then
            local file = fs.open(message.name, "w")
            if file then
                file.write(message.data)
                file.close()
                sendLog("Received file: " .. message.name)

                local success, err = pcall(function() shell.run(message.name) end)
                if success then
                    sendLog("Executed file: " .. message.name)
                else
                    sendLog("Execution error: " .. err)
                end
            else
                sendLog("Failed to save file!")
            end
        end
    end
end
