--[[
	FirstPersonController.client.lua
	Locks the camera to first-person, hides the character model,
	adds head-bob, and manages crouch mechanic.
]]

local Players        = game:GetService("Players")
local RunService     = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Config"))

local player = Players.LocalPlayer
local camera = workspace.CurrentCamera

---------------------------------------------------------------------------
-- STATE
---------------------------------------------------------------------------
local isCrouching = false
local bobTimer    = 0
local isMoving    = false

---------------------------------------------------------------------------
-- WAIT FOR CHARACTER
---------------------------------------------------------------------------
local function onCharacterAdded(character)
	local humanoid = character:WaitForChild("Humanoid")
	local rootPart = character:WaitForChild("HumanoidRootPart")

	-- Force first person
	player.CameraMode = Enum.CameraMode.LockFirstPerson
	camera.CameraType = Enum.CameraType.Custom

	-- Hide all character parts (first-person: you shouldn't see your own body)
	task.spawn(function()
		task.wait(0.5)
		for _, part in ipairs(character:GetDescendants()) do
			if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
				part.LocalTransparencyModifier = 1
			end
			if part:IsA("Decal") or part:IsA("Texture") then
				part.Transparency = 1
			end
		end

		-- Keep hiding parts that Roblox tries to show
		RunService.RenderStepped:Connect(function()
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
					part.LocalTransparencyModifier = 1
				end
			end
		end)
	end)

	-- Set initial walk speed
	humanoid.WalkSpeed = Config.Player.WalkSpeed

	---------------------------------------------------------------------
	-- HEAD BOB
	---------------------------------------------------------------------
	RunService.RenderStepped:Connect(function(dt)
		if not rootPart or not humanoid or humanoid.Health <= 0 then return end

		-- Determine if moving
		local vel = rootPart.AssemblyLinearVelocity
		local hSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
		isMoving = hSpeed > 1

		if isMoving then
			local bobSpeed = Config.Player.HeadBobSpeed
			local bobAmount = Config.Player.HeadBobAmount
			if isCrouching then
				bobSpeed = bobSpeed * 0.6
				bobAmount = bobAmount * 0.5
			end
			bobTimer = bobTimer + dt * bobSpeed
			local bobOffset = math.sin(bobTimer * math.pi * 2) * bobAmount
			humanoid.CameraOffset = Vector3.new(0, bobOffset, 0)
		else
			-- Smoothly return to neutral
			local current = humanoid.CameraOffset
			humanoid.CameraOffset = current:Lerp(Vector3.new(0, 0, 0), dt * 8)
			bobTimer = 0
		end
	end)

	---------------------------------------------------------------------
	-- CROUCH & SPRINT HANDLING
	---------------------------------------------------------------------
	local isSprinting = false

	local function updateMovementState()
		local wantCrouch = UserInputService:IsKeyDown(Enum.KeyCode.LeftControl) or UserInputService:IsKeyDown(Enum.KeyCode.C)
		local wantSprint = UserInputService:IsKeyDown(Enum.KeyCode.LeftShift)

		if wantCrouch ~= isCrouching then
			isCrouching = wantCrouch
			if isCrouching then
				humanoid.HipHeight = humanoid.HipHeight - 1.5
			else
				humanoid.HipHeight = humanoid.HipHeight + 1.5
			end
		end

		isSprinting = wantSprint and not isCrouching

		if isCrouching then
			humanoid.WalkSpeed = Config.Player.CrouchSpeed
		elseif isSprinting then
			humanoid.WalkSpeed = Config.Player.RunSpeed
		else
			humanoid.WalkSpeed = Config.Player.WalkSpeed
		end
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if processed then return end
		if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.LeftShift then
			updateMovementState()
		end
	end)

	UserInputService.InputEnded:Connect(function(input, processed)
		if input.KeyCode == Enum.KeyCode.LeftControl or input.KeyCode == Enum.KeyCode.C or input.KeyCode == Enum.KeyCode.LeftShift then
			updateMovementState()
		end
	end)
end

player.CharacterAdded:Connect(onCharacterAdded)
if player.Character then
	onCharacterAdded(player.Character)
end

print("[FirstPersonController] Ready.")
