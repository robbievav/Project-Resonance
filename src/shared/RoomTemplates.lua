--[[
	RoomTemplates.lua — Defines room archetype blueprints for the procedural generator.
	6 Unique Rooms + Elevator/Stairwell (special-purpose)
]]

local Config = require(script.Parent.Config)

local RoomTemplates = {}

local function door(wallSide, offset)
	return { Wall = wallSide, Offset = offset }
end

local function fixture(fType, ox, oy, oz, rot)
	return { Type = fType, Offset = Vector3.new(ox, oy, oz), Rotation = rot or 0 }
end

-------------------------------------------------------------------------------
-- ROOM 1: MedBay
-------------------------------------------------------------------------------
RoomTemplates.MedBay = {
	Name = "MedBay",
	SizeMultiplier = Vector3.new(1.5, 1, 1.5),
	FloorMaterial  = Config.Materials.Tile,
	FloorColor     = Config.Colors.TileWhite,
	WallMaterial   = Config.Materials.Wall,
	WallColor      = Config.Colors.WallPaint,
	CeilingColor   = Config.Colors.CeilingPanel,
	Doors = { door("NegZ", 0) },
	Fixtures = {
		fixture("FluorescentLight", -4, 11.5, 0),
		fixture("FluorescentLight", 4, 11.5, 0),
	},
	Furniture = {
		fixture("HospitalBed", -8, 0, -6, 0),
		fixture("HospitalBed", -8, 0, 5, 0),
		fixture("CurtainDivider", -5, 0, 0, 0),
		fixture("MedCabinet", 9, 0, -6, 180),
		fixture("BathroomSink", 9, 0, 4, 180),
		fixture("Desk", 5, 0, 8, 90),
	},
	HidingSpots = {
		{ Type = "BehindCurtain", Offset = Vector3.new(-6, 0, -3), Rotation = 0 },
		{ Type = "UnderBed", Offset = Vector3.new(-9, 0, 7), Rotation = 0 },
	},
}

-------------------------------------------------------------------------------
-- ROOM 2: BreakRoom
-------------------------------------------------------------------------------
RoomTemplates.BreakRoom = {
	Name = "BreakRoom",
	SizeMultiplier = Vector3.new(1.5, 1, 1.5),
	FloorMaterial  = Config.Materials.Floor,
	FloorColor     = Config.Colors.FloorTile,
	WallMaterial   = Config.Materials.Wall,
	WallColor      = Config.Colors.WallPaint,
	CeilingColor   = Config.Colors.CeilingPanel,
	Doors = { door("NegZ", 0) },
	Fixtures = {
		fixture("FluorescentLight", 0, 11.5, 0),
		fixture("FluorescentLight", 0, 11.5, -7),
	},
	Furniture = {
		fixture("VendingMachine", -9, 0, -7, 0),
		fixture("Counter", -9, 0, 4, 0),
		fixture("BreakTable", 0, 0, 0, 0),
		fixture("Chair", -2, 0, 2, 30),
		fixture("Chair", 2, 0, -2, -30),
		fixture("Couch", 8, 0, 0, 180),
		fixture("TrashCan", 5, 0, -8, 0),
	},
	HidingSpots = {
		{ Type = "UnderTable", Offset = Vector3.new(0, 0, 0), Rotation = 0 },
	},
}

-------------------------------------------------------------------------------
-- ROOM 3: ArchiveRoom
-------------------------------------------------------------------------------
RoomTemplates.ArchiveRoom = {
	Name = "ArchiveRoom",
	SizeMultiplier = Vector3.new(1.5, 1, 1.5),
	FloorMaterial  = Config.Materials.Floor,
	FloorColor     = Config.Colors.DarkConcrete,
	WallMaterial   = Config.Materials.Wall,
	WallColor      = Config.Colors.DarkConcrete,
	CeilingColor   = Config.Colors.DarkConcrete,
	Doors = { door("NegZ", 0) },
	Fixtures = {
		fixture("DimBulb", -5, 11, 0),
		fixture("DimBulb", 5, 11, 0),
	},
	Furniture = {
		fixture("FilingCabinet", -7, 0, -7, 0),
		fixture("FilingCabinet", -7, 0, 2, 0),
		fixture("FilingCabinet", 0, 0, -7, 0),
		fixture("FilingCabinet", 0, 0, 2, 0),
		fixture("FilingCabinet", 7, 0, -7, 180),
		fixture("FilingCabinet", 7, 0, 2, 180),
		fixture("Desk", -4, 0, 8, 0),
		fixture("Crate", 8, 0, 8, 15),
	},
	HidingSpots = {
		{ Type = "CabinetRow", Offset = Vector3.new(-4, 0, 0), Rotation = 0 },
		{ Type = "CabinetRow", Offset = Vector3.new(4, 0, 0), Rotation = 0 },
	},
}

