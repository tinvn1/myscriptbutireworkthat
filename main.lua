-- MAIN FARMING PIPELINE EXECUTION ENGINE (TINHUB VERSION)
print("[TinHub] Đang khởi động hệ thống rút gọn...")

if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(3.0) -- Đợi 3 giây ổn định game

-- Kiểm tra trạng thái Webhook đầu vào
if _G.Webhook then
    print("[TinHub] Đã ghim cấu hình Webhook thành công.")
end

-- 1. Đường dẫn kho lưu trữ của bạn
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

-- 2. Chạy đồng bộ tất cả các script con theo thứ tự
loadModule("camera.lua")
task.wait(0.5)
loadModule("checker.lua")
task.wait(0.5)
loadModule("webhook.lua") -- Load hệ thống báo cáo Gem
task.wait(0.5)

print("[TinHub] Đang nạp lõi chính...")
loadModule("cochechinh.lua")
