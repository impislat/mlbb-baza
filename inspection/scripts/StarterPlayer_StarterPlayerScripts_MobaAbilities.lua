-- Roblox path: /StarterPlayer/StarterPlayerScripts/MobaAbilities
-- Class: LocalScript

-- MobaAbilities: панель способностей Q/W/E/R, зелье (1), магазин (B)
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local castAbility = ReplicatedStorage:FindFirstChild("CastAbility")
local buyItem = ReplicatedStorage:FindFirstChild("BuyItem")
local usePotion = ReplicatedStorage:FindFirstChild("UsePotion")
local shopCatalog = ReplicatedStorage:FindFirstChild("ShopCatalog")

local gui = Instance.new("ScreenGui")
gui.Name = "MobaAbilities"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Панель способностей внизу по центру
local bar = Instance.new("Frame")
bar.Size = UDim2.new(0, 340, 0, 70)
bar.Position = UDim2.new(0.5, -170, 1, -80)
bar.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
bar.BackgroundTransparency = 0.25
bar.BorderSizePixel = 0
bar.Parent = gui

local COOLDOWNS = { Q = 6, W = 25, E = 15, R = 60 }
local slotLabels = {}
local slotFrames = {}

local function makeSlot(letter, index)
	local frame = Instance.new("Frame")
	frame.Size = UDim2.new(0, 60, 0, 60)
	frame.Position = UDim2.new(0, 10 + (index - 1) * 70, 0, 5)
	frame.BackgroundColor3 = Color3.fromRGB(50, 50, 65)
	frame.BorderSizePixel = 0
	frame.Parent = bar

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = letter
	label.TextSize = 26
	label.TextColor3 = Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.Parent = frame

	local cd = Instance.new("TextLabel")
	cd.Size = UDim2.new(1, 0, 0, 20)
	cd.Position = UDim2.new(0, 0, 1, -20)
	cd.BackgroundTransparency = 1
	cd.Text = ""
	cd.TextSize = 16
	cd.TextColor3 = Color3.fromRGB(255, 220, 100)
	cd.Font = Enum.Font.GothamBold
	cd.Parent = frame

	slotFrames[letter] = frame
	slotLabels[letter] = cd
end

makeSlot("Q", 1) makeSlot("W", 2) makeSlot("E", 3) makeSlot("R", 4)

-- Слот зелья (клавиша 1)
local potionFrame = Instance.new("Frame")
potionFrame.Size = UDim2.new(0, 60, 0, 60)
potionFrame.Position = UDim2.new(0, 10 + 4 * 70, 0, 5)
potionFrame.BackgroundColor3 = Color3.fromRGB(65, 40, 50)
potionFrame.BorderSizePixel = 0
potionFrame.Parent = bar
local potionLabel = Instance.new("TextLabel")
potionLabel.Size = UDim2.new(1, 0, 1, 0)
potionLabel.BackgroundTransparency = 1
potionLabel.Text = "1"
potionLabel.TextSize = 26
potionLabel.TextColor3 = Color3.new(1, 1, 1)
potionLabel.Font = Enum.Font.GothamBold
potionLabel.Parent = potionFrame

local cooldowns = {} -- [slot] = readyAt (os.clock)
local toggleShop -- объявляем заранее, т.к. обработчик ввода ссылается на функцию

local function startCooldown(slot)
	cooldowns[slot] = os.clock() + COOLDOWNS[slot]
end

-- Обновление отображения кулдаунов
task.spawn(function()
	while true do
		task.wait(0.1)
		local now = os.clock()
		for slot, label in pairs(slotLabels) do
			local readyAt = cooldowns[slot]
			if readyAt and now < readyAt then
				label.Text = string.format("%.0f", readyAt - now)
				slotFrames[slot].BackgroundColor3 = Color3.fromRGB(35, 35, 45)
			else
				label.Text = ""
				slotFrames[slot].BackgroundColor3 = Color3.fromRGB(50, 50, 65)
			end
		end
	end
end)

-- Хоткеи
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	local key = input.KeyCode
	if key == Enum.KeyCode.Q or key == Enum.KeyCode.W
	or key == Enum.KeyCode.E or key == Enum.KeyCode.R then
		local slot = key.Name
		local now = os.clock()
		if not cooldowns[slot] or now >= cooldowns[slot] then
			castAbility:FireServer(slot)
			startCooldown(slot)
		end
	elseif key == Enum.KeyCode.One then
		usePotion:FireServer()
	elseif key == Enum.KeyCode.B then
		toggleShop()
	end
end)

-- === МАГАЗИН ===
local shopFrame = Instance.new("Frame")
shopFrame.Size = UDim2.new(0, 300, 0, 360)
shopFrame.Position = UDim2.new(1, -320, 0.5, -180)
shopFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
shopFrame.BackgroundTransparency = 0.1
shopFrame.BorderSizePixel = 0
shopFrame.Visible = false
shopFrame.Parent = gui

local shopTitle = Instance.new("TextLabel")
shopTitle.Size = UDim2.new(1, 0, 0, 30)
shopTitle.BackgroundTransparency = 1
shopTitle.Text = "МАГАЗИН (у фонтана)"
shopTitle.TextSize = 18
shopTitle.TextColor3 = Color3.new(1, 1, 1)
shopTitle.Font = Enum.Font.GothamBold
shopTitle.Parent = shopFrame

local shopList = Instance.new("ScrollingFrame")
shopList.Size = UDim2.new(1, -20, 1, -40)
shopList.Position = UDim2.new(0, 10, 0, 35)
shopList.BackgroundTransparency = 1
shopList.CanvasSize = UDim2.new(0, 0, 0, 0)
shopList.AutomaticCanvasSize = Enum.AutomaticSize.Y
shopList.ScrollBarThickness = 6
shopList.Parent = shopFrame

local catalog = {}
shopCatalog.OnClientEvent:Connect(function(list)
	catalog = list
	-- Перестроить список
	for _, child in ipairs(shopList:GetChildren()) do
		child:Destroy()
	end
	for i, item in ipairs(list) do
		local btn = Instance.new("TextButton")
		btn.Size = UDim2.new(1, 0, 0, 44)
		btn.Position = UDim2.new(0, 0, 0, (i - 1) * 48)
		btn.BackgroundColor3 = Color3.fromRGB(45, 45, 60)
		btn.Text = item.Name .. " — " .. item.Cost .. "g"
		btn.TextSize = 14
		btn.TextColor3 = Color3.new(1, 1, 1)
		btn.Font = Enum.Font.Gotham
		btn.Parent = shopList
		btn.MouseButton1Click:Connect(function()
			buyItem:FireServer(item.Id)
		end)
	end
end)

function toggleShop()
	shopFrame.Visible = not shopFrame.Visible
end

print("[MobaAbilities] Панель способностей запущена: Q/W/E/R, 1 — зелье, B — магазин")