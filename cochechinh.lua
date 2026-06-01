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

-- --- 2. HÀM DI CHUYỂN ADAPTIVE CRAWL (XUYÊN TƯỜNG GỐC) ---
local function adaptiveCrawlTo(targetPos, hrpPart, characterModel)
    local finalTarget = targetPos + Vector3.new(0, 3, 0)
    local FAST_SPEED = 35     
    local SLOW_SPEED = 10     
    local STEP_DISTANCE = 0.25  
    local CLEARANCE_COOLDOWN = 0.5  
    local lastWallDetectedTime = 0
    local lockedYHeight = hrpPart.Position.Y
 
    local raycastParams = RaycastParams.new()
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude
    raycastParams.FilterDescendantsInstances = {characterModel} 
 
    local isMoving = true
    local lastPosition = hrpPart.Position
    local lastMoveTime = os.clock()
    local STUCK_THRESHOLD = 3 

    task.spawn(function()
        while isMoving do
            task.wait(0.5)
            if not hrpPart or not hrpPart.Parent then break end
            
            local currentPos = hrpPart.Position
            local distanceMoved = (currentPos - lastPosition).Magnitude
            
            if distanceMoved > 0.5 then
                lastPosition = currentPos
                lastMoveTime = os.clock()
            else
                if os.clock() - lastMoveTime >= STUCK_THRESHOLD then
                    warn("[Watchdog] Phát hiện kẹt map! Dịch chuyển thẳng tới vị trí đích...")
                    hrpPart.CFrame = CFrame.new(finalTarget)
                    break
                end
            end
        end
    end)
 
    while true do
        if not hrpPart or not hrpPart.Parent then 
            isMoving = false
            break 
        end
        
        local currentPos = hrpPart.Position
        local flatTarget = Vector3.new(finalTarget.X, lockedYHeight, finalTarget.Z)
        local remainingVector = flatTarget - currentPos
        local totalDistance = remainingVector.Magnitude
 
        if totalDistance <= 2 or totalDistance <= STEP_DISTANCE then
            hrpPart.CFrame = CFrame.new(finalTarget)
            hrpPart.AssemblyLinearVelocity = Vector3.new(0, -5, 0) 
            hrpPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0)
            hrpPart.Anchored = true
            task.wait(0.05)
            hrpPart.Anchored = false 
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
 
        hrpPart.CFrame = CFrame.new(flattenedPosition)
        task.wait(delayInterval)
    end
    isMoving = false
end

-- --- 4. CƠ CHẾ TƯƠNG TÁC VÀ KÍCH HOẠT REPLAY LUÔN KHI XONG ---
local function interactWithClosestPowerBox()
    local char = LocalPlayer.Character or LocalPlayer.CharacterAdded:Wait()
    local hrpPart = char:WaitForChild("HumanoidRootPart")
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
        local currentPos = hrpPart.Position
        table.sort(powerBoxData, function(a, b)
            return (currentPos - a.Position).Magnitude < (currentPos - b.Position).Magnitude
        end)
 
        local chosenBox = powerBoxData[1].Instance
        local finalBoxTarget = powerBoxData[1].Position
 
        print("[PowerBox] Tiến hành di chuyển xuyên tường tới Power Box...")
        adaptiveCrawlTo(finalBoxTarget, hrpPart, char)
        
        if (hrpPart.Position - finalBoxTarget).Magnitude < 15 then
            local prompt = chosenBox:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt then
                print("[PowerBox] Đang thực hiện kích hoạt nút sửa máy...")
                
                if fireproximityprompt then
                    fireproximityprompt(prompt)
                else
                    prompt:InputHoldBegin()
                    task.wait(prompt.HoldDuration + 0.02)
                    prompt:InputHoldEnd()
                end
                
                -- CHỈ VOTE REPLAY LẬP TỨC KHÔNG KICK/TELEPORT THỦ CÔNG
                print("[PowerBox] Sửa máy thành công! Đang kích hoạt Vote Chơi Lại...")
                forceVotePlayAgain("Hoàn thành sửa máy (Power Box)")
            end
        end
    else
        warn("[PowerBox] Hiện tại không tìm thấy Power Box nào. Kích hoạt Vote đổi phòng...")
        forceVotePlayAgain("Không tìm thấy Power Box trên bản đồ")
    end
end

-- --- 5. BẢO HIỂM WATCHDOG ĐÚNG 60 GIÂY THEO SCRIPT 2 ---
task.delay(60, function()
    forceVotePlayAgain("Quá thời gian quy định cho một lượt farm (Watchdog Timeout 60s)")
end)

-- --- 6. LUỒNG THỰC THI CHÍNH ---
print("[Main] Khởi chạy chu trình sửa máy...")
interactWithClosestPowerBox()
