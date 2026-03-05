--[[
	DynamicAudio.client.lua
	Tension-based soundtrack and spatial audio system for Project: Resonance.
	Manages ambient drone, AI-proximity music fade, near-miss stingers,
	and environmental sounds (dripping water, fluorescent hum).
]]

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local SoundService   = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer
local AC     = Config.AI
local AU     = Config.Audio

---------------------------------------------------------------------------
-- WAIT FOR EVENTS
---------------------------------------------------------------------------
local GameEvents  = ReplicatedStorage:WaitForChild("GameEvents", 30)
local AIAlertEvent = GameEvents and GameEvents:WaitForChild("AIAlert")

---------------------------------------------------------------------------
-- AMBIENT DRONE
---------------------------------------------------------------------------
local ambientDrone = Instance.new("Sound")
ambientDrone.Name = "AmbientDrone"
ambientDrone.SoundId = AU.AmbientDroneId
ambientDrone.Looped = true
ambientDrone.Volume = 0.4
ambientDrone.Parent = SoundService

---------------------------------------------------------------------------
-- NEAR-MISS STINGER
---------------------------------------------------------------------------
local nearMissStinger = Instance.new("Sound")
nearMissStinger.Name = "NearMissStinger"
nearMissStinger.SoundId = AU.NearMissStingerId
nearMissStinger.Looped = false
nearMissStinger.Volume = 0.7
nearMissStinger.Parent = SoundService

---------------------------------------------------------------------------
-- ENVIRONMENTAL SOUNDS (spatial, placed in the world)
---------------------------------------------------------------------------
local function placeEnvironmentalSounds()
	local mapFolder = workspace:FindFirstChild("GeneratedMap")
	if not mapFolder then return end

	-- Find water coolers and put dripping water sounds near them
	for _, desc in ipairs(mapFolder:GetDescendants()) do
		if desc:IsA("BasePart") then
			if desc.Name == "WaterJug" or desc.Name == "WaterCoolerBody" then
				local drip = Instance.new("Sound")
				drip.Name = "DrippingWater"
				drip.SoundId = AU.DrippingWaterId
				drip.Looped = true
				drip.Volume = 0.15
				drip.RollOffMaxDistance = 25
				drip.RollOffMinDistance = 3
				drip.Parent = desc
				drip:Play()
			end

			-- Fluorescent hum on light fixtures
			if desc.Name == "FluorescentHousing" then
				local hum = Instance.new("Sound")
				hum.Name = "FluorescentHum"
				hum.SoundId = AU.FluorescentHumId
				hum.Looped = true
				hum.Volume = 0.08
				hum.RollOffMaxDistance = 15
				hum.RollOffMinDistance = 2
				hum.Parent = desc
				hum:Play()
			end
		end
	end
end

---------------------------------------------------------------------------
-- AI PROXIMITY MUSIC FADE
---------------------------------------------------------------------------
local targetDroneVolume = 0.4
local currentDroneVolume = 0.4

local function updateAIProximity()
	local character = player.Character
	if not character then return end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if not rootPart then return end

	-- Find TheDecibel entity
	local decibel = workspace:FindFirstChild("TheDecibel")
	if not decibel or not decibel.PrimaryPart then
		targetDroneVolume = 0.4
		return
	end

	local dist = (decibel.PrimaryPart.Position - rootPart.Position).Magnitude
	local hearingRadius = AC.HearingRadius

	if dist < hearingRadius then
		-- Closer the AI = quieter the drone (silence = danger)
		local closeness = 1 - (dist / hearingRadius)
		targetDroneVolume = math.max(0, 0.4 - closeness * 0.4)
	else
		targetDroneVolume = 0.4
	end
end

---------------------------------------------------------------------------
-- AI ALERT HANDLER (near-miss stinger from server)
---------------------------------------------------------------------------
if AIAlertEvent then
	AIAlertEvent.OnClientEvent:Connect(function(data)
		if data and data.Type == "NearMiss" then
			nearMissStinger:Play()
		end
	end)
end

---------------------------------------------------------------------------
-- START
---------------------------------------------------------------------------
local function start()
	-- Start ambient drone
	task.wait(3)
	ambientDrone:Play()

	-- Place environmental sounds after map generates
	task.delay(6, placeEnvironmentalSounds)

	-- Main audio loop
	RunService.Heartbeat:Connect(function(dt)
		-- Smooth volume interpolation
		updateAIProximity()
		currentDroneVolume = currentDroneVolume + (targetDroneVolume - currentDroneVolume) * dt * (1 / AU.DroneFadeTime)
		ambientDrone.Volume = currentDroneVolume
	end)
end

start()

print("[DynamicAudio] Audio system active.")
