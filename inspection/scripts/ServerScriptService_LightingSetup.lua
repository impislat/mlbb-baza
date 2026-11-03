-- Roblox path: /ServerScriptService/LightingSetup
-- Class: Script

-- LightingSetup: сочная, глубокая картинка в стиле Mobile Legends
-- Настраивает сервис Lighting и добавляет пост-эффекты при запуске игры

local Lighting = game:GetService("Lighting")

-- 1. Базовые настройки освещения
Lighting.ClockTime = 14 -- день, солнце высоко
Lighting.Brightness = 2.5 -- яркий день
Lighting.Ambient = Color3.fromRGB(120, 130, 140) -- холодный серо-голубой в тенях
Lighting.OutdoorAmbient = Color3.fromRGB(160, 170, 180) -- светлый оттенок улицы
Lighting.EnvironmentDiffuseScale = 0.5
Lighting.EnvironmentSpecularScale = 0.5
Lighting.GlobalShadows = true

-- 2. Пост-эффекты
local function getOrCreate(className, name)
	local inst = Lighting:FindFirstChild(name)
	if inst and inst:IsA(className) then return inst end
	if inst then inst.Parent = nil end
	return Instance.new(className)
end

-- Atmosphere: лёгкая дымка для глубины
local atmo = getOrCreate("Atmosphere", "MOBA_Atmosphere")
atmo.Density = 0.3
atmo.Haze = 1.5
atmo.Color = Color3.fromRGB(200, 220, 255)
atmo.Parent = Lighting

-- ColorCorrection: сочные цвета
local cc = getOrCreate("ColorCorrectionEffect", "MOBA_ColorCorrection")
cc.Brightness = 0.05
cc.Contrast = 0.15
cc.Saturation = 0.25
cc.TintColor = Color3.fromRGB(255, 245, 235)
cc.Parent = Lighting

-- SunRays: лёгкие лучи солнца
local rays = getOrCreate("SunRaysEffect", "MOBA_SunRays")
rays.Intensity = 0.05
rays.Spread = 0.5
rays.Parent = Lighting

-- Bloom: свечение кристаллов и способностей
local bloom = getOrCreate("BloomEffect", "MOBA_Bloom")
bloom.Intensity = 0.6
bloom.Threshold = 0.8
bloom.Size = 24
bloom.Parent = Lighting

print("[LightingSetup] Освещение и пост-эффекты настроены")