--[[
    ╔═════════════════════════════════════════════════════════════════╗
        TINHUB PROJECT - AUTOMATED GEM LOGGING SYSTEM (ANTI-SPAM)
        * Original Credits: Developed by TheAnonymous (RScript)
        * Modified & Updated: Managed under TinHub Cloud Ecosystem
    ╚═════════════════════════════════════════════════════════════════╝
--]]

-- Sử dụng biến toàn cục để kiểm tra xem script này đã từng chạy trong server này chưa
if _G.Webhook_Already_Sent then 
    print("[WEBHOOK] He thong da gui thong bao truoc do. Bo qua de tranh spam!")
    return 
end

-- Tìm hàm gửi Request tương thích với MỌI loại Executor (PC + Mobile)
local requestFunc = json or request or (syn and syn.request) or (http and http.request) or http_request

if requestFunc then
    task.spawn(function()
        local players = game:GetService("Players")
        local localPlayer = players.LocalPlayer
        
        while not localPlayer do
            task.wait(0.5)
            localPlayer = players.LocalPlayer
        end
        
        -- Chờ PlayerGui xuất hiện ổn định
        local playerGui = localPlayer:WaitForChild("PlayerGui", 20)
        if not playerGui then return end

        -- Tìm và đợi giao diện MainUI hiển thị số lượng Gem
        local mainUI = playerGui:WaitForChild("MainUI", 20)
        local gemCount = nil
        
        if mainUI then
            gemCount = mainUI:FindFirstChild("GemDisplay") and mainUI.GemDisplay:FindFirstChild("Count")
            local timeout = 0
            while not gemCount and timeout < 10 do
                pcall(function()
                    gemCount = playerGui.MainUI.GemDisplay.Count
                end)
                if gemCount then break end
                task.wait(0.5)
                timeout = timeout + 0.5
            end
        end

        -- Lấy văn bản Gem hiển thị thực tế trên màn hình
        local currentGem = "0"
        if gemCount then
            currentGem = gemCount.Text
        end

        -- Khởi tạo cấu trúc Embed gửi Discord chỉn chu
        local payload = {
            ["embeds"] = {{
                ["title"] = "💎 THÔNG BÁO SỐ LƯỢNG GEM 💎",
                ["color"] = 65430, -- Màu xanh Neon
                ["fields"] = {
                    {
                        ["name"] = "👤 Tên nhân vật:",
                        ["value"] = "||`" .. localPlayer.Name .. "`||",
                        ["inline"] = true
                    },
                    {
                        ["name"] = "💎 Số lượng Gem hiện tại:",
                        ["value"] = "**" .. tostring(currentGem) .. "**",
                        ["inline"] = true
                    },
                    {
                        ["name"] = "🎮 Game ID:",
                        ["value"] = "||`" .. tostring(game.PlaceId) .. "`||",
                        ["inline"] = true
                    }
                },
                ["footer"] = {
                    ["text"] = "TinHub Project Engine • Hệ thống tự động"
                },
                ["timestamp"] = DateTime.now():ToIsoDate()
            }}
        }

        -- Lấy link webhook truyền từ bên ngoài vào
        local TargetWebhook = _G.Webhook
        if not TargetWebhook or TargetWebhook == "" or TargetWebhook == "ĐIỀN_LINK_WEBHOOK_DISCORD_TẠI_ĐÂY" then
            warn("[TinHub Webhook] Không tìm thấy Link Webhook hợp lệ ở _G.Webhook!")
            return
        end

        -- Đánh dấu trạng thái ĐÃ GỬI ngay lập tức trước khi request thực hiện xong (Khóa luồng)
        _G.Webhook_Already_Sent = true

        pcall(function()
            requestFunc({
                Url = TargetWebhook,
                Method = "POST",
                Headers = {["content-type"] = "application/json"},
                Body = game:GetService("HttpService"):JSONEncode(payload)
            })
            print("[🚀 SYSTEM] Webhook bao cao Gem da gui thanh cong!")
        end)
    end)
else
    warn("[TinHub Webhook] Executor này không hỗ trợ bất kỳ hàm gửi Request nào!")
end
