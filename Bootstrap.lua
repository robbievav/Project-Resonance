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
local SEED            = 42
local FLOORS          = 3         -- floors to bake (increase as needed)
local GRID_SIZE       = 5
local ROOM_UNIT       = 24        -- every room is exactly 24x24 studs
local GRID_SPACING    = 32        -- center-to-center distance between rooms
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

local function getTheme(f)
	for _, t in ipairs(THEMES) do
		if f >= t.Range[1] and f <= t.Range[2] then return t end
	end
	return THEMES[1]
end

-- Room Weights (for random selection)
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
-- ROOM TEMPLATES
-- ALL rooms are 24x24x12 (1 ROOM_UNIT). Variety is in furniture/fixtures.
-- ALL rooms get doors on all 4 walls so connectors always line up.
-----------------------------------------------------------------------
local function fix(t, ox, oy, oz, rot) return { Type=t, Offset=Vector3.new(ox,oy,oz), Rotation=rot or 0 } end

local ALL_DOORS = {"NegZ","PosZ","NegX","PosX"}

local ROOMS = {}

ROOMS.Hallway = {
	Name="Hallway", FloorMat="SmoothPlastic", FloorCol=C.FloorTile,
	CeilCol=C.CeilingPanel,
	Fixtures={fix("Fluor",0,11.5,-6), fix("Fluor",0,11.5,6)},
	Furniture={}, HidingSpots={},
}

ROOMS.Office = {
	Name="Office", FloorMat="SmoothPlastic", FloorCol=C.FloorTile,
	CeilCol=C.CeilingPanel,
	Fixtures={fix("Fluor",0,11.5,0)},
	Furniture={fix("Desk",-7,0,-5,0), fix("Desk",5,0,-5,180),
		fix("FileCab",9,0,-9,0), fix("FileCab",9,0,9,0),
		fix("Chair",-5,0,-5,30), fix("Chair",3,0,-5,-30),
		fix("WaterCooler",9,0,0,0)},
	HidingSpots={{Type="UnderDesk",Off=Vector3.new(-7,0,-5),Rot=0},{Type="UnderDesk",Off=Vector3.new(5,0,-5),Rot=180}},
}

ROOMS.MaintenanceTunnel = {
	Name="MaintenanceTunnel", FloorMat="DiamondPlate", FloorCol=C.MetalGrate,
	CeilCol=C.DarkConcrete,
	Fixtures={fix("DimBulb",0,11,-5), fix("DimBulb",0,11,5), fix("Pipe",-3,11,0), fix("Pipe",3,11,0)},
	Furniture={fix("Barrel",7,0,-7), fix("ToolBox",-7,0,7)},
	HidingSpots={{Type="Locker",Off=Vector3.new(-8,0,0),Rot=0}},
}

ROOMS.ObservationDeck = {
	Name="ObservationDeck", FloorMat="Marble", FloorCol=C.FloorTile,
	CeilCol=C.CeilingPanel,
	Fixtures={fix("Fluor",0,11.5,0)},
	Furniture={fix("Console",-7,0,-5,0), fix("Console",-7,0,5,0),
		fix("Chair",-4,0,-5,0), fix("Chair",-4,0,5,0)},
	HidingSpots={},
}

ROOMS.SafeHub = {
	Name="SafeHub", FloorMat="Marble", FloorCol=C.FloorTile,
	CeilCol=C.CeilingPanel, IsSafe=true,
	Fixtures={fix("Fluor",-4,11.5,-4), fix("Fluor",4,11.5,4)},
	Furniture={fix("Desk",-7,0,-7,0), fix("Cot",7,0,6,0), fix("MedKit",-7,3,7,0), fix("Locker",-9,0,3,-90)},
	HidingSpots={{Type="Locker",Off=Vector3.new(-9,0,3),Rot=-90}},
}

ROOMS.StorageRoom = {
	Name="StorageRoom", FloorMat="SmoothPlastic", FloorCol=C.DarkConcrete,
	CeilCol=C.DarkConcrete,
	Fixtures={fix("DimBulb",0,11,0)},
	Furniture={fix("ShelfUnit",-9,0,-7,0), fix("ShelfUnit",-9,0,3,0), fix("ShelfUnit",9,0,-7,180),
		fix("Crate",3,0,-7,15), fix("Crate",6,0,-5,-10), fix("Barrel",-4,0,8,0), fix("Locker",9,0,7,180)},
	HidingSpots={{Type="Locker",Off=Vector3.new(9,0,7),Rot=180},{Type="ShelfCrawl",Off=Vector3.new(-9,0,0),Rot=0}},
}

