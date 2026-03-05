--[[
	DecibelAI.server.lua
	The primary antagonist for Project: Resonance.
	Phase 2: Multi-floor patrol, difficulty scaling, hiding awareness, door breaking.
]]

local RunService         = game:GetService("RunService")
local ServerStorage      = game:GetService("ServerStorage")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local Players            = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local TweenService       = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local AC     = Config.AI

---------------------------------------------------------------------------
-- WAIT FOR MAP + EVENTS
---------------------------------------------------------------------------
local mapFolder = workspace:WaitForChild("GeneratedMap", 60)
if not mapFolder then
	warn("[DecibelAI] GeneratedMap not found, aborting.")
	return
end

local GameEvents    = ReplicatedStorage:WaitForChild("GameEvents", 30)
local AIAlertEvent  = GameEvents and GameEvents:WaitForChild("AIAlert")
local getSoundsFunc = ServerStorage:WaitForChild("GetActiveSounds", 30)

---------------------------------------------------------------------------
-- CREATE THE ENTITY MODEL
---------------------------------------------------------------------------
local function createEntityModel()
	local model = Instance.new("Model")
	model.Name = "TheDecibel"

	local torso = Instance.new("Part")
	torso.Name = "HumanoidRootPart"
	torso.Anchored = false
	torso.CanCollide = true
	torso.Size = Vector3.new(3, 7, 2)
	torso.Color = Color3.fromRGB(15, 12, 10)
	torso.Material = Enum.Material.SmoothPlastic
	torso.Transparency = 0
	torso.Parent = model

	local head = Instance.new("Part")
	head.Name = "Head"
	head.Anchored = false
	head.CanCollide = false
	head.Size = Vector3.new(2, 2.5, 2)
	head.Color = Color3.fromRGB(10, 8, 8)
	head.Material = Enum.Material.SmoothPlastic
	head.Shape = Enum.PartType.Ball
	head.Parent = model

	local headWeld = Instance.new("Weld")
	headWeld.Part0 = torso
	headWeld.Part1 = head
	headWeld.C0 = CFrame.new(0, 4.5, 0)
	headWeld.Parent = torso

	for _, xOff in ipairs({-0.4, 0.4}) do
		local eye = Instance.new("Part")
		eye.Name = "Eye"
		eye.Anchored = false
		eye.CanCollide = false
		eye.Size = Vector3.new(0.25, 0.15, 0.1)
		eye.Color = Color3.fromRGB(120, 20, 20)
		eye.Material = Enum.Material.Neon
		eye.Parent = model

		local eyeWeld = Instance.new("Weld")
		eyeWeld.Part0 = head
		eyeWeld.Part1 = eye
		eyeWeld.C0 = CFrame.new(xOff, 0.3, -0.9)
		eyeWeld.Parent = head
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.MaxHealth = math.huge
	humanoid.Health = math.huge
	humanoid.WalkSpeed = AC.PatrolSpeed
	humanoid.Parent = model

	model.PrimaryPart = torso
	return model
end

---------------------------------------------------------------------------
-- AI STATE MACHINE
---------------------------------------------------------------------------
local State = {
	IDLE        = "Idle",
	PATROL      = "Patrol",
	INVESTIGATE = "Investigate",
	CHASE       = "Chase",
	NEAR_MISS   = "NearMiss",
	FLOOR_TRANSITION = "FloorTransition",
}

local entity = nil
local currentState = State.IDLE
local targetPosition = nil
local lastSoundTime = 0
local investigateTarget = nil
local currentFloor = 1
local lastFloorTransition = 0
local floorTransitionCooldown = AC.FloorTransitionDelay

---------------------------------------------------------------------------
-- DIFFICULTY SCALING
---------------------------------------------------------------------------
local function getDifficultyMult()
	return 1 + (currentFloor - 1) * AC.DifficultyPerFloor
end

local function getScaledSpeed(baseSpeed)
	return baseSpeed * getDifficultyMult()
end

local function getScaledHearingRadius()
	return AC.HearingRadius * getDifficultyMult()
end

local function getScaledLoseInterestTime()
	return math.max(3, AC.LoseInterestTime / getDifficultyMult())
