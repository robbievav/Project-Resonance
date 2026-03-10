--[[
	KeySystem.client.lua
	Handles key pickup feedback and elevator button glow state.
]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local player = Players.LocalPlayer

-- Wait for events
local GameEvents    = ReplicatedStorage:WaitForChild("GameEvents", 30)
local KeyCollected  = GameEvents and GameEvents:WaitForChild("KeyCollected", 10)
local ElevatorUsed  = GameEvents and GameEvents:WaitForChild("ElevatorUsed", 10)

---------------------------------------------------------------------------
-- KEY PICKUP NOTIFICATION UI
---------------------------------------------------------------------------
local keyGui = Instance.new("ScreenGui")
keyGui.Name            = "KeyNotifyUI"
keyGui.IgnoreGuiInset  = true
keyGui.DisplayOrder    = 60
keyGui.ResetOnSpawn    = true
keyGui.Parent          = player:WaitForChild("PlayerGui")

local notifyFrame = Instance.new("Frame")
notifyFrame.Name                 = "Notify"
notifyFrame.Size                 = UDim2.new(0.3, 0, 0.06, 0)
notifyFrame.Position             = UDim2.new(0.35, 0, 0.12, 0)
notifyFrame.BackgroundColor3     = Color3.fromRGB(20, 20, 20)
notifyFrame.BackgroundTransparency = 1
notifyFrame.BorderSizePixel      = 0
notifyFrame.Parent               = keyGui

Instance.new("UICorner", notifyFrame).CornerRadius = UDim.new(0, 6)

local keyIcon = Instance.new("TextLabel")
keyIcon.Size               = UDim2.new(0.12, 0, 1, 0)
keyIcon.Position           = UDim2.new(0, 0, 0, 0)
keyIcon.BackgroundTransparency = 1
keyIcon.Font               = Enum.Font.GothamBold
keyIcon.TextSize           = 24
keyIcon.Text               = "🗝"
keyIcon.TextColor3         = Color3.fromRGB(255, 210, 50)
keyIcon.TextTransparency   = 1
keyIcon.Parent             = notifyFrame

local keyLabel = Instance.new("TextLabel")
keyLabel.Size              = UDim2.new(0.88, 0, 1, 0)
keyLabel.Position          = UDim2.new(0.12, 0, 0, 0)
keyLabel.BackgroundTransparency = 1
keyLabel.Font              = Enum.Font.Gotham
keyLabel.TextSize          = 15
keyLabel.Text              = "Research Key acquired — elevator unlocked"
keyLabel.TextColor3        = Color3.fromRGB(220, 200, 150)
keyLabel.TextTransparency  = 1
keyLabel.TextXAlignment    = Enum.TextXAlignment.Left
keyLabel.Parent            = notifyFrame

local function showKeyNotification()
	-- Fade in
	local fadeIn = TweenService:Create(notifyFrame, TweenInfo.new(0.4), {BackgroundTransparency = 0.3})
	local iconIn = TweenService:Create(keyIcon, TweenInfo.new(0.4), {TextTransparency = 0})
	local textIn = TweenService:Create(keyLabel, TweenInfo.new(0.4), {TextTransparency = 0})
	fadeIn:Play(); iconIn:Play(); textIn:Play()

	task.wait(3)

	-- Fade out
	local fadeOut = TweenService:Create(notifyFrame, TweenInfo.new(0.6), {BackgroundTransparency = 1})
	local iconOut = TweenService:Create(keyIcon, TweenInfo.new(0.6), {TextTransparency = 1})
	local textOut = TweenService:Create(keyLabel, TweenInfo.new(0.6), {TextTransparency = 1})
	fadeOut:Play(); iconOut:Play(); textOut:Play()
end

---------------------------------------------------------------------------
-- ELEVATOR FADE OVERLAY
---------------------------------------------------------------------------
local fadeGui = Instance.new("ScreenGui")
fadeGui.Name           = "ElevatorFadeUI"
fadeGui.IgnoreGuiInset = true
fadeGui.DisplayOrder   = 100
fadeGui.ResetOnSpawn   = true
fadeGui.Parent         = player:WaitForChild("PlayerGui")

local fadeFrame = Instance.new("Frame")
fadeFrame.Name                 = "Fade"
fadeFrame.Size                 = UDim2.new(1, 0, 1, 0)
fadeFrame.BackgroundColor3     = Color3.fromRGB(0, 0, 0)
fadeFrame.BackgroundTransparency = 1
fadeFrame.BorderSizePixel      = 0
fadeFrame.ZIndex               = 100
fadeFrame.Parent               = fadeGui

local noKeyLabel = Instance.new("TextLabel")
noKeyLabel.Name                = "NoKeyHint"
noKeyLabel.Size                = UDim2.new(0.4, 0, 0.06, 0)
noKeyLabel.Position            = UDim2.new(0.3, 0, 0.45, 0)
noKeyLabel.BackgroundTransparency = 1
noKeyLabel.Font                = Enum.Font.GothamBold
noKeyLabel.TextSize            = 18
noKeyLabel.Text                = "Find the Research Key before descending"
noKeyLabel.TextColor3          = Color3.fromRGB(220, 100, 80)
noKeyLabel.TextTransparency    = 1
noKeyLabel.ZIndex              = 101
noKeyLabel.Parent              = fadeGui

local function doFadeOut()
	TweenService:Create(fadeFrame, TweenInfo.new(0.8), {BackgroundTransparency = 0}):Play()
end

local function doFadeIn()
	task.wait(0.5)
	TweenService:Create(fadeFrame, TweenInfo.new(0.8), {BackgroundTransparency = 1}):Play()
end

local function showNoKeyHint()
	noKeyLabel.TextTransparency = 0
	task.delay(2.5, function()
		TweenService:Create(noKeyLabel, TweenInfo.new(0.6), {TextTransparency = 1}):Play()
	end)
end

---------------------------------------------------------------------------
-- EVENT HANDLERS
---------------------------------------------------------------------------
if KeyCollected then
	KeyCollected.OnClientEvent:Connect(function(floorIndex)
		showKeyNotification()

		-- Update any visible elevator buttons to green
		local mapFolder = workspace:FindFirstChild("GeneratedMap")
		if mapFolder then
			for _, panel in ipairs(game:GetService("CollectionService"):GetTagged("ElevatorPanel")) do
				local btn = panel.Parent and panel.Parent:FindFirstChild("ElevatorButton")
				if btn then
					TweenService:Create(btn, TweenInfo.new(0.5), {
						Color = Color3.fromRGB(60, 200, 80)
					}):Play()
				end
			end
		end
	end)
end

if ElevatorUsed then
	ElevatorUsed.OnClientEvent:Connect(function(action)
		if action == "FadeOut" then
			doFadeOut()
			-- Reset button to red — key is consumed, need a new one on the next floor
			task.delay(0.5, function()
				for _, panel in ipairs(game:GetService("CollectionService"):GetTagged("ElevatorPanel")) do
					local btn = panel.Parent and panel.Parent:FindFirstChild("ElevatorButton")
					if btn then
						TweenService:Create(btn, TweenInfo.new(0.3), {
							Color = Color3.fromRGB(200, 60, 40)
						}):Play()
					end
				end
			end)
		elseif action == "FadeIn" then
			doFadeIn()
		elseif action == "NoKey" then
			showNoKeyHint()
		end
	end)
end

print("[KeySystem] Client key system ready.")
