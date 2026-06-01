-- --- 0. KHỞI TẠO VÀ CHỜ GAME TẢI XONG ---
print("Loading...")
if not game:IsLoaded() then
    game.Loaded:Wait()
end
 
local ContentProvider = game:GetService("ContentProvider")
while ContentProvider.RequestQueueSize > 0 do
    task.wait(0.5)
end
task.wait(2.0)

-- SERVICES --
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
 
-- CONFIGURATION & REFERENCES --
local LocalPlayer = Players.LocalPlayer
local PermanentNoclipEnabled = true

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
print("[Noclip] Đã kích hoạt cơ chế xuyên tường vĩnh viễn!")

-- --- 2. HÀM DI CHUYỂN ADAPTIVE CRAWL (XUYÊN TƯỜNG GỐC) ---
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
 
    -- [WATCHDOG THỰC THỤ] Kiểm tra và tự gỡ kẹt tại chỗ
    local isMoving = true
    local lastPosition = humanoidRootPart.Position
    local lastMoveTime = os.clock()
    local STUCK_THRESHOLD = 3 -- 3 giây không dịch chuyển sẽ kích hoạt gỡ kẹt

    task.spawn(function()
        while isMoving do
            task.wait(0.5)
            if not humanoidRootPart or not humanoidRootPart.Parent then break end
            
            local currentPos = humanoidRootPart.Position
            local distanceMoved = (currentPos - lastPosition).Magnitude
            
            if distanceMoved > 0.5 then
                -- Nếu vẫn di chuyển mượt thì cập nhật tọa độ liên tục
                lastPosition = currentPos
                lastMoveTime = os.clock()
            else
                -- Nếu phát hiện đứng im quá 3 giây
                if os.clock() - lastMoveTime >= STUCK_THRESHOLD then
                    warn("[Watchdog] Phát hiện kẹt góc! Đang tự động gỡ kẹt vật lý...")
                    
                    -- BƯỚC 1: Giật lùi/Nhấc nhẹ nhân vật lên để thoát khỏi lưới va chạm bị lỗi
                    humanoidRootPart.CFrame = humanoidRootPart.CFrame * CFrame.new(0, 2, 2)
                    task.wait(0.1)
                    
                    -- BƯỚC 2: Force thẳng nhân vật đến điểm cuối luôn để không bị đứng chết ở vòng lặp crawl
                    humanoidRootPart.CFrame = CFrame.new(finalTarget)
                    break -- Tháo xích Watchdog của lượt này
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
    isMoving = false
end

-- --- 3. CƠ CHẾ REJOIN ĐỘC LẬP (ĐÚNG 2 PHÚT LÀ ĐỔI SERVER) ---
local function safeRejoin()
    print("[System] Hết thời gian hạn định 2 phút! Tiến hành Rejoin sang server mới...")
    local TeleportService = game:GetService("TeleportService")
    local LocalPlayer = Players.LocalPlayer

    local coreGui = game:GetService("CoreGui")
    if coreGui:FindFirstChild("RobloxPromptGui") then
        local prompt = coreGui.RobloxPromptGui.promptOverlay:FindFirstChild("ErrorPrompt")
        if prompt then
            game:GetService("GuiService"):ClearError()
        end
    end

    pcall(function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)
    
    task.wait(5)
    pcall(function()
        TeleportService:Teleport(game.PlaceId, LocalPlayer)
    end)
end

-- --- 4. CƠ CHẾ QUÉT VÀ TƯƠNG TÁC POWER BOX ---
local function interactWithClosestPowerBox()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    local MapFolder = Workspace:FindFirstChild("Map")
    
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
 
        print("[PowerBox] Đang di chuyển tới Power Box gần nhất...")
        adaptiveCrawlTo(finalBoxTarget, humanoidRootPart, character)
        task.wait(0.5)
 
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

-- --- 5. HẸN GIỜ ÉP REJOIN SAU 2 PHÚT (120 GIÂY) ---
task.delay(120, function()
    safeRejoin()
end)

-- --- 6. LUỒNG THỰC THI CHÍNH ---
print("[Main] Script vận hành. Watchdog gỡ kẹt tại chỗ và Hẹn giờ Rejoin độc lập đã chạy!")
interactWithClosestPowerBox()
