-- Roblox path: /StarterPlayer/StarterPlayerScripts/MobaHUD
-- Class: LocalScript

-- MobaHUD: таймер матча, счёт, статы героя, баффы, экран победы
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local matchState = ReplicatedStorage:FindFirstChild("MatchState")
local matchEnd = ReplicatedStorage:FindFirstChild("MatchEnd")
local heroState = ReplicatedStorage:FindFirstChild("HeroState")

local gui = Instance.new("ScreenGui")
gui.Name = "MobaHUD"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function makeLabel(size, pos, text, textSize, color)
	local label = Instance.new("TextLabel")
	label.Size = size
	label.Position = pos
	label.BackgroundTransparency = 1
	label.Text = text or ""
	label.TextSize = textSize or 18
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.Font = Enum.Font.GothamBold
	label.Parent = gui
	return label
end

-- Верхняя панель: таймер + счёт
local topFrame = Instance.new("Frame")
topFrame.Size = UDim2.new(0, 420, 0, 44)
topFrame.Position = UDim2.new(0.5, -210, 0, 8)
topFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
topFrame.BackgroundTransparency = 0.25
	topFrame.BorderSizePixel = 0
topFrame.Parent = gui

local scoreLabel = makeLabel(UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0, 0), "Синие 0 : 0 Красные", 16)
scoreLabel.Parent = topFrame
local timerLabel = makeLabel(UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0, 22), "30:00", 20, Color3.fromRGB(255, 220, 100))
timerLabel.Parent = topFrame

-- Левая нижняя панель: статы героя
local statsFrame = Instance.new("Frame")
statsFrame.Size = UDim2.new(0, 240, 0, 110)
statsFrame.Position = UDim2.new(0, 10, 1, -120)
statsFrame.BackgroundColor3 = Color3.fromRGB(25, 25, 35)
statsFrame.BackgroundTransparency = 0.25
statsFrame.BorderSizePixel = 0
statsFrame.Parent = gui

local levelLabel = makeLabel(UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 0, 0), "Уровень 1", 18)
levelLabel.Parent = statsFrame
local goldLabel = makeLabel(UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0, 26), "Золото: 0", 16, Color3.fromRGB(255, 220, 100))
goldLabel.Parent = statsFrame
local kdLabel = makeLabel(UDim2.new(1, 0, 0, 22), UDim2.new(0, 0, 0, 48), "K/D: 0/0", 16)
kdLabel.Parent = statsFrame

-- XP-бар
local xpBack = Instance.new("Frame")
xpBack.Size = UDim2.new(1, -16, 0, 8)
xpBack.Position = UDim2.new(0, 8, 1, -12)
xpBack.BackgroundColor3 = Color3.fromRGB(40, 40, 50)
xpBack.BorderSizePixel = 0
xpBack.Parent = statsFrame
local xpBar = Instance.new("Frame")
xpBar.Size = UDim2.new(0, 0, 1, 0)
xpBar.BackgroundColor3 = Color3.fromRGB(120, 200, 255)
xpBar.BorderSizePixel = 0
xpBar.Parent = xpBack

-- Индикатор баффа
local buffLabel = makeLabel(UDim2.new(0, 200, 0, 24), UDim2.new(0, 10, 1, -150), "", 16)
buffLabel.TextXAlignment = Enum.TextXAlignment.Left

local function formatTime(sec)
	return string.format("%d:%02d", math.floor(sec / 60), sec % 60)
end

matchState.OnClientEvent:Connect(function(state)
	if state.timeLeft then
		timerLabel.Text = formatTime(state.timeLeft)
	end
	if state.score then
		scoreLabel.Text = "Синие " .. (state.score.Blue or 0) .. " : " .. (state.score.Red or 0) .. " Красные"
	end
end)

heroState.OnClientEvent:Connect(function(states)
	local my = states[player.Name]
	if my then
		levelLabel.Text = "Уровень " .. my.level
		goldLabel.Text = "Золото: " .. my.gold
		kdLabel.Text = "K/D: " .. my.kills .. "/" .. my.deaths
		local xpNeed = my.level * 100
		xpBar.Size = UDim2.new(math.clamp(my.xp / xpNeed, 0, 1), 0, 1, 0)
		if my.buff == "Blue" then
			buffLabel.Text = "БАФФ: Синий (реген)"
			buffLabel.TextColor3 = Color3.fromRGB(100, 160, 255)
		elseif my.buff == "Red" then
			buffLabel.Text = "БАФФ: Красный (+урон)"
			buffLabel.TextColor3 = Color3.fromRGB(255, 100, 100)
		else
			buffLabel.Text = ""
		end
	end
end)

-- Экран конца матча
matchEnd.OnClientEvent:Connect(function(winner, reason)
	local overlay = Instance.new("Frame")
	overlay.Size = UDim2.new(1, 0, 1, 0)
	overlay.BackgroundColor3 = Color3.new(0, 0, 0)
	overlay.BackgroundTransparency = 0.4
	overlay.Parent = gui

	local title
	if winner == "Blue" then
		title = "ПОБЕДА СИНИХ!"
		overlay.BackgroundColor3 = Color3.fromRGB(30, 60, 120)
	elseif winner == "Red" then
		title = "ПОБЕДА КРАСНЫХ!"
		overlay.BackgroundColor3 = Color3.fromRGB(120, 40, 30)
	else
		title = "НИЧЬЯ"
	end

	local titleLabel = Instance.new("TextLabel")
	titleLabel.Size = UDim2.new(1, 0, 0, 80)
	titleLabel.Position = UDim2.new(0, 0, 0.35, 0)
	titleLabel.BackgroundTransparency = 1
	titleLabel.Text = title
	titleLabel.TextSize = 56
	titleLabel.TextColor3 = Color3.new(1, 1, 1)
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.Parent = overlay

	local reasonLabel = Instance.new("TextLabel")
	reasonLabel.Size = UDim2.new(1, 0, 0, 30)
	reasonLabel.Position = UDim2.new(0, 0, 0.5, 0)
	reasonLabel.BackgroundTransparency = 1
	reasonLabel.Text = (reason == "nexus") and "Нексус разрушен" or "По очкам (время истекло)"
	reasonLabel.TextSize = 20
	reasonLabel.TextColor3 = Color3.fromRGB(200, 200, 200)
	reasonLabel.Font = Enum.Font.Gotham
	reasonLabel.Parent = overlay
end)

print("[MobaHUD] HUD запущен")