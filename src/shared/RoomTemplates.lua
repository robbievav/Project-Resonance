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
	HidingSpots = {}, -- nowhere to hide
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
	HidingSpots = {
		{ Type = "UnderDesk", Offset = Vector3.new(-6, 0, -4), Rotation = 0 },
		{ Type = "UnderDesk", Offset = Vector3.new(4, 0, -4), Rotation = 180 },
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
	HidingSpots = {
		{ Type = "Locker", Offset = Vector3.new(-3, 0, -6), Rotation = 0 },
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
	HidingSpots = {},
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
	HidingSpots = {
		{ Type = "Locker", Offset = Vector3.new(-9, 0, 0), Rotation = -90 },
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
		fixture("ElevatorPanel", 5.85, 3, 0, 90),
	},
	HidingSpots = {},
}

-------------------------------------------------------------------------------
-- STORAGE ROOM — shelves, crates, dim lighting
-------------------------------------------------------------------------------
RoomTemplates.StorageRoom = {
	Name = "StorageRoom",
	SizeMultiplier = Vector3.new(1.5, 1, 1.5),
	FloorMaterial  = Config.Materials.Floor,
	FloorColor     = Config.Colors.DarkConcrete,
	WallMaterial   = Config.Materials.Wall,
	WallColor      = Config.Colors.DarkConcrete,
	CeilingColor   = Config.Colors.DarkConcrete,
	Doors = {
		door("NegZ", 0),
	},
	Fixtures = {
		fixture("DimBulb", 0, 11, 0),
		fixture("DimBulb", -6, 11, -5),
	},
	Furniture = {
		fixture("ShelfUnit", -7, 0, -6, 0),
		fixture("ShelfUnit", -7, 0,  0, 0),
		fixture("ShelfUnit",  7, 0, -6, 180),
		fixture("ShelfUnit",  7, 0,  3, 180),
		fixture("Crate",      0, 0, -5, 15),
		fixture("Crate",      2, 0, -3, -10),
		fixture("Barrel",    -3, 0,  6, 0),
		fixture("Locker",     5, 0,  7, 90),
	},
	HidingSpots = {
		{ Type = "Locker", Offset = Vector3.new(5, 0, 7), Rotation = 90 },
		{ Type = "ShelfCrawl", Offset = Vector3.new(-7, 0, -3), Rotation = 0 },
	},
}

-------------------------------------------------------------------------------
-- LABORATORY — lab benches, chemical equipment, broken glass
-------------------------------------------------------------------------------
RoomTemplates.Laboratory = {
	Name = "Laboratory",
	SizeMultiplier = Vector3.new(2, 1, 1.5),
	FloorMaterial  = "Marble",
	FloorColor     = Config.Colors.LabWhite,
	WallMaterial   = Config.Materials.Wall,
	WallColor      = Config.Colors.LabWhite,
	CeilingColor   = Config.Colors.CeilingPanel,
	Doors = {
		door("NegZ", -4),
		door("PosX", 0),
	},
	Fixtures = {
		fixture("FluorescentLight", -6, 11.5, 0),
		fixture("FluorescentLight",  6, 11.5, 0),
	},
	Furniture = {
		fixture("LabBench", -8, 0, -4, 0),
		fixture("LabBench", -8, 0,  4, 0),
		fixture("LabBench",  4, 0, -4, 180),
		fixture("FilingCabinet", 10, 0, -8, 90),
		fixture("Chair",   -6, 0, -4, 30),
		fixture("Chair",    6, 0, -4, -30),
	},
	HidingSpots = {
		{ Type = "UnderDesk", Offset = Vector3.new(-8, 0, 4), Rotation = 0 },
	},
}

-------------------------------------------------------------------------------
-- BATHROOM — tiled floor, stall partitions, dripping faucets
-------------------------------------------------------------------------------
RoomTemplates.Bathroom = {
	Name = "Bathroom",
	SizeMultiplier = Vector3.new(1.2, 0.9, 1),
	FloorMaterial  = Config.Materials.Tile,
	FloorColor     = Config.Colors.TileWhite,
	WallMaterial   = Config.Materials.Tile,
	WallColor      = Config.Colors.TileWhite,
	CeilingColor   = Config.Colors.CeilingPanel,
	Doors = {
		door("NegZ", 0),
	},
	Fixtures = {
		fixture("FluorescentLight", 0, 10, 0),
		fixture("Pipe", -4, 9, 0),
	},
	Furniture = {
		fixture("BathroomStall", -5, 0, -3, 0),
		fixture("BathroomStall", -5, 0,  3, 0),
		fixture("BathroomStall",  0, 0, -3, 0),
		fixture("BathroomSink",   5, 0,  0, 90),
	},
	HidingSpots = {
		{ Type = "StallHide", Offset = Vector3.new(-5, 0, 3), Rotation = 0 },
		{ Type = "StallHide", Offset = Vector3.new(0, 0, -3), Rotation = 0 },
	},
}

-------------------------------------------------------------------------------
-- SERVER ROOM — tall server racks, blue glow, cable trays
-------------------------------------------------------------------------------
RoomTemplates.ServerRoom = {
	Name = "ServerRoom",
	SizeMultiplier = Vector3.new(1.5, 1.2, 2),
	FloorMaterial  = Config.Materials.MetalFloor,
	FloorColor     = Config.Colors.MetalGrate,
	WallMaterial   = Config.Materials.Wall,
	WallColor      = Config.Colors.ServerBlue,
	CeilingColor   = Config.Colors.DarkConcrete,
	Doors = {
		door("NegZ", 0),
	},
	Fixtures = {
		fixture("DimBulb", 0, 13, 0),
		fixture("Pipe",   -6, 13, 0),
		fixture("Pipe",    6, 13, 0),
	},
	Furniture = {
		fixture("ServerRack", -7, 0, -8, 0),
		fixture("ServerRack", -7, 0, -2, 0),
		fixture("ServerRack", -7, 0,  4, 0),
		fixture("ServerRack",  7, 0, -8, 180),
		fixture("ServerRack",  7, 0, -2, 180),
		fixture("ServerRack",  7, 0,  4, 180),
		fixture("Console",     0, 0,  8, 0),
	},
	HidingSpots = {
		{ Type = "RackGap", Offset = Vector3.new(-7, 0, 1), Rotation = 0 },
		{ Type = "RackGap", Offset = Vector3.new(7, 0, 1), Rotation = 180 },
	},
}

-------------------------------------------------------------------------------
-- STAIRWELL — vertical shaft connecting floors
-------------------------------------------------------------------------------
RoomTemplates.Stairwell = {
	Name = "Stairwell",
	SizeMultiplier = Vector3.new(1, 2, 1),  -- extra tall
	FloorMaterial  = Config.Materials.Wall,
	FloorColor     = Config.Colors.DarkConcrete,
	WallMaterial   = Config.Materials.Wall,
	WallColor      = Config.Colors.DarkConcrete,
	CeilingColor   = Config.Colors.DarkConcrete,
	IsStairwell    = true,
	Doors = {
		door("NegZ", 0),
	},
	Fixtures = {
		fixture("DimBulb", 0, 20, 0),
		fixture("DimBulb", 0, 10, 0),
	},
	Furniture = {},
	HidingSpots = {},
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
