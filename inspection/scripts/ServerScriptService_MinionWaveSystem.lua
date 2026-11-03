-- Roblox path: /ServerScriptService/MinionWaveSystem
-- Class: Script

-- MinionWaveSystem: волны миньонов по линиям, движение по вейпоинтам, бой
local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MobaConfig = require(ReplicatedStorage:WaitForChild("MobaConfig"))
local MobaShared = require(script.Parent:WaitForChild("MobaShared"))

local minionsFolder = workspace:FindFirstChild("Minions")
if not minionsFolder then
	minionsFolder = Instance.new("Folder")
	minionsFolder.Name = "Minions"
	minionsFolder.Parent = workspace
end

-- Шаблон синего миньона (сгенерированная модель)
local blueTemplate = ReplicatedStorage:FindFirstChild("BlueMinionTemplate")

-- Создание модели миньона
local function createMinion(team, lane, waveIndex)
	local isBlue = team == "Blue"
	local model

	if isBlue and blueTemplate then
		-- Синие миньоны — клоны сгенерированной модели с фото
		model = blueTemplate:Clone()
		model.Name = team .. "_Minion_" .. lane .. "_" .. waveIndex
	else
		-- Красные миньоны — прежний простой вид
		local color = Color3.fromRGB(230, 70, 70)

		model = Instance.new("Model")
		model.Name = team .. "_Minion_" .. lane .. "_" .. waveIndex

		local root = Instance.new("Part")
		root.Name = "HumanoidRootPart"
		root.Size = Vector3.new(2, 2, 2)
		root.Transparency = 1
		root.CanCollide = false
		root.Parent = model

		local body = Instance.new("Part")
		body.Name = "Body"
		body.Size = Vector3.new(2, 3, 2)
		body.Color = color
		body.Material = Enum.Material.SmoothPlastic
		body.Parent = model

		local head = Instance.new("Part")
		head.Name = "Head"
		head.Shape = Enum.PartType.Ball
		head.Size = Vector3.new(1.6, 1.6, 1.6)
		head.Color = color
		head.Material = Enum.Material.SmoothPlastic
		head.Parent = model

		local weld = Instance.new("WeldConstraint")
		weld.Part0 = root
		weld.Part1 = body
		weld.Parent = body
		local weld2 = Instance.new("WeldConstraint")
		weld2.Part0 = root
		weld2.Part1 = head
		weld2.Parent = head

		local hum = Instance.new("Humanoid")
		hum.MaxHealth = 100000
		hum.Health = 100000
		hum.WalkSpeed = 12
		hum.Parent = model

		model.PrimaryPart = root
	end

	-- Атрибуты боевой системы
	model:SetAttribute("Team", team)
	model:SetAttribute("Lane", lane)
	model:SetAttribute("Health", 450)
	model:SetAttribute("MaxHealth", 450)
	model:SetAttribute("Damage", 35)
	model:SetAttribute("AttackRange", 15)
	model:SetAttribute("GoldReward", 25)

	return model
end

-- Вейпоинты для команды: Blue идёт от синих к красным, Red — наоборот
local function waypointsFor(team, lane)
	local pts = MobaConfig.LANES[lane]
	if team == "Blue" then
		return pts
	end
	local reversed = {}
	for i = #pts, 1, -1 do
		table.insert(reversed, pts[i])
	end
	return reversed
end

-- Спавн одной волны по всем линиям
local runMinion -- объявляем заранее, т.к. spawnWave ссылается на функцию
local waveCounter = 0
local function spawnWave()
	waveCounter += 1
	for _, team in ipairs({"Blue", "Red"}) do
		for _, lane in ipairs({"Top", "Mid", "Bot"}) do
			for i = 1, MobaConfig.MINIONS_PER_LANE do
				task.delay((i - 1) * 1.2, function()
					local minion = createMinion(team, lane, waveCounter)
					local start = waypointsFor(team, lane)[1]
					minion:PivotTo(CFrame.new(start + Vector3.new((i - 2) * 4, 4, 0)))
					minion.Parent = minionsFolder
					CollectionService:AddTag(minion, MobaShared.MINION_TAG)
					MobaShared.attachHealthBar(minion, team == "Blue" and 8 or 5)
					task.spawn(runMinion, minion, team, lane)
				end)
			end
		end
	end
end

-- Логика одного миньона: движение + бой + смерть
function runMinion(minion, team, lane)
	local waypoints = waypointsFor(team, lane)
	local wpIndex = 1
	local attackCooldown = 0
	local lastAttack = 0

	while minion.Parent do
		local health = minion:GetAttribute("Health") or 0
		if health <= 0 then break end

		local pos = MobaShared.positionOf(minion)
		local hum = minion:FindFirstChildOfClass("Humanoid")
		if not hum then break end

		-- Поиск цели: сначала враги рядом, иначе идём по вейпоинтам
		local target, dist = MobaShared.findNearestEnemy(pos, team, 40, true)
		local attackRange = minion:GetAttribute("AttackRange") or 5

		if target and dist <= attackRange then
			-- Атака
			local now = os.clock()
			if now - lastAttack >= 1 then
				lastAttack = now
				MobaShared.applyDamage(target, minion:GetAttribute("Damage") or 35)
			end
		elseif target then
			-- Преследуем цель
			hum:MoveTo(MobaShared.positionOf(target))
		else
			-- Движение по линии
			local wp = waypoints[wpIndex]
			if wp then
				hum:MoveTo(wp)
				local flat = Vector3.new(pos.X - wp.X, 0, pos.Z - wp.Z)
				if flat.Magnitude < 24 then
					wpIndex = math.min(wpIndex + 1, #waypoints)
				end
			else
				-- Конец пути — атакуем ближайшее строение (Nexus)
				local t, d = MobaShared.findNearestEnemy(pos, team, 100, true)
				if t then
					hum:MoveTo(MobaShared.positionOf(t))
					if d <= attackRange then
						local now = os.clock()
						if now - lastAttack >= 1 then
							lastAttack = now
							MobaShared.applyDamage(t, minion:GetAttribute("Damage") or 35)
						end
					end
				end
			end
		end

		task.wait(0.4)
	end

	-- Смерть миньона: золото команде-убийце поблизости
	if minion.Parent then
		local pos = MobaShared.positionOf(minion)
		local gold = minion:GetAttribute("GoldReward") or 25
		local enemyTeam = (team == "Blue") and "Red" or "Blue"
		for _, player in ipairs(Players:GetPlayers()) do
				if player.Team and player.Team.Name == enemyTeam and player.Character then
					local d = (MobaShared.positionOf(player.Character) - pos).Magnitude
				if d < 15 then
					player:SetAttribute("Gold", (player:GetAttribute("Gold") or 0) + gold)
				end
			end
		end
		minion.Parent = nil
	end
end

spawnWave()
task.spawn(function()
	while true do
		task.wait(MobaConfig.WAVE_INTERVAL)
		spawnWave()
	end
end)

print("[MinionWaveSystem] Запущен, интервал волн: " .. MobaConfig.WAVE_INTERVAL .. "с")