--[[
	DiegeticHealth.client.lua
	No-HUD health system for Project: Resonance.
	Uses screen blur, vignette, breathing sounds, and heartbeat
	to communicate health state without any UI elements.
]]

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local Lighting       = game:GetService("Lighting")
local SoundService   = game:GetService("SoundService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer

---------------------------------------------------------------------------
-- REFERENCES TO POST-PROCESSING
---------------------------------------------------------------------------
local damageBlur = Lighting:WaitForChild("DamageBlur")

---------------------------------------------------------------------------
-- CREATE VIGNETTE GUI
---------------------------------------------------------------------------
local vignetteGui = Instance.new("ScreenGui")
vignetteGui.Name = "HealthVignette"
vignetteGui.IgnoreGuiInset = true
vignetteGui.DisplayOrder = 5
vignetteGui.ResetOnSpawn = true

local vignetteFrame = Instance.new("Frame")
vignetteFrame.Name = "Vignette"
vignetteFrame.Size = UDim2.new(1, 0, 1, 0)
vignetteFrame.BackgroundColor3 = Color3.fromRGB(80, 0, 0)
vignetteFrame.BackgroundTransparency = 1
vignetteFrame.BorderSizePixel = 0
vignetteFrame.Parent = vignetteGui

local gradient = Instance.new("UIGradient")
gradient.Transparency = NumberSequence.new({
	NumberSequenceKeypoint.new(0, 0),
	NumberSequenceKeypoint.new(0.3, 0.85),
	NumberSequenceKeypoint.new(0.5, 1),
	NumberSequenceKeypoint.new(0.7, 0.85),
	NumberSequenceKeypoint.new(1, 0),
})
gradient.Parent = vignetteFrame

---------------------------------------------------------------------------
-- CREATE SOUNDS
---------------------------------------------------------------------------
local breathingSound = Instance.new("Sound")
breathingSound.Name = "HeavyBreathing"
breathingSound.SoundId = Config.Audio.BreathingId
breathingSound.Looped = true
breathingSound.Volume = 0

local heartbeatSound = Instance.new("Sound")
heartbeatSound.Name = "Heartbeat"
heartbeatSound.SoundId = Config.Audio.HeartbeatId
heartbeatSound.Looped = true
heartbeatSound.Volume = 0

---------------------------------------------------------------------------
-- DEATH FADE
---------------------------------------------------------------------------
local deathGui = Instance.new("ScreenGui")
deathGui.Name = "DeathFade"
deathGui.IgnoreGuiInset = true
deathGui.DisplayOrder = 100
deathGui.ResetOnSpawn = true

local deathFrame = Instance.new("Frame")
deathFrame.Size = UDim2.new(1, 0, 1, 0)
deathFrame.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
deathFrame.BackgroundTransparency = 1
deathFrame.BorderSizePixel = 0
deathFrame.Parent = deathGui

---------------------------------------------------------------------------
-- STATE
---------------------------------------------------------------------------
local lastHealth = Config.Player.MaxHealth
local cameraShakeIntensity = 0

---------------------------------------------------------------------------
-- MAIN
---------------------------------------------------------------------------
local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid")

	-- Parent sounds and GUIs
	breathingSound.Parent = character:WaitForChild("HumanoidRootPart")
	heartbeatSound.Parent = character:WaitForChild("HumanoidRootPart")
	vignetteGui.Parent = player.PlayerGui
	deathGui.Parent = player.PlayerGui

	-- Disable natural regen
	humanoid.MaxHealth = Config.Player.MaxHealth
	humanoid.Health = Config.Player.MaxHealth

	lastHealth = Config.Player.MaxHealth

	-- Health changed
	humanoid.HealthChanged:Connect(function(newHealth)
		local healthPct = newHealth / Config.Player.MaxHealth

		-- BLUR: increases as health drops
		if healthPct < 0.7 then
			damageBlur.Enabled = true
			damageBlur.Size = (1 - healthPct) * 20
		else
			damageBlur.Enabled = false
			damageBlur.Size = 0
		end

		-- VIGNETTE: red pulse as health drops
		if healthPct < 0.5 then
			vignetteFrame.BackgroundTransparency = 0.3 + (healthPct * 0.7)
		else
			vignetteFrame.BackgroundTransparency = 1
		end

		-- BREATHING SOUND
		if healthPct < 0.6 then
			if not breathingSound.Playing then
				breathingSound:Play()
			end
			breathingSound.Volume = (1 - healthPct) * 0.8
		else
			breathingSound.Volume = 0
			if breathingSound.Playing then
				breathingSound:Stop()
			end
		end

		-- HEARTBEAT (critical health)
		if healthPct < 0.3 then
			if not heartbeatSound.Playing then
				heartbeatSound:Play()
			end
			heartbeatSound.Volume = (1 - healthPct) * 1.0
			cameraShakeIntensity = (1 - healthPct) * 0.3
		else
			heartbeatSound.Volume = 0
			cameraShakeIntensity = 0
			if heartbeatSound.Playing then
				heartbeatSound:Stop()
			end
		end

		lastHealth = newHealth
	end)

	-- DEATH
	humanoid.Died:Connect(function()
		breathingSound:Stop()
		heartbeatSound:Stop()
		damageBlur.Enabled = true

		-- Fade to black
		for i = 1, 30 do
			deathFrame.BackgroundTransparency = 1 - (i / 30)
			damageBlur.Size = i
			task.wait(0.05)
		end
	end)

	-- Camera shake for critical health
	RunService.RenderStepped:Connect(function(dt)
		if cameraShakeIntensity > 0 and humanoid.Health > 0 then
			local shakeX = (math.random() - 0.5) * cameraShakeIntensity
			local shakeY = (math.random() - 0.5) * cameraShakeIntensity
			humanoid.CameraOffset = humanoid.CameraOffset + Vector3.new(shakeX, shakeY, 0)
		end
	end)
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	onCharacterAdded(player.Character)
end

print("[DiegeticHealth] Health system ready.")
