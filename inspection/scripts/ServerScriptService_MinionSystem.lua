-- Roblox path: /ServerScriptService/MinionSystem
-- Class: Script

-- MinionSystem
-- Серверная система волн, движения, боя и наград миньонов.

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")
local ServerStorage = game:GetService("ServerStorage")

local MobaConfig = require(ReplicatedStorage:WaitForChild("MobaConfig"))
local MobaShared = require(script.Parent:WaitForChild("MobaShared"))

local CONFIG = {
	FIRST_WAVE_DELAY = 11,
	WAVE_INTERVAL = 30,
	MINIONS_PER_WAVE = 3,
	SPAWN_INTERVAL = 0.5,

	HEALTH = 450,
	WALK_SPEED = 12,

	DAMAGE = {
		Minion = 20,
		Hero = 10,
		Tower = 5,
	},

	ATTACK_RANGE = 4,
	ATTACK_COOLDOWN = 1.2,

	AGGRO_RADIUS = 20,
	CHASE_LEASH = 25,
	SCAN_INTERVAL = 0.5,

	WP_REACH = 5,
	STUCK_TIME = 2,
	SPACING_DIST = 3,
	SPACING_WAIT = 0.5,

	LAST_HIT_GOLD = 65,
	LAST_HIT_XP = 30,
	DENY_GOLD = 40,
	DENY_XP = 20,
	DENY_RADIUS = 15,
}

local HERO_BASE_HEALTH = 600
local HERO_HEALTH_PER_LEVEL = 100
local HERO_BASE_DAMAGE = 50
local HERO_DAMAGE_PER_LEVEL = 8

local LANES = { "Top", "Mid", "Bot" }
local TEAMS = { "Blue", "Red" }

local MINION_TAG = MobaShared.MINION_TAG
local STRUCTURE_TAG = MobaShared.STRUCTURE_TAG

-- =========================================================
-- ПАПКА МИНЬОНОВ
-- =========================================================

local minionsFolder = workspace:FindFirstChild("Minions")

if not minionsFolder then
	minionsFolder = Instance.new("Folder")
	minionsFolder.Name = "Minions"
	minionsFolder.Parent = workspace
end

-- =========================================================
-- МАРШРУТЫ
-- =========================================================

local function waypointsFor(team, lane)
	local points = MobaConfig.LANES[lane]
	if not points then
		warn("[MinionSystem] Не найдена линия:", lane)
		return {}
	end

	local result = {}

	if team == "Blue" then
		for _, point in ipairs(points) do
			table.insert(result, point)
		end
	else
		for i = #points, 1, -1 do
			table.insert(result, points[i])
		end
	end

	return result
end

local function spawnPointFor(team, lane)
	local points = waypointsFor(team, lane)
	if #points == 0 then
		return nil
	end

	return points[1]
end

-- =========================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- =========================================================

local function flatDist(a, b)
	local dx = a.X - b.X
	local dz = a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

local function playerTeam(player)
	return player:GetAttribute("Team")
		or (player.Team and player.Team.Name)
end

local function getHealth(target)
	if not target or not target.Parent then
		return 0
	end

	local hp = target:GetAttribute("Health")
	if hp ~= nil then
		return hp
	end

	local humanoid = target:FindFirstChildOfClass("Humanoid")
	if humanoid then
		return humanoid.Health
	end

	return 0
end

local function targetAlive(target)
	return target ~= nil
		and target.Parent ~= nil
		and getHealth(target) > 0
end

local function damageVs(target)
	if CollectionService:HasTag(target, MINION_TAG) then
		return CONFIG.DAMAGE.Minion
	elseif CollectionService:HasTag(target, STRUCTURE_TAG) then
		return CONFIG.DAMAGE.Tower
	end

	return CONFIG.DAMAGE.Hero
end

local function getTemplate()
	local folder = ReplicatedStorage:FindFirstChild("MinionModels")

	if folder then
		local model = folder:FindFirstChild("Swordsman")
			or folder:FindFirstChild("Melee")
			or folder:FindFirstChildOfClass("Model")

		if model and model:IsA("Model") then
			return model
		end
	end

	local fallback = ReplicatedStorage:FindFirstChild("BlueMinionTemplate")

	if fallback and fallback:IsA("Model") then
		return fallback
	end

	return nil
