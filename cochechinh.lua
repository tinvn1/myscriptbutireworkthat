-- --- CHECK GAME ID BẢO VỆ CHỐNG CHẠY SAI SẢNH CHỜ ---
local TARGET_ID = 116139828947259

if game.PlaceId ~= TARGET_ID and game.GameId ~= TARGET_ID then
    warn("[Loader] Sai Game ID! Script đã tự động tắt để bảo vệ an toàn.")
    return 
end

print("[Loader] Xác thực Game ID thành công! Đang tiến hành tải script...")

-- --- 0. KIỂM TRA VÀ CHỜ LOBBY / GAME LOAD HOÀN TOÀN ---
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local ContentProvider = game:GetService("ContentProvider")
local maxWaitTime = os.clock()
while ContentProvider.RequestQueueSize > 0 do
    task.wait(0.5)
    if os.clock() - maxWaitTime > 15 then 
        warn("[Loader] Quá thời gian chờ asset, tự động bỏ qua để chạy tiếp.")
        break
    end
end

-- SERVICES --
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

-- ĐẢM BẢO NHÂN VẬT VÀ HRPART ĐÃ SẴN SÀNG
local LocalPlayer = Players.LocalPlayer
local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
local humanoidRootPart = character:WaitForChild("HumanoidRootPart", 10)

if not humanoidRootPart then
    warn("[Critical] Không tìm thấy HumanoidRootPart kịp lúc!")
    return
end

task.wait(1.5) 

-- CONFIGURATION & REFERENCES --
local MapFolder = Workspace:FindFirstChild("Map")
local DroppedItemsFolder = Workspace:WaitForChild("DroppedItems")

local cachedGeneratorLocation = nil
local PermanentNoclipEnabled = true

-- --- CƠ CHẾ AUTO VOTE REPLAY GỐC TỪ SCRIPT 2 ---
local function forceVotePlayAgain(reason)
    warn("[REPLAY ENGINE]: " .. tostring(reason))
    
    local PlayAgainRemote = ReplicatedStorage:FindFirstChild("Remotes") 
        and ReplicatedStorage.Remotes:FindFirstChild("Misc") 
        and ReplicatedStorage.Remotes.Misc:FindFirstChild("VotePlayAgain")

    if PlayAgainRemote and PlayAgainRemote:IsA("RemoteEvent") then
        pcall(function()
            PlayAgainRemote:FireServer()
        end)
        print("[Play Again] Đã kích hoạt Remote VotePlayAgain thành công.")
    else
        warn("[Warning] Đường dẫn Remote VotePlayAgain không tồn tại hoặc game đã thay đổi kết cấu.")
    end
    
    -- Khóa luồng hiện tại để nhân vật đứng yên chờ server xử lý chuyển map
    PermanentNoclipEnabled = false
    task.wait(0.1)
    error("Script execution paused. Waiting for server replay transition...")
end

-- RADAR CHỐNG NGƯỜI CHƠI KHÁC TRONG PHÒNG FARM
if #Players:GetPlayers() > 1 then
    forceVotePlayAgain("Phát hiện phòng hiện tại có người chơi khác từ trước!")
end

Players.PlayerAdded:Connect(function(newPlayer)
    if newPlayer ~= LocalPlayer then
        forceVotePlayAgain("Phát hiện người chơi mới vừa kết nối: " .. newPlayer.Name)
    end
end)

-- --- 1. CƠ CHẾ NOCLIP VĨNH VIỄN GỐC (BACKGROUND SERVICE) ---
local function StartPermanentNoclip()
    local noclipConnection = nil
 
    local function ConnectNoclip()
        if noclipConnection then noclipConnection:Disconnect() end
 
        noclipConnection = RunService.Stepped:Connect(function()
            if not PermanentNoclipEnabled then
                if noclipConnection then noclipConnection:Disconnect() end
                return
            end
 
            local char = LocalPlayer.Character
            if char then
                for _, child in ipairs(char:GetDescendants()) do
                    if child:IsA("BasePart") and child.CanCollide then
                        child.CanCollide = false
                    end
                end
 
                local hrp = char:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                end
            end
        end)
    end
 
    ConnectNoclip()
 
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.2) 
        ConnectNoclip()
    end)
end

StartPermanentNoclip()

-- --- LOGIC TÌM KIẾM VỊ TRÍ FUEL GỐC ---
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

