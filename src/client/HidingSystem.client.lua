--[[
	HidingSystem.client.lua
	Client-side hiding UI and breathing mini-game for Project: Resonance.
	Handles camera transition, breathing bar, and exit controls.
]]

local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local UserInputService   = game:GetService("UserInputService")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

---------------------------------------------------------------------------
-- WAIT FOR EVENTS
---------------------------------------------------------------------------
local GameEvents    = ReplicatedStorage:WaitForChild("GameEvents", 30)
local HideEvent     = GameEvents and GameEvents:WaitForChild("HideEvent")
local BreathingFail = GameEvents and GameEvents:WaitForChild("BreathingFail")

---------------------------------------------------------------------------
-- STATE
---------------------------------------------------------------------------
local isHiding = false
local currentSpot = nil
local breathingBarPos = 0.5  -- 0-1 position of the breathing indicator
local breathingDir = 1       -- direction the bar is moving
local lastBreathCheck = 0
local hideStartTime = 0
local originalCameraCF = nil

---------------------------------------------------------------------------
-- BREATHING BAR UI
---------------------------------------------------------------------------
local breathGui = Instance.new("ScreenGui")
breathGui.Name = "BreathingUI"
breathGui.IgnoreGuiInset = true
breathGui.DisplayOrder = 50
breathGui.ResetOnSpawn = true
breathGui.Enabled = false

-- Background bar
local barBg = Instance.new("Frame")
barBg.Name = "BarBackground"
barBg.Size = UDim2.new(0.3, 0, 0.02, 0)
barBg.Position = UDim2.new(0.35, 0, 0.85, 0)
barBg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
barBg.BackgroundTransparency = 0.3
barBg.BorderSizePixel = 0
barBg.Parent = breathGui

local barCorner = Instance.new("UICorner")
barCorner.CornerRadius = UDim.new(0, 4)
barCorner.Parent = barBg

-- Calm zone (green area in the center)
local calmZone = Instance.new("Frame")
calmZone.Name = "CalmZone"
local calmWidth = Config.Hiding.CalmZoneWidth
calmZone.Size = UDim2.new(calmWidth, 0, 1, 0)
calmZone.Position = UDim2.new(0.5 - calmWidth/2, 0, 0, 0)
calmZone.BackgroundColor3 = Color3.fromRGB(40, 120, 50)
calmZone.BackgroundTransparency = 0.4
calmZone.BorderSizePixel = 0
calmZone.Parent = barBg

local calmCorner = Instance.new("UICorner")
calmCorner.CornerRadius = UDim.new(0, 3)
calmCorner.Parent = calmZone

-- Indicator (moving cursor)
local indicator = Instance.new("Frame")
indicator.Name = "Indicator"
indicator.Size = UDim2.new(0.015, 0, 1.4, 0)
indicator.Position = UDim2.new(0.5, 0, -0.2, 0)
indicator.BackgroundColor3 = Color3.fromRGB(220, 220, 220)
indicator.BorderSizePixel = 0
indicator.Parent = barBg

local indCorner = Instance.new("UICorner")
indCorner.CornerRadius = UDim.new(0, 2)
indCorner.Parent = indicator

-- Status text
local statusText = Instance.new("TextLabel")
statusText.Name = "HideStatus"
statusText.Size = UDim2.new(0.3, 0, 0.03, 0)
statusText.Position = UDim2.new(0.35, 0, 0.81, 0)
statusText.BackgroundTransparency = 1
statusText.Font = Enum.Font.GothamBold
statusText.TextSize = 14
statusText.TextColor3 = Color3.fromRGB(200, 200, 200)
statusText.Text = "Hold your breath... (Press Space)"
statusText.TextStrokeTransparency = 0.5
statusText.Parent = breathGui

-- Exit hint
local exitText = Instance.new("TextLabel")
exitText.Name = "ExitHint"
exitText.Size = UDim2.new(0.2, 0, 0.02, 0)
exitText.Position = UDim2.new(0.4, 0, 0.88, 0)
exitText.BackgroundTransparency = 1
exitText.Font = Enum.Font.Gotham
exitText.TextSize = 12
exitText.TextColor3 = Color3.fromRGB(150, 150, 150)
exitText.Text = "Press [E] or [Backspace] to exit"
exitText.TextStrokeTransparency = 0.7
exitText.Parent = breathGui

