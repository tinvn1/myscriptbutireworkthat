-- Chờ trò chơi tải xong hoàn toàn
if not game:IsLoaded() then
    game.Loaded:Wait()
end

print("[📱 MOBILE SYSTEM] Khởi chạy luồng nạp phòng siêu tốc qua Remote...");

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local localPlayer = Players.LocalPlayer
local LobbyRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Lobby")

-- Hàm thực hiện chuyển Server ít người (Server Hop) khi sảnh bị đông
local function hopToLowPlayerServer()
    print("[🔄 SERVER HOP] Đang quét tìm Server vắng hơn...")
    local success = pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local response = game:HttpGet(url)
        local data = HttpService:JSONDecode(response)
        
        if data and data.data then
            for _, server in pairs(data.data) do
                if server.id ~= game.JobId and server.playing and server.playing < server.maxPlayers then
                    print("[🎯] Tìm thấy Server vắng! Đang chuyển hướng...")
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
            -- Kiểm tra bảng trạng thái số người hiển thị trên ô phòng
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

print("[📊 SYSTEM] Số lượng phòng đã có người ở sảnh này: " .. occupiedRoomsCount)

-- 🚨 Nếu sảnh quá đông (từ 3 phòng trở lên đã hoạt động), tự động đổi Server để tránh tranh chấp ô
if occupiedRoomsCount >= 3 then
    warn("[🚨 WARNING] Sảnh đông. Đang tiến hành đổi Server...")
    hopToLowPlayerServer()
    return false
end

-- =========================================================================
-- BƯỚC 2: DI CHUYỂN VÀ GỬI LỆNH TẠO PHÒNG TRỰC TIẾP (BYPASS UI)
-- =========================================================================
if targetHitbox then
    local char = localPlayer.Character or localPlayer.CharacterAdded:Wait()
    local humanoid = char:WaitForChild("Humanoid")
    local rootPart = char:WaitForChild("HumanoidRootPart")
    
    -- Điều khiển nhân vật chạy bộ vào ô trống để hệ thống sảnh ghi nhận hợp lệ
    print("[🏃] Đang tự động đi vào ô phòng trống...")
    humanoid:MoveTo(targetHitbox.Position)
    
    local startTime = tick()
    while (rootPart.Position - targetHitbox.Position).Magnitude > 4 do
        task.wait(0.1)
        if tick() - startTime > 8 then break end
    end
    
    task.wait(0.8) -- Khoảng trễ nhỏ để dữ liệu vị trí đồng bộ với Server
    
    -- 🌟 Thực hiện gửi gói tin tạo đội trực tiếp mà không cần bấm nút trên màn hình
    print("[⚙️] Đang gửi lệnh khởi tạo tổ đội lên máy chủ...")
    local successCreate = pcall(function()
        LobbyRemotes.CreateParty:InvokeServer()
    end)
    
    if successCreate then
        task.wait(0.5)
        
        -- Cấu hình ép số lượng thành viên tối đa của phòng xuống 1 người (Solo)
        print("[🔒] Đang thiết lập giới hạn phòng: 1 người.");
        pcall(function()
            LobbyRemotes.SetPartySize:InvokeServer(1)
        end)
        
        task.wait(0.5)
        
        -- Kích hoạt tải map đấu đơn ngay lập tức
        print("[🔥] Đang nạp Map... Luồng xử lý kết thúc thành công!");
        pcall(function()
            LobbyRemotes.JoinLobby:InvokeServer("") 
        end)
    else
        warn("[❌] Lệnh khởi tạo phòng thất bại, có thể do trễ mạng.")
    end
else
    warn("[⚠️] Không tìm thấy ô phòng trống nào khả dụng, tiến hành chuyển Server...")
    hopToLowPlayerServer()
end

return true
