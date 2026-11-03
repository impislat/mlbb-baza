-- Roblox path: /ServerScriptService/MobaShared
-- Class: ModuleScript

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")

local MobaShared = {}

MobaShared.MINION_TAG = "MobaMinion"
MobaShared.STRUCTURE_TAG = "MobaStructure"
MobaShared.JUNGLE_TAG = "MobaJungle"

-- Расстояние только по горизонтали (карта плоская, вид сверху)
local function flatDist(a, b)
	local dx, dz = a.X - b.X, a.Z - b.Z
	return math.sqrt(dx * dx + dz * dz)
end

function MobaShared.positionOf(target)
	if target:IsA("Model") then
		return target:GetPivot().Position
	end
	return target.Position
end

function MobaShared.applyDamage(target, amount, attacker)
	if not target or not target.Parent then return end
	-- Защищённые башни (T2/T3/Nexus под защитой) урона не получают
	if target:GetAttribute("Invulnerable") then return end

	-- Запоминаем атакующего: нужно для наград (last hit) и аггро на героев
	if attacker ~= nil then
		if typeof(attacker) == "Instance" and attacker:IsA("Player") then
			target:SetAttribute("LastAttackerKind", "Player")
			target:SetAttribute("LastAttackerPlayer", attacker.Name)
			-- Герой атаковал кого-то — вражеские миньоны могут аггриться на него
			local char = attacker.Character
			if char then
				char:SetAttribute("AggroUntil", os.clock() + 4)
			end
		elseif CollectionService:HasTag(attacker, MobaShared.MINION_TAG) then
			target:SetAttribute("LastAttackerKind", "Minion")
			target:SetAttribute("LastAttackerPlayer", nil)
		elseif CollectionService:HasTag(attacker, MobaShared.STRUCTURE_TAG) then
			target:SetAttribute("LastAttackerKind", "Tower")
			target:SetAttribute("LastAttackerPlayer", nil)
		end
	end

	local health = target:GetAttribute("Health")
	if health ~= nil then
		-- миньон или строение (атрибуты)
		target:SetAttribute("Health", math.max(0, health - amount))
		return
	end
	-- персонаж игрока
	if target:IsA("Model") then
		local humanoid = target:FindFirstChildOfClass("Humanoid")
		if humanoid and humanoid.Health > 0 then
			humanoid.Health = humanoid.Health - amount
		end
	end
end

local function isEnemy(target, myTeam)
	local team = target:GetAttribute("Team")
	if team then
		return team ~= myTeam
	end
	local player = Players:GetPlayerFromCharacter(target)
	if player and player.Team then
		return player.Team.Name ~= myTeam
	end
	return false
end

-- Кэш горизонтальных полуразмеров строений (для дистанции до края, а не пивота)
local structureExtents = {}

local function structureEdgeDist(structure, pos)
	local ext = structureExtents[structure]
	if ext == nil then
		local ok, _, size = pcall(structure.GetBoundingBox, structure)
		if ok and size then
			ext = {hx = size.X / 2, hz = size.Z / 2}
		else
			ext = {hx = 0, hz = 0}
		end
		structureExtents[structure] = ext
	end
	local sp = MobaShared.positionOf(structure)
	-- расстояние до прямоугольной зоны строения (0 — внутри)
	local dx = math.max(math.abs(pos.X - sp.X) - ext.hx, 0)
	local dz = math.max(math.abs(pos.Z - sp.Z) - ext.hz, 0)
	return math.sqrt(dx * dx + dz * dz)
end

-- Ищет ближайшего врага: миньон, строение (опционально) или игрок
function MobaShared.findNearestEnemy(pos, myTeam, maxDist, includeStructures)
	local best, bestDist = nil, maxDist

	for _, minion in CollectionService:GetTagged(MobaShared.MINION_TAG) do
		if minion.Parent and (minion:GetAttribute("Health") or 0) > 0 and isEnemy(minion, myTeam) then
			local d = flatDist(MobaShared.positionOf(minion), pos)
			if d < bestDist then
				best, bestDist = minion, d
			end
		end
	end

	if includeStructures ~= false then
		for _, structure in CollectionService:GetTagged(MobaShared.STRUCTURE_TAG) do
			if structure.Parent and (structure:GetAttribute("Health") or 0) > 0
		and not structure:GetAttribute("Invulnerable")
		and isEnemy(structure, myTeam) then
				local d = structureEdgeDist(structure, pos)
				if d < bestDist then
					best, bestDist = structure, d
				end
			end
		end
	end

	for _, player in Players:GetPlayers() do
		local char = player.Character
		local hum = char and char:FindFirstChildOfClass("Humanoid")
		if char and hum and hum.Health > 0 and isEnemy(char, myTeam) then
			local d = flatDist(MobaShared.positionOf(char), pos)
			if d < bestDist then
				best, bestDist = char, d
			end
		end
	end

	return best, bestDist
end

-- Полоска здоровья над строением/миньоном
function MobaShared.attachHealthBar(model, yOffset)
	local gui = Instance.new("BillboardGui")
	gui.Name = "HealthBar"
	gui.Size = UDim2.new(0, 110, 0, 14)
	gui.StudsOffset = Vector3.new(0, yOffset, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 350
	gui.Adornee = model

	local back = Instance.new("Frame")
	back.Size = UDim2.new(1, 0, 1, 0)
	back.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
	back.BackgroundTransparency = 0.3
	back.BorderSizePixel = 0
	back.Parent = gui

	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 1, 0)
	bar.BackgroundColor3 = Color3.fromRGB(80, 220, 80)
	bar.BorderSizePixel = 0
	bar.Parent = back

	local function update()
		local health = model:GetAttribute("Health") or 0
		local maxHealth = model:GetAttribute("MaxHealth") or 100
		local ratio = math.clamp(health / maxHealth, 0, 1)
		bar.Size = UDim2.new(ratio, 0, 1, 0)
		if ratio > 0.5 then
			bar.BackgroundColor3 = Color3.fromRGB(80, 220, 80)
		elseif ratio > 0.25 then
			bar.BackgroundColor3 = Color3.fromRGB(230, 200, 60)
		else
			bar.BackgroundColor3 = Color3.fromRGB(230, 70, 70)
		end
	end
	update()
	model:GetAttributeChangedSignal("Health"):Connect(update)
	gui.Parent = model
end

return MobaShared