-- --- 0. KHỔI TẠO VÀ CHỜ GAME TẢI XONG ---
print("Loading...")
if not game:IsLoaded() then
    game.Loaded:Wait()
end
 
local ContentProvider = game:GetService("ContentProvider")
while ContentProvider.RequestQueueSize > 0 do
    task.wait(0.5)
end
task.wait(1.5) -- Tối ưu lại thời gian đợi vừa đủ để map dựng

-- SERVICES --
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
 
-- CONFIGURATION & REFERENCES --
local LocalPlayer = Players.LocalPlayer
local PermanentNoclipEnabled = true

-- --- CƠ CHẾ SƠ TÁN / REJOIN CỰC TỐC (VOTE PLAY AGAIN) ---
local function safeRejoin(reason)
    warn("[CRITICAL REJOIN]: " .. tostring(reason))
    task.spawn(function()
        -- 1. Kích hoạt Remote Play Again của game để chuyển phòng trong 1 giây
        local PlayAgainRemote = ReplicatedStorage:FindFirstChild("Remotes") 
            and ReplicatedStorage.Remotes:FindFirstChild("Misc") 
            and ReplicatedStorage.Remotes.Misc:FindFirstChild("VotePlayAgain")

        if PlayAgainRemote and PlayAgainRemote:IsA("RemoteEvent") then
            pcall(function()
                PlayAgainRemote:FireServer()
            end)
            print("[Escape] Đang thực hiện VotePlayAgain để đổi server nhanh...")
            task.wait(1.0) -- Giảm thời gian chờ để ưu tiên tốc độ chuyển cảnh
        end
        
        -- 2. Phương thức dự phòng nếu lỗi remote
        local TeleportService = game:GetService("TeleportService")
        pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)

        -- 3. Cứu cánh cuối cùng (Tự Kick để Rejoin tự động)
        task.wait(2.5)
        LocalPlayer:Kick("[REJOIN FAILED] Ép ngắt kết nối để Rejoin!")
    end)
    
    task.wait(0.05)
    error("Script execution terminated.")
end

-- RADAR QUÉT NGƯỜI CHƠI KHÁC (Bảo mật Solo Farm)
if #Players:GetPlayers() > 1 then
    safeRejoin("Phát hiện phòng có người! Đổi server ngay.")
end

Players.PlayerAdded:Connect(function(newPlayer)
    if newPlayer ~= LocalPlayer then
        safeRejoin("Phát hiện người chơi khác vừa vào phòng. Tẩu thoát!")
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
 
    local isMoving = true
    local lastPosition = humanoidRootPart.Position
    local lastMoveTime = os.clock()
    local STUCK_THRESHOLD = 3 

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
                    warn("[Watchdog] Phát hiện kẹt! Dịch chuyển thẳng tới đích...")
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

-- --- 4. CƠ CHẾ TƯƠNG TÁC VÀ KÍCH HOẠT REJOIN LẬP TỨC KHI XONG ---
local function interactWithClosestPowerBox()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    local MapFolder = Workspace:FindFirstChild("Map")
    
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
        local currentPos = humanoidRootPart.Position
        table.sort(powerBoxData, function(a, b)
            return (currentPos - a.Position).Magnitude < (currentPos - b.Position).Magnitude
        end)
 
        local chosenBox = powerBoxData[1].Instance
        local finalBoxTarget = powerBoxData[1].Position
 
        print("[PowerBox] Đang di chuyển tới Power Box gần nhất...")
        adaptiveCrawlTo(finalBoxTarget, humanoidRootPart, character)
        
        -- Kiểm tra khoảng cách để tương tác nút
        if (humanoidRootPart.Position - finalBoxTarget).Magnitude < 15 then
            local prompt = chosenBox:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt then
                print("[PowerBox] Đang tương tác sửa máy...")
                
                -- Thực hiện tương tác kích hoạt nút sửa máy
                if fireproximityprompt then
                    fireproximityprompt(prompt)
                else
                    prompt:InputHoldBegin()
                    task.wait(prompt.HoldDuration + 0.02) -- Tối ưu thời gian nhấn giữ nút vừa đủ khít
                    prompt:InputHoldEnd()
                end
                
                -- KÍCH HOẠT REJOIN NGAY LẬP TỨC SAU KHI CLICK XONG NÚT SỬA MÁY
                print("[PowerBox] Đã sửa máy xong! Tiến hành chuyển server siêu tốc...")
                safeRejoin("Hoàn thành sửa máy (Power Box)")
            end
        end
    else
        warn("[PowerBox] Không tìm thấy Power Box. Đổi server ngay...")
        safeRejoin("Không thấy Power Box trên bản đồ")
    end
end

-- --- 5. BẢO HIỂM CHỐNG KẸT MÀN HÌNH (WATCHDOG 45 GIÂY) ---
task.delay(45, function()
    safeRejoin("Quá thời gian farm cho phép (Watchdog Timeout)")
end)

-- --- 6. LUỒNG THỰC THI CHÍNH ---
print("[Main] Bắt đầu quét mục tiêu sửa máy...")
interactWithClosestPowerBox()
