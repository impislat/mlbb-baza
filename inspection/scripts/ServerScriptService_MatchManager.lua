-- Roblox path: /ServerScriptService/MatchManager
-- Class: Script

--==================================================
-- MATCH MANAGER
-- Основная система управления матчем MOBA
--==================================================

local Players = game:GetService("Players")
local Teams = game:GetService("Teams")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local MobaConfig = require(ReplicatedStorage:WaitForChild("MobaConfig"))

--==================================================
-- НАСТРОЙКИ
--==================================================

local MATCH_DURATION = MobaConfig.MATCH_DURATION or 900

local RESPAWN_BASE = MobaConfig.RESPAWN_BASE or 8
local RESPAWN_PER_LEVEL = MobaConfig.RESPAWN_PER_LEVEL or 2

local STARTING_GOLD = 200
local STARTING_LEVEL = 1
local STARTING_XP = 0

local STATE_UPDATE_INTERVAL = 5

Players.CharacterAutoLoads = false

--==================================================
-- REMOTE EVENTS
--==================================================

local function getRemoteEvent(name)
	local event = ReplicatedStorage:FindFirstChild(name)

	if not event then
		event = Instance.new("RemoteEvent")
		event.Name = name
		event.Parent = ReplicatedStorage
	end

	return event
end

local MatchState = getRemoteEvent("MatchState")
local MatchEnd = getRemoteEvent("MatchEnd")

--==================================================
-- SERVER EVENTS
--==================================================

local signals = ServerStorage:FindFirstChild("MatchSignals")

if not signals then
	signals = Instance.new("Folder")
	signals.Name = "MatchSignals"
	signals.Parent = ServerStorage
end

local function getBindable(name)
	local event = signals:FindFirstChild(name)

	if not event then
		event = Instance.new("BindableEvent")
		event.Name = name
		event.Parent = signals
	end

	return event
end

local MatchStarted = getBindable("MatchStarted")
local MatchEnded = getBindable("MatchEnded")
local MatchEndRequested = getBindable("MatchEndRequested")

--==================================================
-- MATCH STATE
--==================================================

local matchActive = false
local matchFinished = false

local timeLeft = MATCH_DURATION

local teamScores = {
	Blue = 0,
	Red = 0
}

signals:SetAttribute("MatchActive", false)

--==================================================
-- TEAMS
--==================================================

local function getOrCreateTeam(name, color)
	local team = Teams:FindFirstChild(name)

	if not team then
		team = Instance.new("Team")
		team.Name = name
		team.Parent = Teams
	end

	team.TeamColor = BrickColor.new(color)
	team.AutoAssignable = false

	return team
end

local BlueTeam = getOrCreateTeam("Blue", "Bright blue")
local RedTeam = getOrCreateTeam("Red", "Bright red")

BlueTeam:SetAttribute("Score", 0)
RedTeam:SetAttribute("Score", 0)

--==================================================
-- PLAYER STATS
--==================================================

local function createStat(folder, name, value)
	local stat = folder:FindFirstChild(name)

	if not stat then
		stat = Instance.new("IntValue")
		stat.Name = name
		stat.Parent = folder
	end

	stat.Value = value

	return stat
end

local function setStat(player, name, value)
	player:SetAttribute(name, value)

	local stats = player:FindFirstChild("PlayerStats")

	if stats then
		local stat = stats:FindFirstChild(name)

		if stat and stat:IsA("IntValue") then
			stat.Value = value
		end
	end
end

local function getStat(player, name, defaultValue)
	local value = player:GetAttribute(name)

	if typeof(value) == "number" then
		return value
	end

	return defaultValue
end

local function initializePlayerStats(player)
	local stats = player:FindFirstChild("PlayerStats")

	if not stats then
		stats = Instance.new("Folder")
		stats.Name = "PlayerStats"
		stats.Parent = player
	end

	createStat(stats, "Gold", STARTING_GOLD)
	createStat(stats, "Level", STARTING_LEVEL)
	createStat(stats, "XP", STARTING_XP)
	createStat(stats, "Kills", 0)
	createStat(stats, "Deaths", 0)

	setStat(player, "Gold", STARTING_GOLD)
	setStat(player, "Level", STARTING_LEVEL)
	setStat(player, "XP", STARTING_XP)
	setStat(player, "Kills", 0)
	setStat(player, "Deaths", 0)
end

--==================================================
-- TEAM BALANCE
--==================================================

local function countTeamPlayers(team)
	local count = 0

	for _, player in ipairs(Players:GetPlayers()) do
		if player.Team == team then
			count += 1
		end
	end

	return count
end

local function assignTeam(player)
	local blueCount = countTeamPlayers(BlueTeam)
	local redCount = countTeamPlayers(RedTeam)

	if blueCount <= redCount then
		player.Team = BlueTeam
	else
		player.Team = RedTeam
	end

	player.Neutral = false
end

--==================================================
-- TEAM SCORE
--==================================================

local function updateTeamScore(teamName, amount)
	if teamName ~= "Blue" and teamName ~= "Red" then
		return
	end

	teamScores[teamName] += amount

	local team = teamName == "Blue" and BlueTeam or RedTeam
	team:SetAttribute("Score", teamScores[teamName])

	MatchState:FireAllClients(
		timeLeft,
		teamScores.Blue,
		teamScores.Red,
		matchActive
	)
end

--==================================================
-- KILLER DETECTION
--==================================================

local function getKiller(character)
	if not character then
		return nil
	end

	if character:GetAttribute("LastAttackerKind") ~= "Player" then
		return nil
	end

	local attackerUserId = character:GetAttribute("LastAttackerUserId")

	if typeof(attackerUserId) == "number" then
		local player = Players:GetPlayerByUserId(attackerUserId)

		if player then
			return player
		end
	end

	local attackerName = character:GetAttribute("LastAttackerPlayer")

	if typeof(attackerName) == "string" then
		return Players:FindFirstChild(attackerName)
	end

	return nil