end

---------------------------------------------------------------------------
-- GET AI'S CURRENT FLOOR
---------------------------------------------------------------------------
local function getAIFloor()
	if not entity or not entity.PrimaryPart then return 1 end
	local y = entity.PrimaryPart.Position.Y
	local floor = math.floor(-y / Config.Map.FloorSeparation) + 1
	return math.clamp(floor, 1, Config.Map.FloorsToGenerate)
end

---------------------------------------------------------------------------
-- PATROL: Pick a random walkable position on the current floor
---------------------------------------------------------------------------
local function getRandomPatrolTarget()
	local floorName = "Floor_" .. currentFloor
	local floorFolder = mapFolder:FindFirstChild(floorName)
	if not floorFolder then return Vector3.new(0, 0, 0) end

	local parts = {}
	for _, child in ipairs(floorFolder:GetDescendants()) do
		if child:IsA("BasePart") and child.Name == "Floor" then
			table.insert(parts, child)
		end
	end

	if #parts == 0 then return Vector3.new(0, 0, 0) end
	local chosen = parts[math.random(1, #parts)]
	return chosen.Position + Vector3.new(
		math.random(-5, 5),
		4,
		math.random(-5, 5)
	)
end

---------------------------------------------------------------------------
-- FIND STAIRWELL ON CURRENT FLOOR
---------------------------------------------------------------------------
local function findStairwell()
	local floorName = "Floor_" .. currentFloor
	local floorFolder = mapFolder:FindFirstChild(floorName)
	if not floorFolder then return nil end

	for _, child in ipairs(floorFolder:GetChildren()) do
		if child.Name == "Stairwell" then
			for _, desc in ipairs(child:GetDescendants()) do
				if desc:IsA("BasePart") and desc.Name == "Floor" then
					return desc.Position + Vector3.new(0, 4, 0)
				end
			end
		end
	end
	return nil
end

local PathfindingService = game:GetService("PathfindingService")
local currentPath = nil
local waypointIndex = 1

---------------------------------------------------------------------------
-- MOVE TOWARD TARGET (Using Pathfinding)
---------------------------------------------------------------------------
local function moveToward(pos)
	if not entity or not entity.PrimaryPart then return end
	local humanoid = entity:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = false,
		WaypointSpacing = 4,
	})

	local success, errorMessage = pcall(function()
		path:ComputeAsync(entity.PrimaryPart.Position, pos)
	end)

	if success and path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		if #waypoints >= 2 then
			-- Move to the next immediate waypoint (index 2 because 1 is our current spot)
			local nextPoint = waypoints[2]
			humanoid:MoveTo(nextPoint.Position)
			if nextPoint.Action == Enum.PathWaypointAction.Jump then
				humanoid.Jump = true
			end
		else
			-- We are right next to it, just move directly
			humanoid:MoveTo(pos)
		end
	else
		-- Fallback to straight line if path fails
		humanoid:MoveTo(pos)
	end
end

---------------------------------------------------------------------------
-- FIND LOUDEST SOUND (with scaled hearing radius)
---------------------------------------------------------------------------
local function getLoudestSound()
	if not getSoundsFunc then return nil end

	local ok, sounds = pcall(function()
		return getSoundsFunc:Invoke()
	end)

	if not ok or not sounds then return nil end

	local loudest = nil
	local maxVol = 0
	local hearingRadius = getScaledHearingRadius()

	for _, s in ipairs(sounds) do
		if s.Volume > maxVol then
			if entity and entity.PrimaryPart then
				local dist = (s.Position - entity.PrimaryPart.Position).Magnitude
				if dist <= hearingRadius then
					loudest = s
					maxVol = s.Volume
				end
			end
		end
	end

	return loudest
end

