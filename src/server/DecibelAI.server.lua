--[[
	DecibelAI.server.lua
	The primary antagonist for Project: Resonance.
	Phase 2: Multi-floor patrol, difficulty scaling, hiding awareness, door breaking.
	Refactored to support dual instances (Single Player & Multiplayer Co-op).
]]

local RunService         = game:GetService("RunService")
local ServerStorage      = game:GetService("ServerStorage")
local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local Players            = game:GetService("Players")
local PathfindingService = game:GetService("PathfindingService")
local TweenService       = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local AC     = Config.AI
local MC     = Config.Map

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
-- AI STATE MACHINE DEFINITION
---------------------------------------------------------------------------
local State = {
	IDLE             = "Idle",
	PATROL           = "Patrol",
	INVESTIGATE      = "Investigate",
	CHASE            = "Chase",
	NEAR_MISS        = "NearMiss",
	FLOOR_TRANSITION = "FloorTransition",
}

---------------------------------------------------------------------------
-- HELPER PROCEDURES
---------------------------------------------------------------------------
local function getRoomGridCell(pos, modeName)
	local spacing = MC.RoomSpacing or 44
	local gridSize = (modeName == "Multiplayer") and MC.MultiplayerGridSize or MC.RoomGridSize
	local halfGrid = (gridSize - 1) / 2
	local col = math.floor((pos.X + halfGrid * spacing + spacing/2) / spacing) + 1
	local row = math.floor((pos.Z + halfGrid * spacing + spacing/2) / spacing) + 1
	return row, col
end

local function moveToward(entity, pos)
	if not entity or not entity.PrimaryPart then return end
	local humanoid = entity:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	local path = PathfindingService:CreatePath({
		AgentRadius = 2,
		AgentHeight = 5,
		AgentCanJump = false,
		WaypointSpacing = 4,
		Costs = {
			Door = 1.0
		}
	})

	local success, errorMessage = pcall(function()
		path:ComputeAsync(entity.PrimaryPart.Position, pos)
	end)

	if success and path.Status == Enum.PathStatus.Success then
		local waypoints = path:GetWaypoints()
		if #waypoints >= 2 then
			local nextPoint = waypoints[2]
			humanoid:MoveTo(nextPoint.Position)
			if nextPoint.Action == Enum.PathWaypointAction.Jump then
				humanoid.Jump = true
			end
		else
			humanoid:MoveTo(pos)
		end
	else
		humanoid:MoveTo(pos)
	end
end

local function tryBreakNearbyDoor(entity, modeFolder)
	if not entity or not entity.PrimaryPart or not modeFolder then return end
	local pos = entity.PrimaryPart.Position
	for _, desc in ipairs(modeFolder:GetDescendants()) do
		if desc:IsA("BasePart") and desc.Name == "Door" and desc.CanCollide then
			local dist = (desc.Position - pos).Magnitude
			if dist < 8 then
				task.spawn(function()
					task.wait(AC.DoorBreakTime)
					if desc and desc.Parent then
						local breakDoor = game:GetService("ServerStorage"):FindFirstChild("BreakDoor")
						if breakDoor then
							breakDoor:Fire(desc, entity.PrimaryPart)
						end
					end
				end)
				return
			end
		end
	end
end

local function tryOpenNearbyDoorNormally(entity, modeFolder)
	if not entity or not entity.PrimaryPart or not modeFolder then return end
	local pos = entity.PrimaryPart.Position
	for _, desc in ipairs(modeFolder:GetDescendants()) do
		if desc:IsA("BasePart") and desc.Name == "Door" and desc.CanCollide then
			local dist = (desc.Position - pos).Magnitude
			if dist < 8 then
				local toggleDoor = game:GetService("ServerStorage"):FindFirstChild("ToggleDoor")
				if toggleDoor then
					toggleDoor:Fire(desc, true, entity.PrimaryPart)
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- DECIBEL CLASS
---------------------------------------------------------------------------
local DecibelAI = {}
DecibelAI.__index = DecibelAI

function DecibelAI.new(modeName, maxFloors, baseY, activeAttributeName)
	local self = setmetatable({}, DecibelAI)
	self.modeName = modeName
	self.maxFloors = maxFloors
	self.baseY = baseY
	self.activeAttributeName = activeAttributeName
	self.modeFolder = mapFolder:FindFirstChild(modeName)
	
	self.entity = nil
	self.currentState = State.IDLE
	self.targetPosition = nil
	self.lastSoundTime = 0
	self.investigateTarget = nil
	self.currentFloor = 1
	self.lastFloorTransition = 0
	self.lastEchoTime = 0
	
	return self
