-- Roblox path: /ServerScriptService/AbilitySystem
-- Class: Script

-- AbilitySystem: способности героя Q/W/E/R с кулдаунами
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MobaShared = require(script.Parent:WaitForChild("MobaShared"))
local castAbility = ReplicatedStorage:FindFirstChild("CastAbility")

-- Кулдауны способностей (сек)
local COOLDOWNS = { Q = 6, W = 25, E = 15, R = 60 }
local nextReady = {} -- [player] = { [slot] = timestamp }

local function visualEffect(pos, color, radius, duration)
	local sphere = Instance.new("Part")
	sphere.Shape = Enum.PartType.Ball
	sphere.Size = Vector3.new(radius * 2, radius * 2, radius * 2)
	sphere.Position = pos
	sphere.Anchored = true
	sphere.CanCollide = false
	sphere.CanQuery = false
	sphere.Material = Enum.Material.Neon
	sphere.Color = color
	sphere.Transparency = 0.6
	sphere.Parent = workspace
	game:GetService("Debris"):AddItem(sphere, duration or 0.4)
end

local function castQ(player, char)
	-- Огненный шар: урон ближайшему врагу в радиусе 18
	local team = player:GetAttribute("Team") or (player.Team and player.Team.Name)
	local pos = MobaShared.positionOf(char)
	local target = MobaShared.findNearestEnemy(pos, team, 18, true)
	if not target then return false, "Нет цели в радиусе" end
	local dmg = (player:GetAttribute("Damage") or 50) * 1.5
	MobaShared.applyDamage(target, dmg, player) -- передаём атакующего для last hit
	local tPos = MobaShared.positionOf(target)
	visualEffect(tPos, Color3.fromRGB(255, 140, 50), 3, 0.3)
	return true
end

local function castW(player, char)
	-- Лечение: +30% здоровья
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return false end
	hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * 0.3)
	visualEffect(MobaShared.positionOf(char), Color3.fromRGB(100, 255, 120), 4, 0.4)
	return true
end

local function castE(player, char)
	-- Рывок: ускорение на 3 секунды
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return false end
	hum.WalkSpeed = hum.WalkSpeed * 1.8
	task.delay(3, function()
		if hum.Parent then hum.WalkSpeed = hum.WalkSpeed / 1.8 end
	end)
	visualEffect(MobaShared.positionOf(char), Color3.fromRGB(120, 200, 255), 3, 0.3)
	return true
end

local function castR(player, char)
	-- Ультимейт: массовый урон вокруг героя (радиус 15)
	local team = player:GetAttribute("Team") or (player.Team and player.Team.Name)
	local pos = MobaShared.positionOf(char)
	local dmg = (player:GetAttribute("Damage") or 50) * 2.5
	local hitAny = false
	local hitTargets = {}
	for _, minion in ipairs(game:GetService("CollectionService"):GetTagged(MobaShared.MINION_TAG)) do
		if minion.Parent and (minion:GetAttribute("Health") or 0) > 0 and minion:GetAttribute("Team") ~= team then
			if (MobaShared.positionOf(minion) - pos).Magnitude < 15 then
				table.insert(hitTargets, minion)
			end
		end
	end
	for _, monster in ipairs(game:GetService("CollectionService"):GetTagged(MobaShared.JUNGLE_TAG)) do
		if monster.Parent and (monster:GetAttribute("Health") or 0) > 0 then
			if (MobaShared.positionOf(monster) - pos).Magnitude < 15 then
				table.insert(hitTargets, monster)
			end
		end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		local c = p.Character
		local h = c and c:FindFirstChildOfClass("Humanoid")
		if c and h and h.Health > 0 and p ~= player then
			local pTeam = p:GetAttribute("Team") or (p.Team and p.Team.Name)
			if pTeam ~= team and (MobaShared.positionOf(c) - pos).Magnitude < 15 then
				table.insert(hitTargets, c)
			end
		end
	end
	for _, t in ipairs(hitTargets) do
		MobaShared.applyDamage(t, dmg, player) -- передаём атакующего для last hit
		hitAny = true
	end
	visualEffect(pos, Color3.fromRGB(200, 100, 255), 15, 0.5)
	return hitAny or true -- ульт всегда кастуется (визуал), даже без целей
end

castAbility.OnServerEvent:Connect(function(player, slot)
	-- Валидация
	if typeof(slot) ~= "string" or not COOLDOWNS[slot] then return end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not char or not hum or hum.Health <= 0 then return end

	local now = os.clock()
	nextReady[player] = nextReady[player] or {}
	if nextReady[player][slot] and now < nextReady[player][slot] then
		return -- ещё на кулдауне
	end

	local ok
	if slot == "Q" then ok = castQ(player, char)
	elseif slot == "W" then ok = castW(player, char)
	elseif slot == "E" then ok = castE(player, char)
	elseif slot == "R" then ok = castR(player, char)
	end

	if ok then
		nextReady[player][slot] = now + COOLDOWNS[slot]
	end
end)

Players.PlayerRemoving:Connect(function(player)
	nextReady[player] = nil
end)

print("[AbilitySystem] Запущен: Q/W/E/R")