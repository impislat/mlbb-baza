-- Roblox path: /ServerScriptService/JungleSystem
-- Class: Script

-- JungleSystem: лесные кемпы, баффы (синий/красный), боссы (Черепаха, Лорд)
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MobaConfig = require(ReplicatedStorage:WaitForChild("MobaConfig"))
local MobaShared = require(script.Parent:WaitForChild("MobaShared"))

local jungleFolder = workspace:FindFirstChild("Jungle")
if not jungleFolder then
	jungleFolder = Instance.new("Folder")
	jungleFolder.Name = "Jungle"
	jungleFolder.Parent = workspace
end

-- Создание монстра
local function createMonster(name, health, damage, color, size)
	local model = Instance.new("Model")
	model.Name = name

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = Vector3.new(2, 2, 2)
	root.Transparency = 1
	root.CanCollide = false
	root.Parent = model

	local body = Instance.new("Part")
	body.Name = "Body"
	body.Shape = Enum.PartType.Ball
	body.Size = Vector3.new(size, size, size)
	body.Color = color
	body.Material = Enum.Material.SmoothPlastic
	body.Parent = model

	local eye1 = Instance.new("Part")
	eye1.Size = Vector3.new(0.4, 0.4, 0.4)
	eye1.Color = Color3.new(1, 1, 0)
	eye1.Material = Enum.Material.Neon
	eye1.Parent = model
	local eye2 = eye1:Clone()
	eye2.Parent = model

	local w1 = Instance.new("WeldConstraint") w1.Part0 = root w1.Part1 = body w1.Parent = body
	eye1.CFrame = CFrame.new(-0.4, size * 0.2, -size * 0.45)
	eye2.CFrame = CFrame.new(0.4, size * 0.2, -size * 0.45)
	local w2 = Instance.new("WeldConstraint") w2.Part0 = root w2.Part1 = eye1 w2.Parent = eye1
	local w3 = Instance.new("WeldConstraint") w3.Part0 = root w3.Part1 = eye2 w3.Parent = eye2

	local hum = Instance.new("Humanoid")
	hum.MaxHealth = 100000
	hum.Health = 100000
	hum.WalkSpeed = 14
	hum.Parent = model

	model.PrimaryPart = root
	model:SetAttribute("Health", health)
	model:SetAttribute("MaxHealth", health)
	model:SetAttribute("Damage", damage)
	model:SetAttribute("AttackRange", 12)
	return model
end

local function spawnCampMonster(campPos, campType, buffType, index, slot)	slot = slot or 1
	local health, damage, color, size
	if campType == "Big" then
		health, damage, size = 900, 60, 4
		color = buffType == "Blue" and Color3.fromRGB(60, 140, 255) or Color3.fromRGB(255, 80, 60)
	else
		health, damage, size = 350, 30, 2.5
		color = Color3.fromRGB(120, 90, 60)
	end
	local monster = createMonster("JungleMonster" .. index, health, damage, color, size)
	monster:SetAttribute("CampType", campType)
	monster:SetAttribute("BuffType", buffType)
	monster:SetAttribute("HomePos", campPos)
	monster:PivotTo(CFrame.new(campPos + Vector3.new((slot - 1) * 3 - 1, 3, 0)))
	monster.Parent = jungleFolder
	CollectionService:AddTag(monster, MobaShared.JUNGLE_TAG)
	MobaShared.attachHealthBar(monster, size)
	return monster
end

-- Выдача баффа игроку
local BUFF_DURATION = 70
local function grantBuff(player, buffType)
	if not player then return end
	player:SetAttribute("Buff", buffType)
	player:SetAttribute("BuffUntil", os.clock() + BUFF_DURATION)
	-- Мгновенный визуальный отклик: цвет игрока на 1с — потом HeroSystem обработает остальное
end

