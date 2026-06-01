-- MAIN FARMING PIPELINE EXECUTION ENGINE (TINHUB VERSION)
print("[TinHub] Đang khởi động hệ thống rút gọn...")

if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(3.0) -- Đợi 3 giây ổn định game

-- Kiểm tra trạng thái Webhook đầu vào
if _G.Webhook then
    print("[TinHub] Đã ghim cấu hình Webhook thành công.")
end

-- 1. Đường dẫn kho lưu trữ mới của bạn
local BaseURL = "https://raw.githubusercontent.com/tinvn1/myscriptbutireworkthat/refs/heads/main/"

local function loadModule(name)
    local success, code = pcall(game.HttpGet, game, BaseURL .. name)
    if success then
        local func, err = loadstring(code)
        if func then 
            task.spawn(func)
            print("[Loaded] -> " .. name)
        else 
            warn("[Error Cú Pháp] " .. name .. ": " .. tostring(err)) 
        end
    else
        warn("[Error Kết Nối] Không thể tải: " .. name)
    end
end

-- ===================================================================
-- 2. CHẠY ĐỒNG BỘ CÁC MODULE THEO THỨ TỰ LOGIC CHUẨN
-- ===================================================================

-- Nhóm 1: Tải các tính năng bổ trợ góc nhìn & kết nối map trước
loadModule("camera.lua")
task.wait(0.5)
loadModule("join_map.lua")
task.wait(0.5)

-- Nhóm 2: Tải các tính năng tự động trang bị và chiến đấu (Auto Equip / Kill Aura)
loadModule("AutoEquip.lua")
task.wait(0.5)
loadModule("autodrag&killaura.lua")
task.wait(0.5)

-- Nhóm 3: Tải hệ thống bảo mật và báo cáo trạng thái/Gem lên Discord
loadModule("checker.lua")
task.wait(0.5)
loadModule("webhook.lua")
task.wait(0.5)

-- Nhóm 4: Nạp lõi vận hành chính (Xuyên tường & Farm) sau khi các bổ trợ đã sẵn sàng
print("[TinHub] Đang nạp lõi chính...")
loadModule("cochechinh.lua")
