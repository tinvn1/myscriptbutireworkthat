-- Made by TheAnonymous in RScript / Theultimateuser in Scriptblox

-- Feel free to adjust
-- The ultimate solo gem farming (Slapped some stuff with AI so no hate :) )
-- Remember to put this into auto-execution folder or smth, each run is completed in around 25-35 seconds so 2-2.4 gems/min
-- This is FREE and KEYLESS
-- You shall not copy this code and add key system on top of it for pure greediness. Don't be like Racky in Rscript where he tries to make money off from mine without adding new stuff LOL (seriously, add some unique stuff that makes it worth the trouble)
-- You can modify it and give credits, it's fine :PP

-- The script works like this: finds two fuels to upgrade the generator -> go fix the closest power plant (main way to get gem)
print("Loading")
 
if not game:IsLoaded() then
    game.Loaded:Wait()
end
 
local ContentProvider = game:GetService("ContentProvider")
while ContentProvider.RequestQueueSize > 0 do
    task.wait(0.5)
end
 
print("The game is loaded in. Wait more for things to fully load")
-- This is based on your pings so the finding fuel function doesn't break (adjust it to your liking)
task.wait(6.0)
print("Complete! Starting the farm.")
 
 
-- SERVICES --
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService") -- Thêm dịch vụ Tween
 
-- --- CONFIGURATION & REFERENCES ---
local LocalPlayer = Players.LocalPlayer
local MapFolder = Workspace:FindFirstChild("Map")
local DroppedItemsFolder = Workspace:WaitForChild("DroppedItems")
local AdjustBackpackRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Tools"):WaitForChild("AdjustBackpack")
 
local cachedGeneratorLocation = nil
local PermanentNoclipEnabled = true
 
-- --- Safety First Lads You gotta be the sneakiest to be the ultimate gem grinder ---
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
            task.wait(1.0) -- Waiting for the remote to work
        end
        
        -- 2. Forceful escape by getting kicked if the remote is slow as heck
        LocalPlayer:Kick("[WARNING] UNKNOWN PLAYER DETECTED!")
    end)
    
	-- Stops the script immediately
    error("Script execution terminated.")
end

-- Checking if there is mod already joined
if #Players:GetPlayers() > 1 then
    evacuateServer("Pre-existing player DETECTED!")
end
-- Hook live background radar listener for immediate exit on mid-game arrivals
Players.PlayerAdded:Connect(function(newPlayer)
    if newPlayer ~= LocalPlayer then
        evacuateServer("Player entry detected (" .. newPlayer.Name .. "). Executing immediate escape.")
    end
end)
 
-- --- BACKGROUND SERVICE: PERMANENT NOCLIP ENGINE (GIỮ NGUYÊN BẢN 100%) ---
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
                -- Instantly strips all collisions before physics steps process
                for _, child in ipairs(character:GetDescendants()) do
                    if child:IsA("BasePart") and child.CanCollide then
                        child.CanCollide = false
                    end
                end
 
                -- Zeroes velocity to stop anti-cheat rubberbanding
                local hrp = character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                end
            end
        end)
    end
 
    ConnectNoclip()
 
    -- Re-applies the permanent noclip loop whenever you respawn
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.1)
        ConnectNoclip()
    end)
end

StartPermanentNoclip()
 
-- Find the closest fuel's location
local excludeFuel = {}

local function getClosestFuelPosition(currentPos)
    local foundValidFuel = nil
    
    -- This loop will continuously retry until a valid item is found or none remain
    while not foundValidFuel do
        local bestTarget = nil
        local shortestDistance = math.huge
        
        if DroppedItemsFolder then
            for _, item in ipairs(DroppedItemsFolder:GetChildren()) do
                if item.Name == "Fuel" then
                    -- Check if this is in the exclusion table
                    if not excludeFuel[item] then
                        local fuelPos = item:GetPivot().Position
                        local dist = (currentPos - fuelPos).Magnitude
                        
                        -- Track the temporary closest item for this specific scan cycle
                        if dist < shortestDistance then
                            shortestDistance = dist
                            bestTarget = item
                        end
                    end
                end
            end
        end
        
        -- If no good fuel exist, uh we exit and everything breaks but this ain't happening I'm sure
        if not bestTarget then
            break
        end
        
        -- Checking if the fuel is on top of a tall object to ignore
        local targetPosition = bestTarget:GetPivot().Position
        local heightDifference = targetPosition.Y - currentPos.Y
        
        if heightDifference <= 2 then
            -- CRITERIA MET: Assign the item to exit the retry loop successfully
            foundValidFuel = bestTarget
        else
            -- CRITERIA FAILED: Add this specific item instance to the exclusion table
            print("[-] Fuel anomaly detected at height: " .. tostring(targetPosition.Y) .. ". Excluding item.")
            excludeFuel[bestTarget] = true
        end
    end
    
    -- Returns the item instance (or nil if the map is empty) to prevent unassigned runtime exceptions
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

