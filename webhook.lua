
-- Reset trạng thái biến kích hoạt khi sang server mới
_G.StartGemCheck = false
_G.Webhook_Already_Sent = nil

print("Loading via TinHub Engine [Post-Interaction Check]")

if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- SERVICES --
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-- --- CONFIGURATION & REFERENCES ---
local requestFunc = json or request or (syn and syn.request) or (http and http.request) or http_request

-- Hàm chuyển đổi text Gem sang dạng số để so sánh
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
    local statusDetail = isSuccess and "**Thành công! Số lượng Gem đã tăng lên sau khi sửa máy.**" or "**[ERROR] Máy đã sửa nhưng Gem không tăng!**"

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

-- --- MAIN PIPELINE MONITOR ---
local function startWatchdog()
    if not requestFunc then
        warn("[TinHub Webhook] Executor không hỗ trợ gửi Request!")
        return
    end

    local gemCountInst = getGemCountInstance()
    while not gemCountInst do
        task.wait(0.5)
        gemCountInst = getGemCountInstance()
    end

    -- Ghi nhớ số lượng Gem GỐC ngay lúc này (trước khi sửa máy xong)
    local initialGemValue = parseGemCount(gemCountInst.Text)
    print("[Dữ liệu] Đã ghi nhớ số Gem nền ban đầu: " .. tostring(initialGemValue))

    -- [QUAN TRỌNG] Vòng lặp chờ tín hiệu "Đã sửa máy xong" từ script Farm truyền qua
    print("[Watchdog] Đang đứng im chế độ nền chờ bạn sửa máy...")
    while not _G.StartGemCheck do
        task.wait(0.05) -- Quét cực nhanh với delay thấp để không bỏ lỡ khoảnh khắc bấm nút
    end

    -- Cập nhật lại mốc chính xác ngay khi vừa tương tác xong
    initialGemValue = parseGemCount(gemCountInst.Text)
    print("[Watchdog] Đã nhận tín hiệu sửa máy! Bắt đầu kích hoạt 8 giây check tăng Gem...")

    local scanTime = 0
    local maxWaitTime = 8.0 -- Giảm xuống 8 giây vì máy đã sửa xong, Gem bắt buộc phải nhảy số ngay lập tức
    local hasTriggered = false

    -- Cơ chế kết hợp lắng nghe thuộc tính thay đổi để đẩy tốc độ lên tối đa
    local connection
    connection = gemCountInst:GetPropertyChangedSignal("Text"):Connect(function()
        local currentGemValue = parseGemCount(gemCountInst.Text)
        if currentGemValue > initialGemValue and not hasTriggered then
            hasTriggered = true
            if connection then connection:Disconnect() end
            sendStatusWebhook(true, gemCountInst.Text)
        end
    end)

    -- Vòng lặp quét bảo hiểm dự phòng
    while scanTime < maxWaitTime and not hasTriggered do
        task.wait(0.1)
        scanTime = scanTime + 0.1

        if gemCountInst and gemCountInst.Parent then
            local currentGemValue = parseGemCount(gemCountInst.Text)
            if currentGemValue > initialGemValue and not hasTriggered then
                hasTriggered = true
                if connection then connection:Disconnect() end
                sendStatusWebhook(true, gemCountInst.Text)
                break
            end
        else
            gemCountInst = getGemCountInstance()
        end
    end

    -- Trường hợp quá thời gian (8 giây) sau khi bấm nút sửa máy mà Gem vẫn không nhảy số
    if not hasTriggered then
        hasTriggered = true
        if connection then connection:Disconnect() end
        
        local finalGemText = gemCountInst and gemCountInst.Text or "0"
        print("[⚠️ FAILED] LỖI THỰC SỰ: Đã bấm sửa máy nhưng quá 8 giây Gem không tăng!")
        sendStatusWebhook(false, finalGemText)
    end
end

startWatchdog()
