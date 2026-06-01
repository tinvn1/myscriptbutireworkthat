print("[TinHub] Đang khởi động hệ thống rút gọn...")

if not game:IsLoaded() then game.Loaded:Wait() end
task.wait(3.0) -- Đợi 3 giây ổn định game

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

-- 2. Chạy đồng bộ tất cả các script con
loadModule("camera.lua")
task.wait(0.5)
loadModule("checker.lua")
task.wait(0.5)
loadModule("webhook.lua")
task.wait(0.5)

print("[TinHub] Đang nạp lõi chính...")
loadModule("cochechinh.lua")
