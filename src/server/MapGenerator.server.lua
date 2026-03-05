--[[
	MapGenerator.server.lua
	Seed-based procedural floor generator for Project: Resonance.
	Builds rooms from Part primitives, places doors, lights, and furniture.
]]

local ServerStorage    = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting          = game:GetService("Lighting")

local Config        = require(ReplicatedStorage.Shared.Config)
local RoomTemplates = require(ReplicatedStorage.Shared.RoomTemplates)

local MC = Config.Map
local CC = Config.Colors

---------------------------------------------------------------------------
-- CONTAINERS
---------------------------------------------------------------------------
local mapFolder = Instance.new("Folder")
mapFolder.Name = "GeneratedMap"
mapFolder.Parent = workspace

---------------------------------------------------------------------------
-- UTILITY HELPERS
---------------------------------------------------------------------------
local function getMaterial(name)
	return Enum.Material[name] or Enum.Material.SmoothPlastic
end

local function makePart(props)
	local p = Instance.new("Part")
	p.Anchored   = true
	p.CanCollide = props.CanCollide ~= false
	p.Size        = props.Size or Vector3.new(1,1,1)
	p.CFrame      = props.CFrame or CFrame.new()
	p.Material     = props.Material or Enum.Material.SmoothPlastic
	p.Color        = props.Color or Color3.fromRGB(180,180,180)
	p.TopSurface   = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Name         = props.Name or "Part"
	p.Parent       = props.Parent
	return p
end