-- Логика монстра: аггро на игроков, возврат домой, атака, смерть
local function runMonster(monster, campPos, campType, buffType, campIndex, slot)
	local lastAttack = 0
	while monster.Parent do
		if (monster:GetAttribute("Health") or 0) <= 0 then break end
		local pos = MobaShared.positionOf(monster)
		local hum = monster:FindFirstChildOfClass("Humanoid")
		if not hum then break end

		-- Ищем ближайшего игрока-врага (для леса все игроки — враги)
		local target, dist
		for _, player in ipairs(Players:GetPlayers()) do
			local char = player.Character
			local h = char and char:FindFirstChildOfClass("Humanoid")
			if char and h and h.Health > 0 then
				local d = (MobaShared.positionOf(char) - pos).Magnitude
				if not target or d < dist then
					target, dist = char, d
				end
			end
		end

		local homeDist = (pos - campPos).Magnitude
		if target and dist < 45 and homeDist < 100 then
			-- Аггро
			if dist <= (monster:GetAttribute("AttackRange") or 4) then
				local now = os.clock()
				if now - lastAttack >= 1 then
					lastAttack = now
					MobaShared.applyDamage(target, monster:GetAttribute("Damage") or 30)
				end
				hum:MoveTo(pos)
			else
				hum:MoveTo(MobaShared.positionOf(target))
			end
		elseif homeDist > 15 then
			-- Возврат домой и регенерация
			hum:MoveTo(campPos)
			local hp = monster:GetAttribute("Health") or 0
			local maxHp = monster:GetAttribute("MaxHealth") or 1
			monster:SetAttribute("Health", math.min(maxHp, hp + maxHp * 0.05))
		end

		task.wait(0.4)
	end

	-- Смерть: бафф убившему игроку, респавн кемпа (боссов обрабатывает watchBoss)
	if monster.Parent and not monster:GetAttribute("IsBoss") then
		local killer = monster:GetAttribute("LastHitBy")
		if killer then
			local player = Players:FindFirstChild(killer)
			if player then
				if buffType then
					grantBuff(player, buffType)
				end
				player:SetAttribute("Gold", (player:GetAttribute("Gold") or 0) + (campType == "Big" and 60 or 20))
			end
		end
		monster.Parent = nil
		task.delay(MobaConfig.CAMP_RESPAWN, function()
			local m = spawnCampMonster(campPos, campType, buffType, campIndex, slot)
			task.spawn(runMonster, m, campPos, campType, buffType, campIndex, slot)
		end)
	end
end

-- Отслеживание, кто нанёс последний удар по монстру (через изменённые атрибуты Health)
-- К сожалению applyDamage не передаёт атакующего — используем ближайшего игрока при смерти
local function trackLastHit(monster)
	monster:GetAttributeChangedSignal("Health"):Connect(function()
		if (monster:GetAttribute("Health") or 0) <= 0 then
			local pos = MobaShared.positionOf(monster)
			local closest, cd = nil, 60
			for _, player in ipairs(Players:GetPlayers()) do
				local char = player.Character
				if char then
					local d = (MobaShared.positionOf(char) - pos).Magnitude
					if d < cd then
						closest, cd = player, d
					end
				end
			end
			if closest then
					monster:SetAttribute("LastHitBy", closest.Name)
			end
		end
	end)
end

-- Инициализация кемпов
for i, camp in ipairs(MobaConfig.CAMPS) do
	local pos = camp[1]
	local campType = camp[2]
	local buffType = camp[3]
	local count = (campType == "Big") and 1 or 2
	for j = 1, count do
		local monster = spawnCampMonster(pos, campType, buffType, i .. "_" .. j, j)
		trackLastHit(monster)
		task.spawn(runMonster, monster, pos, campType, buffType, i .. "_" .. j, j)
	end
end