end

local template = getTemplate()

if not template then
	warn("[MinionSystem] Не найден шаблон MinionModels.Swordsman")
end

-- =========================================================
-- СОЗДАНИЕ МИНЬОНА
-- =========================================================

local function createMinion(team, lane, index, wave)
	if not template then
		return nil
	end

	local model = template:Clone()
	model.Name = team .. "_Swordsman_" .. lane .. "_" .. wave .. "_" .. index

	local humanoid = model:FindFirstChildOfClass("Humanoid")
	local root = model:FindFirstChild("HumanoidRootPart")

	if not humanoid or not root then
		warn("[MinionSystem] В Swordsman отсутствует Humanoid или HumanoidRootPart")
		model:Destroy()
		return nil
	end

	model.PrimaryPart = root

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = false

			if team == "Red" then
				part.Color = Color3.fromRGB(230, 70, 70)
			end
		end
	end

	humanoid.MaxHealth = CONFIG.HEALTH
	humanoid.Health = CONFIG.HEALTH
	humanoid.WalkSpeed = CONFIG.WALK_SPEED

	model:SetAttribute("Team", team)
	model:SetAttribute("Lane", lane)
	model:SetAttribute("Type", "Melee")
	model:SetAttribute("Health", CONFIG.HEALTH)
	model:SetAttribute("MaxHealth", CONFIG.HEALTH)
	model:SetAttribute("GoldReward", CONFIG.LAST_HIT_GOLD)
	model:SetAttribute("DeathHandled", false)

	-- Сервер управляет физикой миньона.
	pcall(function()
		root:SetNetworkOwner(nil)
	end)

	model:GetAttributeChangedSignal("Health"):Connect(function()
		if not humanoid.Parent then
			return
		end

		local hp = model:GetAttribute("Health") or 0
		humanoid.Health = math.clamp(hp, 0, CONFIG.HEALTH)
	end)

	return model
end

-- =========================================================
-- АНИМАЦИЯ СМЕРТИ
-- =========================================================

local function playDeathAnimation(minion)
	local humanoid = minion:FindFirstChildOfClass("Humanoid")
	local animator = humanoid and humanoid:FindFirstChildOfClass("Animator")

	if not animator then
		return
	end

	for _, child in ipairs(minion:GetDescendants()) do
		if child:IsA("Animation")
			and string.lower(child.Name):find("death") then

			local success, track = pcall(function()
				return animator:LoadAnimation(child)
			end)

			if success and track then
				track.Priority = Enum.AnimationPriority.Action
				track:Play()
			end

			return
		end
	end
end

-- =========================================================
-- ОПЫТ И УРОВНИ
-- В следующем этапе перенесём эту функцию в HeroSystem.
-- =========================================================

local function giveXP(player, amount)
	local xp = (player:GetAttribute("XP") or 0) + amount
	local level = player:GetAttribute("Level") or 1

	while xp >= level * 100 do
		xp -= level * 100
		level += 1

		player:SetAttribute("Level", level)

		local maxHp = HERO_BASE_HEALTH
			+ (level - 1) * HERO_HEALTH_PER_LEVEL

		local damage = HERO_BASE_DAMAGE
			+ (level - 1) * HERO_DAMAGE_PER_LEVEL

		player:SetAttribute("MaxHealth", maxHp)
		player:SetAttribute("Damage", damage)

		local character = player.Character
		local humanoid = character
			and character:FindFirstChildOfClass("Humanoid")

		if humanoid then
			local oldMax = humanoid.MaxHealth
			local healthRatio = oldMax > 0 and humanoid.Health / oldMax or 1

			humanoid.MaxHealth = maxHp
			humanoid.Health = math.clamp(healthRatio * maxHp, 1, maxHp)
		end
	end

	player:SetAttribute("XP", xp)
end

-- =========================================================
-- НАГРАДЫ
-- =========================================================

local function giveGold(player, amount)
	player:SetAttribute(
		"Gold",
		(player:GetAttribute("Gold") or 0) + amount
	)