end

function DecibelAI:getAIFloor()
	if not self.entity or not self.entity.PrimaryPart then return 1 end
	local y = self.entity.PrimaryPart.Position.Y
	local floor
	if self.modeName == "Multiplayer" then
		floor = math.floor((-y + MC.MultiplayerBaseY) / MC.FloorSeparation) + 1
	else
		floor = math.floor(-y / MC.FloorSeparation) + 1
	end
	return math.clamp(floor, 1, self.maxFloors)
end

function DecibelAI:getRandomPatrolTarget()
	local floorFolder = self.modeFolder and self.modeFolder:FindFirstChild("Floor_" .. self.currentFloor)
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

function DecibelAI:getDifficultyMult()
	return 1 + (self.currentFloor - 1) * AC.DifficultyPerFloor
end

function DecibelAI:getScaledSpeed(baseSpeed)
	return baseSpeed * self:getDifficultyMult()
end

function DecibelAI:getScaledHearingRadius()
	return AC.HearingRadius * self:getDifficultyMult()
end

function DecibelAI:getScaledLoseInterestTime()
	return math.max(3, AC.LoseInterestTime / self:getDifficultyMult())
end

function DecibelAI:getLoudestSound()
	if not getSoundsFunc then return nil end

	local ok, sounds = pcall(function()
		return getSoundsFunc:Invoke()
	end)

	if not ok or not sounds then return nil end

	local loudest = nil
	local maxVol = 0
	local hearingRadius = self:getScaledHearingRadius()

	for _, s in ipairs(sounds) do
		if s.Volume > maxVol then
			if self.entity and self.entity.PrimaryPart then
				local dist = (s.Position - self.entity.PrimaryPart.Position).Magnitude
				if dist <= hearingRadius then
					-- Segregate sounds vertically: make sure we are on the same vertical mode plane
					local yDiff = math.abs(s.Position.Y - self.entity.PrimaryPart.Position.Y)
					if yDiff < 100 then
						loudest = s
						maxVol = s.Volume
					end
				end
			end
		end
	end

	return loudest
end

function DecibelAI:getNearestPlayer()
	if not self.entity or not self.entity.PrimaryPart then return nil, math.huge end

	local nearest = nil
	local nearestDist = math.huge

	for _, plr in ipairs(Players:GetPlayers()) do
		if plr:GetAttribute(self.activeAttributeName) == true then
			local char = plr.Character
			if char then
				local root = char:FindFirstChild("HumanoidRootPart")
				if root then
					local dist = (root.Position - self.entity.PrimaryPart.Position).Magnitude
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

function DecibelAI:performEcholocation(player)
	local char = player.Character
	if not char or not self.entity or not self.entity.PrimaryPart then return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return end

	local torso = self.entity.PrimaryPart

	local sonarSound = torso:FindFirstChild("SonarSound")
	if not sonarSound then
		sonarSound = Instance.new("Sound")
		sonarSound.Name = "SonarSound"
		sonarSound.SoundId = "rbxassetid://9114234894"
		sonarSound.Volume = 1
		sonarSound.RollOffMaxDistance = 120
		sonarSound.Parent = torso
	end
	sonarSound:Play()

	task.spawn(function()
		local ring = Instance.new("Part")
		ring.Name = "EchoRing"
		ring.Shape = Enum.PartType.Ball
		ring.Material = Enum.Material.Neon
		ring.Color = Color3.fromRGB(0, 150, 255)
		ring.Transparency = 0.5
		ring.Anchored = true
		ring.CanCollide = false
		ring.CFrame = torso.CFrame
		ring.Size = Vector3.new(2, 2, 2)
		ring.Parent = workspace

		local info = TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
		local tween = TweenService:Create(ring, info, {
			Size = Vector3.new(72, 72, 72),
			Transparency = 1,
		})
		tween:Play()
		tween.Completed:Wait()
		ring:Destroy()
	end)

	self.investigateTarget = root.Position
	self.currentState = State.INVESTIGATE
	self.lastSoundTime = tick()

	if AIAlertEvent then
		AIAlertEvent:FireClient(player, {
			Type = "Echolocation",
			Position = torso.Position,
		})
	end
end

