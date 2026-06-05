--[[
	Config.lua — Central configuration for Project: Resonance
	All tunable game parameters live here.
]]

local Config = {}

---------------------------------------------------------------------------
-- MAP GENERATION
---------------------------------------------------------------------------
Config.Map = {
	Seed             = 0,          -- 0 = random seed each round
	FloorsToGenerate = 5,          -- 5 floors for Single Player mode
	RoomGridSize     = 5,          -- NxN grid of rooms per floor
	MultiplayerFloors = 10,        -- 10 floors for Multiplayer mode
	MultiplayerGridSize = 7,       -- 7x7 grid of rooms per floor
	MultiplayerBaseY = -500,       -- Starting Y offset for Multiplayer floors
	RoomUnit         = 36,         -- studs per room tile
	HallwayWidth     = 8,          -- studs
	WallHeight       = 12,         -- studs
	WallThickness    = 1,          -- studs
	DoorWidth        = 5,          -- studs
	DoorHeight       = 8,          -- studs
	FloorSeparation  = 50,         -- vertical gap between floors
	ActiveFloorRange = 1,          -- only keep ±N floors loaded
	StairwellGridRow = 2,          -- fixed grid position for stairwells
	StairwellGridCol = 4,
	RoomSpacing      = 44,         -- center-to-center spacing
	LobbyHeight      = 100,        -- vertical Y coordinate for Spawn Hub
}

---------------------------------------------------------------------------
-- ROOM TYPES & WEIGHTS  (higher weight = more common)
---------------------------------------------------------------------------
Config.RoomWeights = {
	MedBay            = 15,
	BreakRoom         = 15,
	ArchiveRoom       = 15,
	SecurityStation   = 12,
	MechanicalRoom    = 15,
	Dormitory         = 15,
	Elevator          = 0,   -- placed explicitly, not randomly
	Stairwell         = 0,   -- placed explicitly
}

---------------------------------------------------------------------------
-- MATERIALS  (Roblox Enum names)
---------------------------------------------------------------------------
Config.Materials = {
	Floor      = "SmoothPlastic",
	Wall       = "Concrete",
	Ceiling    = "SmoothPlastic",
	MetalFloor = "DiamondPlate",
	Pipes      = "Metal",
	Tile       = "Marble",
}

---------------------------------------------------------------------------
-- COLORS  (washed-out 90s palette)
---------------------------------------------------------------------------
Config.Colors = {
	FloorTile     = Color3.fromRGB(160, 155, 145),
	WallPaint     = Color3.fromRGB(195, 190, 180),
	CeilingPanel  = Color3.fromRGB(200, 198, 192),
	MetalGrate    = Color3.fromRGB(100, 100, 105),
	DarkConcrete  = Color3.fromRGB(80, 78, 75),
	Rust          = Color3.fromRGB(140, 85, 55),
	DoorFrame     = Color3.fromRGB(130, 125, 115),
	FluorLight    = Color3.fromRGB(235, 230, 210),
	LabWhite      = Color3.fromRGB(215, 218, 220),
	LabBench      = Color3.fromRGB(55, 55, 60),
	TileWhite     = Color3.fromRGB(210, 210, 205),
	ServerBlue    = Color3.fromRGB(20, 30, 50),
	Crate         = Color3.fromRGB(120, 100, 70),
}

---------------------------------------------------------------------------
-- LIGHTING (per-room overrides)
---------------------------------------------------------------------------
Config.Lighting = {
	FluorescentBrightness = 1.2,
	FluorescentRange      = 30,
	FlickerChance         = 0.25,      -- 25 % of lights flicker
	FlickerMinInterval    = 0.4,
	FlickerMaxInterval    = 3.0,
}

---------------------------------------------------------------------------
-- PLAYER
---------------------------------------------------------------------------
Config.Player = {
	WalkSpeed      = 10,
	RunSpeed       = 18,
	CrouchSpeed    = 5,
	MaxHealth      = 100,
	HealthRegenRate = 0,            -- no passive regen
	HeadBobAmount  = 0.15,          -- studs
	HeadBobSpeed   = 8,             -- cycles / sec while walking
}

