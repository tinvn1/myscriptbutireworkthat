local Workspace = game:GetService("Workspace") [cite: 1]
local RunService = game:GetService("RunService") [cite: 1]
local Players = game:GetService("Players") [cite: 1]
local localPlayer = Players.LocalPlayer [cite: 1]

local PermanentNoclipEnabled = true [cite: 1]

-- =========================================================================
-- 🟩 1. BACKGROUND SERVICE: PERMANENT NOCLIP ENGINE
-- =========================================================================
local function StartPermanentNoclip() [cite: 1]
    local noclipConnection = nil [cite: 1]

    local function ConnectNoclip() [cite: 1]
        if noclipConnection then noclipConnection:Disconnect() end [cite: 1]

        noclipConnection = RunService.Stepped:Connect(function() [cite: 1]
            if not PermanentNoclipEnabled then [cite: 1]
                if noclipConnection then noclipConnection:Disconnect() end [cite: 2]
                return [cite: 2]
            end [cite: 2]

            local character = localPlayer.Character [cite: 2]
            if character then [cite: 2]
                for _, child in ipairs(character:GetDescendants()) do [cite: 2]
                    if child:IsA("BasePart") and child.CanCollide then [cite: 3]
                        child.CanCollide = false [cite: 3]
                    end [cite: 3]
                end [cite: 3]
            end [cite: 2]
        end) [cite: 1]
    end [cite: 1]

    ConnectNoclip() [cite: 1]
    
    localPlayer.CharacterAdded:Connect(function() [cite: 4]
        task.wait(0.2) [cite: 4]
        ConnectNoclip() [cite: 4]
    end) [cite: 4]
end [cite: 1]

StartPermanentNoclip() [cite: 1]

-- =========================================================================
-- 🟩 2. UNDERGROUND PHYSICAL GLIDE ENGINE
-- =========================================================================
local function executePhysicalStage(subTarget, speed, character, humanoidRootPart, stopDistance)
    stopDistance = stopDistance or 2.0 -- Mặc định là 2 studs [cite: 5]

    local lastPosition = humanoidRootPart.Position [cite: 4]
    local lastMoveTime = os.clock() [cite: 4]
    local isStuck = false [cite: 4]

    local raycastParams = RaycastParams.new() [cite: 4]
    raycastParams.FilterType = Enum.RaycastFilterType.Exclude [cite: 4]
    raycastParams.FilterDescendantsInstances = {character} [cite: 4]

    while true do [cite: 4]
        if not humanoidRootPart or not humanoidRootPart.Parent then break end [cite: 4]
        
        local currentPos = humanoidRootPart.Position [cite: 4]
        local remainingVector = subTarget - currentPos [cite: 4]
        local distance = remainingVector.Magnitude [cite: 4]

        -- ĐẠT ĐẾN KHOẢNG CÁCH YÊU CẦU THÌ DỪNG CHẶNG
        if distance <= stopDistance then
            humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0) [cite: 5]
            break [cite: 5]
        end

        -- Bộ lọc chống kẹt cứng địa hình [cite: 6]
        if (currentPos - lastPosition).Magnitude > 0.15 then [cite: 6]
            lastPosition = currentPos [cite: 6]
            lastMoveTime = os.clock() [cite: 6]
        else [cite: 6]
            if os.clock() - lastMoveTime >= 3.5 then [cite: 6]
                isStuck = true [cite: 7]
                break [cite: 7]
            end [cite: 6]
        end [cite: 6]

        local direction = remainingVector.Unit [cite: 7]

        -- Kiểm tra vật cản (Đất/Sàn) để tinh chỉnh vận tốc thích hợp [cite: 7]
        local rayResult = Workspace:Raycast(currentPos, direction * 4, raycastParams) [cite: 7]
        local currentAllowedSpeed = speed [cite: 7]
        if rayResult and rayResult.Instance and rayResult.Instance.CanCollide then [cite: 8]
            currentAllowedSpeed = 4.0 -- Ép đi cực chậm khi đang xuyên qua lớp vỏ bản đồ / nền đất dày [cite: 8]
        end [cite: 8]

        -- Bơm thẳng lực vận tốc 3D [cite: 8]
        humanoidRootPart.AssemblyLinearVelocity = direction * currentAllowedSpeed [cite: 8]
        humanoidRootPart.AssemblyAngularVelocity = Vector3.new(0, 0, 0) [cite: 8]
        humanoidRootPart.CFrame = CFrame.new(currentPos, subTarget) [cite: 9]

        RunService.Heartbeat:Wait() [cite: 9]
    end [cite: 9]

    if isStuck then [cite: 9]
        humanoidRootPart.CFrame = CFrame.new(subTarget) [cite: 9]
    end [cite: 9]