end

local function giveGoldAndExp(minion)
	local killerKind = minion:GetAttribute("LastAttackerKind")
	local killerName = minion:GetAttribute("LastAttackerPlayer")
	local minionTeam = minion:GetAttribute("Team")
	local position = MobaShared.positionOf(minion)

	if killerKind == "Player" and killerName then
		local killer = Players:FindFirstChild(killerName)

		if killer and playerTeam(killer) ~= minionTeam then
			giveGold(killer, CONFIG.LAST_HIT_GOLD)
			giveXP(killer, CONFIG.LAST_HIT_XP)
		end

	elseif killerKind == "Minion" then
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character

			if character and playerTeam(player) ~= minionTeam then
				local distance = flatDist(
					MobaShared.positionOf(character),
					position
				)

				if distance <= CONFIG.DENY_RADIUS then
					giveGold(player, CONFIG.DENY_GOLD)
					giveXP(player, CONFIG.DENY_XP)
				end
			end
		end
	end

	-- Убийство башней не выдаёт награду.
end

-- =========================================================
-- СМЕРТЬ МИНЬОНА
-- =========================================================

local function onMinionDeath(minion)
	if not minion.Parent then
		return
	end

	if minion:GetAttribute("DeathHandled") then
		return
	end

	minion:SetAttribute("DeathHandled", true)

	-- Отключаем дальнейшее управление.
	minion:SetAttribute("Health", 0)

	local humanoid = minion:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.WalkSpeed = 0
	end

	giveGoldAndExp(minion)
	playDeathAnimation(minion)

	Debris:AddItem(minion, 2)
end

-- =========================================================
-- ПОИСК ЦЕЛЕЙ
-- Приоритет: миньоны > башни > агрессивные герои.
-- =========================================================

local function findTarget(position, team, lane)
	local bestTarget = nil
	local bestDistance = CONFIG.AGGRO_RADIUS

	-- 1. Вражеские миньоны.
	for _, minion in ipairs(CollectionService:GetTagged(MINION_TAG)) do
		if minion.Parent
			and minion:GetAttribute("Team") ~= team
			and targetAlive(minion) then

			local distance = flatDist(
				MobaShared.positionOf(minion),
				position
			)

			if distance < bestDistance then
				bestTarget = minion
				bestDistance = distance
			end
		end
	end

	if bestTarget then
		return bestTarget
	end

	-- 2. Вражеские строения.
	-- Разрешаем строения своей линии и общие строения базы.
	for _, structure in ipairs(CollectionService:GetTagged(STRUCTURE_TAG)) do
		local structureLane = structure:GetAttribute("Lane")

		local sameLane = structureLane == lane
			or structureLane == "Base"
			or structureLane == nil

		if structure.Parent
			and sameLane
			and structure:GetAttribute("Team") ~= team
			and not structure:GetAttribute("Invulnerable")
			and targetAlive(structure) then

			local distance = flatDist(
				MobaShared.positionOf(structure),
				position
			)

			if distance < bestDistance then
				bestTarget = structure
				bestDistance = distance
			end
		end
	end

	if bestTarget then
		return bestTarget
	end

	-- 3. Герои, которые недавно атаковали союзников.
	local now = os.clock()

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character
			and character:FindFirstChildOfClass("Humanoid")

		if character
			and humanoid
			and humanoid.Health > 0
			and playerTeam(player) ~= team then

			local aggroUntil = character:GetAttribute("AggroUntil")

			if aggroUntil and aggroUntil > now then
				local distance = flatDist(
					MobaShared.positionOf(character),
					position
				)

				if distance < bestDistance then
					bestTarget = character
					bestDistance = distance
				end
			end
		end
	end

	return bestTarget
end

-- =========================================================
-- ПОИСК БЛИЖАЙШЕГО ВЕЙПОИНТА
-- =========================================================

local function nearestWaypointIndex(position, waypoints)
	local bestIndex = 1
	local bestDistance = math.huge

	for index, waypoint in ipairs(waypoints) do
		local distance = flatDist(position, waypoint)

		if distance < bestDistance then
			bestDistance = distance
			bestIndex = index
		end
	end

	return bestIndex
