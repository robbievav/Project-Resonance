--[[
	RoomTemplates.lua — Room blueprints for the procedural generator.
	6 Unique Rooms + Elevator/Stairwell (special-purpose)
	Furniture at max ±4-5 offset, arranged with purpose, clear of all door paths.
]]

local Config = require(script.Parent.Config)

local RoomTemplates = {}

local function door(wallSide, offset)
	return { Wall = wallSide, Offset = offset }
end

local function fixture(fType, ox, oy, oz, rot)
	return { Type = fType, Offset = Vector3.new(ox, oy, oz), Rotation = rot or 0 }
end

RoomTemplates.MedBay = {
	Name = "MedBay",
	SizeMultiplier = Vector3.new(1.5, 1, 1.5),
	FloorMaterial = Config.Materials.Tile, FloorColor = Config.Colors.TileWhite,
	WallMaterial = Config.Materials.Wall, WallColor = Config.Colors.WallPaint,
	CeilingColor = Config.Colors.CeilingPanel,
	Doors = { door("NegZ", 0) },
	Fixtures = { fixture("FluorescentLight", -4, 11.5, -4), fixture("FluorescentLight", 4, 11.5, 4) },
	Furniture = {
		fixture("HospitalBed", -4, 0, -4, 90), fixture("HospitalBed", -4, 0, 4, 90),
		fixture("MedCabinet", 5, 0, -5, 0),
		fixture("Desk", 5, 0, 5, 0),
	},
	HidingSpots = {},
}

RoomTemplates.BreakRoom = {
	Name = "BreakRoom",
	SizeMultiplier = Vector3.new(1.5, 1, 1.5),
	FloorMaterial = Config.Materials.Floor, FloorColor = Config.Colors.FloorTile,
	WallMaterial = Config.Materials.Wall, WallColor = Config.Colors.WallPaint,
	CeilingColor = Config.Colors.CeilingPanel,
	Doors = { door("NegZ", 0) },
	Fixtures = { fixture("FluorescentLight", -4, 11.5, -4), fixture("FluorescentLight", 4, 11.5, 4) },
	Furniture = {
		fixture("VendingMachine", -5, 0, -5, 0),
		fixture("BreakTable", 0, 0, 0, 0),
		fixture("Chair", -2, 0, 1, 0),
		fixture("Couch", 4, 0, 4, 180),
		fixture("TrashCan", -5, 0, -3, 0),
	},
	HidingSpots = {},
}

RoomTemplates.ArchiveRoom = {
	Name = "ArchiveRoom",
	SizeMultiplier = Vector3.new(1.5, 1, 1.5),
	FloorMaterial = Config.Materials.Floor, FloorColor = Config.Colors.DarkConcrete,
	WallMaterial = Config.Materials.Wall, WallColor = Config.Colors.DarkConcrete,
	CeilingColor = Config.Colors.DarkConcrete,
	Doors = { door("NegZ", 0) },
	Fixtures = { fixture("FluorescentLight", -4, 11.5, -4), fixture("FluorescentLight", 4, 11.5, 4) },
	Furniture = {
		fixture("FilingCabinet", -5, 0, -5, 0), fixture("FilingCabinet", -2, 0, -5, 0),
		fixture("FilingCabinet", 2, 0, -5, 0), fixture("FilingCabinet", 5, 0, -5, 0),
		fixture("Desk", -4, 0, 5, 0),
		fixture("Crate", 4, 0, 5, 0),
	},
	HidingSpots = {},
}

RoomTemplates.SecurityStation = {
	Name = "SecurityStation",
	SizeMultiplier = Vector3.new(1.5, 1, 1.5),
	FloorMaterial = Config.Materials.Floor, FloorColor = Config.Colors.FloorTile,
	WallMaterial = Config.Materials.Wall, WallColor = Config.Colors.WallPaint,
	CeilingColor = Config.Colors.CeilingPanel,
	Doors = { door("NegZ", 0) },
	Fixtures = { fixture("FluorescentLight", -4, 11.5, -4), fixture("FluorescentLight", 4, 11.5, 4) },
	Furniture = {
		fixture("Console", -3, 0, -5, 0), fixture("Console", 3, 0, -5, 0),
		fixture("Chair", -3, 0, -3, 0), fixture("Chair", 3, 0, -3, 0),
		fixture("Locker", 5, 0, 5, 180),
		fixture("ShelfUnit", -5, 0, 5, 0),
	},
	HidingSpots = {},
}

RoomTemplates.MechanicalRoom = {
	Name = "MechanicalRoom",
	SizeMultiplier = Vector3.new(1.5, 1, 1.5),
	FloorMaterial = Config.Materials.MetalFloor, FloorColor = Config.Colors.MetalGrate,
	WallMaterial = Config.Materials.Wall, WallColor = Config.Colors.DarkConcrete,
	CeilingColor = Config.Colors.DarkConcrete,
	Doors = { door("NegZ", 0) },
	Fixtures = {
		fixture("FluorescentLight", -4, 11.5, -4), fixture("FluorescentLight", 4, 11.5, 4),
		fixture("Pipe", -4, 11, 0), fixture("Pipe", 4, 11, 0), fixture("Pipe", 0, 11, -5), fixture("Pipe", 0, 11, 5),
	},
	Furniture = {
		fixture("Generator", -4, 0, -4, 0),
		fixture("Barrel", 5, 0, -5, 0), fixture("Barrel", 4, 0, -4, 0),
		fixture("ShelfUnit", 5, 0, 5, 180),
		fixture("ToolBox", 3, 0, 5, 0),
	},
	HidingSpots = {},
}

