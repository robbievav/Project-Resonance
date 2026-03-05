--[[
	Bootstrap.lua — Project: Resonance
	Paste this entire script into the Roblox Studio COMMAND BAR and press Enter.
	It creates all map geometry permanently in the place: rooms, hallways, doors,
	furniture, hiding spots, stairwells, and the spawn location.

	After running, SAVE the place file. The geometry persists across sessions.
	The runtime scripts (DecibelAI, DoorSystem, etc.) reference these existing parts.

	To regenerate with a different seed, run this script again (it clears the old map first).
]]

-----------------------------------------------------------------------
-- CONFIG (same values as Config.lua)
-----------------------------------------------------------------------
local SEED            = 42        -- fixed seed for the permanent build
local FLOORS          = 3         -- floors to bake (increase as needed)
local GRID_SIZE       = 5
local ROOM_UNIT       = 24
local HALLWAY_WIDTH   = 8
local WALL_HEIGHT     = 12
local WALL_THICKNESS  = 1
local DOOR_WIDTH      = 5
local DOOR_HEIGHT     = 8
local FLOOR_SEP       = 50
local STAIRWELL_ROW   = 2
local STAIRWELL_COL   = 4
local FLICKER_CHANCE  = 0.25
local FLUOR_BRIGHTNESS = 1.2
local FLUOR_RANGE     = 30

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

local function getTheme(floorIdx)
	for _, t in ipairs(THEMES) do
		if floorIdx >= t.Range[1] and floorIdx <= t.Range[2] then return t end
	end
	return THEMES[1]
end