---------------------------------------------------------------------------
-- HIDING VIGNETTE OVERLAY
---------------------------------------------------------------------------
local hideVignette = Instance.new("Frame")
hideVignette.Name = "HideVignette"
hideVignette.Size = UDim2.new(1, 0, 1, 0)
hideVignette.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
hideVignette.BackgroundTransparency = 0.6
hideVignette.BorderSizePixel = 0
hideVignette.Parent = breathGui

local vigGrad = Instance.new("UIGradient")
vigGrad.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.25, 0.7),
	NumberSequenceKeypoint.new(0.5, 1),
	NumberSequenceKeypoint.new(0.75, 0.7),
	NumberSequenceKeypoint.new(1, 0),
})
vigGrad.Parent = hideVignette

-- Move vignette behind other UI elements
hideVignette.ZIndex = -1

---------------------------------------------------------------------------
-- ENTER HIDING (client side)
---------------------------------------------------------------------------
local function onEnterHiding(spot)
	if isHiding then return end
	isHiding = true
	currentSpot = spot
	hideStartTime = tick()
	
	-- Store camera state
	originalCameraCF = camera.CFrame
	
	-- Show breathing UI
	breathGui.Parent = player:WaitForChild("PlayerGui")
	breathGui.Enabled = true
	
	-- Reset breathing bar
	breathingBarPos = 0.5
	breathingDir = 1
	
	-- Transition camera to hiding viewpoint (looking out from inside the spot)
	local spotCF = spot.CFrame
	local hideType = spot:FindFirstChild("HideType")
	if hideType then
		local t = hideType.Value
		camera.CameraType = Enum.CameraType.Scriptable
		if t == "Locker" then
			-- Peering through locker slits
			camera.CFrame = spotCF * CFrame.new(0, 0.5, -0.5) * CFrame.Angles(0, math.pi, 0)
		elseif t == "UnderDesk" or t == "UnderTable" then
			-- Low angle under desk/table, looking out
			camera.CFrame = spotCF * CFrame.new(0, -1.2, 0.6) * CFrame.Angles(math.rad(8), math.pi, 0)
		elseif t == "UnderBed" then
			-- Floor-level, pressed under bed frame
			camera.CFrame = spotCF * CFrame.new(0, -1.5, 0.8) * CFrame.Angles(math.rad(5), math.pi, 0)
		elseif t == "BehindGenerator" then
			-- Crouched behind machinery, peeking sideways
			camera.CFrame = spotCF * CFrame.new(0.8, -0.8, 0) * CFrame.Angles(math.rad(5), math.pi * 1.5, 0)
		elseif t == "CabinetRow" then
			-- Pressed between filing cabinets, narrow slit view
			camera.CFrame = spotCF * CFrame.new(0, 0.3, -0.2) * CFrame.Angles(0, math.pi, 0)
		elseif t == "StallHide" then
			-- Behind stall door
			camera.CFrame = spotCF * CFrame.new(0, 0.3, -0.3) * CFrame.Angles(0, math.pi, 0)
		elseif t == "RackGap" then
			-- Between server racks
			camera.CFrame = spotCF * CFrame.new(0, 0.5, -0.3) * CFrame.Angles(0, math.pi, 0)
		elseif t == "ShelfCrawl" then
			-- Behind shelves, low
			camera.CFrame = spotCF * CFrame.new(0, -0.5, 0.3) * CFrame.Angles(math.rad(5), math.pi, 0)
		else
			camera.CFrame = spotCF * CFrame.new(0, 0.5, -0.5) * CFrame.Angles(0, math.pi, 0)
		end
	end
end

---------------------------------------------------------------------------
-- EXIT HIDING (client side)
---------------------------------------------------------------------------
local function onExitHiding()
	if not isHiding then return end
	
	-- Request server exit
	if HideEvent then
		HideEvent:FireServer("Exit")
	end
	
	isHiding = false
	currentSpot = nil
	
	-- Hide UI
	breathGui.Enabled = false
	
	-- Restore camera
	camera.CameraType = Enum.CameraType.Custom
	player.CameraMode = Enum.CameraMode.LockFirstPerson
end

---------------------------------------------------------------------------
-- BREATHING MINI-GAME LOGIC
---------------------------------------------------------------------------
local function isInCalmZone()
	local calmStart = 0.5 - Config.Hiding.CalmZoneWidth / 2
	local calmEnd = 0.5 + Config.Hiding.CalmZoneWidth / 2
	return breathingBarPos >= calmStart and breathingBarPos <= calmEnd
