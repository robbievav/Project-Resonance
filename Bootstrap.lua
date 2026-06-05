--[[
	Bootstrap.lua — Project: Resonance
	Paste this entire script into the Roblox Studio COMMAND BAR and press Enter.
	It creates all map geometry permanently in the place: rooms, hallways, doors,
	furniture, hiding spots, stairwells, and the spawn location.

	After running, SAVE the place file. The geometry persists across sessions.
	To regenerate with a different seed, run this script again (it clears the old map first).
]]

-----------------------------------------------------------------------
-- CONFIG
-----------------------------------------------------------------------
local SEED            = 0          -- 0 = random seed each launch
local FLOORS          = 5         -- floors to bake (increase as needed)
local GRID_SIZE       = 5
local ROOM_UNIT       = 36        -- every room is exactly 36x36 studs
local GRID_SPACING    = 44        -- center-to-center distance between rooms
local HALLWAY_WIDTH   = 8
local WALL_HEIGHT     = 12
local WALL_THICKNESS  = 1
local DOOR_WIDTH      = 5
local DOOR_HEIGHT     = 8
local FLOOR_SEP       = 50
local STAIRWELL_ROW   = 2
local STAIRWELL_COL   = 4
local FLICKER_CHANCE  = 0.25
local FLUOR_BRIGHTNESS = 1.5
local FLUOR_RANGE     = 50

-- Colors
local C = {
	FloorTile    = Color3.fromRGB(160, 155, 145),
	WallPaint    = Color3.fromRGB(195, 190, 180),
	CeilingPanel = Color3.fromRGB(200, 198, 192),
	MetalGrate   = Color3.fromRGB(100, 100, 105),
	DarkConcrete = Color3.fromRGB(80, 78, 75),
	Rust         = Color3.fromRGB(140, 85, 55),
	DoorFrame    = Color3.fromRGB(130, 125, 115),
	FluorLight   = Color3.fromRGB(235, 230, 210),
	LabWhite     = Color3.fromRGB(215, 218, 220),
	LabBench     = Color3.fromRGB(55, 55, 60),
	TileWhite    = Color3.fromRGB(210, 210, 205),
	ServerBlue   = Color3.fromRGB(20, 30, 50),
	Crate        = Color3.fromRGB(120, 100, 70),
}

-- Floor Themes
local THEMES = {
	{ Name="CleanOffice",   Range={1,10},  WallColor=Color3.fromRGB(195,190,180), FloorColor=Color3.fromRGB(160,155,145), WallMat="Concrete",  LightMult=1.0 },
	{ Name="Deteriorating", Range={11,25}, WallColor=Color3.fromRGB(150,145,135), FloorColor=Color3.fromRGB(130,125,118), WallMat="Concrete",  LightMult=0.7 },
	{ Name="Industrial",    Range={26,40}, WallColor=Color3.fromRGB(100,95,90),   FloorColor=Color3.fromRGB(90,88,82),    WallMat="Slate",     LightMult=0.45 },
	{ Name="Abandoned",     Range={41,50}, WallColor=Color3.fromRGB(65,60,55),    FloorColor=Color3.fromRGB(55,52,48),    WallMat="Slate",     LightMult=0.25 },
}

local function getTheme(f)
	for _, t in ipairs(THEMES) do
		if f >= t.Range[1] and f <= t.Range[2] then return t end
	end
	return THEMES[1]
end

-- Room Weights (for random selection)
local ROOM_WEIGHTS = {
	MedBay=10, BreakRoom=10, ArchiveRoom=10, SecurityStation=8,
	MechanicalRoom=10, Dormitory=10,
	PoolRoom=15, YellowOffice=15,
}

-----------------------------------------------------------------------
-- UTILITIES
-----------------------------------------------------------------------
local function getMat(name) return Enum.Material[name] or Enum.Material.SmoothPlastic end

