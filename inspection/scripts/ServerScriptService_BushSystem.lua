-- Roblox path: /ServerScriptService/BushSystem
-- Class: Script

-- BushSystem: отслеживает, в каком кусту находится каждый игрок
-- Выставляет атрибут InBushId на персонаже (0 = не в кусту)

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local bushes = workspace:FindFirstChild("MOBA_Map")
if bushes then bushes = bushes:FindFirstChild("Bushes") end
if not bushes then
	warn("[BushSystem] Папка Bushes не найдена")
	return
end

-- Кэш кустов: { id, x, z, hx, hz } — прямоугольная зона в мировых осях
local bushList = {}
local function refreshBushes()
	table.clear(bushList)
	for _, model in ipairs(bushes:GetChildren()) do
		if model:IsA("Model") then
			local id = model:GetAttribute("BushId")
			if id then
				local pos = model:GetPivot().Position
				local hx = model:GetAttribute("HalfX") or model:GetAttribute("BushRadius") or 8.5
				local hz = model:GetAttribute("HalfZ") or model:GetAttribute("BushRadius") or 8.5
				table.insert(bushList, {id = id, x = pos.X, z = pos.Z, hx = hx, hz = hz})
			end
			end
	end
end
refreshBushes()

local function findBush(pos)
	for _, b in ipairs(bushList) do
		local dx, dz = pos.X - b.x, pos.Z - b.z
		if math.abs(dx) <= b.hx and math.abs(dz) <= b.hz then
			return b.id
		end
	end
	return 0
end

-- Проверка каждые 0.2 секунды
local UPDATE_RATE = 0.2
local acc = 0
RunService.Heartbeat:Connect(function(dt)
	acc += dt
	if acc < UPDATE_RATE then return end
	acc = 0
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		if character then
			local hrp = character:FindFirstChild("HumanoidRootPart")
			if hrp then
				local bushId = findBush(hrp.Position)
				if character:GetAttribute("InBushId") ~= bushId then
					character:SetAttribute("InBushId", bushId)
				end
			end
		end
	end
end)

print("[BushSystem] Запущен: " .. #bushList .. " кустов")