---------------------------------------------------------------------------
-- ROOM BUILDER
---------------------------------------------------------------------------
local function buildRoom(template, origin, floorFolder)
	local unit = MC.RoomUnit
	local sx = unit * template.SizeMultiplier.X
	local sz = unit * template.SizeMultiplier.Z
	local height = MC.WallHeight * template.SizeMultiplier.Y
	local thick = MC.WallThickness

	local roomFolder = Instance.new("Folder")
	roomFolder.Name = template.Name
	roomFolder.Parent = floorFolder

	-- FLOOR
	makePart({
		Name     = "Floor",
		Size     = Vector3.new(sx, thick, sz),
		CFrame   = CFrame.new(origin + Vector3.new(0, -thick/2, 0)),
		Material = getMaterial(template.FloorMaterial),
		Color    = template.FloorColor,
		Parent   = roomFolder,
	})

	-- CEILING
	makePart({
		Name     = "Ceiling",
		Size     = Vector3.new(sx, thick, sz),
		CFrame   = CFrame.new(origin + Vector3.new(0, height + thick/2, 0)),
		Material = getMaterial(Config.Materials.Ceiling),
		Color    = template.CeilingColor,
		Parent   = roomFolder,
	})

	-- WALLS — four sides with door cutouts
	local doorSet = {}
	for _, d in ipairs(template.Doors) do
		doorSet[d.Wall] = d
	end

	local walls = {
		{ side = "PosX",  normal = Vector3.new(1,0,0),  size = Vector3.new(thick, height, sz) , pos = Vector3.new(sx/2, height/2, 0) },
		{ side = "NegX",  normal = Vector3.new(-1,0,0), size = Vector3.new(thick, height, sz) , pos = Vector3.new(-sx/2, height/2, 0) },
		{ side = "PosZ",  normal = Vector3.new(0,0,1),  size = Vector3.new(sx, height, thick) , pos = Vector3.new(0, height/2, sz/2) },
		{ side = "NegZ",  normal = Vector3.new(0,0,-1), size = Vector3.new(sx, height, thick) , pos = Vector3.new(0, height/2, -sz/2) },
	}

	for _, w in ipairs(walls) do
		if doorSet[w.side] then
			-- Split the wall around a door opening
			local dw = MC.DoorWidth
			local dh = MC.DoorHeight
			local dOff = doorSet[w.side].Offset  -- lateral offset

			-- Above door
			local aboveH = height - dh
			if aboveH > 0 then
				local aboveSize, aboveCF
				if w.side == "PosZ" or w.side == "NegZ" then
					aboveSize = Vector3.new(dw, aboveH, thick)
					aboveCF   = CFrame.new(origin + w.pos + Vector3.new(dOff, (height - aboveH)/2, 0))
				else
					aboveSize = Vector3.new(thick, aboveH, dw)
					aboveCF   = CFrame.new(origin + w.pos + Vector3.new(0, (height - aboveH)/2, dOff))
				end
				makePart({ Name="WallAboveDoor", Size=aboveSize, CFrame=aboveCF, Material=getMaterial(template.WallMaterial), Color=template.WallColor, Parent=roomFolder })
			end

			-- Left of door
			local leftWidth, rightWidth
			if w.side == "PosZ" or w.side == "NegZ" then
				leftWidth  = sx/2 + dOff - dw/2
				rightWidth = sx/2 - dOff - dw/2
			else
				leftWidth  = sz/2 + dOff - dw/2
				rightWidth = sz/2 - dOff - dw/2
			end

			if leftWidth > 0.1 then
				local lSize, lCF
				if w.side == "PosZ" or w.side == "NegZ" then
					lSize = Vector3.new(leftWidth, height, thick)
					lCF   = CFrame.new(origin + w.pos + Vector3.new(dOff - dw/2 - leftWidth/2, 0, 0))
				else
					lSize = Vector3.new(thick, height, leftWidth)
					lCF   = CFrame.new(origin + w.pos + Vector3.new(0, 0, dOff - dw/2 - leftWidth/2))
				end
				makePart({ Name="WallLeft", Size=lSize, CFrame=lCF, Material=getMaterial(template.WallMaterial), Color=template.WallColor, Parent=roomFolder })
			end

			if rightWidth > 0.1 then
				local rSize, rCF
				if w.side == "PosZ" or w.side == "NegZ" then
					rSize = Vector3.new(rightWidth, height, thick)
					rCF   = CFrame.new(origin + w.pos + Vector3.new(dOff + dw/2 + rightWidth/2, 0, 0))
				else
					rSize = Vector3.new(thick, height, rightWidth)
					rCF   = CFrame.new(origin + w.pos + Vector3.new(0, 0, dOff + dw/2 + rightWidth/2))
				end
				makePart({ Name="WallRight", Size=rSize, CFrame=rCF, Material=getMaterial(template.WallMaterial), Color=template.WallColor, Parent=roomFolder })
			end

			-- Create door part (interactable)
			local doorPart
			if w.side == "PosZ" or w.side == "NegZ" then
				doorPart = makePart({
					Name = "Door",
					Size = Vector3.new(dw, dh, thick * 0.5),
					CFrame = CFrame.new(origin + w.pos + Vector3.new(dOff, -(height - dh)/2, 0)),
					Material = Enum.Material.Wood,
					Color = Config.Colors.DoorFrame,
					Parent = roomFolder,
				})
			else
				doorPart = makePart({
					Name = "Door",
					Size = Vector3.new(thick * 0.5, dh, dw),
					CFrame = CFrame.new(origin + w.pos + Vector3.new(0, -(height - dh)/2, dOff)),
					Material = Enum.Material.Wood,
					Color = Config.Colors.DoorFrame,
					Parent = roomFolder,
				})
			end

			-- Add a proximity prompt to the door
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Open"
			prompt.ObjectText = "Door"
			prompt.MaxActivationDistance = 8
			prompt.HoldDuration = 0.3
			prompt.Parent = doorPart

			-- Tag door for the DoorSystem
			local tag = Instance.new("StringValue")
			tag.Name = "DoorTag"
			tag.Value = template.Name
			tag.Parent = doorPart
		else
			-- Solid wall, no door
			makePart({
				Name   = "Wall_" .. w.side,
				Size   = w.size,
				CFrame = CFrame.new(origin + w.pos),
				Material = getMaterial(template.WallMaterial),
				Color    = template.WallColor,
				Parent   = roomFolder,
			})
		end
	end

	-- FIXTURES (lights, pipes, windows)
	for _, fix in ipairs(template.Fixtures) do
		local pos = origin + fix.Offset

		if fix.Type == "FluorescentLight" then
			local housing = makePart({
				Name = "FluorescentHousing",
				Size = Vector3.new(4, 0.3, 1),
				CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(fix.Rotation), 0),
				Material = Enum.Material.SmoothPlastic,
				Color = Color3.fromRGB(220, 220, 215),
				Parent = roomFolder,
			})

			local light = Instance.new("SurfaceLight")
			light.Face = Enum.NormalId.Bottom
			light.Brightness = Config.Lighting.FluorescentBrightness
			light.Range = Config.Lighting.FluorescentRange
			light.Color = Config.Colors.FluorLight
			light.Angle = 120
			light.Parent = housing

			-- Tag some lights for flickering
			local rngFlicker = math.random()
			if rngFlicker < Config.Lighting.FlickerChance then
				local flickerTag = Instance.new("BoolValue")
				flickerTag.Name = "Flicker"
				flickerTag.Value = true
				flickerTag.Parent = housing
			end

		elseif fix.Type == "DimBulb" then
			local bulb = makePart({
				Name = "DimBulb",
				Size = Vector3.new(0.6, 0.6, 0.6),
				CFrame = CFrame.new(pos),
				Material = Enum.Material.Neon,
				Color = Color3.fromRGB(180, 160, 100),
				Parent = roomFolder,
			})
			local pl = Instance.new("PointLight")
			pl.Brightness = 0.5
			pl.Range = 16
			pl.Color = Color3.fromRGB(180, 160, 100)
			pl.Parent = bulb

		elseif fix.Type == "Pipe" then
			makePart({
				Name = "Pipe",
				Size = Vector3.new(0.5, 0.5, MC.RoomUnit * 2),
				CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(fix.Rotation), 0),
				Material = getMaterial(Config.Materials.Pipes),
				Color = Config.Colors.Rust,
				Parent = roomFolder,
			})

		elseif fix.Type == "WindowPanel" then
			local glass = makePart({
				Name = "Window",
				Size = Vector3.new(0.2, 4, 6),
				CFrame = CFrame.new(pos) * CFrame.Angles(0, math.rad(fix.Rotation), 0),
				Material = Enum.Material.Glass,
				Color = Color3.fromRGB(50, 55, 65),
				Parent = roomFolder,
			})
			glass.Transparency = 0.6
		end
	end

	-- FURNITURE
	for _, furn in ipairs(template.Furniture) do
		local fPos = origin + furn.Offset
		local fRot = CFrame.Angles(0, math.rad(furn.Rotation), 0)

		if furn.Type == "Desk" then
			-- Desktop surface
			makePart({ Name="DeskTop", Size=Vector3.new(5, 0.3, 2.5), CFrame=CFrame.new(fPos + Vector3.new(0, 2.5, 0)) * fRot, Material=Enum.Material.Wood, Color=Color3.fromRGB(130,100,70), Parent=roomFolder })
			-- Legs
			for _, lx in ipairs({-2.2, 2.2}) do
				for _, lz in ipairs({-1, 1}) do
					makePart({ Name="DeskLeg", Size=Vector3.new(0.3, 2.5, 0.3), CFrame=CFrame.new(fPos + Vector3.new(lx, 1.25, lz)) * fRot, Material=Enum.Material.Metal, Color=Color3.fromRGB(90,90,90), Parent=roomFolder })
				end
			end

		elseif furn.Type == "Chair" then
			-- Seat
			makePart({ Name="ChairSeat", Size=Vector3.new(2, 0.3, 2), CFrame=CFrame.new(fPos + Vector3.new(0,1.8,0)) * fRot, Material=Enum.Material.Fabric, Color=Color3.fromRGB(60,65,75), Parent=roomFolder })
			-- Back
			makePart({ Name="ChairBack", Size=Vector3.new(2, 2, 0.3), CFrame=CFrame.new(fPos + Vector3.new(0,2.8,-1)) * fRot, Material=Enum.Material.Fabric, Color=Color3.fromRGB(60,65,75), Parent=roomFolder })

		elseif furn.Type == "FilingCabinet" then
			makePart({ Name="FilingCabinet", Size=Vector3.new(2, 4, 1.5), CFrame=CFrame.new(fPos + Vector3.new(0,2,0)) * fRot, Material=Enum.Material.Metal, Color=Color3.fromRGB(110,110,105), Parent=roomFolder })

		elseif furn.Type == "WaterCooler" then
			makePart({ Name="WaterCoolerBody", Size=Vector3.new(1.2, 3.5, 1.2), CFrame=CFrame.new(fPos + Vector3.new(0,1.75,0)) * fRot, Material=Enum.Material.SmoothPlastic, Color=Color3.fromRGB(200,200,195), Parent=roomFolder })
			local jug = makePart({ Name="WaterJug", Size=Vector3.new(0.8, 1.2, 0.8), CFrame=CFrame.new(fPos + Vector3.new(0,4.1,0)) * fRot, Material=Enum.Material.Glass, Color=Color3.fromRGB(140,180,210), Parent=roomFolder })
			jug.Transparency = 0.4

		elseif furn.Type == "Barrel" then
			makePart({ Name="Barrel", Size=Vector3.new(2, 3, 2), CFrame=CFrame.new(fPos + Vector3.new(0,1.5,0)) * fRot, Material=Enum.Material.Metal, Color=Config.Colors.Rust, Parent=roomFolder })

		elseif furn.Type == "ToolBox" then
			makePart({ Name="ToolBox", Size=Vector3.new(2, 1, 1), CFrame=CFrame.new(fPos + Vector3.new(0,0.5,0)) * fRot, Material=Enum.Material.Metal, Color=Color3.fromRGB(180,50,40), Parent=roomFolder })

		elseif furn.Type == "Console" then
			-- Base
			makePart({ Name="ConsoleDeck", Size=Vector3.new(4, 2.5, 2), CFrame=CFrame.new(fPos + Vector3.new(0,1.25,0)) * fRot, Material=Enum.Material.Metal, Color=Color3.fromRGB(70,70,75), Parent=roomFolder })
			-- Screen
			local screen = makePart({ Name="ConsoleScreen", Size=Vector3.new(3, 2, 0.2), CFrame=CFrame.new(fPos + Vector3.new(0,3.5,-0.8)) * fRot * CFrame.Angles(math.rad(-15),0,0), Material=Enum.Material.Neon, Color=Color3.fromRGB(30,80,50), Parent=roomFolder })
			screen.Transparency = 0.2

		elseif furn.Type == "MonitorBank" then
			for i = 0, 2 do
				local screen = makePart({ Name="Monitor", Size=Vector3.new(0.2, 2, 2.5), CFrame=CFrame.new(fPos + Vector3.new(0, i * 2.2, 0)) * fRot, Material=Enum.Material.Neon, Color=Color3.fromRGB(20,30,20), Parent=roomFolder })
				screen.Transparency = 0.3
			end

		elseif furn.Type == "Cot" then
			makePart({ Name="CotFrame", Size=Vector3.new(3, 0.8, 6), CFrame=CFrame.new(fPos + Vector3.new(0,0.4,0)) * fRot, Material=Enum.Material.Metal, Color=Color3.fromRGB(90,90,90), Parent=roomFolder })
			makePart({ Name="CotMattress", Size=Vector3.new(2.6, 0.4, 5.6), CFrame=CFrame.new(fPos + Vector3.new(0,1,0)) * fRot, Material=Enum.Material.Fabric, Color=Color3.fromRGB(120,130,120), Parent=roomFolder })

		elseif furn.Type == "MedKit" then
			local kit = makePart({ Name="MedKit", Size=Vector3.new(1.5, 1, 0.5), CFrame=CFrame.new(fPos) * fRot, Material=Enum.Material.SmoothPlastic, Color=Color3.fromRGB(200,200,200), Parent=roomFolder })
			-- Interactable
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Take"
			prompt.ObjectText = "Med Kit"
			prompt.MaxActivationDistance = 6
			prompt.Parent = kit

		elseif furn.Type == "Locker" then
			makePart({ Name="Locker", Size=Vector3.new(1.5, 6, 2), CFrame=CFrame.new(fPos + Vector3.new(0,3,0)) * fRot, Material=Enum.Material.Metal, Color=Color3.fromRGB(95,100,95), Parent=roomFolder })

		elseif furn.Type == "ElevatorPanel" then
			local panel = makePart({ Name="ElevatorPanel", Size=Vector3.new(0.3, 1.5, 1), CFrame=CFrame.new(fPos) * fRot, Material=Enum.Material.Metal, Color=Color3.fromRGB(70,70,75), Parent=roomFolder })
			-- Button indicator neon
			local btn = makePart({ Name="ElevatorButton", Size=Vector3.new(0.35, 0.3, 0.3), CFrame=CFrame.new(fPos + Vector3.new(-0.05, 0.3, 0)) * fRot, Material=Enum.Material.Neon, Color=Color3.fromRGB(200, 60, 40), Parent=roomFolder })
		end
	end

	return roomFolder