local function mp(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = props.CanCollide ~= false
	p.Size = props.Size or Vector3.new(1,1,1)
	p.CFrame = props.CFrame or CFrame.new()
	p.Material = props.Material or Enum.Material.SmoothPlastic
	p.Color = props.Color or Color3.fromRGB(180,180,180)
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Name = props.Name or "Part"
	p.Parent = props.Parent
	return p
end

local function getWeightedRandom(rng)
	local total = 0
	for _, w in pairs(ROOM_WEIGHTS) do total = total + w end
	local roll = rng:NextNumber() * total
	local cum = 0
	for name, w in pairs(ROOM_WEIGHTS) do
		cum = cum + w
		if roll <= cum then return name end
	end
	return "Hallway"
end

-----------------------------------------------------------------------
-- ROOM TEMPLATES
-- ALL rooms are 24x24x12 (1 ROOM_UNIT). Variety is in furniture/fixtures.
-- ALL rooms get doors on all 4 walls so connectors always line up.
-----------------------------------------------------------------------
local function fix(t, ox, oy, oz, rot) return { Type=t, Offset=Vector3.new(ox,oy,oz), Rotation=rot or 0 } end

local ALL_DOORS = {"NegZ","PosZ","NegX","PosX"}

local ROOMS = {}

-----------------------------------------------------------------------
-- ROOM 1: MedBay — Medical facility with hospital beds and supplies
-----------------------------------------------------------------------
ROOMS.MedBay = {
	Name="MedBay", FloorMat="Marble", FloorCol=C.TileWhite,
	CeilCol=C.CeilingPanel,
	Fixtures={fix("Fluor",-6,11.5,-6), fix("Fluor",6,11.5,6)},
	Furniture={
		-- Hospital beds spaced apart, facing inward
		fix("HospitalBed",-7.5,0,10,90), fix("HospitalBed",-15.5,0,-12.2,-90),
		-- Medical supplies grouped on the right side
		fix("MedCabinet",5,0,-5,0),
		fix("Desk",3.5,0,1.5,90),
	},
	HidingSpots={},
}

-----------------------------------------------------------------------
-- ROOM 2: BreakRoom — Staff lounge with vending machines and seating
-----------------------------------------------------------------------
ROOMS.BreakRoom = {
	Name="BreakRoom", FloorMat="SmoothPlastic", FloorCol=C.FloorTile,
	CeilCol=C.CeilingPanel,
	Fixtures={fix("Fluor",-6,11.5,-6), fix("Fluor",6,11.5,6)},
	Furniture={
		-- Fridge in back-left area
		fix("VendingMachine",-11.25,0,-16,0),
		-- Central dining table with a chair
		fix("BreakTable",0,0,0,0),
		fix("Chair",-4.1,0,1,0),
		-- Couch on the right side, facing center
		fix("Couch",10.1,0,8.6,180),
		-- Trash can beside vending machine
		fix("TrashCan",-5,0,-3,0),
	},
	HidingSpots={},
}

-----------------------------------------------------------------------
-- ROOM 3: ArchiveRoom — Records storage with filing cabinet rows
-----------------------------------------------------------------------
ROOMS.ArchiveRoom = {
	Name="ArchiveRoom", FloorMat="SmoothPlastic", FloorCol=C.DarkConcrete,
	CeilCol=C.DarkConcrete,
	Fixtures={fix("Fluor",-6,11.5,-6), fix("Fluor",6,11.5,6)},
	Furniture={
		-- Row of filing cabinets along back wall
		fix("FileCab",-5,0,-5,0), fix("FileCab",-2,0,-5,0),
		fix("FileCab",2,0,-5,0), fix("FileCab",5,0,-5,0),
		-- Reading desk in front-left corner
		fix("Desk",-4,0,5,0),
		-- Crate in front-right corner
		fix("Crate",4,0,5,0),
	},
	HidingSpots={},
}

-----------------------------------------------------------------------
-- ROOM 4: SecurityStation — Guard post with monitors and lockers
-----------------------------------------------------------------------
ROOMS.SecurityStation = {
	Name="SecurityStation", FloorMat="SmoothPlastic", FloorCol=C.FloorTile,
	CeilCol=C.CeilingPanel,
	Fixtures={fix("Fluor",-6,11.5,-6), fix("Fluor",6,11.5,6)},
	Furniture={
		-- Monitor consoles facing the room
		fix("Console",-9.5,0,-4.25,180), fix("Console",12,0,-5,0),
		-- Chairs at each console
		fix("Chair",-5.1,0,-1.1,90), fix("Chair",9.4,0,-8.4,-90),
		-- Shelf on the left side
		fix("ShelfUnit",-17.6,0,16.7,90),
		-- Locker in front-right corner
		fix("Locker",5,0,5,180),
	},
	HidingSpots={},
}

-----------------------------------------------------------------------
-- ROOM 5: MechanicalRoom — Boiler/HVAC with pipes and generators
-----------------------------------------------------------------------
ROOMS.MechanicalRoom = {
	Name="MechanicalRoom", FloorMat="DiamondPlate", FloorCol=C.MetalGrate,
	CeilCol=C.DarkConcrete,
	Fixtures={fix("Fluor",-6,11.5,-6), fix("Fluor",6,11.5,6), fix("Pipe",-4,11,0), fix("Pipe",4,11,0), fix("Pipe",0,11,-8), fix("Pipe",0,11,8)},
	Furniture={
		-- Generator in the back-left corner
		fix("Generator",-4,0,-4,0),
		-- Barrels grouped in back-right corner
		fix("Barrel",5,0,-5,0), fix("Barrel",4,0,-4,0),
		-- Row of shelves along back wall
		fix("ShelfUnit",-17.3,0,-16.7,0), fix("ShelfUnit",-10.3,0,-16.7,0),
		fix("ShelfUnit",3.6,0,-16.7,0), fix("ShelfUnit",10.7,0,-16.7,0),
		-- Row of shelves along front wall
		fix("ShelfUnit",17.3,0,16.3,180), fix("ShelfUnit",10.3,0,16.3,180),
		fix("ShelfUnit",-3.6,0,16.3,180), fix("ShelfUnit",-10.7,0,16.1,180),
		-- Toolbox
		fix("ToolBox",3,0,5,0),
	},
	HidingSpots={},
}

-----------------------------------------------------------------------
-- ROOM 6: Dormitory — Staff sleeping quarters with bunk beds
-----------------------------------------------------------------------
ROOMS.Dormitory = {
	Name="Dormitory", FloorMat="SmoothPlastic", FloorCol=C.FloorTile,
	CeilCol=C.CeilingPanel,
	Fixtures={fix("Fluor",-6,11.5,-6), fix("Fluor",6,11.5,6)},
	Furniture={
		-- Cots spaced around the room
		fix("Cot",13.9,0,6,90), fix("Cot",-6.5,0,6.5,90),
		fix("Cot",-14.4,0,-7.6,-90), fix("Cot",7,0,-9.5,-90),
		-- Footlockers at the foot of each bed row
		fix("Footlocker",-2,0,-4,0), fix("Footlocker",-2,0,4,0),
	},
	HidingSpots={},
}

-----------------------------------------------------------------------
-- ROOM 7: PoolRoom — White-tiled subterranean water chamber
-----------------------------------------------------------------------
ROOMS.PoolRoom = {
	Name="PoolRoom", FloorMat="Marble", FloorCol=Color3.fromRGB(235, 235, 235),
	CeilCol=Color3.fromRGB(220, 220, 220),
	Fixtures={
		fix("Fluor",-6,11.5,-6), fix("Fluor",6,11.5,6),
		{ Type="PoolWater", Offset=Vector3.new(0,0.1,0), Rotation=0 }
	},
	Furniture={
		{ Type="PoolPillar", Offset=Vector3.new(0,0,0), Rotation=0 },
		{ Type="Lounger", Offset=Vector3.new(-8,0,-8), Rotation=45 }
	},
	HidingSpots={},
}

-----------------------------------------------------------------------
-- ROOM 8: YellowOffice — Sickly yellow monospace office layout
-----------------------------------------------------------------------
ROOMS.YellowOffice = {
	Name="YellowOffice", FloorMat="SmoothPlastic", FloorCol=Color3.fromRGB(165, 155, 115),
	CeilCol=Color3.fromRGB(185, 185, 170),
	Fixtures={fix("Fluor",-6,11.5,-6), fix("Fluor",6,11.5,6)},
	Furniture={
		{ Type="PartitionWall", Offset=Vector3.new(-4,0,-4), Rotation=0 },
		{ Type="PartitionWall", Offset=Vector3.new(2,0,2), Rotation=90 },
		{ Type="PartitionWall", Offset=Vector3.new(8,0,-4), Rotation=0 },
		fix("Desk",5,0,-1,0),
		fix("Chair",1,0,-2.45,-90),
		fix("FileCab",12,0,-8,180),
	},
	HidingSpots={},
}

-----------------------------------------------------------------------
-- SPECIAL ROOMS (placed explicitly, not randomly)
-----------------------------------------------------------------------
ROOMS.Elevator = {
	Name="Elevator", FloorMat="DiamondPlate", FloorCol=C.MetalGrate,
	CeilCol=C.DarkConcrete, IsSafe=true,
	Fixtures={fix("DimBulb",0,11,0)},
	Furniture={fix("ElevatorPanel",-17.35,3,5,0)},
	HidingSpots={},
}

ROOMS.Stairwell = {
	Name="Stairwell", FloorMat="Concrete", FloorCol=C.DarkConcrete,
	CeilCol=C.DarkConcrete, IsStairwell=true,
	Fixtures={fix("DimBulb",0,11,0)},
	Furniture={}, HidingSpots={},
}

-----------------------------------------------------------------------
-- FURNITURE — Clone from ReplicatedStorage.Furniture
-----------------------------------------------------------------------
local FurnitureFolder = game:GetService("ReplicatedStorage"):FindFirstChild("Furniture")

-- Map: internal type → { model name, scale, Y rotation adjustment }
-- Scale adjusts the model size, RotFix adds extra rotation if model faces wrong way
local FURNITURE_MAP = {
	-- Core furniture (reused across rooms)
	Desk           = { Model = "work station",      Scale = 1.0,  RotFix = 0   },
	Chair          = { Model = "Chair - pemble08",  Scale = 1.0,  RotFix = 0   },
	FileCab        = { Model = "cabinet 1",         Scale = 1.0,  RotFix = 0   },
	Barrel         = { Model = "cabinet 3",         Scale = 0.7,  RotFix = 0   },
	ToolBox        = { Model = "small safe",        Scale = 0.6,  RotFix = 0   },
	Console        = { Model = "work station",      Scale = 1.0,  RotFix = 0   },
	Cot            = { Model = "couch",             Scale = 1.0,  RotFix = 0   },
	Locker         = { Model = "cabinet 2",         Scale = 1.0,  RotFix = 0   },
	ShelfUnit      = { Model = "shelf1",            Scale = 1.0,  RotFix = 0   },
	Crate          = { Model = "cabinet 4",         Scale = 0.8,  RotFix = 0   },
	-- MedBay furniture
	HospitalBed    = { Model = "couch",             Scale = 1.1,  RotFix = 0   },
	MedCabinet     = { Model = "cabinet 1",         Scale = 0.9,  RotFix = 0   },
	-- BreakRoom furniture
	VendingMachine = { Model = "Refridgerator",     Scale = 1.0,  RotFix = 0   },
	BreakTable     = { Model = "dinner table",      Scale = 1.0,  RotFix = 0   },
	Couch          = { Model = "couch",             Scale = 1.0,  RotFix = 0   },
	TrashCan       = { Model = "cabinet 3",         Scale = 0.4,  RotFix = 0   },
	-- MechanicalRoom furniture
	Generator      = { Model = "cabinet 4",         Scale = 1.5,  RotFix = 0   },
	-- Dormitory furniture
	Footlocker     = { Model = "small safe",        Scale = 0.7,  RotFix = 0   },
}

-- Scale all BaseParts in a model
local function scaleModel(model, factor)
	if factor == 1 then return end
	local parts = {}
	if model:IsA("BasePart") then
		parts = {model}
	else
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then table.insert(parts, p) end
		end
	end
	-- Get center for scaling around the model's center
	local cf, size
	if model:IsA("Model") then
		cf, size = model:GetBoundingBox()
	else
		cf = model.CFrame
	end
	local center = cf.Position
	for _, p in ipairs(parts) do
		p.Size = p.Size * factor
		local offset = p.Position - center
		p.CFrame = CFrame.new(center + offset * factor) * (p.CFrame - p.CFrame.Position)
	end
end

-- Get the lowest Y point of a model (for grounding)
local function getModelBounds(model)
	if model:IsA("Model") and model.PrimaryPart then
		return model.PrimaryPart.CFrame, model.PrimaryPart.Size
	elseif model:IsA("Model") then
		local cf, size = model:GetBoundingBox()
		return cf, size
	elseif model:IsA("BasePart") then
		return model.CFrame, model.Size
	end
	return CFrame.new(), Vector3.new(0,0,0)
end

local function cloneFurniture(typeName, pos, rot, parent)
	if typeName == "PoolWater" then
		local water = mp({
			Name = "WaterPlane",
			Size = Vector3.new(14, 0.2, 14),
			CFrame = CFrame.new(pos),
			Material = Enum.Material.Glass,
			Color = Color3.fromRGB(0, 160, 210),
			Parent = parent,
			CanCollide = false
		})
		water.Transparency = 0.4
		local pl = Instance.new("PointLight")
		pl.Brightness = 0.5
		pl.Range = 15
		pl.Color = Color3.fromRGB(0, 200, 255)
		pl.Parent = water
		return
	elseif typeName == "PoolPillar" then
		mp({
			Name = "PoolPillar",
			Size = Vector3.new(3, WALL_HEIGHT, 3),
			CFrame = CFrame.new(pos + Vector3.new(0, WALL_HEIGHT/2, 0)),
			Material = Enum.Material.Marble,
			Color = Color3.fromRGB(235, 235, 235),
			Parent = parent
		})
		return
	elseif typeName == "Lounger" then
		local r = CFrame.Angles(0, math.rad(rot), 0)
		local base = mp({
			Name = "LoungerBase",
			Size = Vector3.new(2, 0.4, 5),
			CFrame = CFrame.new(pos + Vector3.new(0, 0.2, 0)) * r,
			Material = Enum.Material.SmoothPlastic,
			Color = Color3.fromRGB(240, 240, 245),
			Parent = parent
		})
		mp({
			Name = "LoungerBack",
			Size = Vector3.new(2, 1.8, 0.3),
			CFrame = CFrame.new(pos) * r * CFrame.new(0, 1.0, -2.3) * CFrame.Angles(math.rad(-30), 0, 0),
			Material = Enum.Material.SmoothPlastic,
			Color = Color3.fromRGB(240, 240, 245),
			Parent = parent
		})
		return
	elseif typeName == "PartitionWall" then
		local r = CFrame.Angles(0, math.rad(rot), 0)
		mp({
			Name = "PartitionWall",
			Size = Vector3.new(1, WALL_HEIGHT, 12),
			CFrame = CFrame.new(pos + Vector3.new(0, WALL_HEIGHT/2, 0)) * r,
			Material = Enum.Material.Concrete,
			Color = Color3.fromRGB(215, 205, 150),
			Parent = parent
		})
		return
	end

	-- Special case: ElevatorPanel is game-specific (neon button)
	if typeName == "ElevatorPanel" then
		local r = CFrame.Angles(0, math.rad(rot), 0)
		local panel = mp({Name="ElevatorPanel",Size=Vector3.new(0.3,1.5,1),CFrame=CFrame.new(pos)*r,Material=Enum.Material.Metal,Color=Color3.fromRGB(70,70,75),Parent=parent})
		mp({Name="ElevatorButton",Size=Vector3.new(0.35,0.3,0.3),CFrame=CFrame.new(pos+Vector3.new(0.15,0.3,0))*r,Material=Enum.Material.Neon,Color=Color3.fromRGB(200,60,40),Parent=parent})
		local pp = Instance.new("ProximityPrompt"); pp.ActionText="Call Elevator"; pp.ObjectText="Elevator"; pp.MaxActivationDistance=8; pp.HoldDuration=0; pp.Parent=panel
		-- Tag so server can find all panels via CollectionService
		game:GetService("CollectionService"):AddTag(panel, "ElevatorPanel")
		return
	end

	local info = FURNITURE_MAP[typeName]
	if not info or not FurnitureFolder then return end

	local template = FurnitureFolder:FindFirstChild(info.Model)
	if not template then
		warn("[Bootstrap] Furniture model not found:", info.Model, "for type", typeName)
		return
	end

	local clone = template:Clone()
	clone.Name = typeName

	-- Ensure PrimaryPart is set for Models
	if clone:IsA("Model") and not clone.PrimaryPart then
		local firstPart = clone:FindFirstChildWhichIsA("BasePart", true)
		if firstPart then clone.PrimaryPart = firstPart end
	end

	-- Parent it temporarily so GetBoundingBox works
	clone.Parent = workspace

	-- Anchor all parts first
	for _, part in ipairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then part.Anchored = true end
	end
	if clone:IsA("BasePart") then clone.Anchored = true end

	-- Apply scaling
	scaleModel(clone, info.Scale)

	-- Final rotation = room rotation + any model-specific rotation fix
	local finalRot = rot + info.RotFix

	local finalPos
	if clone:IsA("Model") and clone.PrimaryPart then
		finalPos = Vector3.new(pos.X, pos.Y + clone.PrimaryPart.Size.Y / 2, pos.Z)
		clone:PivotTo(CFrame.new(finalPos) * CFrame.Angles(0, math.rad(finalRot), 0))
	elseif clone:IsA("Model") then
		local cf, size = clone:GetBoundingBox()
		finalPos = Vector3.new(pos.X, pos.Y + size.Y / 2, pos.Z)
		clone:PivotTo(CFrame.new(finalPos) * CFrame.Angles(0, math.rad(finalRot), 0))
	elseif clone:IsA("BasePart") then
		finalPos = Vector3.new(pos.X, pos.Y + clone.Size.Y / 2, pos.Z)
		clone.CFrame = CFrame.new(finalPos) * CFrame.Angles(0, math.rad(finalRot), 0)
	end

	-- Reparent to the room folder
	clone.Parent = parent
end

-----------------------------------------------------------------------
-- ROOM BUILDER
-- Every room is exactly ROOM_UNIT x ROOM_UNIT (24x24x12).
-- Doors on all 4 walls, ONLY if connection exists.
-----------------------------------------------------------------------
local function buildRoom(template, origin, floorFolder, floorIdx, connections)
	local sx = ROOM_UNIT
	local sz = ROOM_UNIT
	local height = WALL_HEIGHT
	local thick = WALL_THICKNESS
	local theme = getTheme(floorIdx)
	local wallColor = theme.WallColor
	local wallMat = getMat(theme.WallMat)
	local lightMult = theme.LightMult

	local roomFolder = Instance.new("Folder")
	roomFolder.Name = template.Name
	roomFolder.Parent = floorFolder
	roomFolder:SetAttribute("RoomType", template.Name)

	-- Floor
	mp({Name="Floor",Size=Vector3.new(sx,thick,sz),CFrame=CFrame.new(origin+Vector3.new(0,-thick/2,0)),Material=getMat(template.FloorMat),Color=template.FloorCol,Parent=roomFolder})
	-- Ceiling
	mp({Name="Ceiling",Size=Vector3.new(sx,thick,sz),CFrame=CFrame.new(origin+Vector3.new(0,height+thick/2,0)),Material=Enum.Material.SmoothPlastic,Color=template.CeilCol,Parent=roomFolder})

	-- Walls — EVERY wall gets a centered door opening
	local dw = DOOR_WIDTH
	local dh = DOOR_HEIGHT
	local dOff = 0  -- all doors centered

	local walls = {
		{side="PosX", isZ=false, size=Vector3.new(thick,height,sz), pos=Vector3.new(sx/2,height/2,0), hasDoor=connections and connections.East},
		{side="NegX", isZ=false, size=Vector3.new(thick,height,sz), pos=Vector3.new(-sx/2,height/2,0), hasDoor=connections and connections.West},
		{side="PosZ", isZ=true,  size=Vector3.new(sx,height,thick), pos=Vector3.new(0,height/2,sz/2), hasDoor=connections and connections.South},
		{side="NegZ", isZ=true,  size=Vector3.new(sx,height,thick), pos=Vector3.new(0,height/2,-sz/2), hasDoor=connections and connections.North},
	}

	for _, w in ipairs(walls) do
		local curDW = w.hasDoor and dw or 0
		local curDH = w.hasDoor and dh or 0
		local aboveH = height - curDH
		-- Wall above the door
		if aboveH > 0 then
			if w.isZ then
				mp({Name="WallAbove",Size=Vector3.new(curDW,aboveH,thick),CFrame=CFrame.new(origin+w.pos+Vector3.new(0,(height-aboveH)/2,0)),Material=wallMat,Color=wallColor,Parent=roomFolder})
			else
				mp({Name="WallAbove",Size=Vector3.new(thick,aboveH,curDW),CFrame=CFrame.new(origin+w.pos+Vector3.new(0,(height-aboveH)/2,0)),Material=wallMat,Color=wallColor,Parent=roomFolder})
			end
		end
		-- Wall left of door
		local sideLen = w.isZ and sx or sz
		local lw = sideLen/2 + dOff - curDW/2
		local rw = sideLen/2 - dOff - curDW/2
		if lw > 0.1 then
			if w.isZ then
				mp({Name="WallLeft",Size=Vector3.new(lw,height,thick),CFrame=CFrame.new(origin+w.pos+Vector3.new(-curDW/2-lw/2,0,0)),Material=wallMat,Color=wallColor,Parent=roomFolder})
			else
				mp({Name="WallLeft",Size=Vector3.new(thick,height,lw),CFrame=CFrame.new(origin+w.pos+Vector3.new(0,0,-curDW/2-lw/2)),Material=wallMat,Color=wallColor,Parent=roomFolder})
			end
		end
		if rw > 0.1 then
			if w.isZ then
				mp({Name="WallRight",Size=Vector3.new(rw,height,thick),CFrame=CFrame.new(origin+w.pos+Vector3.new(curDW/2+rw/2,0,0)),Material=wallMat,Color=wallColor,Parent=roomFolder})
			else
				mp({Name="WallRight",Size=Vector3.new(thick,height,rw),CFrame=CFrame.new(origin+w.pos+Vector3.new(0,0,curDW/2+rw/2)),Material=wallMat,Color=wallColor,Parent=roomFolder})
			end
		end
		-- Door part
		if w.hasDoor then
			local dp
			if w.isZ then
				dp = mp({Name="Door",Size=Vector3.new(dw,dh,thick*0.5),CFrame=CFrame.new(origin+w.pos+Vector3.new(0,-(height-dh)/2,0)),Material=Enum.Material.Wood,Color=C.DoorFrame,Parent=roomFolder})
			else
				dp = mp({Name="Door",Size=Vector3.new(thick*0.5,dh,dw),CFrame=CFrame.new(origin+w.pos+Vector3.new(0,-(height-dh)/2,0)),Material=Enum.Material.Wood,Color=C.DoorFrame,Parent=roomFolder})
			end
			local pp = Instance.new("ProximityPrompt"); pp.ActionText="Open"; pp.ObjectText="Door"; pp.MaxActivationDistance=8; pp.HoldDuration=0.3; pp.Parent=dp
			local tg = Instance.new("StringValue"); tg.Name="DoorTag"; tg.Value=template.Name; tg.Parent=dp
			local pm = Instance.new("PathfindingModifier"); pm.Label="Door"; pm.PassThrough=true; pm.Parent=dp
		end
	end

	-- Fixtures
	for _, f in ipairs(template.Fixtures) do
		local pos = origin + f.Offset
		if f.Type == "Fluor" then
			local h = mp({Name="FluorescentHousing",Size=Vector3.new(4,0.3,1),CFrame=CFrame.new(pos)*CFrame.Angles(0,math.rad(f.Rotation),0),Material=Enum.Material.SmoothPlastic,Color=Color3.fromRGB(220,220,215),Parent=roomFolder})
			local l = Instance.new("SurfaceLight"); l.Face=Enum.NormalId.Bottom; l.Brightness=FLUOR_BRIGHTNESS*lightMult; l.Range=FLUOR_RANGE; l.Color=C.FluorLight; l.Angle=120; l.Parent=h
			if math.random() < FLICKER_CHANCE then local ft=Instance.new("BoolValue"); ft.Name="Flicker"; ft.Value=true; ft.Parent=h end
		elseif f.Type == "DimBulb" then
			local b = mp({Name="DimBulb",Size=Vector3.new(0.6,0.6,0.6),CFrame=CFrame.new(pos),Material=Enum.Material.Neon,Color=Color3.fromRGB(180,160,100),Parent=roomFolder})
			local pl = Instance.new("PointLight"); pl.Brightness=0.6*lightMult; pl.Range=28; pl.Color=Color3.fromRGB(180,160,100); pl.Parent=b
		elseif f.Type == "Pipe" then
			mp({Name="Pipe",Size=Vector3.new(0.5,0.5,ROOM_UNIT),CFrame=CFrame.new(pos)*CFrame.Angles(0,math.rad(f.Rotation),0),Material=Enum.Material.Metal,Color=C.Rust,Parent=roomFolder})
		end
	end

	-- Furniture (clone from ReplicatedStorage.Furniture)
	for _, f in ipairs(template.Furniture) do
		local fPos = origin + f.Offset
		cloneFurniture(f.Type, fPos, f.Rotation, roomFolder)
	end


	return roomFolder
end

-----------------------------------------------------------------------
-- STAIRWELL BUILDER
-----------------------------------------------------------------------
local function buildStairwell(origin, floorIdx, floorFolder, connections)
	local roomF = buildRoom(ROOMS.Stairwell, origin, floorFolder, floorIdx, connections)
	local stairF = Instance.new("Folder"); stairF.Name="Stairs_"..floorIdx; stairF.Parent=floorFolder
	local numSteps = 16
	local stepH = FLOOR_SEP / numSteps
	for i=0, numSteps-1 do
		local angle = (i/numSteps) * math.pi * 2
		local y = -(i * stepH)
		local x = math.cos(angle) * 4
		local z = math.sin(angle) * 4
		mp({Name="Step_"..i,Size=Vector3.new(3,0.5,2),CFrame=CFrame.new(origin+Vector3.new(x,y-0.25,z))*CFrame.Angles(0,-angle,0),Material=Enum.Material.Concrete,Color=C.DarkConcrete,Parent=stairF})
		mp({Name="Railing_"..i,Size=Vector3.new(0.2,3,0.2),CFrame=CFrame.new(origin+Vector3.new(x+math.cos(angle)*1.5,y+1.25,z+math.sin(angle)*1.5)),Material=Enum.Material.Metal,Color=C.MetalGrate,Parent=stairF})
	end
	return roomF
end

-----------------------------------------------------------------------
-- CONNECTOR BUILDER
-----------------------------------------------------------------------
local function buildConnector(posA, posB, floorFolder, floorIdx)
	local mid = (posA + posB) / 2
	local diff = posB - posA
	local len = diff.Magnitude
	if len < 1 then return end  -- skip zero-length connectors
	local height = WALL_HEIGHT
	local thick = WALL_THICKNESS
	local hw = HALLWAY_WIDTH
	local theme = getTheme(floorIdx)
	local cf = CFrame.lookAt(mid, mid + diff.Unit)

	mp({Name="ConnectorFloor",Size=Vector3.new(hw,thick,len),CFrame=cf*CFrame.new(0,-thick/2,0),Material=Enum.Material.SmoothPlastic,Color=theme.FloorColor,Parent=floorFolder})
	mp({Name="ConnectorCeiling",Size=Vector3.new(hw,thick,len),CFrame=cf*CFrame.new(0,height+thick/2,0),Material=Enum.Material.SmoothPlastic,Color=C.CeilingPanel,Parent=floorFolder})
	mp({Name="ConnectorWallL",Size=Vector3.new(thick,height,len),CFrame=cf*CFrame.new(-hw/2,height/2,0),Material=getMat(theme.WallMat),Color=theme.WallColor,Parent=floorFolder})
	mp({Name="ConnectorWallR",Size=Vector3.new(thick,height,len),CFrame=cf*CFrame.new(hw/2,height/2,0),Material=getMat(theme.WallMat),Color=theme.WallColor,Parent=floorFolder})
	local b = mp({Name="ConnectorLight",Size=Vector3.new(0.4,0.4,0.4),CFrame=cf*CFrame.new(0,height-0.5,0),Material=Enum.Material.Neon,Color=C.FluorLight,Parent=floorFolder})
	local pl = Instance.new("PointLight"); pl.Brightness=0.4*theme.LightMult; pl.Range=14; pl.Color=C.FluorLight; pl.Parent=b
end

-----------------------------------------------------------------------
-- FLOOR GENERATOR
-----------------------------------------------------------------------
local function generateFloor(floorIdx, rng, mapFolder)
	local ff = Instance.new("Folder"); ff.Name="Floor_"..floorIdx; ff.Parent=mapFolder
	local baseY = -(floorIdx - 1) * FLOOR_SEP
	local halfGrid = (GRID_SIZE - 1) / 2  -- center the grid at X=0, Z=0

	local cellData = {}
	for row = 1, GRID_SIZE do
		cellData[row] = {}
		for col = 1, GRID_SIZE do
			-- Center the grid: col=1 → left side, col=GRID_SIZE → right side
			local origin = Vector3.new(
				(col - 1 - halfGrid) * GRID_SPACING,
				baseY,
				(row - 1 - halfGrid) * GRID_SPACING
			)

			local tName
			if row == math.ceil(GRID_SIZE/2) and col == math.ceil(GRID_SIZE/2) then
				tName = "Elevator"
			else
				tName = getWeightedRandom(rng)
			end

			local tmpl = ROOMS[tName]
			if tmpl then
				cellData[row][col] = { origin = origin, name = tName, template = tmpl }
			end
		end
	end

	-- Now build the rooms because we know where neighbors are
	for row = 1, GRID_SIZE do
		for col = 1, GRID_SIZE do
			local cell = cellData[row][col]
			if cell then
				local connections = {
					North = cellData[row - 1] and cellData[row - 1][col] ~= nil,
					South = cellData[row + 1] and cellData[row + 1][col] ~= nil,
					West = cellData[row][col - 1] ~= nil,
					East = cellData[row][col + 1] ~= nil,
				}
				buildRoom(cell.template, cell.origin, ff, floorIdx, connections)
			end
		end
	end

	-- Connectors between adjacent rooms
	local halfRoom = ROOM_UNIT / 2  -- 12 studs from center to wall
	for row = 1, GRID_SIZE do
		for col = 1, GRID_SIZE do
			if cellData[row][col] then
				-- Horizontal connector (east)
				if col < GRID_SIZE and cellData[row][col + 1] then
					local a = cellData[row][col].origin
					local b = cellData[row][col + 1].origin
					local edgeA = a + Vector3.new(halfRoom, 0, 0)
					local edgeB = b - Vector3.new(halfRoom, 0, 0)
					if (edgeB - edgeA).Magnitude > 1 then
						buildConnector(edgeA, edgeB, ff, floorIdx)
					end
				end
				-- Vertical connector (south)
				if row < GRID_SIZE and cellData[row + 1] and cellData[row + 1][col] then
					local a = cellData[row][col].origin
					local b = cellData[row + 1][col].origin
					local edgeA = a + Vector3.new(0, 0, halfRoom)
					local edgeB = b - Vector3.new(0, 0, halfRoom)
					if (edgeB - edgeA).Magnitude > 1 then
						buildConnector(edgeA, edgeB, ff, floorIdx)
					end
				end
			end
		end
	end

	-- Spawning will occur via lobby elevator teleportation
	if floorIdx == 1 then
		print("[Bootstrap] Floor 1 generated. Spawn location will be handled in lobby.")
	end

	return ff
end

-----------------------------------------------------------------------
-- MAIN
-----------------------------------------------------------------------
-- Clear old map and default baseplate
local old = workspace:FindFirstChild("GeneratedMap")
if old then old:Destroy() end
local baseplate = workspace:FindFirstChild("Baseplate")
if baseplate then baseplate:Destroy() end
-- Also remove any default SpawnLocations
for _, obj in ipairs(workspace:GetDescendants()) do
	if obj:IsA("SpawnLocation") then obj:Destroy() end
end

local mapFolder = Instance.new("Folder")
mapFolder.Name = "GeneratedMap"
mapFolder.Parent = workspace

local actualSeed = SEED == 0 and (os.time() + math.random(1, 99999)) or SEED
local rng = Random.new(actualSeed)
mapFolder:SetAttribute("Seed", actualSeed)
print("[Bootstrap] Using seed:", actualSeed)

for floor = 1, FLOORS do
	generateFloor(floor, rng, mapFolder)
	print("[Bootstrap] Floor", floor, "built. Theme:", getTheme(floor).Name)
end

-- Define buildLobby inside MAIN or call it
local function buildLobby(mapFolder)
	local lobbyFolder = Instance.new("Folder")
	lobbyFolder.Name = "Lobby"
	lobbyFolder.Parent = mapFolder

	local lobbyHeight = 100
	local sz = 60
	local wallH = 20
	local thick = 1

	-- Floor
	local floor = mp({
		Name = "Floor",
		Size = Vector3.new(sz, thick, sz),
		CFrame = CFrame.new(0, lobbyHeight - thick/2, 0),
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(60, 62, 65),
		Parent = lobbyFolder
	})

	-- Ceiling
	local ceiling = mp({
		Name = "Ceiling",
		Size = Vector3.new(sz, thick, sz),
		CFrame = CFrame.new(0, lobbyHeight + wallH + thick/2, 0),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(180, 180, 185),
		Parent = lobbyFolder
	})

	-- Walls
	mp({
		Name = "NorthWall",
		Size = Vector3.new(sz, wallH, thick),
		CFrame = CFrame.new(0, lobbyHeight + wallH/2, -sz/2),
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(90, 92, 95),
		Parent = lobbyFolder
	})
	mp({
		Name = "SouthWall",
		Size = Vector3.new(sz, wallH, thick),
		CFrame = CFrame.new(0, lobbyHeight + wallH/2, sz/2),
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(90, 92, 95),
		Parent = lobbyFolder
	})
	mp({
		Name = "EastWall",
		Size = Vector3.new(thick, wallH, sz),
		CFrame = CFrame.new(sz/2, lobbyHeight + wallH/2, 0),
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(90, 92, 95),
		Parent = lobbyFolder
	})
	mp({
		Name = "WestWall",
		Size = Vector3.new(thick, wallH, sz),
		CFrame = CFrame.new(-sz/2, lobbyHeight + wallH/2, 0),
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(90, 92, 95),
		Parent = lobbyFolder
	})

	-- Ceiling lights
	for _, x in ipairs({-15, 15}) do
		for _, z in ipairs({-15, 15}) do
			local lh = mp({
				Name = "LobbyCeilingLight",
				Size = Vector3.new(4, 0.3, 1),
				CFrame = CFrame.new(x, lobbyHeight + wallH - 0.2, z),
				Material = Enum.Material.Neon,
				Color = Color3.fromRGB(235, 230, 210),
				Parent = lobbyFolder
			})
			local l = Instance.new("SurfaceLight")
			l.Face = Enum.NormalId.Bottom
			l.Brightness = 1.5
			l.Range = 40
			l.Color = Color3.fromRGB(235, 230, 210)
			l.Parent = lh
		end
	end

	-- Default Spawn Location inside Lobby
	local spawnLoc = Instance.new("SpawnLocation")
	spawnLoc.Name = "LobbySpawn"
	spawnLoc.Anchored = true
	spawnLoc.CanCollide = true
	spawnLoc.Neutral = true
	spawnLoc.Size = Vector3.new(6, 0.2, 6)
	spawnLoc.CFrame = CFrame.new(0, lobbyHeight + 0.1, 0)
	spawnLoc.Color = Color3.fromRGB(80, 82, 85)
	spawnLoc.Material = Enum.Material.Concrete
	spawnLoc.TopSurface = Enum.SurfaceType.Smooth
	spawnLoc.Parent = lobbyFolder

	local spawnDecal = Instance.new("Decal")
	spawnDecal.Face = Enum.NormalId.Top
	spawnDecal.Texture = "rbxassetid://15264350172"
	spawnDecal.Transparency = 0.5
	spawnDecal.Parent = spawnLoc

	-- SP Elevator
	local spElev = Instance.new("Folder")
	spElev.Name = "SinglePlayerElevator"
	spElev.Parent = lobbyFolder

	local function makeElevatorBox(folder, name, xCenter, isLocked, titleText, titleColor)
		local zCenter = -sz/2 + 3
		-- Side Walls
		mp({
			Name = "LeftWall",
			Size = Vector3.new(0.2, 10, 6),
			CFrame = CFrame.new(xCenter - 4, lobbyHeight + 5, zCenter),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(60, 60, 65),
			Parent = folder
		})
		mp({
			Name = "RightWall",
			Size = Vector3.new(0.2, 10, 6),
			CFrame = CFrame.new(xCenter + 4, lobbyHeight + 5, zCenter),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(60, 60, 65),
			Parent = folder
		})
		-- Back Wall
		mp({
			Name = "BackWall",
			Size = Vector3.new(8, 10, 0.2),
			CFrame = CFrame.new(xCenter, lobbyHeight + 5, zCenter - 3),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(60, 60, 65),
			Parent = folder
		})
		-- Roof
		mp({
			Name = "Roof",
			Size = Vector3.new(8, 0.2, 6),
			CFrame = CFrame.new(xCenter, lobbyHeight + 10, zCenter),
			Material = Enum.Material.Metal,
			Color = Color3.fromRGB(60, 60, 65),
			Parent = folder
		})

		-- Glowing floor pad
		local pad = mp({
			Name = "GlowPad",
			Size = Vector3.new(7.6, 0.2, 5.6),
			CFrame = CFrame.new(xCenter, lobbyHeight + 0.1, zCenter),
			Material = Enum.Material.Neon,
			Color = isLocked and Color3.fromRGB(180, 50, 50) or Color3.fromRGB(50, 150, 220),
			CanCollide = false,
			Parent = folder
		})

		-- Billboard Gui above elevator opening
		local board = mp({
			Name = "Sign",
			Size = Vector3.new(8, 1.5, 0.2),
			CFrame = CFrame.new(xCenter, lobbyHeight + 10.75, zCenter + 3),
			Material = Enum.Material.SmoothPlastic,
			Color = Color3.fromRGB(30, 30, 32),
			Parent = folder
		})
		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.new(0, 300, 0, 80)
		bb.StudsOffset = Vector3.new(0, 0, 0.2)
		bb.AlwaysOnTop = true
		bb.Adornee = board
		bb.Parent = board

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.Code
		lbl.TextSize = 18
		lbl.TextColor3 = titleColor
		lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		lbl.TextStrokeTransparency = 0
		lbl.Text = titleText
		lbl.Parent = bb

		if isLocked then
			-- Locked visual: neon red bars across entrance
			for i = -3, 3, 2 do
				local bar = mp({
					Name = "GateBar",
					Size = Vector3.new(0.2, 10, 0.2),
					CFrame = CFrame.new(xCenter + i, lobbyHeight + 5, zCenter + 3),
					Material = Enum.Material.Neon,
					Color = Color3.fromRGB(180, 50, 50),
					Parent = folder
				})
			end
			-- Locked control panel
			local panel = mp({
				Name = "LockedPanel",
				Size = Vector3.new(0.2, 1.5, 1),
				CFrame = CFrame.new(xCenter + 3.8, lobbyHeight + 3.5, zCenter + 1),
				Material = Enum.Material.Metal,
				Color = Color3.fromRGB(70, 70, 75),
				Parent = folder
			})
			local btn = mp({
				Name = "Button",
				Size = Vector3.new(0.25, 0.3, 0.3),
				CFrame = CFrame.new(xCenter + 3.9, lobbyHeight + 3.8, zCenter + 1),
				Material = Enum.Material.Neon,
				Color = Color3.fromRGB(180, 50, 50),
				Parent = folder
			})
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "LOCKED"
			prompt.ObjectText = "Coming Soon"
			prompt.MaxActivationDistance = 0
			prompt.Parent = panel
		else
			-- Active elevator: panel with trigger prompt
			local panel = mp({
				Name = "ElevatorPanel",
				Size = Vector3.new(0.2, 1.5, 1),
				CFrame = CFrame.new(xCenter + 3.8, lobbyHeight + 3.5, zCenter + 1),
				Material = Enum.Material.Metal,
				Color = Color3.fromRGB(70, 70, 75),
				Parent = folder
			})
			local btn = mp({
				Name = "ElevatorButton",
				Size = Vector3.new(0.25, 0.3, 0.3),
				CFrame = CFrame.new(xCenter + 3.9, lobbyHeight + 3.8, zCenter + 1),
				Material = Enum.Material.Neon,
				Color = Color3.fromRGB(50, 180, 80),
				Parent = folder
			})
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Start Game"
			prompt.ObjectText = "Single Player"
			prompt.MaxActivationDistance = 8
			prompt.HoldDuration = 0.5
			prompt.Parent = panel
			game:GetService("CollectionService"):AddTag(panel, "SinglePlayerStartPanel")
		end
	end

	makeElevatorBox(spElev, "SinglePlayer", -15, false, "SINGLE PLAYER\n[READY]", Color3.fromRGB(50, 200, 220))

	-- Co-op Elevator
	local coopElev = Instance.new("Folder")
	coopElev.Name = "CoopElevator"
	coopElev.Parent = lobbyFolder
	makeElevatorBox(coopElev, "Coop", 0, true, "MULTIPLAYER CO-OP\n[COMING SOON]", Color3.fromRGB(180, 50, 50))

	-- Endless Elevator
	local endlessElev = Instance.new("Folder")
	endlessElev.Name = "EndlessElevator"
	endlessElev.Parent = lobbyFolder
	makeElevatorBox(endlessElev, "Endless", 15, true, "ENDLESS MODE\n[COMING SOON]", Color3.fromRGB(180, 50, 50))

	-- Monetization Shop Pads
	local function makeShopPad(name, x, z, col, labelText)
		local pad = Instance.new("Part")
		pad.Name = name
		pad.Shape = Enum.PartType.Cylinder
		pad.Size = Vector3.new(0.2, 6, 6)
		pad.CFrame = CFrame.new(x, lobbyHeight + 0.1, z) * CFrame.Angles(0, 0, math.rad(90))
		pad.Anchored = true
		pad.CanCollide = false
		pad.Material = Enum.Material.Neon
		pad.Color = col
		pad.Parent = lobbyFolder

		local bb = Instance.new("BillboardGui")
		bb.Size = UDim2.new(0, 250, 0, 60)
		bb.StudsOffset = Vector3.new(0, 4, 0)
		bb.AlwaysOnTop = true
		bb.Adornee = pad
		bb.Parent = pad

		local lbl = Instance.new("TextLabel")
		lbl.Size = UDim2.new(1, 0, 1, 0)
		lbl.BackgroundTransparency = 1
		lbl.Font = Enum.Font.Code
		lbl.TextSize = 14
		lbl.TextColor3 = col
		lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
		lbl.TextStrokeTransparency = 0
		lbl.Text = labelText .. "\n[SHOP COMING SOON]"
		lbl.Parent = bb
	end

	makeShopPad("FlashlightShopPad", -15, 15, Color3.fromRGB(220, 220, 50), "FLASHLIGHT UPGRADES")
	makeShopPad("CosmeticsShopPad", 15, 15, Color3.fromRGB(160, 50, 220), "COSMETIC TRAILS")

	-- CRT Stats Terminal Console
	local consoleFolder = Instance.new("Folder")
	consoleFolder.Name = "StatsTerminal"
	consoleFolder.Parent = lobbyFolder

	local consoleBase = mp({
		Name = "ConsoleBase",
		Size = Vector3.new(1.5, 3.5, 4),
		CFrame = CFrame.new(sz/2 - 1.25, lobbyHeight + 1.75, 0),
		Material = Enum.Material.Concrete,
		Color = Color3.fromRGB(50, 50, 52),
		Parent = consoleFolder
	})
	local monitor = mp({
		Name = "Monitor",
		Size = Vector3.new(1.5, 2.5, 3.5),
		CFrame = CFrame.new(sz/2 - 1.25, lobbyHeight + 4.75, 0),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(40, 40, 42),
		Parent = consoleFolder
	})
	local screen = mp({
		Name = "Screen",
		Size = Vector3.new(0.1, 2.2, 3.2),
		CFrame = CFrame.new(sz/2 - 2.05, lobbyHeight + 4.75, 0),
		Material = Enum.Material.Glass,
		Color = Color3.fromRGB(10, 15, 10),
		Parent = consoleFolder
	})

	local sg = Instance.new("SurfaceGui")
	sg.Face = Enum.NormalId.West
	sg.CanvasSize = Vector2.new(400, 300)
	sg.Parent = screen

	local screenFrame = Instance.new("Frame")
	screenFrame.Size = UDim2.new(1, 0, 1, 0)
	screenFrame.BackgroundColor3 = Color3.fromRGB(10, 20, 10)
	screenFrame.BorderSizePixel = 0
	screenFrame.Parent = sg

	local screenText = Instance.new("TextLabel")
	screenText.Size = UDim2.new(0.9, 0, 0.9, 0)
	screenText.Position = UDim2.new(0.05, 0, 0.05, 0)
	screenText.BackgroundTransparency = 1
	screenText.Font = Enum.Font.Code
	screenText.TextSize = 14
	screenText.TextColor3 = Color3.fromRGB(50, 255, 50)
	screenText.TextXAlignment = Enum.TextXAlignment.Left
	screenText.TextYAlignment = Enum.TextYAlignment.Top
	screenText.Text = "=== SYSTEM DIAGNOSTICS ===\n\nLOBBY SYSTEM: ACTIVE\nSINGLE PLAYER PORTAL: READY\nCO-OP SYSTEM: OFFLINE\nMONITORING ANOMALY: DECIBEL\nFACILITY DEPTH: 50 FLOORS\n\nSTATUS: AWAITING EXPEDITION..."
	screenText.Parent = screenFrame

	-- Obby / Parkour Course
	local obbyFolder = Instance.new("Folder")
	obbyFolder.Name = "Obby"
	obbyFolder.Parent = lobbyFolder

	local obbySteps = {
		{ Pos = Vector3.new(-28, 102, -20), Size = Vector3.new(3, 0.8, 3), Mat = Enum.Material.Concrete, Col = Color3.fromRGB(70, 72, 75) },
		{ Pos = Vector3.new(-28, 104.5, -12), Size = Vector3.new(1, 0.8, 4), Mat = Enum.Material.Metal, Col = Color3.fromRGB(100, 100, 105) },
		{ Pos = Vector3.new(-28, 107, -4), Size = Vector3.new(3, 0.8, 3), Mat = Enum.Material.Concrete, Col = Color3.fromRGB(70, 72, 75) },
		{ Pos = Vector3.new(-28, 109.5, 4), Size = Vector3.new(3, 0.8, 3), Mat = Enum.Material.Concrete, Col = Color3.fromRGB(70, 72, 75) },
		{ Pos = Vector3.new(-25, 112, 12), Size = Vector3.new(1, 0.8, 4), Mat = Enum.Material.Metal, Col = Color3.fromRGB(100, 100, 105) },
		{ Pos = Vector3.new(-18, 114, 20), Size = Vector3.new(3, 0.8, 3), Mat = Enum.Material.Concrete, Col = Color3.fromRGB(70, 72, 75) },
		{ Pos = Vector3.new(-10, 116, 26), Size = Vector3.new(3, 0.8, 3), Mat = Enum.Material.Concrete, Col = Color3.fromRGB(70, 72, 75) },
		{ Pos = Vector3.new(0, 117.5, 27), Size = Vector3.new(3, 0.8, 3), Mat = Enum.Material.Concrete, Col = Color3.fromRGB(70, 72, 75) },
		{ Pos = Vector3.new(10, 118, 27), Size = Vector3.new(3, 0.8, 3), Mat = Enum.Material.Concrete, Col = Color3.fromRGB(70, 72, 75) },
		{ Pos = Vector3.new(20, 118.5, 26), Size = Vector3.new(5, 0.8, 5), Mat = Enum.Material.Concrete, Col = Color3.fromRGB(50, 52, 55), IsTrophyPlatform = true },
	}

	for _, step in ipairs(obbySteps) do
		local p = mp({
			Name = "ObbyStep",
			Size = step.Size,
			CFrame = CFrame.new(step.Pos),
			Material = step.Mat,
			Color = step.Col,
			Parent = obbyFolder
		})

		if step.IsTrophyPlatform then
			local trophyFolder = Instance.new("Folder")
			trophyFolder.Name = "PrototypeTrophy"
			trophyFolder.Parent = lobbyFolder

			local tBase = mp({
				Name = "TrophyBase",
				Size = Vector3.new(1.2, 0.3, 1.2),
				CFrame = CFrame.new(step.Pos + Vector3.new(0, 0.55, 0)),
				Material = Enum.Material.Metal,
				Color = Color3.fromRGB(150, 120, 40),
				Parent = trophyFolder
			})
			local tStem = mp({
				Name = "TrophyStem",
				Size = Vector3.new(0.4, 0.6, 0.4),
				CFrame = CFrame.new(step.Pos + Vector3.new(0, 1.0, 0)),
				Material = Enum.Material.Metal,
				Color = Color3.fromRGB(150, 120, 40),
				Parent = trophyFolder
			})
			local tCup = mp({
				Name = "TrophyCup",
				Size = Vector3.new(1.0, 1.0, 1.0),
				CFrame = CFrame.new(step.Pos + Vector3.new(0, 1.8, 0)),
				Material = Enum.Material.Neon,
				Color = Color3.fromRGB(255, 215, 0),
				Parent = trophyFolder
			})

			local pl = Instance.new("PointLight")
			pl.Brightness = 1.0
			pl.Range = 10
			pl.Color = Color3.fromRGB(255, 215, 0)
			pl.Parent = tCup

			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Inspect Trophy"
			prompt.ObjectText = "Obby Champion"
			prompt.MaxActivationDistance = 8
			prompt.HoldDuration = 1.0
			prompt.Parent = tCup
			game:GetService("CollectionService"):AddTag(tCup, "LobbyTrophy")

			local bb = Instance.new("BillboardGui")
			bb.Size = UDim2.new(0, 200, 0, 50)
			bb.StudsOffset = Vector3.new(0, 1.5, 0)
			bb.AlwaysOnTop = true
			bb.Adornee = tCup
			bb.Parent = tCup

			local lbl = Instance.new("TextLabel")
			lbl.Size = UDim2.new(1, 0, 1, 0)
			lbl.BackgroundTransparency = 1
			lbl.Font = Enum.Font.Code
			lbl.TextSize = 14
			lbl.TextColor3 = Color3.fromRGB(255, 215, 0)
			lbl.TextStrokeColor3 = Color3.fromRGB(0, 0, 0)
			lbl.TextStrokeTransparency = 0
			lbl.Text = "🏆 PROTOTYPE TROPHY 🏆"
			lbl.Parent = bb
		end
	end
end

buildLobby(mapFolder)

print("[Bootstrap] Done! "..FLOORS.." floors + Lobby built. SAVE the place!")
