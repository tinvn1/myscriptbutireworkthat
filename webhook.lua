
print("Loading via TinHub Engine [Fixed Version]")

if not game:IsLoaded() then
    game.Loaded:Wait()
end

print("Complete! Starting the Pure Gem Data Watchdog.")

-- SERVICES --
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-- --- CONFIGURATION & REFERENCES ---
local requestFunc = json or request or (syn and syn.request) or (http and http.request) or http_request

-- Hàm chuyển đổi text Gem sang dạng số
local function parseGemCount(gemStr)
    local cleaned = string.gsub(gemStr, "[^%d]", "") 
    return tonumber(cleaned) or 0
end

-- Lấy Object chứa Text Gem hiện tại trên MainUI
local function getGemCountInstance()
    local playerGui = LocalPlayer:FindFirstChild("PlayerGui")
    if playerGui then
        local mainUI = playerGui:FindFirstChild("MainUI")
        if mainUI then
            return mainUI:FindFirstChild("GemDisplay") and mainUI.GemDisplay:FindFirstChild("Count")
        end
    end
    return nil
end

-- --- HỆ THỐNG GỬI WEBHOOK PHÂN LOẠI TRẠNG THÁI ---
local function sendStatusWebhook(isSuccess, currentGemText)
    if _G.Webhook_Already_Sent then 
        print("[WEBHOOK] Hệ thống đã gửi thông báo trước đó. Bỏ qua để tránh spam!")
        return 
    end
    _G.Webhook_Already_Sent = true

    local TargetWebhook = _G.Webhook
    if not requestFunc or not TargetWebhook or TargetWebhook == "" or TargetWebhook == "ĐIỀN_LINK_WEBHOOK_DISCORD_TẠI_ĐÂY" then
        warn("[TinHub Webhook] Link Webhook không hợp lệ hoặc không hỗ trợ gửi Request!")
        return
    end

    local title = isSuccess and "🟩 GEM UP SUCCESSFUL 🟩" or "🟥 GEM NOT UP ERROR 🟥"
    local color = isSuccess and 65280 or 16711680
    local statusDetail = isSuccess and "**Thành công! Số lượng Gem đã tăng lên.**" or "**[ERROR] Gem by game gem not up!**"

    local payload = {
        ["embeds"] = {{
            ["title"] = title,
            ["color"] = color,
            ["fields"] = {
                {
                    ["name"] = "👤 Tên nhân vật:",
                    ["value"] = "||`" .. LocalPlayer.Name .. "`||",
                    ["inline"] = true
                },
                {
                    ["name"] = "💎 Số lượng Gem hiện tại:",
                    ["value"] = "**" .. tostring(currentGemText) .. "**",
                    ["inline"] = true
                },
                {
                    ["name"] = "📊 Trạng thái hệ thống:",
                    ["value"] = statusDetail,
                    ["inline"] = false
                },
                {
                    ["name"] = "🎮 Game ID:",
                    ["value"] = "||`" .. tostring(game.PlaceId) .. "`||",
                    ["inline"] = true
                }
            },
            ["footer"] = {
                ["text"] = "TinHub Project Engine • Kiểm tra trạng thái tự động"
            },
            ["timestamp"] = DateTime.now():ToIsoDate()
        }}
    }

    pcall(function()
        requestFunc({
            Url = TargetWebhook,
            Method = "POST",
            Headers = {["content-type"] = "application/json"},
            Body = HttpService:JSONEncode(payload)
        })
        print("[🚀 SYSTEM] Webhook báo cáo trạng thái kiểm tra Gem đã được phát đi!")
    end)
end

-- --- MAIN PIPELINE MONITOR (SỬA ĐỔI LOGIC KIỂM TRA) ---
local function startWatchdog()
    if not requestFunc then
        warn("[TinHub Webhook] Executor này không hỗ trợ hàm gửi Request!")
        return
    end

    -- Đợi UI Gem xuất hiện
    local gemCountInst = getGemCountInstance()
    local timeout = 0
    while not gemCountInst and timeout < 10 do
        task.wait(0.2)
        gemCountInst = getGemCountInstance()
        timeout = timeout + 0.2
    end

    if not gemCountInst then
        warn("[Dữ liệu] Không tìm thấy UI hiển thị số lượng Gem!")
        return
    end

    -- Sử dụng biến môi trường toàn cục _G để lưu trữ số lượng Gem thực tế xuyên suốt các phòng (Session)
    if not _G.TinHub_LastGemValue then
        _G.TinHub_LastGemValue = parseGemCount(gemCountInst.Text)
        print("[Dữ liệu] Khởi tạo phiên làm việc. Ghi nhớ gốc: " .. tostring(_G.TinHub_LastGemValue))
    end

    local initialGemValue = _G.TinHub_LastGemValue
    local hasTriggered = false

    -- CƠ CHẾ 1: Lắng nghe sự thay đổi trực tiếp của thuộc tính Text (Bắt trọn khoảnh khắc Gem nhảy số)
    local connection
    connection = gemCountInst:GetPropertyChangedSignal("Text"):Connect(function()
        local currentGemValue = parseGemCount(gemCountInst.Text)
        if currentGemValue > initialGemValue and not hasTriggered then
            hasTriggered = true
            _G.TinHub_LastGemValue = currentGemValue -- Cập nhật mốc mới cho phòng sau
            if connection then connection:Disconnect() end
            sendStatusWebhook(true, gemCountInst.Text)
        end
    end)

    -- CƠ CHẾ 2: Kiểm tra đột xuất ngay lập tức (Phòng trường hợp script load chậm khi Gem đã nhảy trước đó)
    local instantCheck = parseGemCount(gemCountInst.Text)
    if instantCheck > initialGemValue and not hasTriggered then
        hasTriggered = true
        _G.TinHub_LastGemValue = instantCheck
        if connection then connection:Disconnect() end
        sendStatusWebhook(true, gemCountInst.Text)
        return
    end

    -- CƠ CHẾ 3: Bộ đếm thời gian bảo hiểm (Watchdog Timeout)
    task.delay(14.0, function()
        if not hasTriggered then
            hasTriggered = true
            if connection then connection:Disconnect() end
            
            -- Đọc lại giá trị cuối cùng trước khi báo lỗi đỏ
            gemCountInst = getGemCountInstance()
            local finalGemText = gemCountInst and gemCountInst.Text or "0"
            local finalGemValue = parseGemCount(finalGemText)
            
            if finalGemValue > initialGemValue then
                -- Cứu nguy phút chót nếu giá trị thực tế lớn hơn mốc lưu trữ ban đầu
                _G.TinHub_LastGemValue = finalGemValue
                sendStatusWebhook(true, finalGemText)
            else
                print("[⚠️ FAILED] Quá thời gian chờ! Gem thực sự không tăng.")
                sendStatusWebhook(false, finalGemText)
            end
        end
    end)
end

startWatchdog()