end

-- =========================================================
-- ПРОВЕРКА ИНТЕРВАЛА МЕЖДУ СОЮЗНЫМИ МИНЬОНАМИ
-- =========================================================

local function isBlockedByAlly(minion, position, direction, team)
	for _, other in ipairs(CollectionService:GetTagged(MINION_TAG)) do
		if other ~= minion
			and other.Parent
			and other:GetAttribute("Team") == team
			and targetAlive(other) then

			local otherPosition = MobaShared.positionOf(other)
			local distance = flatDist(otherPosition, position)

			if distance < CONFIG.SPACING_DIST then
				local toOther = otherPosition - position
				toOther = Vector3.new(toOther.X, 0, toOther.Z)

				if toOther.Magnitude > 0.1
					and direction:Dot(toOther.Unit) > 0.5 then
					return true
				end
			end
		end
	end

	return false
end

-- =========================================================
-- ЛОГИКА ОДНОГО МИНЬОНА
-- =========================================================

local function runMinion(minion, team, lane)
	local waypoints = waypointsFor(team, lane)

	if #waypoints == 0 then
		return
	end

	local humanoid = minion:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return
	end

	local waypointIndex = 1
	local target = nil
	local hadTarget = false

	local lastAttack = 0
	local lastScan = 0
	local lastPosition = MobaShared.positionOf(minion)
	local lastMoveTime = os.clock()

	while minion.Parent do
		if not targetAlive(minion) then
			break
		end

		if not humanoid.Parent or humanoid.Health <= 0 then
			break
		end

		local position = MobaShared.positionOf(minion)
		local now = os.clock()

		-- Периодическое сканирование.
		if now - lastScan >= CONFIG.SCAN_INTERVAL then
			lastScan = now

			if target and (
				not targetAlive(target)
					or flatDist(MobaShared.positionOf(target), position)
					> CONFIG.CHASE_LEASH
				) then
				target = nil
			end

			if not target then
				target = findTarget(position, team, lane)
			end
		end

		-- Потеряли цель: возвращаемся к ближайшей точке маршрута.
		if target then
			hadTarget = true
		elseif hadTarget then
			hadTarget = false
			waypointIndex = nearestWaypointIndex(position, waypoints)
		end

		local inAttackRange = false
		local movementGoal = nil

		if target and targetAlive(target) then
			local targetPosition = MobaShared.positionOf(target)
			local distance = flatDist(targetPosition, position)

			if distance <= CONFIG.ATTACK_RANGE then
				inAttackRange = true
				humanoid:MoveTo(position)

				if now - lastAttack >= CONFIG.ATTACK_COOLDOWN then
					lastAttack = now

					if targetAlive(target) then
						MobaShared.applyDamage(
							target,
							damageVs(target),
							minion
						)
					end
				end
			else
				movementGoal = targetPosition
			end
		else
			target = nil

			local waypoint = waypoints[waypointIndex]

			if waypoint then
				local direction = waypoint - position
				direction = Vector3.new(direction.X, 0, direction.Z)

				if direction.Magnitude > 0.1 then
					if isBlockedByAlly(
						minion,
						position,
						direction.Unit,
						team
						) then
						humanoid:MoveTo(position)
					else
						movementGoal = waypoint
					end
				end

				if flatDist(position, waypoint) <= CONFIG.WP_REACH then
					waypointIndex = math.min(
						waypointIndex + 1,
						#waypoints + 1
					)
				end
			end

			-- После конца маршрута ищем только доступные строения.
			if waypointIndex > #waypoints then
				local structureTarget = findTarget(position, team, lane)

				if structureTarget
					and CollectionService:HasTag(
						structureTarget,
						STRUCTURE_TAG
					) then

					target = structureTarget
				end
			end
		end

		if movementGoal and not inAttackRange then
			humanoid:MoveTo(movementGoal)
		end

		-- Обнаружение застревания.
		if not inAttackRange then
			local moved = flatDist(position, lastPosition)

			if moved < 0.5 then
				if now - lastMoveTime >= CONFIG.STUCK_TIME then
					local goal = movementGoal

					if not goal and target and targetAlive(target) then
						goal = MobaShared.positionOf(target)
					end

					if goal then
						local direction = goal - position
						direction = Vector3.new(
							direction.X,
							0,
							direction.Z
						)

						if direction.Magnitude > 0.1 then
							minion:PivotTo(
								minion:GetPivot()
									+ direction.Unit * 1
							)
						end
					end

					humanoid.Jump = true
					lastMoveTime = now
				end
			else
				lastMoveTime = now
			end
		else
			lastMoveTime = now
		end

		lastPosition = position
		task.wait(0.25)
	end