end

---------------------------------------------------------------------------
-- HALLWAY CONNECTOR between two room grid cells
---------------------------------------------------------------------------
local function buildConnector(posA, posB, floorFolder)
	local mid = (posA + posB) / 2
	local diff = posB - posA
	local length = diff.Magnitude
	local dir = diff.Unit
	local height = MC.WallHeight
	local thick = MC.WallThickness
	local hw = MC.HallwayWidth

	local cf = CFrame.lookAt(mid, mid + dir) * CFrame.new(0, 0, 0)

	-- Floor
	makePart({
		Name = "ConnectorFloor",
		Size = Vector3.new(hw, thick, length),
		CFrame = cf * CFrame.new(0, -thick/2, 0),
		Material = getMaterial(Config.Materials.Floor),
		Color = Config.Colors.FloorTile,
		Parent = floorFolder,
	})

	-- Ceiling
	makePart({
		Name = "ConnectorCeiling",
		Size = Vector3.new(hw, thick, length),
		CFrame = cf * CFrame.new(0, height + thick/2, 0),
		Material = getMaterial(Config.Materials.Ceiling),
		Color = Config.Colors.CeilingPanel,
		Parent = floorFolder,
	})

	-- Left wall
	makePart({
		Name = "ConnectorWallL",
		Size = Vector3.new(thick, height, length),
		CFrame = cf * CFrame.new(-hw/2, height/2, 0),
		Material = getMaterial(Config.Materials.Wall),
		Color = Config.Colors.WallPaint,
		Parent = floorFolder,
	})

	-- Right wall
	makePart({
		Name = "ConnectorWallR",
		Size = Vector3.new(thick, height, length),
		CFrame = cf * CFrame.new(hw/2, height/2, 0),
		Material = getMaterial(Config.Materials.Wall),
		Color = Config.Colors.WallPaint,
		Parent = floorFolder,
	})

	-- Single dim light in connector
	local bulb = makePart({
		Name = "ConnectorLight",
		Size = Vector3.new(0.4, 0.4, 0.4),
		CFrame = cf * CFrame.new(0, height - 0.5, 0),
		Material = Enum.Material.Neon,
		Color = Config.Colors.FluorLight,
		Parent = floorFolder,
	})
	local pl = Instance.new("PointLight")
	pl.Brightness = 0.4
	pl.Range = 14
	pl.Color = Config.Colors.FluorLight
	pl.Parent = bulb
