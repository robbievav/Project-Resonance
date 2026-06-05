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

	-- Larger invisible trigger part for reliable touch detection
	local trigger = Instance.new("Part")
	trigger.Name = "Trigger"
	trigger.Size = Vector3.new(3, 4, 3)
	trigger.CFrame = body.CFrame
	trigger.Transparency = 1
	trigger.Anchored = true
	trigger.CanCollide = false
	trigger.CastShadow = false
	trigger.Parent = keyModel

	return keyModel, trigger
end

---------------------------------------------------------------------------
---------------------------------------------------------------------------
-- SAFE COLLISION-FREE KEY POSITIONING
---------------------------------------------------------------------------
local function findSafeSpawnPosition(roomFolder, floorPart)
	local floorCenter = floorPart.Position
	local floorY = floorCenter.Y + floorPart.Size.Y / 2

	-- List of candidate X, Z offsets to try (first corners, then smaller offsets, then center)
	local candidateOffsets = {
		Vector3.new(10, 0, 10),
		Vector3.new(-10, 0, 10),
		Vector3.new(10, 0, -10),
		Vector3.new(-10, 0, -10),
		Vector3.new(5, 0, 5),
		Vector3.new(-5, 0, 5),
		Vector3.new(5, 0, -5),
		Vector3.new(-5, 0, -5),
		Vector3.new(0, 0, 0),
	}

	-- Shuffle candidates to randomize spawning position
	local shuffled = {}
	local temp = {unpack(candidateOffsets)}
	while #temp > 0 do
		table.insert(shuffled, table.remove(temp, math.random(1, #temp)))
	end

	for _, offset in ipairs(shuffled) do
		-- Test position is 1.5 studs above floor level
		local testPos = floorCenter + Vector3.new(offset.X, floorPart.Size.Y / 2 + 1.5, offset.Z)

		-- Check if the test area intersects with any furniture/props in this room
		local halfSize = Vector3.new(1.0, 1.5, 1.0)
		local params = OverlapParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = {roomFolder}

		local parts = workspace:GetPartBoundsInBox(CFrame.new(testPos), halfSize * 2, params)
		local isSafe = true
		for _, part in ipairs(parts) do
			local name = part.Name:lower()
			if not name:find("floor") and not name:find("wall") and not name:find("ceiling") and not name:find("light") and not name:find("door") and not name:find("stairs") then
				isSafe = false
				break
			end
		end

		if isSafe then
			-- Raycast down to find the exact top surface (either the floor or a low surface like a desk)
			local rayOrigin = floorCenter + Vector3.new(offset.X, 4, offset.Z)
			local rayParams = RaycastParams.new()
			-- Exclude nothing so we can find any valid platform
			local result = workspace:Raycast(rayOrigin, Vector3.new(0, -6, 0), rayParams)
			if result then
				local hitPart = result.Instance
				local hitName = hitPart.Name:lower()
				local heightAboveFloor = result.Position.Y - floorY
				-- Verify the hit height is reasonable (not high ceilings/walls) and it belongs to the room
				if heightAboveFloor >= -0.1 and heightAboveFloor < 4.0 and (hitName == "floor" or hitPart:IsDescendantOf(roomFolder)) then
					-- Place key 1.5 studs above hit surface (since makeKey adds 1.0, we return Y with 0.5 offset)
					return result.Position + Vector3.new(0, 0.5, 0)
				end
			end
		end
	end

	-- Fallback to a default known safe position above floor center
	warn("[KeySystem] Could not find a safe collision-free spawn position for room: " .. roomFolder.Name .. ". Falling back to center.")
	return floorCenter + Vector3.new(0, floorPart.Size.Y / 2 + 1.0, 0)
end

---------------------------------------------------------------------------
-- SPAWN KEYS BY FOLDER
---------------------------------------------------------------------------
local function spawnKeysInFolder(folder, isMultiplayer)
	for _, floorFolder in ipairs(folder:GetChildren()) do
		if floorFolder.Name:find("Floor_") then
			local floorIndex = tonumber(floorFolder.Name:match("%d+"))
			if floorIndex then
				local candidates = {}
				for _, roomFolder in ipairs(floorFolder:GetChildren()) do
					local rtype = roomFolder:GetAttribute("RoomType") or roomFolder.Name
					if rtype ~= "Elevator" and rtype ~= "Stairwell" and roomFolder:IsA("Folder") then
						for _, part in ipairs(roomFolder:GetDescendants()) do
							if part:IsA("BasePart") and part.Name == "Floor" then
								table.insert(candidates, part)
								break
							end
						end
					end
				end

				if #candidates > 0 then
					local chosen = candidates[math.random(1, #candidates)]
					local spawnPos = findSafeSpawnPosition(chosen.Parent, chosen)

					local keyModel, keyTrigger = makeKey(floorFolder, spawnPos)

					local isPickedUp = false
					keyTrigger.Touched:Connect(function(otherPart)
						if isPickedUp then return end
						local char = otherPart.Parent
						if not char then return end
						local humanoid = char:FindFirstChildOfClass("Humanoid")
						if not humanoid or humanoid.Health <= 0 then return end
						local player = Players:GetPlayerFromCharacter(char)
						if not player then return end

						isPickedUp = true

						if isMultiplayer then
							-- Share key with all active multiplayer players on this floor
							for _, p in ipairs(Players:GetPlayers()) do
								if p:GetAttribute("MultiplayerActive") == true and p:GetAttribute("CurrentFloor") == floorIndex then
									p:SetAttribute("MP_KeyFloor_" .. floorIndex, true)
									if KeyCollected then
										KeyCollected:FireClient(p, floorIndex)
									end
								end
							end
							print("[KeySystem]", player.Name, "walked over and picked up multiplayer key for floor", floorIndex, "(Shared with team)")
						else
							-- Single Player key
							player:SetAttribute("SP_KeyFloor_" .. floorIndex, true)
							if KeyCollected then
								KeyCollected:FireClient(player, floorIndex)
							end
							print("[KeySystem]", player.Name, "walked over and picked up single-player key for floor", floorIndex)
						end

						keyModel:Destroy()
					end)

					print("[KeySystem] Key spawned on", isMultiplayer and "Multiplayer" or "SinglePlayer", "floor", floorIndex, "in room:", chosen.Parent.Name)
				else
					warn("[KeySystem] No candidate rooms found on floor", floorIndex)
				end
			end
		end
	end
end

---------------------------------------------------------------------------
-- INITIALIZATION
---------------------------------------------------------------------------
task.wait(2)  -- wait for map generator setup

local spFolder = mapFolder:FindFirstChild("SinglePlayer")
if spFolder then
	spawnKeysInFolder(spFolder, false)
end

local mpFolder = mapFolder:FindFirstChild("Multiplayer")
if mpFolder then
	spawnKeysInFolder(mpFolder, true)
end

print("[KeySystem] Walk-over key pickup system active.")
print("[KeySystem] Key spawning sequence complete.")
