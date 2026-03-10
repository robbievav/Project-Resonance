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
local FLOORS          = 3         -- floors to bake (increase as needed)
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

-- Room Weights (for random selection) — only the 6 unique rooms
local ROOM_WEIGHTS = {
	MedBay=15, BreakRoom=15, ArchiveRoom=15, SecurityStation=12,
	MechanicalRoom=15, Dormitory=15,
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
	Fixtures={fix("Fluor",-8,11.5,0), fix("Fluor",8,11.5,0)},
	Furniture={
		-- Hospital beds spaced apart, facing inward
		fix("HospitalBed",-7.5,0,10,90), fix("HospitalBed",-15.5,0,-12.2,-90),
		-- Medical supplies grouped on the right side
		fix("MedCabinet",5,0,-5,0),
		fix("Desk",3.5,0,1.5,90),
	},
	HidingSpots={
		-- Under bed 1 (at -7.5, 0, 10)
		{Type="UnderBed",Off=Vector3.new(-7.5,0,10),Rot=90},
		-- Under bed 2 (at -15.5, 0, -12.2)
		{Type="UnderBed",Off=Vector3.new(-15.5,0,-12.2),Rot=-90},
	},
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
	HidingSpots={
		-- Under the break table (table is at 0,0,0 — offset slightly so key won't spawn there)
		{Type="UnderTable",Off=Vector3.new(0,0,1.5),Rot=0},
	},
}

-----------------------------------------------------------------------
-- ROOM 3: ArchiveRoom — Records storage with filing cabinet rows
-----------------------------------------------------------------------
ROOMS.ArchiveRoom = {
	Name="ArchiveRoom", FloorMat="SmoothPlastic", FloorCol=C.DarkConcrete,
	CeilCol=C.DarkConcrete,
	Fixtures={fix("DimBulb",-8,11,0), fix("DimBulb",8,11,0), fix("DimBulb",0,11,-8)},
	Furniture={
		-- Row of filing cabinets along back wall
		fix("FileCab",-5,0,-5,0), fix("FileCab",-2,0,-5,0),
		fix("FileCab",2,0,-5,0), fix("FileCab",5,0,-5,0),
		-- Reading desk in front-left corner
		fix("Desk",-4,0,5,0),
		-- Crate in front-right corner
		fix("Crate",4,0,5,0),
	},
	HidingSpots={
		-- Between the two left filing cabinet pairs (at Z=-5)
		{Type="CabinetRow",Off=Vector3.new(-3.5,0,-5),Rot=0},
	},
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
	HidingSpots={
		{Type="Locker",Off=Vector3.new(5,0,5),Rot=180},
	},
}

-----------------------------------------------------------------------
-- ROOM 5: MechanicalRoom — Boiler/HVAC with pipes and generators
-----------------------------------------------------------------------
ROOMS.MechanicalRoom = {
	Name="MechanicalRoom", FloorMat="DiamondPlate", FloorCol=C.MetalGrate,
	CeilCol=C.DarkConcrete,
	Fixtures={fix("DimBulb",0,11,0), fix("DimBulb",-8,11,0), fix("Pipe",-4,11,0), fix("Pipe",4,11,0), fix("Pipe",0,11,-8), fix("Pipe",0,11,8)},
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
	HidingSpots={
		-- Behind the generator (generator is at -4, 0, -4)
		{Type="BehindGenerator",Off=Vector3.new(-4,0,-2),Rot=0},
	},
}

-----------------------------------------------------------------------
-- ROOM 6: Dormitory — Staff sleeping quarters with bunk beds
-----------------------------------------------------------------------
ROOMS.Dormitory = {
	Name="Dormitory", FloorMat="SmoothPlastic", FloorCol=C.FloorTile,
	CeilCol=C.CeilingPanel,
	Fixtures={fix("DimBulb",-8,11,-8), fix("DimBulb",8,11,8)},
	Furniture={
		-- Cots spaced around the room
		fix("Cot",13.9,0,6,90), fix("Cot",-6.5,0,6.5,90),
		fix("Cot",-14.4,0,-7.6,-90), fix("Cot",7,0,-9.5,-90),
		-- Footlockers at the foot of each bed row
		fix("Footlocker",-2,0,-4,0), fix("Footlocker",-2,0,4,0),
	},
	HidingSpots={
		-- Under cot 2 (at -6.5, 0, 6.5)
		{Type="UnderBed",Off=Vector3.new(-6.5,0,6.5),Rot=90},
		-- Under cot 3 (at -14.4, 0, -7.6)
		{Type="UnderBed",Off=Vector3.new(-14.4,0,-7.6),Rot=-90},
	},
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
		clone:SetPrimaryPartCFrame(CFrame.new(finalPos) * CFrame.Angles(0, math.rad(finalRot), 0))
	elseif clone:IsA("Model") then
		local cf, size = clone:GetBoundingBox()
		finalPos = Vector3.new(pos.X, pos.Y + size.Y / 2, pos.Z)
		clone:SetPrimaryPartCFrame(CFrame.new(finalPos) * CFrame.Angles(0, math.rad(finalRot), 0))
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
			elseif row == STAIRWELL_ROW and col == STAIRWELL_COL then
				tName = "Stairwell"
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
				if cell.name == "Stairwell" then
					buildStairwell(cell.origin, floorIdx, ff, connections)
				else
					buildRoom(cell.template, cell.origin, ff, floorIdx, connections)
				end
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

	-- Spawn on floor 1 — on the ground inside the elevator room
	if floorIdx == 1 then
		local eR = math.ceil(GRID_SIZE / 2)
		local eC = math.ceil(GRID_SIZE / 2)
		if cellData[eR] and cellData[eR][eC] then
			-- Delete any existing SpawnLocations
			for _, obj in ipairs(workspace:GetDescendants()) do
				if obj:IsA("SpawnLocation") then obj:Destroy() end
			end
			local spawnOrigin = cellData[eR][eC].origin
			local sp = Instance.new("SpawnLocation")
			sp.Anchored = true
			sp.CanCollide = true
			sp.Size = Vector3.new(4, 1, 4)
			sp.CFrame = CFrame.new(spawnOrigin + Vector3.new(0, 0.5, 0))
			sp.TopSurface = Enum.SurfaceType.Smooth
			sp.Transparency = 1
			sp.Name = "ElevatorSpawn"
			sp.Parent = ff
			print("[Bootstrap] Spawn at:", spawnOrigin + Vector3.new(0, 0.5, 0))
		end
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

print("[Bootstrap] Done! "..FLOORS.." floors with seed "..SEED..". All rooms are 24x24, doors on all 4 walls. SAVE the place!")
