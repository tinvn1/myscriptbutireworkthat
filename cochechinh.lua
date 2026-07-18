-- -- Made by TheAnonymous in RScript / Theultimateuser in Scriptblox
-- SỬA LỖI: Fix lỗi nhân vật tự lên cao bằng mặt đất rồi mới di chuyển ở phần 3

print("Loading")
 
if not game:IsLoaded() then
    game.Loaded:Wait()
end
 
local ContentProvider = game:GetService("ContentProvider")
while ContentProvider.RequestQueueSize > 0 do
    task.wait(0.5)
end
 
print("The game is loaded in. Wait more for things to fully load")
task.wait(6.0)
print("Complete! Starting the farm.")
 
-- SERVICES --
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
 
-- --- CONFIGURATION & REFERENCES ---
local LocalPlayer = Players.LocalPlayer
local MapFolder = Workspace:FindFirstChild("Map")
local DroppedItemsFolder = Workspace:WaitForChild("DroppedItems")
local AdjustBackpackRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Tools"):WaitForChild("AdjustBackpack")
 
local cachedGeneratorLocation = nil
local PermanentNoclipEnabled = true
 
-- --- Safety First Lads ---
local function evacuateServer(reason)
    warn("[CRITICAL EVACUATION]: " .. reason)
    task.spawn(function()
        local PlayAgainRemote = ReplicatedStorage:FindFirstChild("Remotes") 
            and ReplicatedStorage.Remotes:FindFirstChild("Misc") 
            and ReplicatedStorage.Remotes.Misc:FindFirstChild("VotePlayAgain")

        if PlayAgainRemote and PlayAgainRemote:IsA("RemoteEvent") then
            pcall(function()
                PlayAgainRemote:FireServer()
            end)
            print("ESCAPING BY PLAYING AGAIN")
            task.wait(1.0)
        end
        LocalPlayer:Kick("[WARNING] UNKNOWN PLAYER DETECTED!")
    end)
    error("Script execution terminated.")
end

if #Players:GetPlayers() > 1 then
    evacuateServer("Pre-existing player DETECTED!")
end

Players.PlayerAdded:Connect(function(newPlayer)
    if newPlayer ~= LocalPlayer then
        evacuateServer("Player entry detected (" .. newPlayer.Name .. "). Executing immediate escape.")
    end
end)
 
-- --- BACKGROUND SERVICE: PERMANENT NOCLIP ENGINE ---
local function StartPermanentNoclip()
    local noclipConnection = nil
 
    local function ConnectNoclip()
        if noclipConnection then noclipConnection:Disconnect() end
 
        noclipConnection = RunService.Stepped:Connect(function()
            if not PermanentNoclipEnabled then
                if noclipConnection then noclipConnection:Disconnect() end
                return
            end
 
            local character = LocalPlayer.Character
            if character then
                for _, child in ipairs(character:GetDescendants()) do
                    if child:IsA("BasePart") and child.CanCollide then
                        child.CanCollide = false
                    end
                end
 
                local hrp = character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                end
            end
        end)
    end
 
    ConnectNoclip()
 
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.1)
        ConnectNoclip()
    end)
end

StartPermanentNoclip()
 
local excludeFuel = {}

local function getClosestFuelPosition(currentPos)
    local foundValidFuel = nil
    
    while not foundValidFuel do
        local bestTarget = nil
        local shortestDistance = math.huge
        
        if DroppedItemsFolder then
            for _, item in ipairs(DroppedItemsFolder:GetChildren()) do
                if item.Name == "Fuel" then
                    if not excludeFuel[item] then
                        local fuelPos = item:GetPivot().Position
                        local dist = (currentPos - fuelPos).Magnitude
                        
                        if dist < shortestDistance then
                            shortestDistance = dist
                            bestTarget = item
                        end
                    end
                end
            end
        end
        
        if not bestTarget then
            break
        end
        
        local targetPosition = bestTarget:GetPivot().Position
        local heightDifference = targetPosition.Y - currentPos.Y
        
        if heightDifference <= 2 then
            foundValidFuel = bestTarget
        else
            print("[-] Fuel anomaly detected at height: " .. tostring(targetPosition.Y) .. ". Excluding item.")
            excludeFuel[bestTarget] = true
        end
    end
    
    return foundValidFuel
end
 