function DecibelAI:tick()
	if not self.entity or not self.entity.PrimaryPart then return end
	local humanoid = self.entity:FindFirstChildOfClass("Humanoid")
	if not humanoid then return end

	if self.currentState == State.FLOOR_TRANSITION then return end

	self.currentFloor = self:getAIFloor()
	self.entity:SetAttribute("CurrentFloor", self.currentFloor)

	local loudest = self:getLoudestSound()
	local nearestPlayer, nearestDist = self:getNearestPlayer()

	if loudest then
		self.lastSoundTime = tick()
		self.investigateTarget = loudest.Position

		local chaseThreshold = math.max(0.1, Config.SoundLevels.Run - (self.currentFloor - 1) * 0.25)

		if loudest.Volume >= chaseThreshold then
			self.currentState = State.CHASE
			humanoid.WalkSpeed = self:getScaledSpeed(AC.ChaseSpeed)
		else
			self.currentState = State.INVESTIGATE
			humanoid.WalkSpeed = self:getScaledSpeed(AC.PatrolSpeed + 4)
		end
	end

	-- Same-room Echolocation check
	if nearestPlayer then
		local playerFloor = nearestPlayer:GetAttribute("CurrentFloor") or 1
		if playerFloor == self.currentFloor then
			local playerChar = nearestPlayer.Character
			local playerRoot = playerChar and playerChar:FindFirstChild("HumanoidRootPart")
			if playerRoot then
				local aRow, aCol = getRoomGridCell(self.entity.PrimaryPart.Position, self.modeName)
				local pRow, pCol = getRoomGridCell(playerRoot.Position, self.modeName)

				if aRow == pRow and aCol == pCol then
					if tick() - self.lastEchoTime > (AC.EchoInterval or 4) then
						self.lastEchoTime = tick()
						self:performEcholocation(nearestPlayer)
					end
				end
			end
		end
	end

	-- Lose interest timeout
	if self.currentState == State.INVESTIGATE or self.currentState == State.CHASE then
		if tick() - self.lastSoundTime > self:getScaledLoseInterestTime() then
			self.currentState = State.PATROL
			humanoid.WalkSpeed = self:getScaledSpeed(AC.PatrolSpeed)
			self.investigateTarget = nil
		end
	end

	-- Execute state behavior
	if self.currentState ~= State.CHASE then
		tryOpenNearbyDoorNormally(self.entity, self.modeFolder)
	end

	if self.currentState == State.PATROL then
		if not self.targetPosition or (self.entity.PrimaryPart.Position - self.targetPosition).Magnitude < 5 then
			self.targetPosition = self:getRandomPatrolTarget()
		end
		moveToward(self.entity, self.targetPosition)

		-- Floor transition logic
		if tick() - self.lastFloorTransition > AC.FloorTransitionDelay then
			if math.random() < 0.3 then
				local targetFloor = self.currentFloor
				for _, plr in ipairs(Players:GetPlayers()) do
					if plr:GetAttribute(self.activeAttributeName) == true then
						local pFloor = plr:GetAttribute("CurrentFloor") or 1
						if math.abs(pFloor - self.currentFloor) >= 1 then
							targetFloor = pFloor
							break
						end
					end
				end

				if targetFloor ~= self.currentFloor then
					self.currentState = State.FLOOR_TRANSITION
					self.lastFloorTransition = tick()
					
					task.spawn(function()
						if not self.entity or not self.entity.PrimaryPart then return end
						
						-- Fade out parts
						for _, p in ipairs(self.entity:GetDescendants()) do
							if p:IsA("BasePart") then
								TweenService:Create(p, TweenInfo.new(1.0), {Transparency = 1}):Play()
							end
						end
						
						task.wait(1.0)
						if not self.entity or not self.entity.PrimaryPart then return end
						
						-- Teleport to new floor
						self.currentFloor = targetFloor
						local spawnPos = self:getRandomPatrolTarget()
						self.entity:PivotTo(CFrame.new(spawnPos))
						self.entity:SetAttribute("CurrentFloor", self.currentFloor)
						
						task.wait(0.5)
						if not self.entity or not self.entity.PrimaryPart then return end
						
						-- Fade in parts
						for _, p in ipairs(self.entity:GetDescendants()) do
							if p:IsA("BasePart") then
								TweenService:Create(p, TweenInfo.new(1.0), {Transparency = 0}):Play()
							end
						end
						
						task.wait(1.0)
						if self.currentState == State.FLOOR_TRANSITION then
							self.currentState = State.PATROL
							humanoid.WalkSpeed = self:getScaledSpeed(AC.PatrolSpeed)
						end
					end)
				end
			end
			self.lastFloorTransition = tick()
		end

	elseif self.currentState == State.INVESTIGATE then
		if self.investigateTarget then
			moveToward(self.entity, self.investigateTarget)

			-- Near-miss check
			if nearestDist < AC.NearMissRadius and not loudest then
				self.currentState = State.NEAR_MISS
				if nearestPlayer and AIAlertEvent then
					AIAlertEvent:FireClient(nearestPlayer, {
						Type = "NearMiss",
						Position = self.entity.PrimaryPart.Position,
					})
				end
			end
		end

	elseif self.currentState == State.CHASE then
		if self.investigateTarget then
			moveToward(self.entity, self.investigateTarget)
		end

		tryBreakNearbyDoor(self.entity, self.modeFolder)

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

	elseif self.currentState == State.NEAR_MISS then
		if nearestPlayer and nearestPlayer.Character then
			local playerPos = nearestPlayer.Character:FindFirstChild("HumanoidRootPart")
			if playerPos then
				local awayDir = (self.entity.PrimaryPart.Position - playerPos.Position).Unit
				self.targetPosition = self.entity.PrimaryPart.Position + awayDir * 30
				moveToward(self.entity, self.targetPosition)
			end
		end
		task.delay(1.5, function()
			if self.currentState == State.NEAR_MISS then
				self.currentState = State.PATROL
				humanoid.WalkSpeed = self:getScaledSpeed(AC.PatrolSpeed)
			end
		end)

	end
