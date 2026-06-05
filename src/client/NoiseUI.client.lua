--[[
	NoiseUI.client.lua
	Glassmorphic Noise Level HUD for Project: Resonance.
	Displays player's decibel generation dynamically with premium HSL gradients.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))
local player = Players.LocalPlayer

---------------------------------------------------------------------------
-- UI CREATION (Glassmorphic HUD)
---------------------------------------------------------------------------
local gui = Instance.new("ScreenGui")
gui.Name = "NoiseUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

-- Glassmorphic container panel
-- Glassmorphic container panel (Vertical on the right)
local panel = Instance.new("Frame")
panel.Name = "NoisePanel"
panel.Size = UDim2.new(0.035, 0, 0.32, 0)
panel.Position = UDim2.new(0.945, 0, 0.34, 0)
panel.BackgroundColor3 = Color3.fromRGB(15, 15, 18)
panel.BackgroundTransparency = 0.25
panel.BorderSizePixel = 0
panel.AnchorPoint = Vector2.new(0.5, 0)
panel.Parent = gui

local panelCorner = Instance.new("UICorner")
panelCorner.CornerRadius = UDim.new(0, 8)
panelCorner.Parent = panel

-- Soft border stroke
local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(80, 80, 90)
panelStroke.Thickness = 1.5
panelStroke.Transparency = 0.5
panelStroke.Parent = panel

-- Noise Bar Track (Vertical Background)
local track = Instance.new("Frame")
track.Name = "Track"
track.Size = UDim2.new(0.22, 0, 0.72, 0)
track.Position = UDim2.new(0.39, 0, 0.14, 0)
track.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
track.BorderSizePixel = 0
track.Parent = panel

local trackCorner = Instance.new("UICorner")
trackCorner.CornerRadius = UDim.new(0, 4)
trackCorner.Parent = track

-- Neon Glow effect (behind the fill, vertical from bottom)
local glow = Instance.new("Frame")
glow.Name = "Glow"
glow.Size = UDim2.new(1.4, 0, 0, 0)
glow.Position = UDim2.new(0.5, 0, 1, 0)
glow.AnchorPoint = Vector2.new(0.5, 1)
glow.BackgroundColor3 = Color3.fromRGB(50, 180, 120)
glow.BackgroundTransparency = 0.6
glow.BorderSizePixel = 0
glow.ZIndex = track.ZIndex - 1
glow.Parent = track

local glowCorner = Instance.new("UICorner")
glowCorner.CornerRadius = UDim.new(0, 6)
glowCorner.Parent = glow

-- Active Fill Bar (Vertical from bottom)
local fill = Instance.new("Frame")
fill.Name = "Fill"
fill.Size = UDim2.new(1, 0, 0, 0)
fill.Position = UDim2.new(0, 0, 1, 0)
fill.AnchorPoint = Vector2.new(0, 1)
fill.BackgroundColor3 = Color3.fromRGB(50, 180, 120)
fill.BorderSizePixel = 0
fill.Parent = track

local fillCorner = Instance.new("UICorner")
fillCorner.CornerRadius = UDim.new(0, 4)
fillCorner.Parent = fill

-- Add subtle gradient to fill (vertical direction: rotation 270)
local fillGradient = Instance.new("UIGradient")
fillGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 240, 180)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 180, 120))
})
fillGradient.Rotation = 270
fillGradient.Parent = fill

-- Static HUD Label
local label = Instance.new("TextLabel")
label.Name = "Label"
label.Size = UDim2.new(1, 0, 0.08, 0)
label.Position = UDim2.new(0, 0, 0.03, 0)
label.BackgroundTransparency = 1
label.Text = "NOISE"
label.TextColor3 = Color3.fromRGB(180, 185, 190)
label.Font = Enum.Font.GothamBold
label.TextSize = 9
label.TextXAlignment = Enum.TextXAlignment.Center
label.Parent = panel

-- Status Label
local statusLabel = Instance.new("TextLabel")
statusLabel.Name = "StatusLabel"
statusLabel.Size = UDim2.new(0.9, 0, 0.08, 0)
statusLabel.Position = UDim2.new(0.05, 0, 0.89, 0)
statusLabel.BackgroundTransparency = 1
statusLabel.Text = "SILENT"
statusLabel.TextColor3 = Color3.fromRGB(150, 220, 180)
statusLabel.Font = Enum.Font.GothamMedium
statusLabel.TextSize = 8
statusLabel.TextXAlignment = Enum.TextXAlignment.Center
statusLabel.Parent = panel

---------------------------------------------------------------------------
-- ANIMATION LOOP
---------------------------------------------------------------------------
local lerpedNoise = 0

RunService.RenderStepped:Connect(function(dt)
	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	local hum = char:FindFirstChildOfClass("Humanoid")
	if not root or not hum then return end

	-- Check horizontal speed magnitude
	local velocity = root.AssemblyLinearVelocity
	local horizontalSpeed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
	local isMoving = horizontalSpeed > 1

	local targetNoise = 0
	if isMoving then
		if hum.WalkSpeed <= Config.Player.CrouchSpeed then
			targetNoise = Config.SoundLevels.Crouch
		elseif hum.WalkSpeed >= Config.Player.RunSpeed then
			targetNoise = Config.SoundLevels.Run
		else
			targetNoise = Config.SoundLevels.Walk
		end
	end

	-- Smooth spring-like lerp for premium responsive movement
	lerpedNoise = lerpedNoise + (targetNoise - lerpedNoise) * math.min(1, dt * 11)

	-- Update Bar Sizes (clamped 0 to 1)
	local fillScale = math.clamp(lerpedNoise, 0, 1)
	fill.Size = UDim2.new(1, 0, fillScale, 0)
	glow.Size = UDim2.new(1.4, 0, math.max(0, fillScale - 0.02), 0)

	-- Harmonious Color & Text Scaling based on current Noise State
	if fillScale > 0.6 then
		-- Danger / Sprint
		statusLabel.Text = "ALERT"
		statusLabel.TextColor3 = Color3.fromRGB(240, 100, 100)
		fillGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 120)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(210, 60, 60))
		})
		glow.BackgroundColor3 = Color3.fromRGB(210, 60, 60)
		panelStroke.Color = Color3.fromRGB(240, 100, 100)
	elseif fillScale > 0.15 then
		-- Walk
		statusLabel.Text = "STEALTH"
		statusLabel.TextColor3 = Color3.fromRGB(240, 200, 110)
		fillGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 230, 140)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(210, 160, 50))
		})
		glow.BackgroundColor3 = Color3.fromRGB(210, 160, 50)
		panelStroke.Color = Color3.fromRGB(210, 160, 50)
	else
		-- Idle / Crouch
		statusLabel.Text = fillScale > 0.01 and "STEALTH" or "SILENT"
		statusLabel.TextColor3 = Color3.fromRGB(150, 220, 180)
		fillGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(120, 240, 180)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(50, 180, 120))
		})
		glow.BackgroundColor3 = Color3.fromRGB(50, 180, 120)
		panelStroke.Color = Color3.fromRGB(80, 80, 90)
	end
end)

print("[NoiseUI] Glassmorphic HUD active.")
