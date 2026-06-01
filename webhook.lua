--[[
    ╔═════════════════════════════════════════════════════════════════╗
        TINHUB PROJECT - AUTOMATED GEM WATCHDOG SYSTEM (GLOBAL ED.)
        * Pure Standalone Version - No Script Integration Required
        * Designed for Global Users & International Communities
    ╚═════════════════════════════════════════════════════════════════╝
--]]

-- Reset environmental markers for the new session
_G.Webhook_Already_Sent = nil

print("[TinHub Engine] Initializing Pure Gem Watchdog...")

if not game:IsLoaded() then
    game.Loaded:Wait()
end

-- SERVICES --
local Players = game:GetService("Players")
local HttpService = game:GetService("HttpService")
local LocalPlayer = Players.LocalPlayer

-- --- CONFIGURATION & GLOBAL UTILITIES ---
local requestFunc = json or request or (syn and syn.request) or (http and http.request) or http_request

-- Extracts numeric values cleanly from GUI text strings
local function parseGemCount(gemStr)
    local cleaned = string.gsub(gemStr, "[^%d]", "") 
    return tonumber(cleaned) or 0
end

-- Locates the core Gem Text Object within the game interface
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

-- --- GLOBAL DISCORD EMBED TRANSMITTER (ENGLISH ONLY) ---
local function sendStatusWebhook(isSuccess, currentGemText)
    if _G.Webhook_Already_Sent then 
        print("[WEBHOOK] Notification already dispatched for this session. Skipping to prevent spam.")
        return 
    end
    _G.Webhook_Already_Sent = true

    local TargetWebhook = _G.Webhook
    if not requestFunc or not TargetWebhook or TargetWebhook == "" or TargetWebhook == "ĐIỀN_LINK_WEBHOOK_DISCORD_TẠI_ĐÂY" then
        warn("[TinHub Webhook] Invalid Webhook URL configuration or Executor lack of HTTP Request support!")
        return
    end

    -- Configure interface structure based on verification status
    local title = isSuccess and "🟩 GEM UP SUCCESSFUL 🟩" or "🟥 GEM NOT UP ERROR 🟥"
    local color = isSuccess and 65280 or 16711680 -- 65280: Emerald Green | 16711680: Crimson Red
    local statusDetail = isSuccess and "**Success! The account balance has increased cleanly.**" or "**[ERROR] Server rotation initiated without data update!**"

    local payload = {
        ["embeds"] = {{
            ["title"] = title,
            ["color"] = color,
            ["fields"] = {
                {
                    ["name"] = "👤 Account Username:",
                    ["value"] = "||`" .. LocalPlayer.Name .. "`||",
                    ["inline"] = true
                },
                {
                    ["name"] = "💎 Current Gem Balance:",
                    ["value"] = "**" .. tostring(currentGemText) .. "**",
                    ["inline"] = true
                },
                {
                    ["name"] = "📊 Watchdog System Status:",
                    ["value"] = statusDetail,
                    ["inline"] = false
                },
                {
                    ["name"] = "🎮 Execution Place ID:",
                    ["value"] = "||`" .. tostring(game.PlaceId) .. "`||",
                    ["inline"] = true
                }
            },
            ["footer"] = {
                ["text"] = "TinHub Project Engine • Automated Integrity Verification"
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
        print("[🚀 SYSTEM] Webhook status payload successfully broadcasted!")
    end)
end

-- --- STANDALONE AUTOMATED MONITOR ---
local function startWatchdog()
    if not requestFunc then
        warn("[TinHub Webhook] Critical: Executor lacks HTTP request execution capability.")
        return
    end

    -- Phase 1: Wait for UI rendering completion
    local gemCountInst = getGemCountInstance()
    local bootTimeout = 0
    while not gemCountInst and bootTimeout < 15 do
        task.wait(0.5)
        gemCountInst = getGemCountInstance()
        bootTimeout = bootTimeout + 0.5
    end

    if not gemCountInst then
        warn("[System Error] Failed to hook into the UI Gem Tracking Node.")
        return
    end

    -- Ghi nhớ giá trị ban đầu khi vừa đặt chân vào server
    local initialGemValue = parseGemCount(gemCountInst.Text)
    print("[Watchdog Data] Base value registered: " .. tostring(initialGemValue))

    local statusTriggered = false

    -- CORE ENGINE 1: Real-time Property Signal Interceptor (Instantaneous Update Detection)
    local propertyConnection
    propertyConnection = gemCountInst:GetPropertyChangedSignal("Text"):Connect(function()
        local realTimeValue = parseGemCount(gemCountInst.Text)
        if realTimeValue > initialGemValue and not statusTriggered then
            statusTriggered = true
            if propertyConnection then propertyConnection:Disconnect() end
            sendStatusWebhook(true, gemCountInst.Text)
        end
    end)

    -- CORE ENGINE 2: Thread Destruction / Room Disconnection Listener (The Error Trigger)
    -- Khi nhân vật bị xóa để đổi server, nếu statusTriggered vẫn chưa là true -> Nghĩa là đổi phòng mà không lên Gem
    LocalPlayer.CharacterRemoving:Connect(function()
        task.wait(0.1) -- Small physics delay to let final engine packets complete
        if not statusTriggered then
            statusTriggered = true
            if propertyConnection then propertyConnection:Disconnect() end
            
            local finalVerificationText = gemCountInst and gemCountInst.Text or tostring(initialGemValue)
            local finalVerificationValue = parseGemCount(finalVerificationText)
            
            -- Phút chót cứu nguy: Check lại xem UI thực tế có tăng trước khi biến mất hoàn toàn không
            if finalVerificationValue > initialGemValue then
                sendStatusWebhook(true, finalVerificationText)
            else
                print("[⚠️ ALERT] Character removed from current chamber without any balance changes.")
                sendStatusWebhook(false, finalVerificationText)
            end
        end
    end)
    
    -- CORE ENGINE 3: Safety Net Match Hard-Timeout (60 Seconds)
    task.delay(60.0, function()
        if not statusTriggered then
            statusTriggered = true
            if propertyConnection then propertyConnection:Disconnect() end
            
            gemCountInst = getGemCountInstance()
            local finalText = gemCountInst and gemCountInst.Text or "0"
            print("[⚠️ ALERT] Match deadline exceeded with stagnant stats.")
            sendStatusWebhook(false, finalText)
        end
    end)
end

startWatchdog()
