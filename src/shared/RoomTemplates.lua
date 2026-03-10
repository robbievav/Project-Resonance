--[[
	RoomTemplates.lua — Defines room archetype blueprints for the procedural generator.
	Each template specifies dimensions, door positions, fixture spots, and furniture lists.
	
	6 Unique Rooms + Elevator/Stairwell (special-purpose)
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
-- ROOM 1: MedBay — Medical facility with hospital beds and supplies
-------------------------------------------------------------------------------
RoomTemplates.MedBay = {
	Name = "MedBay",
	SizeMultiplier = Vector3.new(1.5, 1, 1.5),
	FloorMaterial  = Config.Materials.Tile,
	FloorColor     = Config.Colors.TileWhite,
	WallMaterial   = Config.Materials.Wall,
	WallColor      = Config.Colors.WallPaint,
	CeilingColor   = Config.Colors.CeilingPanel,
	Doors = {
		door("NegZ", 0),
	},
	Fixtures = {
		fixture("FluorescentLight", -4, 11.5, 0),
		fixture("FluorescentLight", 4, 11.5, 0),
	},
	Furniture = {
		-- Hospital beds along left wall
		fixture("HospitalBed", -9, 0, -7, 0),
		fixture("HospitalBed", -9, 0, 0, 0),
		fixture("HospitalBed", -9, 0, 7, 0),
		-- Curtain dividers between beds
		fixture("CurtainDivider", -6, 0, -3, 0),
		fixture("CurtainDivider", -6, 0, 4, 0),
		-- Medicine cabinet and sink on right wall
		fixture("MedCabinet", 10, 0, -8, 180),
		fixture("MedCabinet", 10, 0, -2, 180),
		fixture("BathroomSink", 10, 0, 5, 180),
		-- Doctor station
		fixture("Desk", 5, 0, 8, 90),
		fixture("Chair", 3, 0, 8, 90),
	},
	HidingSpots = {
		{ Type = "BehindCurtain", Offset = Vector3.new(-6, 0, -3), Rotation = 0 },
		{ Type = "UnderBed", Offset = Vector3.new(-9, 0, 7), Rotation = 0 },
	},
}

-------------------------------------------------------------------------------
-- ROOM 2: BreakRoom — Staff lounge with vending machines and seating
-------------------------------------------------------------------------------
RoomTemplates.BreakRoom = {
	Name = "BreakRoom",
	SizeMultiplier = Vector3.new(1.5, 1, 1.5),
	FloorMaterial  = Config.Materials.Floor,
	FloorColor     = Config.Colors.FloorTile,
	WallMaterial   = Config.Materials.Wall,
	WallColor      = Config.Colors.WallPaint,
	CeilingColor   = Config.Colors.CeilingPanel,
	Doors = {
		door("NegZ", 0),
	},
	Fixtures = {
		fixture("FluorescentLight", 0, 11.5, 0),
		fixture("FluorescentLight", 0, 11.5, -7),
	},
	Furniture = {
		-- Vending machines against back wall
		fixture("VendingMachine", -9, 0, -9, 0),
		fixture("VendingMachine", -9, 0, -4, 0),
		-- Counter with microwave
		fixture("Counter", -9, 0, 4, 0),
		fixture("MicrowaveUnit", -9, 3, 4, 0),
		-- Central table with chairs
		fixture("BreakTable", 0, 0, 0, 0),
		fixture("Chair", -2, 0, 2, 30),
		fixture("Chair", 2, 0, 2, -30),
		fixture("Chair", -2, 0, -2, 150),
		fixture("Chair", 2, 0, -2, -150),
		-- Couch along right wall
		fixture("Couch", 9, 0, 0, 180),
		fixture("Couch", 9, 0, 6, 180),
		-- Trash can
		fixture("TrashCan", 5, 0, -9, 0),
	},
	HidingSpots = {
		{ Type = "UnderTable", Offset = Vector3.new(0, 0, 0), Rotation = 0 },
	},
}

-------------------------------------------------------------------------------
-- ROOM 3: ArchiveRoom — Records storage with filing cabinet rows
-------------------------------------------------------------------------------
RoomTemplates.ArchiveRoom = {
	Name = "ArchiveRoom",
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
		fixture("DimBulb", -5, 11, 0),
		fixture("DimBulb", 5, 11, 0),
	},
	Furniture = {
		-- Filing cabinet rows (3 rows running north-south)
		fixture("FilingCabinet", -8, 0, -8, 0),
		fixture("FilingCabinet", -8, 0, -3, 0),
		fixture("FilingCabinet", -8, 0, 2, 0),
		fixture("FilingCabinet", -8, 0, 7, 0),
		fixture("FilingCabinet", 0, 0, -8, 0),
		fixture("FilingCabinet", 0, 0, -3, 0),
		fixture("FilingCabinet", 0, 0, 2, 0),
		fixture("FilingCabinet", 0, 0, 7, 0),
		fixture("FilingCabinet", 8, 0, -8, 180),
		fixture("FilingCabinet", 8, 0, -3, 180),
		fixture("FilingCabinet", 8, 0, 2, 180),
		fixture("FilingCabinet", 8, 0, 7, 180),
		-- Reading desk
		fixture("Desk", -4, 0, 9, 0),
		fixture("Chair", -2, 0, 9, 0),
		-- Box stacks
		fixture("Crate", 9, 0, 9, 15),
		fixture("Crate", 7, 0, 9, -10),
	},
	HidingSpots = {
		{ Type = "CabinetRow", Offset = Vector3.new(-4, 0, 0), Rotation = 0 },
		{ Type = "CabinetRow", Offset = Vector3.new(4, 0, 0), Rotation = 0 },
	},
}

-------------------------------------------------------------------------------
-- ROOM 4: SecurityStation — Guard post with monitors and lockers
-------------------------------------------------------------------------------
RoomTemplates.SecurityStation = {
	Name = "SecurityStation",
	SizeMultiplier = Vector3.new(1.5, 1, 1.5),
	FloorMaterial  = Config.Materials.Floor,
	FloorColor     = Config.Colors.FloorTile,
	WallMaterial   = Config.Materials.Wall,
	WallColor      = Config.Colors.WallPaint,
	CeilingColor   = Config.Colors.CeilingPanel,
	Doors = {
		door("NegZ", 0),
	},
	Fixtures = {
		fixture("FluorescentLight", 0, 11.5, 0),
	},
	Furniture = {
		-- Monitor desks at back
		fixture("Console", -6, 0, -9, 0),
		fixture("Console", 0, 0, -9, 0),
		fixture("Console", 6, 0, -9, 0),
		fixture("Chair", -6, 0, -7, 0),
		fixture("Chair", 0, 0, -7, 0),
		fixture("Chair", 6, 0, -7, 0),
		-- Locker row along right wall
		fixture("Locker", 10, 0, -6, 180),
		fixture("Locker", 10, 0, -1, 180),
		fixture("Locker", 10, 0, 4, 180),
		-- Weapon racks (shelves) on left wall
		fixture("ShelfUnit", -10, 0, -4, 0),
		fixture("ShelfUnit", -10, 0, 4, 0),
		-- Radio desk
		fixture("Desk", 0, 0, 8, 0),
		fixture("ToolBox", 2, 0, 8, 0),
	},
	HidingSpots = {
		{ Type = "Locker", Offset = Vector3.new(10, 0, 4), Rotation = 180 },
	},
}

-------------------------------------------------------------------------------
-- ROOM 5: MechanicalRoom — Boiler/HVAC with pipes and generators
-------------------------------------------------------------------------------
RoomTemplates.MechanicalRoom = {
	Name = "MechanicalRoom",
	SizeMultiplier = Vector3.new(1.5, 1, 1.5),
	FloorMaterial  = Config.Materials.MetalFloor,
	FloorColor     = Config.Colors.MetalGrate,
	WallMaterial   = Config.Materials.Wall,
	WallColor      = Config.Colors.DarkConcrete,
	CeilingColor   = Config.Colors.DarkConcrete,
	Doors = {
		door("NegZ", 0),
	},
	Fixtures = {
		fixture("DimBulb", 0, 11, 0),
		fixture("Pipe", -4, 11, 0),
		fixture("Pipe", 4, 11, 0),
		fixture("Pipe", 0, 11, -5),
		fixture("Pipe", 0, 11, 5),
	},
	Furniture = {
		-- Large generator unit
		fixture("Generator", -7, 0, 0, 0),
		-- Barrels along back wall
		fixture("Barrel", 9, 0, -8, 0),
		fixture("Barrel", 9, 0, -4, 0),
		fixture("Barrel", 7, 0, -8, 0),
		-- Tool shelves
		fixture("ShelfUnit", 10, 0, 2, 180),
		fixture("ShelfUnit", 10, 0, 8, 180),
		-- Crates and toolbox
		fixture("Crate", -3, 0, -9, 20),
		fixture("Crate", -6, 0, -9, -15),
		fixture("ToolBox", 5, 0, 9, 0),
		-- Valve barrel
		fixture("Barrel", -9, 0, 8, 0),
	},
	HidingSpots = {
		{ Type = "BehindGenerator", Offset = Vector3.new(-7, 0, 3), Rotation = 0 },
	},
}

-------------------------------------------------------------------------------
-- ROOM 6: Dormitory — Staff sleeping quarters with bunk beds
-------------------------------------------------------------------------------
RoomTemplates.Dormitory = {
	Name = "Dormitory",
	SizeMultiplier = Vector3.new(1.5, 1, 1.5),
	FloorMaterial  = Config.Materials.Floor,
	FloorColor     = Config.Colors.FloorTile,
	WallMaterial   = Config.Materials.Wall,
	WallColor      = Config.Colors.WallPaint,
	CeilingColor   = Config.Colors.CeilingPanel,
	Doors = {
		door("NegZ", 0),
	},
	Fixtures = {
		fixture("DimBulb", -4, 11, -4),
		fixture("DimBulb", 4, 11, 4),
	},
	Furniture = {
		-- Bunk beds (cots) along left wall
		fixture("Cot", -9, 0, -8, 0),
		fixture("Cot", -9, 0, -3, 0),
		fixture("Cot", -9, 0, 2, 0),
		fixture("Cot", -9, 0, 7, 0),
		-- Bunk beds along right wall
		fixture("Cot", 9, 0, -8, 180),
		fixture("Cot", 9, 0, -3, 180),
		fixture("Cot", 9, 0, 2, 180),
		-- Footlockers
		fixture("Footlocker", -6, 0, -8, 0),
		fixture("Footlocker", -6, 0, -3, 0),
		fixture("Footlocker", -6, 0, 2, 0),
		fixture("Footlocker", 6, 0, -8, 180),
		fixture("Footlocker", 6, 0, -3, 180),
		-- Desk and chair
		fixture("Desk", 5, 0, 8, 90),
		fixture("Chair", 3, 0, 8, 90),
		-- Shelf
		fixture("ShelfUnit", 9, 0, 8, 180),
	},
	HidingSpots = {
		{ Type = "UnderBed", Offset = Vector3.new(-9, 0, -3), Rotation = 0 },
		{ Type = "UnderBed", Offset = Vector3.new(9, 0, 2), Rotation = 180 },
	},
}

-------------------------------------------------------------------------------
-- SPECIAL: Elevator — spawn room, placed explicitly on each floor
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
-- SPECIAL: Stairwell — vertical shaft connecting floors
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
-- Utility: Get a weighted-random room type name (excludes Elevator/Stairwell)
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
	return "MedBay"  -- fallback
end

return RoomTemplates