end

--==================================================
-- MATCH FINISH
--==================================================

local function finishMatch(winner, reason)
	if matchFinished then
		return
	end

	matchFinished = true
	matchActive = false

	reason = reason or "unknown"

	signals:SetAttribute("MatchActive", false)

	MatchEnded:Fire(winner, reason)

	MatchState:FireAllClients(
		0,
		teamScores.Blue,
		teamScores.Red,
		false
	)

	MatchEnd:FireAllClients(winner, reason)

	print("[MatchManager] Матч завершён")
	print("[MatchManager] Победитель:", winner)
	print("[MatchManager] Причина:", reason)
end

--==================================================
-- WIN BY SCORE
--==================================================

local function finishByScore()
	if teamScores.Blue > teamScores.Red then
		finishMatch("Blue", "score")

	elseif teamScores.Red > teamScores.Blue then
		finishMatch("Red", "score")

	else
		finishMatch("Draw", "draw")
	end
end

--==================================================
-- SERVER REQUEST TO END MATCH
--==================================================

MatchEndRequested.Event:Connect(function(winner, reason)
	if not matchActive or matchFinished then
		return
	end

	if typeof(winner) == "Instance" and winner:IsA("Team") then
		winner = winner.Name
	end

	if winner ~= "Blue" and winner ~= "Red" then
		warn("[MatchManager] Некорректный победитель:", winner)
		return
	end

	finishMatch(winner, reason or "nexus")
end)

--==================================================
-- RESPAWN
--==================================================

local function getRespawnTime(player)
	local level = getStat(player, "Level", STARTING_LEVEL)

	return RESPAWN_BASE + level * RESPAWN_PER_LEVEL
end

local function loadCharacter(player)
	if not player or not player.Parent then
		return
	end

	if matchFinished or not matchActive then
		return
	end

	local success, err = pcall(function()
		player:LoadCharacterAsync()
	end)

	if not success then
		warn(
			"[MatchManager] Ошибка загрузки персонажа:",
			player.Name,
			err
		)
	end
end

--==================================================
-- CHARACTER DEATH
--==================================================

local connectedCharacters = setmetatable({}, {__mode = "k"})

local function setupCharacter(player, character)
	if connectedCharacters[character] then
		return
	end

	connectedCharacters[character] = true

	local humanoid = character:WaitForChild("Humanoid", 10)

	if not humanoid then
		warn("[MatchManager] Не найден Humanoid:", player.Name)
		return
	end

	local deathHandled = false

	humanoid.Died:Connect(function()
		if deathHandled then
			return
		end

		deathHandled = true

		if not matchActive or matchFinished then
			return
		end

		-- Смерти
		local deaths = getStat(player, "Deaths", 0)
		setStat(player, "Deaths", deaths + 1)

		-- Убийца
		local killer = getKiller(character)

		if killer and killer ~= player
			and killer.Team and player.Team
			and killer.Team ~= player.Team then

			local kills = getStat(killer, "Kills", 0)
			setStat(killer, "Kills", kills + 1)

			updateTeamScore(killer.Team.Name, 1)
		end

		-- Возрождение
		local respawnTime = getRespawnTime(player)

		print(
			"[MatchManager]",
			player.Name,
			"погиб. Возрождение через",
			respawnTime,
			"секунд"
		)

		task.delay(respawnTime, function()
			if not player.Parent then
				return
			end

			if not matchActive or matchFinished then
				return
			end

			loadCharacter(player)
		end)
	end)
end

--==================================================
-- PLAYER SETUP
--==================================================

local function setupPlayer(player)
	initializePlayerStats(player)

	if player.Team ~= BlueTeam and player.Team ~= RedTeam then
		assignTeam(player)
	else
		player.Neutral = false
	end

	player.CharacterAdded:Connect(function(character)
		setupCharacter(player, character)
	end)

	if player.Character then
		setupCharacter(player, player.Character)
	elseif matchActive then
		loadCharacter(player)
	end
end

Players.PlayerAdded:Connect(setupPlayer)

Players.PlayerRemoving:Connect(function(player)
	print("[MatchManager] Игрок покинул матч:", player.Name)
end)

-- Уже подключённые игроки
for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

--==================================================
-- START MATCH
--==================================================

local function startMatch()
	if matchActive or matchFinished then
		return
	end

	matchActive = true
	timeLeft = MATCH_DURATION

	signals:SetAttribute("MatchActive", true)

	print("[MatchManager] Матч начался!")

	MatchStarted:Fire()

	MatchState:FireAllClients(
		timeLeft,
		teamScores.Blue,
		teamScores.Red,
		true
	)

	-- Загружаем персонажей
	for _, player in ipairs(Players:GetPlayers()) do
		if not player.Character then
			loadCharacter(player)
		end
	end
end

--==================================================
-- MATCH TIMER
--==================================================

local function runMatchTimer()
	while matchActive and not matchFinished do
		task.wait(1)

		if not matchActive or matchFinished then
			break
		end

		timeLeft -= 1

		if timeLeft <= 0 then
			timeLeft = 0
			finishByScore()
			break
		end

		if timeLeft % STATE_UPDATE_INTERVAL == 0 then
			MatchState:FireAllClients(
				timeLeft,
				teamScores.Blue,
				teamScores.Red,
				true
			)
		end
	end
end

--==================================================
-- INITIALIZE
--==================================================

task.wait(1)

startMatch()

task.spawn(runMatchTimer)

print("[MatchManager] Полностью загружен")