-- The more overpowered version, it can literally teleport fuel to the generator (People gonna skid this thing hard trust me)
local function FuelTeleport(hrp, targetFuel)
    local generatorLoc = getGeneratorPosition()
    if not hrp or not targetFuel or not generatorLoc then return end

    local fuelUnion = targetFuel:FindFirstChild("Union") or targetFuel.PrimaryPart
    local itemDrag = targetFuel:FindFirstChild("ItemDrag")
    local networkRemote = itemDrag and itemDrag:FindFirstChild("RequestNetworkOwnership")

    if fuelUnion and networkRemote then
        -- Hippity Hoppity the fuel is now my property
        pcall(function()
            networkRemote:FireServer(fuelUnion)
        end)
        
        -- small delay so it doesn't blow up
        task.wait(0.12) 

        -- Instantly teleport item directly to the generator
        pcall(function()
            targetFuel:PivotTo(CFrame.new(generatorLoc) + Vector3.new(0, 1, 0))
        end)
        
        -- small delay so it doesn't blow up
        task.wait(0.15) 
    end
end


 
-- TRAVEL COMPONENT (CƠ CHẾ MOVETO GỐC ĐỂ DI CHUYỂN NGANG)
local function adaptiveCrawlTo(targetPos, humanoidRootPart, character, customYHeight)
    local finalTarget = targetPos + Vector3.new(0, 3, 0)
 
    local FAST_SPEED = 35     
    local SLOW_SPEED = 10     
    local STEP_DISTANCE = 0.25 
 
    local CLEARANCE_COOLDOWN = 0.5 
    local lastWallDetectedTime = 0
 
    -- Nếu truyền vào chiều cao custom (khi đang ở dưới lòng đất), dùng nó để cố định trục Y
    local lockedYHeight = customYHeight or humanoidRootPart.Position.Y
 
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {character} 
 
    while true do
        if not humanoidRootPart or not humanoidRootPart.Parent then break end
        local currentPos = humanoidRootPart.Position
        local flatTarget = Vector3.new(finalTarget.X, lockedYHeight, finalTarget.Z)
        local remainingVector = flatTarget - currentPos
        local totalDistance = remainingVector.Magnitude
 
        if totalDistance <= 2 or totalDistance <= STEP_DISTANCE then
            -- Khi kết thúc, nếu có Y custom thì giữ nguyên Y dưới lòng đất
            local targetPosition = customYHeight and Vector3.new(finalTarget.X, customYHeight, finalTarget.Z) or finalTarget
            humanoidRootPart.CFrame = CFrame.new(targetPosition)
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
            activeStepDistance = 1.4  
            currentAllowedSpeed = FAST_SPEED
        end
 
        local delayInterval = activeStepDistance / currentAllowedSpeed
        local nextPosition = currentPos + (direction * activeStepDistance)
        local flattenedPosition = Vector3.new(nextPosition.X, lockedYHeight, nextPosition.Z)
 
        humanoidRootPart.CFrame = CFrame.new(flattenedPosition)
        task.wait(delayInterval)
    end
end