-------------------------------------------------------------------------------
-- ROOM 4: SecurityStation
-------------------------------------------------------------------------------
RoomTemplates.SecurityStation = {
	Name = "SecurityStation",
	SizeMultiplier = Vector3.new(1.5, 1, 1.5),
	FloorMaterial  = Config.Materials.Floor,
	FloorColor     = Config.Colors.FloorTile,
	WallMaterial   = Config.Materials.Wall,
	WallColor      = Config.Colors.WallPaint,
	CeilingColor   = Config.Colors.CeilingPanel,
	Doors = { door("NegZ", 0) },
	Fixtures = {
		fixture("FluorescentLight", 0, 11.5, 0),
	},
	Furniture = {
		fixture("Console", -5, 0, -8, 0),
		fixture("Console", 5, 0, -8, 0),
		fixture("Chair", -5, 0, -6, 0),
		fixture("Chair", 5, 0, -6, 0),
		fixture("Locker", 9, 0, -4, 180),
		fixture("Locker", 9, 0, 4, 180),
		fixture("ShelfUnit", -9, 0, 0, 0),
		fixture("Desk", 0, 0, 7, 0),
	},
	HidingSpots = {
		{ Type = "Locker", Offset = Vector3.new(9, 0, 4), Rotation = 180 },
	},
}

-------------------------------------------------------------------------------
-- ROOM 5: MechanicalRoom
-------------------------------------------------------------------------------
RoomTemplates.MechanicalRoom = {
	Name = "MechanicalRoom",
	SizeMultiplier = Vector3.new(1.5, 1, 1.5),
	FloorMaterial  = Config.Materials.MetalFloor,
	FloorColor     = Config.Colors.MetalGrate,
	WallMaterial   = Config.Materials.Wall,
	WallColor      = Config.Colors.DarkConcrete,
	CeilingColor   = Config.Colors.DarkConcrete,
	Doors = { door("NegZ", 0) },
	Fixtures = {
		fixture("DimBulb", 0, 11, 0),
		fixture("Pipe", -4, 11, 0),
		fixture("Pipe", 4, 11, 0),
		fixture("Pipe", 0, 11, -5),
		fixture("Pipe", 0, 11, 5),
	},
	Furniture = {
		fixture("Generator", -6, 0, 0, 0),
		fixture("Barrel", 8, 0, -7, 0),
		fixture("Barrel", 6, 0, -7, 0),
		fixture("ShelfUnit", 9, 0, 5, 180),
		fixture("Crate", -4, 0, -8, 20),
		fixture("ToolBox", 5, 0, 8, 0),
	},
	HidingSpots = {
		{ Type = "BehindGenerator", Offset = Vector3.new(-7, 0, 3), Rotation = 0 },
	},
}

-------------------------------------------------------------------------------
-- ROOM 6: Dormitory
-------------------------------------------------------------------------------
RoomTemplates.Dormitory = {
	Name = "Dormitory",
	SizeMultiplier = Vector3.new(1.5, 1, 1.5),
	FloorMaterial  = Config.Materials.Floor,
	FloorColor     = Config.Colors.FloorTile,
	WallMaterial   = Config.Materials.Wall,
	WallColor      = Config.Colors.WallPaint,
	CeilingColor   = Config.Colors.CeilingPanel,
	Doors = { door("NegZ", 0) },
	Fixtures = {
		fixture("DimBulb", -4, 11, -4),
		fixture("DimBulb", 4, 11, 4),
	},
	Furniture = {
		fixture("Cot", -8, 0, -6, 0),
		fixture("Cot", -8, 0, 3, 0),
		fixture("Cot", 8, 0, -6, 180),
		fixture("Cot", 8, 0, 3, 180),
		fixture("Footlocker", -5, 0, -6, 0),
		fixture("Footlocker", -5, 0, 3, 0),
		fixture("Desk", 5, 0, 8, 90),
	},
	HidingSpots = {
		{ Type = "UnderBed", Offset = Vector3.new(-8, 0, -6), Rotation = 0 },
		{ Type = "UnderBed", Offset = Vector3.new(8, 0, 3), Rotation = 180 },
	},
}

-------------------------------------------------------------------------------
-- SPECIAL: Elevator
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
	Doors = { door("PosZ", 0) },
	Fixtures = { fixture("DimBulb", 0, 14, 0) },
	Furniture = { fixture("ElevatorPanel", 5.85, 3, 0, 90) },
	HidingSpots = {},
}

-------------------------------------------------------------------------------
-- SPECIAL: Stairwell
-------------------------------------------------------------------------------
RoomTemplates.Stairwell = {
	Name = "Stairwell",
	SizeMultiplier = Vector3.new(1, 2, 1),
	FloorMaterial  = Config.Materials.Wall,
	FloorColor     = Config.Colors.DarkConcrete,
	WallMaterial   = Config.Materials.Wall,
	WallColor      = Config.Colors.DarkConcrete,
	CeilingColor   = Config.Colors.DarkConcrete,
	IsStairwell    = true,
	Doors = { door("NegZ", 0) },
	Fixtures = { fixture("DimBulb", 0, 20, 0), fixture("DimBulb", 0, 10, 0) },
	Furniture = {},
	HidingSpots = {},
}

-------------------------------------------------------------------------------
-- Utility: Get a weighted-random room type name
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
		if roll <= cumulative then return name end
	end
	return "MedBay"
end

return RoomTemplates
