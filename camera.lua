local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- CẤU HÌNH CAMERA ĐỐI DIỆN POWER BOX
local CAMERA_DISTANCE = 8  -- Khoảng cách từ camera đến Power Box
local CAMERA_HEIGHT = 4     -- Chiều cao của camera so với vị trí Power Box
local TRIGGER_DISTANCE = 7  -- Khoảng cách (studs) tối đa để camera bắt đầu tác động

-- Đặt chế độ camera thành Scriptable để tự điều khiển bằng code
camera.CameraType = Enum.CameraType.Scriptable

-- Hàm tìm cục Power Box ở gần nhân vật nhất và trả về cả Part lẫn khoảng cách
local function getClosestPowerBox(character)
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return nil, math.huge end

	local closestBox = nil
	local shortestDistance = math.huge

	-- Quét toàn bộ object trong Workspace để tìm các đối tượng tên "Power Box"
	for _, obj in pairs(workspace:GetDescendants()) do
		if obj.Name == "Power Box" then
			local boxPart = nil
			if obj:IsA("BasePart") then
				boxPart = obj
			elseif obj:IsA("Model") then
				boxPart = obj.PrimaryPart or obj:FindFirstChildWhichIsA("BasePart", true)
			end

			if boxPart then
				local distance = (rootPart.Position - boxPart.Position).Magnitude
				if distance < shortestDistance then
					shortestDistance = distance
					closestBox = boxPart
				end
			end
		end
	end
	return closestBox, shortestDistance
end

RunService.RenderStepped:Connect(function()
	local character = player.Character
	if not character then return end
	
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	
	if rootPart and humanoid and humanoid.Health > 0 then
		camera.CameraType = Enum.CameraType.Scriptable
		
		-- Lấy cục Power Box gần nhất và khoảng cách hiện tại của nhân vật tới nó
		local closestBox, currentDistance = getClosestPowerBox(character)
		
		-- CHỈ TÁC ĐỘNG KHI CÓ BOX VÀ KHOẢNG CÁCH NHỎ HƠN HOẶC BẰNG 7 STUDS
		if closestBox and currentDistance <= TRIGGER_DISTANCE then
			local boxPos = closestBox.Position
			local boxLookVector = closestBox.CFrame.LookVector
			
			-- Tính toán vị trí đối diện trước mặt Power Box
			local targetCameraPos = boxPos + (boxLookVector * CAMERA_DISTANCE) + Vector3.new(0, CAMERA_HEIGHT, 0)
			
			-- Khóa góc nhìn trực diện vào Power Box
			camera.CFrame = CFrame.lookAt(targetCameraPos, boxPos)
		else
			-- NẾU Ở XA (> 7 STUDS): Camera quay lại đi theo sau lưng nhân vật để dễ di chuyển
			local rootPos = rootPart.Position
			local rootLookVector = rootPart.CFrame.LookVector
			
			-- Góc nhìn sau lưng mặc định
			local fallbackPos = rootPos - (rootLookVector * 10) + Vector3.new(0, 3.5, 0)
			camera.CFrame = CFrame.lookAt(fallbackPos, rootPos + Vector3.new(0, 1.5, 0))
		end
	else
		-- Nếu nhân vật chết hoặc chưa load xong, trả camera về mặc định
		camera.CameraType = Enum.CameraType.Custom
	end
end)