ROOMS.Laboratory = {
	Name="Laboratory", FloorMat="Marble", FloorCol=C.LabWhite,
	CeilCol=C.CeilingPanel,
	Fixtures={fix("Fluor",-4,11.5,0), fix("Fluor",4,11.5,0)},
	Furniture={fix("LabBench",-8,0,-6,0), fix("LabBench",-8,0,5,0), fix("LabBench",5,0,-6,180),
		fix("FileCab",9,0,-9,0), fix("Chair",-5,0,-6,30), fix("Chair",3,0,-6,-30)},
	HidingSpots={{Type="UnderDesk",Off=Vector3.new(-8,0,5),Rot=0}},
}

ROOMS.Bathroom = {
	Name="Bathroom", FloorMat="Marble", FloorCol=C.TileWhite,
	CeilCol=C.CeilingPanel,
	Fixtures={fix("Fluor",0,11.5,0), fix("Pipe",-5,11,0)},
	Furniture={fix("BathroomStall",-7,0,-5,0), fix("BathroomStall",-7,0,5,0), fix("BathroomStall",0,0,-5,0), fix("BathroomSink",8,0,0,90)},
	HidingSpots={{Type="StallHide",Off=Vector3.new(-7,0,5),Rot=0},{Type="StallHide",Off=Vector3.new(0,0,-5),Rot=0}},
}

ROOMS.ServerRoom = {
	Name="ServerRoom", FloorMat="DiamondPlate", FloorCol=C.MetalGrate,
	CeilCol=C.DarkConcrete,
	Fixtures={fix("DimBulb",0,11,0), fix("Pipe",-6,11,4), fix("Pipe",6,11,4)},
	Furniture={fix("ServerRack",-9,0,-7,0), fix("ServerRack",-9,0,0,0), fix("ServerRack",-9,0,7,0),
		fix("ServerRack",9,0,-7,180), fix("ServerRack",9,0,0,180), fix("ServerRack",9,0,7,180), fix("Console",0,0,9,0)},
	HidingSpots={{Type="RackGap",Off=Vector3.new(-9,0,3.5),Rot=0},{Type="RackGap",Off=Vector3.new(9,0,3.5),Rot=180}},
}

ROOMS.Elevator = {
	Name="Elevator", FloorMat="DiamondPlate", FloorCol=C.MetalGrate,
	CeilCol=C.DarkConcrete, IsSafe=true,
	Fixtures={fix("DimBulb",0,11,0)},
	Furniture={fix("ElevatorPanel",-11.85,3,5,0)},
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

-- Map internal type names → model names inside ReplicatedStorage.Furniture
local FURNITURE_MAP = {
	Desk         = "work station",
	Chair        = "Chair - pemble08",
	FileCab      = "cabinet 1",
	WaterCooler  = "Refridgerator",
	Barrel       = "cabinet 3",
	ToolBox      = "small safe",
	Console      = "work station",
	Cot          = "couch",
	MedKit       = "small safe",
	Locker       = "cabinet 2",
	ShelfUnit    = "shelf1",
	Crate        = "cabinet 4",
	LabBench     = "dinner table",
	BathroomSink = "bathroom sink",
	ServerRack   = "cabinet 4",
	BathroomStall = "cabinet 3",  -- closest tall piece
}

local function cloneFurniture(typeName, pos, rot, parent)
	-- Special case: ElevatorPanel is game-specific (neon button)
	if typeName == "ElevatorPanel" then
		local r = CFrame.Angles(0, math.rad(rot), 0)
		mp({Name="ElevatorPanel",Size=Vector3.new(0.3,1.5,1),CFrame=CFrame.new(pos)*r,Material=Enum.Material.Metal,Color=Color3.fromRGB(70,70,75),Parent=parent})
		mp({Name="ElevatorButton",Size=Vector3.new(0.35,0.3,0.3),CFrame=CFrame.new(pos+Vector3.new(-0.05,0.3,0))*r,Material=Enum.Material.Neon,Color=Color3.fromRGB(200,60,40),Parent=parent})
		return
	end

	local modelName = FURNITURE_MAP[typeName]
	if not modelName or not FurnitureFolder then return end

	local template = FurnitureFolder:FindFirstChild(modelName)
	if not template then
		warn("[Bootstrap] Furniture model not found:", modelName, "for type", typeName)
		return
	end

	local clone = template:Clone()
	clone.Name = typeName

	-- Position and rotate the model
	if clone:IsA("Model") then
		if clone.PrimaryPart then
			clone:SetPrimaryPartCFrame(CFrame.new(pos) * CFrame.Angles(0, math.rad(rot), 0))
		else
			-- If no PrimaryPart, set one
			local firstPart = clone:FindFirstChildWhichIsA("BasePart", true)
			if firstPart then
				clone.PrimaryPart = firstPart
				clone:SetPrimaryPartCFrame(CFrame.new(pos) * CFrame.Angles(0, math.rad(rot), 0))
			end
		end
	elseif clone:IsA("BasePart") then
		clone.CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(rot), 0)
	end

	-- Anchor all parts so they don't fall
	for _, part in ipairs(clone:GetDescendants()) do
		if part:IsA("BasePart") then
			part.Anchored = true
		end
	end

	clone.Parent = parent
