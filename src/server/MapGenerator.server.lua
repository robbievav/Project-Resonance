--[[
	MapGenerator.server.lua
	Runtime companion for the Bootstrap-generated map.
	
	The Bootstrap.lua script (run in Studio Command Bar) creates all permanent
	map geometry. This server script just:
	1. Creates RemoteEvents needed by other systems
	2. Sets up player floor tracking
	3. Validates the GeneratedMap folder exists
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")

local Config = require(ReplicatedStorage.Shared.Config)
local MC = Config.Map

---------------------------------------------------------------------------
-- VALIDATE MAP EXISTS
---------------------------------------------------------------------------
local mapFolder = workspace:FindFirstChild("GeneratedMap")
if not mapFolder then
	warn("[MapGenerator] GeneratedMap folder not found! Run Bootstrap.lua in the Studio Command Bar first.")
	-- Create an empty folder so other scripts don't error out
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
