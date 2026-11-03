-- Roblox path: /ServerScriptService/ItemShop
-- Class: Script

-- ItemShop: магазин предметов у фонтана (ключ B рядом с базой)
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MobaConfig = require(ReplicatedStorage:WaitForChild("MobaConfig"))
local buyItem = ReplicatedStorage:FindFirstChild("BuyItem")

-- Каталог предметов: эффекты применяются к статам героя
local ITEMS = {
	{ Id = "Sword", Name = "Меч (+15 урона)", Cost = 300, Damage = 15 },
	{ Id = "Armor", Name = "Броня (+250 ХП)", Cost = 300, Health = 250 },
	{ Id = "Boots", Name = "Сапоги (+3 скорость)", Cost = 250, Speed = 3 },
	{ Id = "Regen", Name = "Амулет (+2 реген/с)", Cost = 400, Regen = 2 },
	{ Id = "Potion", Name = "Зелье (лечит 40%)", Cost = 50, Consumable = true },
	{ Id = "Elixir", Name = "Эликсир (+30 урона)", Cost = 800, Damage = 30 },
}

-- Рассылка каталога клиентам при входе
local catalogEvent = Instance.new("RemoteEvent")
catalogEvent.Name = "ShopCatalog"
catalogEvent.Parent = ReplicatedStorage

local function sendCatalog(player)
	local list = {}
	for i, item in ipairs(ITEMS) do
		list[i] = { Id = item.Id, Name = item.Name, Cost = item.Cost }
	end
	catalogEvent:FireClient(player, list)
end

Players.PlayerAdded:Connect(sendCatalog)
for _, p in ipairs(Players:GetPlayers()) do
	sendCatalog(p)
end

-- Пересчёт статов с учётом предметов
local function applyItemStats(player)
	local items = player:GetAttribute("Items") or ""
	local owned = {}
	for id in string.gmatch(items, "[^,]+") do
		owned[id] = (owned[id] or 0) + 1
	end
	local addDamage, addHealth, addSpeed, addRegen = 0, 0, 0, 0
	for _, item in ipairs(ITEMS) do
		local n = owned[item.Id] or 0
		addDamage += (item.Damage or 0) * n
		addHealth += (item.Health or 0) * n
		addSpeed += (item.Speed or 0) * n
		addRegen += (item.Regen or 0) * n
	end
	player:SetAttribute("BonusDamage", addDamage)
	player:SetAttribute("BonusHealth", addHealth)
	player:SetAttribute("BonusSpeed", addSpeed)
	player:SetAttribute("BonusRegen", addRegen)

	-- Применяем к персонажу
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if hum then
		local level = player:GetAttribute("Level") or 1
		local maxHp = 600 + (level - 1) * 100 + addHealth
		hum.MaxHealth = maxHp
		hum.WalkSpeed = 16 + addSpeed
	end
end

-- Проверка близости к фонтану своей команды
local function nearFountain(player)
	local team = player:GetAttribute("Team")
	local fountainPos = MobaConfig.FOUNTAIN[team]
	if not fountainPos or not player.Character then return false end
	local pos = player.Character:GetPivot().Position
	local dx, dz = pos.X - fountainPos.X, pos.Z - fountainPos.Z
	return math.sqrt(dx * dx + dz * dz) < 30
end

buyItem.OnServerEvent:Connect(function(player, itemId)
	if typeof(itemId) ~= "string" then return end
	-- Найти предмет
	local item
	for _, it in ipairs(ITEMS) do
		if it.Id == itemId then item = it break end
	end
	if not item then return end
	-- Покупка расходников разрешена где угодно (если уже куплены), остальное — у фонтана
	local items = player:GetAttribute("Items") or ""
	if not item.Consumable and not nearFountain(player) then
		return -- слишком далеко от магазина
	end
	local gold = player:GetAttribute("Gold") or 0
	if gold < item.Cost then return end
	player:SetAttribute("Gold", gold - item.Cost)
	player:SetAttribute("Items", items == "" and itemId or items .. "," .. itemId)
	applyItemStats(player)
end)

-- Использование зелья (клавиша 1) — отдельное событие
local usePotion = Instance.new("RemoteEvent")
usePotion.Name = "UsePotion"
usePotion.Parent = ReplicatedStorage
usePotion.OnServerEvent:Connect(function(player)
	local items = player:GetAttribute("Items") or ""
	-- Найти и удалить одно зелье
	local found = false
	local rest = {}
	for id in string.gmatch(items, "[^,]+") do
		if id == "Potion" and not found then
			found = true
		else
			table.insert(rest, id)
		end
	end
	if not found then return end
	local char = player.Character
	local hum = char and char:FindFirstChildOfClass("Humanoid")
	if not hum or hum.Health <= 0 then return end
	hum.Health = math.min(hum.MaxHealth, hum.Health + hum.MaxHealth * 0.4)
	player:SetAttribute("Items", table.concat(rest, ","))
	applyItemStats(player)
end)

-- Регенерация от амулета
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		applyItemStats(player)
	end)
end)

task.spawn(function()
	while true do
		task.wait(1)
		for _, player in ipairs(Players:GetPlayers()) do
			local regen = player:GetAttribute("BonusRegen") or 0
			if regen > 0 and player.Character then
				local hum = player.Character:FindFirstChildOfClass("Humanoid")
				if hum and hum.Health > 0 then
					hum.Health = math.min(hum.MaxHealth, hum.Health + regen)
				end
			end
		end
	end
end)

print("[ItemShop] Запущен: " .. #ITEMS .. " предметов")