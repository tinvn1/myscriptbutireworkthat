task.wait(1)
local VirtualInputManager = game:GetService("VirtualInputManager")
local UserInputService = game:GetService("UserInputService")
local Camera = workspace.CurrentCamera
local StarterGui = game:GetService("StarterGui")

local OFFSET_DOWN = 20     -- Độ thấp dưới tâm màn hình (pixel)
local HOLD_DURATION = 19   -- Thời gian giữ (giây)

-- Kiểm tra xem người chơi có phải đang dùng PC hay không
local isPC = UserInputService.KeyboardEnabled and UserInputService.MouseEnabled

-- Thông báo bắt đầu hành động
local noticeText = "Bắt đầu giữ dưới tâm 20px trong 19 giây..."
if isPC then
    noticeText = "Bắt đầu giữ tâm -20px & đè phím [E] trong 19 giây..."
end

StarterGui:SetCore("SendNotification", {
    Title = "Auto Hold System",
    Text = noticeText,
    Duration = 3
})

-- Tính toán tọa độ chính giữa màn hình và hạ xuống 20 pixel
local centerX = Camera.ViewportSize.X / 2
local targetY = (Camera.ViewportSize.Y / 2) + OFFSET_DOWN

task.spawn(function()
    -- [BƯỚC 1]: BẮT ĐẦU GIỮ (Chuột/Touch và phím E nếu là PC)
    -- Giữ vị trí màn hình (Hạ xuống 20 pixel)
    VirtualInputManager:SendMouseButtonEvent(centerX, targetY, 0, true, game, 0)
    
    -- Nếu là PC, kích hoạt đè giữ phím E (Enum.KeyCode.E)
    if isPC then
        VirtualInputManager:SendKeyEvent(true, Enum.KeyCode.E, false, game)
    end
    
    -- [BƯỚC 2]: DUY TRÌ TRẠNG THÁI TRONG 19 GIÂY
    task.wait(HOLD_DURATION)
    
    -- [BƯỚC 3]: THẢ RA HOÀN TOÀN
    -- Thả vị trí màn hình
    VirtualInputManager:SendMouseButtonEvent(centerX, targetY, 0, false, game, 0)
    
    -- Nếu là PC, nhả phím E ra
    if isPC then
        VirtualInputManager:SendKeyEvent(false, Enum.KeyCode.E, false, game)
    end
    
    -- Thông báo hoàn thành
    StarterGui:SetCore("SendNotification", {
        Title = "Auto Hold System",
        Text = isPC and "Đã thả vị trí và phím [E] thành công!" or "Đã giữ đủ 19 giây và tự động thả!",
        Duration = 3
    })
end)
