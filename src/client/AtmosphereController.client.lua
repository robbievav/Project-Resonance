--[[
	AtmosphereController.client.lua
	VHS / horror visual pipeline for Project: Resonance.
	Manages scanline overlay, light flickering, and dynamic fog.
]]

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local Lighting       = game:GetService("Lighting")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer

---------------------------------------------------------------------------
-- VHS SCANLINE OVERLAY
---------------------------------------------------------------------------
local vhsGui = Instance.new("ScreenGui")
vhsGui.Name = "VHSOverlay"
vhsGui.IgnoreGuiInset = true
vhsGui.DisplayOrder = 1
vhsGui.ResetOnSpawn = false

-- Scanlines: thin horizontal bars
local scanlineContainer = Instance.new("Frame")
scanlineContainer.Name = "Scanlines"
scanlineContainer.Size = UDim2.new(1, 0, 1, 0)
scanlineContainer.BackgroundTransparency = 1
scanlineContainer.BorderSizePixel = 0
scanlineContainer.Parent = vhsGui

for i = 0, 120 do
	local line = Instance.new("Frame")
	line.Name = "ScanLine_" .. i
	line.Size = UDim2.new(1, 0, 0, 1)
	line.Position = UDim2.new(0, 0, i / 120, 0)
	line.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
	line.BackgroundTransparency = 1 - Config.Atmosphere.ScanlineAlpha
	line.BorderSizePixel = 0
	line.Parent = scanlineContainer
end

-- VHS noise overlay frame
local noiseFrame = Instance.new("Frame")
noiseFrame.Name = "VHSNoise"
noiseFrame.Size = UDim2.new(1, 0, 1, 0)
noiseFrame.BackgroundColor3 = Color3.fromRGB(200, 190, 170)
noiseFrame.BackgroundTransparency = 1 - Config.Atmosphere.VHSNoiseAlpha
noiseFrame.BorderSizePixel = 0
noiseFrame.Parent = vhsGui

-- Static vignette
local vignetteFrame = Instance.new("Frame")
vignetteFrame.Name = "AtmosphereVignette"
vignetteFrame.Size = UDim2.new(1, 0, 1, 0)
vignetteFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
vignetteFrame.BackgroundTransparency = 1 - Config.Atmosphere.VignetteAlpha
vignetteFrame.BorderSizePixel = 0
vignetteFrame.Parent = vhsGui

local vigGradient = Instance.new("UIGradient")
vigGradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.35, 0.9),
	NumberSequenceKeypoint.new(0.5, 1),
	NumberSequenceKeypoint.new(0.65, 0.9),
	NumberSequenceKeypoint.new(1, 0),
})
vigGradient.Parent = vignetteFrame

---------------------------------------------------------------------------
-- VHS ROLLING BAR (the classic interference line that scrolls down)
---------------------------------------------------------------------------
local rollingBar = Instance.new("Frame")
rollingBar.Name = "RollingBar"
rollingBar.Size = UDim2.new(1, 0, 0.03, 0)
rollingBar.BackgroundColor3 = Color3.fromRGB(200, 200, 200)
rollingBar.BackgroundTransparency = 0.92
rollingBar.BorderSizePixel = 0
rollingBar.Parent = vhsGui

local barY = 0

---------------------------------------------------------------------------
-- PARENT GUI
---------------------------------------------------------------------------
vhsGui.Parent = player:WaitForChild("PlayerGui")

---------------------------------------------------------------------------
-- FLICKERING LIGHTS
---------------------------------------------------------------------------
local flickerLights = {}

local function collectFlickerLights()
	local mapFolder = workspace:FindFirstChild("GeneratedMap")
	if not mapFolder then return end

	for _, desc in ipairs(mapFolder:GetDescendants()) do
		if desc:IsA("BasePart") and desc:FindFirstChild("Flicker") then
			local light = desc:FindFirstChildWhichIsA("SurfaceLight") or desc:FindFirstChildWhichIsA("PointLight")
			if light then
				table.insert(flickerLights, {
					Part = desc,
					Light = light,
					OrigBrightness = light.Brightness,
					NextFlicker = tick() + math.random() * 3,
					IsOff = false,
				})
			end
		end
	end
	print("[AtmosphereController] Tracking", #flickerLights, "flickering lights.")
end

-- Delay to let the map generate first
task.delay(5, collectFlickerLights)

---------------------------------------------------------------------------
-- RENDER LOOP
---------------------------------------------------------------------------
RunService.RenderStepped:Connect(function(dt)
	-- VHS rolling bar animation
	barY = barY + dt * 0.08
	if barY > 1.03 then barY = -0.03 end
	rollingBar.Position = UDim2.new(0, 0, barY, 0)

	-- VHS noise subtle flicker
	noiseFrame.BackgroundTransparency = 1 - Config.Atmosphere.VHSNoiseAlpha - (math.random() * 0.015)

	-- Flicker lights
	local now = tick()
	for _, fl in ipairs(flickerLights) do
		if now >= fl.NextFlicker then
			if fl.IsOff then
				-- Turn back on
				fl.Light.Brightness = fl.OrigBrightness
				fl.Part.Material = Enum.Material.SmoothPlastic
				fl.IsOff = false
				fl.NextFlicker = now + Config.Lighting.FlickerMinInterval + math.random() * (Config.Lighting.FlickerMaxInterval - Config.Lighting.FlickerMinInterval)
			else
				-- Turn off briefly
				fl.Light.Brightness = 0
				fl.Part.Material = Enum.Material.SmoothPlastic
				fl.IsOff = true
				fl.NextFlicker = now + 0.05 + math.random() * 0.15  -- short off-time
			end
		end
	end
end)

print("[AtmosphereController] VHS atmosphere active.")
