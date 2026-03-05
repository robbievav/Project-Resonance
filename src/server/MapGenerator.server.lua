--[[
	MapGenerator.server.lua
	Seed-based procedural floor generator for Project: Resonance.
	Phase 2: 50 floors, lazy loading, stairwells, hiding spots, floor themes.
]]

local ServerStorage     = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Lighting          = game:GetService("Lighting")
local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")

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
-- LAZY LOADING STATE
---------------------------------------------------------------------------
local loadedFloors = {}   -- [floorIndex] = floorFolder
local floorSeeds   = {}   -- [floorIndex] = RNG state (for deterministic rebuild)
local masterRng    = nil  -- set in generate()

---------------------------------------------------------------------------
-- FLOOR THEME HELPER
---------------------------------------------------------------------------
local function getFloorTheme(floorIndex)
	for _, theme in ipairs(Config.FloorThemes) do
		if floorIndex >= theme.FloorRange[1] and floorIndex <= theme.FloorRange[2] then
			return theme
		end
	end
	return Config.FloorThemes[1]
end

---------------------------------------------------------------------------
-- UTILITY HELPERS
---------------------------------------------------------------------------
local function getMaterial(name)
	return Enum.Material[name] or Enum.Material.SmoothPlastic
end

local function makePart(props)
	local p = Instance.new("Part")
	p.Anchored    = true
	p.CanCollide  = props.CanCollide ~= false
	p.Size        = props.Size or Vector3.new(1,1,1)
	p.CFrame      = props.CFrame or CFrame.new()
	p.Material    = props.Material or Enum.Material.SmoothPlastic
	p.Color       = props.Color or Color3.fromRGB(180,180,180)
	p.TopSurface  = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Name        = props.Name or "Part"
	p.Parent      = props.Parent
	return p
end

---------------------------------------------------------------------------
-- NEW FURNITURE BUILDERS (Phase 2)
---------------------------------------------------------------------------
local function buildShelfUnit(origin, rot, parent)
	local fRot = CFrame.Angles(0, math.rad(rot), 0)
	-- Frame
	makePart({ Name="ShelfFrame", Size=Vector3.new(1.5, 8, 4), CFrame=CFrame.new(origin + Vector3.new(0,4,0)) * fRot, Material=Enum.Material.Metal, Color=Color3.fromRGB(90,90,85), Parent=parent })
	-- Shelves
	for _, sy in ipairs({1.5, 3.5, 5.5, 7.5}) do
		makePart({ Name="Shelf", Size=Vector3.new(2, 0.2, 4), CFrame=CFrame.new(origin + Vector3.new(0,sy,0)) * fRot, Material=Enum.Material.Wood, Color=Color3.fromRGB(110,95,70), Parent=parent })
	end
end

local function buildCrate(origin, rot, parent)
	local fRot = CFrame.Angles(0, math.rad(rot), 0)
	makePart({ Name="Crate", Size=Vector3.new(3, 2.5, 3), CFrame=CFrame.new(origin + Vector3.new(0,1.25,0)) * fRot, Material=Enum.Material.Wood, Color=CC.Crate, Parent=parent })
end

local function buildLabBench(origin, rot, parent)
	local fRot = CFrame.Angles(0, math.rad(rot), 0)
	-- Bench surface (like a desk but wider and with a different look)
	makePart({ Name="LabBenchTop", Size=Vector3.new(6, 0.3, 3), CFrame=CFrame.new(origin + Vector3.new(0,2.8,0)) * fRot, Material=Enum.Material.SmoothPlastic, Color=CC.LabBench, Parent=parent })
	-- Legs
	for _, lx in ipairs({-2.5, 2.5}) do
		for _, lz in ipairs({-1.2, 1.2}) do
			makePart({ Name="LabBenchLeg", Size=Vector3.new(0.3, 2.8, 0.3), CFrame=CFrame.new(origin + Vector3.new(lx, 1.4, lz)) * fRot, Material=Enum.Material.Metal, Color=Color3.fromRGB(80,80,80), Parent=parent })
		end
	end
	-- Beakers/equipment
	makePart({ Name="Beaker", Size=Vector3.new(0.4, 0.8, 0.4), CFrame=CFrame.new(origin + Vector3.new(1, 3.3, 0)) * fRot, Material=Enum.Material.Glass, Color=Color3.fromRGB(180,200,180), Parent=parent })