end

-- =========================================================================
-- 🟩 3. CORE TUNNELING CONTROLLER
-- =========================================================================
local function moveWithUndergroundTunnel(targetPos, humanoidRootPart, character, onReached6Studs)
    local humanoid = character:FindFirstChildWhichIsA("Humanoid") [cite: 9]
    local finalTarget = targetPos + Vector3.new(0, 3, 0) [cite: 9]
    
    local CRUISE_SPEED = 26     -- Tốc độ lướt ngầm dưới lòng đất công cộng [cite: 9]
    local DIG_DEPTH = 35        -- Độ sâu đục xuống dưới sàn (35 studs) [cite: 10]

    -- Vô hiệu hóa trọng lực nội tại thông qua Humanoid State [cite: 10]
    if humanoid then [cite: 10]
        humanoid.PlatformStand = true [cite: 10]
        humanoid:ChangeState(Enum.HumanoidStateType.Physics) [cite: 10]
    end [cite: 10]
    
    -- Kích hoạt VectorForce triệt tiêu hoàn toàn Gravity của bản đồ [cite: 10]
    local attachment = Instance.new("Attachment") [cite: 10]
    attachment.Parent = humanoidRootPart [cite: 10]
    
    local vectorForce = Instance.new("VectorForce") [cite: 11]
    vectorForce.Attachment0 = attachment [cite: 11]
    vectorForce.Force = Vector3.new(0, Workspace.Gravity * humanoidRootPart:GetMass(), 0) [cite: 11]
    vectorForce.RelativeTo = Enum.ActuatorRelativeTo.World [cite: 11]
    vectorForce.Parent = humanoidRootPart [cite: 11]

    local startPos = humanoidRootPart.Position [cite: 11]

    -- 🔽 GIAI ĐOẠN 1: Đục thẳng đứng xuống dưới lòng đất [cite: 11]
    print("[Tunnel] Phase 1: Digging vertically downward...") [cite: 11]
    local stage1_Target = Vector3.new(startPos.X, startPos.Y - DIG_DEPTH, startPos.Z) [cite: 11]
    executePhysicalStage(stage1_Target, 15, character, humanoidRootPart, 2.0) [cite: 11]
    task.wait(0.05) [cite: 11]

    -- ↔️ GIAI ĐOẠN 2: Di chuyển ngang tốc độ cao [cite: 11]
    print("[Tunnel] Phase 2: Traveling horizontally underground...") [cite: 11]
    local stage2_Target = Vector3.new(finalTarget.X, startPos.Y - DIG_DEPTH, finalTarget.Z) [cite: 12]
    executePhysicalStage(stage2_Target, CRUISE_SPEED, character, humanoidRootPart, 2.0) [cite: 12]
    task.wait(0.05) [cite: 12]

    -- 🔼 GIAI ĐOẠN 3: Chồi thẳng đứng lên - DỪNG CHÍNH XÁC KHI CÁCH 6 STUDS
    print("[Tunnel] Phase 3: Popping up... Stopping early at 6 studs.") [cite: 12]
    executePhysicalStage(finalTarget, 15, character, humanoidRootPart, 6.0) -- Phanh lại khi cách mục tiêu 6 studs

    -- 🔥 GỌI SCRIPT TIẾP THEO NGAY LẬP TỨC THÔNG QUA HÀM BẤT ĐỒNG BỘ
    if onReached6Studs then
        task.spawn(onReached6Studs)
    end

    -- [TIẾP TỤC CHẠY HẾT CODE CŨ]: Nhích nốt quãng đường còn lại để hoàn thành tương tác cũ
    executePhysicalStage(finalTarget, 10, character, humanoidRootPart, 1.5)

    -- 🧼 DỌN DẸP HỆ THỐNG VẬT LÝ SAU KHI TIẾP CẬN THÀNH CÔNG [cite: 12]
    vectorForce:Destroy() [cite: 12]
    attachment:Destroy() [cite: 13]
    if humanoid then [cite: 13]
        humanoid.PlatformStand = false [cite: 13]
        humanoid:ChangeState(Enum.HumanoidStateType.GettingUp) [cite: 13]
    end [cite: 13]

    -- Khóa vị trí tuyệt đối để triệt tiêu quán tính rò rỉ [cite: 13]
    humanoidRootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0) [cite: 13]
    humanoidRootPart.CFrame = CFrame.new(finalTarget) [cite: 13]
    humanoidRootPart.Anchored = true [cite: 13]
    task.wait(0.05) [cite: 13]
    humanoidRootPart.Anchored = false [cite: 13]