-- === БОССЫ ===
local function spawnBoss(bossType, pos)
	local health, damage, color, size
	if bossType == "Turtle" then
		health, damage, size = 3000, 90, 7
		color = Color3.fromRGB(70, 160, 120)
	else -- Lord
		health, damage, size = 8000, 150, 9
		color = Color3.fromRGB(140, 60, 200)
	end
	local boss = createMonster(bossType, health, damage, color, size)
	boss.Name = bossType
	boss:SetAttribute("IsBoss", true)
	boss:SetAttribute("HomePos", pos)
	boss:PivotTo(CFrame.new(pos + Vector3.new(0, 5, 0)))
	boss.Parent = jungleFolder
	CollectionService:AddTag(boss, MobaShared.JUNGLE_TAG)
	MobaShared.attachHealthBar(boss, size + 3)
	task.spawn(runMonster, boss, pos, "Boss", nil, bossType)
	return boss
end

-- Награда за босса всей команде
local function onBossDied(boss)
	local bossType = boss.Name
	local pos = MobaShared.positionOf(boss)
	-- Определяем команду-убийцу по ближайшему игроку
	local killerTeam
	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if char then
			local d = (MobaShared.positionOf(char) - pos).Magnitude
			if d < 80 and player.Team then
				killerTeam = player.Team.Name
				break
			end
		end
	end
	if killerTeam then
		for _, player in ipairs(Players:GetPlayers()) do
			if player.Team and player.Team.Name == killerTeam then
				player:SetAttribute("Gold", (player:GetAttribute("Gold") or 0) + (bossType == "Lord" and 300 or 120))
				-- Командный бафф: урон +20% на 60с
				player:SetAttribute("TeamBuff", bossType)
				player:SetAttribute("TeamBuffUntil", os.clock() + 60)
			end
		end
	end
	-- Респавн босса
	local respawn = (bossType == "Turtle") and MobaConfig.TURTLE_RESPAWN or MobaConfig.LORD_RESPAWN
	task.delay(respawn, function()
		local b = spawnBoss(bossType, pos)
		trackLastHit(b)
	end)
end

-- Обработка смерти боссов (переопределяем обычную логику смерти)
local function watchBoss(boss)
	boss:GetAttributeChangedSignal("Health"):Connect(function()
		if (boss:GetAttribute("Health") or 0) <= 0 and boss.Parent then
			local pos = MobaShared.positionOf(boss)
			-- ближайший игрок = убийца
			local closest, cd = nil, 80
			for _, player in ipairs(Players:GetPlayers()) do
				local char = player.Character
			if char then
				local d = (MobaShared.positionOf(char) - pos).Magnitude
				if d < cd then closest, cd = player, d end
			end
		end
			if closest then boss:SetAttribute("LastHitBy", closest.Name) end
			for _, part in ipairs(boss:GetDescendants()) do
				if part:IsA("BasePart") then part.Transparency = 1 end
			end
			task.delay(2, function()
				boss.Parent = nil
				onBossDied(boss)
			end)
		end
		end)
end

-- Лорд появляется только через 5 минут после начала матча
task.delay(300, function()
	for bossType, pos in pairs(MobaConfig.BOSSES) do
		if bossType == "Turtle" then
			local b = spawnBoss(bossType, pos)
			watchBoss(b)
			trackLastHit(b)
		end
	end
end)
task.delay(MobaConfig.LORD_RESPAWN - 180, function()
	local pos = MobaConfig.BOSSES.Lord
	local b = spawnBoss("Lord", pos)
	watchBoss(b)
	trackLastHit(b)
end)

-- Регенерация синего баффа (мана-реген заменяем на реген здоровья, т.к. маны пока нет)
task.spawn(function()
	while true do
		task.wait(1)
		local now = os.clock()
		for _, player in ipairs(Players:GetPlayers()) do
			local buffUntil = player:GetAttribute("BuffUntil")
			if buffUntil and buffUntil > now and player:GetAttribute("Buff") == "Blue" then
				local char = player.Character
				local hum = char and char:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					hum.Health = math.min(hum.MaxHealth, hum.Health + 3)
				end
			end
			-- Снятие истёкших баффов
			if buffUntil and buffUntil <= now and player:GetAttribute("Buff") then
				player:SetAttribute("Buff", nil)
			end
		end
	end
end)

print("[JungleSystem] Запущен: " .. #MobaConfig.CAMPS .. " кемпов, 2 босса")