end

---------------------------------------------------------------------------
-- FLOOR GENERATOR
---------------------------------------------------------------------------
local function generateFloor(floorIndex, rng)
	local floorFolder = Instance.new("Folder")
	floorFolder.Name = "Floor_" .. floorIndex
	floorFolder.Parent = mapFolder

	local baseY = -(floorIndex - 1) * MC.FloorSeparation
	local grid  = MC.RoomGridSize
	local unit  = MC.RoomUnit

	-- Track which grid cells have rooms and their origin positions
	local cellData = {}  -- [row][col] = { origin, template }

	for row = 1, grid do
		cellData[row] = {}
		for col = 1, grid do
			local origin = Vector3.new(
				(col - 1) * (unit * 2) - (grid * unit),
				baseY,
				(row - 1) * (unit * 2) - (grid * unit)
			)

			local templateName
			-- Place the elevator at grid center on every floor
			if row == math.ceil(grid/2) and col == math.ceil(grid/2) then
				templateName = "Elevator"
			else
				templateName = RoomTemplates.GetRandomType(rng)
			end

			local template = RoomTemplates[templateName]
			if template then
				buildRoom(template, origin, floorFolder)
				cellData[row][col] = { origin = origin, template = template }
			end
		end
	end

	-- Connect adjacent rooms with hallway connectors
	for row = 1, grid do
		for col = 1, grid do
			if cellData[row][col] then
				-- Connect to right neighbor
				if col < grid and cellData[row][col + 1] then
					local a = cellData[row][col].origin
					local b = cellData[row][col + 1].origin
					local midA = a + Vector3.new(unit * cellData[row][col].template.SizeMultiplier.X / 2, 0, 0)
					local midB = b - Vector3.new(unit * cellData[row][col + 1].template.SizeMultiplier.X / 2, 0, 0)
					if (midB - midA).Magnitude > 2 then
						buildConnector(midA, midB, floorFolder)
					end
				end
				-- Connect to bottom neighbor
				if row < grid and cellData[row + 1] and cellData[row + 1][col] then
					local a = cellData[row][col].origin
					local b = cellData[row + 1][col].origin
					local midA = a + Vector3.new(0, 0, unit * cellData[row][col].template.SizeMultiplier.Z / 2)
					local midB = b - Vector3.new(0, 0, unit * cellData[row + 1][col].template.SizeMultiplier.Z / 2)
					if (midB - midA).Magnitude > 2 then
						buildConnector(midA, midB, floorFolder)
					end
				end
			end
		end
	end

	-- Create a SpawnLocation in the elevator
	local elevRow = math.ceil(grid / 2)
	local elevCol = math.ceil(grid / 2)
	if cellData[elevRow] and cellData[elevRow][elevCol] then
		local elevOrigin = cellData[elevRow][elevCol].origin
		if floorIndex == 1 then
			local spawn = Instance.new("SpawnLocation")
			spawn.Anchored = true
			spawn.CanCollide = true
			spawn.Size = Vector3.new(4, 1, 4)
			spawn.CFrame = CFrame.new(elevOrigin + Vector3.new(0, 0.5, 0))
			spawn.TopSurface = Enum.SurfaceType.Smooth
			spawn.Transparency = 1
			spawn.Name = "ElevatorSpawn"
			spawn.Parent = floorFolder
		end
	end

	return floorFolder