end

-- =========================================================================
-- 🟩 4. PIPELINE EXECUTION ENGINE
-- =========================================================================
local function runPowerBoxPipeline()
    local character = localPlayer.Character or localPlayer.CharacterAdded:Wait() [cite: 13]
    local humanoidRootPart = character:WaitForChild("HumanoidRootPart") [cite: 14]

    local powerBoxData = {} [cite: 14]

    local function ScanDirectory(root) [cite: 14]
        if not root then return end [cite: 14]
        for _, child in ipairs(root:GetDescendants()) do [cite: 14]
            if child.Name == "Power Box" and child:IsA("Model") then [cite: 14]
                table.insert(powerBoxData, { [cite: 14]
                    Instance = child, [cite: 14]
                    Position = child:GetPivot().Position [cite: 15]
                }) [cite: 14]
            end [cite: 14]
        end [cite: 14]
    end [cite: 14]

    local MapFolder = Workspace:FindFirstChild("Map") [cite: 15]
    if MapFolder then ScanDirectory(MapFolder) else ScanDirectory(Workspace) end [cite: 15]

    if #powerBoxData > 0 then [cite: 15]
        local currentPos = humanoidRootPart.Position [cite: 15]
        table.sort(powerBoxData, function(a, b) [cite: 16]
            return (currentPos - a.Position).Magnitude < (currentPos - b.Position).Magnitude [cite: 16]
        end) [cite: 16]

        local chosenBox = powerBoxData[1].Instance [cite: 16]
        local finalBoxTarget = powerBoxData[1].Position [cite: 16]

        print("[Pipeline] Executing Underground Tunnel Core...") [cite: 16]

        -- Định nghĩa kịch bản tiếp theo sẽ chạy khi đạt khoảng cách 6 studs
        local function ThucHienScriptTiepTheo()
            print("[Trigger] ĐÃ ĐẠT 6 STUDS! Đang kích hoạt chạy script tiếp theo...")
            
            -------------------------------------------------------------
            -- 💡 DÁN CODE CỦA SCRIPT TIẾP THEO CỦA BẠN DƯỚI ĐÂY:
            -------------------------------------------------------------
            -- Ví dụ: loadstring(game:HttpGet("link_script.lua"))()
            
        end

        -- Gọi hàm di chuyển ngầm, truyền kèm theo hành động chạy script tiếp theo
        moveWithUndergroundTunnel(finalBoxTarget, humanoidRootPart, character, ThucHienScriptTiepTheo) [cite: 16]
        task.wait(0.1)

        -- Kích hoạt ProximityPrompt (Code gốc vẫn chạy để hoàn thành tương tác) [cite: 17]
        if (humanoidRootPart.Position - finalBoxTarget).Magnitude < 15 then [cite: 17]
            local prompt = chosenBox:FindFirstChildWhichIsA("ProximityPrompt", true) [cite: 17]
            if prompt then [cite: 17]
                print("[Pipeline] Interacting with Power Box...") [cite: 17]
                for i = 1, 3 do [cite: 17]
                    if fireproximityprompt then [cite: 18]
                        fireproximityprompt(prompt) [cite: 18]
                    else [cite: 18]
                        prompt:InputHoldBegin() [cite: 18]
                        task.wait(prompt.HoldDuration + 0.05) [cite: 19]
                        prompt:InputHoldEnd() [cite: 19]
                    end [cite: 18]
                    task.wait(0.1) [cite: 19]
                end [cite: 19]
                print("[Pipeline] Interaction successfully completed!") [cite: 20]
            end [cite: 17]
        end [cite: 17]
    else [cite: 20]
        warn("[Warning] No valid Power Box found on the map.") [cite: 20]
    end [cite: 20]
end [cite: 20]

runPowerBoxPipeline() [cite: 20]
