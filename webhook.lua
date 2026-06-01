--[[
    ╔═════════════════════════════════════════════════════════════════╗
        TINHUB PROJECT - AUTOMATED GEM WATCHDOG SYSTEM (WEBHOOK ONLY)
        * Original Credits: Developed by TheAnonymous (RScript)
        * Modified & Updated: Managed under TinHub Cloud Ecosystem
    ╚═════════════════════════════════════════════════════════════════╝
--]]

print("Loading via TinHub Engine")

if not game:IsLoaded() then
    game.Loaded:Wait()
end

print("Complete! Starting the Pure Gem Data Watchdog.")

-- SERVICES --
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-- --- CONFIGURATION & REFERENCES ---
local initialGemValue = 0

-- Tìm hàm gửi Request tương thích với MỌI loại Executor (PC + Mobile)
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

    -- Thiết lập giao diện Embed dựa trên trạng thái dữ liệu Gem
    local title = isSuccess and "🟩 GEM UP SUCCESSFUL 🟩" or "🟥 GEM NOT UP ERROR 🟥"
    local color = isSuccess and 65280 or 16711680 -- 65280: Xanh Lá | 16711680: Đỏ rực
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

-- --- MAIN PIPELINE MONITOR ---
local function startWatchdog()
    if not requestFunc then
        warn("[TinHub Webhook] Executor này không hỗ trợ bất kỳ hàm gửi Request nào!")
        return
    end

    -- 1. Chờ và lấy dữ liệu số lượng Gem gốc ban đầu lúc vào phòng
    local gemCountInst = getGemCountInstance()
    local timeout = 0
    while not gemCountInst and timeout < 15 do
        task.wait(0.5)
        gemCountInst = getGemCountInstance()
        timeout = timeout + 0.5
    end

    if not gemCountInst then
        warn("[Dữ liệu] Không tìm thấy UI hiển thị số lượng Gem!")
        return
    end

    initialGemValue = parseGemCount(gemCountInst.Text)
    print("[Dữ liệu] Đã ghi nhớ số Gem ban đầu: " .. tostring(initialGemValue))

    -- 2. Chạy luồng giám sát dữ liệu liên tục
    task.spawn(function()
        local scanTime = 0
        local maxWaitTime = 12.0 -- Thời gian tối đa (giây) chờ Gem tăng, nếu quá thời gian này mà không tăng thì tính là Lỗi

        while scanTime < maxWaitTime do
            task.wait(0.2)
            scanTime = scanTime + 0.2

            if gemCountInst and gemCountInst.Parent then
                local currentGemValue = parseGemCount(gemCountInst.Text)

                -- TRƯỜNG HỢP 1: Phát hiện Gem TĂNG lên (Thành công)
                if currentGemValue > initialGemValue then
                    sendStatusWebhook(true, gemCountInst.Text)
                    return -- Dừng luồng sau khi đã check xong và gửi webhook Xanh
                end
            else
                gemCountInst = getGemCountInstance()
            end
        end

        -- TRƯỜNG HỢP 2: Đã hết thời gian chờ (12 giây) mà Gem vẫn không tăng (Thất bại)
        local finalGemText = gemCountInst and gemCountInst.Text or "0"
        print("[⚠️ FAILED] Quá thời gian chờ kiểm tra dữ liệu! Gem không tăng. Gửi Webhook Đỏ.")
        sendStatusWebhook(false, finalGemText)
    end)
end

startWatchdog()
