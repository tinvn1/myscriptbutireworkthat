-- Feel free to adjust
-- Optimized Custom Mode: Pure Power Box Route (Using Original Crawl Mechanic)
-- Original Author: TheAnonymous in RScript
-- Updated & Optimized by: TinHub Project + FireProximityPrompt + Gem Watchdog

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
local UserInputService = game:GetService("UserInputService")
local StarterGui = game:GetService("StarterGui")
local HttpService = game:GetService("HttpService")
 
-- --- CONFIGURATION & REFERENCES ---
local LocalPlayer = Players.LocalPlayer
local MapFolder = Workspace:FindFirstChild("Map")
local PermanentNoclipEnabled = true

-- BIẾN KIỂM SOÁT LUỒNG TOÀN CỤC KHẨN CẤP
local forceStopInteraction = false
local initialGemValue = 0

-- Hàm chuyển đổi text Gem (Ví dụ: "1,250", "500") sang dạng số để so sánh
local function parseGemCount(gemStr)
    local cleaned = string.gsub(gemStr, "[^%d]", "") -- Lọc bỏ dấu phẩy hoặc ký tự lạ
    return tonumber(cleaned) or 0
end

-- Lấy Object chứa Text Gem hiện tại
local function getGemCountInstance()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        local mainUI = playerGui:FindFirstChild("MainUI")
        if mainUI then
            return mainUI:FindFirstChild("GemDisplay") and mainUI.GemDisplay:FindFirstChild("Count")
        end
    end
    return nil
end
 
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

-- --- AUTOMATED GEM LOGGING & WATCHDOG SYSTEM ---
local function startGemWatchdog()
    task.spawn(function()
        local gemCountInst = getGemCountInstance()
        local timeout = 0
        while not gemCountInst and timeout < 10 do
            task.wait(0.5)
            gemCountInst = getGemCountInstance()
            timeout = timeout + 0.5
        end

        if gemCountInst then
            initialGemValue = parseGemCount(gemCountInst.Text)
            print("[Gem Watchdog] Khoi tao so luong Gem ban dau: " .. tostring(initialGemValue))

            -- GỬI WEBHOOK BAN ĐẦU (ANTI-SPAM)
            if not _G.Webhook_Already_Sent then
                local requestFunc = json or request or (syn and syn.request) or (http and http.request) or http_request
                local TargetWebhook = _G.Webhook

                if requestFunc and TargetWebhook and TargetWebhook ~= "" and TargetWebhook ~= "ĐIỀN_LINK_WEBHOOK_DISCORD_TẠI_ĐÂY" then
                    _G.Webhook_Already_Sent = true
                    local payload = {
                        ["embeds"] = {{
                            ["title"] = "💎 THÔNG BÁO SỐ LƯỢNG GEM 💎",
                            ["color"] = 65430,
                            ["fields"] = {
                                {["name"] = "👤 Tên nhân vật:", ["value"] = "||`" .. LocalPlayer.Name .. "`||", ["inline"] = true},
                                {["name"] = "💎 Số lượng Gem hiện tại:", ["value"] = "**" .. gemCountInst.Text .. "**", ["inline"] = true},
                                {["name"] = "🎮 Game ID:", ["value"] = "||`" .. tostring(game.PlaceId) .. "`||", ["inline"] = true}
                            },
                            ["footer"] = {["text"] = "TinHub Project Engine • Hệ thống tự động"},
                            ["timestamp"] = DateTime.now():ToIsoDate()
                        }}
                    }
                    pcall(function()
                        requestFunc({
                            Url = TargetWebhook,
                            Method = "POST",
                            Headers = {["content-type"] = "application/json"},
                            Body = HttpService:JSONEncode(payload)
                        })
                        print("[🚀 SYSTEM] Webhook bao cao Gem da gui thanh cong!")
                    end)
                end
            end

            -- VÒNG LẶP KIỂM TRA TĂNG GEM ĐỂ VOTEPLAYAGAIN LẬP TỨC
            while true do
                task.wait(0.1)
                if forceStopInteraction then break end
                
                local currentGemValue = parseGemCount(gemCountInst.Text)
                if currentGemValue > initialGemValue then
                    print("[🔥 CRITICAL] PHÁT HIỆN GEM TĂNG LÊN HOẶC THAY ĐỔI! LẬP TỨC ĐỔI SERVER")
                    forceStopInteraction = true 
                    
                    local PlayAgainRemote = ReplicatedStorage:FindFirstChild("Remotes") 
                        and ReplicatedStorage.Remotes:FindFirstChild("Misc") 
                        and ReplicatedStorage.Remotes.Misc:FindFirstChild("VotePlayAgain")
                    
                    if PlayAgainRemote and PlayAgainRemote:IsA("RemoteEvent") then
                        pcall(function()
                            PlayAgainRemote:FireServer()
                        end)
                        print("[Watchdog Success] Da gui lenh VotePlayAgain khan cap khi nhan duoc Gem!")
                    end
                    break
                end
            end
        end
    end)