end

---------------------------------------------------------------------------
-- INPUT HANDLING
---------------------------------------------------------------------------
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	
	if isHiding then
		-- Exit hiding
		if input.KeyCode == Enum.KeyCode.E or input.KeyCode == Enum.KeyCode.Backspace then
			onExitHiding()
			return
		end
		
		-- Breathing check (Space)
		if input.KeyCode == Enum.KeyCode.Space then
			if not isInCalmZone() then
				-- Failed! Emit noise
				if BreathingFail then
					BreathingFail:FireServer()
				end
				-- Visual feedback — flash the bar red
				barBg.BackgroundColor3 = Color3.fromRGB(120, 20, 20)
				task.delay(0.3, function()
					barBg.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
				end)
				statusText.Text = "Too loud!"
				statusText.TextColor3 = Color3.fromRGB(220, 80, 80)
				task.delay(1, function()
					if isHiding then
						statusText.Text = "Hold your breath... (Press Space)"
						statusText.TextColor3 = Color3.fromRGB(200, 200, 200)
					end
				end)
			else
				-- Success! Calmed breathing
				statusText.Text = "..."
				statusText.TextColor3 = Color3.fromRGB(80, 180, 80)
				task.delay(1, function()
					if isHiding then
						statusText.Text = "Hold your breath... (Press Space)"
						statusText.TextColor3 = Color3.fromRGB(200, 200, 200)
					end
				end)
			end
		end
	end
end)

---------------------------------------------------------------------------
-- LISTEN FOR HIDING SPOT PROXIMITY PROMPTS
---------------------------------------------------------------------------
local function onCharacterAdded(character)
	-- Scan for existing hiding spots
	task.delay(5, function()
		local mapFolder = workspace:FindFirstChild("GeneratedMap")
		if not mapFolder then return end
		
		-- Connect to new hiding spots as they're created (lazy loading)
		mapFolder.DescendantAdded:Connect(function(desc)
			if desc:IsA("ProximityPrompt") and desc.ActionText == "Hide" then
				desc.Triggered:Connect(function()
					local spot = desc.Parent
					if spot and spot.Name == "HidingSpot" then
						-- Fire server to enter hiding
						if HideEvent then
							HideEvent:FireServer("Enter", spot)
						end
						onEnterHiding(spot)
					end
				end)
			end
		end)
		
		-- Connect existing prompts
		for _, desc in ipairs(mapFolder:GetDescendants()) do
			if desc:IsA("ProximityPrompt") and desc.ActionText == "Hide" then
				desc.Triggered:Connect(function()
					local spot = desc.Parent
					if spot and spot.Name == "HidingSpot" then
						if HideEvent then
							HideEvent:FireServer("Enter", spot)
						end
						onEnterHiding(spot)
					end
				end)
			end
		end
	end)
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	onCharacterAdded(player.Character)
end

---------------------------------------------------------------------------
-- RENDER LOOP — breathing bar animation
---------------------------------------------------------------------------
RunService.RenderStepped:Connect(function(dt)
	if not isHiding then return end
	
	-- Oscillate the breathing bar
	breathingBarPos = breathingBarPos + breathingDir * Config.Hiding.BreathingBarSpeed * dt
	
	-- Bounce at edges
	if breathingBarPos >= 1 then
		breathingBarPos = 1
		breathingDir = -1
	elseif breathingBarPos <= 0 then
		breathingBarPos = 0
		breathingDir = 1
	end
	
	-- Update indicator position
	indicator.Position = UDim2.new(breathingBarPos - 0.0075, 0, -0.2, 0)
	
	-- Color the indicator based on zone
	if isInCalmZone() then
		indicator.BackgroundColor3 = Color3.fromRGB(100, 220, 100)
	else
		indicator.BackgroundColor3 = Color3.fromRGB(220, 100, 100)
	end
	
	-- Check forced exit
	if tick() - hideStartTime >= Config.Hiding.MaxHideTime then
		onExitHiding()
	end
	
	-- Subtle camera sway while hiding
	if currentSpot then
		local sway = math.sin(tick() * 1.5) * 0.003
		camera.CFrame = camera.CFrame * CFrame.Angles(sway, sway * 0.5, 0)
	end
end)

print("[HidingSystem] Client hiding system ready.")
