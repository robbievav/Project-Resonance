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
-- SHAREABLE TOGGLE DOOR METHOD
---------------------------------------------------------------------------
local function toggleDoor(door, wantOpen, initiatorPart)
	local state = doorStates[door]
	if not state or state.tweening then return end
	if state.isOpen == wantOpen then return end

	state.tweening = true

	local prompt = door:FindFirstChildOfClass("ProximityPrompt")
	local hingeSound = door:FindFirstChild("HingeSound")

	if not wantOpen then
		-- CLOSE the door — tween back to original
		if prompt then prompt.ActionText = "Open" end
		local tween = TweenService:Create(door, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = state.originalCF
		})
		if hingeSound then hingeSound:Play() end
		tween:Play()
		tween.Completed:Wait()
		state.isOpen = false
		door.CanCollide = true

		emitDoorSound(door.Position, "DoorClose")
	else
		-- OPEN the door — swing 90 degrees away from the initiator
		if prompt then prompt.ActionText = "Close" end

		-- Determine perpendicular normal vector of the door
		local doorNormal = (door.Size.X > door.Size.Z) and door.CFrame.LookVector or door.CFrame.RightVector
		
		-- Default swing direction, flip if initiator is on positive normal side
		local angle = 90
		if initiatorPart then
			local toInitiator = initiatorPart.Position - door.Position
			local dot = toInitiator:Dot(doorNormal)
			if dot > 0 then
				angle = -90
			end
		end

		-- Compute the world-space hinge position
		local hingeCF = state.originalCF * state.hingeOffset
		-- Rotate around the hinge, then offset back
		local openCF = hingeCF * CFrame.Angles(0, math.rad(angle), 0) * state.hingeOffset:Inverse()

		local tween = TweenService:Create(door, TweenInfo.new(0.6, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			CFrame = openCF
		})
		if hingeSound then hingeSound:Play() end
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
end

local function breakDoor(door, initiatorPart)
	local state = doorStates[door]
	if not state or state.tweening then return end

	state.tweening = true

	local prompt = door:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = false
	end

	-- Determine perpendicular normal vector of the door
	local doorNormal = (door.Size.X > door.Size.Z) and door.CFrame.LookVector or door.CFrame.RightVector
	
	-- Determine swing direction based on initiator position relative to normal
	local angle = 110
	if initiatorPart then
		local toInitiator = initiatorPart.Position - door.Position
		local dot = toInitiator:Dot(doorNormal)
		if dot > 0 then
			angle = -110
		end
	end

	-- Compute the world-space hinge position
	local hingeCF = state.originalCF * state.hingeOffset
	-- Rotate 110 degrees around the hinge violently
	local openCF = hingeCF * CFrame.Angles(0, math.rad(angle), 0) * state.hingeOffset:Inverse()

	local tween = TweenService:Create(door, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		CFrame = openCF
	})
	
	local hingeSound = door:FindFirstChild("HingeSound")
	if hingeSound then hingeSound:Play() end
	
	tween:Play()
	tween.Completed:Wait()

	state.isOpen = true
	door.CanCollide = false
	state.tweening = false

	-- Emit door break sound (loud)
	emitDoorSound(door.Position, "DoorBreak")
end

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
		-- Inject PathfindingModifier dynamically as a fallback for old/active maps
		local pm = door:FindFirstChildOfClass("PathfindingModifier")
		if not pm then
			pm = Instance.new("PathfindingModifier")
			pm.Label = "Door"
			pm.PassThrough = true
			pm.Parent = door
		end

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
			prompt.RequiresLineOfSight = false
			prompt.Triggered:Connect(function(player)
				local state = doorStates[door]
				if not state or state.tweening then return end
				local char = player.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				toggleDoor(door, not state.isOpen, root)
			end)
		end
	end
end

---------------------------------------------------------------------------
-- EMIT DOOR SOUND (directly to SoundEmitter's active sounds)
---------------------------------------------------------------------------
function emitDoorSound(position, soundType)
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
	local emitEvent = ServerStorage:FindFirstChild("EmitSound")
	if not emitEvent then
		emitEvent = Instance.new("BindableEvent")
		emitEvent.Name = "EmitSound"
		emitEvent.Parent = ServerStorage
	end
end)

-- Register ToggleDoor BindableEvent for external caller scripts (like DecibelAI)
local ServerStorage = game:GetService("ServerStorage")
local toggleDoorEvent = ServerStorage:FindFirstChild("ToggleDoor")
if not toggleDoorEvent then
	toggleDoorEvent = Instance.new("BindableEvent")
	toggleDoorEvent.Name = "ToggleDoor"
	toggleDoorEvent.Parent = ServerStorage
end

toggleDoorEvent.Event:Connect(function(door, wantOpen, initiatorPart)
	toggleDoor(door, wantOpen, initiatorPart)
end)

-- Register BreakDoor BindableEvent for Decibel AI violent breaks
local breakDoorEvent = ServerStorage:FindFirstChild("BreakDoor")
if not breakDoorEvent then
	breakDoorEvent = Instance.new("BindableEvent")
	breakDoorEvent.Name = "BreakDoor"
	breakDoorEvent.Parent = ServerStorage
end

breakDoorEvent.Event:Connect(function(door, initiatorPart)
	breakDoor(door, initiatorPart)
end)

setupDoors()
print("[DoorSystem] Door system active.")
