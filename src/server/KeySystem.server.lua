--[[
	KeySystem.server.lua
	Spawns a ResearchKey item in a random room each floor.
	The elevator won't activate until the player picks up that floor's key.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)

-- Wait for GameEvents (created by MapGenerator)
local GameEvents   = ReplicatedStorage:WaitForChild("GameEvents", 30)
local KeyCollected = GameEvents and GameEvents:WaitForChild("KeyCollected", 10)

local mapFolder = workspace:WaitForChild("GeneratedMap", 30)

---------------------------------------------------------------------------
-- KEY APPEARANCE
---------------------------------------------------------------------------
local KEY_COLOR   = Color3.fromRGB(255, 210, 50)   -- bright gold
local KEY_SIZE    = Vector3.new(0.4, 0.8, 0.1)

local function makeKey(parent, position)
	local keyModel = Instance.new("Model")
	keyModel.Name = "ResearchKey"
	keyModel.Parent = parent

	-- Key body
	local body = Instance.new("Part")
	body.Name    = "KeyBody"
	body.Size    = KEY_SIZE
	body.CFrame  = CFrame.new(position + Vector3.new(0, 1, 0))
	body.Material = Enum.Material.Neon
	body.Color   = KEY_COLOR
	body.Anchored = true
	body.CanCollide = false
	body.CastShadow = false
	body.Parent = keyModel
	keyModel.PrimaryPart = body

	-- Glow
	local light = Instance.new("PointLight")
	light.Brightness = 3
	light.Range      = 12
	light.Color      = KEY_COLOR
	light.Parent     = body

	-- Pickup prompt
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText          = "Pick Up Key"
	prompt.ObjectText          = "Research Key"
	prompt.MaxActivationDistance = 8
	prompt.HoldDuration        = 0
	prompt.Parent              = body

	-- Slow spin via script tag (AtmosphereController handles neon objects,
	-- but we do a simple heartbeat spin here)
	local startCF = body.CFrame
	local conn; conn = game:GetService("RunService").Heartbeat:Connect(function(dt)
		if body.Parent == nil then conn:Disconnect(); return end
		startCF = startCF * CFrame.Angles(0, dt * 1.2, 0)
		body.CFrame = startCF
	end)

	return keyModel, body, prompt
end

---------------------------------------------------------------------------
-- SPAWN KEY ON A FLOOR
---------------------------------------------------------------------------
local spawnedKeys = {}  -- [floorIndex] = {keyModel, floorFolder}

local function spawnKeyOnFloor(floorIndex)
	local floorFolder = mapFolder:FindFirstChild("Floor_" .. floorIndex)
	if not floorFolder then return end

	-- Collect candidate rooms (not Elevator or Stairwell)
	local candidates = {}
	for _, roomFolder in ipairs(floorFolder:GetChildren()) do
		local rtype = roomFolder:GetAttribute("RoomType") or ""
		if rtype ~= "Elevator" and rtype ~= "Stairwell" and roomFolder:IsA("Folder") then
			-- Find a floor part to place the key on
			for _, part in ipairs(roomFolder:GetDescendants()) do
				if part:IsA("BasePart") and part.Name == "Floor" then
					table.insert(candidates, part)
					break
				end
			end
		end
	end

	if #candidates == 0 then
		warn("[KeySystem] No candidate rooms found on floor", floorIndex)
		return
	end

	local chosen = candidates[math.random(1, #candidates)]
	-- Spawn near a random wall corner, not the floor center
	local cornerOffsets = {
		Vector3.new(10, 0, 10), Vector3.new(-10, 0, 10),
		Vector3.new(10, 0, -10), Vector3.new(-10, 0, -10),
	}
	local corner = cornerOffsets[math.random(1, #cornerOffsets)]
	local spawnPos = chosen.Position + Vector3.new(corner.X, chosen.Size.Y / 2 + 1, corner.Z)

	local keyModel, keyBody, prompt = makeKey(floorFolder, spawnPos)
	spawnedKeys[floorIndex] = keyModel

	-- Handle pickup
	prompt.Triggered:Connect(function(player)
		-- Mark player as having the key for this floor
		player:SetAttribute("KeyFloor_" .. floorIndex, true)

		-- Notify client
		if KeyCollected then
			KeyCollected:FireClient(player, floorIndex)
		end

		-- Remove the key from the world
		keyModel:Destroy()
		spawnedKeys[floorIndex] = nil

		print("[KeySystem]", player.Name, "picked up key for floor", floorIndex)
	end)

	print("[KeySystem] Key spawned on floor", floorIndex, "in room:", chosen.Parent.Name)
end

---------------------------------------------------------------------------
-- SPAWN KEYS FOR ALL EXISTING FLOORS
---------------------------------------------------------------------------
task.wait(2)  -- give MapGenerator time to finish setup

local floorCount = #mapFolder:GetChildren()
for i = 1, floorCount do
	spawnKeyOnFloor(i)
end

-- Clean up key state when player leaves
Players.PlayerRemoving:Connect(function(player)
	-- Attributes clean up automatically with the player
end)

print("[KeySystem] Keys spawned for", floorCount, "floors.")
