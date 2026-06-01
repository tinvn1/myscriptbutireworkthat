-- Chờ trò chơi tải xong hoàn toànt
if not game:IsLoaded() then
    game.Loaded:Wait()
end

print("[📱 MOBILE SYSTEM] Khởi chạy luồng giả lập click UI an toàn...");

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local LobbyRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Lobby")

-- Hàm kích nổ sự kiện click chuẩn cho mọi thiết bị Mobile (Bypass lỗi phím)
local function mobileClick(button)
    if not button then return end
    -- Duyệt qua tất cả các kết nối click có sẵn của nút bấm để kích hoạt trực tiếp
    local connections = getconnections or button.MouseButton1Click
    if type(connections) == "function" then
        button.MouseButton1Click:Fire()
    else
        for _, connection in pairs(getconnections(button.MouseButton1Click)) do
            connection:Fire()
        end
        for _, connection in pairs(getconnections(button.Activated)) do
            connection:Fire()
        end
    end
end

-- Hàm thực hiện chuyển Server ít người (Server Hop)
local function hopToLowPlayerServer()
    print("[🔄 SERVER HOP] Đang quét tìm Server vắng...")
    local success = pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local response = game:HttpGet(url)
        local data = HttpService:JSONDecode(response)
        
        if data and data.data then
            for _, server in pairs(data.data) do
                if server.id ~= game.JobId and server.playing and server.playing < server.maxPlayers then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, localPlayer)
                    return true
                end
            end
        end
    end)
    if not success then TeleportService:Teleport(game.PlaceId, localPlayer) end
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

-- Nếu từ 3 phòng trở lên đã có người, tự động đổi Server ngay
if occupiedRoomsCount >= 3 then
    warn("[🚨] Sảnh đông (" .. occupiedRoomsCount .. " phòng). Đang đổi Server...")
    hopToLowPlayerServer()
    return false
end

-- =========================================================================
-- BƯỚC 2: TIẾN VÀO Ô VÀ KÍCH HOẠT CLICK SỐ 1 + CREATE
-- =========================================================================
if targetHitbox then
    local char = localPlayer.Character or localPlayer.CharacterAdded:Wait()
    local humanoid = char:WaitForChild("Humanoid")
    local rootPart = char:WaitForChild("HumanoidRootPart")
    
    -- Chạy bộ vào ô trống
    humanoid:MoveTo(targetHitbox.Position)
    local startTime = tick()
    while (rootPart.Position - targetHitbox.Position).Magnitude > 4 do
        task.wait(0.1)
        if tick() - startTime > 8 then break end
    end
    
    task.wait(0.5) 
    
    pcall(function()
        LobbyRemotes.CreateParty:InvokeServer()
    end)
    
    -- Chờ bảng UI hiển thị hẳn lên màn hình Mobile
    task.wait(1.2) 

    local mainGui = playerGui:FindFirstChild("Main")
    local createPartyWindow = mainGui and mainGui:FindFirstChild("CreateParty")
    
    if createPartyWindow then
        -- Định vị chính xác phần tử UI nút số 1 và nút Create
        local buttonOne = createPartyWindow:FindFirstChild("1") or createPartyWindow:FindFirstChildWhichIsA("GuiButton", true)
        local createButton = createPartyWindow:FindFirstChild("Create") or createPartyWindow:FindFirstChild("Confirm", true)
        
        -- 1. Giả lập bấm nút chọn số 1 người
        if buttonOne then
            print("[🎯] Đang chọn ô số 1...");
            mobileClick(buttonOne)
            task.wait(0.4) -- Đợi giao diện Mobile chuyển trạng thái màu vàng
        end
        
        -- 2. Giả lập bấm nút Create và triệt tiêu UI ngay lập tức để né nút Leave
        if createButton then
            print("[🎯] Đang bấm nút Create...");
            mobileClick(createButton)
            
            -- 🔥 CHỐNG BẤM NHẦM NÚT LEAVE: Ẩn ngay lập tức bảng UI này đi 
            createPartyWindow.Visible = false
            
            -- Chặn đứng mọi lệnh bấm dư thừa tiếp theo
            print("[🔥 SUCCESS] Phòng đơn đã được tạo! Đang đợi chuyển cảnh...");
        end
    else
        warn("[❌] Không tìm thấy giao diện CreateParty trên thiết bị!")
    end
else
    warn("[⚠️] Không tìm thấy ô trống, đang tiến hành nhảy Server...")
    hopToLowPlayerServer()
end

return true
