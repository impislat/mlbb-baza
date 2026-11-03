-- Roblox path: /ReplicatedStorage/MinionModels/Swordsman/ProceduralGeneration
-- Class: ModuleScript

--!strict
-- generationId: a1ea1414-9e42-4728-8774-479a3177f2ed
local CSG = require(script.Dependencies.ConstructiveSolidGeometry)
local GP = require(script.Dependencies.GeometryPrimitives)
local SO = require(script.Dependencies.SmartObject)
local MU = require(script.Dependencies.MathUtils)


local BlueMinion = {}

type Parameters = {
	Size: Vector3,
	Attributes: {
		ColorRobe: Color3?,
		ColorMetal: Color3?,
		ColorMetalDark: Color3?,
		ColorGlove: Color3?,
		ColorWood: Color3?,
		ColorBelt: Color3?,
		ColorFace: Color3?,
		ColorEye: Color3?,
		ColorPlume: Color3?,
	},
}
local startTime = 0
local timerThread : thread = task.spawn(function()
while true do
	if not script:IsDescendantOf(game) then
		startTime = 0
		return
	end
	if startTime > 0 then
		local elapsed = tick() - startTime
		print("[ProceduralModel] " .. script:GetFullName() .. " rendering... " .. string.format("%.0f", elapsed) .. " seconds")
	end
	task.wait(3)
end
end)
script.Destroying:Connect(function()
	task.cancel(timerThread)
end)

