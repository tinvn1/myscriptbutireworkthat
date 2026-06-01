-- Chờ trò chơi tải xong hoàn toàn
if not game:IsLoaded() then
    game.Loaded:Wait()
end

print("[🚀 AUTO LOBBY LOADER] Đang khởi chạy luồng tự động load vào màn chơi an toàn...");

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")

-- Kiểm tra thư mục Remotes an toàn để tránh lỗi nil
local remotesFolder = ReplicatedStorage:WaitForChild("Remotes", 5)
local LobbyRemotes = remotesFolder and remotesFolder:WaitForChild("Lobby", 5)

if not LobbyRemotes then
    warn("[❌] Không tìm thấy thư mục Remotes của phòng chờ!")
    return false
end

-- Hàm click UI mô phỏng người dùng thật (Giảm thiểu việc bị quét từ getconnections)
local function safeClick(button)
    if not button then return false end
    
    -- Ưu tiên click trực tiếp thông thường trước để an toàn
    local success = pcall(function() 
        button.MouseButton1Click:Fire() 
    end)
    
    -- Nếu thất bại mới dùng tới phương thức nâng cao (nhưng giới hạn lại để tránh bị quét)
    if not success and getconnections then
        pcall(function()
            for _, connection in pairs(getconnections(button.MouseButton1Click)) do 
                connection:Fire() 
            end
        end)
    end
    return true
end

-- =========================================================================
-- 🏃 BƯỚC 1: TÌM Ô HOÀN TOÀN TRỐNG (0 NGƯỜI) ĐỂ CHIẾM PHÒNG SOLO
-- =========================================================================
local lobbiesFolder = Workspace:FindFirstChild("Lobbies")
local targetHitbox = nil
local selectedRoom = nil

if lobbiesFolder then
    for i = 1, 10 do
        local lobby = lobbiesFolder:FindFirstChild(tostring(i))
        if lobby then
            local labelObj = lobby:FindFirstChildWhichIsA("TextLabel", true) or lobby:FindFirstChild("Status", true)
            
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
-- ⚡ BƯỚC 2: TIẾN HÀNH CHIẾM GIỮ PHÒNG VÀ KHÓA PHÒNG MÔ PHỎNG NGƯỜI THẬT
-- =========================================================================
if targetHitbox then
    print("[💎] Tìm thấy phòng trống số " .. selectedRoom .. "! Đang tiến hành vào phòng...")
    
    local char = localPlayer.Character
    local rootPart = char and char:FindFirstChild("HumanoidRootPart")
    
    if rootPart then
        -- Thay vì dịch chuyển tức thời ngay tâm, dịch chuyển cách một chút rồi chờ để Server đồng bộ vị trí hợp lệ
        rootPart.CFrame = targetHitbox.CFrame + Vector3.new(0, 2, 0)
        task.wait(0.8) -- Tăng thời gian chờ lên 0.8s để bypass Anti-Cheat kiểm tra vị trí (Ping)
    end
    
    -- Gửi Remote tạo Party ngắt quãng
    print("[⚙️] Đang gửi yêu cầu tạo Party...")
    local successCreate = pcall(function()
        LobbyRemotes.CreateParty:InvokeServer()
    end)
    
    task.wait(1.5) -- Tăng thời gian chờ lên 1.5s để UI và Server tải hoàn tất dữ liệu phòng mới
    
    -- Thay đổi kích thước phòng đơn an toàn
    print("[⚙️] Đang đặt giới hạn phòng về 1 người...")
    pcall(function()
        LobbyRemotes.SetPartySize:InvokeServer(1)
    end)
    
    task.wait(1.0) -- Chờ 1 giây để tránh việc gửi lệnh nạp map quá dồn dập
    
    -- Định vị nút bấm "Create" trên giao diện UI để tải map
    local createButton = playerGui:FindFirstChild("Main") 
        and playerGui.Main:FindFirstChild("CreateParty") 
        and playerGui.Main.CreateParty:FindFirstChild("Create")
    
    if createButton and createButton.Visible then
        print("[🔥] Khóa phòng đơn thành công! Đang kích hoạt nạp map qua giao diện...")
        safeClick(createButton)
    else
        -- Cơ chế dự phòng an toàn, thêm khoảng trễ lớn để không bị kick vì spam remote
        print("[⚠️] Giao diện không phản hồi, gửi lệnh nạp map dự phòng bằng Remote...")
        task.wait(0.5)
        pcall(function()
            LobbyRemotes.JoinLobby:InvokeServer("")
        end)
    end
else
    -- =========================================================================
    -- 🚨 CƠ CHẾ DỰ PHÒNG: TỰ TẠO PHÒNG CÁCH LY KHI SẢNH CHỜ KÍN KHÔNG CÓ Ô TRỐNG
    -- =========================================================================
    warn("[⚠️] Toàn bộ sảnh chờ đều kín phòng! Kích hoạt giao thức tạo phòng đơn cách ly với độ trễ an toàn...")
    
    pcall(function()
        LobbyRemotes.CreateParty:InvokeServer()
        task.wait(1.2)
        LobbyRemotes.SetPartySize:InvokeServer(1)
        task.wait(1.2)
        LobbyRemotes.JoinLobby:InvokeServer("")
    end)
end

return true