---------------------------------------------------------------------------
-- FOOTSTEP SOUND IDS  (placeholder Roblox asset IDs — replace with real ones)
---------------------------------------------------------------------------
Config.FootstepSounds = {
	Concrete   = "rbxasset://sounds/action_footsteps_plastic.mp3",
	Metal      = "rbxasset://sounds/action_footsteps_plastic.mp3",
	Tile       = "rbxasset://sounds/action_footsteps_plastic.mp3",
	Carpet     = "rbxasset://sounds/action_footsteps_plastic.mp3",
	Glass      = "rbxasset://sounds/action_footsteps_plastic.mp3",  -- laboratory
	Granite    = "rbxasset://sounds/action_footsteps_plastic.mp3",  -- stairwells
	Default    = "rbxasset://sounds/action_footsteps_plastic.mp3",
}

---------------------------------------------------------------------------
-- SOUND EMISSION  (decibel scale 0-1)
---------------------------------------------------------------------------
Config.SoundLevels = {
	Walk      = 0.25,
	Run       = 0.70,
	Crouch    = 0.05,
	DoorOpen  = 0.50,
	DoorClose = 0.40,
	ItemDrop  = 0.60,
	DoorBreak = 0.90,
}

---------------------------------------------------------------------------
-- DECIBEL AI
---------------------------------------------------------------------------
Config.AI = {
	SpawnDelay           = 10,        -- seconds after round start
	PatrolSpeed          = 8,
	ChaseSpeed           = 20,
	HearingRadius        = 80,       -- studs
	SoundMemoryTime      = 5,        -- seconds to remember a sound
	NearMissRadius       = 15,       -- studs  (wander-away threshold)
	LoseInterestTime     = 8,        -- seconds without sound → resume patrol
	DifficultyPerFloor   = 0.1,      -- multiplier added per floor
	FloorTransitionDelay = 5,        -- seconds before AI changes floors
	DoorBreakTime        = 1.5,      -- seconds to break through a closed door (CHASE)
	EchoInterval         = 4,        -- seconds between room scans (Echolocation)
}

---------------------------------------------------------------------------
-- ATMOSPHERE / VHS
---------------------------------------------------------------------------
Config.Atmosphere = {
	ScanlineAlpha      = 0.06,
	VHSNoiseAlpha      = 0.03,
	VignetteAlpha      = 0.35,
	FogDensityPerFloor = 0.02,     -- added per floor depth
}

---------------------------------------------------------------------------
-- AUDIO
---------------------------------------------------------------------------
Config.Audio = {
	AmbientDroneId     = "rbxasset://sounds/action_falling.ogg",  -- placeholder
	HeartbeatId        = "rbxassetid://6724333590",
	BreathingId        = "rbxasset://sounds/action_falling.ogg",
	DoorHingeId        = "rbxasset://sounds/action_jump_land.mp3",
	NearMissStingerId  = "rbxassetid://12221967",
	DrippingWaterId    = "rbxassetid://12221967",
	FluorescentHumId   = "rbxassetid://12221967",
	DroneFadeTime      = 2,        -- seconds
}


---------------------------------------------------------------------------
-- FLOOR THEMES (deeper floors = more deteriorated)
---------------------------------------------------------------------------
Config.FloorThemes = {
	{
		Name        = "CleanOffice",
		FloorRange  = {1, 10},
		WallColor   = Color3.fromRGB(195, 190, 180),
		FloorColor  = Color3.fromRGB(160, 155, 145),
		WallMaterial = "Concrete",
		LightMult   = 1.0,
	},
	{
		Name        = "Deteriorating",
		FloorRange  = {11, 25},
		WallColor   = Color3.fromRGB(150, 145, 135),
		FloorColor  = Color3.fromRGB(130, 125, 118),
		WallMaterial = "Concrete",
		LightMult   = 0.7,
	},
	{
		Name        = "Industrial",
		FloorRange  = {26, 40},
		WallColor   = Color3.fromRGB(100, 95, 90),
		FloorColor  = Color3.fromRGB(90, 88, 82),
		WallMaterial = "Slate",
		LightMult   = 0.45,
	},
	{
		Name        = "Abandoned",
		FloorRange  = {41, 50},
		WallColor   = Color3.fromRGB(65, 60, 55),
		FloorColor  = Color3.fromRGB(55, 52, 48),
		WallMaterial = "Slate",
		LightMult   = 0.25,
	},
}

return Config
