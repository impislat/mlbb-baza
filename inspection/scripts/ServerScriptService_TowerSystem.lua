-- Roblox path: /ServerScriptService/TowerSystem
-- Class: Script

--==================================================
-- TOWER SYSTEM
-- Башни, атака, приоритет целей и защита строений
-- Совместим с MatchManager
--==================================================

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local Debris = game:GetService("Debris")

local MobaConfig = require(ReplicatedStorage:WaitForChild("MobaConfig"))
local MobaShared = require(script.Parent:WaitForChild("MobaShared"))

--==================================================
-- НАСТРОЙКИ
--==================================================

local ATTACK_INTERVAL = 0.5
local ATTACK_COOLDOWN = 1
local DEFAULT_RANGE = 38
local DEFAULT_DAMAGE = 30

--==================================================
-- MATCH SIGNALS
--==================================================

local signals = ServerStorage:WaitForChild("MatchSignals")
local matchEndRequested = signals:WaitForChild("MatchEndRequested")

--==================================================
-- ПОИСК ПАПКИ БАШЕН
--==================================================

local map = workspace:WaitForChild("MOBA_Map")
local towersFolder = map:WaitForChild("Towers")

--==================================================
-- ДАННЫЕ СТРОЕНИЙ
--==================================================

local structures = {}
local towersByLane = {}
local tier3Towers = {}
local nexusByTeam = {}

local handledDeaths = {}
local towerLastAttack = {}

for _, model in ipairs(towersFolder:GetChildren()) do
	if model:IsA("Model") and model:GetAttribute("Team") then
		local team = model:GetAttribute("Team")
		local tier = model:GetAttribute("Tier")
		local lane = model:GetAttribute("Lane")
		local towerType = model:GetAttribute("TowerType")

		structures[model.Name] = model

		if towerType == "Nexus" then
			nexusByTeam[team] = model

		elseif tier == 3 then
			table.insert(tier3Towers, model)

		elseif lane and tier then
			towersByLane[team] = towersByLane[team] or {}
			towersByLane[team][lane] = towersByLane[team][lane] or {}
			towersByLane[team][lane][tier] = model
		end
	end
end

--==================================================
-- СОСТОЯНИЕ СТРОЕНИЯ
--==================================================

local function isAlive(model)
	return model ~= nil
		and model.Parent ~= nil
		and (model:GetAttribute("Health") or 0) > 0
end

local function setProtected(model, protected)
	if not model or not model.Parent then
		return
	end

	model:SetAttribute("Invulnerable", protected)

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			if protected then
				part.Transparency = math.max(part.Transparency, 0.75)
			else
				part.Transparency = 0
			end
		end
	end
end

--==================================================
-- ЗАЩИТА БАШЕН И НЕКСУСА
-- T2 защищена живой T1 своей линии.
-- T3 открываются, когда хотя бы одна линия полностью разрушена.
-- Nexus открывается после уничтожения обеих T3.
--==================================================

local function refreshProtection()
	for team, lanes in pairs(towersByLane) do

		-- Защита T2
		for _, tiers in pairs(lanes) do
			local t1 = tiers[1]
			local t2 = tiers[2]

			if t2 then
				setProtected(t2, isAlive(t1))
			end
		end

		-- Защита T3
		local anyLaneOpen = false

		for _, tiers in pairs(lanes) do
			if not isAlive(tiers[1]) and not isAlive(tiers[2]) then
				anyLaneOpen = true
				break
			end
		end

		for _, t3 in ipairs(tier3Towers) do
			if t3:GetAttribute("Team") == team then
				setProtected(t3, not anyLaneOpen)
			end
		end

		-- Защита Nexus
		local allT3Dead = true

		for _, t3 in ipairs(tier3Towers) do
			if t3:GetAttribute("Team") == team and isAlive(t3) then
				allT3Dead = false
				break
			end
		end

		local nexus = nexusByTeam[team]

		if nexus then
			setProtected(nexus, not allT3Dead)
		end
	end
end

--==================================================
-- РАЗРУШЕНИЕ СТРОЕНИЯ
--==================================================

local function destroyStructure(model)
	if not model or handledDeaths[model] then
		return
	end

	if (model:GetAttribute("Health") or 0) > 0 then
		return
	end

	handledDeaths[model] = true

	local towerType = model:GetAttribute("TowerType")
	local team = model:GetAttribute("Team")

	print("[TowerSystem] Уничтожено строение:", model.Name)

	-- Разрушение Nexus завершает матч
	if towerType == "Nexus" then
		local winner = team == "Blue" and "Red" or "Blue"

		print("[TowerSystem] Nexus уничтожен! Победитель:", winner)

		matchEndRequested:Fire(winner, "nexus")
	end

	-- Эффект разрушения
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			part.CanCollide = false
			part.CanTouch = false
			part.Transparency = 1
		end
	end

	refreshProtection()