local function getGeneratorPosition()
    if cachedGeneratorLocation then return cachedGeneratorLocation end
    if MapFolder then
        local tiles = MapFolder:FindFirstChild("Tiles")
        if tiles then
            for _, child in ipairs(tiles:GetChildren()) do
                if child.Name == "Generator" or child:FindFirstChild("Generator") then
                    cachedGeneratorLocation = child:GetPivot().Position
                    return cachedGeneratorLocation
                end
            end
        end
    end
    local fallbackGen = Workspace:FindFirstChild("Generator", true)
    if fallbackGen then
        cachedGeneratorLocation = fallbackGen:GetPivot().Position
        return cachedGeneratorLocation
    end
    return nil
end

local function FuelTeleport(hrp, targetFuel)
    local generatorLoc = getGeneratorPosition()
    if not hrp or not targetFuel or not generatorLoc then return end

    local fuelUnion = targetFuel:FindFirstChild("Union") or targetFuel.PrimaryPart
    local itemDrag = targetFuel:FindFirstChild("ItemDrag")
    local networkRemote = itemDrag and itemDrag:FindFirstChild("RequestNetworkOwnership")

    if fuelUnion and networkRemote then
        pcall(function()
            networkRemote:FireServer(fuelUnion)
        end)
        
        task.wait(0.12) 

        pcall(function()
            targetFuel:PivotTo(CFrame.new(generatorLoc) + Vector3.new(0, 1, 0))
        end)
        
        task.wait(0.15) 
    end
end

-- TRAVEL COMPONENT (Đã cập nhật tham số ignoreLockY để sửa lỗi Phần 3)
local function adaptiveCrawlTo(targetPos, humanoidRootPart, character, ignoreLockY)
    local finalTarget = targetPos + Vector3.new(0, 3, 0)
 
    local FAST_SPEED = 25      
    local SLOW_SPEED = 8       
    local STEP_DISTANCE = 0.25 
 
    local CLEARANCE_COOLDOWN = 0.5 
    local lastWallDetectedTime = 0
 
    local lockedYHeight = humanoidRootPart.Position.Y
 
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {character} 
 
    while true do
        if not humanoidRootPart or not humanoidRootPart.Parent then break end
        local currentPos = humanoidRootPart.Position
        
        -- Nếu ignoreLockY = true, đi chéo thẳng tới mục tiêu (bao gồm cả độ cao Y mong muốn)
        local flatTarget = ignoreLockY and finalTarget or Vector3.new(finalTarget.X, lockedYHeight, finalTarget.Z)
        local remainingVector = flatTarget - currentPos
        local totalDistance = remainingVector.Magnitude
 
        if totalDistance <= 2 or totalDistance <= STEP_DISTANCE then
            humanoidRootPart.CFrame = CFrame.new(finalTarget)
            humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, -5, 0) 
            humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
 
            humanoidRootPart.Anchored = true
            task.wait(0.05)
            humanoidRootPart.Anchored = false 
            break
        end
 
        local direction = remainingVector.Unit
        local lookAheadDistance = 5
        local rayResult = Workspace:Raycast(currentPos, direction * lookAheadDistance, raycastParams)
 
        if rayResult and rayResult.Instance and rayResult.Instance.CanCollide then
            lastWallDetectedTime = os.clock()
        end
 
        local activeStepDistance = 0.25 
        local currentAllowedSpeed = SLOW_SPEED
        if os.clock() - lastWallDetectedTime >= CLEARANCE_COOLDOWN then
            activeStepDistance = 1.0  
            currentAllowedSpeed = FAST_SPEED
        end
 
        local delayInterval = activeStepDistance / currentAllowedSpeed
        local nextPosition = currentPos + (direction * activeStepDistance)
        
        -- Tính toán vị trí tiếp theo dựa trên cấu hình Y mong muốn
        local nextCFramePosition = ignoreLockY and nextPosition or Vector3.new(nextPosition.X, lockedYHeight, nextPosition.Z)
 
        humanoidRootPart.CFrame = CFrame.new(nextCFramePosition)
        task.wait(delayInterval)
    end
end
 
