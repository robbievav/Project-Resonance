--[[
	DoorSystem.server.lua
	Manages all doors in Project: Resonance.
	Doors open/close with sound, emit noise events for the AI.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)

---------------------------------------------------------------------------
-- Wait for map and events
---------------------------------------------------------------------------
local mapFolder  = workspace:WaitForChild("GeneratedMap", 60)
local GameEvents = ReplicatedStorage:WaitForChild("GameEvents", 30)
if not GameEvents then
	warn("[DoorSystem] GameEvents not found!")
	return
end

local SoundEvent = GameEvents:WaitForChild("SoundEvent")
local DoorEvent  = GameEvents:WaitForChild("DoorEvent")

---------------------------------------------------------------------------
-- DOOR STATE TRACKING
---------------------------------------------------------------------------
local doorStates = {}  -- [door Part] = { isOpen, originalCF, tweening }

---------------------------------------------------------------------------
-- SETUP: Find all doors and attach listeners
---------------------------------------------------------------------------
local function setupDoors()
	-- Give the map a moment to fully generate
	task.wait(2)

	local doors = {}
	for _, descendant in ipairs(mapFolder:GetDescendants()) do
		if descendant:IsA("BasePart") and descendant.Name == "Door" then
			table.insert(doors, descendant)
		end
	end

	print("[DoorSystem] Found", #doors, "doors.")

	for _, door in ipairs(doors) do
		-- Determine the hinge offset based on door orientation
		-- Hinge on the left edge of the door (relative to its local axes)
		local doorSize = door.Size
		local hingeOffset
		if doorSize.X > doorSize.Z then
			-- Door faces along Z axis (PosZ/NegZ wall) — hinge on left X edge
			hingeOffset = CFrame.new(-doorSize.X / 2, 0, 0)
		else
			-- Door faces along X axis (PosX/NegX wall) — hinge on left Z edge
			hingeOffset = CFrame.new(0, 0, -doorSize.Z / 2)
		end

		doorStates[door] = {
			isOpen      = false,
			originalCF  = door.CFrame,
			tweening    = false,
			hingeOffset = hingeOffset,
		}

		-- Create the hinge sound
		local hingeSound = Instance.new("Sound")
		hingeSound.Name = "HingeSound"
		hingeSound.SoundId = Config.Audio.DoorHingeId
		hingeSound.Volume = 0.6
		hingeSound.RollOffMaxDistance = 40
		hingeSound.Parent = door

		-- Listen for ProximityPrompt activation
		local prompt = door:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				local state = doorStates[door]
				if not state or state.tweening then return end

				state.tweening = true

				if state.isOpen then
					-- CLOSE the door — tween back to original
					prompt.ActionText = "Open"
					local tween = TweenService:Create(door, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						CFrame = state.originalCF
					})
					hingeSound:Play()
					tween:Play()
					tween.Completed:Wait()
					state.isOpen = false
					door.CanCollide = true

					emitDoorSound(door.Position, "DoorClose")
				else
					-- OPEN the door — rotate 90° around the hinge edge
					prompt.ActionText = "Close"

					-- Compute the world-space hinge position
					local hingeCF = state.originalCF * state.hingeOffset
					-- Rotate 90° around the hinge, then offset back
					local openCF = hingeCF * CFrame.Angles(0, math.rad(90), 0) * state.hingeOffset:Inverse()

					local tween = TweenService:Create(door, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
						CFrame = openCF
					})
					hingeSound:Play()
					tween:Play()
					tween.Completed:Wait()
					state.isOpen = true
					door.CanCollide = false

					emitDoorSound(door.Position, "DoorOpen")
				end

				state.tweening = false

				-- Notify clients about door state change
				DoorEvent:FireAllClients({
					DoorId   = door:GetFullName(),
					IsOpen   = state.isOpen,
					Position = door.Position,
				})
			end)
		end
	end
end

---------------------------------------------------------------------------
-- EMIT DOOR SOUND (directly to SoundEmitter's active sounds)
---------------------------------------------------------------------------
function emitDoorSound(position, soundType)
	local getSoundsFunc = game:GetService("ServerStorage"):FindFirstChild("GetActiveSounds")
	-- We can't easily push; instead use a BindableEvent approach
	-- For now, fire a custom event that the SoundEmitter picks up

	-- Create a one-shot BindableEvent if it doesn't exist
	local emitFunc = game:GetService("ServerStorage"):FindFirstChild("EmitSound")
	if not emitFunc then
		emitFunc = Instance.new("BindableEvent")
		emitFunc.Name = "EmitSound"
		emitFunc.Parent = game:GetService("ServerStorage")
	end

	emitFunc:Fire({
		Position  = position,
		Volume    = Config.SoundLevels[soundType] or 0.5,
		Type      = soundType,
		Timestamp = tick(),
		Player    = nil,
	})
end

---------------------------------------------------------------------------
-- MAIN
---------------------------------------------------------------------------
-- Also listen for the BindableEvent on the SoundEmitter side
task.spawn(function()
	local ServerStorage = game:GetService("ServerStorage")
	-- Create EmitSound event if it doesn't exist
	local emitEvent = ServerStorage:FindFirstChild("EmitSound")
	if not emitEvent then
		emitEvent = Instance.new("BindableEvent")
		emitEvent.Name = "EmitSound"
		emitEvent.Parent = ServerStorage
	end

	-- The SoundEmitter will hook into this in its own script
end)

setupDoors()
print("[DoorSystem] Door system active.")
