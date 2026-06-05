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

print("[MapGenerator] GeneratedMap found.")

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
	
	if player:GetAttribute("MultiplayerActive") == true then
		local floorIndex = math.floor((-y + MC.MultiplayerBaseY) / MC.FloorSeparation) + 1
		return math.clamp(floorIndex, 1, MC.MultiplayerFloors)
	else
		local floorIndex = math.floor(-y / MC.FloorSeparation) + 1
		return math.clamp(floorIndex, 1, MC.FloorsToGenerate)
	end
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

local function findElevatorRoom(floorIndex, isMultiplayer)
	local rootFolder = isMultiplayer and mapFolder:FindFirstChild("Multiplayer") or mapFolder:FindFirstChild("SinglePlayer")
	if not rootFolder then return nil end
	local floorFolder = rootFolder:FindFirstChild("Floor_" .. floorIndex)
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
	local isMultiplayer = player:GetAttribute("MultiplayerActive") == true

	-- Fire client to show the elevator fade effect
	local elevUsed = events:FindFirstChild("ElevatorUsed")
	if elevUsed then elevUsed:FireClient(player, "FadeOut") end

	task.wait(1.2)  -- wait for client fade

	-- Find elevator room on target floor
	local targetRoom = findElevatorRoom(targetFloor, isMultiplayer)
	local spawnCF = targetRoom and getElevatorSpawnCFrame(targetRoom)

	if spawnCF then
		root.CFrame = spawnCF
	else
		-- Estimate Y position
		local estimatedY
		if isMultiplayer then
			estimatedY = MC.MultiplayerBaseY - (targetFloor - 1) * MC.FloorSeparation + 5
		else
			estimatedY = -(targetFloor - 1) * MC.FloorSeparation + 5
		end
		root.CFrame = CFrame.new(root.Position.X, estimatedY, root.Position.Z)
		warn("[MapGenerator] Could not find elevator room on floor", targetFloor, "— used Y estimate.")
	end

	task.wait(0.3)

	-- Clear key for the floor they just left
	local keyAttr = isMultiplayer and ("MP_KeyFloor_" .. currentFloor) or ("SP_KeyFloor_" .. currentFloor)
	player:SetAttribute(keyAttr, nil)

	-- Fade back in
	if elevUsed then elevUsed:FireClient(player, "FadeIn") end

	-- Cooldown
	task.delay(3, function()
		elevatorCooldown[player] = nil
	end)

	print("[MapGenerator]", player.Name, "moved to floor", targetFloor, "| Multiplayer:", isMultiplayer)
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

	-- Clear keys and active flags
	player:SetAttribute("SinglePlayerActive", false)
	player:SetAttribute("MultiplayerActive", false)
	player:SetAttribute("SP_KeyFloor_" .. currentFloor, nil)
	player:SetAttribute("MP_KeyFloor_" .. currentFloor, nil)
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
		local isMultiplayer = player:GetAttribute("MultiplayerActive") == true

		-- Check if player has the key for this floor
		local keyAttr = isMultiplayer and ("MP_KeyFloor_" .. currentFloor) or ("SP_KeyFloor_" .. currentFloor)
		local hasKey = player:GetAttribute(keyAttr)
		if not hasKey then
			-- Flash a "Find the key first" message to the client
			local elevUsed = events:FindFirstChild("ElevatorUsed")
			if elevUsed then elevUsed:FireClient(player, "NoKey") end
			return
		end

		local maxFloors = isMultiplayer and MC.MultiplayerFloors or MC.FloorsToGenerate
		if targetFloor > maxFloors then
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