end

---------------------------------------------------------------------------
-- RUN STATE MACHINE LOOPS
---------------------------------------------------------------------------
local function runAILoop(aiInstance)
	while true do
		task.wait(1)

		local activePlayer = nil
		for _, plr in ipairs(Players:GetPlayers()) do
			if plr:GetAttribute(aiInstance.activeAttributeName) == true then
				activePlayer = plr
				break
			end
		end

		if activePlayer then
			if not aiInstance.entity then
				print("[DecibelAI] Active player found in " .. aiInstance.modeName .. ". Starting spawn delay...")
				
				local startTime = tick()
				local delayAborted = false
				while tick() - startTime < AC.SpawnDelay do
					task.wait(0.5)
					local stillActive = false
					for _, plr in ipairs(Players:GetPlayers()) do
						if plr:GetAttribute(aiInstance.activeAttributeName) == true then
							stillActive = true
							break
						end
					end
					if not stillActive then
						delayAborted = true
						break
					end
				end

				if not delayAborted then
					aiInstance.entity = createEntityModel()
					aiInstance.entity.Name = "TheDecibel_" .. aiInstance.modeName

					aiInstance.currentFloor = activePlayer:GetAttribute("CurrentFloor") or 1
					aiInstance.entity:SetAttribute("CurrentFloor", aiInstance.currentFloor)

					local spawnPos = aiInstance:getRandomPatrolTarget()
					aiInstance.entity:PivotTo(CFrame.new(spawnPos))
					aiInstance.entity.Parent = workspace

					aiInstance.currentState = State.PATROL
					aiInstance.lastFloorTransition = tick()
					print("[DecibelAI] " .. aiInstance.entity.Name .. " spawned on floor " .. aiInstance.currentFloor)

					while aiInstance.entity and aiInstance.entity.Parent do
						local hasActive = false
						for _, plr in ipairs(Players:GetPlayers()) do
							if plr:GetAttribute(aiInstance.activeAttributeName) == true then
								hasActive = true
								break
							end
						end

						if not hasActive then
							print("[DecibelAI] No active " .. aiInstance.modeName .. " players left. Despawning...")
							aiInstance.entity:Destroy()
							aiInstance.entity = nil
							aiInstance.currentState = State.IDLE
							break
						end

						aiInstance:tick()
						task.wait(0.3)
					end
				else
					print("[DecibelAI] Spawn delay aborted for " .. aiInstance.modeName)
				end
			end
		else
			if aiInstance.entity then
				print("[DecibelAI] Fail-safe: Despawning " .. aiInstance.modeName .. " Decibel.")
				aiInstance.entity:Destroy()
				aiInstance.entity = nil
				aiInstance.currentState = State.IDLE
			end
		end
	end
end

---------------------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------------------
local singlePlayerAI = DecibelAI.new("SinglePlayer", MC.FloorsToGenerate, 0, "SinglePlayerActive")
local multiplayerAI = DecibelAI.new("Multiplayer", MC.MultiplayerFloors, MC.MultiplayerBaseY, "MultiplayerActive")

task.spawn(function()
	runAILoop(singlePlayerAI)
end)

task.spawn(function()
	runAILoop(multiplayerAI)
end)

print("[DecibelAI] Dual AI loops active.")
