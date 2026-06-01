-- Chờ trò chơi tải xong xuôi
if not game:IsLoaded() then
    game.Loaded:Wait()
end

print("[🚀 MOBILE COMBINED] Đang khởi chạy hệ thống gộp: Kill Aura + Mobile Auto Drag...");

local RunService = game:GetService("RunService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local localPlayer = Players.LocalPlayer

-- ====================================================================
-- BẢNG CẤU HÌNH TỐI ƯU TOÀN DIỆN CHO ĐIỆN THOẠI
-- ====================================================================
local CONFIG = {
    -- Cấu hình Kill Aura (Đập quái/Phế liệu)
    AuraEnabled = true,        -- Bật/Tắt Kill Aura
    MaxDistance = 16,          -- Khoảng cách quét (Studs)
    AttackDelay = 0.12,        -- Tốc độ đánh (0.12s tối ưu cho ping mạng di động)
    MaxTargets = 4,            -- Tối đa 4 mục tiêu cùng lúc

    -- Cấu hình Auto Drag (Nhặt đồ chuẩn Mobile)
    DragEnabled = true,        -- Bật/Tắt Auto Drag
    DetectRange = 15,           -- Tầm quét 9 studs vừa phải để Mobile né gom quá nhiều đồ gây lag
    FollowDistance = 2.5,      -- Giữ đồ sát hông (2.5 studs) để giảm biên độ lắc lư khi đổi hướng
    MaxHoldingItems = 8,       -- Giới hạn gom tối đa 8 món để tránh quá tải engine vật lý của điện thoại

    -- Các thư mục quét của game
    SearchFolders = {
        Workspace:FindFirstChild("Characters"),
        Workspace:FindFirstChild("Structures"),
    },
    DroppedItemsFolder = Workspace:WaitForChild("DroppedItems")
}

local holdingItems = {}
local currentHoldingCount = 0

-- ====================================================================
-- CÁC HÀM BỔ TRỢ (UTILITIES)
-- ====================================================================

-- [Kill Aura] Kiểm tra mục tiêu hợp lệ
local function isValidTarget(obj, character)
    if not obj or obj == character or obj:IsAncestorOf(character) then return false end
    if Players:GetPlayerFromCharacter(obj) then return false end
    
    if string.find(string.lower(obj.Name), "scrap pile") then
        return true
    end
    
    local humanoid = obj:FindFirstChildWhichIsA("Humanoid")
    if humanoid and humanoid.Health > 0 then
        return true
    end
    
    return false
end

-- [Kill Aura] Lấy vũ khí và Remote
local function getBatStuff()
    local character = localPlayer.Character
    if character then
        local bat = character:FindFirstChild("Bat")
        local autoTarget = character:FindFirstChild("AutoTargetClient")
        if bat and bat:FindFirstChild("Swing") and bat:FindFirstChild("HitTargets") and autoTarget and autoTarget:FindFirstChild("UpdateNearbyTargets") then
            return bat, autoTarget.UpdateNearbyTargets
        end
    end
    return nil, nil
end

-- [Auto Drag] Lấy Remote kéo đồ
local function getDragRemote()
    local character = localPlayer.Character
    if not character then return nil end
    local dragSystem = character:FindFirstChild("DragSystem")
    return dragSystem and dragSystem:FindFirstChild("DragItem") or nil
end

-- [Auto Drag] Giả lập kích hoạt hệ thống DragDetector
local function triggerDragSystem(item, itemPart)
    local dragDetector = item:FindFirstChildWhichIsA("DragDetector") or item:FindFirstChildOfClass("DragDetector")
    if dragDetector and firesignal then
        firesignal(dragDetector.DragStart, localPlayer)
    end

    local networkRemote = item:FindFirstChild("ItemDrag") and item.ItemDrag:FindFirstChild("RequestNetworkOwnership")
    if networkRemote then
        pcall(function()
            networkRemote:FireServer(itemPart)
        end)
    end
end

-- [Auto Drag] Vô hiệu hóa va chạm để chống văng (Anti-Fling)
local function noClipItem(item)
    if item:IsA("BasePart") then
        item.CanCollide = false
    end
    for _, child in ipairs(item:GetDescendants()) do
        if child:IsA("BasePart") then
            child.CanCollide = false
            child.Velocity = Vector3.zero
            child.RotVelocity = Vector3.zero
        end
    end
end

-- ====================================================================
-- LUỒNG XỬ LÝ KÉO ĐỒ CHUẨN MOBILE (CẢI TIẾN KHÓA GÓC XOAY)
-- ====================================================================
local function attachmentDrag(item, rootPart)
    if holdingItems[item] or currentHoldingCount >= CONFIG.MaxHoldingItems then return end
    
    local itemPart = item:FindFirstChild("Union") or item:FindFirstChild("Can") or (item:IsA("Model") and item.PrimaryPart) or item:FindFirstChildWhichIsA("BasePart") or item
    if not itemPart then return end
    
    triggerDragSystem(item, itemPart)
    task.wait(0.03)
    
    local dragRemote = getDragRemote()
    if not dragRemote then return end

    holdingItems[item] = true
    currentHoldingCount = currentHoldingCount + 1
    noClipItem(item)

    task.spawn(function()
        pcall(function()
            dragRemote:FireServer(item, itemPart)
        end)
    end)

    -- Điểm kết nối trên vật phẩm
    local attItem = Instance.new("Attachment")
    attItem.Name = "MobileDragAttItem"
    attItem.Parent = itemPart

    -- Điểm kết nối sau hông người chơi
    local attPlayer = Instance.new("Attachment")
    attPlayer.Name = "MobileDragAttPlayer"
    attPlayer.Position = Vector3.new(0, 0.5, CONFIG.FollowDistance)
    attPlayer.Parent = rootPart

    -- [Giữ Nguyên Cơ Chế] Kéo vị trí vật thể bằng AlignPosition
    local alignPos = Instance.new("AlignPosition")
    alignPos.Name = "DragAlignPos"
    alignPos.Mode = Enum.PositionAlignmentMode.TwoAttachment
    alignPos.Attachment0 = attItem
    alignPos.Attachment1 = attPlayer
    alignPos.MaxForce = 99999
    alignPos.Responsiveness = 30
    alignPos.Parent = item

    -- 🔥 [Cải Tiến Cho Mobile] Khóa cứng góc xoay bằng AlignOrientation (Chống cấn tường gây văng)
    local alignOri = Instance.new("AlignOrientation")
    alignOri.Name = "DragAlignOri"
    alignOri.Mode = Enum.OrientationAlignmentMode.TwoAttachment
    alignOri.Attachment0 = attItem
    alignOri.Attachment1 = attPlayer
    alignOri.MaxTorque = 99999
    alignOri.Responsiveness = 30
    alignOri.Parent = item
    
    -- Duy trì No-Clip ổn định theo nhịp Stepped
    local noClipConnection
    noClipConnection = RunService.Stepped:Connect(function()
        if not item or not item.Parent or not holdingItems[item] then
            if holdingItems[item] then
                holdingItems[item] = nil
                currentHoldingCount = math.max(0, currentHoldingCount - 1)
            end
            noClipConnection:Disconnect()
            return
        end
        if itemPart and itemPart.Parent then
            itemPart.CanCollide = false
        end
    end)
end

-- ====================================================================
-- KÍCH HOẠT VÒNG LẶP ĐỒNG THỜI (CORE LOOPS)
-- ====================================================================

-- 1. Luồng chạy Kill Aura độc lập (Cực mượt)
task.spawn(function()
    print("[⚔️] Tiến trình Kill Aura Mobile đã kích hoạt.");
    while task.wait(CONFIG.AttackDelay) do
        if not CONFIG.AuraEnabled then continue end
        
        local character = localPlayer.Character
        local hrp = character and character:FindFirstChild("HumanoidRootPart")
        local bat, updateNearbyRemote = getBatStuff()
        
        if hrp and bat then
            local rawTargets = {}
            
            for _, folder in pairs(CONFIG.SearchFolders) do
                if folder then
                    for _, obj in pairs(folder:GetChildren()) do
                        if isValidTarget(obj, character) then
                            table.insert(rawTargets, obj)
                        end
                    end
                end
            end
            
            if getnilinstances then
                for _, obj in pairs(getnilinstances()) do
                    if obj:IsA("Model") and isValidTarget(obj, character) then
                        table.insert(rawTargets, obj)
                    end
                end
            end
            
            local validTargetsWithDist = {}
            for _, obj in pairs(rawTargets) do
                local targetPart = obj:FindFirstChild("HumanoidRootPart") 
                    or obj:FindFirstChild("Torso") 
                    or (obj:IsA("Model") and (obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart"))) 
                    or (obj:IsA("BasePart") and obj)
                
                if targetPart then
                    local distance = (hrp.Position - targetPart.Position).Magnitude
                    if distance <= CONFIG.MaxDistance then
                        table.insert(validTargetsWithDist, {instance = obj, dist = distance})
                    end
                end
            end
            
            table.sort(validTargetsWithDist, function(a, b) return a.dist < b.dist end)
            
            local targetsToAttack = {}
            for i = 1, math.min(#validTargetsWithDist, CONFIG.MaxTargets) do
                table.insert(targetsToAttack, validTargetsWithDist[i].instance)
            end
            
            if #targetsToAttack > 0 then
                bat.Swing:FireServer()
                local packedArgs = { [1] = targetsToAttack }
                updateNearbyRemote:FireServer(unpack(packedArgs))
                bat.HitTargets:FireServer(unpack(packedArgs))
            end
        end
    end
end)

-- 2. Luồng quét nhặt vật phẩm Auto Drag theo khung hình Heartbeat
RunService.Heartbeat:Connect(function()
    if not CONFIG.DragEnabled then return end
    
    local character = localPlayer.Character
    local rootPart = character and character:FindFirstChild("HumanoidRootPart")
    if not rootPart then return end
    
    if currentHoldingCount >= CONFIG.MaxHoldingItems then return end
    
    local items = CONFIG.DroppedItemsFolder:GetChildren()
    for i = 1, #items do
        local item = items[i]
        
        if not holdingItems[item] then
            local itemPosition = item:IsA("Model") and item:GetPivot().Position or (item:IsA("BasePart") and item.Position)
            
            if itemPosition then
                local distance = (rootPart.Position - itemPosition).Magnitude
                if distance <= CONFIG.DetectRange then
                    attachmentDrag(item, rootPart)
                    if currentHoldingCount >= CONFIG.MaxHoldingItems then 
                        break 
                    end
                end
            end
        end
    end
end)

print("[🎉 SUCCESS] Toàn bộ hệ thống Kill Aura + Mobile Auto Drag đã chạy đồng bộ!");
return true