-- Handle player joining and respawning: ensure game states reset
local function setupPlayer(player)
	player:SetAttribute("SinglePlayerActive", false)
	player:SetAttribute("MultiplayerActive", false)
	player.CharacterAdded:Connect(function(char)
		player:SetAttribute("SinglePlayerActive", false)
		player:SetAttribute("MultiplayerActive", false)
		for name, value in pairs(player:GetAttributes()) do
			if name:find("KeyFloor_") or name:find("SP_KeyFloor_") or name:find("MP_KeyFloor_") then
				player:SetAttribute(name, nil)
			end
		end

		-- Teleport player inside the lobby to prevent spawning on the roof
		task.wait(0.1)
		local root = char:FindFirstChild("HumanoidRootPart")
		local lobbySpawn = workspace:FindFirstChild("GeneratedMap") 
			and workspace.GeneratedMap:FindFirstChild("Lobby") 
			and workspace.GeneratedMap.Lobby:FindFirstChild("LobbySpawn")
		if root and lobbySpawn then
			root.CFrame = lobbySpawn.CFrame + Vector3.new(0, 3, 0)
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
-- DECIBEL SENSOR SHOP pad
---------------------------------------------------------------------------
local function connectTrackerShop(pad)
	local prompt = pad:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Equip Sensor"
		prompt.ObjectText = "Decibel Radar"
		prompt.MaxActivationDistance = 10
		prompt.HoldDuration = 0
		prompt.Parent = pad
	end

	prompt.Triggered:Connect(function(player)
		local ServerStorage = game:GetService("ServerStorage")
		local trackerTemplate = ServerStorage:FindFirstChild("DecibelTracker")
		if not trackerTemplate then
			warn("[MapGenerator] DecibelTracker tool template not found in ServerStorage!")
			return
		end

		local backpack = player:FindFirstChild("Backpack")
		if backpack then
			if backpack:FindFirstChild("DecibelTracker") or (player.Character and player.Character:FindFirstChild("DecibelTracker")) then
				return
			end
			local clone = trackerTemplate:Clone()
			clone.Parent = backpack
			print("[MapGenerator] DecibelTracker given to", player.Name)
		end
	end)
end

for _, pad in ipairs(CollectionService:GetTagged("TrackerShopPad")) do
	connectTrackerShop(pad)
end
CollectionService:GetInstanceAddedSignal("TrackerShopPad"):Connect(connectTrackerShop)

---------------------------------------------------------------------------
-- MULTIPLAYER CO-OP QUEUE DETECTOR
---------------------------------------------------------------------------
task.spawn(function()
	local countStart = nil

	while true do
		task.wait(1)

		local pad = CollectionService:GetTagged("MultiplayerCoopPad")[1]
		local textLabels = CollectionService:GetTagged("MultiplayerCoopTextLabel")

		if pad then
			local center = pad.Position + Vector3.new(0, 5, 0)
			local boxSize = Vector3.new(7.6, 10, 5.6)
			
			local params = OverlapParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			params.FilterDescendantsInstances = {}
			
			local parts = workspace:GetPartBoundsInBox(CFrame.new(center), boxSize, params)
			local playersInBox = {}
			
			for _, part in ipairs(parts) do
				local char = part.Parent
				if char and char:FindFirstChild("Humanoid") then
					local player = Players:GetPlayerFromCharacter(char)
					if player and not table.find(playersInBox, player) then
						table.insert(playersInBox, player)
					end
				end
			end
			
			local count = #playersInBox
			
			if count < 4 then
				countStart = nil
				for _, lbl in ipairs(textLabels) do
					lbl.Text = "MULTIPLAYER CO-OP\n[" .. count .. "/4 READY]"
					lbl.TextColor3 = Color3.fromRGB(50, 200, 220)
				end
			else
				if not countStart then
					countStart = tick()
				end
				
				local elapsed = tick() - countStart
				local remaining = math.ceil(5 - elapsed)
				
				if remaining > 0 then
					for _, lbl in ipairs(textLabels) do
						lbl.Text = "MULTIPLAYER CO-OP\n[STARTING IN " .. remaining .. "...]"
						lbl.TextColor3 = Color3.fromRGB(50, 220, 50)
					end
				else
					for _, lbl in ipairs(textLabels) do
						lbl.Text = "MULTIPLAYER CO-OP\n[LAUNCHING...]"
						lbl.TextColor3 = Color3.fromRGB(255, 215, 0)
					end
					
					-- Teleport the 4 players to multiplayer floor 1
					for i = 1, 4 do
						local p = playersInBox[i]
						if p then
							p:SetAttribute("MultiplayerActive", true)
							teleportToFloor(p, 1)
						end
					end
					
					task.wait(2)
					countStart = nil
				end
			end
		end
	end
end)

---------------------------------------------------------------------------
-- RUNTIME CLEANUP OF HIDING SPOTS / PROMPTS
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
