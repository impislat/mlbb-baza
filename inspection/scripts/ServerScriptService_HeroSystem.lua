-- Roblox path: /ServerScriptService/HeroSystem
-- Class: Script

--[[
    HERO SYSTEM
    Серверная система героев для MOBA.
    Совместима с MatchManager и MobaShared.

    Отвечает за:
    - характеристики героев и рост от уровня;
    - синхронизацию Player Attributes и PlayerStats;
    - пассивное золото;
    - базовые атаки по команде игрока;
    - красный и командный баффы;
    - передачу состояния героев интерфейсу.

    Опыт и награды за миньонов начисляет MinionSystem.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService = game:GetService("CollectionService")

local MobaShared = require(
	script.Parent:WaitForChild("MobaShared")
)

-- НАСТРОЙКИ ГЕРОЕВ

local BASE_HEALTH = 600
local BASE_DAMAGE = 50

local HEALTH_PER_LEVEL = 100
local DAMAGE_PER_LEVEL = 8

local ATTACK_RANGE = 8
local ATTACK_COOLDOWN = 1

local PASSIVE_GOLD_AMOUNT = 1
local PASSIVE_GOLD_INTERVAL = 1.5

local STATE_UPDATE_INTERVAL = 1

-- СОБЫТИЯ

local function getRemoteEvent(name)
	local event = ReplicatedStorage:FindFirstChild(name)

	if event and event:IsA("RemoteEvent") then
		return event
	end

	if event then
		event:Destroy()
	end

	event = Instance.new("RemoteEvent")
	event.Name = name
	event.Parent = ReplicatedStorage

	return event
end

local heroState = getRemoteEvent("HeroState")
local basicAttack = getRemoteEvent("BasicAttack")

-- СЛУЖЕБНЫЕ ФУНКЦИИ

local function getLevel(player)
	return math.max(1, player:GetAttribute("Level") or 1)
end

local function getTeam(player)
	if player.Team then
		return player.Team.Name
	end

	return player:GetAttribute("Team")
end

local function getHumanoid(player)
	local character = player.Character

	if not character then
		return nil
	end

	return character:FindFirstChildOfClass("Humanoid")
end

local function isHeroAlive(player)
	local humanoid = getHumanoid(player)

	return humanoid ~= nil and humanoid.Health > 0
end

local function getPlayerStats(player)
	return player:FindFirstChild("PlayerStats")
end

-- СИНХРОНИЗАЦИЯ PLAYERSTATS И ATTRIBUTES

local STAT_NAMES = {
	"Gold",
	"XP",
	"Level",
	"Kills",
	"Deaths"
}

local syncing = {}

local function syncStat(player, statName)
	if syncing[player] then
		return
	end

	local stats = getPlayerStats(player)

	if not stats then
		return
	end

	local valueObject = stats:FindFirstChild(statName)

	if not valueObject or not valueObject:IsA("IntValue") then
		return
	end

	local value = player:GetAttribute(statName)

	if value == nil then
		value = 0
	end

	syncing[player] = true
	valueObject.Value = value
	syncing[player] = nil
end

local function setupStatSync(player)
	for _, statName in ipairs(STAT_NAMES) do
		local currentValue = player:GetAttribute(statName)

		if currentValue == nil then
			if statName == "Gold" then
				currentValue = 200
			elseif statName == "Level" then
				currentValue = 1
			else
				currentValue = 0
			end

			player:SetAttribute(statName, currentValue)
		end

		player:GetAttributeChangedSignal(statName):Connect(function()
			syncStat(player, statName)
		end)

		syncStat(player, statName)
	end

	local stats = getPlayerStats(player)

	if stats then
		for _, statName in ipairs(STAT_NAMES) do
			local valueObject = stats:FindFirstChild(statName)

			if valueObject and valueObject:IsA("IntValue") then
				valueObject.Changed:Connect(function(value)
					if syncing[player] then
						return
					end

					syncing[player] = true
					player:SetAttribute(statName, value)
					syncing[player] = nil
				end)
			end
		end
	end
end

-- ХАРАКТЕРИСТИКИ ГЕРОЯ

local function applyLevelStats(player, refillHealth)
	local level = getLevel(player)

	local maxHealth =
		BASE_HEALTH + (level - 1) * HEALTH_PER_LEVEL

	local damage =
		BASE_DAMAGE + (level - 1) * DAMAGE_PER_LEVEL

	player:SetAttribute("MaxHealth", maxHealth)
	player:SetAttribute("Damage", damage)

	local humanoid = getHumanoid(player)

	if humanoid then
		local oldMaxHealth = humanoid.MaxHealth

		humanoid.MaxHealth = maxHealth

		if refillHealth then
			humanoid.Health = maxHealth
		elseif maxHealth > oldMaxHealth then
			humanoid.Health = math.min(
				humanoid.Health + (maxHealth - oldMaxHealth),
				maxHealth
			)
		end
	end
end

-- УРОН ГЕРОЯ С УЧЁТОМ БАФФОВ

local function getHeroDamage(player)
	local damage =
		(player:GetAttribute("Damage") or BASE_DAMAGE)
		+ (player:GetAttribute("BonusDamage") or 0)

	local now = os.clock()

	-- Красный бафф: +20% урона
	local buffUntil = player:GetAttribute("BuffUntil")

	if buffUntil
		and buffUntil > now
		and player:GetAttribute("Buff") == "Red" then

		damage *= 1.2
	end

	-- Командный бафф босса: +20% урона
	local teamBuffUntil = player:GetAttribute("TeamBuffUntil")

	if teamBuffUntil and teamBuffUntil > now then
		damage *= 1.2
	end

	return damage
end

-- ПРОВЕРКА ЦЕЛИ ДЛЯ БАЗОВОЙ АТАКИ

local function isValidTarget(player, target)
	if typeof(target) ~= "Instance" then
		return false
	end

	if not target:IsA("Model") then
		return false
	end

	if not target:IsDescendantOf(workspace) then
		return false
	end

	if target:GetAttribute("Invulnerable") then
		return false
	end

	local myTeam = getTeam(player)

	if not myTeam then
		return false
	end

	-- Вражеский герой
	local targetPlayer = Players:GetPlayerFromCharacter(target)

	if targetPlayer then
		if targetPlayer == player then
			return false
		end

		if getTeam(targetPlayer) == myTeam then
			return false
		end

		local humanoid = target:FindFirstChildOfClass("Humanoid")

		return humanoid ~= nil and humanoid.Health > 0
	end

	-- Вражеский миньон
	if CollectionService:HasTag(target, MobaShared.MINION_TAG) then
		return target:GetAttribute("Team") ~= myTeam
			and (target:GetAttribute("Health") or 0) > 0
	end

	-- Вражеское строение
	if CollectionService:HasTag(target, MobaShared.STRUCTURE_TAG) then
		return target:GetAttribute("Team") ~= myTeam
			and (target:GetAttribute("Health") or 0) > 0
	end

	return false
end

-- БАЗОВАЯ АТАКА

local lastAttacks = {}

basicAttack.OnServerEvent:Connect(function(player, target)
	if not isHeroAlive(player) then
		return
	end

	if not isValidTarget(player, target) then
		return
	end

	local character = player.Character

	if not character then
		return
	end

	local now = os.clock()

	local cooldown =
		player:GetAttribute("AttackCooldown")
		or ATTACK_COOLDOWN

	local previousAttack = lastAttacks[player] or 0

	if now - previousAttack < cooldown then
		return
	end

	local heroPosition = MobaShared.positionOf(character)
	local targetPosition = MobaShared.positionOf(target)

	local dx = heroPosition.X - targetPosition.X
	local dz = heroPosition.Z - targetPosition.Z

	local distance = math.sqrt(dx * dx + dz * dz)

	local attackRange =
		player:GetAttribute("AttackRange")
		or ATTACK_RANGE

	if distance > attackRange then
		return
	end

	lastAttacks[player] = now

	local damage = getHeroDamage(player)

	MobaShared.applyDamage(target, damage, player)
end)

-- ПАССИВНОЕ ЗОЛОТО

task.spawn(function()
	while true do
		task.wait(PASSIVE_GOLD_INTERVAL)

		for _, player in ipairs(Players:GetPlayers()) do
			local gold = player:GetAttribute("Gold") or 0

			player:SetAttribute(
				"Gold",
				gold + PASSIVE_GOLD_AMOUNT
			)
		end
	end
end)

-- СОСТОЯНИЕ ГЕРОЕВ ДЛЯ HUD

local function syncStates()
	local states = {}

	for _, player in ipairs(Players:GetPlayers()) do
		local humanoid = getHumanoid(player)

		states[player.Name] = {
			level = getLevel(player),

			gold = player:GetAttribute("Gold") or 0,
			xp = player:GetAttribute("XP") or 0,

			kills = player:GetAttribute("Kills") or 0,
			deaths = player:GetAttribute("Deaths") or 0,

			buff = player:GetAttribute("Buff"),

			health = humanoid and humanoid.Health or 0,

			maxHealth =
				humanoid and humanoid.MaxHealth
				or player:GetAttribute("MaxHealth")
				or BASE_HEALTH,

			damage = getHeroDamage(player)
		}
	end

	heroState:FireAllClients(states)
end

task.spawn(function()
	while true do
		task.wait(STATE_UPDATE_INTERVAL)
		syncStates()
	end
end)

-- ИГРОКИ

local function setupPlayer(player)
	setupStatSync(player)

	player:SetAttribute(
		"AttackRange",
		player:GetAttribute("AttackRange") or ATTACK_RANGE
	)

	player:SetAttribute(
		"AttackCooldown",
		player:GetAttribute("AttackCooldown") or ATTACK_COOLDOWN
	)

	applyLevelStats(player, false)

	player:GetAttributeChangedSignal("Level"):Connect(function()
		applyLevelStats(player, false)
	end)

	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid", 10)

		if not humanoid then
			return
		end

		applyLevelStats(player, true)

		humanoid.Died:Connect(function()
			lastAttacks[player] = nil
		end)
	end)

	if player.Character then
		local humanoid = player.Character:FindFirstChildOfClass("Humanoid")

		if humanoid then
			applyLevelStats(player, false)
		end
	end
end

Players.PlayerAdded:Connect(setupPlayer)

for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

Players.PlayerRemoving:Connect(function(player)
	lastAttacks[player] = nil
	syncing[player] = nil
end)

print("[HeroSystem] Геройная система запущена")