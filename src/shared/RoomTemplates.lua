--[[
	RoomTemplates.lua — Defines room archetype blueprints for the procedural generator.
	Each template specifies dimensions, door positions, fixture spots, and furniture lists.
]]

local Config = require(script.Parent.Config)

local RoomTemplates = {}

-------------------------------------------------------------------------------
-- HELPER: Shorthand for a door slot definition
-------------------------------------------------------------------------------
local function door(wallSide, offset)
	return { Wall = wallSide, Offset = offset }
end

-- Fixture: { Type, Offset (Vector3 from room origin), Rotation (Y degrees) }
local function fixture(fType, ox, oy, oz, rot)
	return { Type = fType, Offset = Vector3.new(ox, oy, oz), Rotation = rot or 0 }
end

-------------------------------------------------------------------------------
-- HALLWAY — long, narrow corridor with flickering fluorescents
-------------------------------------------------------------------------------
RoomTemplates.Hallway = {
	Name = "Hallway",
	SizeMultiplier = Vector3.new(3, 1, 1),   -- 3× long, 1× wide
	FloorMaterial  = Config.Materials.Floor,
	FloorColor     = Config.Colors.FloorTile,
	WallMaterial   = Config.Materials.Wall,
	WallColor      = Config.Colors.WallPaint,
	CeilingColor   = Config.Colors.CeilingPanel,
	Doors = {
		door("NegZ", 0),   -- entrance
		door("PosZ", 0),   -- exit
	},
	Fixtures = {
		fixture("FluorescentLight", 0, 11.5, -8),
		fixture("FluorescentLight", 0, 11.5, 0),
		fixture("FluorescentLight", 0, 11.5, 8),
	},
	Furniture = {},   -- hallways are sparse
}

-------------------------------------------------------------------------------
-- OFFICE — desks, filing cabinets, liminal office furniture
-------------------------------------------------------------------------------
RoomTemplates.Office = {
	Name = "Office",
	SizeMultiplier = Vector3.new(1.5, 1, 1.5),
	FloorMaterial  = Config.Materials.Floor,
	FloorColor     = Config.Colors.FloorTile,
	WallMaterial   = Config.Materials.Wall,
	WallColor      = Config.Colors.WallPaint,
	CeilingColor   = Config.Colors.CeilingPanel,
	Doors = {
		door("NegZ", -3),
	},
	Fixtures = {
		fixture("FluorescentLight", 0, 11.5, 0),
		fixture("FluorescentLight", -6, 11.5, 5),
	},
	Furniture = {
		fixture("Desk",          -6, 0, -4, 0),
		fixture("Desk",          -6, 0,  4, 0),
		fixture("Desk",           4, 0, -4, 180),
		fixture("FilingCabinet",  7, 0, -7, 90),
		fixture("FilingCabinet",  7, 0,  7, 90),
		fixture("Chair",         -4, 0, -4, 30),
		fixture("Chair",         -4, 0,  4, -20),
		fixture("WaterCooler",    7, 0,  0, -90),
	},
}

-------------------------------------------------------------------------------
-- MAINTENANCE TUNNEL — narrow, dark, pipes along ceiling
-------------------------------------------------------------------------------
RoomTemplates.MaintenanceTunnel = {
	Name = "MaintenanceTunnel",
	SizeMultiplier = Vector3.new(2.5, 0.75, 0.6),  -- long and cramped
	FloorMaterial  = Config.Materials.MetalFloor,
	FloorColor     = Config.Colors.MetalGrate,
	WallMaterial   = Config.Materials.Wall,
	WallColor      = Config.Colors.DarkConcrete,
	CeilingColor   = Config.Colors.DarkConcrete,
	Doors = {
		door("NegZ", 0),
		door("PosZ", 0),
	},
	Fixtures = {
		fixture("DimBulb", 0, 7, -6),
		fixture("DimBulb", 0, 7,  6),
		fixture("Pipe",   -2, 8,  0),
		fixture("Pipe",    2, 8,  0),
	},
	Furniture = {
		fixture("Barrel",  2, 0, -4),
		fixture("ToolBox", -2, 0,  5),
	},
}

