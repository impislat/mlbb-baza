-- Roblox path: /ServerScriptService/TowerVisualFX
-- Class: Script

-- TowerVisualFX: анимация кристаллов башен и нексусов
-- Кристаллы пульсируют, осколки вращаются вокруг них, руны на земле мерцают

local RunService = game:GetService("RunService")

local towersFolder = workspace:FindFirstChild("MOBA_Map")
if towersFolder then towersFolder = towersFolder:FindFirstChild("Towers") end
if not towersFolder then return end

-- Собираем данные о башнях при запуске (и добавляем новые, если появятся)
local towers = {}

local function registerTower(model)
	if not model:IsA("Model") then return end
	local crystal = model:FindFirstChild("Crystal")
	if not crystal then return end
	local shards = {}
	for _, child in ipairs(model:GetChildren()) do
		if string.match(child.Name, "^Shard") then table.insert(shards, child) end
	end
	local light = crystal:FindFirstChildOfClass("PointLight")
	table.insert(towers, {
		model = model,
		crystal = crystal,
		shards = shards,
		light = light,
		baseCF = crystal.CFrame,
		baseSize = crystal.Size,
	})
end

for _, model in ipairs(towersFolder:GetChildren()) do
	registerTower(model)
end
towersFolder.DescendantAdded:Connect(function()
	-- простая перерегистрация не требуется: строения статичны
end)

RunService.Heartbeat:Connect(function(dt)
	local t = os.clock()
	for i, entry in ipairs(towers) do
		if entry.crystal.Parent then
			-- Пульсация кристалла
			local pulse = 1 + math.sin(t * 2 + i) * 0.06
			entry.crystal.Size = entry.baseSize * pulse
			if entry.light then
				entry.light.Brightness = 2 + math.sin(t * 2 + i) * 0.8
			end
			-- Вращение осколков вокруг кристалла
			for s, shard in ipairs(entry.shards) do
				if shard.Parent then
					local angle = t * 1.2 + (s - 1) * (math.pi * 2 / #entry.shards)
					local radius = 4.5
					local base = entry.crystal.Position
					shard.Position = base + Vector3.new(math.cos(angle) * radius, math.sin(t * 1.5 + s) * 1.2, math.sin(angle) * radius)
				end
			end
		else
			table.remove(towers, i)
		end
	end
end)

print("[TowerVisualFX] Анимация кристаллов запущена: " .. #towers .. " строений")