end

local function buildBathroomStall(origin, rot, parent)
	local fRot = CFrame.Angles(0, math.rad(rot), 0)
	-- Left wall
	makePart({ Name="StallWallL", Size=Vector3.new(0.2, 5, 4), CFrame=CFrame.new(origin + Vector3.new(-1.5, 2.5, 0)) * fRot, Material=Enum.Material.SmoothPlastic, Color=Color3.fromRGB(180,180,175), Parent=parent })
	-- Right wall
	makePart({ Name="StallWallR", Size=Vector3.new(0.2, 5, 4), CFrame=CFrame.new(origin + Vector3.new(1.5, 2.5, 0)) * fRot, Material=Enum.Material.SmoothPlastic, Color=Color3.fromRGB(180,180,175), Parent=parent })
	-- Door
	local stallDoor = makePart({ Name="StallDoor", Size=Vector3.new(2.8, 4, 0.15), CFrame=CFrame.new(origin + Vector3.new(0, 2, -2)) * fRot, Material=Enum.Material.SmoothPlastic, Color=Color3.fromRGB(170,170,165), Parent=parent })
	-- Toilet
	makePart({ Name="Toilet", Size=Vector3.new(1.2, 1.5, 1.5), CFrame=CFrame.new(origin + Vector3.new(0, 0.75, 1)) * fRot, Material=Enum.Material.SmoothPlastic, Color=Color3.fromRGB(230,230,225), Parent=parent })
end

local function buildBathroomSink(origin, rot, parent)
	local fRot = CFrame.Angles(0, math.rad(rot), 0)
	-- Counter
	makePart({ Name="SinkCounter", Size=Vector3.new(0.5, 2.5, 6), CFrame=CFrame.new(origin + Vector3.new(0, 1.25, 0)) * fRot, Material=Enum.Material.SmoothPlastic, Color=Color3.fromRGB(200,200,195), Parent=parent })
	-- Mirror
	local mirror = makePart({ Name="Mirror", Size=Vector3.new(0.1, 3, 5), CFrame=CFrame.new(origin + Vector3.new(-0.1, 4, 0)) * fRot, Material=Enum.Material.Glass, Color=Color3.fromRGB(150,160,170), Parent=parent })
	mirror.Transparency = 0.3
	mirror.Reflectance = 0.4
end

local function buildServerRack(origin, rot, parent)
	local fRot = CFrame.Angles(0, math.rad(rot), 0)
	-- Main rack body
	makePart({ Name="ServerRackBody", Size=Vector3.new(2, 8, 3), CFrame=CFrame.new(origin + Vector3.new(0,4,0)) * fRot, Material=Enum.Material.Metal, Color=Color3.fromRGB(30,30,35), Parent=parent })
	-- Indicator LEDs (neon strips)
	for i = 1, 5 do
		local led = makePart({ Name="ServerLED", Size=Vector3.new(0.1, 0.15, 0.15), CFrame=CFrame.new(origin + Vector3.new(-1.05, 1.5 + i * 1.1, 0.5)) * fRot, Material=Enum.Material.Neon, Color=Color3.fromRGB(30,120,200), Parent=parent })
	end
end

