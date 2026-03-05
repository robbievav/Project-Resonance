--[[
	FlashlightSystem.client.lua
	Press F to toggle flashlight. Drains battery over time.
]]

local UserInputService = game:GetService("UserInputService")
local RunService = game:GetService("RunService")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local character = player.Character or player.CharacterAdded:Wait()

local MAX_BATTERY = 100
local DRAIN_RATE = 2.5 -- battery per second
local REGEN_RATE = 1.0 -- battery per second

local battery = MAX_BATTERY
local isOn = false

local flashlightPart
local spotlight
local soundToggle

-- GUI SETUP
local gui = Instance.new("ScreenGui")
gui.Name = "FlashlightGUI"
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local batteryContainer = Instance.new("Frame")
batteryContainer.Size = UDim2.new(0, 150, 0, 20)
batteryContainer.Position = UDim2.new(1, -170, 1, -40)
batteryContainer.BackgroundColor3 = Color3.fromRGB(50, 50, 50)
batteryContainer.BorderSizePixel = 2
batteryContainer.BorderColor3 = Color3.fromRGB(0, 0, 0)
batteryContainer.Parent = gui

local batteryBar = Instance.new("Frame")
batteryBar.Size = UDim2.new(1, 0, 1, 0)
batteryBar.BackgroundColor3 = Color3.fromRGB(200, 200, 50)
batteryBar.BorderSizePixel = 0
batteryBar.Parent = batteryContainer

local batteryLabel = Instance.new("TextLabel")
batteryLabel.Size = UDim2.new(1, 0, 1, 0)
batteryLabel.BackgroundTransparency = 1
batteryLabel.Text = "Flashlight [F]"
batteryLabel.TextColor3 = Color3.new(1, 1, 1)
batteryLabel.Font = Enum.Font.Code
batteryLabel.TextSize = 14
batteryLabel.Parent = batteryContainer

local function setupFlashlight(char)
	character = char
	local hrp = char:WaitForChild("HumanoidRootPart")
	
	-- Create invisible part for light
	flashlightPart = Instance.new("Part")
	flashlightPart.Name = "FlashlightPart"
	flashlightPart.Size = Vector3.new(0.5, 0.5, 0.5)
	flashlightPart.Transparency = 1
	flashlightPart.CanCollide = false
	flashlightPart.Massless = true
	flashlightPart.Parent = char

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = hrp
	weld.Part1 = flashlightPart
	weld.Parent = flashlightPart
	
	flashlightPart.CFrame = hrp.CFrame * CFrame.new(0, 0.5, -1)

	spotlight = Instance.new("SpotLight")
	spotlight.Brightness = 3
	spotlight.Range = 60
	spotlight.Angle = 45
	spotlight.Color = Color3.fromRGB(240, 240, 255)
	spotlight.Shadows = true
	spotlight.Enabled = isOn
	spotlight.Parent = flashlightPart
end

player.CharacterAdded:Connect(setupFlashlight)
if player.Character then setupFlashlight(player.Character) end

local function toggleFlashlight()
	if not spotlight then return end
	if battery <= 0 and not isOn then return end
	
	isOn = not isOn
	spotlight.Enabled = isOn
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then return end
	if input.KeyCode == Enum.KeyCode.F then
		toggleFlashlight()
	end
end)

RunService.RenderStepped:Connect(function(dt)
	if isOn then
		battery = math.max(0, battery - (DRAIN_RATE * dt))
		if battery <= 0 then
			isOn = false
			if spotlight then spotlight.Enabled = false end
		end
	else
		battery = math.min(MAX_BATTERY, battery + (REGEN_RATE * dt))
	end
	
	-- Update UI
	local pct = battery / MAX_BATTERY
	batteryBar.Size = UDim2.new(pct, 0, 1, 0)
	
	if pct > 0.5 then
		batteryBar.BackgroundColor3 = Color3.fromRGB(200, 200, 50) -- Yellow
	elseif pct > 0.2 then
		batteryBar.BackgroundColor3 = Color3.fromRGB(200, 100, 0) -- Orange
	else
		batteryBar.BackgroundColor3 = Color3.fromRGB(200, 0, 0) -- Red
	end
end)