---------------------------------------------------------------------------
-- CHECK FOR NEARBY PLAYERS (hiding-aware)
---------------------------------------------------------------------------
local function getNearestPlayer()
	if not entity or not entity.PrimaryPart then return nil, math.huge end

	local nearest = nil
	local nearestDist = math.huge

	for _, plr in ipairs(Players:GetPlayers()) do
		local char = plr.Character
		if char then
			-- Skip players that are hiding (unless AI is very close and heard them)
			local isHiding = char:GetAttribute("IsHiding")
			if not isHiding then
				local root = char:FindFirstChild("HumanoidRootPart")
				if root then
					local dist = (root.Position - entity.PrimaryPart.Position).Magnitude
					if dist < nearestDist then
						nearest = plr
						nearestDist = dist
					end
				end
			end
		end
	end

	return nearest, nearestDist
end

---------------------------------------------------------------------------
-- DOOR BREAKING (Chase state)
---------------------------------------------------------------------------
local function tryBreakNearbyDoor()
	if not entity or not entity.PrimaryPart then return end

	local pos = entity.PrimaryPart.Position
	-- Check for closed doors within reach
	for _, desc in ipairs(mapFolder:GetDescendants()) do
		if desc:IsA("BasePart") and desc.Name == "Door" and desc.CanCollide then
			local dist = (desc.Position - pos).Magnitude
			if dist < 8 then
				-- Break the door!
				task.spawn(function()
					task.wait(AC.DoorBreakTime)
					if desc and desc.Parent then
						-- Violent open — fling the door
						desc.CanCollide = false
						local breakTween = TweenService:Create(desc, TweenInfo.new(0.3, Enum.EasingStyle.Back), {
							CFrame = desc.CFrame * CFrame.Angles(0, math.rad(110), 0),
						})
						breakTween:Play()

						-- Emit loud sound
						local emitEvent = ServerStorage:FindFirstChild("EmitSound")
						if emitEvent then
							emitEvent:Fire({
								Position  = desc.Position,
								Volume    = 0.9,
								Type      = "DoorBreak",
								Timestamp = tick(),
								Player    = nil,
							})
						end
					end
				end)
				return  -- only break one door at a time
			end
		end
	end
end

