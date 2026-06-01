-- Chờ trò chơi tải xong hoàn toàn
if not game:IsLoaded() then
    game.Loaded:Wait()
end

print("[🚀 AUTO LOBBY LOADER] Đang khởi chạy luồng tự động load vào màn chơi...");

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local LobbyRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Lobby")

-- Hàm xử lý kích nổ sự kiện Click UI (Bypass trễ hoàn toàn trên Mobile)
local function safeClick(button)
    if not button then return false end
    if getconnections then
        local clicked = false
        for _, connection in pairs(getconnections(button.MouseButton1Click)) do connection:Fire() clicked = true end
        for _, connection in pairs(getconnections(button.Activated)) do connection:Fire() clicked = true end
        if clicked then return true end
    end
    local success = pcall(function() button.MouseButton1Click:Fire() end)
    return success
end

-- =========================================================================
-- 🏃 BƯỚC 1: TÌM Ô HOÀN TOÀN TRỐNG (0 NGƯỜI) ĐỂ CHIẾM PHÒNG SOLO
-- =========================================================================
local lobbiesFolder = Workspace:FindFirstChild("Lobbies")
local targetHitbox = nil
local selectedRoom = nil

if lobbiesFolder then
    -- Vòng lặp quét nhanh qua 10 phòng của sảnh chờ
    for i = 1, 10 do
        local lobby = lobbiesFolder:FindFirstChild(tostring(i))
        if lobby then
            local labelObj = lobby:FindFirstChildWhichIsA("TextLabel", true) or lobby:FindFirstChild("Status", true)
            
            -- Kiểm tra nếu phòng hiển thị trạng thái trống (0 người hoặc "0/")
            if labelObj and (string.find(labelObj.Text, "0/") or string.find(labelObj.Text, "0 Players")) then
                local hitbox = lobby:FindFirstChild("Hitbox") or lobby:FindFirstChildWhichIsA("BasePart")
                if hitbox then
                    targetHitbox = hitbox
                    selectedRoom = i
                    break
                end
            end
        end
    end
end

-- =========================================================================
-- ⚡ BƯỚC 2: TIẾN HÀNH CHIẾM GIỮ PHÒNG VÀ KHÓA PHÒNG 1 NGƯỜI (SOLO BYPASS)
-- =========================================================================
if targetHitbox then
    print("[💎] Tìm thấy phòng trống số " .. selectedRoom .. "! Tiến hành chiếm giữ phòng...")
    
    local char = localPlayer.Character
    local rootPart = char and char:FindFirstChild("HumanoidRootPart")
    
    if rootPart then
        -- Dịch chuyển tức thời nhân vật chạm vào Hitbox sảnh chờ để kích hoạt sự kiện Join phòng vật lý
        rootPart.CFrame = targetHitbox.CFrame
        task.wait(0.3) -- Chờ tín hiệu phản hồi mạng đồng bộ
    end
    
    -- Gửi Remote yêu cầu tạo Party sảnh chờ độc lập
    pcall(function()
        LobbyRemotes.CreateParty:InvokeServer()
    end)
    
    task.wait(1.2) -- Chờ UI phòng "CreateParty" xuất hiện hoàn chỉnh trên màn hình
    
    -- ÉP BUỘC SERVER: Thay đổi kích thước phòng tối đa xuống 1 người (Ngăn chặn người khác nhảy vào ké)
    print("[⚙️] Đang ép Server hạ giới hạn phòng xuống 1 người để khóa Solo...")
    pcall(function()
        LobbyRemotes.SetPartySize:InvokeServer(1)
    end)
    
    task.wait(0.5) -- Đợi dữ liệu máy chủ cập nhật trạng thái giới hạn phòng thành 1/1
    
    -- Định vị nút bấm "Create" trên giao diện UI để tải map
    local createButton = playerGui:FindFirstChild("Main") 
        and playerGui.Main:FindFirstChild("CreateParty") 
        and playerGui.Main.CreateParty:FindFirstChild("Create")
    
    if createButton then
        print("[🔥] Khóa phòng đơn thành công! Đang nhấn nút khởi động nạp map...")
        safeClick(createButton)
    else
        -- Cơ chế dự phòng: Nếu giao diện UI bị ẩn hoặc lỗi không thấy nút, cưỡng chế gọi Server tự load map bằng Remote
        print("[⚠️] Không thấy nút giao diện UI, gửi Remote cưỡng chế chạy màn chơi đơn từ xa...")
        pcall(function()
            LobbyRemotes.JoinLobby:InvokeServer("")
        end)
    end
else
    -- =========================================================================
    -- 🚨 CƠ CHẾ DỰ PHÒNG: TỰ TẠO PHÒNG CÁCH LY KHI SẢNH CHỜ KHÔNG CÓ Ô TRỐNG
    -- =========================================================================
    warn("[⚠️] Toàn bộ sảnh chờ đều kín phòng! Đang kích hoạt giao thức tạo phòng đơn cách ly khẩn cấp...")
    
    pcall(function()
        LobbyRemotes.CreateParty:InvokeServer()
        task.wait(0.5)
        LobbyRemotes.SetPartySize:InvokeServer(1)
        task.wait(0.5)
        LobbyRemotes.JoinLobby:InvokeServer("")
    end)
end

return true
