-- Chờ trò chơi tải xong hoàn toàn
if not game:IsLoaded() then
    game.Loaded:Wait()
end

print("[📱 MOBILE SYSTEM] Khởi chạy luồng tối ưu hóa giao diện cho thiết bị di động...");

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local LobbyRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Lobby")

-- Hàm kích nổ sự kiện Click UI siêu tốc trên Mobile (Bypass delay bấm nút)
local function mobileFriendlyClick(button)
    if not button then return false end
    
    -- Kích hoạt trực tiếp hàm kết nối sự kiện của Roblox để Mobile không bị trễ
    local success = pcall(function() 
        button.MouseButton1Click:Fire() 
    end)
    
    if not success and button:IsA("GuiButton") then
        pcall(function() button:Activated():Fire() end)
    end
    return success
end

-- Hàm thực hiện chuyển Server ít người (Server Hop cho Mobile)
local function hopToLowPlayerServer()
    print("[🔄 SERVER HOP] Đang quét tìm Server vắng...")
    local success = pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local response = game:HttpGet(url)
        local data = HttpService:JSONDecode(response)
        
        if data and data.data then
            for _, server in pairs(data.data) do
                if server.id ~= game.JobId and server.playing and server.playing < server.maxPlayers then
                    print("[🎯] Đang chuyển hướng sang Server vắng...")
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, localPlayer)
                    return true
                end
            end
        end
    end)
    
    if not success then
        TeleportService:Teleport(game.PlaceId, localPlayer)
    end
end

-- =========================================================================
-- BƯỚC 1: QUÉT SẢNH VÀ ĐẾM SỐ PHÒNG ĐÃ CÓ NGƯỜI
-- =========================================================================
local lobbiesFolder = Workspace:FindFirstChild("Lobbies")
local targetHitbox = nil
local occupiedRoomsCount = 0 

if lobbiesFolder then
    for i = 1, 10 do
        local lobby = lobbiesFolder:FindFirstChild(tostring(i))
        if lobby then
            local labelObj = lobby:FindFirstChildWhichIsA("TextLabel", true) or lobby:FindFirstChild("Status", true)
            if labelObj then
                if not (string.find(labelObj.Text, "0/") or string.find(labelObj.Text, "0 Players")) then
                    occupiedRoomsCount = occupiedRoomsCount + 1
                else
                    if not targetHitbox then
                        local hitbox = lobby:FindFirstChild("Hitbox") or lobby:FindFirstChildWhichIsA("BasePart")
                        if hitbox then
                            targetHitbox = hitbox
                        end
                    end
                end
            end
        end
    end
end

print("[📊 SYSTEM] Số lượng phòng đã có người: " .. occupiedRoomsCount)

-- Nếu từ 3 phòng trở lên đã có người, tự động đổi Server ngay
if occupiedRoomsCount >= 3 then
    warn("[🚨 WARNING] Sảnh đông. Đang Hop Server...")
    hopToLowPlayerServer()
    return false
end

-- =========================================================================
-- BƯỚC 2: TỰ DI CHUYỂN VÀ XỬ LÝ UI MOBILE AN TOÀN (NÉ NÚT LEAVE ĐỎ CHÉT)
-- =========================================================================
if targetHitbox then
    local char = localPlayer.Character or localPlayer.CharacterAdded:Wait()
    local humanoid = char:WaitForChild("Humanoid")
    local rootPart = char:WaitForChild("HumanoidRootPart")
    
    -- Chạy bộ đến ô phòng trống giống người thật nhằm bypass anti-cheat
    humanoid:MoveTo(targetHitbox.Position)
    local startTime = tick()
    while (rootPart.Position - targetHitbox.Position).Magnitude > 4 do
        task.wait(0.1)
        if tick() - startTime > 8 then break end
    end
    
    task.wait(0.6) -- Đợi sảnh nhận diện ổn định vị trí nhân vật
    
    pcall(function()
        LobbyRemotes.CreateParty:InvokeServer()
    end)
    
    task.wait(1.5) -- Đợi UI mở hẳn ra trên thiết bị Mobile

    local mainGui = playerGui:FindFirstChild("Main")
    local createPartyWindow = mainGui and mainGui:FindFirstChild("CreateParty")
    
    if createPartyWindow then
        local buttonOne = createPartyWindow:FindFirstChild("1") or createPartyWindow:FindFirstChildWhichIsA("GuiButton", true)
        local createButton = createPartyWindow:FindFirstChild("Create") or createPartyWindow:FindFirstChild("Confirm", true)
        
        -- 🌟 GIẢI PHÁP NÉ NÚT LEAVE ĐỎ: Tìm nút Leave ingame và khóa nó lại trước khi click Create
        -- Thay thế "Leave" bằng tên chính xác của nút Đỏ trong cấu trúc UI nếu nó nằm chỗ khác
        local leaveButton = createPartyWindow:FindFirstChild("Leave") or mainGui:FindFirstChild("Leave", true)
        if leaveButton then
            print("[🔒 SYSTEM] Đã phát hiện nút Leave đỏ! Đang tạm khóa để chống bấm nhầm...");
            leaveButton.Visible = false --Ẩn tạm thời nút Leave đi để script không thể tương tác trúng
        end
        
        -- 1. Click chọn ô số 1 người trên Mobile
        if buttonOne then
            print("[🎯] Đang chọn ô 1 người...");
            mobileFriendlyClick(buttonOne)
            task.wait(0.6) -- Chờ UI Mobile cập nhật dữ liệu phòng lên Server
        end
        
        -- 2. Click nút Create để khởi động nạp Map
        if createButton then
            print("[🎯] Đang bấm nút Create để tạo trận...");
            mobileFriendlyClick(createButton)
            print("[🔥 SUCCESS] Đã tạo phòng thành công! Toàn bộ luồng bấm dừng lại.");
        end
        
        -- Mở khóa lại nút Leave sau khi nạp map thành công (nếu cần)
        task.wait(0.5)
        if leaveButton then
            leaveButton.Visible = true
        end
    else
        warn("[❌] Không tìm thấy bảng giao diện tạo phòng!")
    end
else
    warn("[⚠️] Sảnh đầy phòng, thực hiện đổi Server...")
    hopToLowPlayerServer()
end

return true