end

-----------------------------------------------------------------------
-- ROOM BUILDER
-- Every room is exactly ROOM_UNIT x ROOM_UNIT (24x24x12).
-- Doors on all 4 walls, centered.
-----------------------------------------------------------------------
local function buildRoom(template, origin, floorFolder, floorIdx)
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
		{side="PosX", isZ=false, size=Vector3.new(thick,height,sz), pos=Vector3.new(sx/2,height/2,0)},
		{side="NegX", isZ=false, size=Vector3.new(thick,height,sz), pos=Vector3.new(-sx/2,height/2,0)},
		{side="PosZ", isZ=true,  size=Vector3.new(sx,height,thick), pos=Vector3.new(0,height/2,sz/2)},
		{side="NegZ", isZ=true,  size=Vector3.new(sx,height,thick), pos=Vector3.new(0,height/2,-sz/2)},
	}

	for _, w in ipairs(walls) do
		local aboveH = height - dh
		-- Wall above the door
		if aboveH > 0 then
			if w.isZ then
				mp({Name="WallAbove",Size=Vector3.new(dw,aboveH,thick),CFrame=CFrame.new(origin+w.pos+Vector3.new(0,(height-aboveH)/2,0)),Material=wallMat,Color=wallColor,Parent=roomFolder})
			else
				mp({Name="WallAbove",Size=Vector3.new(thick,aboveH,dw),CFrame=CFrame.new(origin+w.pos+Vector3.new(0,(height-aboveH)/2,0)),Material=wallMat,Color=wallColor,Parent=roomFolder})
			end
		end
		-- Wall left of door
		local sideLen = w.isZ and sx or sz
		local lw = sideLen/2 + dOff - dw/2
		local rw = sideLen/2 - dOff - dw/2
		if lw > 0.1 then
			if w.isZ then
				mp({Name="WallLeft",Size=Vector3.new(lw,height,thick),CFrame=CFrame.new(origin+w.pos+Vector3.new(-dw/2-lw/2,0,0)),Material=wallMat,Color=wallColor,Parent=roomFolder})
			else
				mp({Name="WallLeft",Size=Vector3.new(thick,height,lw),CFrame=CFrame.new(origin+w.pos+Vector3.new(0,0,-dw/2-lw/2)),Material=wallMat,Color=wallColor,Parent=roomFolder})
			end
		end
		if rw > 0.1 then
			if w.isZ then
				mp({Name="WallRight",Size=Vector3.new(rw,height,thick),CFrame=CFrame.new(origin+w.pos+Vector3.new(dw/2+rw/2,0,0)),Material=wallMat,Color=wallColor,Parent=roomFolder})
			else
				mp({Name="WallRight",Size=Vector3.new(thick,height,rw),CFrame=CFrame.new(origin+w.pos+Vector3.new(0,0,dw/2+rw/2)),Material=wallMat,Color=wallColor,Parent=roomFolder})
			end
		end
		-- Door part
		local dp
		if w.isZ then
			dp = mp({Name="Door",Size=Vector3.new(dw,dh,thick*0.5),CFrame=CFrame.new(origin+w.pos+Vector3.new(0,-(height-dh)/2,0)),Material=Enum.Material.Wood,Color=C.DoorFrame,Parent=roomFolder})
		else
			dp = mp({Name="Door",Size=Vector3.new(thick*0.5,dh,dw),CFrame=CFrame.new(origin+w.pos+Vector3.new(0,-(height-dh)/2,0)),Material=Enum.Material.Wood,Color=C.DoorFrame,Parent=roomFolder})
		end
		local pp = Instance.new("ProximityPrompt"); pp.ActionText="Open"; pp.ObjectText="Door"; pp.MaxActivationDistance=8; pp.HoldDuration=0.3; pp.Parent=dp
		local tg = Instance.new("StringValue"); tg.Name="DoorTag"; tg.Value=template.Name; tg.Parent=dp
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
				if tName == "Stairwell" then
					buildStairwell(origin, floorIdx, ff)
				else
					buildRoom(tmpl, origin, ff, floorIdx)
				end
				cellData[row][col] = { origin = origin }
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

local rng = Random.new(SEED)
mapFolder:SetAttribute("Seed", SEED)

for floor = 1, FLOORS do
	generateFloor(floor, rng, mapFolder)
	print("[Bootstrap] Floor", floor, "built. Theme:", getTheme(floor).Name)
end

print("[Bootstrap] Done! "..FLOORS.." floors with seed "..SEED..". All rooms are 24x24, doors on all 4 walls. SAVE the place!")
