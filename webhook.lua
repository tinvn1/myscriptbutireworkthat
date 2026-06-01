print("[TinHub Webhook] Đang khởi tạo hệ thống báo cáo...")

local HttpService = game:GetService("HttpService")
local LocalPlayer = game:GetService("Players").LocalPlayer

-- Tìm hàm gửi Request tương thích với MỌI loại Executor (PC + Mobile)
local requestFunc = json or request or (syn and syn.request) or (http and http.request) or http_request

_G.SendTinHubLog = function(statusType, details)
    -- Lấy link webhook truyền từ loadstring ra, nếu trống thì dừng luôn
    local TargetWebhook = _G.Webhook
    if not TargetWebhook or TargetWebhook == "" or TargetWebhook == "ĐIỀN_LINK_WEBHOOK_DISCORD_CỦA_BẠN_TẠI_ĐÂY" then
        warn("[TinHub Webhook] Không tìm thấy Link Webhook hợp lệ ở _G.Webhook!")
        return
    end

    local title = "🚀 TRẠNG THÁI FARM"
    local color = 65280 -- Màu xanh lá mặc định

    if statusType == "Success" then
        title = "⚡ KÍCH HOẠT POWER BOX THÀNH CÔNG"
        color = 16776960
    elseif statusType == "Evacuate" then
        title = "🚨 THOÁT PHÒNG KHẨN CẤP"
        color = 16711680
    end

    local data = {
        ["embeds"] = {{
            ["title"] = title,
            ["description"] = details or "Tài khoản đang bắt đầu tiến trình chạy xuyên tường.",
            ["color"] = color,
            ["footer"] = { ["text"] = "TinHub Project • " .. os.date("%X") },
            ["fields"] = {
                { ["name"] = "Tài khoản:", ["value"] = "||" .. LocalPlayer.Name .. "||", ["inline"] = true },
                { ["name"] = "JobId:", ["value"] = game.JobId ~= "" and "`" .. game.JobId .. "`" or "`Solo`", ["inline"] = true }
            }
        }}
    }

    -- Tiến hành gửi dữ liệu lên Discord
    task.spawn(function()
        if requestFunc then
            pcall(requestFunc, {
                Url = TargetWebhook,
                Method = "POST",
                Headers = {["Content-Type"] = "application/json"},
                Body = HttpService:JSONEncode(data)
            })
        else
            warn("[TinHub Webhook] Executor này không hỗ trợ bất kỳ hàm gửi Request nào!")
        end
    end)
end

-- Tự động gửi thông báo test trận đầu khi vừa nạp xong file
task.wait(1.0)
_G.SendTinHubLog("Start", "Đã kết nối dữ liệu đám mây thành công!")
