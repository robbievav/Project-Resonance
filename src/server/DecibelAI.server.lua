--[[
	DecibelAI.server.lua
	The primary antagonist for Project: Resonance.
	A blind entity that navigates via 3D directional hearing.
	Behaviors: Patrol → Investigate sound → Chase → Near-miss wander.
]]

local RunService        = game:GetService("RunService")
local ServerStorage     = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")

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

local GameEvents  = ReplicatedStorage:WaitForChild("GameEvents", 30)
local AIAlertEvent = GameEvents and GameEvents:WaitForChild("AIAlert")

local getSoundsFunc = ServerStorage:WaitForChild("GetActiveSounds", 30)

---------------------------------------------------------------------------
-- CREATE THE ENTITY MODEL
---------------------------------------------------------------------------
local function createEntityModel()
	local model = Instance.new("Model")
	model.Name = "TheDecibel"

	-- Main body — tall, dark, unsettling silhouette
	local torso = Instance.new("Part")
	torso.Name = "HumanoidRootPart"
	torso.Anchored = false
	torso.CanCollide = true
	torso.Size = Vector3.new(3, 7, 2)
	torso.Color = Color3.fromRGB(15, 12, 10)
	torso.Material = Enum.Material.SmoothPlastic
	torso.Transparency = 0
	torso.Parent = model

	-- Head — featureless, slightly elongated
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

	-- Subtle glow eyes (barely visible — unsettling)
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

	-- Humanoid (for pathfinding)
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
	IDLE       = "Idle",
	PATROL     = "Patrol",
	INVESTIGATE = "Investigate",
	CHASE      = "Chase",
	NEAR_MISS  = "NearMiss",
}

local entity = nil
local currentState = State.IDLE
local targetPosition = nil
local lastSoundTime = 0
local investigateTarget = nil

---------------------------------------------------------------------------
-- PATROL: Pick a random walkable position on the floor
---------------------------------------------------------------------------
local function getRandomPatrolTarget()
	local floorFolder = mapFolder:FindFirstChild("Floor_1")
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
-- MOVE TOWARD TARGET
---------------------------------------------------------------------------
local function moveToward(pos)
	if not entity or not entity.PrimaryPart then return end
	local humanoid = entity:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid:MoveTo(pos)
	end
end

---------------------------------------------------------------------------
-- FIND LOUDEST SOUND
---------------------------------------------------------------------------
local function getLoudestSound()
	if not getSoundsFunc then return nil end

	local ok, sounds = pcall(function()
		return getSoundsFunc:Invoke()
	end)

	if not ok or not sounds then return nil end

	local loudest = nil
	local maxVol = 0

	for _, s in ipairs(sounds) do
		if s.Volume > maxVol then
			-- Check if within hearing radius
			if entity and entity.PrimaryPart then
				local dist = (s.Position - entity.PrimaryPart.Position).Magnitude
				if dist <= AC.HearingRadius then
					loudest = s
					maxVol = s.Volume
				end
			end
		end
	end

	return loudest
end

---------------------------------------------------------------------------
-- CHECK FOR NEARBY PLAYERS (for near-miss & chase kill)
---------------------------------------------------------------------------
local function getNearestPlayer()
	if not entity or not entity.PrimaryPart then return nil, math.huge end

	local nearest = nil
	local nearestDist = math.huge

	for _, player in ipairs(Players:GetPlayers()) do
		local char = player.Character
		if char then
			local root = char:FindFirstChild("HumanoidRootPart")
			if root then
				local dist = (root.Position - entity.PrimaryPart.Position).Magnitude
				if dist < nearestDist then
					nearest = player
					nearestDist = dist
				end
			end
		end
	end

	return nearest, nearestDist
end

---------------------------------------------------------------------------
-- AI TICK
---------------------------------------------------------------------------
local function aiTick()
	if not entity or not entity.PrimaryPart then return end
	local humanoid = entity:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local loudest = getLoudestSound()
	local nearestPlayer, nearestDist = getNearestPlayer()

	-- State transitions based on sound
	if loudest then
		lastSoundTime = tick()
		investigateTarget = loudest.Position

		if loudest.Volume >= Config.SoundLevels.Run then
			currentState = State.CHASE
			humanoid.WalkSpeed = AC.ChaseSpeed
		else
			currentState = State.INVESTIGATE
			humanoid.WalkSpeed = AC.PatrolSpeed + 4
		end
	end

	-- Lose interest timeout
	if currentState == State.INVESTIGATE or currentState == State.CHASE then
		if tick() - lastSoundTime > AC.LoseInterestTime then
			currentState = State.PATROL
			humanoid.WalkSpeed = AC.PatrolSpeed
			investigateTarget = nil
		end
	end

	-- Execute state behavior
	if currentState == State.PATROL then
		if not targetPosition or (entity.PrimaryPart.Position - targetPosition).Magnitude < 5 then
			targetPosition = getRandomPatrolTarget()
		end
		moveToward(targetPosition)

	elseif currentState == State.INVESTIGATE then
		if investigateTarget then
			moveToward(investigateTarget)

			-- Near-miss check: close to a hiding player but no sound → wander away
			if nearestDist < AC.NearMissRadius and not loudest then
				currentState = State.NEAR_MISS
				-- Alert client for tension stinger
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
		-- Wander away from the player
		if nearestPlayer and nearestPlayer.Character then
			local playerPos = nearestPlayer.Character:FindFirstChild("HumanoidRootPart")
			if playerPos then
				local awayDir = (entity.PrimaryPart.Position - playerPos.Position).Unit
				targetPosition = entity.PrimaryPart.Position + awayDir * 30
				moveToward(targetPosition)
			end
		end
		-- Return to patrol after moving away
		task.delay(4, function()
			if currentState == State.NEAR_MISS then
				currentState = State.PATROL
				humanoid.WalkSpeed = AC.PatrolSpeed
			end
		end)
	end
end

---------------------------------------------------------------------------
-- SPAWN AND MAIN LOOP
---------------------------------------------------------------------------
local function start()
	print("[DecibelAI] Waiting", AC.SpawnDelay, "seconds before spawning...")
	task.wait(AC.SpawnDelay)

	entity = createEntityModel()

	-- Spawn at a random floor location
	local spawnPos = getRandomPatrolTarget()
	entity:SetPrimaryPartCFrame(CFrame.new(spawnPos))
	entity.Parent = workspace

	currentState = State.PATROL
	print("[DecibelAI] The Decibel has spawned.")

	-- Main AI loop
	while entity and entity.Parent do
		aiTick()
		task.wait(0.3)  -- AI tick rate
	end
end

start()
