-- --- 0. KHỔI TẠO VÀ CHỜ GAME TẢI XONG ---
print("Loading...")
if not game:IsLoaded() then
    game.Loaded:Wait()
end
 
local ContentProvider = game:GetService("ContentProvider")
while ContentProvider.RequestQueueSize > 0 do
    task.wait(0.5)
end
task.wait(2.0) -- Đợi thêm một chút để đảm bảo map đã dựng xong

-- SERVICES --
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
 
-- CONFIGURATION & REFERENCES --
local LocalPlayer = Players.LocalPlayer
local PermanentNoclipEnabled = true

-- --- CƠ CHẾ SƠ TÁN / REJOIN TỐI ƯU CỦA SCRIPT 2 (EVACUATE SERVER) ---
local function safeRejoin(reason)
    warn("[CRITICAL EVACUATION / REJOIN]: " .. tostring(reason))
    task.spawn(function()
        -- 1. Ưu tiên sử dụng Remote nhảy server / chơi lại nhanh của game (Tối ưu tốc độ)
        local PlayAgainRemote = ReplicatedStorage:FindFirstChild("Remotes") 
            and ReplicatedStorage.Remotes:FindFirstChild("Misc") 
            and ReplicatedStorage.Remotes.Misc:FindFirstChild("VotePlayAgain")

        if PlayAgainRemote and PlayAgainRemote:IsA("RemoteEvent") then
            pcall(function()
                PlayAgainRemote:FireServer()
            end)
            print("[Escape] Đang thực hiện VotePlayAgain để đổi server nhanh...")
            task.wait(1.5) -- Đợi remote xử lý
        end
        
        -- 2. Dự phòng: Nếu remote lỗi hoặc chậm, dùng TeleportService thông thường
        print("[Escape] Sử dụng phương thức Teleport dự phòng...")
        local TeleportService = game:GetService("TeleportService")
        pcall(function()
            TeleportService:Teleport(game.PlaceId, LocalPlayer)
        end)

        -- 3. Cứu cánh cuối cùng: Tự Kick bản thân nếu bị kẹt (Dành cho Auto-Execute tự kết nối lại)
        task.wait(3.5)
        LocalPlayer:Kick("[REJOIN FAILED] Đang ép ngắt kết nối để Rejoin qua Trình quản lý!")
    end)
    
    -- Dừng luồng script hiện tại ngay lập tức để tránh lỗi xung đột dữ liệu
    task.wait(0.1)
    error("Script execution terminated via safeRejoin.")
end

-- ANTI-SOCIAL / RADAR QUÉT NGƯỜI CHƠI KHÁC (Chỉ cho phép Solo)
if #Players:GetPlayers() > 1 then
    safeRejoin("Phát hiện phòng đã có người chơi khác từ trước!")
end

Players.PlayerAdded:Connect(function(newPlayer)
    if newPlayer ~= LocalPlayer then
        safeRejoin("Phát hiện người chơi khác vừa vào phòng (" .. newPlayer.Name .. "). Tiến hành tẩu thoát!")
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
                -- Loại bỏ hoàn toàn va chạm của tất cả các bộ phận nhân vật trước khi chu kỳ physics tính toán
                for _, child in ipairs(character:GetDescendants()) do
                    if child:IsA("BasePart") and child.CanCollide then
                        child.CanCollide = false
                    end
                end
 
                -- Triệt tiêu gia tốc/vận tốc gốc để tránh bị chống gian lận giật ngược (Anti-cheat rubberbanding)
                local hrp = character:FindFirstChild("HumanoidRootPart")
                if hrp then
                    hrp.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
                end
            end
        end)
    end
 
    ConnectNoclip()
 
    -- Tự động áp dụng lại vòng lặp Noclip mỗi khi nhân vật hồi sinh (Respawn)
    LocalPlayer.CharacterAdded:Connect(function()
        task.wait(0.1)
        ConnectNoclip()
    end)
end

-- Kích hoạt Noclip chạy ngầm ngay khi chạy script
StartPermanentNoclip()
print("[Noclip] Đã kích hoạt cơ chế xuyên tường vĩnh viễn!")

-- --- 2. HÀM DI CHUYỂN ADAPTIVE CRAWL (XUYÊN TƯỜNG GỐC) ---
local function adaptiveCrawlTo(targetPos, humanoidRootPart, character)
    local finalTarget = targetPos + Vector3.new(0, 3, 0)
    local FAST_SPEED = 35     
    local SLOW_SPEED = 10     
    -- Sửa lại bug nhỏ: script gốc dùng STEP_DISTANCE nhưng khai báo cục bộ là activeStepDistance bên dưới, đồng bộ lại thành 0.25
    local STEP_DISTANCE = 0.25  
    local CLEARANCE_COOLDOWN = 0.5  
    local lastWallDetectedTime = 0
    local lockedYHeight = humanoidRootPart.Position.Y
 
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {character} 
 
    -- [WATCHDOG] Cấu hình chống kẹt góc khi di chuyển
    local isMoving = true
    local lastPosition = humanoidRootPart.Position
    local lastMoveTime = os.clock()
    local STUCK_THRESHOLD = 3 -- Tối đa 3 giây đứng im tại chỗ sẽ tự nhảy thẳng tới đích

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
                    warn("[Watchdog] Phát hiện bị kẹt góc nặng! Đang Bypass dịch chuyển thẳng tới đích...")
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

-- --- 4. CƠ CHẾ QUÉT VÀ TƯƠNG TÁC POWER BOX ---
local function interactWithClosestPowerBox()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
    local MapFolder = Workspace:FindFirstChild("Map")
    
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

-- --- 5. HẸN GIỜ ÉP REJOIN DỰ PHÒNG SAU 1 PHÚT (Bảo hiểm chống kẹt / giống script 2) ---
task.delay(60, function()
    safeRejoin("Hết thời gian chờ tối đa cho phép (60 giây Watchdog)")
end)

-- --- 6. LUỒNG THỰC THI CHÍNH VÀ ĐIỀU HƯỚNG TỐT NHẤT ---
print("[Main] Script khởi động hoàn tất. Tiến hành quét mục tiêu...")
local completed = interactWithClosestPowerBox()

if completed then
    print("[Main] Đã hoàn thành xong việc! Chờ 0.5 giây để đồng bộ phần thưởng rồi tiến hành Rejoin...")
    task.wait(0.5)
    safeRejoin("Hoàn thành tương tác Power Box thành công")
else
    print("[Main] Không thể tương tác hoặc không tìm thấy mục tiêu. Đổi server ngay lập tức...")
    task.wait(0.5)
    safeRejoin("Thất bại hoặc Không thấy Power Box trên bản đồ")
end
