--[[
	FootstepSystem.client.lua
	Material-aware footstep sounds for Project: Resonance.
	Raycasts down to detect floor material, plays appropriate sounds,
	and fires SoundEvent to server for AI hearing.
]]

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer

---------------------------------------------------------------------------
-- WAIT FOR EVENTS
---------------------------------------------------------------------------
local GameEvents = ReplicatedStorage:WaitForChild("GameEvents", 30)
local SoundEvent = GameEvents and GameEvents:WaitForChild("SoundEvent")

---------------------------------------------------------------------------
-- SOUND POOL (pre-created sounds to avoid GC churn)
---------------------------------------------------------------------------
local soundPool = {}

local function getOrCreateSound(parent, soundId)
	local key = soundId
	if soundPool[key] then
		soundPool[key].Parent = parent
		return soundPool[key]
	end

	local s = Instance.new("Sound")
	s.SoundId = soundId
	s.Volume = 0.4
	s.RollOffMaxDistance = 30
	s.Parent = parent
	soundPool[key] = s
	return s
end

---------------------------------------------------------------------------
-- MAP MATERIAL → SOUND
---------------------------------------------------------------------------
local materialMap = {
	[Enum.Material.SmoothPlastic] = Config.FootstepSounds.Concrete,
	[Enum.Material.Concrete]      = Config.FootstepSounds.Concrete,
	[Enum.Material.DiamondPlate]  = Config.FootstepSounds.Metal,
	[Enum.Material.Metal]         = Config.FootstepSounds.Metal,
	[Enum.Material.CorrodedMetal] = Config.FootstepSounds.Metal,
	[Enum.Material.Marble]        = Config.FootstepSounds.Tile,
	[Enum.Material.Granite]       = Config.FootstepSounds.Granite,
	[Enum.Material.Glass]         = Config.FootstepSounds.Glass,
	[Enum.Material.Fabric]        = Config.FootstepSounds.Carpet,
	[Enum.Material.Wood]          = Config.FootstepSounds.Carpet,
	[Enum.Material.Slate]         = Config.FootstepSounds.Concrete,
}

---------------------------------------------------------------------------
-- STATE
---------------------------------------------------------------------------
local stepTimer     = 0
local lastStepTime  = 0
local isCrouching   = false
local isSprinting   = false

---------------------------------------------------------------------------
-- MAIN
---------------------------------------------------------------------------
local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid")
	local rootPart = character:WaitForChild("HumanoidRootPart")

	-- Pre-create a footstep sound on the root
	local footstepSound = Instance.new("Sound")
	footstepSound.Name = "Footstep"
	footstepSound.Volume = 0.3
	footstepSound.RollOffMaxDistance = 40
	footstepSound.Parent = rootPart

	RunService.Heartbeat:Connect(function(dt)
		if not rootPart or humanoid.Health <= 0 then return end

		-- Detect movement state
		local vel = rootPart.AssemblyLinearVelocity
		local hSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
		local isMoving = hSpeed > 1

		-- Detect crouch / sprint from walk speed
		isCrouching = humanoid.WalkSpeed <= Config.Player.CrouchSpeed
		isSprinting = humanoid.WalkSpeed >= Config.Player.RunSpeed

		if not isMoving then return end

		-- Suppress footsteps while hiding
		if character:GetAttribute("IsHiding") then return end

		-- Step interval depends on speed
		local stepInterval
		if isCrouching then
			stepInterval = 0.7
		elseif isSprinting then
			stepInterval = 0.28
		else
			stepInterval = 0.45
		end

		stepTimer = stepTimer + dt
		if stepTimer < stepInterval then return end
		stepTimer = 0

		-- Raycast down to detect floor material
		local rayParams = RaycastParams.new()
		rayParams.FilterType = Enum.RaycastFilterType.Exclude
		rayParams.FilterDescendantsInstances = {character}

		local result = workspace:Raycast(rootPart.Position, Vector3.new(0, -6, 0), rayParams)
		local material = result and result.Material or Enum.Material.SmoothPlastic
		local soundId = materialMap[material] or Config.FootstepSounds.Default

		-- Play the footstep
		footstepSound.SoundId = soundId
		footstepSound.Volume = isCrouching and 0.1 or (isSprinting and 0.6 or 0.3)

		-- Slight pitch variation for realism
		footstepSound.PlaybackSpeed = 0.9 + math.random() * 0.2
		footstepSound:Play()

		-- Fire sound event to server for AI hearing
		if SoundEvent then
			local soundType = "Walk"
			if isCrouching then soundType = "Crouch" end
			if isSprinting then soundType = "Run" end

			SoundEvent:FireServer({
				Position = rootPart.Position,
				Type     = soundType,
			})
		end
	end)
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	onCharacterAdded(player.Character)
end

print("[FootstepSystem] Footstep system ready.")