-- --- PIPELINE EXECUTION ENGINE ---
local function runPipeline()
    print("Free and Keyless, script is in https://pastebin.com/V0wHqZe4")
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
 
    print("[Pipeline] Initiating Complete Sequence...")
    task.wait(0.3)
 
    -- STEP 1: Nearest Fuel Remote Teleport
    local fuelOne = getClosestFuelPosition(humanoidRootPart.Position)
    if fuelOne then
        print("[Step 1] Moving to first closest fuel.")
        adaptiveCrawlTo(fuelOne:GetPivot().Position, humanoidRootPart, character, false)
        task.wait(0.3)
        FuelTeleport(humanoidRootPart, fuelOne)
        task.wait(0.5)
    end
 
    -- STEP 2: Second Nearest Fuel Remote Teleport
    local fuelTwo = getClosestFuelPosition(humanoidRootPart.Position)
    if fuelTwo then
        print("[Step 2] Moving to second closest fuel.")
        adaptiveCrawlTo(fuelTwo:GetPivot().Position, humanoidRootPart, character, false)
        task.wait(0.3)
        FuelTeleport(humanoidRootPart, fuelTwo)
        task.wait(0.5)
    end
 
    -- STEP 3: OPTIMIZED POWER BOX QUERY & TRACKING
    print("[Step 3] Scanning for closest Power Box model...")
    local chosenBox = nil
    local finalBoxTarget = nil
    local shortestBoxDistance = math.huge
    local currentPos = humanoidRootPart.Position
 
    if MapFolder and MapFolder:FindFirstChild("Tiles") then
        local tiles = MapFolder.Tiles:GetChildren()
        for i = 1, #tiles do
            local child = tiles[i]
            if child.Name == "Power Plant" then
                local powerBox = child:FindFirstChild("Power Box")
                if powerBox and powerBox:IsA("Model") then
                    local boxPos = powerBox:GetPivot().Position
                    local dist = (currentPos - boxPos).Magnitude
                    if dist < shortestBoxDistance then
                        shortestBoxDistance = dist
                        chosenBox = powerBox
                        finalBoxTarget = boxPos
                    end
                end
            end
        end
    end
 
    local interactionSuccess = false
    if chosenBox and finalBoxTarget then
        print("[Step 3] Crawling directly to closest Power Box.")
        -- ĐÃ FIX: Thêm tham số `true` ở cuối để nhân vật di chuyển mượt mà thẳng tới mục tiêu mặt đất, không bị giật lên cao trước khi đi
        adaptiveCrawlTo(finalBoxTarget, humanoidRootPart, character, true)
        task.wait(0.3) 
 
        if (humanoidRootPart.Position - finalBoxTarget).Magnitude < 15 then
            local prompt = chosenBox:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt then
                for i = 1, 3 do
                    if fireproximityprompt then
                        fireproximityprompt(prompt)
                    -- Fallback nếu executor không có hàm fireproximityprompt công khai
                    else
                        prompt:InputHoldBegin()
                        task.wait(prompt.HoldDuration + 0.02)
                        prompt:InputHoldEnd()
                    end
                    task.wait(0.05)
                end
                print("[Pipeline] Interaction successfully forced!")
                interactionSuccess = true
            end
        end
    end
 
    -- --- VOTE PLAY AGAIN SEQUENCE ---
    task.wait(0.5) 
    if interactionSuccess then
        local PlayAgainRemote = ReplicatedStorage:FindFirstChild("Remotes") 
            and ReplicatedStorage.Remotes:FindFirstChild("Misc") 
            and ReplicatedStorage.Remotes.Misc:FindFirstChild("VotePlayAgain")
 
        if PlayAgainRemote and PlayAgainRemote:IsA("RemoteEvent") then
            pcall(function()
                PlayAgainRemote:FireServer()
            end)
            print("[Play Again] Sequence executed successfully.")
        else
            warn("[Warning] VotePlayAgain remote path could not be found.")
        end
        print("Free and Keyless, script is in https://pastebin.com/V0wHqZe4")
    end
end

runPipeline()

-- Watchdog Timer
task.spawn(function()
    task.wait(60.0) 
    
    local PlayAgainRemote = ReplicatedStorage:FindFirstChild("Remotes") 
        and ReplicatedStorage.Remotes:FindFirstChild("Misc") 
        and ReplicatedStorage.Remotes.Misc:FindFirstChild("VotePlayAgain")

    if PlayAgainRemote then
        print("[Watchdog Warning] Match timeout reached. Forcing server rotation.")
        pcall(function()
            PlayAgainRemote:FireServer()
        end)
    end
end)
