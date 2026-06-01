-- Chờ trò chơi tải xong hoàn toàn
if not game:IsLoaded() then
    game.Loaded:Wait()
end

print("[🎮 SYSTEM] Khởi chạy luồng giả lập click theo tọa độ màn hình (Chống bấm nhầm Leave)...");

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GuiService = game:GetService("GuiService") 
local VirtualInputManager = game:GetService("VirtualInputManager")
local TeleportService = game:GetService("TeleportService")
local HttpService = game:GetService("HttpService")

local localPlayer = Players.LocalPlayer
local playerGui = localPlayer:WaitForChild("PlayerGui")
local LobbyRemotes = ReplicatedStorage:WaitForChild("Remotes"):WaitForChild("Lobby")

-- Đảm bảo tắt mọi trạng thái UI Navigation cũ tránh xung đột tiêu điểm vàng
GuiService.SelectedObject = nil

-- Hàm giả lập click chuột trái vào tọa độ chính xác của nút trên màn hình (Bypass UI Navigation hoàn toàn)
local function clickGuiObject(guiObject)
    if not guiObject or not guiObject:IsA("GuiObject") then return false end
    
    -- Lấy vị trí trung tâm thực tế của nút trên màn hình (tính bằng pixel)
    local posX = guiObject.AbsolutePosition.X + (guiObject.AbsoluteSize.X / 2)
    local posY = guiObject.AbsolutePosition.Y + (guiObject.AbsoluteSize.Y / 2) + 36 -- +36 topbar offset của Roblox
    
    -- Giả lập di chuột tới và click trái
    VirtualInputManager:SendMouseButtonEvent(posX, posY, 0, true, game, 1) -- Nhấn chuột xuống
    task.wait(0.05)
    VirtualInputManager:SendMouseButtonEvent(posX, posY, 0, false, game, 1) -- Thả chuột ra
    return true
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

print("[📊 SYSTEM] Số lượng phòng đã có người ở sảnh này: " .. occupiedRoomsCount)

-- Nếu từ 3 phòng trở lên đã có người, tự động đổi Server
if occupiedRoomsCount >= 3 then
    warn("[🚨 WARNING] Sảnh đông. Tiến hành chuyển Server!")
    pcall(function()
        local url = "https://games.roblox.com/v1/games/" .. game.PlaceId .. "/servers/Public?sortOrder=Asc&limit=100"
        local response = game:HttpGet(url)
        local data = HttpService:JSONDecode(response)
        if data and data.data then
            for _, server in pairs(data.data) do
                if server.id ~= game.JobId and server.playing and server.playing < server.maxPlayers then
                    TeleportService:TeleportToPlaceInstance(game.PlaceId, server.id, localPlayer)
                    return false
                end
            end
        end
        TeleportService:Teleport(game.PlaceId, localPlayer)
    end)
    return false
end

-- =========================================================================
-- BƯỚC 2: TỰ CHẠY ĐẾN Ô VÀ CLICK TỌA ĐỘ AN TOÀN
-- =========================================================================
if targetHitbox then
    local char = localPlayer.Character or localPlayer.CharacterAdded:Wait()
    local humanoid = char:WaitForChild("Humanoid")
    local rootPart = char:WaitForChild("HumanoidRootPart")
    
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
    
    task.wait(1.5) -- Đợi UI mở hẳn ra

    local mainGui = playerGui:FindFirstChild("Main")
    local createPartyWindow = mainGui and mainGui:FindFirstChild("CreateParty")
    
    if createPartyWindow then
        -- Tìm kiếm nút dựa trên tên/loại cấu trúc UI của bạn
        local buttonOne = createPartyWindow:FindFirstChild("1") or createPartyWindow:FindFirstChildWhichIsA("GuiButton", true)
        local createButton = createPartyWindow:FindFirstChild("Create") or createPartyWindow:FindFirstChild("Confirm", true)
        
        -- 1. Click chính xác vào nút số 1
        if buttonOne and buttonOne.AbsoluteSize.X > 0 then
            print("[🎯] Click tọa độ màn hình vào ô chọn số 1 người...");
            clickGuiObject(buttonOne)
            task.wait(0.5) -- Chờ UI cập nhật lựa chọn
        else
            warn("[❌] Không tìm thấy hoặc nút số 1 chưa hiển thị trên màn hình!")
        end
        
        -- 2. Click chính xác vào nút Create
        if createButton and createButton.AbsoluteSize.X > 0 then
            print("[🎯] Click tọa độ màn hình vào nút Create...");
            clickGuiObject(createButton)
            print("[🔥] Đã kích hoạt nút Create thành công! Luồng bấm dừng lại tại đây.");
        else
            warn("[❌] Không tìm thấy hoặc nút Create chưa hiển thị trên màn hình!")
        end
    else
        warn("[❌] Không tìm thấy bảng giao diện CreateParty!")
    end
else
    warn("[⚠️] Sảnh đầy, đang tiến hành nhảy Server...")
end

return true