end

--==================================================
-- НАБЛЮДЕНИЕ ЗА ЗДОРОВЬЕМ СТРОЕНИЙ
--==================================================

local function watchStructure(model)
	model:GetAttributeChangedSignal("Health"):Connect(function()
		if (model:GetAttribute("Health") or 0) <= 0 then
			task.defer(destroyStructure, model)
		end
	end)

	if (model:GetAttribute("Health") or 0) <= 0 then
		task.defer(destroyStructure, model)
	end
end

--==================================================
-- ПОЛОСКИ ЗДОРОВЬЯ
--==================================================

for _, model in pairs(structures) do
	watchStructure(model)

	local _, size = model:GetBoundingBox()

	local offset

	if model:GetAttribute("TowerType") == "Nexus" then
		offset = size.Y / 2 + 10
	else
		offset = 42
	end

	MobaShared.attachHealthBar(model, offset)
end

--==================================================
-- ПОИСК ЦЕЛИ ДЛЯ БАШНИ
-- Приоритет: миньоны -> герои
--==================================================

local function towerTarget(tower)
	local team = tower:GetAttribute("Team")
	local range = tower:GetAttribute("Range") or DEFAULT_RANGE

	local position = MobaShared.positionOf(tower)

	local bestMinion = nil
	local bestMinionDistance = range

	-- Сначала ищем вражеских миньонов
	for _, minion in ipairs(CollectionService:GetTagged(MobaShared.MINION_TAG)) do
		if minion.Parent
			and (minion:GetAttribute("Health") or 0) > 0
			and minion:GetAttribute("Team") ~= team then

			local distance = (
				MobaShared.positionOf(minion) - position
			).Magnitude

			if distance < bestMinionDistance then
				bestMinion = minion
				bestMinionDistance = distance
			end
		end
	end

	if bestMinion then
		return bestMinion
	end

	-- Если миньонов нет, ищем героев
	local bestHero = nil
	local bestHeroDistance = range

	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")

		if character
			and humanoid
			and humanoid.Health > 0
			and player.Team
			and player.Team.Name ~= team then

			local distance = (
				MobaShared.positionOf(character) - position
			).Magnitude

			if distance < bestHeroDistance then
				bestHero = character
				bestHeroDistance = distance
			end
		end
	end

	return bestHero
end

--==================================================
-- ВЫСТРЕЛ БАШНИ
--==================================================

local function towerShoot(tower, target)
	if not tower.Parent or not target or not target.Parent then
		return
	end

	local from = MobaShared.positionOf(tower) + Vector3.new(0, 35, 0)
	local to = MobaShared.positionOf(target) + Vector3.new(0, 2, 0)

	local beam = Instance.new("Part")
	beam.Name = "TowerProjectile"
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanTouch = false
	beam.CanQuery = false
	beam.Material = Enum.Material.Neon

	if tower:GetAttribute("Team") == "Blue" then
		beam.Color = Color3.fromRGB(80, 160, 255)
	else
		beam.Color = Color3.fromRGB(255, 90, 80)
	end

	local distance = (to - from).Magnitude

	beam.Size = Vector3.new(0.6, 0.6, distance)
	beam.CFrame = CFrame.lookAt(from, to) * CFrame.new(0, 0, -distance / 2)
	beam.Parent = workspace

	Debris:AddItem(beam, 0.15)

	MobaShared.applyDamage(
		target,
		tower:GetAttribute("Damage") or DEFAULT_DAMAGE,
		tower
	)
end

--==================================================
-- ЦИКЛ АТАК БАШЕН
--==================================================

task.spawn(function()
	while true do
		task.wait(ATTACK_INTERVAL)

		for _, tower in pairs(structures) do
			if tower.Parent
				and tower:GetAttribute("TowerType") ~= "Nexus"
				and isAlive(tower)
				and not tower:GetAttribute("Invulnerable") then

				local now = os.clock()
				local lastAttack = towerLastAttack[tower] or 0

				if now - lastAttack >= ATTACK_COOLDOWN then
					local target = towerTarget(tower)

					if target then
						towerLastAttack[tower] = now
						towerShoot(tower, target)
					end
				end
			end
		end
	end
end)

--==================================================
-- INITIALIZE
--==================================================

refreshProtection()

print(
	"[TowerSystem] Запущен. Строений:",
	#towersFolder:GetChildren(),
	"Башен:",
	#tier3Towers
)