-- Room Weights
local ROOM_WEIGHTS = {
	Hallway=25, Office=20, MaintenanceTunnel=12, ObservationDeck=8, SafeHub=4,
	StorageRoom=12, Laboratory=10, Bathroom=8, ServerRoom=6,
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
-- ROOM TEMPLATES (inline)
-----------------------------------------------------------------------
local function door(wall, off) return { Wall=wall, Offset=off } end
local function fix(t, ox, oy, oz, rot) return { Type=t, Offset=Vector3.new(ox,oy,oz), Rotation=rot or 0 } end

local ROOMS = {}

ROOMS.Hallway = {
	Name="Hallway", SM=Vector3.new(3,1,1), FloorMat="SmoothPlastic", FloorCol=C.FloorTile,
	WallMat="Concrete", WallCol=C.WallPaint, CeilCol=C.CeilingPanel,
	Doors={door("NegZ",0), door("PosZ",0)},
	Fixtures={fix("Fluor",0,11.5,-8), fix("Fluor",0,11.5,0), fix("Fluor",0,11.5,8)},
	Furniture={}, HidingSpots={},
}

ROOMS.Office = {
	Name="Office", SM=Vector3.new(1.5,1,1.5), FloorMat="SmoothPlastic", FloorCol=C.FloorTile,
	WallMat="Concrete", WallCol=C.WallPaint, CeilCol=C.CeilingPanel,
	Doors={door("NegZ",-3)},
	Fixtures={fix("Fluor",0,11.5,0), fix("Fluor",-6,11.5,5)},
	Furniture={fix("Desk",-6,0,-4,0), fix("Desk",-6,0,4,0), fix("Desk",4,0,-4,180),
		fix("FileCab",7,0,-7,90), fix("FileCab",7,0,7,90), fix("Chair",-4,0,-4,30),
		fix("Chair",-4,0,4,-20), fix("WaterCooler",7,0,0,-90)},
	HidingSpots={{Type="UnderDesk",Off=Vector3.new(-6,0,-4),Rot=0},{Type="UnderDesk",Off=Vector3.new(4,0,-4),Rot=180}},
}

ROOMS.MaintenanceTunnel = {
	Name="MaintenanceTunnel", SM=Vector3.new(2.5,0.75,0.6), FloorMat="DiamondPlate", FloorCol=C.MetalGrate,
	WallMat="Concrete", WallCol=C.DarkConcrete, CeilCol=C.DarkConcrete,
	Doors={door("NegZ",0), door("PosZ",0)},
	Fixtures={fix("DimBulb",0,7,-6), fix("DimBulb",0,7,6), fix("Pipe",-2,8,0), fix("Pipe",2,8,0)},
	Furniture={fix("Barrel",2,0,-4), fix("ToolBox",-2,0,5)},
	HidingSpots={{Type="Locker",Off=Vector3.new(-3,0,-6),Rot=0}},
}

ROOMS.ObservationDeck = {
	Name="ObservationDeck", SM=Vector3.new(2,1,2), FloorMat="Marble", FloorCol=C.FloorTile,
	WallMat="Concrete", WallCol=C.WallPaint, CeilCol=C.CeilingPanel,
	Doors={door("NegX",0)},
	Fixtures={fix("Fluor",0,11.5,0), fix("Fluor",-8,11.5,-8), fix("Fluor",8,11.5,8),
		fix("Window",10,5,-8,90), fix("Window",10,5,0,90), fix("Window",10,5,8,90)},
	Furniture={fix("Console",-6,0,0,0), fix("Console",-6,0,6,0), fix("MonitorBank",8,3,-6,90),
		fix("Chair",-4,0,0,0), fix("Chair",-4,0,6,0)},
	HidingSpots={},
}

ROOMS.SafeHub = {
	Name="SafeHub", SM=Vector3.new(2,1.2,2), FloorMat="Marble", FloorCol=C.FloorTile,
	WallMat="Concrete", WallCol=C.WallPaint, CeilCol=C.CeilingPanel, IsSafe=true,
	Doors={door("NegZ",0)},
	Fixtures={fix("Fluor",-6,13,-6), fix("Fluor",6,13,-6), fix("Fluor",-6,13,6), fix("Fluor",6,13,6)},
	Furniture={fix("Desk",-8,0,-8,0), fix("Desk",8,0,-8,180), fix("Cot",8,0,6,0), fix("MedKit",-8,3,8,0), fix("Locker",-9,0,0,-90)},
	HidingSpots={{Type="Locker",Off=Vector3.new(-9,0,0),Rot=-90}},
}

ROOMS.StorageRoom = {
	Name="StorageRoom", SM=Vector3.new(1.5,1,1.5), FloorMat="SmoothPlastic", FloorCol=C.DarkConcrete,
	WallMat="Concrete", WallCol=C.DarkConcrete, CeilCol=C.DarkConcrete,
	Doors={door("NegZ",0)},
	Fixtures={fix("DimBulb",0,11,0), fix("DimBulb",-6,11,-5)},
	Furniture={fix("ShelfUnit",-7,0,-6,0), fix("ShelfUnit",-7,0,0,0), fix("ShelfUnit",7,0,-6,180), fix("ShelfUnit",7,0,3,180),
		fix("Crate",0,0,-5,15), fix("Crate",2,0,-3,-10), fix("Barrel",-3,0,6,0), fix("Locker",5,0,7,90)},
	HidingSpots={{Type="Locker",Off=Vector3.new(5,0,7),Rot=90},{Type="ShelfCrawl",Off=Vector3.new(-7,0,-3),Rot=0}},
}

ROOMS.Laboratory = {
	Name="Laboratory", SM=Vector3.new(2,1,1.5), FloorMat="Marble", FloorCol=C.LabWhite,
	WallMat="Concrete", WallCol=C.LabWhite, CeilCol=C.CeilingPanel,
	Doors={door("NegZ",-4), door("PosX",0)},
	Fixtures={fix("Fluor",-6,11.5,0), fix("Fluor",6,11.5,0)},
	Furniture={fix("LabBench",-8,0,-4,0), fix("LabBench",-8,0,4,0), fix("LabBench",4,0,-4,180),
		fix("FileCab",10,0,-8,90), fix("Chair",-6,0,-4,30), fix("Chair",6,0,-4,-30)},
	HidingSpots={{Type="UnderDesk",Off=Vector3.new(-8,0,4),Rot=0}},
}

ROOMS.Bathroom = {
	Name="Bathroom", SM=Vector3.new(1.2,0.9,1), FloorMat="Marble", FloorCol=C.TileWhite,
	WallMat="Marble", WallCol=C.TileWhite, CeilCol=C.CeilingPanel,
	Doors={door("NegZ",0)},
	Fixtures={fix("Fluor",0,10,0), fix("Pipe",-4,9,0)},
	Furniture={fix("BathroomStall",-5,0,-3,0), fix("BathroomStall",-5,0,3,0), fix("BathroomStall",0,0,-3,0), fix("BathroomSink",5,0,0,90)},
	HidingSpots={{Type="StallHide",Off=Vector3.new(-5,0,3),Rot=0},{Type="StallHide",Off=Vector3.new(0,0,-3),Rot=0}},
}

ROOMS.ServerRoom = {
	Name="ServerRoom", SM=Vector3.new(1.5,1.2,2), FloorMat="DiamondPlate", FloorCol=C.MetalGrate,
	WallMat="Concrete", WallCol=C.ServerBlue, CeilCol=C.DarkConcrete,
	Doors={door("NegZ",0)},
	Fixtures={fix("DimBulb",0,13,0), fix("Pipe",-6,13,0), fix("Pipe",6,13,0)},
	Furniture={fix("ServerRack",-7,0,-8,0), fix("ServerRack",-7,0,-2,0), fix("ServerRack",-7,0,4,0),
		fix("ServerRack",7,0,-8,180), fix("ServerRack",7,0,-2,180), fix("ServerRack",7,0,4,180), fix("Console",0,0,8,0)},
	HidingSpots={{Type="RackGap",Off=Vector3.new(-7,0,1),Rot=0},{Type="RackGap",Off=Vector3.new(7,0,1),Rot=180}},
}

ROOMS.Elevator = {
	Name="Elevator", SM=Vector3.new(0.5,1.5,0.5), FloorMat="DiamondPlate", FloorCol=C.MetalGrate,
	WallMat="Concrete", WallCol=C.DarkConcrete, CeilCol=C.DarkConcrete, IsSafe=true,
	Doors={door("PosZ",0)},
	Fixtures={fix("DimBulb",0,14,0)},
	Furniture={fix("ElevatorPanel",5.85,3,0,90)},
	HidingSpots={},
}

ROOMS.Stairwell = {
	Name="Stairwell", SM=Vector3.new(1,2,1), FloorMat="Concrete", FloorCol=C.DarkConcrete,
	WallMat="Concrete", WallCol=C.DarkConcrete, CeilCol=C.DarkConcrete, IsStairwell=true,
	Doors={door("NegZ",0)},
	Fixtures={fix("DimBulb",0,20,0), fix("DimBulb",0,10,0)},
	Furniture={}, HidingSpots={},
}

-----------------------------------------------------------------------
-- FURNITURE BUILDERS
-----------------------------------------------------------------------
local function buildDesk(pos, rot, parent)
	local r = CFrame.Angles(0,math.rad(rot),0)
	mp({Name="DeskTop",Size=Vector3.new(5,0.3,2.5),CFrame=CFrame.new(pos+Vector3.new(0,2.5,0))*r,Material=Enum.Material.Wood,Color=Color3.fromRGB(130,100,70),Parent=parent})
	for _,lx in ipairs({-2.2,2.2}) do for _,lz in ipairs({-1,1}) do
		mp({Name="DeskLeg",Size=Vector3.new(0.3,2.5,0.3),CFrame=CFrame.new(pos+Vector3.new(lx,1.25,lz))*r,Material=Enum.Material.Metal,Color=Color3.fromRGB(90,90,90),Parent=parent})
	end end
end

local function buildChair(pos, rot, parent)
	local r = CFrame.Angles(0,math.rad(rot),0)
	mp({Name="ChairSeat",Size=Vector3.new(2,0.3,2),CFrame=CFrame.new(pos+Vector3.new(0,1.8,0))*r,Material=Enum.Material.Fabric,Color=Color3.fromRGB(60,65,75),Parent=parent})
	mp({Name="ChairBack",Size=Vector3.new(2,2,0.3),CFrame=CFrame.new(pos+Vector3.new(0,2.8,-1))*r,Material=Enum.Material.Fabric,Color=Color3.fromRGB(60,65,75),Parent=parent})
end

local function buildFileCab(pos, rot, parent)
	local r = CFrame.Angles(0,math.rad(rot),0)
	mp({Name="FilingCabinet",Size=Vector3.new(2,4,1.5),CFrame=CFrame.new(pos+Vector3.new(0,2,0))*r,Material=Enum.Material.Metal,Color=Color3.fromRGB(110,110,105),Parent=parent})
end

local function buildWaterCooler(pos, rot, parent)
	local r = CFrame.Angles(0,math.rad(rot),0)
	mp({Name="WaterCoolerBody",Size=Vector3.new(1.2,3.5,1.2),CFrame=CFrame.new(pos+Vector3.new(0,1.75,0))*r,Material=Enum.Material.SmoothPlastic,Color=Color3.fromRGB(200,200,195),Parent=parent})
	local jug = mp({Name="WaterJug",Size=Vector3.new(0.8,1.2,0.8),CFrame=CFrame.new(pos+Vector3.new(0,4.1,0))*r,Material=Enum.Material.Glass,Color=Color3.fromRGB(140,180,210),Parent=parent})
	jug.Transparency = 0.4
end

local function buildBarrel(pos, rot, parent)
	mp({Name="Barrel",Size=Vector3.new(2,3,2),CFrame=CFrame.new(pos+Vector3.new(0,1.5,0))*CFrame.Angles(0,math.rad(rot),0),Material=Enum.Material.Metal,Color=C.Rust,Parent=parent})
end

local function buildToolBox(pos, rot, parent)
	mp({Name="ToolBox",Size=Vector3.new(2,1,1),CFrame=CFrame.new(pos+Vector3.new(0,0.5,0))*CFrame.Angles(0,math.rad(rot),0),Material=Enum.Material.Metal,Color=Color3.fromRGB(180,50,40),Parent=parent})
end

local function buildConsole(pos, rot, parent)
	local r = CFrame.Angles(0,math.rad(rot),0)
	mp({Name="ConsoleDeck",Size=Vector3.new(4,2.5,2),CFrame=CFrame.new(pos+Vector3.new(0,1.25,0))*r,Material=Enum.Material.Metal,Color=Color3.fromRGB(70,70,75),Parent=parent})
	local scr = mp({Name="ConsoleScreen",Size=Vector3.new(3,2,0.2),CFrame=CFrame.new(pos+Vector3.new(0,3.5,-0.8))*r*CFrame.Angles(math.rad(-15),0,0),Material=Enum.Material.Neon,Color=Color3.fromRGB(30,80,50),Parent=parent})
	scr.Transparency = 0.2
end

local function buildMonitorBank(pos, rot, parent)
	local r = CFrame.Angles(0,math.rad(rot),0)
	for i=0,2 do
		local scr = mp({Name="Monitor",Size=Vector3.new(0.2,2,2.5),CFrame=CFrame.new(pos+Vector3.new(0,i*2.2,0))*r,Material=Enum.Material.Neon,Color=Color3.fromRGB(20,30,20),Parent=parent})
		scr.Transparency = 0.3
	end
end

local function buildCot(pos, rot, parent)
	local r = CFrame.Angles(0,math.rad(rot),0)
	mp({Name="CotFrame",Size=Vector3.new(3,0.8,6),CFrame=CFrame.new(pos+Vector3.new(0,0.4,0))*r,Material=Enum.Material.Metal,Color=Color3.fromRGB(90,90,90),Parent=parent})
	mp({Name="CotMattress",Size=Vector3.new(2.6,0.4,5.6),CFrame=CFrame.new(pos+Vector3.new(0,1,0))*r,Material=Enum.Material.Fabric,Color=Color3.fromRGB(120,130,120),Parent=parent})
end

local function buildMedKit(pos, rot, parent)
	local kit = mp({Name="MedKit",Size=Vector3.new(1.5,1,0.5),CFrame=CFrame.new(pos)*CFrame.Angles(0,math.rad(rot),0),Material=Enum.Material.SmoothPlastic,Color=Color3.fromRGB(200,200,200),Parent=parent})
	local pp = Instance.new("ProximityPrompt"); pp.ActionText="Take"; pp.ObjectText="Med Kit"; pp.MaxActivationDistance=6; pp.Parent=kit
end

local function buildLocker(pos, rot, parent)
	mp({Name="Locker",Size=Vector3.new(1.5,6,2),CFrame=CFrame.new(pos+Vector3.new(0,3,0))*CFrame.Angles(0,math.rad(rot),0),Material=Enum.Material.Metal,Color=Color3.fromRGB(95,100,95),Parent=parent})
end

local function buildElevatorPanel(pos, rot, parent)
	local r = CFrame.Angles(0,math.rad(rot),0)
	mp({Name="ElevatorPanel",Size=Vector3.new(0.3,1.5,1),CFrame=CFrame.new(pos)*r,Material=Enum.Material.Metal,Color=Color3.fromRGB(70,70,75),Parent=parent})
	mp({Name="ElevatorButton",Size=Vector3.new(0.35,0.3,0.3),CFrame=CFrame.new(pos+Vector3.new(-0.05,0.3,0))*r,Material=Enum.Material.Neon,Color=Color3.fromRGB(200,60,40),Parent=parent})
end

local function buildShelfUnit(pos, rot, parent)
	local r = CFrame.Angles(0,math.rad(rot),0)
	mp({Name="ShelfFrame",Size=Vector3.new(1.5,8,4),CFrame=CFrame.new(pos+Vector3.new(0,4,0))*r,Material=Enum.Material.Metal,Color=Color3.fromRGB(90,90,85),Parent=parent})
	for _,sy in ipairs({1.5,3.5,5.5,7.5}) do
		mp({Name="Shelf",Size=Vector3.new(2,0.2,4),CFrame=CFrame.new(pos+Vector3.new(0,sy,0))*r,Material=Enum.Material.Wood,Color=Color3.fromRGB(110,95,70),Parent=parent})
	end
end

local function buildCrate(pos, rot, parent)
	mp({Name="Crate",Size=Vector3.new(3,2.5,3),CFrame=CFrame.new(pos+Vector3.new(0,1.25,0))*CFrame.Angles(0,math.rad(rot),0),Material=Enum.Material.Wood,Color=C.Crate,Parent=parent})
end

local function buildLabBench(pos, rot, parent)
	local r = CFrame.Angles(0,math.rad(rot),0)
	mp({Name="LabBenchTop",Size=Vector3.new(6,0.3,3),CFrame=CFrame.new(pos+Vector3.new(0,2.8,0))*r,Material=Enum.Material.SmoothPlastic,Color=C.LabBench,Parent=parent})
	for _,lx in ipairs({-2.5,2.5}) do for _,lz in ipairs({-1.2,1.2}) do
		mp({Name="LabBenchLeg",Size=Vector3.new(0.3,2.8,0.3),CFrame=CFrame.new(pos+Vector3.new(lx,1.4,lz))*r,Material=Enum.Material.Metal,Color=Color3.fromRGB(80,80,80),Parent=parent})
	end end
	mp({Name="Beaker",Size=Vector3.new(0.4,0.8,0.4),CFrame=CFrame.new(pos+Vector3.new(1,3.3,0))*r,Material=Enum.Material.Glass,Color=Color3.fromRGB(180,200,180),Parent=parent})
end

local function buildBathroomStall(pos, rot, parent)
	local r = CFrame.Angles(0,math.rad(rot),0)
	mp({Name="StallWallL",Size=Vector3.new(0.2,5,4),CFrame=CFrame.new(pos+Vector3.new(-1.5,2.5,0))*r,Material=Enum.Material.SmoothPlastic,Color=Color3.fromRGB(180,180,175),Parent=parent})
	mp({Name="StallWallR",Size=Vector3.new(0.2,5,4),CFrame=CFrame.new(pos+Vector3.new(1.5,2.5,0))*r,Material=Enum.Material.SmoothPlastic,Color=Color3.fromRGB(180,180,175),Parent=parent})
	mp({Name="StallDoor",Size=Vector3.new(2.8,4,0.15),CFrame=CFrame.new(pos+Vector3.new(0,2,-2))*r,Material=Enum.Material.SmoothPlastic,Color=Color3.fromRGB(170,170,165),Parent=parent})
	mp({Name="Toilet",Size=Vector3.new(1.2,1.5,1.5),CFrame=CFrame.new(pos+Vector3.new(0,0.75,1))*r,Material=Enum.Material.SmoothPlastic,Color=Color3.fromRGB(230,230,225),Parent=parent})
end

local function buildBathroomSink(pos, rot, parent)
	local r = CFrame.Angles(0,math.rad(rot),0)
	mp({Name="SinkCounter",Size=Vector3.new(0.5,2.5,6),CFrame=CFrame.new(pos+Vector3.new(0,1.25,0))*r,Material=Enum.Material.SmoothPlastic,Color=Color3.fromRGB(200,200,195),Parent=parent})
	local mir = mp({Name="Mirror",Size=Vector3.new(0.1,3,5),CFrame=CFrame.new(pos+Vector3.new(-0.1,4,0))*r,Material=Enum.Material.Glass,Color=Color3.fromRGB(150,160,170),Parent=parent})
	mir.Transparency = 0.3; mir.Reflectance = 0.4
end

local function buildServerRack(pos, rot, parent)
	local r = CFrame.Angles(0,math.rad(rot),0)
	mp({Name="ServerRackBody",Size=Vector3.new(2,8,3),CFrame=CFrame.new(pos+Vector3.new(0,4,0))*r,Material=Enum.Material.Metal,Color=Color3.fromRGB(30,30,35),Parent=parent})
	for i=1,5 do
		mp({Name="ServerLED",Size=Vector3.new(0.1,0.15,0.15),CFrame=CFrame.new(pos+Vector3.new(-1.05,1.5+i*1.1,0.5))*r,Material=Enum.Material.Neon,Color=Color3.fromRGB(30,120,200),Parent=parent})
	end
end

-- Dispatch
local BUILDERS = {
	Desk=buildDesk, Chair=buildChair, FileCab=buildFileCab, WaterCooler=buildWaterCooler,
	Barrel=buildBarrel, ToolBox=buildToolBox, Console=buildConsole, MonitorBank=buildMonitorBank,
	Cot=buildCot, MedKit=buildMedKit, Locker=buildLocker, ElevatorPanel=buildElevatorPanel,
	ShelfUnit=buildShelfUnit, Crate=buildCrate, LabBench=buildLabBench, BathroomStall=buildBathroomStall,
	BathroomSink=buildBathroomSink, ServerRack=buildServerRack,
}

-----------------------------------------------------------------------
-- ROOM BUILDER
-----------------------------------------------------------------------
local function buildRoom(template, origin, floorFolder, floorIdx)
	local sx = ROOM_UNIT * template.SM.X
	local sz = ROOM_UNIT * template.SM.Z
	local height = WALL_HEIGHT * template.SM.Y
	local thick = WALL_THICKNESS
	local theme = getTheme(floorIdx)
	local wallColor = theme.WallColor
	local wallMat = getMat(theme.WallMat)
	local lightMult = theme.LightMult

	local roomFolder = Instance.new("Folder")
	roomFolder.Name = template.Name
	roomFolder.Parent = floorFolder

	-- Floor
	mp({Name="Floor",Size=Vector3.new(sx,thick,sz),CFrame=CFrame.new(origin+Vector3.new(0,-thick/2,0)),Material=getMat(template.FloorMat),Color=template.FloorCol,Parent=roomFolder})
	-- Ceiling
	mp({Name="Ceiling",Size=Vector3.new(sx,thick,sz),CFrame=CFrame.new(origin+Vector3.new(0,height+thick/2,0)),Material=Enum.Material.SmoothPlastic,Color=template.CeilCol,Parent=roomFolder})

	-- Walls with door cutouts
	local doorSet = {}
	for _, d in ipairs(template.Doors) do doorSet[d.Wall] = d end

	local walls = {
		{side="PosX", size=Vector3.new(thick,height,sz), pos=Vector3.new(sx/2,height/2,0)},
		{side="NegX", size=Vector3.new(thick,height,sz), pos=Vector3.new(-sx/2,height/2,0)},
		{side="PosZ", size=Vector3.new(sx,height,thick), pos=Vector3.new(0,height/2,sz/2)},
		{side="NegZ", size=Vector3.new(sx,height,thick), pos=Vector3.new(0,height/2,-sz/2)},
	}

	for _, w in ipairs(walls) do
		if doorSet[w.side] then
			local dw,dh,dOff = DOOR_WIDTH, DOOR_HEIGHT, doorSet[w.side].Offset
			local aboveH = height - dh
			local isZ = (w.side == "PosZ" or w.side == "NegZ")
			if aboveH > 0 then
				if isZ then
					mp({Name="WallAboveDoor",Size=Vector3.new(dw,aboveH,thick),CFrame=CFrame.new(origin+w.pos+Vector3.new(dOff,(height-aboveH)/2,0)),Material=wallMat,Color=wallColor,Parent=roomFolder})
				else
					mp({Name="WallAboveDoor",Size=Vector3.new(thick,aboveH,dw),CFrame=CFrame.new(origin+w.pos+Vector3.new(0,(height-aboveH)/2,dOff)),Material=wallMat,Color=wallColor,Parent=roomFolder})
				end
			end
			local lw,rw
			if isZ then lw=sx/2+dOff-dw/2; rw=sx/2-dOff-dw/2 else lw=sz/2+dOff-dw/2; rw=sz/2-dOff-dw/2 end
			if lw > 0.1 then
				if isZ then mp({Name="WallLeft",Size=Vector3.new(lw,height,thick),CFrame=CFrame.new(origin+w.pos+Vector3.new(dOff-dw/2-lw/2,0,0)),Material=wallMat,Color=wallColor,Parent=roomFolder})
				else mp({Name="WallLeft",Size=Vector3.new(thick,height,lw),CFrame=CFrame.new(origin+w.pos+Vector3.new(0,0,dOff-dw/2-lw/2)),Material=wallMat,Color=wallColor,Parent=roomFolder}) end
			end
			if rw > 0.1 then
				if isZ then mp({Name="WallRight",Size=Vector3.new(rw,height,thick),CFrame=CFrame.new(origin+w.pos+Vector3.new(dOff+dw/2+rw/2,0,0)),Material=wallMat,Color=wallColor,Parent=roomFolder})
				else mp({Name="WallRight",Size=Vector3.new(thick,height,rw),CFrame=CFrame.new(origin+w.pos+Vector3.new(0,0,dOff+dw/2+rw/2)),Material=wallMat,Color=wallColor,Parent=roomFolder}) end
			end
			-- Door part
			local dp
			if isZ then
				dp = mp({Name="Door",Size=Vector3.new(dw,dh,thick*0.5),CFrame=CFrame.new(origin+w.pos+Vector3.new(dOff,-(height-dh)/2,0)),Material=Enum.Material.Wood,Color=C.DoorFrame,Parent=roomFolder})
			else
				dp = mp({Name="Door",Size=Vector3.new(thick*0.5,dh,dw),CFrame=CFrame.new(origin+w.pos+Vector3.new(0,-(height-dh)/2,dOff)),Material=Enum.Material.Wood,Color=C.DoorFrame,Parent=roomFolder})
			end
			local pp = Instance.new("ProximityPrompt"); pp.ActionText="Open"; pp.ObjectText="Door"; pp.MaxActivationDistance=8; pp.HoldDuration=0.3; pp.Parent=dp
			local tg = Instance.new("StringValue"); tg.Name="DoorTag"; tg.Value=template.Name; tg.Parent=dp
		else
			mp({Name="Wall_"..w.side,Size=w.size,CFrame=CFrame.new(origin+w.pos),Material=wallMat,Color=wallColor,Parent=roomFolder})
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
			local pl = Instance.new("PointLight"); pl.Brightness=0.5*lightMult; pl.Range=16; pl.Color=Color3.fromRGB(180,160,100); pl.Parent=b
		elseif f.Type == "Pipe" then
			mp({Name="Pipe",Size=Vector3.new(0.5,0.5,ROOM_UNIT*2),CFrame=CFrame.new(pos)*CFrame.Angles(0,math.rad(f.Rotation),0),Material=Enum.Material.Metal,Color=C.Rust,Parent=roomFolder})
		elseif f.Type == "Window" then
			local g = mp({Name="Window",Size=Vector3.new(0.2,4,6),CFrame=CFrame.new(pos)*CFrame.Angles(0,math.rad(f.Rotation),0),Material=Enum.Material.Glass,Color=Color3.fromRGB(50,55,65),Parent=roomFolder})
			g.Transparency = 0.6
		end
	end

	-- Furniture
	for _, f in ipairs(template.Furniture) do
		local fPos = origin + f.Offset
		local builder = BUILDERS[f.Type]
		if builder then builder(fPos, f.Rotation, roomFolder) end
	end

	-- Hiding Spots
	for _, spot in ipairs(template.HidingSpots) do
		local spotPos = origin + spot.Off
		local hp = mp({Name="HidingSpot",Size=Vector3.new(2,3,2),CFrame=CFrame.new(spotPos+Vector3.new(0,1.5,0))*CFrame.Angles(0,math.rad(spot.Rot),0),Color=Color3.fromRGB(0,0,0),CanCollide=false,Parent=roomFolder})
		hp.Transparency = 1
		local ht = Instance.new("StringValue"); ht.Name="HideType"; ht.Value=spot.Type; ht.Parent=hp
		local fi = Instance.new("IntValue"); fi.Name="FloorIndex"; fi.Value=floorIdx; fi.Parent=hp
		local pp = Instance.new("ProximityPrompt"); pp.ActionText="Hide"; pp.ObjectText=spot.Type; pp.MaxActivationDistance=6; pp.HoldDuration=0.8; pp.Parent=hp
	end

	return roomFolder
end

-----------------------------------------------------------------------
-- STAIRWELL BUILDER
-----------------------------------------------------------------------
local function buildStairwell(origin, floorIdx, floorFolder)
	buildRoom(ROOMS.Stairwell, origin, floorFolder, floorIdx)
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
end

-----------------------------------------------------------------------
-- CONNECTOR BUILDER
-----------------------------------------------------------------------
local function buildConnector(posA, posB, floorFolder, floorIdx)
	local mid = (posA+posB)/2
	local diff = posB-posA; local len = diff.Magnitude
	local height = WALL_HEIGHT; local thick = WALL_THICKNESS; local hw = HALLWAY_WIDTH
	local theme = getTheme(floorIdx)
	local cf = CFrame.lookAt(mid, mid+diff.Unit)
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
	local baseY = -(floorIdx-1) * FLOOR_SEP
	local cellData = {}
	for row=1,GRID_SIZE do
		cellData[row] = {}
		for col=1,GRID_SIZE do
			local origin = Vector3.new((col-1)*(ROOM_UNIT*2)-(GRID_SIZE*ROOM_UNIT), baseY, (row-1)*(ROOM_UNIT*2)-(GRID_SIZE*ROOM_UNIT))
			local tName
			if row==math.ceil(GRID_SIZE/2) and col==math.ceil(GRID_SIZE/2) then tName="Elevator"
			elseif row==STAIRWELL_ROW and col==STAIRWELL_COL then tName="Stairwell"
			else tName=getWeightedRandom(rng) end
			local tmpl = ROOMS[tName]
			if tmpl then
				if tName=="Stairwell" then buildStairwell(origin, floorIdx, ff)
				else buildRoom(tmpl, origin, ff, floorIdx) end
				cellData[row][col] = {origin=origin, template=tmpl}
			end
		end
	end
	-- Connectors
	for row=1,GRID_SIZE do for col=1,GRID_SIZE do
		if cellData[row][col] then
			if col<GRID_SIZE and cellData[row][col+1] then
				local a=cellData[row][col].origin; local b=cellData[row][col+1].origin
				local mA=a+Vector3.new(ROOM_UNIT*cellData[row][col].template.SM.X/2,0,0)
				local mB=b-Vector3.new(ROOM_UNIT*cellData[row][col+1].template.SM.X/2,0,0)
				if (mB-mA).Magnitude>2 then buildConnector(mA,mB,ff,floorIdx) end
			end
			if row<GRID_SIZE and cellData[row+1] and cellData[row+1][col] then
				local a=cellData[row][col].origin; local b=cellData[row+1][col].origin
				local mA=a+Vector3.new(0,0,ROOM_UNIT*cellData[row][col].template.SM.Z/2)
				local mB=b-Vector3.new(0,0,ROOM_UNIT*cellData[row+1][col].template.SM.Z/2)
				if (mB-mA).Magnitude>2 then buildConnector(mA,mB,ff,floorIdx) end
			end
		end
	end end
	-- Spawn on floor 1 — inside the elevator room
	if floorIdx==1 then
		local eR,eC = math.ceil(GRID_SIZE/2), math.ceil(GRID_SIZE/2)
		if cellData[eR] and cellData[eR][eC] then
			local spawnOrigin = cellData[eR][eC].origin
			-- Delete any existing SpawnLocations in the workspace
			for _, obj in ipairs(workspace:GetDescendants()) do
				if obj:IsA("SpawnLocation") and obj.Name ~= "ElevatorSpawn" then
					obj:Destroy()
				end
			end
			local sp = Instance.new("SpawnLocation")
			sp.Anchored=true; sp.CanCollide=true; sp.Size=Vector3.new(4,1,4)
			sp.CFrame=CFrame.new(spawnOrigin + Vector3.new(0, 3, 0))
			sp.TopSurface=Enum.SurfaceType.Smooth; sp.Transparency=1; sp.Name="ElevatorSpawn"; sp.Parent=ff
			print("[Bootstrap] Spawn placed INSIDE elevator room at:", spawnOrigin + Vector3.new(0, 3, 0))
		end
	end
	return ff
end

-----------------------------------------------------------------------
-- MAIN — RUN THIS
-----------------------------------------------------------------------
-- Clear old map
local old = workspace:FindFirstChild("GeneratedMap")
if old then old:Destroy() end

local mapFolder = Instance.new("Folder")
mapFolder.Name = "GeneratedMap"
mapFolder.Parent = workspace

local rng = Random.new(SEED)
mapFolder:SetAttribute("Seed", SEED)

for floor = 1, FLOORS do
	generateFloor(floor, rng, mapFolder)
	print("[Bootstrap] Floor", floor, "built. Theme:", getTheme(floor).Name)
end

print("[Bootstrap] Done! " .. FLOORS .. " floors generated with seed " .. SEED .. ". Save the place to keep them.")
