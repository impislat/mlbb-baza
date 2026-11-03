-- Roblox path: /ReplicatedStorage/MobaConfig
-- Class: ModuleScript

-- Общий конфиг МОБА: раскладка карты и балансовые константы
-- Масштаб карты: 3000x3000 studs (координаты х3)
local MobaConfig = {}

MobaConfig.SCALE = 3
MobaConfig.HEX_R = 960
MobaConfig.HEX_H = 960 * math.sqrt(3) / 2

-- Вейпоинты линий (от базы Синих к базе Красных)
MobaConfig.LANES = {
	Top = {
		Vector3.new(0, 0, 645),
		Vector3.new(-270, 0, 705),
		Vector3.new(-765, 0, 420),
		Vector3.new(-885, 0, 0),
		Vector3.new(-765, 0, -420),
		Vector3.new(-270, 0, -705),
		Vector3.new(0, 0, -645),
	},
	Mid = {
		Vector3.new(0, 0, 645),
		Vector3.new(0, 0, -645),
	},
	Bot = {
		Vector3.new(0, 0, 645),
		Vector3.new(270, 0, 705),
		Vector3.new(765, 0, 420),
		Vector3.new(885, 0, 0),
		Vector3.new(765, 0, -420),
		Vector3.new(270, 0, -705),
		Vector3.new(0, 0, -645),
	},
}

-- Башни: {позиция, команда, линия, тир}
MobaConfig.TOWERS = {
	-- Синие (юг)
	{Vector3.new(-330, 0, 690), "Blue", "Top", 2},
	{Vector3.new(-795, 0, 315), "Blue", "Top", 1},
	{Vector3.new(0, 0, 450), "Blue", "Mid", 2},
	{Vector3.new(0, 0, 240), "Blue", "Mid", 1},
	{Vector3.new(330, 0, 690), "Blue", "Bot", 2},
	{Vector3.new(795, 0, 315), "Blue", "Bot", 1},
	{Vector3.new(-105, 0, 585), "Blue", "Base", 3},
	{Vector3.new(105, 0, 585), "Blue", "Base", 3},
	-- Красные (север, зеркально)
	{Vector3.new(-330, 0, -690), "Red", "Top", 2},
	{Vector3.new(-795, 0, -315), "Red", "Top", 1},
	{Vector3.new(0, 0, -450), "Red", "Mid", 2},
	{Vector3.new(0, 0, -240), "Red", "Mid", 1},
	{Vector3.new(330, 0, -690), "Red", "Bot", 2},
	{Vector3.new(795, 0, -315), "Red", "Bot", 1},
	{Vector3.new(-105, 0, -585), "Red", "Base", 3},
	{Vector3.new(105, 0, -585), "Red", "Base", 3},
}

-- Nexus и фонтаны
MobaConfig.NEXUS = {
	Blue = Vector3.new(0, 0, 735),
	Red = Vector3.new(0, 0, -735),
}
MobaConfig.FOUNTAIN = {
	Blue = Vector3.new(0, 0, 620),
	Red = Vector3.new(0, 0, -620),
}
MobaConfig.SPAWN = {
	Blue = Vector3.new(0, 1, 765),
	Red = Vector3.new(0, 1, -765),
}

-- Кемпы леса: {позиция, тип, бафф}
MobaConfig.CAMPS = {
	{Vector3.new(-450, 0, 240), "Small", nil},
	{Vector3.new(450, 0, 240), "Small", nil},
	{Vector3.new(-450, 0, -240), "Small", nil},
	{Vector3.new(450, 0, -240), "Small", nil},
	{Vector3.new(-300, 0, 210), "Big", "Blue"},
	{Vector3.new(300, 0, 210), "Big", "Red"},
	{Vector3.new(-300, 0, -210), "Big", "Blue"},
	{Vector3.new(300, 0, -210), "Big", "Red"},
}

-- Боссы в реке
MobaConfig.BOSSES = {
	Turtle = Vector3.new(-210, 0, 0),
	Lord = Vector3.new(210, 0, 0),
}

-- Тайминги и баланс
MobaConfig.WAVE_INTERVAL = 30
MobaConfig.MINIONS_PER_LANE = 3
MobaConfig.CAMP_RESPAWN = 75
MobaConfig.TURTLE_RESPAWN = 120
MobaConfig.LORD_RESPAWN = 480
MobaConfig.MATCH_DURATION = 30 * 60
MobaConfig.RESPAWN_BASE = 5
MobaConfig.RESPAWN_PER_LEVEL = 2

return MobaConfig