-- Feel free to adjust
-- Optimized Custom Mode: Pure Power Box Route (Using Original Crawl Mechanic)
-- Original Author: TheAnonymous in RScript
-- Updated & Optimized by: TinHub Project + Auto Hold, Triple Tap/Press Integrated

print("Loading via TinHub Engine")
 
if not game:IsLoaded() then
    game.Loaded:Wait()
end
 
local ContentProvider = game:GetService("ContentProvider")
while ContentProvider.RequestQueueSize > 0 do
    task.wait(0.5)
end
 
print("The game is loaded in. Wait more for things to fully load")
task.wait(3.0)
print("Complete! Starting the farm.")
 
-- SERVICES --
local Workspace = game:GetService("Workspace")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local Camera = workspace.CurrentCamera
 
-- --- CONFIGURATION & REFERENCES ---
local LocalPlayer = Players.LocalPlayer
local MapFolder = Workspace:FindFirstChild("Map")
local PermanentNoclipEnabled = true

local OFFSET_DOWN = 20     -- Độ thấp dưới tâm màn hình (pixel)
local HOLD_DURATION = 11   -- Đã chỉnh thành 11 giây giữ máy
 
-- --- EMERGENCY DETECTION RADAR ---
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
 
-- ===================================================================
-- 1. GIỮ NGUYÊN 100% CƠ CHẾ XUYÊN TƯỜNG (ADAPTIVE CRAWL GỐC)
-- ===================================================================
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
 
-- --- PIPELINE EXECUTION ENGINE ---
local function runPipeline()
    local character = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart")
 
    print("[Pipeline] Khởi động lộ trình: Di chuyển thẳng tới Power Box...")
    task.wait(0.3)
 
    -- 2. CƠ CHẾ QUÉT VÀ ĐỊNH VỊ POWER BOX GẦN NHẤT
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
 
        print("[Pipeline] Sử dụng crawl gốc di chuyển thẳng tới Power Box...")
        adaptiveCrawlTo(finalBoxTarget, humanoidRootPart, character)
        task.wait(0.5)
 
        -- 3. CƠ CHẾ NHẤP NHẢ 3 LẦN VÀ TỰ ĐỘNG GIỮ (PC & MOBILE ADAPTIVE)
        if (humanoidRootPart.Position - finalBoxTarget).Magnitude < 15 then
            local prompt = chosenBox:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt then
                
                local isPC = UserInputService.KeyboardEnabled and UserInputService.MouseEnabled
                local noticeText = "Đang chạm màn hình 3 lần và giữ máy trong 11 giây..."
                if isPC then
                    noticeText = "Đang nhấp nhả phím [E] 3 lần và đè giữ trong 11 giây..."
                end

                StarterGui:SetCore("SendNotification", {
                    Title = "Interaction System",
                    Text = noticeText,
                    Duration = 3
                })

                -- Tính toán tọa độ chính giữa màn hình hạ xuống 20 pixel
                local centerX = Camera.ViewportSize.X / 2
                local targetY = (Camera.ViewportSize.Y / 2) + OFFSET_DOWN

                -- [BƯỚC 1]: THỰC HIỆN NHẤP NHẢ 3 LẦN (TÙY THEO THIẾT BỊ)
                if isPC then
                    print("[Pipeline] Phát hiện PC: Tiến hành nhấp nhả phím E 3 lần...")
                    for i = 1, 3 do
                        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)  -- Nhấn E xuống
                        task.wait(0.05)
                        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game) -- Thả E ra
                        task.wait(0.05)
                    end
                else
                    print("[Pipeline] Phát hiện Mobile: Tiến hành chạm màn hình 3 lần...")
                    for i = 1, 3 do
                        VirtualInputManager:SendMouseButtonEvent(centerX, targetY, 0, true, game, 0) -- Chạm xuống
                        task.wait(0.05)
                        VirtualInputManager:SendMouseButtonEvent(centerX, targetY, 0, false, game, 0) -- Nhấc lên
                        task.wait(0.05)
                    end
                end

                -- [BƯỚC 2]: BẮT ĐẦU ĐÈ GIỮ (HOLD) CHẶT NGAY SAU ĐÓ
                print("[Pipeline] Bắt đầu đè giữ chặt nút kích hoạt...")
                VirtualInputManager:SendMouseButtonEvent(centerX, targetY, 0, true, game, 0)
                if isPC then
                    VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                end

                -- Kích hoạt ProximityPrompt của game theo cơ chế gốc
                if fireproximityprompt then
                    fireproximityprompt(prompt)
                else
                    prompt:InputHoldBegin()
                end

                -- [BƯỚC 3]: DUY TRÌ TRẠNG THÁI GIỮ TRONG 11 GIÂY
                task.wait(HOLD_DURATION)

                -- [BƯỚC 4]: THẢ RA HOÀN TOÀN
                VirtualInputManager:SendMouseButtonEvent(centerX, targetY, 0, false, game, 0)
                if isPC then
                    VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                end

                if not fireproximityprompt then
                    prompt:InputHoldEnd()
                end

                -- Thông báo hoàn thành
                StarterGui:SetCore("SendNotification", {
                    Title = "Interaction System",
                    Text = "Đã sửa xong máy điện, chuẩn bị đổi phòng!",
                    Duration = 3
                })

                print("[Pipeline] Loop complete and keys released successfully!")
                interactionSuccess = true
            end
        end
    else
        warn("[Warning] Không tìm thấy bất kỳ Power Box nào trên bản đồ này!")
    end
 
    -- --- VOTE PLAY AGAIN SEQUENCE (TỰ ĐỘNG ĐỔI TRẬN) ---
    task.wait(1.0) 
    
    if interactionSuccess then
        local PlayAgainRemote = ReplicatedStorage:FindFirstChild("Remotes") 
            and ReplicatedStorage.Remotes:FindFirstChild("Misc") 
            and ReplicatedStorage.Remotes.Misc:FindFirstChild("VotePlayAgain")
 
        if PlayAgainRemote and PlayAgainRemote:IsA("RemoteEvent") then
            pcall(function()
                PlayAgainRemote:FireServer()
            end)
            print("[Play Again] Đã gửi lệnh đổi server sau khi chờ thêm 1 giây.")
        else
            warn("[Warning] VotePlayAgain remote path could not be found.")
        end
    end
end

runPipeline()

-- Watchdog kiểm soát kẹt phòng
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
