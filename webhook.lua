-- MAIN FARMING PIPELINE EXECUTION ENGINE (TINHUB VERSION)
-- Khởi chạy và quản lý toàn bộ hệ thống script thông qua nguồn TinHub

print("[TinHub System] Đang khởi tạo luồng kết nối...")

-- 1. Chờ game tải hoàn chỉnh để tránh lỗi mất gói tin
if not game:IsLoaded() then
    game.Loaded:Wait()
end

local ContentProvider = game:GetService("ContentProvider")
while ContentProvider.RequestQueueSize > 0 do
    task.wait(0.5)
end

print("[TinHub System] Kết nối thành công. Bắt đầu đồng bộ dữ liệu đám mây...")
task.wait(1.5)

-- Cấu hình đường dẫn URL gốc của bạn trên TinHub / Github / Pastebin lưu trữ code công khai
-- (Bạn có thể thay đổi đường dẫn link bên dưới cho đúng tài khoản lưu trữ của bạn)
local BaseURL = "https://raw.githubusercontent.com/TinHubProject/Main/main/scripts/"

-- Hàm nạp dữ liệu trực tuyến an toàn chống lỗi treo/kẹt tiến trình
local function loadTinHubModule(scriptName)
    local scriptURL = BaseURL .. scriptName
    local success, result = pcall(function()
        -- Gọi API lấy mã nguồn trực tuyến từ bộ nhớ đám mây của Executor
        local getScriptCode = game:HttpGet(scriptURL)
        local scriptFunction, compileError = loadstring(getScriptCode)
        
        if scriptFunction then
            task.spawn(scriptFunction) -- Chạy luồng độc lập tránh xung đột
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

-- Đợi 3 giây trước khi bắt đầu tải các module con theo yêu cầu
task.wait(3)

-- 2. THỰC THI NẠP TỪNG CHỨC NĂNG THEO THỨ TỰ LOGIC
-- Tải các module bổ trợ góc nhìn và bảo mật trước
loadTinHubModule("camera.lua")
task.wait(0.5)

loadTinHubModule("checker.lua")
task.wait(0.5)

loadTinHubModule("webhook.lua")
task.wait(0.5)

-- Nạp lõi chính: Cơ chế xuyên tường và kích hoạt máy điện duy nhất
print("[TinHub System] Đang đồng bộ lõi di chuyển xuyên tường...")
local coreLoaded = loadTinHubModule("cochechinh.lua")

if coreLoaded then
    print("[TinHub System] KÍCH HOẠT THÀNH CÔNG! Toàn bộ quy trình farm bắt đầu vận hành.")
else
    warn("[TinHub System] Khởi động thất bại. Vui lòng kiểm tra lại đường dẫn link BaseURL hoặc file code 'cochechinh.lua' trên máy chủ.")
end
