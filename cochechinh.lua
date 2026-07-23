-- Made by TheAnonymous in RScript / Theultimateuser in Scriptblox
 
if not game:IsLoaded() then
    game.Loaded:Wait()
end
 
local ContentProvider = game:GetService("ContentProvider")
while ContentProvider.RequestQueueSize > 0 do
    task.wait(0.5)
end
 
task.wait(6.0) -- Đã tối ưu thời gian chờ khi vừa load map
 
-- SERVICES --
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
 
-- CONFIGURATION & REFERENCES --
local LocalPlayer = Players.LocalPlayer
local MapFolder = Workspace:FindFirstChild("Map")
local DroppedItemsFolder = Workspace:WaitForChild("DroppedItems")
local PlayAgainRemote = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Misc"):FindFirstChild("VotePlayAgain")
local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
 
local cachedGeneratorLocation = nil
local PermanentNoclipEnabled = true
 
-- SAFETY ESCAPE --
local function evacuateServer(reason)
    warn("[CRITICAL EVACUATION]: " .. reason)
    task.spawn(function()
        if PlayAgainRemote and PlayAgainRemote:IsA("RemoteEvent") then
            pcall(function()
                PlayAgainRemote:FireServer()
            end)
            task.wait(1.0)
        end
        LocalPlayer:Kick("[WARNING] UNKNOWN PLAYER DETECTED!")
    end)
    error("Script execution terminated.")
end
 
-- NOCLIP ENGINE --
local function StartPermanentNoclip()
    local noclipConnection = nil
    local function ConnectNoclip()
        if noclipConnection then noclipConnection:Disconnect() end
        noclipConnection = RunService.Stepped:Connect(function()
            if not PermanentNoclipEnabled then
                if noclipConnection then noclipConnection:Disconnect() end
                return
            end
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
 
-- FUEL LOCATOR --
local excludeFuel = {}
local function getClosestFuelPosition(currentPos)
    local foundValidFuel = nil
    while not foundValidFuel do
        local bestTarget = nil
        local shortestDistance = math.huge
        if DroppedItemsFolder then
            for _, item in ipairs(DroppedItemsFolder:GetChildren()) do
                if item.Name == "Fuel" and not excludeFuel[item] then
                    local fuelPos = item:GetPivot().Position
                    local dist = (currentPos - fuelPos).Magnitude
                    if dist < shortestDistance then
                        shortestDistance = dist
                        bestTarget = item
                    end
                end
            end
        end
        if not bestTarget then break end
 
        local targetPosition = bestTarget:GetPivot().Position
        if (targetPosition.Y - currentPos.Y) <= 2 then
            foundValidFuel = bestTarget
        else
            excludeFuel[bestTarget] = true
        end
    end
    return foundValidFuel
end
 
local function getGeneratorPosition()
    if cachedGeneratorLocation then return cachedGeneratorLocation end
    if MapFolder and MapFolder:FindFirstChild("Tiles") then
        for _, child in ipairs(MapFolder.Tiles:GetChildren()) do
            if child.Name == "Generator" or child:FindFirstChild("Generator") then
                cachedGeneratorLocation = child:GetPivot().Position
                return cachedGeneratorLocation
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
        pcall(function() networkRemote:FireServer(fuelUnion) end)
        task.wait(0.12)
        pcall(function() targetFuel:PivotTo(CFrame.new(generatorLoc) + Vector3.new(0, 1, 0)) end)
        task.wait(0.15)
    end
end
 
-- CRAWL & HOVER MOVEMENT --
local function adaptiveCrawlTo(targetPos, humanoidRootPart, character)
    local HOVER_HEIGHT = 0.6
    local finalTarget = targetPos + Vector3.new(0, 3, 0)
    local BURST_SPEED = 70
    local SLOW_SPEED = 7
    local CLEARANCE_COOLDOWN = 0.5  
    local SLOW_ZONE_DURATION = 0.35
 
    local lastWallDetectedTime = 0
    local baseGroundY = humanoidRootPart.Position.Y
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {character} 
    local heartbeatEvent = RunService.Heartbeat
 
    while true do
        if not humanoidRootPart or not humanoidRootPart.Parent then break end
        local deltaTime = heartbeatEvent:Wait()
        local currentPos = humanoidRootPart.Position
        
        local roofCheck = workspace:Raycast(currentPos, Vector3.new(0, HOVER_HEIGHT + 2, 0), raycastParams)
        local targetYHeight = baseGroundY + HOVER_HEIGHT
        
        if roofCheck and roofCheck.Instance and roofCheck.Instance.CanCollide then
            targetYHeight = baseGroundY
        end
 
        local flatTarget = Vector3.new(finalTarget.X, targetYHeight, finalTarget.Z)
        local remainingVector = flatTarget - currentPos
        local totalDistance = remainingVector.Magnitude
 
        if totalDistance <= 2.0 then
            humanoidRootPart.CFrame = CFrame.new(finalTarget)
            humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, -5, 0) 
            humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            humanoidRootPart.Anchored = true
            task.wait(0.05)
            humanoidRootPart.Anchored = false 
            break
        end
 
        local direction = remainingVector.Unit
        local rayResult = workspace:Raycast(currentPos, direction * 5, raycastParams)
        if rayResult and rayResult.Instance and rayResult.Instance.CanCollide then
            lastWallDetectedTime = os.clock()
        end
 
        local currentAllowedSpeed = SLOW_SPEED
        if os.clock() - lastWallDetectedTime >= CLEARANCE_COOLDOWN then
            local serverTime = workspace:GetServerTimeNow()
            if (serverTime % 1.0) < (1.0 - SLOW_ZONE_DURATION) then
                currentAllowedSpeed = BURST_SPEED
            end
        end
 
        local frameTravelDistance = math.min(currentAllowedSpeed * deltaTime, totalDistance)
        local nextPosition = currentPos + (direction * frameTravelDistance)
        humanoidRootPart.CFrame = CFrame.new(Vector3.new(nextPosition.X, targetYHeight, nextPosition.Z))
    end
