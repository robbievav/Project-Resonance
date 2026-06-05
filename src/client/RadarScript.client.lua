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
	beepSound.Volume = 0.5
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
			local nearestDecibel = nil
			local nearestDist = math.huge
			
			for _, child in ipairs(workspace:GetChildren()) do
				if child.Name:find("TheDecibel") and child:IsA("Model") then
					local decibelRoot = child:FindFirstChild("HumanoidRootPart")
					if decibelRoot then
						local dist = (decibelRoot.Position - root.Position).Magnitude
						if dist < nearestDist then
							nearestDecibel = child
							nearestDist = dist
						end
					end
				end
			end
			
			if nearestDecibel then
				if not highlight or highlight.Parent ~= nearestDecibel then
					if highlight then highlight:Destroy() end
					highlight = Instance.new("Highlight")
					highlight.Name = "TrackerHighlight"
					highlight.FillColor = Color3.fromRGB(255, 50, 50)
					highlight.OutlineColor = Color3.fromRGB(255, 0, 0)
					highlight.FillTransparency = 0.4
					highlight.OutlineTransparency = 0
					highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
					highlight.Parent = nearestDecibel
				end
				
				local interval = math.clamp(nearestDist / 100, 0.25, 2.5)
				if tick() - lastBeep > interval then
					lastBeep = tick()
					local beep = Instance.new("Sound")
					beep.SoundId = "rbxassetid://12221967"
					beep.Volume = math.clamp(1.5 - nearestDist/120, 0.1, 0.8)
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