end

-- =========================================================
-- СПАВН ОДНОГО МИНЬОНА
-- =========================================================

local function spawnMinion(team, lane, index, wave)
	local minion = createMinion(team, lane, index, wave)

	if not minion then
		return
	end

	local spawnPosition = spawnPointFor(team, lane)

	if not spawnPosition then
		minion:Destroy()
		return
	end

	local offset = Vector3.new((index - 2) * CONFIG.SPACING_DIST, 3, 0)

	minion:PivotTo(CFrame.new(spawnPosition + offset))
	minion.Parent = minionsFolder

	CollectionService:AddTag(minion, MINION_TAG)

	MobaShared.attachHealthBar(
		minion,
		team == "Blue" and 8 or 5
	)

	minion:GetAttributeChangedSignal("Health"):Connect(function()
		if (minion:GetAttribute("Health") or 0) <= 0 then
			onMinionDeath(minion)
		end
	end)

	-- Дополнительная страховка на случай смерти через Humanoid.
	local humanoid = minion:FindFirstChildOfClass("Humanoid")

	if humanoid then
		humanoid.Died:Connect(function()
			onMinionDeath(minion)
		end)
	end

	task.spawn(runMinion, minion, team, lane)
end

-- =========================================================
-- ВОЛНЫ
-- =========================================================

local waveCounter = 0

local function spawnWave()
	waveCounter += 1
	local currentWave = waveCounter

	for _, team in ipairs(TEAMS) do
		for _, lane in ipairs(LANES) do
			for index = 1, CONFIG.MINIONS_PER_WAVE do
				local currentTeam = team
				local currentLane = lane
				local currentIndex = index

				task.delay(
					(currentIndex - 1) * CONFIG.SPAWN_INTERVAL,
					function()
						spawnMinion(
							currentTeam,
							currentLane,
							currentIndex,
							currentWave
						)
					end
				)
			end
		end
	end

	print("[MinionSystem] Волна #" .. currentWave .. " запущена")
end

-- =========================================================
-- СТАРТ ВОЛН ПО СИГНАЛАМ МАТЧА
-- =========================================================

local signals = ServerStorage:FindFirstChild("MatchSignals")
local matchStarted = signals and signals:FindFirstChild("MatchStarted")
local matchEnded = signals and signals:FindFirstChild("MatchEnded")

local wavesRunning = false

local function startWaveLoop()
	if wavesRunning then
		return
	end

	wavesRunning = true

	task.spawn(function()
		task.wait(CONFIG.FIRST_WAVE_DELAY)

		if not wavesRunning then
			return
		end

		spawnWave()

		while wavesRunning do
			task.wait(CONFIG.WAVE_INTERVAL)

			if wavesRunning then
				spawnWave()
			end
		end
	end)

	print(
		"[MinionSystem] Матч начался. Первая волна через "
			.. CONFIG.FIRST_WAVE_DELAY
			.. " сек."
	)
end

local function stopWaveLoop()
	wavesRunning = false
	print("[MinionSystem] Матч завершён — спавн волн остановлен")
end

if matchStarted then
	if signals:GetAttribute("MatchActive") then
		-- Матч уже идёт — запускаем волны сразу.
		startWaveLoop()
	else
		matchStarted.Event:Connect(startWaveLoop)
	end
else
	warn(
		"[MinionSystem] Не найден ServerStorage.MatchSignals.MatchStarted — волны не запустятся"
	)
end

if matchEnded then
	matchEnded.Event:Connect(stopWaveLoop)
end