end

---------------------------------------------------------------------------
-- MAIN
---------------------------------------------------------------------------
local function generate()
	-- Determine seed
	local seed = Config.Map.Seed
	if seed == 0 then
		seed = math.random(1, 999999)
	end
	print("[MapGenerator] Generating with seed:", seed)

	local rng = Random.new(seed)

	-- Store seed as attribute on the map folder so clients can read it
	mapFolder:SetAttribute("Seed", seed)

	for floor = 1, MC.FloorsToGenerate do
		generateFloor(floor, rng)
		print("[MapGenerator] Floor", floor, "generated.")
	end

	-- Create RemoteEvents for game systems
	local events = Instance.new("Folder")
	events.Name = "GameEvents"
	events.Parent = ReplicatedStorage

	local soundEvent = Instance.new("RemoteEvent")
	soundEvent.Name = "SoundEvent"
	soundEvent.Parent = events

	local doorEvent = Instance.new("RemoteEvent")
	doorEvent.Name = "DoorEvent"
	doorEvent.Parent = events

	local healthEvent = Instance.new("RemoteEvent")
	healthEvent.Name = "HealthUpdate"
	healthEvent.Parent = events

	local aiAlertEvent = Instance.new("RemoteEvent")
	aiAlertEvent.Name = "AIAlert"
	aiAlertEvent.Parent = events

	print("[MapGenerator] All floors and events ready.")
end

generate()