RoomTemplates.Dormitory = {
	Name = "Dormitory",
	SizeMultiplier = Vector3.new(1.5, 1, 1.5),
	FloorMaterial = Config.Materials.Floor, FloorColor = Config.Colors.FloorTile,
	WallMaterial = Config.Materials.Wall, WallColor = Config.Colors.WallPaint,
	CeilingColor = Config.Colors.CeilingPanel,
	Doors = { door("NegZ", 0) },
	Fixtures = { fixture("FluorescentLight", -4, 11.5, -4), fixture("FluorescentLight", 4, 11.5, 4) },
	Furniture = {
		fixture("Cot", -4, 0, -4, 90), fixture("Cot", -4, 0, 4, 90),
		fixture("Cot", 4, 0, -4, -90), fixture("Cot", 4, 0, 4, -90),
		fixture("Footlocker", -2, 0, -4, 0), fixture("Footlocker", -2, 0, 4, 0),
	},
	HidingSpots = {},
}

RoomTemplates.PoolRoom = {
	Name = "PoolRoom",
	SizeMultiplier = Vector3.new(1.5, 1, 1.5),
	FloorMaterial = Config.Materials.Tile, FloorColor = Color3.fromRGB(235, 235, 235),
	WallMaterial = Config.Materials.Wall, WallColor = Config.Colors.WallPaint,
	CeilingColor = Config.Colors.CeilingPanel,
	Doors = { door("NegZ", 0) },
	Fixtures = { fixture("FluorescentLight", -4, 11.5, -4), fixture("FluorescentLight", 4, 11.5, 4) },
	Furniture = {
		fixture("PoolWater", 0, 0.1, 0, 0),
		fixture("PoolPillar", 0, 0, 0, 0),
		fixture("Lounger", -8, 0, -8, 45)
	},
	HidingSpots = {},
}

RoomTemplates.YellowOffice = {
	Name = "YellowOffice",
	SizeMultiplier = Vector3.new(1.5, 1, 1.5),
	FloorMaterial = Config.Materials.Floor, FloorColor = Color3.fromRGB(165, 155, 115),
	WallMaterial = Config.Materials.Wall, WallColor = Color3.fromRGB(215, 205, 150),
	CeilingColor = Color3.fromRGB(185, 185, 170),
	Doors = { door("NegZ", 0) },
	Fixtures = { fixture("FluorescentLight", -4, 11.5, -4), fixture("FluorescentLight", 4, 11.5, 4) },
	Furniture = {
		fixture("PartitionWall", -4, 0, -4, 0),
		fixture("PartitionWall", 2, 0, 2, 90),
		fixture("PartitionWall", 8, 0, -4, 0),
		fixture("Desk", -13, 0, -8, 90),
		fixture("Chair", -10, 0, -8, -90),
		fixture("FilingCabinet", 12, 0, -8, 180)
	},
	HidingSpots = {},
}

RoomTemplates.Elevator = {
	Name = "Elevator",
	SizeMultiplier = Vector3.new(0.5, 1.5, 0.5),
	FloorMaterial = Config.Materials.MetalFloor, FloorColor = Config.Colors.MetalGrate,
	WallMaterial = Config.Materials.Wall, WallColor = Config.Colors.DarkConcrete,
	CeilingColor = Config.Colors.DarkConcrete,
	IsSafe = true,
	Doors = { door("PosZ", 0) },
	Fixtures = { fixture("DimBulb", 0, 14, 0) },
	Furniture = { fixture("ElevatorPanel", 5.85, 3, 0, 90) },
	HidingSpots = {},
}

RoomTemplates.Stairwell = {
	Name = "Stairwell",
	SizeMultiplier = Vector3.new(1, 2, 1),
	FloorMaterial = Config.Materials.Wall, FloorColor = Config.Colors.DarkConcrete,
	WallMaterial = Config.Materials.Wall, WallColor = Config.Colors.DarkConcrete,
	CeilingColor = Config.Colors.DarkConcrete,
	IsStairwell = true,
	Doors = { door("NegZ", 0) },
	Fixtures = { fixture("DimBulb", 0, 20, 0), fixture("DimBulb", 0, 10, 0) },
	Furniture = {},
	HidingSpots = {},
}

function RoomTemplates.GetRandomType(rng)
	local totalWeight = 0
	for _, w in pairs(Config.RoomWeights) do totalWeight = totalWeight + w end
	local roll = rng:NextNumber() * totalWeight
	local cumulative = 0
	for name, w in pairs(Config.RoomWeights) do
		cumulative = cumulative + w
		if roll <= cumulative then return name end
	end
	return "MedBay"
end

return RoomTemplates