-------------------------------------------------------------------------------
-- OBSERVATION DECK — open room with windows and consoles
-------------------------------------------------------------------------------
RoomTemplates.ObservationDeck = {
	Name = "ObservationDeck",
	SizeMultiplier = Vector3.new(2, 1, 2),
	FloorMaterial  = Config.Materials.Tile,
	FloorColor     = Config.Colors.FloorTile,
	WallMaterial   = Config.Materials.Wall,
	WallColor      = Config.Colors.WallPaint,
	CeilingColor   = Config.Colors.CeilingPanel,
	Doors = {
		door("NegX", 0),
	},
	Fixtures = {
		fixture("FluorescentLight", 0, 11.5, 0),
		fixture("FluorescentLight", -8, 11.5, -8),
		fixture("FluorescentLight",  8, 11.5,  8),
		fixture("WindowPanel",  10, 5, -8, 90),
		fixture("WindowPanel",  10, 5,  0, 90),
		fixture("WindowPanel",  10, 5,  8, 90),
	},
	Furniture = {
		fixture("Console",  -6, 0, 0, 0),
		fixture("Console",  -6, 0, 6, 0),
		fixture("MonitorBank", 8, 3, -6, 90),
		fixture("Chair",    -4, 0, 0, 0),
		fixture("Chair",    -4, 0, 6, 0),
	},
}

-------------------------------------------------------------------------------
-- SAFE HUB — larger, well-lit, locked entry
-------------------------------------------------------------------------------
RoomTemplates.SafeHub = {
	Name = "SafeHub",
	SizeMultiplier = Vector3.new(2, 1.2, 2),
	FloorMaterial  = Config.Materials.Tile,
	FloorColor     = Config.Colors.FloorTile,
	WallMaterial   = Config.Materials.Wall,
	WallColor      = Config.Colors.WallPaint,
	CeilingColor   = Config.Colors.CeilingPanel,
	IsSafe         = true,             -- AI cannot enter
	Doors = {
		door("NegZ", 0),
	},
	Fixtures = {
		fixture("FluorescentLight", -6, 13, -6),
		fixture("FluorescentLight",  6, 13, -6),
		fixture("FluorescentLight", -6, 13,  6),
		fixture("FluorescentLight",  6, 13,  6),
	},
	Furniture = {
		fixture("Desk",    -8, 0, -8, 0),
		fixture("Desk",     8, 0, -8, 180),
		fixture("Cot",      8, 0,  6, 0),
		fixture("MedKit",  -8, 3,  8, 0),
		fixture("Locker",  -9, 0,  0, -90),
	},
}

-------------------------------------------------------------------------------
-- ELEVATOR — spawn room, placed explicitly on each floor
-------------------------------------------------------------------------------
RoomTemplates.Elevator = {
	Name = "Elevator",
	SizeMultiplier = Vector3.new(0.5, 1.5, 0.5),
	FloorMaterial  = Config.Materials.MetalFloor,
	FloorColor     = Config.Colors.MetalGrate,
	WallMaterial   = Config.Materials.Wall,
	WallColor      = Config.Colors.DarkConcrete,
	CeilingColor   = Config.Colors.DarkConcrete,
	IsSafe         = true,
	Doors = {
		door("PosZ", 0),
	},
	Fixtures = {
		fixture("DimBulb", 0, 14, 0),
	},
	Furniture = {
		fixture("ElevatorPanel", 3, 4, 2, 90),
	},
}

-------------------------------------------------------------------------------
-- Utility: Get a weighted-random room type name (excludes Elevator)
-------------------------------------------------------------------------------
function RoomTemplates.GetRandomType(rng)
	local totalWeight = 0
	for _, w in pairs(Config.RoomWeights) do
		totalWeight = totalWeight + w
	end

	local roll = rng:NextNumber() * totalWeight
	local cumulative = 0
	for name, w in pairs(Config.RoomWeights) do
		cumulative = cumulative + w
		if roll <= cumulative then
			return name
		end
	end
	return "Hallway"  -- fallback
end

return RoomTemplates