---------------------------------------------------------------------------
-- ROOM BUILDER
---------------------------------------------------------------------------
local function buildRoom(template, origin, floorFolder, floorIndex)
	local unit = MC.RoomUnit
	local sx = unit * template.SizeMultiplier.X
	local sz = unit * template.SizeMultiplier.Z
	local height = MC.WallHeight * template.SizeMultiplier.Y
	local thick = MC.WallThickness

	-- Apply floor theme overrides
	local theme = getFloorTheme(floorIndex)
	local wallColor = theme.WallColor
	local floorColor = theme.FloorColor
	local wallMat = getMaterial(theme.WallMaterial)
	local lightMult = theme.LightMult

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
			local dw = MC.DoorWidth
			local dh = MC.DoorHeight
			local dOff = doorSet[w.side].Offset

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
				makePart({ Name="WallAboveDoor", Size=aboveSize, CFrame=aboveCF, Material=wallMat, Color=wallColor, Parent=roomFolder })
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
				makePart({ Name="WallLeft", Size=lSize, CFrame=lCF, Material=wallMat, Color=wallColor, Parent=roomFolder })
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
				makePart({ Name="WallRight", Size=rSize, CFrame=rCF, Material=wallMat, Color=wallColor, Parent=roomFolder })
			end

			-- Create door part
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

			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Open"
			prompt.ObjectText = "Door"
			prompt.MaxActivationDistance = 8
			prompt.HoldDuration = 0.3
			prompt.Parent = doorPart

			local tag = Instance.new("StringValue")
			tag.Name = "DoorTag"
			tag.Value = template.Name
			tag.Parent = doorPart
		else
			makePart({
				Name   = "Wall_" .. w.side,
				Size   = w.size,
				CFrame = CFrame.new(origin + w.pos),
				Material = wallMat,
				Color    = wallColor,
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
			light.Brightness = Config.Lighting.FluorescentBrightness * lightMult
			light.Range = Config.Lighting.FluorescentRange
			light.Color = Config.Colors.FluorLight
			light.Angle = 120
			light.Parent = housing

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
			pl.Brightness = 0.5 * lightMult
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
			makePart({ Name="DeskTop", Size=Vector3.new(5, 0.3, 2.5), CFrame=CFrame.new(fPos + Vector3.new(0, 2.5, 0)) * fRot, Material=Enum.Material.Wood, Color=Color3.fromRGB(130,100,70), Parent=roomFolder })
			for _, lx in ipairs({-2.2, 2.2}) do
				for _, lz in ipairs({-1, 1}) do
					makePart({ Name="DeskLeg", Size=Vector3.new(0.3, 2.5, 0.3), CFrame=CFrame.new(fPos + Vector3.new(lx, 1.25, lz)) * fRot, Material=Enum.Material.Metal, Color=Color3.fromRGB(90,90,90), Parent=roomFolder })
				end
			end

		elseif furn.Type == "Chair" then
			makePart({ Name="ChairSeat", Size=Vector3.new(2, 0.3, 2), CFrame=CFrame.new(fPos + Vector3.new(0,1.8,0)) * fRot, Material=Enum.Material.Fabric, Color=Color3.fromRGB(60,65,75), Parent=roomFolder })
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
			makePart({ Name="ConsoleDeck", Size=Vector3.new(4, 2.5, 2), CFrame=CFrame.new(fPos + Vector3.new(0,1.25,0)) * fRot, Material=Enum.Material.Metal, Color=Color3.fromRGB(70,70,75), Parent=roomFolder })
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
			local prompt = Instance.new("ProximityPrompt")
			prompt.ActionText = "Take"
			prompt.ObjectText = "Med Kit"
			prompt.MaxActivationDistance = 6
			prompt.Parent = kit

		elseif furn.Type == "Locker" then
			makePart({ Name="Locker", Size=Vector3.new(1.5, 6, 2), CFrame=CFrame.new(fPos + Vector3.new(0,3,0)) * fRot, Material=Enum.Material.Metal, Color=Color3.fromRGB(95,100,95), Parent=roomFolder })

		elseif furn.Type == "ElevatorPanel" then
			makePart({ Name="ElevatorPanel", Size=Vector3.new(0.3, 1.5, 1), CFrame=CFrame.new(fPos) * fRot, Material=Enum.Material.Metal, Color=Color3.fromRGB(70,70,75), Parent=roomFolder })
			makePart({ Name="ElevatorButton", Size=Vector3.new(0.35, 0.3, 0.3), CFrame=CFrame.new(fPos + Vector3.new(-0.05, 0.3, 0)) * fRot, Material=Enum.Material.Neon, Color=Color3.fromRGB(200, 60, 40), Parent=roomFolder })

		-- Phase 2 furniture types
		elseif furn.Type == "ShelfUnit" then
			buildShelfUnit(fPos, furn.Rotation, roomFolder)

		elseif furn.Type == "Crate" then
			buildCrate(fPos, furn.Rotation, roomFolder)

		elseif furn.Type == "LabBench" then
			buildLabBench(fPos, furn.Rotation, roomFolder)

		elseif furn.Type == "BathroomStall" then
			buildBathroomStall(fPos, furn.Rotation, roomFolder)

		elseif furn.Type == "BathroomSink" then
			buildBathroomSink(fPos, furn.Rotation, roomFolder)

		elseif furn.Type == "ServerRack" then
			buildServerRack(fPos, furn.Rotation, roomFolder)
		end
	end

	-- HIDING SPOTS (Phase 2)
	if template.HidingSpots then
		for _, spot in ipairs(template.HidingSpots) do
			local spotPos = origin + spot.Offset
			local spotRot = CFrame.Angles(0, math.rad(spot.Rotation), 0)

			local hidePart = makePart({
				Name = "HidingSpot",
				Size = Vector3.new(2, 3, 2),
				CFrame = CFrame.new(spotPos + Vector3.new(0, 1.5, 0)) * spotRot,
				Material = Enum.Material.SmoothPlastic,
				Color = Color3.fromRGB(0, 0, 0),
				CanCollide = false,
				Parent = roomFolder,
			})
			hidePart.Transparency = 1  -- invisible trigger volume

			-- Tag it
			local typeTag = Instance.new("StringValue")
			typeTag.Name = "HideType"
			typeTag.Value = spot.Type
			typeTag.Parent = hidePart

			local floorTag = Instance.new("IntValue")
			floorTag.Name = "FloorIndex"
			floorTag.Value = floorIndex
			floorTag.Parent = hidePart

			-- ProximityPrompt for entering the spot
			local hidePrompt = Instance.new("ProximityPrompt")
			hidePrompt.ActionText = "Hide"
			hidePrompt.ObjectText = spot.Type
			hidePrompt.MaxActivationDistance = 6
			hidePrompt.HoldDuration = Config.Hiding.EnterTime
			hidePrompt.Parent = hidePart
		end
	end

	return roomFolder
end

---------------------------------------------------------------------------
-- STAIRWELL BUILDER — spiral staircase connecting this floor to the next
---------------------------------------------------------------------------
local function buildStairwell(origin, floorIndex, floorFolder)
	local height = MC.WallHeight * 2  -- stairwells are double height
	local stairWidth = 3
	local numSteps = 16
	local stepHeight = MC.FloorSeparation / numSteps

	-- Build the stairwell room itself
	local template = RoomTemplates.Stairwell
	buildRoom(template, origin, floorFolder, floorIndex)

	-- Add spiral stairs going DOWN to next floor
	local stairFolder = Instance.new("Folder")
	stairFolder.Name = "Stairs_" .. floorIndex
	stairFolder.Parent = floorFolder

	for i = 0, numSteps - 1 do
		local angle = (i / numSteps) * math.pi * 2
		local y = -(i * stepHeight)
		local x = math.cos(angle) * 4
		local z = math.sin(angle) * 4

		local step = makePart({
			Name = "Step_" .. i,
			Size = Vector3.new(stairWidth, 0.5, 2),
			CFrame = CFrame.new(origin + Vector3.new(x, y - 0.25, z)) * CFrame.Angles(0, -angle, 0),
			Material = Enum.Material.Concrete,
			Color = Config.Colors.DarkConcrete,
			Parent = stairFolder,
		})

		-- Railing
		makePart({
			Name = "Railing_" .. i,
			Size = Vector3.new(0.2, 3, 0.2),
			CFrame = CFrame.new(origin + Vector3.new(x + math.cos(angle) * 1.5, y + 1.25, z + math.sin(angle) * 1.5)),
			Material = Enum.Material.Metal,
			Color = Config.Colors.MetalGrate,
			Parent = stairFolder,
		})
	end
end

---------------------------------------------------------------------------
-- HALLWAY CONNECTOR
---------------------------------------------------------------------------
local function buildConnector(posA, posB, floorFolder, floorIndex)
	local mid = (posA + posB) / 2
	local diff = posB - posA
	local length = diff.Magnitude
	local dir = diff.Unit
	local height = MC.WallHeight
	local thick = MC.WallThickness
	local hw = MC.HallwayWidth

	local theme = getFloorTheme(floorIndex)
	local cf = CFrame.lookAt(mid, mid + dir) * CFrame.new(0, 0, 0)

	makePart({
		Name = "ConnectorFloor",
		Size = Vector3.new(hw, thick, length),
		CFrame = cf * CFrame.new(0, -thick/2, 0),
		Material = getMaterial(Config.Materials.Floor),
		Color = theme.FloorColor,
		Parent = floorFolder,
	})

	makePart({
		Name = "ConnectorCeiling",
		Size = Vector3.new(hw, thick, length),
		CFrame = cf * CFrame.new(0, height + thick/2, 0),
		Material = getMaterial(Config.Materials.Ceiling),
		Color = Config.Colors.CeilingPanel,
		Parent = floorFolder,
	})

	makePart({
		Name = "ConnectorWallL",
		Size = Vector3.new(thick, height, length),
		CFrame = cf * CFrame.new(-hw/2, height/2, 0),
		Material = getMaterial(theme.WallMaterial),
		Color = theme.WallColor,
		Parent = floorFolder,
	})

	makePart({
		Name = "ConnectorWallR",
		Size = Vector3.new(thick, height, length),
		CFrame = cf * CFrame.new(hw/2, height/2, 0),
		Material = getMaterial(theme.WallMaterial),
		Color = theme.WallColor,
		Parent = floorFolder,
	})

	local bulb = makePart({
		Name = "ConnectorLight",
		Size = Vector3.new(0.4, 0.4, 0.4),
		CFrame = cf * CFrame.new(0, height - 0.5, 0),
		Material = Enum.Material.Neon,
		Color = Config.Colors.FluorLight,
		Parent = floorFolder,
	})
	local pl = Instance.new("PointLight")
	pl.Brightness = 0.4 * getFloorTheme(floorIndex).LightMult
	pl.Range = 14
	pl.Color = Config.Colors.FluorLight
	pl.Parent = bulb
end

---------------------------------------------------------------------------
-- FLOOR GENERATOR
---------------------------------------------------------------------------
local function generateFloor(floorIndex, rng)
	-- Don't regenerate if already loaded
	if loadedFloors[floorIndex] then return loadedFloors[floorIndex] end

	local floorFolder = Instance.new("Folder")
	floorFolder.Name = "Floor_" .. floorIndex
	floorFolder.Parent = mapFolder

	local baseY = -(floorIndex - 1) * MC.FloorSeparation
	local grid  = MC.RoomGridSize
	local unit  = MC.RoomUnit

	local cellData = {}

	for row = 1, grid do
		cellData[row] = {}
		for col = 1, grid do
			local origin = Vector3.new(
				(col - 1) * (unit * 2) - (grid * unit),
				baseY,
				(row - 1) * (unit * 2) - (grid * unit)
			)

			local templateName
			-- Place elevator at grid center
			if row == math.ceil(grid/2) and col == math.ceil(grid/2) then
				templateName = "Elevator"
			-- Place stairwell at fixed position
			elseif row == MC.StairwellGridRow and col == MC.StairwellGridCol then
				templateName = "Stairwell"
			else
				templateName = RoomTemplates.GetRandomType(rng)
			end

			local template = RoomTemplates[templateName]
			if template then
				if templateName == "Stairwell" then
					buildStairwell(origin, floorIndex, floorFolder)
				else
					buildRoom(template, origin, floorFolder, floorIndex)
				end
				cellData[row][col] = { origin = origin, template = template }
			end
		end
	end

	-- Connect adjacent rooms with hallway connectors
	for row = 1, grid do
		for col = 1, grid do
			if cellData[row][col] then
				if col < grid and cellData[row][col + 1] then
					local a = cellData[row][col].origin
					local b = cellData[row][col + 1].origin
					local midA = a + Vector3.new(unit * cellData[row][col].template.SizeMultiplier.X / 2, 0, 0)
					local midB = b - Vector3.new(unit * cellData[row][col + 1].template.SizeMultiplier.X / 2, 0, 0)
					if (midB - midA).Magnitude > 2 then
						buildConnector(midA, midB, floorFolder, floorIndex)
					end
				end
				if row < grid and cellData[row + 1] and cellData[row + 1][col] then
					local a = cellData[row][col].origin
					local b = cellData[row + 1][col].origin
					local midA = a + Vector3.new(0, 0, unit * cellData[row][col].template.SizeMultiplier.Z / 2)
					local midB = b - Vector3.new(0, 0, unit * cellData[row + 1][col].template.SizeMultiplier.Z / 2)
					if (midB - midA).Magnitude > 2 then
						buildConnector(midA, midB, floorFolder, floorIndex)
					end
				end
			end
		end
	end

	-- SpawnLocation on floor 1
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

	loadedFloors[floorIndex] = floorFolder
	print("[MapGenerator] Floor", floorIndex, "generated. Theme:", getFloorTheme(floorIndex).Name)
	return floorFolder
end

---------------------------------------------------------------------------
-- UNLOAD FLOOR (lazy loading)
---------------------------------------------------------------------------
local function unloadFloor(floorIndex)
	local folder = loadedFloors[floorIndex]
	if folder then
		folder:Destroy()
		loadedFloors[floorIndex] = nil
		print("[MapGenerator] Floor", floorIndex, "unloaded.")
	end
end

---------------------------------------------------------------------------
-- GET PLAYER'S CURRENT FLOOR
---------------------------------------------------------------------------
local function getPlayerFloor(player)
	local char = player.Character
	if not char then return 1 end
	local root = char:FindFirstChild("HumanoidRootPart")
	if not root then return 1 end

	local y = root.Position.Y
	-- Floor 1 is at Y=0, Floor 2 at Y=-50, etc.
	local floorIndex = math.floor(-y / MC.FloorSeparation) + 1
	return math.clamp(floorIndex, 1, MC.FloorsToGenerate)
end

---------------------------------------------------------------------------
-- LAZY FLOOR MANAGER
---------------------------------------------------------------------------
local function updateLoadedFloors()
	-- Find the deepest floor any player is on
	local deepestFloor = 1
	for _, player in ipairs(Players:GetPlayers()) do
		local pFloor = getPlayerFloor(player)
		if pFloor > deepestFloor then
			deepestFloor = pFloor
		end
	end

	local range = MC.ActiveFloorRange
	local minFloor = math.max(1, deepestFloor - range)
	local maxFloor = math.min(MC.FloorsToGenerate, deepestFloor + range)

	-- Generate floors that should be loaded
	for i = minFloor, maxFloor do
		if not loadedFloors[i] then
			-- Create a deterministic RNG for this floor
			local floorRng = Random.new(floorSeeds[i])
			generateFloor(i, floorRng)
		end
	end

	-- Unload floors outside the range
	for idx, _ in pairs(loadedFloors) do
		if idx < minFloor or idx > maxFloor then
			unloadFloor(idx)
		end
	end

	-- Set current floor attribute on players
	for _, player in ipairs(Players:GetPlayers()) do
		player:SetAttribute("CurrentFloor", getPlayerFloor(player))
	end
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

	masterRng = Random.new(seed)
	mapFolder:SetAttribute("Seed", seed)

	-- Pre-compute deterministic seeds for each floor
	for floor = 1, MC.FloorsToGenerate do
		floorSeeds[floor] = masterRng:NextInteger(1, 999999)
	end

	-- Generate initial floors (floor 1 and adjacent)
	for floor = 1, math.min(1 + MC.ActiveFloorRange, MC.FloorsToGenerate) do
		local floorRng = Random.new(floorSeeds[floor])
		generateFloor(floor, floorRng)
	end

	-- Create RemoteEvents
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

	local hideEvent = Instance.new("RemoteEvent")
	hideEvent.Name = "HideEvent"
	hideEvent.Parent = events

	local breathingFailEvent = Instance.new("RemoteEvent")
	breathingFailEvent.Name = "BreathingFail"
	breathingFailEvent.Parent = events

	print("[MapGenerator] Initial floors and events ready. Lazy loading active for", MC.FloorsToGenerate, "floors.")

	-- Start lazy loading loop
	RunService.Heartbeat:Connect(function()
		updateLoadedFloors()
	end)
end

generate()
