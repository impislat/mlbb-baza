-- Roblox path: /StarterPlayer/StarterPlayerScripts/CameraControl
-- Class: LocalScript

-- CameraControl: наклонная MOBA-камера за персонажем
-- Колесо мыши = наклон (вверх/вниз), Shift+колесо = дистанция, ПКМ+мышь = поворот
-- Использует ContextActionService — работает даже когда системные скрипты обрабатывают ввод

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

-- Настройки наклона (в градусах)
local PITCH_MIN = -75
local PITCH_MAX = -15
local PITCH_DEFAULT = -35
local PITCH_STEP = 6

local DISTANCE_MIN = 12
local DISTANCE_MAX = 60
local DISTANCE_DEFAULT = 28

local pitch = PITCH_DEFAULT
local yaw = 0
local distance = DISTANCE_DEFAULT
local targetPosition = nil

local function getCharacterRoot()
	local character = player.Character
	if not character then return nil end
	return character:FindFirstChild("HumanoidRootPart") or character:FindFirstChild("Torso")
end

local function updateTarget()
	local root = getCharacterRoot()
	if root then
		if targetPosition then
			targetPosition = targetPosition:Lerp(root.Position, 0.25)
		else
			targetPosition = root.Position
		end
	end
end

local function computeCameraCFrame()
	if not targetPosition then return nil end
	local pitchRad = math.rad(pitch)
	local yawRad = math.rad(yaw)
	local offset = CFrame.new(targetPosition)
		* CFrame.fromEulerAnglesYXZ(pitchRad, yawRad, 0)
		* CFrame.new(0, 0, distance)
	return CFrame.lookAt(offset.Position, targetPosition)
end

-- Колесо мыши: наклон / дистанция (с Shift)
-- ВАЖНО: не проверяем gameProcessed — системные скрипты ClickToMove помечают колесо
-- как обработанное, из-за этого наклон не работал
UserInputService.InputChanged:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseWheel then
		if UserInputService:IsKeyDown(Enum.KeyCode.LeftShift) or UserInputService:IsKeyDown(Enum.KeyCode.RightShift) then
			distance = math.clamp(distance - input.Position.Z * 4, DISTANCE_MIN, DISTANCE_MAX)
		else
			pitch = math.clamp(pitch - input.Position.Z * PITCH_STEP, PITCH_MIN, PITCH_MAX)
		end
		print("[CameraControl] pitch = " .. pitch .. ", distance = " .. distance)
	end
end)

-- ПКМ + движение мыши = поворот камеры
local rightMouseDown = false
UserInputService.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		rightMouseDown = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton2 then
		rightMouseDown = false
	end
end)

UserInputService.InputChanged:Connect(function(input)
	if rightMouseDown and input.UserInputType == Enum.UserInputType.MouseMovement then
		local delta = input.Delta
		yaw = (yaw - delta.X * 0.15) % 360
		pitch = math.clamp(pitch - delta.Y * 0.08, PITCH_MIN, PITCH_MAX)
	end
end)

-- Основной цикл камеры
RunService.RenderStepped:Connect(function()
	updateTarget()
	local cf = computeCameraCFrame()
	if cf then
		camera.CameraType = Enum.CameraType.Scriptable
		camera.CFrame = cf
	end
end)

print("[CameraControl] Наклонная камера: колесо = наклон, Shift+колесо = дистанция, ПКМ = поворот")