end
 
-- PIPELINE RUNNER --
local function runPipeline()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    task.wait(0.3)
 
    local fuelOne = getClosestFuelPosition(humanoidRootPart.Position)
    if fuelOne then
        adaptiveCrawlTo(fuelOne:GetPivot().Position, humanoidRootPart, character)
        task.wait(0.3)
        FuelTeleport(humanoidRootPart, fuelOne)
        task.wait(0.5)
    end
 
    local fuelTwo = getClosestFuelPosition(humanoidRootPart.Position)
    if fuelTwo then
        adaptiveCrawlTo(fuelTwo:GetPivot().Position, humanoidRootPart, character)
        task.wait(0.3)
        FuelTeleport(humanoidRootPart, fuelTwo)
        task.wait(0.5)
    end
 
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
 
        adaptiveCrawlTo(finalBoxTarget, humanoidRootPart, character)
        task.wait(0.5)
 
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
                interactionSuccess = true
            end
        end
    end
 
    task.wait(0.5) 
    if interactionSuccess and PlayAgainRemote and PlayAgainRemote:IsA("RemoteEvent") then
        pcall(function() PlayAgainRemote:FireServer() end)
    end
end
 
if #Players:GetPlayers() > 1 then
    evacuateServer("Pre-existing player DETECTED!")
end
 
Players.PlayerAdded:Connect(function(newPlayer)
    if newPlayer ~= LocalPlayer then
        evacuateServer("Player entry detected (" .. newPlayer.Name .. ").")
    end
end)
 
task.spawn(function()
    task.wait(90.0)
    if PlayAgainRemote and PlayAgainRemote:IsA("RemoteEvent") then
        pcall(function() PlayAgainRemote:FireServer() end)
    end
end)
 
LocalPlayer.Character:GetAttributeChangedSignal("Dead"):Connect(function()
    pcall(function() PlayAgainRemote:FireServer() end)
end)
 
runPipeline()