end
 
-- --- PIPELINE EXECUTION ENGINE ---
local function runPipeline()
    startGemWatchdog() -- Khởi chạy hệ thống quét Gem ngầm

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
 
        -- ===================================================================
        -- 3. CƠ CHẾ TÁC ĐỘNG TỪ XA GỐC (THAY THẾ HOÀN TOÀN TRIPLE TAP VIRTUAL INPUT)
        -- ===================================================================
        if (humanoidRootPart.Position - finalBoxTarget).Magnitude < 15 then
            local prompt = chosenBox:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt then
                if forceStopInteraction then return end -- Ngắt nếu Gem nhảy sớm

                StarterGui:SetCore("SendNotification", {
                    Title = "Interaction System",
                    Text = "Đang kích hoạt bẻ khóa Power Box từ xa...",
                    Duration = 2
                })

                print("[Pipeline] Đang ép tương tác ProximityPrompt bằng Bypass Engine...")
                for i = 1, 3 do -- Lặp 3 lần liên tiếp để tránh mất gói tin
                    if forceStopInteraction then return end
                    
                    if fireproximityprompt then
                        -- Ưu tiên sử dụng hàm gốc của các bản Executor chuyên dụng (Bypass Hold cực nhanh)
                        fireproximityprompt(prompt)
                    else
                        -- Phương án dự phòng chuẩn Core-Engine nếu chạy Executor thường không có hàm trên
                        prompt:InputHoldBegin()
                        task.wait(prompt.HoldDuration + 0.05)
                        prompt:InputHoldEnd()
                    end
                    task.wait(0.1)
                end

                print("[Pipeline] Tác động thành công! Đã bỏ qua chu kỳ gõ/chạm màn hình.")
                interactionSuccess = true
            end
        end
    else
        warn("[Warning] Không tìm thấy bất kỳ Power Box nào trên bản đồ này!")
    end
 
    -- --- VOTE PLAY AGAIN SEQUENCE (TỰ ĐỘNG ĐỔI TRẬN LẬP TỨC) ---
    if not forceStopInteraction and interactionSuccess then
        task.wait(0.2) -- Giảm thiểu thời gian chờ xuống mức tối đa để đổi phòng siêu tốc
        local PlayAgainRemote = ReplicatedStorage:FindFirstChild("Remotes") 
            and ReplicatedStorage.Remotes:FindFirstChild("Misc") 
            and ReplicatedStorage.Remotes.Misc:FindFirstChild("VotePlayAgain")
 
        if PlayAgainRemote and PlayAgainRemote:IsA("RemoteEvent") then
            pcall(function()
                PlayAgainRemote:FireServer()
            end)
            print("[Play Again] Đã gửi lệnh đổi server siêu tốc.")
        end
    end
end

runPipeline()

-- Watchdog kiểm soát kẹt phòng (Giảm xuống còn 35 giây vì script giờ kết thúc siêu tốc)
task.spawn(function()
    task.wait(35.0) 
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
