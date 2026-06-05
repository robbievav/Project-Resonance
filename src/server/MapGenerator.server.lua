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
-- DECIBEL SENSOR
-- DecibelTracker template is synced directly via default.project.json from Rojo
---------------------------------------------------------------------------


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
		local floorIndex = math.floor((25 - (y - MC.MultiplayerBaseY)) / MC.FloorSeparation) + 1
		return math.clamp(floorIndex, 1, MC.MultiplayerFloors)
	else
		local floorIndex = math.floor((25 - y) / MC.FloorSeparation) + 1
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
-- KEY TRACKER TEMPLATE GETTER / DYNAMIC GENERATOR
---------------------------------------------------------------------------
local function getOrCreateKeyTrackerTemplate()
	local ServerStorage = game:GetService("ServerStorage")
	local existing = ServerStorage:FindFirstChild("KeyTracker")
	if existing then return existing end

	print("[MapGenerator] KeyTracker template not found in ServerStorage. Generating dynamically...")
	local tool = Instance.new("Tool")
	tool.Name = "KeyTracker"
	tool.RequiresHandle = true

	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1.2, 0.8, 0.4)
	handle.Color = Color3.fromRGB(200, 160, 40)
	handle.Material = Enum.Material.Metal
	handle.Anchored = false
	handle.CanCollide = false
	handle.Parent = tool

	local screen = Instance.new("Part")
	screen.Name = "Screen"
	screen.Size = Vector3.new(0.8, 0.6, 0.05)
	screen.Color = Color3.fromRGB(30, 30, 10)
	screen.Material = Enum.Material.Glass
	screen.Anchored = false
	screen.CanCollide = false
	screen.Parent = tool

	local starterPlayer = game:GetService("StarterPlayer")
	local starterScripts = starterPlayer:FindFirstChild("StarterPlayerScripts")
	local clientFolder = starterScripts and starterScripts:FindFirstChild("Client")
	local radarScript = clientFolder and clientFolder:FindFirstChild("KeyRadarScript")
	
	if radarScript then
		local clone = radarScript:Clone()
		clone.Name = "RadarScript"
		clone.Parent = tool
	else
		warn("[MapGenerator] KeyRadarScript not found under StarterPlayerScripts.Client!")
	end

	tool.Parent = ServerStorage
	return tool
