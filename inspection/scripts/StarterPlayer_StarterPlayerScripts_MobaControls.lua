-- Roblox path: /StarterPlayer/StarterPlayerScripts/MobaControls
-- Class: LocalScript

-- MobaControls: точка-и-клик движение (как в МОБА) + камера сверху
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Настройки камеры
local CAMERA_HEIGHT = 45
local CAMERA_BACK = 22

-- Маркер цели движения
local marker
local function showMarker(pos)
	if not marker then
		marker = Instance.new("Part")
		marker.Name = "MoveMarker"
		marker.Shape = Enum.PartType.Cylinder
		marker.Size = Vector3.new(0.2, 4, 4)
		marker.Anchored = true
		marker.CanCollide = false
		marker.CanQuery = false
		marker.Material = Enum.Material.Neon
		marker.Color = Color3.fromRGB(120, 255, 120)
		marker.Parent = workspace
	end
	marker.CFrame = CFrame.new(pos + Vector3.new(0, 0.15, 0)) * CFrame.Angles(0, 0, math.rad(90))
	marker.Transparency = 0.4
	task.delay(0.4, function()
		if marker then marker.Transparency = 1 end
	end)
end

-- Луч из курсора в мир
local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
local function getGroundPos(x, y)
	local char = player.Character
	rayParams.FilterDescendantsInstances = char and { char } or {}
	local ray = camera:ViewportPointToRay(x, y)
	local result = workspace:Raycast(ray.Origin, ray.Direction * 500, rayParams)
	if result then
		return result.Position
	end
	return nil
end

-- Движение по клику/удержанию ЛКМ
local mouseDown = false
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		mouseDown = true
		local pos = getGroundPos(input.Position.X, input.Position.Y)
		if pos then
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum:MoveTo(pos)
				showMarker(pos)
			end
		end
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		mouseDown = false
	end
end)

-- Обновление цели при удержании кнопки
RunService.RenderStepped:Connect(function()
	if mouseDown then
		local pos = getGroundPos(UserInputService:GetMouseLocation().X, UserInputService:GetMouseLocation().Y)
		if pos then
			local char = player.Character
			local hum = char and char:FindFirstChildOfClass("Humanoid")
			if hum then
				hum:MoveTo(pos)
		end
		end
	end
end)

-- МОБА-камера: сверху-сзади за героем
RunService.RenderStepped:Connect(function()
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart")
	if root then
		camera.CameraType = Enum.CameraType.Scriptable
		local target = root.Position
		camera.CFrame = CFrame.lookAt(target + Vector3.new(0, CAMERA_HEIGHT, CAMERA_BACK), target)
	end
end)

print("[MobaControls] Клиент запущен: ЛКМ — движение")