---------------------------------------------------------------------------
-- AI TICK
---------------------------------------------------------------------------
local function aiTick()
	if not entity or not entity.PrimaryPart then return end
	local humanoid = entity:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	-- Update AI's current floor
	currentFloor = getAIFloor()
	entity:SetAttribute("CurrentFloor", currentFloor)

	local loudest = getLoudestSound()
	local nearestPlayer, nearestDist = getNearestPlayer()

	-- State transitions based on sound
	if loudest then
		lastSoundTime = tick()
		investigateTarget = loudest.Position

		if loudest.Volume >= Config.SoundLevels.Run then
			currentState = State.CHASE
			humanoid.WalkSpeed = getScaledSpeed(AC.ChaseSpeed)
		else
			currentState = State.INVESTIGATE
			humanoid.WalkSpeed = getScaledSpeed(AC.PatrolSpeed + 4)
		end
	end

	-- Lose interest timeout (scaled by difficulty)
	if currentState == State.INVESTIGATE or currentState == State.CHASE then
		if tick() - lastSoundTime > getScaledLoseInterestTime() then
			currentState = State.PATROL
			humanoid.WalkSpeed = getScaledSpeed(AC.PatrolSpeed)
			investigateTarget = nil
		end
	end

	-- Execute state behavior
	if currentState == State.PATROL then
		if not targetPosition or (entity.PrimaryPart.Position - targetPosition).Magnitude < 5 then
			targetPosition = getRandomPatrolTarget()
		end
		moveToward(targetPosition)

		-- Floor transition: periodically move to stairwell and change floors
		if tick() - lastFloorTransition > floorTransitionCooldown then
			-- Decide whether to change floors (30% chance per check)
			if math.random() < 0.3 then
				-- Try to follow the closest player's floor
				local targetFloor = currentFloor
				for _, plr in ipairs(Players:GetPlayers()) do
					local pFloor = plr:GetAttribute("CurrentFloor") or 1
					if math.abs(pFloor - currentFloor) >= 1 then
						targetFloor = pFloor
						break
					end
				end

				if targetFloor ~= currentFloor then
					local stairPos = findStairwell()
					if stairPos then
						currentState = State.FLOOR_TRANSITION
						targetPosition = stairPos
						moveToward(stairPos)
					end
				end
			end
			lastFloorTransition = tick()
		end

	elseif currentState == State.INVESTIGATE then
		if investigateTarget then
			moveToward(investigateTarget)

			-- Near-miss check
			if nearestDist < AC.NearMissRadius and not loudest then
				currentState = State.NEAR_MISS
				if nearestPlayer and AIAlertEvent then
					AIAlertEvent:FireClient(nearestPlayer, {
						Type = "NearMiss",
						Position = entity.PrimaryPart.Position,
					})
				end
			end
		end

	elseif currentState == State.CHASE then
		if investigateTarget then
			moveToward(investigateTarget)
		end

		-- Try to break doors in the way
		tryBreakNearbyDoor()

		-- Kill check
		if nearestDist < 4 then
			if nearestPlayer then
				local char = nearestPlayer.Character
				if char then
					local hum = char:FindFirstChildOfClass("Humanoid")
					if hum then
						hum.Health = 0
					end
				end
			end
		end

	elseif currentState == State.NEAR_MISS then
		if nearestPlayer and nearestPlayer.Character then
			local playerPos = nearestPlayer.Character:FindFirstChild("HumanoidRootPart")
			if playerPos then
				local awayDir = (entity.PrimaryPart.Position - playerPos.Position).Unit
				targetPosition = entity.PrimaryPart.Position + awayDir * 30
				moveToward(targetPosition)
			end
		end
		task.delay(1.5, function()
			if currentState == State.NEAR_MISS then
				currentState = State.PATROL
				humanoid.WalkSpeed = getScaledSpeed(AC.PatrolSpeed)
			end
		end)

	elseif currentState == State.FLOOR_TRANSITION then
		-- Move toward the stairwell
		if targetPosition then
			moveToward(targetPosition)
			-- Check if we've reached the stairwell
			if (entity.PrimaryPart.Position - targetPosition).Magnitude < 8 then
				-- Teleport to the stairwell on the adjacent floor
				local nextFloor
				-- Try to move toward the nearest player
				local targetFloor = currentFloor
				for _, plr in ipairs(Players:GetPlayers()) do
					local pFloor = plr:GetAttribute("CurrentFloor") or 1
					if pFloor > currentFloor then
						targetFloor = currentFloor + 1
						break
					elseif pFloor < currentFloor then
						targetFloor = currentFloor - 1
						break
					end
				end
				nextFloor = math.clamp(targetFloor, 1, Config.Map.FloorsToGenerate)

				if nextFloor ~= currentFloor then
					local newBaseY = -(nextFloor - 1) * Config.Map.FloorSeparation
					entity:SetPrimaryPartCFrame(CFrame.new(
						entity.PrimaryPart.Position.X,
						newBaseY + 4,
						entity.PrimaryPart.Position.Z
					))
					currentFloor = nextFloor
					print("[DecibelAI] Transitioned to floor", currentFloor, "| Difficulty:", string.format("%.1fx", getDifficultyMult()))
				end

				currentState = State.PATROL
				humanoid.WalkSpeed = getScaledSpeed(AC.PatrolSpeed)
				lastFloorTransition = tick()
			end
		end
	end
end

---------------------------------------------------------------------------
-- SPAWN AND MAIN LOOP
---------------------------------------------------------------------------
local function start()
	print("[DecibelAI] Waiting", AC.SpawnDelay, "seconds before spawning...")
	task.wait(AC.SpawnDelay)

	entity = createEntityModel()

	-- Spawn on the same floor as the first player
	local firstPlayer = Players:GetPlayers()[1]
	if firstPlayer then
		currentFloor = firstPlayer:GetAttribute("CurrentFloor") or 1
	end

	local spawnPos = getRandomPatrolTarget()
	entity:SetPrimaryPartCFrame(CFrame.new(spawnPos))
	entity.Parent = workspace

	currentState = State.PATROL
	lastFloorTransition = tick()
	print("[DecibelAI] The Decibel has spawned on floor", currentFloor, "| Difficulty:", string.format("%.1fx", getDifficultyMult()))

	while entity and entity.Parent do
		aiTick()
		task.wait(0.3)
	end
end

start()
