--[[
    ╔═════════════════════════════════════════════════════════════════╗
        TINHUB PROJECT - MULTI-MODULE HUB SYSTEM
        
        * Original Core Mechanic: TheAnonymous (RScript)
        * Optimized & Hosted by  : TinHub Project
        * Structure References   : camera, checker, cochechinh, webhook
    ╚═════════════════════════════════════════════════════════════════╝
--]]

print("[TinHub System] Đang khởi tạo luồng kết nối...")

-- 1. Chờ game tải hoàn chỉnh để tránh lỗi mất gói tin khi nạp đám mây
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local ContentProvider = game:GetService("ContentProvider")
while ContentProvider.RequestQueueSize > 0 do
    task.wait(0.5)
end

print("[TinHub System] Kết nối thành công. Bắt đầu đồng bộ dữ liệu đám mây...")
task.wait(1.5)

-- Cấu hình đường dẫn URL gốc dẫn thẳng tới kho lưu trữ của bạn (tinvn1) trên GitHub
local BaseURL = "https://raw.githubusercontent.com/tinvn1/Main/main/"

-- Hàm nạp dữ liệu trực tuyến an toàn chống lỗi treo/kẹt tiến trình
local function loadTinHubModule(scriptName)
    local scriptURL = BaseURL .. scriptName
    local success, result = pcall(function()
        -- Gọi API lấy mã nguồn trực tuyến từ bộ nhớ đám mây của Executor
        local getScriptCode = game:HttpGet(scriptURL)
        local scriptFunction, compileError = loadstring(getScriptCode)
        
        if scriptFunction then
            task.spawn(scriptFunction) -- Chạy luồng độc lập tránh xung đột mạch chính
            print("[TinHub Load] Đã đồng bộ thành công: " .. scriptName)
            return true
        else
            warn("[TinHub Compile Error] Phát hiện lỗi cú pháp trong file nguồn trực tuyến " .. scriptName .. ": " .. tostring(compileError))
        end
        return false
    end)
    
    if not success then
        warn("[TinHub Critical Error] Không thể kết nối hoặc tải dữ liệu từ: " .. scriptURL .. " | Lỗi: " .. tostring(result))
    end
    return success
end

-- Đợi 3 giây trước khi bắt đầu tải các module con để hệ thống game ổn định hoàn toàn
task.wait(3.0)

-- 2. THỰC THI NẠP TÙNG CHỨC NĂNG ĐỒNG BỘ THEO THỨ TỰ LOGIC
-- Tải các module bổ trợ góc nhìn, bảo mật và webhook báo cáo trước
loadTinHubModule("camera.lua")
task.wait(0.5)

loadTinHubModule("checker.lua")
task.wait(0.5)

loadTinHubModule("webhook.lua")
task.wait(0.5)

-- Nạp lõi chính cuối cùng: Cơ chế xuyên tường và kích hoạt máy điện duy nhất
print("[TinHub System] Đang đồng bộ lõi di chuyển xuyên tường...")
local coreLoaded = loadTinHubModule("cochechinh.lua")

if coreLoaded then
    print("[TinHub System] KÍCH HOẠT THÀNH CÔNG! Toàn bộ quy trình farm bắt đầu vận hành đồng bộ.")
else
    warn("[TinHub System] Khởi động thất bại. Vui lòng kiểm tra lại đường dẫn link BaseURL hoặc file code 'cochechinh.lua' trên máy chủ.")
end