end

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
	print("[Server teleportToFloor] Initiated for player:", player.Name, "TargetFloor:", targetFloor)
	if elevatorCooldown[player] then 
		print("[Server teleportToFloor] Elevator cooldown is active. Aborting.")
		return 
	end
	elevatorCooldown[player] = true

	-- Fail-safe cooldown reset (Clears in 4 seconds no matter what crashes or yields)
	task.delay(4, function()
		elevatorCooldown[player] = nil
		print("[Server teleportToFloor] Cooldown cleared for", player.Name)
	end)

	local char = player.Character
	if not char then 
		print("[Server teleportToFloor] Character model not found!")
		return 
	end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then 
		print("[Server teleportToFloor] HumanoidRootPart not found in character model!")
		return 
	end

	local currentFloor = player:GetAttribute("CurrentFloor") or 1
	local isMultiplayer = player:GetAttribute("MultiplayerActive") == true

	-- Fire client to show the elevator fade effect
	local elevUsed = events:FindFirstChild("ElevatorUsed")
	if elevUsed then 
		print("[Server teleportToFloor] Firing ElevatorUsed to client:", player.Name)
		elevUsed:FireClient(player, "FadeOut") 
	end

	task.wait(1.2)  -- wait for client fade

	-- Find elevator room on target floor
	local targetRoom = findElevatorRoom(targetFloor, isMultiplayer)
	local spawnCF = targetRoom and getElevatorSpawnCFrame(targetRoom)

	if spawnCF then
		print("[Server teleportToFloor] Teleporting to target room spawn CFrame:", spawnCF)
		root.CFrame = spawnCF
	else
		-- Estimate Y position
		local estimatedY
		if isMultiplayer then
			estimatedY = MC.MultiplayerBaseY - (targetFloor - 1) * MC.FloorSeparation + 5
		else
			estimatedY = -(targetFloor - 1) * MC.FloorSeparation + 5
		end
		root.CFrame = CFrame.new(0, estimatedY + 3, 2)
		warn("[MapGenerator] Could not find elevator room on floor", targetFloor, "— used Y estimate at room center:", root.CFrame)
	end

	task.wait(0.3)

	-- If entering Floor 1, guarantee they have both tools in their backpack/character
	if targetFloor == 1 then
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		local backpack = player:FindFirstChild("Backpack")
		local ServerStorage = game:GetService("ServerStorage")
		
		if backpack and humanoid then
			local dbTemplate = ServerStorage:FindFirstChild("DecibelTracker")
			if dbTemplate and not (backpack:FindFirstChild("DecibelTracker") or char:FindFirstChild("DecibelTracker")) then
				local clone = dbTemplate:Clone()
				local handle = clone:FindFirstChild("Handle")
				local screen = clone:FindFirstChild("Screen")
				if handle and screen then
					screen.CFrame = handle.CFrame * CFrame.new(0, 0.2, -0.21)
					local weld = handle:FindFirstChildOfClass("WeldConstraint") or Instance.new("WeldConstraint")
					weld.Part0 = handle
					weld.Part1 = screen
					weld.Parent = handle
				end
				clone.Parent = backpack
				humanoid:EquipTool(clone)
			end
			
			local ktTemplate = getOrCreateKeyTrackerTemplate()
			if ktTemplate and not (backpack:FindFirstChild("KeyTracker") or char:FindFirstChild("KeyTracker")) then
				local clone = ktTemplate:Clone()
				local handle = clone:FindFirstChild("Handle")
				local screen = clone:FindFirstChild("Screen")
				if handle and screen then
					screen.CFrame = handle.CFrame * CFrame.new(0, 0.2, -0.21)
					local weld = handle:FindFirstChildOfClass("WeldConstraint") or Instance.new("WeldConstraint")
					weld.Part0 = handle
					weld.Part1 = screen
					weld.Parent = handle
				end
				clone.Parent = backpack
			end
		end
	end

	-- Reset all key tokens to ensure fresh state on the new floor
	for name, value in pairs(player:GetAttributes()) do
		if name:find("KeyFloor_") or name:find("SP_KeyFloor_") or name:find("MP_KeyFloor_") then
			player:SetAttribute(name, nil)
		end
	end

	-- Fade back in
	if elevUsed then elevUsed:FireClient(player, "FadeIn") end

	print("[Server teleportToFloor] Teleportation phase complete for", player.Name)
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
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Call Elevator"
		prompt.ObjectText = "Elevator"
		prompt.MaxActivationDistance = 8
		prompt.HoldDuration = 0
		prompt.Parent = panel
	end
	prompt.RequiresLineOfSight = false

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

		if isMultiplayer then
			-- Get all active multiplayer players on this floor
			local activePlayers = {}
			for _, p in ipairs(Players:GetPlayers()) do
				if p:GetAttribute("MultiplayerActive") == true and p:GetAttribute("CurrentFloor") == currentFloor then
					table.insert(activePlayers, p)
				end
			end

			-- Check if they are all in the elevator room (within 16 studs of panel)
			local notInRoom = {}
			for _, p in ipairs(activePlayers) do
				local char = p.Character
				local root = char and char:FindFirstChild("HumanoidRootPart")
				if root then
					local dist = (root.Position - panel.Position).Magnitude
					if dist > 16 then
						table.insert(notInRoom, p.Name)
					end
				else
					table.insert(notInRoom, p.Name)
				end
			end

			if #notInRoom > 0 then
				local elevUsed = events:FindFirstChild("ElevatorUsed")
				if elevUsed then
					elevUsed:FireClient(player, "WaitForTeam", notInRoom)
				end
				return
			end

			-- If all are in the room, descend/win together!
			if targetFloor > maxFloors then
				for _, p in ipairs(activePlayers) do
					task.spawn(function()
						teleportToLobby(p, true)
					end)
				end
			else
				for _, p in ipairs(activePlayers) do
					task.spawn(function()
						teleportToFloor(p, targetFloor)
					end)
				end
			end
		else
			-- Single Player
			if targetFloor > maxFloors then
				teleportToLobby(player, true)
			else
				teleportToFloor(player, targetFloor)
			end
		end
	end)
end