-- --- HÀM TWEEN PHỤ TRỢ (CHỈ DÙNG ĐỂ ĐỤC THẲNG ĐỨNG XUỐNG VÀ LÊN) ---
local function tweenVertically(targetCFrame, speed, humanoidRootPart)
    local distance = (humanoidRootPart.Position - targetCFrame.Position).Magnitude
    local duration = distance / speed
    if duration <= 0 then return end
    
    local tweenInfo = TweenInfo.new(duration, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut)
    local tween = TweenService:Create(humanoidRootPart, tweenInfo, {CFrame = targetCFrame})
    
    humanoidRootPart.Anchored = true
    tween:Play()
    tween.Completed:Wait()
    humanoidRootPart.Anchored = false
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
        adaptiveCrawlTo(fuelOne:GetPivot().Position, humanoidRootPart, character)
        task.wait(0.3)
        FuelTeleport(humanoidRootPart, fuelOne)
        task.wait(0.5)
    end
 
    -- STEP 2: Second Nearest Fuel Remote Teleport
    local fuelTwo = getClosestFuelPosition(humanoidRootPart.Position)
    if fuelTwo then
        print("[Step 2] Moving to second closest fuel.")
        adaptiveCrawlTo(fuelTwo:GetPivot().Position, humanoidRootPart, character)
        task.wait(0.3)
        FuelTeleport(humanoidRootPart, fuelTwo)
        task.wait(0.5)
    end
 
    -- STEP 3: MECHANISM INTEGRATION (TWEEN DOWN 30 STUDS -> MOVETO INTERNALLY -> TWEEN UP)
    print("[Step 3] Scanning for closest Power Box model...")
    local powerBoxData = {}
    local interactionSuccess = false
 
    if MapFolder and MapFolder:FindFirstChild("Tiles") then
        for _, child in ipairs(MapFolder.Tiles:GetChildren()) do
            if child.Name == "Power Plant" then
                local powerBox = child:FindFirstChild("Power Box")
                if powerBox and powerBox:IsA("Model") then
                    table.insert(powerBoxData, {
                        Instance = powerBox,
                        Position = powerBox:GetPivot().Position
                    })
                end
            end
        end
    end
 
    if #powerBoxData > 0 then
        local currentPos = humanoidRootPart.Position
        table.sort(powerBoxData, function(a, b)
            return (currentPos - a.Position).Magnitude < (currentPos - b.Position).Magnitude
        end)
 
        local chosenBox = powerBoxData[1].Instance
        local finalBoxTarget = powerBoxData[1].Position
 
        print("[Step 3] Executing safe mechanism for Power Box.")
        
        -- 🔽 1. TWEEN THẲNG ĐỨNG XUỐNG DƯỚI ĐẤT 30 STUDS
        local startPos = humanoidRootPart.Position
        local undergroundY = startPos.Y - 30
        local stage1_Pos = Vector3.new(startPos.X, undergroundY, startPos.Z)
        local currentRotation = CFrame.Angles(0, math.rad(humanoidRootPart.Orientation.Y), 0)
        
        print("[Mechanism] Tweening down 30 studs...")
        tweenVertically(CFrame.new(stage1_Pos) * currentRotation, 15, humanoidRootPart)
        task.wait(0.1)
        
        -- ↔️ 2. MOVE TO (HÀM CRAWL GỐC) ĐỂ LƯỚT NGANG TRONG LÒNG ĐẤT
        print("[Mechanism] Moving to destination under the ground...")
        -- Cố định độ cao Y ngầm ở mức -30 studs trong suốt quá trình bò ngang
        adaptiveCrawlTo(finalBoxTarget, humanoidRootPart, character, undergroundY)
        task.wait(0.1)
        
        -- 🔼 3. TWEEN THẲNG ĐỨNG TỪ DƯỚI ĐẤT TRỒI LÊN POWER BOX
        print("[Mechanism] Tweening up to objective...")
        local finalUpTarget = finalBoxTarget + Vector3.new(0, 3, 0)
        tweenVertically(CFrame.new(finalUpTarget) * currentRotation, 15, humanoidRootPart)
        task.wait(0.2)
 
        if (humanoidRootPart.Position - finalBoxTarget).Magnitude < 15 then
            local prompt = chosenBox:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt then
                for i = 1, 3 do
                    if fireproximityprompt then
                        fireproximityprompt(prompt)
                    else
                        prompt:InputHoldBegin()
                        task.wait(prompt.HoldDuration + 0.05)
                        prompt:InputHoldEnd()
                    end
                    task.wait(0.1)
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

-- If a run somehow fails (either finding fuel function broke or smth) do a fresh new run
task.spawn(function()
    task.wait(60.0) -- Hard 1-minute safety timeout limit
    
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