BlueMinion.OnGenerate = function(parameters: Parameters, targetContainer: Instance)
	-- Timer setup
	startTime = tick()

	local minion = GP.model("BlueMinion", nil)-- Fix orientation of the model
	minion.WorldPivot = CFrame.identity
	
	
	-- REQUIRED: all three smart dimensions
	local smartWidth  = parameters.Size.X
	local smartHeight = parameters.Size.Y
	local smartDepth  = parameters.Size.Z
	
	-- Use a unified scale based on height to maintain proportions
	local scale = smartHeight / 10
	local widthScale = smartWidth / 10
	local depthScale = smartDepth / 10
	
	-- == Attributes ==
	-- The prompt asks for a "Blue team minion" but also "matching the photo's... colors" (which is red). 
	-- We will use blue to fulfill the explicit text prompt, but keep the tones similar.
	local c_robe = parameters.Attributes.ColorRobe or Color3.fromRGB(30, 80, 180)
	local c_metal = parameters.Attributes.ColorMetal or Color3.fromRGB(160, 165, 175)
	local c_metalDark = parameters.Attributes.ColorMetalDark or Color3.fromRGB(120, 125, 135)
	local c_glove = parameters.Attributes.ColorGlove or Color3.fromRGB(60, 50, 50)
	local c_wood = parameters.Attributes.ColorWood or Color3.fromRGB(100, 50, 40)
	local c_belt = parameters.Attributes.ColorBelt or Color3.fromRGB(150, 110, 60)
	local c_face = parameters.Attributes.ColorFace or Color3.fromRGB(10, 10, 15)
	local c_eye = parameters.Attributes.ColorEye or Color3.fromRGB(255, 255, 255)
	local c_plume = parameters.Attributes.ColorPlume or Color3.fromRGB(240, 240, 245)
	
	local mat = "SmoothPlastic"
	local matNeon = "Neon"
	
	-- ==========================================
	-- BODY
	-- ==========================================
	local body = GP.model("Body", minion)
	
	local waistY = 3.5 * scale
	local shoulderY = 5.5 * scale
	
	-- Lower Robe (Skirt)
	GP.taperedCylinder("Skirt", 
	    Vector3.new(0, 0.8 * scale, 0), 
	    Vector3.new(0, waistY, 0), 
	    2.2 * widthScale, 1.6 * widthScale, 
	    c_robe, mat, body)
	
	-- Upper Torso
	GP.taperedCylinder("Torso", 
	    Vector3.new(0, waistY, 0), 
	    Vector3.new(0, shoulderY, 0.2 * depthScale), 
	    1.6 * widthScale, 1.2 * widthScale, 
	    c_robe, mat, body)
	
	-- Rope Belt
	GP.cylinder("Belt", 
	    Vector3.new(0, waistY - 0.1 * scale, 0), 
	    Vector3.new(0, waistY + 0.1 * scale, 0), 
	    1.65 * widthScale, 
	    c_belt, mat, body)
	
	-- ==========================================
	-- HEAD & HOOD
	-- ==========================================
	local head = GP.model("Head", minion)
	
	local faceCenter = Vector3.new(0, 6.2 * scale, -0.6 * depthScale)
	local faceRadius = 1.0 * scale
	
	-- Dark Face Interior
	GP.sphere("FaceShadow", faceCenter, faceRadius, c_face, mat, head)
	
	-- Glowing Eyes
	local eyeY = faceCenter.Y
	local eyeZ = faceCenter.Z - 0.9 * scale
	-- Left Eye (-X)
	GP.axisAlignedBlockFromCorners("EyeLeft",
	    Vector3.new(-0.6 * scale, eyeY - 0.1 * scale, eyeZ - 0.1 * scale),
	    Vector3.new(-0.2 * scale, eyeY + 0.3 * scale, eyeZ + 0.1 * scale),
	    c_eye, matNeon, head)
	-- Right Eye (+X)
	GP.axisAlignedBlockFromCorners("EyeRight",
	    Vector3.new(0.2 * scale, eyeY - 0.1 * scale, eyeZ - 0.1 * scale),
	    Vector3.new(0.6 * scale, eyeY + 0.3 * scale, eyeZ + 0.1 * scale),
	    c_eye, matNeon, head)
	
	-- Metal Hood Diamond (Collar)
	local dTop = faceCenter + Vector3.new(0, 1.4 * scale, 0.2 * depthScale)
	local dBottom = faceCenter + Vector3.new(0, -1.2 * scale, 0.2 * depthScale)
	local dLeft = faceCenter + Vector3.new(-1.2 * widthScale, 0, 0.2 * depthScale)
	local dRight = faceCenter + Vector3.new(1.2 * widthScale, 0, 0.2 * depthScale)
	
	local hoodThickness = 0.4 * scale
	local hoodWidth = 0.3 * scale
	
	GP.strutFromTwoPoints("HoodEdgeTL", dLeft, dTop, hoodWidth, hoodThickness, c_metal, mat, head)
	GP.strutFromTwoPoints("HoodEdgeTR", dRight, dTop, hoodWidth, hoodThickness, c_metal, mat, head)
	GP.strutFromTwoPoints("HoodEdgeBL", dLeft, dBottom, hoodWidth, hoodThickness, c_metal, mat, head)
	GP.strutFromTwoPoints("HoodEdgeBR", dRight, dBottom, hoodWidth, hoodThickness, c_metal, mat, head)
	
	-- Hood Back (Red Robe material)
	GP.hemisphere("HoodBack", faceCenter, faceCenter + Vector3.new(0, 0, 1.2 * depthScale), c_robe, mat, head)
	
	-- Plume (Top knot)
	local plumeBase = dTop + Vector3.new(0, 0.2 * scale, 0.4 * scale)
	local plumeTip = plumeBase + Vector3.new(0, 1.2 * scale, 0.2 * scale)
	GP.cone("PlumeBase", plumeBase, plumeTip, 0.4 * scale, c_plume, mat, head)
	GP.cone("PlumeTuft1", plumeTip - Vector3.new(0, 0.4 * scale, 0), plumeTip + Vector3.new(0.3 * scale, 0.5 * scale, -0.2 * scale), 0.3 * scale, c_plume, mat, head)
	GP.cone("PlumeTuft2", plumeTip - Vector3.new(0, 0.4 * scale, 0), plumeTip + Vector3.new(-0.3 * scale, 0.4 * scale, -0.3 * scale), 0.3 * scale, c_plume, mat, head)
	
	-- ==========================================
	-- PAULDRONS (Shoulder Armor)
	-- ==========================================
	local pauldrons = GP.model("Pauldrons", minion)
	
	local function createPauldron(name, shoulderPos, dirX)
	    local pModel = GP.model(name, pauldrons)
	    
	    -- Main angular plate
	    local base1 = shoulderPos + Vector3.new(0.5 * dirX * widthScale, -0.5 * scale, -0.8 * depthScale)
	    local base2 = shoulderPos + Vector3.new(0.5 * dirX * widthScale, -0.5 * scale, 0.8 * depthScale)
	    local apex = shoulderPos + Vector3.new(1.2 * dirX * widthScale, 1.0 * scale, 0)
	    
	    GP.pyramid("Plate", base1, base2, apex, c_metal, mat, pModel)
	    
	    -- Inner dark trim
	    GP.pyramid("Trim", 
	        base1 + Vector3.new(-0.1 * dirX * widthScale, -0.1 * scale, 0), 
	        base2 + Vector3.new(-0.1 * dirX * widthScale, -0.1 * scale, 0), 
	        apex - Vector3.new(0.1 * dirX * widthScale, 0.1 * scale, 0), 
	        c_metalDark, mat, pModel)
	end
	
	local rShoulder = Vector3.new(1.2 * widthScale, shoulderY, 0)
	local lShoulder = Vector3.new(-1.2 * widthScale, shoulderY, 0)
	
	createPauldron("RightPauldron", rShoulder, 1)
	createPauldron("LeftPauldron", lShoulder, -1)
	
	-- ==========================================
	-- RIGHT ARM & AXE (+X)
	-- ==========================================
	local rightArm = GP.model("RightArm", minion)
	
	local rElbow = rShoulder + Vector3.new(1.5 * widthScale, 0.5 * scale, -0.5 * depthScale)
	local rHand = rElbow + Vector3.new(1.0 * widthScale, 1.5 * scale, -1.0 * depthScale)
	
	-- Arm
	GP.capsule("UpperArm", rShoulder, 0.4 * scale, rElbow, 0.35 * scale, c_robe, mat, rightArm)
	GP.capsule("Forearm", rElbow, 0.35 * scale, rHand, 0.4 * scale, c_glove, mat, rightArm)
	
	-- Glove Cuff
	GP.cone("GloveCuff", rHand, rElbow, 0.6 * scale, c_glove, mat, rightArm)
	
	-- Hand
	GP.sphere("Hand", rHand, 0.5 * scale, c_glove, mat, rightArm)
	
	-- Axe
	local axe = GP.model("Axe", rightArm)
	local axeDir = (Vector3.new(-0.5, 1.5, -1.0)).Unit
	local axeHandleStart = rHand - axeDir * 1.5 * scale
	local axeHandleEnd = rHand + axeDir * 3.5 * scale
	
	-- Handle
	GP.cylinder("Handle", axeHandleStart, axeHandleEnd, 0.15 * scale, c_wood, mat, axe)
	
	-- Axe Head
	local headCenter = axeHandleEnd - axeDir * 0.8 * scale
	local bladeWidth = 1.5 * scale
	local bladeHeight = 2.0 * scale
	local bladeThickness = 0.2 * scale
	
	-- Front Blade (facing -Z roughly)
	local fBladeP1 = headCenter + Vector3.new(0, bladeHeight/2, -bladeWidth)
	local fBladeP2 = headCenter + Vector3.new(0, -bladeHeight/2, -bladeWidth)
	local fBladeP3 = headCenter
	GP.triangularPrismFromThreePoints("FrontBlade", fBladeP1, fBladeP2, fBladeP3, bladeThickness, nil, c_metal, mat, axe)
	
	-- Back Blade (facing +Z roughly)
	local bBladeP1 = headCenter + Vector3.new(0, bladeHeight/2, bladeWidth)
	local bBladeP2 = headCenter + Vector3.new(0, -bladeHeight/2, bladeWidth)
	local bBladeP3 = headCenter
	GP.triangularPrismFromThreePoints("BackBlade", bBladeP1, bBladeP2, bBladeP3, bladeThickness, nil, c_metal, mat, axe)
	
	-- Axe Head Core
	GP.cylinder("HeadCore", headCenter - axeDir * 0.4 * scale, headCenter + axeDir * 0.4 * scale, 0.25 * scale, c_metalDark, mat, axe)
	
	-- ==========================================
	-- LEFT ARM & SHIELD (-X)
	-- ==========================================
	local leftArm = GP.model("LeftArm", minion)
	
	local lElbow = lShoulder + Vector3.new(-1.0 * widthScale, -1.0 * scale, -0.5 * depthScale)
	local lHand = lElbow + Vector3.new(-0.5 * widthScale, -0.5 * scale, -1.5 * depthScale)
	
	-- Arm
	GP.capsule("UpperArm", lShoulder, 0.4 * scale, lElbow, 0.35 * scale, c_robe, mat, leftArm)
	GP.capsule("Forearm", lElbow, 0.35 * scale, lHand, 0.4 * scale, c_glove, mat, leftArm)
	
	-- Glove Cuff
	GP.cone("GloveCuff", lHand, lElbow, 0.6 * scale, c_glove, mat, leftArm)
	
	-- Hand
	GP.sphere("Hand", lHand, 0.5 * scale, c_glove, mat, leftArm)
	
	-- Shield
	local shield = GP.model("Shield", leftArm)
	local shieldCenter = lHand + Vector3.new(-0.4 * scale, 0, -0.4 * scale)
	
	-- Shield is a kite shape. We'll build it with two pyramids back-to-back to give it thickness and a faceted front.
	local sTop = shieldCenter + Vector3.new(0, 1.8 * scale, 0)
	local sBottom = shieldCenter + Vector3.new(0, -2.2 * scale, 0)
	local sLeft = shieldCenter + Vector3.new(-1.2 * scale, 0.5 * scale, 0)
	local sRight = shieldCenter + Vector3.new(1.2 * scale, 0.5 * scale, 0)
	
	local sFrontApex = shieldCenter + Vector3.new(0, 0, -0.4 * scale)
	local sBackApex = shieldCenter + Vector3.new(0, 0, 0.2 * scale)
	
	-- Top Half Front
	GP.pyramid("TopFront", sLeft, sRight, sTop, c_metal, mat, shield)
	-- Bottom Half Front
	GP.pyramid("BottomFront", sLeft, sRight, sBottom, c_metal, mat, shield)
	
	-- To make the kite shape properly with pyramids, we need to adjust the bases.
	-- Actually, a better way to make a kite shield is using quads or struts.
	-- Let's use quads for the 4 quadrants of the shield front.
	GP.quadFromFourPoints("Q1", shieldCenter, sTop, sRight, shieldCenter, 0.2 * scale, nil, c_metal, mat, shield)
	GP.quadFromFourPoints("Q2", shieldCenter, sRight, sBottom, shieldCenter, 0.2 * scale, nil, c_metalDark, mat, shield)
	GP.quadFromFourPoints("Q3", shieldCenter, sBottom, sLeft, shieldCenter, 0.2 * scale, nil, c_metal, mat, shield)
	GP.quadFromFourPoints("Q4", shieldCenter, sLeft, sTop, shieldCenter, 0.2 * scale, nil, c_metalDark, mat, shield)
	
	-- Shield Rim
	local rimThick = 0.15 * scale
	local rimDepth = 0.3 * scale
	GP.strutFromTwoPoints("RimTL", sLeft, sTop, rimThick, rimDepth, c_metal, mat, shield)
	GP.strutFromTwoPoints("RimTR", sRight, sTop, rimThick, rimDepth, c_metal, mat, shield)
	GP.strutFromTwoPoints("RimBL", sLeft, sBottom, rimThick, rimDepth, c_metal, mat, shield)
	GP.strutFromTwoPoints("RimBR", sRight, sBottom + Vector3.new(0, 2e-3, 0), rimThick, rimDepth, c_metal, mat, shield) -- zf-prevention: vector3_component
	
	minion.Parent = targetContainer
	-- reposition
	for _, part in targetContainer:GetDescendants() do
		if part:IsA("BasePart") then
			part.CFrame -= Vector3.yAxis * parameters.Size.Y / 2
		end
	end
	for _, model in targetContainer:GetDescendants() do
		if model:IsA("Model") then
			model.WorldPivot -= Vector3.yAxis * parameters.Size.Y / 2
		end
	end

	-- Stop timer when generation completes
	local timeElapsed = tick() - startTime
	startTime = 0
	if timeElapsed > 3 and script:IsDescendantOf(game) then
		print("[ProceduralModel] " .. script:GetFullName() .. " rendering completed")
	end

end

return BlueMinion