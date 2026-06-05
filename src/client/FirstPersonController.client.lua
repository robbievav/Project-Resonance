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
	print("[Client FirstPersonController] onCharacterAdded fired for character:", character.Name)
	local humanoid = character:WaitForChild("Humanoid")
	local rootPart = character:WaitForChild("HumanoidRootPart")
	print("[Client FirstPersonController] Character loaded: Humanoid and HumanoidRootPart found.")

	-- Teleport to lobby on client to prevent network ownership lag from pushing player to roof
	task.spawn(function()
		print("[Client Teleport Loop] Starting client-side snap-to-lobby loop...")
		for i = 1, 10 do
			local active = (player:GetAttribute("SinglePlayerActive") == true) or (player:GetAttribute("MultiplayerActive") == true)
			if not active then
				print("[Client Teleport Loop] Snapping player to lobby (Y=103) - Iteration:", i)
				rootPart.CFrame = CFrame.new(0, 103, 0)
				rootPart.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
			else
				print("[Client Teleport Loop] Player is active in game. Breaking loop.")
				break
			end
			task.wait(0.1)
		end
	end)

	-- Dynamically manage camera mode and body transparency based on active state
	local active = false
	
	local function updateCameraAndVisibility()
		active = (player:GetAttribute("SinglePlayerActive") == true) or (player:GetAttribute("MultiplayerActive") == true)
		if active then
			player.CameraMode = Enum.CameraMode.LockFirstPerson
			camera.CameraType = Enum.CameraType.Custom
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("Decal") or part:IsA("Texture") then
					part.Transparency = 1
				end
			end
		else
			player.CameraMode = Enum.CameraMode.Classic
			camera.CameraType = Enum.CameraType.Custom
			
			-- Reset crouch state if returning to lobby
			if isCrouching then
				isCrouching = false
				humanoid.HipHeight = humanoid.HipHeight + 1.5
			end
			humanoid.WalkSpeed = 16
			
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("Decal") or part:IsA("Texture") then
					part.Transparency = 0
				end
			end
		end
	end

	player:GetAttributeChangedSignal("SinglePlayerActive"):Connect(updateCameraAndVisibility)
	player:GetAttributeChangedSignal("MultiplayerActive"):Connect(updateCameraAndVisibility)
	updateCameraAndVisibility()

	task.spawn(function()
		task.wait(0.5)
		updateCameraAndVisibility()

		RunService.RenderStepped:Connect(function()
			for _, part in ipairs(character:GetDescendants()) do
				if part:IsA("BasePart") and part.Name ~= "HumanoidRootPart" then
					if active then
						-- Hide character parts in-game, except for tool parts
						local isToolPart = false
						local current = part.Parent
						while current and current ~= character do
							if current:IsA("Tool") then
								isToolPart = true
								break
							end
							current = current.Parent
						end
						if isToolPart then
							part.LocalTransparencyModifier = 0
						else
							part.LocalTransparencyModifier = 1
						end
					else
						-- Show normally in the lobby
						part.LocalTransparencyModifier = 0
					end
				end
			end
		end)
	end)

	-- Set initial walk speed
	updateCameraAndVisibility()

	---------------------------------------------------------------------
	-- HEAD BOB
	---------------------------------------------------------------------
	RunService.RenderStepped:Connect(function(dt)
		if not rootPart or not humanoid or humanoid.Health <= 0 then return end

		-- Determine if moving
		local vel = rootPart.AssemblyLinearVelocity
		local hSpeed = Vector3.new(vel.X, 0, vel.Z).Magnitude
		isMoving = hSpeed > 1

		if isMoving and active then
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
		if not active then
			humanoid.WalkSpeed = 16
			return
		end

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
