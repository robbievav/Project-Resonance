--[[
	SoundEmitter.server.lua
	Server-authoritative sound event system for Project: Resonance.
	Receives sound events from clients and broadcasts to the Decibel AI.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players           = game:GetService("Players")

local Config = require(ReplicatedStorage.Shared.Config)

---------------------------------------------------------------------------
-- Wait for GameEvents folder from MapGenerator
---------------------------------------------------------------------------
local GameEvents = ReplicatedStorage:WaitForChild("GameEvents", 30)
if not GameEvents then
	warn("[SoundEmitter] GameEvents folder not found!")
	return
end

local SoundEvent = GameEvents:WaitForChild("SoundEvent")

---------------------------------------------------------------------------
-- ACTIVE SOUNDS — a rolling list that the AI reads
---------------------------------------------------------------------------
local ActiveSounds = {}  -- { position, volume, timestamp, player }

local function cleanOldSounds()
	local now = tick()
	local cutoff = Config.AI.SoundMemoryTime
	local cleaned = {}
	for _, s in ipairs(ActiveSounds) do
		if now - s.Timestamp < cutoff then
			table.insert(cleaned, s)
		end
	end
	ActiveSounds = cleaned
end

---------------------------------------------------------------------------
-- PUBLIC API (called by DecibelAI)
---------------------------------------------------------------------------
local SoundEmitter = {}

function SoundEmitter.GetActiveSounds()
	cleanOldSounds()
	return ActiveSounds
end

-- Make the module accessible via a BindableFunction
local getSoundsFunc = Instance.new("BindableFunction")
getSoundsFunc.Name = "GetActiveSounds"
getSoundsFunc.OnInvoke = function()
	return SoundEmitter.GetActiveSounds()
end
getSoundsFunc.Parent = game:GetService("ServerStorage")

---------------------------------------------------------------------------
-- INCOMING CLIENT EVENTS
---------------------------------------------------------------------------
SoundEvent.OnServerEvent:Connect(function(player, data)
	if typeof(data) ~= "table" then return end

	local position = data.Position
	local soundType = data.Type  -- "Walk", "Run", "Crouch", "DoorOpen", etc.

	if not position or not soundType then return end

	-- Look up volume from config
	local volume = Config.SoundLevels[soundType] or 0.3

	local soundEntry = {
		Position  = position,
		Volume    = volume,
		Type      = soundType,
		Timestamp = tick(),
		Player    = player,
	}

	table.insert(ActiveSounds, soundEntry)

	-- Cap the list to avoid memory bloat
	if #ActiveSounds > 100 then
		table.remove(ActiveSounds, 1)
	end
end)

---------------------------------------------------------------------------
-- BINDABLE EVENT: Server-side sounds (doors, etc.)
---------------------------------------------------------------------------
local ServerStorage = game:GetService("ServerStorage")
task.spawn(function()
	local emitEvent = ServerStorage:WaitForChild("EmitSound", 30)
	if emitEvent and emitEvent:IsA("BindableEvent") then
		emitEvent.Event:Connect(function(data)
			if typeof(data) ~= "table" then return end
			table.insert(ActiveSounds, {
				Position  = data.Position,
				Volume    = data.Volume or 0.5,
				Type      = data.Type or "Unknown",
				Timestamp = data.Timestamp or tick(),
				Player    = data.Player,
			})
			if #ActiveSounds > 100 then
				table.remove(ActiveSounds, 1)
			end
		end)
	end
end)

print("[SoundEmitter] Sound event system active.")
