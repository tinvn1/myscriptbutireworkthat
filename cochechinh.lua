-- --- 1. HÀM DI CHUYỂN ADAPTIVE CRAWL (BẮT BUỘC ĐỂ DI CHUYỂN TỚI BOX) ---
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
 
    -- [WATCHDOG CONFIG] Thiết lập cấu hình chống kẹt
    local isMoving = true
    local lastPosition = humanoidRootPart.Position
    local lastMoveTime = os.clock()
    local STUCK_THRESHOLD = 3 -- Số giây tối đa đứng yên một chỗ trước khi tính là bị kẹt

    -- Khởi chạy Watchdog ngầm
    task.spawn(function()
        while isMoving do
            task.wait(0.5)
            if not humanoidRootPart or not humanoidRootPart.Parent then break end
            
            local currentPos = humanoidRootPart.Position
            local distanceMoved = (currentPos - lastPosition).Magnitude
            
            if distanceMoved > 0.5 then
                lastPosition = currentPos
                lastMoveTime = os.clock()
            else
                if os.clock() - lastMoveTime >= STUCK_THRESHOLD then
                    warn("[Watchdog] Phát hiện nhân vật bị kẹt góc! Kích hoạt Teleport Bypass...")
                    humanoidRootPart.CFrame = CFrame.new(finalTarget)
                    break
                end
            end
        end
    end)
 
    while true do
        if not humanoidRootPart or not humanoidRootPart.Parent then 
            isMoving = false
            break 
        end
        
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
            isMoving = false
            break
        end
 
        local direction = remainingVector.Unit
        local lookAheadDistance = 5
        local rayResult = workspace:Raycast(currentPos, direction * lookAheadDistance, raycastParams)
 
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
    isMoving = false
end

-- --- 2. CƠ CHẾ REJOIN (VÀO LẠI SERVER) ---
local function safeRejoin()
    print("[System] Hết thời gian 2 phút! Đang tiến hành Rejoin sang server mới...")
    local TeleportService = game:GetService("TeleportService")
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer

    -- Bỏ qua màn hình báo lỗi ngắt kết nối/bị kích nếu có
    local coreGui = game:GetService("CoreGui")
    if coreGui:FindFirstChild("RobloxPromptGui") then
        local prompt = coreGui.RobloxPromptGui.promptOverlay:FindFirstChild("ErrorPrompt")
        if prompt then
            game:GetService("GuiService"):ClearError()
        end
    end

    -- Thực hiện Teleport về lại game để nhảy server
    pcall(function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)
    
    -- Đợi đề phòng lỗi mạng, sẽ cố gắng thử lại sau 5 giây
    task.wait(5)
    TeleportService:Teleport(game.PlaceId, LocalPlayer)
end

-- --- 3. CƠ CHẾ QUÉT VÀ TƯƠNG TÁC POWER BOX ---
local function interactWithClosestPowerBox()
    local Players = game:GetService("Players")
    local LocalPlayer = Players.LocalPlayer
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    local MapFolder = workspace:FindFirstChild("Map")
    
    local powerBoxData = {}
    local interactionSuccess = false
 
    -- Bước A: Quét toàn bộ map để tìm các model "Power Box" nằm trong "Power Plant"
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
 
    -- Bước B: Nếu tìm thấy Box, tiến hành sắp xếp để chọn cái gần nhất
    if #powerBoxData > 0 then
        local currentPos = humanoidRootPart.Position
        table.sort(powerBoxData, function(a, b)
            return (currentPos - a.Position).Magnitude < (currentPos - b.Position).Magnitude
        end)
 
        local chosenBox = powerBoxData[1].Instance
        local finalBoxTarget = powerBoxData[1].Position
 
        print("[PowerBox] Đang di chuyển tới Power Box gần nhất...")
        adaptiveCrawlTo(finalBoxTarget, humanoidRootPart, character)
        task.wait(0.5)
 
        -- Bước C: Kiểm tra khoảng cách an toàn (< 15 studs) và kích hoạt nút (ProximityPrompt)
        if (humanoidRootPart.Position - finalBoxTarget).Magnitude < 15 then
            local prompt = chosenBox:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt then
                print("[PowerBox] Đang tương tác với nút...")
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
                print("[PowerBox] Tác động thành công!")
                interactionSuccess = true
            end
        end
    else
        warn("[PowerBox] Không tìm thấy Power Box nào trên bản đồ.")
    end
    
    return interactionSuccess
end

-- --- 4. KHỞI CHẠY HẸN GIỜ REJOIN TRƯỚC (BẮT BUỘC CHẠY SONG SONG) ---
task.delay(120, function()
    safeRejoin()
end)

-- --- 5. CHẠY LUỒNG THỰC THI CHÍNH ---
print("[Main] Script bắt đầu hoạt động. Đếm ngược 2 phút Rejoin kích hoạt!")
interactWithClosestPowerBox()
