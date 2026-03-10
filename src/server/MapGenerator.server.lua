--[[
	MapGenerator.server.lua
	Runtime companion for the Bootstrap-generated map.

	1. Creates RemoteEvents needed by other systems
	2. Sets up player floor tracking
	3. Handles elevator teleportation between floors
	4. Validates the GeneratedMap folder exists
]]

local ReplicatedStorage  = game:GetService("ReplicatedStorage")
local Players            = game:GetService("Players")
local RunService         = game:GetService("RunService")
local CollectionService  = game:GetService("CollectionService")
local TweenService       = game:GetService("TweenService")

local Config = require(ReplicatedStorage.Shared.Config)
local MC = Config.Map

---------------------------------------------------------------------------
-- VALIDATE MAP EXISTS
---------------------------------------------------------------------------
local mapFolder = workspace:FindFirstChild("GeneratedMap")
if not mapFolder then
	warn("[MapGenerator] GeneratedMap not found! Run Bootstrap.lua in Studio first.")
	mapFolder = Instance.new("Folder")
	mapFolder.Name = "GeneratedMap"
	mapFolder.Parent = workspace
end

print("[MapGenerator] GeneratedMap found with", #mapFolder:GetChildren(), "floors.")

---------------------------------------------------------------------------
-- CREATE REMOTE EVENTS
---------------------------------------------------------------------------
local events = Instance.new("Folder")
events.Name = "GameEvents"
events.Parent = ReplicatedStorage

local function makeEvent(name)
	local e = Instance.new("RemoteEvent")
	e.Name = name
	e.Parent = events
	return e
end

makeEvent("SoundEvent")
makeEvent("DoorEvent")
makeEvent("HealthUpdate")
makeEvent("AIAlert")
makeEvent("HideEvent")
makeEvent("BreathingFail")
makeEvent("KeyCollected")
makeEvent("ElevatorUsed")

print("[MapGenerator] GameEvents created.")

---------------------------------------------------------------------------
-- PLAYER FLOOR TRACKING
---------------------------------------------------------------------------
local function getPlayerFloor(player)
	local char = player.Character
	if not char then return 1 end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return 1 end
	local y = root.Position.Y
	local floorIndex = math.floor(-y / MC.FloorSeparation) + 1
	return math.clamp(floorIndex, 1, MC.FloorsToGenerate)
end

RunService.Heartbeat:Connect(function()
	for _, player in ipairs(Players:GetPlayers()) do
		player:SetAttribute("CurrentFloor", getPlayerFloor(player))
	end
end)

print("[MapGenerator] Floor tracking active.")

---------------------------------------------------------------------------
-- ELEVATOR SYSTEM
---------------------------------------------------------------------------
-- Track which players are mid-transition (prevent spamming)
local elevatorCooldown = {}

local function findElevatorRoom(floorIndex)
	local floorFolder = mapFolder:FindFirstChild("Floor_" .. floorIndex)
	if not floorFolder then return nil end
	-- Find room tagged as Elevator
	for _, roomFolder in ipairs(floorFolder:GetChildren()) do
		if roomFolder:GetAttribute("RoomType") == "Elevator" then
			return roomFolder
		end
	end
	-- Fallback: find by name pattern
	for _, roomFolder in ipairs(floorFolder:GetChildren()) do
		if roomFolder.Name:find("Elevator") then
			return roomFolder
		end
	end
	return nil
end

local function getElevatorSpawnCFrame(roomFolder)
	-- Find the floor part of the elevator room to stand on
	for _, part in ipairs(roomFolder:GetDescendants()) do
		if part:IsA("BasePart") and part.Name == "Floor" then
			return CFrame.new(part.Position + Vector3.new(0, part.Size.Y / 2 + 3, 2))
		end
	end
	-- Fallback: use roomFolder's primary part or estimate from children
	local parts = roomFolder:GetChildren()
	for _, p in ipairs(parts) do
		if p:IsA("BasePart") then
			return CFrame.new(p.Position + Vector3.new(0, 5, 2))
		end
	end
	return nil
end

local function teleportToFloor(player, targetFloor)
	if elevatorCooldown[player] then return end
	elevatorCooldown[player] = true

	local char = player.Character
	if not char then elevatorCooldown[player] = nil; return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then elevatorCooldown[player] = nil; return end

	-- Fire client to show the elevator fade effect
	local elevUsed = events:FindFirstChild("ElevatorUsed")
	if elevUsed then elevUsed:FireClient(player, "FadeOut") end

	task.wait(1.2)  -- wait for client fade

	-- Find elevator room on target floor
	local targetRoom = findElevatorRoom(targetFloor)
	local spawnCF = targetRoom and getElevatorSpawnCFrame(targetRoom)

	if spawnCF then
		root.CFrame = spawnCF
	else
		-- Estimate Y position based on floor separation
		local estimatedY = -(targetFloor - 1) * MC.FloorSeparation + 5
		root.CFrame = CFrame.new(root.Position.X, estimatedY, root.Position.Z)
		warn("[MapGenerator] Could not find elevator room on floor", targetFloor, "— used Y estimate.")
	end

	task.wait(0.3)

	-- Fade back in
	if elevUsed then elevUsed:FireClient(player, "FadeIn") end

	-- Cooldown
	task.delay(3, function()
		elevatorCooldown[player] = nil
	end)

	print("[MapGenerator]", player.Name, "moved to floor", targetFloor)
end

-- Wire up all ElevatorPanel ProximityPrompts via CollectionService tag
local function connectElevatorPanel(panel)
	local prompt = panel:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then return end

	prompt.Triggered:Connect(function(player)
		local currentFloor = player:GetAttribute("CurrentFloor") or 1
		local targetFloor = currentFloor + 1

		-- Check if player has the key for this floor
		local hasKey = player:GetAttribute("KeyFloor_" .. currentFloor)
		if not hasKey then
			-- Flash a "Find the key first" message to the client
			local elevUsed = events:FindFirstChild("ElevatorUsed")
			if elevUsed then elevUsed:FireClient(player, "NoKey") end
			return
		end

		if targetFloor > MC.FloorsToGenerate then
			warn("[MapGenerator] No more floors to descend to.")
			return
		end

		teleportToFloor(player, targetFloor)
	end)
end

-- Connect existing panels
for _, panel in ipairs(CollectionService:GetTagged("ElevatorPanel")) do
	connectElevatorPanel(panel)
end

-- Connect future panels (if map regenerated at runtime)
CollectionService:GetInstanceAddedSignal("ElevatorPanel"):Connect(connectElevatorPanel)

-- Cleanup on leave
Players.PlayerRemoving:Connect(function(player)
	elevatorCooldown[player] = nil
end)

print("[MapGenerator] Elevator system active.")
