local Players = game:GetService("Players")
local localPlayer = Players.LocalPlayer
local WEAPON_NAME = "Bat" -- Kiểm tra kỹ tên vũ khí xem có đúng là "Bat" không nhé
local HP_THRESHOLD_PERCENT = 60 -- Chỉ cầm khi dưới 40% HP

print("[⚔️ SYSTEM] Đang khởi chạy Auto Equip - CHỈ kích hoạt khi dưới 40% HP...");

-- Hàm kiểm tra và trang bị vũ khí
local function attemptEquip()
    pcall(function()
        local char = localPlayer.Character
        if not char then return end
        
        local humanoid = char:FindFirstChildOfClass("Humanoid")
        if not humanoid or humanoid.Health <= 0 then return end
        
        -- Tính toán phần trăm máu hiện tại
        local healthPercent = (humanoid.Health / humanoid.MaxHealth) * 100
        
        -- CHỈ thực hiện nếu máu dưới hoặc bằng 40%
        if healthPercent <= HP_THRESHOLD_PERCENT then
            -- Nếu đã cầm sẵn vũ khí trên tay rồi thì thôi
            if char:FindFirstChild(WEAPON_NAME) then return end
            
            local backpack = localPlayer:FindFirstChild("Backpack")
            if backpack then
                local weapon = backpack:FindFirstChild(WEAPON_NAME)
                if weapon and weapon:IsA("Tool") then
                    humanoid:EquipTool(weapon)
                    print("[⚔️ PROTECTION] Máu thấp (" .. math.floor(healthPercent) .. "%). Đã tự động cầm: " .. WEAPON_NAME)
                end
            end
        end
    end)
end

-- =========================================================================
-- CƠ CHẾ THEO DÕI VÀ KÍCH HOẠT
-- =========================================================================

-- Hàm lắng nghe sự thay đổi máu của nhân vật
local function monitorHealth(char)
    local humanoid = char:WaitForChild("Humanoid", 10)
    if humanoid then
        -- Mỗi khi máu tăng/giảm, kiểm tra xem có dưới 40% không để cầm vũ khí
        humanoid.HealthChanged:Connect(function()
            attemptEquip()
        end)
    end
end

-- 1. Theo dõi khi nhân vật hồi sinh hoặc đổi nhân vật mới
localPlayer.CharacterAdded:Connect(function(char)
    monitorHealth(char)
end)

-- Bật theo dõi ngay lập tức nếu nhân vật đã có sẵn trong game
if localPlayer.Character then
    monitorHealth(localPlayer.Character)
end

-- 2. Vòng lặp quét bảo hiểm (Đề phòng trường hợp lỗi kết nối hoặc lag)
-- Vòng lặp này cũng tuân thủ điều kiện: Chỉ dưới 40% HP mới cầm vũ khí
task.spawn(function()
    while true do
        attemptEquip()
        task.wait(3) -- Quét lại mỗi 3 giây
    end
end)

-- Kiểm tra thử ngay khi vừa chạy script
attemptEquip()

return true
