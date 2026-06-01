-- Feel free to adjust
-- Optimized Custom Mode: Pure Power Box Route (Using Original Crawl Mechanic)
-- Original Author: TheAnonymous in RScript
-- Updated & Optimized by: TinHub Project + Auto Hold, Triple Tap/Press (Double Sequence) + Gem Watchdog

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
local HttpService = game:GetService("HttpService")
local Camera = workspace.CurrentCamera
 
-- --- CONFIGURATION & REFERENCES ---
local LocalPlayer = Players.LocalPlayer
local MapFolder = Workspace:FindFirstChild("Map")
local PermanentNoclipEnabled = true

local OFFSET_DOWN = 20     -- Độ thấp dưới tâm màn hình (pixel)
local HOLD_DURATION = 11   -- Đã chỉnh thành 11 giây giữ máy

-- BIẾN KIỂM SOÁT LUỒNG TOÀN CỤC NGẮT KHẨN CẤP
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
                    print("[🔥 CRITICAL] PHÁT HIỆN GEM TĂNG LÊN! (" .. tostring(initialGemValue) .. " -> " .. tostring(currentGemValue) .. ")")
                    forceStopInteraction = true -- Kích hoạt cờ ngắt khẩn cấp luồng tương tác máy điện
                    
                    -- Kích hoạt VotePlayAgain ngay lập tức để đổi server
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
 
        -- 3. CƠ CHẾ NHẤP NHẢ 3 LẦN VÀ TỰ ĐỘNG GIỮ (PC & MOBILE ADAPTIVE)
        if (humanoidRootPart.Position - finalBoxTarget).Magnitude < 15 then
            local prompt = chosenBox:FindFirstChildWhichIsA("ProximityPrompt", true)
            if prompt then
                
                local isPC = UserInputService.KeyboardEnabled and UserInputService.MouseEnabled
                local centerX = Camera.ViewportSize.X / 2
                local targetY = (Camera.ViewportSize.Y / 2) + OFFSET_DOWN

                -- Hàm thực hiện chu kỳ tương tác (Có tích hợp ngắt khẩn cấp)
                local function executeInteractionSequence(sequenceNumber)
                    if forceStopInteraction then return end -- Kiểm tra nếu đã nhận được Gem thì dừng luôn

                    local noticeText = "Lần " .. sequenceNumber .. ": Đang chạm màn hình 3 lần và giữ máy..."
                    if isPC then
                        noticeText = "Lần " .. sequenceNumber .. ": Đang nhấp nhả phím [E] 3 lần và đè giữ..."
                    end

                    StarterGui:SetCore("SendNotification", {
                        Title = "Interaction System",
                        Text = noticeText,
                        Duration = 3
                    })

                    -- [BƯỚC 1]: THỰC HIỆN NHẤP NHẢ 3 LẦN
                    if isPC then
                        print("[Sequence " .. sequenceNumber .. "] Nhấp nhả phím E 3 lần...")
                        for i = 1, 3 do
                            if forceStopInteraction then return end
                            VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                            task.wait(0.05)
                            VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                            task.wait(0.05)
                        end
                    else
                        print("[Sequence " .. sequenceNumber .. "] Chạm màn hình 3 lần...")
                        for i = 1, 3 do
                            if forceStopInteraction then return end
                            VirtualInputManager:SendMouseButtonEvent(centerX, targetY, 0, true, game, 0)
                            task.wait(0.05)
                            VirtualInputManager:SendMouseButtonEvent(centerX, targetY, 0, false, game, 0)
                            task.wait(0.05)
                        end
                    end

                    -- [BƯỚC 2]: BẮT ĐẦU ĐÈ GIỮ (HOLD) CHẶT
                    if forceStopInteraction then return end
                    print("[Sequence " .. sequenceNumber .. "] Đè giữ nút...")
                    VirtualInputManager:SendMouseButtonEvent(centerX, targetY, 0, true, game, 0)
                    if isPC then
                        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
                    end

                    if fireproximityprompt then
                        fireproximityprompt(prompt)
                    else
                        prompt:InputHoldBegin()
                    end

                    -- [BƯỚC 3]: DUY TRÌ TRẠNG THÁI GIỮ TRONG 11 GIÂY (KIỂM TRA TỪNG GIÂY ĐỂ NGẮT SỚM)
                    local timeElapsed = 0
                    while timeElapsed < HOLD_DURATION do
                        if forceStopInteraction then
                            -- Giải phóng nút bấm ngay lập tức nếu bị ngắt ngang do nhận Gem
                            VirtualInputManager:SendMouseButtonEvent(centerX, targetY, 0, false, game, 0)
                            if isPC then VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game) end
                            if not fireproximityprompt then prompt:InputHoldEnd() end
                            return 
                        end
                        task.wait(0.2)
                        timeElapsed = timeElapsed + 0.2
                    end

                    -- [BƯỚC 4]: THẢ RA HOÀN TOÀN KHI HẾT THỜI GIAN KHÔNG BỊ NGẮT
                    VirtualInputManager:SendMouseButtonEvent(centerX, targetY, 0, false, game, 0)
                    if isPC then
                        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
                    end

                    if not fireproximityprompt then
                        prompt:InputHoldEnd()
                    end
                    print("[Sequence " .. sequenceNumber .. "] Đã hoàn thành chu kỳ và nhả phím.")
                end

                -- ====== CHẠY LẦN 1 ======
                executeInteractionSequence(1)
                
                -- Nghỉ ngắn giữa 2 lượt tương tác (Bỏ qua nếu bị ngắt)
                if not forceStopInteraction then task.wait(0.5) end

                -- ====== CHẠY LẦN 2 ======
                executeInteractionSequence(2)

                if not forceStopInteraction then
                    StarterGui:SetCore("SendNotification", {
                        Title = "Interaction System",
                        Text = "Đã hoàn thành chu kỳ sửa máy! Chuẩn bị đổi phòng.",
                        Duration = 3
                    })
                    interactionSuccess = true
                end
            end
        end
    else
        warn("[Warning] Không tìm thấy bất kỳ Power Box nào trên bản đồ này!")
    end
 
    -- --- VOTE PLAY AGAIN SEQUENCE (TỰ ĐỘNG ĐỔI TRẬN THÔNG THƯỜNG) ---
    -- Chỉ chạy khối này nếu chu kỳ chạy hết sạch và không bị kích hoạt bởi cờ ngắt khẩn cấp của Gem
    if not forceStopInteraction and interactionSuccess then
        task.wait(1.0) 
        local PlayAgainRemote = ReplicatedStorage:FindFirstChild("Remotes") 
            and ReplicatedStorage.Remotes:FindFirstChild("Misc") 
            and ReplicatedStorage.Remotes.Misc:FindFirstChild("VotePlayAgain")
 
        if PlayAgainRemote and PlayAgainRemote:IsA("RemoteEvent") then
            pcall(function()
                PlayAgainRemote:FireServer()
            end)
            print("[Play Again] Đã gửi lệnh đổi server thông thường.")
        end
    end
end

runPipeline()

-- Watchdog kiểm soát kẹt phòng
task.spawn(function()
    task.wait(90.0) 
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
