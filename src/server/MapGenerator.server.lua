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

	local currentFloor = player:GetAttribute("CurrentFloor") or 1

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

	-- Clear the key for the floor they just left — must find a new one each floor
	player:SetAttribute("KeyFloor_" .. currentFloor, nil)

	-- Fade back in
	if elevUsed then elevUsed:FireClient(player, "FadeIn") end

	-- Cooldown
	task.delay(3, function()
		elevatorCooldown[player] = nil
	end)

	print("[MapGenerator]", player.Name, "moved to floor", targetFloor)
end

local function teleportToLobby(player, isVictory)
	if elevatorCooldown[player] then return end
	elevatorCooldown[player] = true

	local char = player.Character
	if not char then elevatorCooldown[player] = nil; return end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then elevatorCooldown[player] = nil; return end

	local currentFloor = player:GetAttribute("CurrentFloor") or 1

	-- Fire client to show transition / victory screen
	local elevUsed = events:FindFirstChild("ElevatorUsed")
	if elevUsed then
		if isVictory then
			elevUsed:FireClient(player, "Victory")
		else
			elevUsed:FireClient(player, "FadeOut")
		end
	end

	task.wait(1.5)  -- wait for client transition screen

	-- Find Lobby SpawnLocation in GeneratedMap
	local lobbyFolder = mapFolder:FindFirstChild("Lobby")
	local spawnLoc = lobbyFolder and lobbyFolder:FindFirstChild("LobbySpawn")

	if spawnLoc then
		root.CFrame = spawnLoc.CFrame + Vector3.new(0, 3, 0)
	else
		root.CFrame = CFrame.new(0, 103, 0)
		warn("[MapGenerator] LobbySpawn not found during teleport to lobby!")
	end

	-- Clear keys and single player status
	player:SetAttribute("SinglePlayerActive", false)
	player:SetAttribute("KeyFloor_" .. currentFloor, nil)

	task.wait(0.3)

	-- Fade back in
	if elevUsed then elevUsed:FireClient(player, "FadeIn") end

	-- Cooldown
	task.delay(3, function()
		elevatorCooldown[player] = nil
	end)

	print("[MapGenerator]", player.Name, "returned to lobby. Victory:", isVictory)
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
			-- Escaped the facility (Victory!)
			teleportToLobby(player, true)
			return
		end

		teleportToFloor(player, targetFloor)
	end)
end

-- Wire up Single Player Start Panel
local function connectSinglePlayerPanel(panel)
	local prompt = panel:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then return end

	prompt.Triggered:Connect(function(player)
		if player:GetAttribute("SinglePlayerActive") then return end
		player:SetAttribute("SinglePlayerActive", true)
		teleportToFloor(player, 1)
	end)
end

-- Connect existing panels
for _, panel in ipairs(CollectionService:GetTagged("ElevatorPanel")) do
	connectElevatorPanel(panel)
end
for _, panel in ipairs(CollectionService:GetTagged("SinglePlayerStartPanel")) do
	connectSinglePlayerPanel(panel)
end

-- Connect future panels (if map regenerated at runtime)
CollectionService:GetInstanceAddedSignal("ElevatorPanel"):Connect(connectElevatorPanel)
CollectionService:GetInstanceAddedSignal("SinglePlayerStartPanel"):Connect(connectSinglePlayerPanel)

-- Handle player joining and respawning: ensure SinglePlayerActive = false
local function setupPlayer(player)
	player:SetAttribute("SinglePlayerActive", false)
	player.CharacterAdded:Connect(function(char)
		player:SetAttribute("SinglePlayerActive", false)
		for name, value in pairs(player:GetAttributes()) do
			if name:find("KeyFloor_") then
				player:SetAttribute(name, nil)
			end
		end
	end)
end

Players.PlayerAdded:Connect(setupPlayer)
for _, player in ipairs(Players:GetPlayers()) do
	setupPlayer(player)
end

-- Cleanup on leave
Players.PlayerRemoving:Connect(function(player)
	elevatorCooldown[player] = nil
end)

---------------------------------------------------------------------------
-- RUNTIME CLEANUP OF HIDING SPOTS / PROMPTS (Fail-safe for leftover geometry)
---------------------------------------------------------------------------
local function cleanHidingElements(parent)
	for _, desc in ipairs(parent:GetDescendants()) do
		if desc:IsA("ProximityPrompt") and (desc.ActionText == "Hide" or desc.ObjectText:find("Hide")) then
			desc:Destroy()
		end
		if desc:IsA("BasePart") and desc.Name == "HidingSpot" then
			desc:Destroy()
		end
	end
end

task.spawn(function()
	task.wait(1)
	cleanHidingElements(workspace)

	-- Destroy any prompts added dynamically (e.g. cloned from furniture models)
	workspace.DescendantAdded:Connect(function(desc)
		if desc:IsA("ProximityPrompt") and (desc.ActionText == "Hide" or desc.ObjectText:find("Hide")) then
			task.defer(function()
				if desc.Parent then desc:Destroy() end
			end)
		end
		if desc:IsA("BasePart") and desc.Name == "HidingSpot" then
			task.defer(function()
				if desc.Parent then desc:Destroy() end
			end)
		end
	end)
end)

print("[MapGenerator] Elevator system & dynamic cleanup active.")