-- Wire up Single Player Start Panel (walk-over / touch)
local function connectSinglePlayerPanel(panel)
	print("[Server connectSinglePlayerPanel] Connecting start panel (walk-over):", panel:GetFullName())
	local prompt = panel:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt:Destroy()
	end

	panel.Touched:Connect(function(otherPart)
		local char = otherPart.Parent
		if not char then return end
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then return end
		local player = Players:GetPlayerFromCharacter(char)
		if not player then return end

		if player:GetAttribute("SinglePlayerActive") then 
			return 
		end
		player:SetAttribute("SinglePlayerActive", true)
		print("[Server Start Game Button] Touch triggered by player:", player.Name)
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
	print("[Server setupPlayer] Initializing player:", player.Name)
	player:SetAttribute("SinglePlayerActive", false)
	player:SetAttribute("MultiplayerActive", false)

	local function handleCharacter(char)
		print("[Server handleCharacter] Character added for player:", player.Name)
		player:SetAttribute("SinglePlayerActive", false)
		player:SetAttribute("MultiplayerActive", false)
		for name, value in pairs(player:GetAttributes()) do
			if name:find("KeyFloor_") or name:find("SP_KeyFloor_") or name:find("MP_KeyFloor_") then
				player:SetAttribute(name, nil)
			end
		end

		-- Force teleporting to the lobby spawn multiple times over the first second of spawning
		-- to guarantee they never get stuck on the roof due to Roblox load-order physics.
		task.spawn(function()
			print("[Server Teleport Loop] Starting snap-to-lobby loop for", player.Name)
			for i = 1, 10 do
				local root = char:FindFirstChild("HumanoidRootPart")
				if root then
					print("[Server Teleport Loop] Snapping", player.Name, "to lobby (Y=103) - Iteration:", i)
					root.CFrame = CFrame.new(0, 103, 0)
					root.AssemblyLinearVelocity = Vector3.new(0, 0, 0)
				else
					print("[Server Teleport Loop] HumanoidRootPart not found for", player.Name, "on iteration:", i)
				end
				task.wait(0.1)
			end
		end)
	end

	player.CharacterAdded:Connect(handleCharacter)
	if player.Character then
		handleCharacter(player.Character)
	end
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
	-- Remove the ProximityPrompt if it exists
	local prompt = pad:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt:Destroy()
	end

	pad.Touched:Connect(function(otherPart)
		local char = otherPart.Parent
		if not char then return end
		local humanoid = char:FindFirstChildOfClass("Humanoid")
		if not humanoid or humanoid.Health <= 0 then return end
		local player = Players:GetPlayerFromCharacter(char)
		if not player then return end

		local ServerStorage = game:GetService("ServerStorage")
		local trackerTemplate = ServerStorage:FindFirstChild("DecibelTracker")
		local keyTrackerTemplate = getOrCreateKeyTrackerTemplate()

		local backpack = player:FindFirstChild("Backpack")
		if backpack then
			-- Give Decibel Tracker
			if trackerTemplate and not (backpack:FindFirstChild("DecibelTracker") or char:FindFirstChild("DecibelTracker")) then
				local clone = trackerTemplate:Clone()
				local handle = clone:FindFirstChild("Handle")
				local screen = clone:FindFirstChild("Screen")
				if handle and screen then
					screen.CFrame = handle.CFrame * CFrame.new(0, 0.2, -0.21)
					local weld = handle:FindFirstChildOfClass("WeldConstraint") or Instance.new("WeldConstraint")
					weld.Part0 = handle
					weld.Part1 = screen
					weld.Parent = handle
				end
				clone.Parent = backpack
				humanoid:EquipTool(clone)
				print("[MapGenerator] DecibelTracker given via Touched to", player.Name)
			end

			-- Give Key Tracker
			if keyTrackerTemplate and not (backpack:FindFirstChild("KeyTracker") or char:FindFirstChild("KeyTracker")) then
				local clone = keyTrackerTemplate:Clone()
				local handle = clone:FindFirstChild("Handle")
				local screen = clone:FindFirstChild("Screen")
				if handle and screen then
					screen.CFrame = handle.CFrame * CFrame.new(0, 0.2, -0.21)
					local weld = handle:FindFirstChildOfClass("WeldConstraint") or Instance.new("WeldConstraint")
					weld.Part0 = handle
					weld.Part1 = screen
					weld.Parent = handle
				end
				clone.Parent = backpack
				print("[MapGenerator] KeyTracker given via Touched to", player.Name)
			end
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

local function cleanPromptIfDisallowed(prompt)
	task.defer(function()
		if not prompt or not prompt.Parent then return end
		
		local parent = prompt.Parent
		local allowed = false
		
		if parent.Name == "Door" then
			allowed = true
		elseif parent.Name == "ElevatorPanel" or game:GetService("CollectionService"):HasTag(parent, "ElevatorPanel") then
			allowed = true
		elseif parent.Parent and (parent.Parent.Name == "ElevatorPanel" or game:GetService("CollectionService"):HasTag(parent.Parent, "ElevatorPanel")) then
			allowed = true
		end
		
		if not allowed then
			print("[MapGenerator] Auto-destroying disallowed ProximityPrompt:", prompt:GetFullName())
			prompt:Destroy()
		end
	end)
end

task.spawn(function()
	task.wait(1)
	cleanHidingElements(workspace)

	-- Clean existing disallowed prompts
	for _, desc in ipairs(workspace:GetDescendants()) do
		if desc:IsA("ProximityPrompt") then
			cleanPromptIfDisallowed(desc)
		end
	end

	workspace.DescendantAdded:Connect(function(desc)
		if desc:IsA("ProximityPrompt") then
			if desc.ActionText == "Hide" or desc.ObjectText:find("Hide") then
				task.defer(function()
					if desc.Parent then desc:Destroy() end
				end)
			else
				cleanPromptIfDisallowed(desc)
			end
		end
		if desc:IsA("BasePart") and desc.Name == "HidingSpot" then
			task.defer(function()
				if desc.Parent then desc:Destroy() end
			end)
		end
	end)
end)

print("[MapGenerator] Elevator system & dynamic cleanup active.")
