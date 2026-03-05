--[[
	HidingSystem.server.lua
	Server-authoritative hiding system for Project: Resonance.
	Manages enter/exit hiding, anchors player inside spot, handles breathing failures.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local ServerStorage     = game:GetService("ServerStorage")

local Config = require(ReplicatedStorage.Shared.Config)

---------------------------------------------------------------------------
-- WAIT FOR EVENTS
---------------------------------------------------------------------------
local GameEvents = ReplicatedStorage:WaitForChild("GameEvents", 30)
if not GameEvents then
	warn("[HidingSystem] GameEvents not found!")
	return
end

local HideEvent       = GameEvents:WaitForChild("HideEvent")
local BreathingFail   = GameEvents:WaitForChild("BreathingFail")
local SoundEvent      = GameEvents:WaitForChild("SoundEvent")

---------------------------------------------------------------------------
-- HIDING STATE
---------------------------------------------------------------------------
local hiddenPlayers = {}  -- [player] = { spot, originalCF, hideTime }

---------------------------------------------------------------------------
-- ENTER HIDING
---------------------------------------------------------------------------
local function enterHiding(player, hidingSpot)
	if hiddenPlayers[player] then return end  -- already hiding
	
	local char = player.Character
	if not char then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	if not root or not humanoid then return end
	
	-- Validate proximity
	local dist = (root.Position - hidingSpot.Position).Magnitude
	if dist > 12 then return end  -- too far away
	
	-- Store original position and anchor the player inside the spot
	local originalCF = root.CFrame
	
	hiddenPlayers[player] = {
		spot = hidingSpot,
		originalCF = originalCF,
		hideTime = tick(),
	}
	
	-- Set the attribute for AI to check
	char:SetAttribute("IsHiding", true)
	char:SetAttribute("HidingSpotPosition", hidingSpot.Position)
	
	-- Move player into the hiding spot and anchor them
	root.CFrame = CFrame.new(hidingSpot.Position + Vector3.new(0, -0.5, 0))
	root.Anchored = true
	humanoid.WalkSpeed = 0
	
	-- Make character invisible
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.Transparency = 1
		end
	end
	
	-- Disable the prompt while occupied
	local prompt = hidingSpot:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = false
	end
	
	print("[HidingSystem]", player.Name, "entered hiding in", hidingSpot:FindFirstChild("HideType") and hidingSpot.HideType.Value or "unknown")
	
	-- Force exit after MaxHideTime
	task.delay(Config.Hiding.MaxHideTime, function()
		if hiddenPlayers[player] then
			exitHiding(player)
		end
	end)
end

---------------------------------------------------------------------------
-- EXIT HIDING
---------------------------------------------------------------------------
function exitHiding(player)
	local data = hiddenPlayers[player]
	if not data then return end
	
	local char = player.Character
	if not char then
		hiddenPlayers[player] = nil
		return
	end
	
	local root = char:FindFirstChild("HumanoidRootPart")
	local humanoid = char:FindFirstChildOfClass("Humanoid")
	
	if root then
		root.Anchored = false
		-- Move player back near the spot (slightly offset so they don't clip)
		root.CFrame = data.originalCF + Vector3.new(0, 0.5, 2)
	end
	
	if humanoid then
		humanoid.WalkSpeed = Config.Player.WalkSpeed
	end
	
	-- Clear attributes
	char:SetAttribute("IsHiding", false)
	char:SetAttribute("HidingSpotPosition", nil)
	
	-- Restore character visibility
	for _, part in ipairs(char:GetDescendants()) do
		if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
			part.LocalTransparencyModifier = 0
			part.Transparency = 0
		end
	end
	
	-- Re-enable the hiding spot prompt
	local prompt = data.spot:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = true
	end
	
	hiddenPlayers[player] = nil
	print("[HidingSystem]", player.Name, "exited hiding.")
end

---------------------------------------------------------------------------
-- BREATHING FAILURE — player made noise while hiding
---------------------------------------------------------------------------
local function onBreathingFail(player)
	local data = hiddenPlayers[player]
	if not data then return end
	
	-- Emit a sound at the hiding spot position for the AI to hear
	local emitEvent = ServerStorage:FindFirstChild("EmitSound")
	if not emitEvent then
		emitEvent = Instance.new("BindableEvent")
		emitEvent.Name = "EmitSound"
		emitEvent.Parent = ServerStorage
	end
	
	emitEvent:Fire({
		Position  = data.spot.Position,
		Volume    = Config.Hiding.BreathingFailVolume,
		Type      = "BreathingFail",
		Timestamp = tick(),
		Player    = player,
	})
	
	-- Temporarily reveal the player to the AI
	local char = player.Character
	if char then
		char:SetAttribute("IsHiding", false)
		-- Re-hide after a short window
		task.delay(2, function()
			if hiddenPlayers[player] then
				char:SetAttribute("IsHiding", true)
			end
		end)
	end
	
	print("[HidingSystem]", player.Name, "breathing fail! Sound emitted.")
end

---------------------------------------------------------------------------
-- EVENT LISTENERS
---------------------------------------------------------------------------
HideEvent.OnServerEvent:Connect(function(player, action, hidingSpot)
	if action == "Enter" and hidingSpot and hidingSpot:IsA("BasePart") then
		enterHiding(player, hidingSpot)
	elseif action == "Exit" then
		exitHiding(player)
	end
end)

BreathingFail.OnServerEvent:Connect(function(player)
	onBreathingFail(player)
end)

-- Cleanup on player leave
Players.PlayerRemoving:Connect(function(player)
	if hiddenPlayers[player] then
		hiddenPlayers[player] = nil
	end
end)

-- Cleanup on character death
Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function(character)
		local humanoid = character:WaitForChild("Humanoid")
		humanoid.Died:Connect(function()
			if hiddenPlayers[player] then
				hiddenPlayers[player] = nil
			end
		end)
	end)
end)

print("[HidingSystem] Server hiding system active.")
