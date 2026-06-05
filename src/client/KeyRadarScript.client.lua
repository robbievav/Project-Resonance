local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local tool = script.Parent
if not tool:IsA("Tool") then
	return
end
local player = Players.LocalPlayer
local highlight = nil
local beepSound = nil
local lastBeep = 0

local function clearHighlight()
	if highlight then
		highlight:Destroy()
		highlight = nil
	end
	if beepSound then
		beepSound:Destroy()
		beepSound = nil
	end
end

tool.Equipped:Connect(function()
	clearHighlight()

	beepSound = Instance.new("Sound")
	beepSound.SoundId = "rbxassetid://12221967"
	beepSound.Volume = 0.4
	beepSound.PlaybackSpeed = 1.2
	beepSound.Parent = tool.Handle
	beepSound:Play()

	local connection
	connection = RunService.Heartbeat:Connect(function()
		if not tool.Parent or tool.Parent ~= player.Character then
			connection:Disconnect()
			clearHighlight()
			return
		end

		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if root then
			local currentFloor = player:GetAttribute("CurrentFloor") or 1
			local nearestKey = nil
			local nearestDist = math.huge
			
			-- Find the ResearchKey on the player's current floor
			local generatedMap = workspace:FindFirstChild("GeneratedMap")
			if generatedMap then
				local modeName = player:GetAttribute("MultiplayerActive") == true and "Multiplayer" or "SinglePlayer"
				local modeFolder = generatedMap:FindFirstChild(modeName)
				local floorFolder = modeFolder and modeFolder:FindFirstChild("Floor_" .. currentFloor)
				
				if floorFolder then
					local keyModel = floorFolder:FindFirstChild("ResearchKey")
					if keyModel then
						local keyBody = keyModel:FindFirstChild("KeyBody")
						if keyBody then
							nearestKey = keyModel
							nearestDist = (keyBody.Position - root.Position).Magnitude
						end
					end
				end
			end
			
			if nearestKey then
				if not highlight or highlight.Parent ~= nearestKey then
					if highlight then highlight:Destroy() end
					highlight = Instance.new("Highlight")
					highlight.Name = "KeyTrackerHighlight"
					highlight.FillColor = Color3.fromRGB(255, 215, 0)
					highlight.OutlineColor = Color3.fromRGB(255, 200, 50)
					highlight.FillTransparency = 0.3
					highlight.OutlineTransparency = 0
					highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					highlight.Parent = nearestKey
				end
				
				local interval = math.clamp(nearestDist / 120, 0.2, 2.0)
				if tick() - lastBeep > interval then
					lastBeep = tick()
					local beep = Instance.new("Sound")
					beep.SoundId = "rbxassetid://12221967"
					beep.Volume = math.clamp(1.2 - nearestDist/120, 0.1, 0.7)
					beep.PlaybackSpeed = 1.3
					beep.Parent = tool.Handle
					beep:Play()
					game:GetService("Debris"):AddItem(beep, 1)
				end
			else
				if highlight then
					highlight:Destroy()
					highlight = nil
				end
			end
		end
	end)
end)

tool.Unequipped:Connect(clearHighlight)
