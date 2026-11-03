-- Roblox path: /StarterPlayer/StarterPlayerScripts/BushVision
-- Class: LocalScript

-- BushVision: скрывает игроков в кустах от тех, кто не в этом же кусту
-- Персонаж в кусту виден только себе и игрокам в том же кусту

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer

local function setCharacterHidden(character, hidden)
	-- Прозрачность всех частей
	for _, part in ipairs(character:GetDescendants()) do
		if part:IsA("BasePart") and part.LocalTransparencyModifier ~= (hidden and 1 or 0) then
			part.LocalTransparencyModifier = hidden and 1 or 0
		end
		-- Полоски здоровья и прочие GUI над персонажем
		if hidden and part:IsA("BillboardGui") and part.Enabled then
			part.Enabled = false
			part:SetAttribute("HiddenByBush", true)
		elseif not hidden and part:IsA("BillboardGui") and part:GetAttribute("HiddenByBush") then
			part.Enabled = true
			part:SetAttribute("HiddenByBush", false)
		end
		-- Декали (лицо)
		if part:IsA("Decal") then
			part.LocalTransparencyModifier = hidden and 1 or 0
		end
	end
	-- Имя над головой
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		if hidden then
			if humanoid.DisplayDistanceType ~= Enum.HumanoidDisplayDistanceType.None then
				humanoid:SetAttribute("SavedDisplayType", humanoid.DisplayDistanceType.Value)
				humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
			end
		else
			local saved = humanoid:GetAttribute("SavedDisplayType")
			if saved then
				humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.fromLocal(saved)
			humanoid:SetAttribute("SavedDisplayType", nil)
		end
	end
end

local function watchCharacter(character)
	if character == player.Character then return end
	local lastHidden = false
	local conn
	conn = RunService.Heartbeat:Connect(function()
		if not character.Parent then
			conn:Disconnect()
			return
		end
		local myChar = player.Character
		local myBush = myChar and myChar:GetAttribute("InBushId") or 0
		local theirBush = character:GetAttribute("InBushId") or 0
		-- Скрываем, если он в кусту, а мы не в этом же кусту
		local shouldHide = theirBush ~= 0 and myBush ~= theirBush
		if shouldHide ~= lastHidden then
			lastHidden = shouldHide
			setCharacterHidden(character, shouldHide)
		end
	end)
end

local function onPlayerAdded(other)
	other.CharacterAdded:Connect(watchCharacter)
	if other.Character then watchCharacter(other.Character) end
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, other in ipairs(Players:GetPlayers()) do
	if other ~= player then onPlayerAdded(other) end
end

print("[BushVision] Скрытность в кустах активна")