-- --- LOGIC TÌM VỊ TRÍ MÁY GEN ---
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

-- --- 2. HÀM DI CHUYỂN ADAPTIVE CRAWL LẤY TỪ SCRIPT 2 (HOÀN TOÀN KHÔNG ĐỔI) ---
local function adaptiveCrawlTo(targetPos, humanoidRootPart, character)
    local finalTarget = targetPos + Vector3.new(0, 3, 0)
 
    local FAST_SPEED = 35     
    local SLOW_SPEED = 10     
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
        local flatTarget = Vector3.new(finalTarget.X, lockedYHeight, finalTarget.Z)
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

-- --- 4. LUỒNG THỰC THI PIPELINE THEO LỘ TRÌNH CHI TIẾT ---
local function runPipeline()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrpPart = char:WaitForChild("HumanoidRootPart")
 
    print("[Pipeline] Khởi chạy chu trình lộ trình tuần tự...")
    task.wait(0.3)
 
    -- BƯỚC 1: Di chuyển tới vị trí Cục Fuel thứ nhất -> Dừng 0.5s
    local fuelOne = getClosestFuelPosition(hrpPart.Position)
    if fuelOne then
        print("[Lộ trình 1/4] Đang di chuyển tới Fuel 1...")
        adaptiveCrawlTo(fuelOne:GetPivot().Position, hrpPart, char)
        excludeFuel[fuelOne] = true -- Loại trừ cục này để bước tiếp theo không đi lại
        task.wait(0.5)
    end
 
    -- BƯỚC 2: Di chuyển tới vị trí Cục Fuel thứ hai -> Dừng 0.5s
    local fuelTwo = getClosestFuelPosition(hrpPart.Position)
    if fuelTwo then
        print("[Lộ trình 2/4] Đang di chuyển tới Fuel 2...")
        adaptiveCrawlTo(fuelTwo:GetPivot().Position, hrpPart, char)
        excludeFuel[fuelTwo] = true
        task.wait(0.5)
    end
 
    -- BƯỚC 3: Di chuyển tới Máy Phát Điện (Generator) -> Dừng 0.5s
    local generatorPos = getGeneratorPosition()
    if generatorPos then
        print("[Lộ trình 3/4] Đang di chuyển tới Máy Phát Điện (Generator)...")
        adaptiveCrawlTo(generatorPos, hrpPart, char)
        task.wait(0.5)
    else
        warn("[Warning] Không tìm thấy máy Gen, bỏ qua bước trung gian.")
    end
 
    -- BƯỚC 4: Quét trạm điện (Power Box) gần nhất và tiến hành sửa máy
    print("[Lộ trình 4/4] Quét trạm điện gần nhất trên bản đồ...")
    local powerBoxData = {}
 
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
        local currentPos = hrpPart.Position
        table.sort(powerBoxData, function(a, b)
            return (currentPos - a.Position).Magnitude < (currentPos - b.Position).Magnitude
        end)
 
        local chosenBox = powerBoxData[1].Instance
        local finalBoxTarget = powerBoxData[1].Position
 
        print("[Hành động] Di chuyển xuyên tường thẳng tới Power Box mục tiêu.")
        adaptiveCrawlTo(finalBoxTarget, hrpPart, char)
        task.wait(0.5)
 
        if (hrpPart.Position - finalBoxTarget).Magnitude < 15 then
            local prompt = chosenBox:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt then
                print("[Hành động] Tiến hành tương tác sửa máy...")
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
                
                print("[Pipeline] Hoàn thành sửa máy! Kích hoạt Vote Chơi Lại...")
                forceVotePlayAgain("Hoàn tất toàn bộ chu trình lộ trình thành công")
            end
        end
    else
        warn("[PowerBox] Không tìm thấy Power Box nào trên bản đồ. Kích hoạt Vote đổi phòng...")
        forceVotePlayAgain("Không tìm thấy Power Box trên bản đồ")
    end
end

-- --- 5. BẢO HIỂM WATCHDOG ĐÚNG 60 GIÂY ---
task.delay(60, function()
    forceVotePlayAgain("Quá thời gian quy định cho một lượt farm (Watchdog Timeout 60s)")
end)

-- --- 6. KHỞI CHẠY CHƯƠNG TRÌNH ---
runPipeline()
