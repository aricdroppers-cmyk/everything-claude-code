--[[
	DEEP SEA SALVAGE - Server
	Type: Script (a normal server Script, NOT a LocalScript)
	Name it: SalvageServer
	Put it in: ServerScriptService

	This script:
	  * builds the whole map when the game starts (ocean, island, lighthouse,
	    docks, cranes, kelp, rocks, lighting)
	  * gives every player their own salvage bay with up to 5 subs
	  * runs the dive -> haul -> collect loop and the loot rolls
	  * restores ships when a player completes a set
	  * runs events (Storm Surge, Treasure Tide, Kraken Attack)
	  * saves progress with DataStores
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local Config = require(ReplicatedStorage:WaitForChild("SalvageConfig"))

local rng = Random.new()
local BAY_COUNT = 6
local DIVE_ANIM_TIME = 2.5

local function now()
	return workspace:GetServerTimeNow()
end

---------------------------------------------------------------------------
-- REMOTES
---------------------------------------------------------------------------
local remotes = Instance.new("Folder")
remotes.Name = "SalvageRemotes"

local StateUpdate = Instance.new("RemoteEvent")
StateUpdate.Name = "StateUpdate"
StateUpdate.Parent = remotes

local Notify = Instance.new("RemoteEvent")
Notify.Name = "Notify"
Notify.Parent = remotes

local Action = Instance.new("RemoteEvent")
Action.Name = "Action"
Action.Parent = remotes

remotes:SetAttribute("EventId", "")
remotes:SetAttribute("EventEnd", 0)
remotes:SetAttribute("KrakenHP", 0)
remotes:SetAttribute("KrakenMax", 0)
remotes.Parent = ReplicatedStorage

---------------------------------------------------------------------------
-- BUILD HELPERS
---------------------------------------------------------------------------
local World = Instance.new("Folder")
World.Name = "SalvageWorld"
World.Parent = workspace

local function makePart(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props.Shape then
		p.Shape = props.Shape
	end
	for key, value in pairs(props) do
		if key ~= "Parent" and key ~= "Shape" then
			p[key] = value
		end
	end
	p.Parent = props.Parent or World
	return p
end

-- Point on a circle around the island. angle in radians, 0 = +Z
local function polar(radius, angle, y)
	return Vector3.new(math.sin(angle) * radius, y, math.cos(angle) * radius)
end

-- Cylinders in Roblox point along X; this stands one upright
local UPRIGHT = CFrame.Angles(0, 0, math.rad(90))

local function addBillboard(adornee, text, color, offsetY, maxDistance, sizeX)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, sizeX or 200, 0, 40)
	gui.StudsOffset = Vector3.new(0, offsetY or 4, 0)
	gui.MaxDistance = maxDistance or 120
	gui.AlwaysOnTop = false
	gui.Adornee = adornee
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = color or Color3.new(1, 1, 1)
	label.TextStrokeTransparency = 0.3
	label.Text = text
	label.Parent = gui
	gui.Parent = adornee
	return label, gui
end

local function addSurfaceText(part, face, text, textColor, bgColor)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundColor3 = bgColor or Color3.fromRGB(20, 40, 60)
	label.BackgroundTransparency = bgColor and 0 or 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = textColor
	label.Text = text
	label.Parent = gui
	gui.Parent = part
	return label
end

---------------------------------------------------------------------------
-- LIGHTING + OCEAN
---------------------------------------------------------------------------
local function getOrCreate(parent, className, name)
	local obj = parent:FindFirstChild(name)
	if not obj then
		obj = Instance.new(className)
		obj.Name = name
		obj.Parent = parent
	end
	return obj
end

local function buildLighting()
	Lighting.ClockTime = 16.6
	Lighting.Brightness = 2.4
	Lighting.Ambient = Color3.fromRGB(70, 80, 100)
	Lighting.OutdoorAmbient = Color3.fromRGB(130, 150, 170)
	Lighting.EnvironmentDiffuseScale = 0.6
	Lighting.EnvironmentSpecularScale = 0.8
	Lighting.GlobalShadows = true

	local atmosphere = getOrCreate(Lighting, "Atmosphere", "SalvageAtmosphere")
	atmosphere.Density = 0.3
	atmosphere.Offset = 0.25
	atmosphere.Color = Color3.fromRGB(199, 222, 236)
	atmosphere.Decay = Color3.fromRGB(100, 140, 175)
	atmosphere.Glare = 0.4
	atmosphere.Haze = 1.4

	local cc = getOrCreate(Lighting, "ColorCorrectionEffect", "SalvageColor")
	cc.Saturation = 0.15
	cc.Contrast = 0.06
	cc.TintColor = Color3.fromRGB(255, 250, 245)

	local bloom = getOrCreate(Lighting, "BloomEffect", "SalvageBloom")
	bloom.Intensity = 0.6
	bloom.Size = 24
	bloom.Threshold = 1.6

	local rays = getOrCreate(Lighting, "SunRaysEffect", "SalvageSunRays")
	rays.Intensity = 0.06
	rays.Spread = 0.6

	local clouds = getOrCreate(workspace.Terrain, "Clouds", "SalvageClouds")
	clouds.Cover = 0.55
	clouds.Density = 0.6
	clouds.Color = Color3.fromRGB(255, 255, 255)
end

local function buildOcean()
	-- Remove the default template floor/spawn so they don't cover the ocean
	for _, name in ipairs({ "Baseplate", "SpawnLocation" }) do
		local obj = workspace:FindFirstChild(name)
		if obj and obj:IsA("BasePart") then
			obj:Destroy()
		end
	end

	local terrain = workspace.Terrain
	terrain:FillBlock(CFrame.new(0, -60, 0), Vector3.new(1024, 8, 1024), Enum.Material.Sand)
	terrain:FillBlock(CFrame.new(0, -28, 0), Vector3.new(1024, 56, 1024), Enum.Material.Water)
	terrain.WaterColor = Color3.fromRGB(16, 118, 140)
	terrain.WaterTransparency = 0.45
	terrain.WaterReflectance = 0.35
	terrain.WaterWaveSize = 0.15
	terrain.WaterWaveSpeed = 12

	-- Sea floor decoration: kelp forests, rocks, coral, an old anchor
	local seabed = Instance.new("Folder")
	seabed.Name = "Seabed"
	seabed.Parent = World
	for _ = 1, 70 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(85, 330)
		local height = rng:NextNumber(14, 40)
		local base = polar(radius, angle, -56)
		makePart({
			Name = "Kelp",
			Size = Vector3.new(0.8, height, 0.4),
			CFrame = CFrame.new(base + Vector3.new(0, height / 2, 0))
				* CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, 6.28), rng:NextNumber(-0.15, 0.15)),
			Color = Color3.fromRGB(40, rng:NextInteger(110, 150), 60),
			Material = Enum.Material.Grass,
			CanCollide = false,
			Parent = seabed,
		})
	end
	for _ = 1, 45 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(80, 380)
		local s = rng:NextNumber(4, 14)
		makePart({
			Name = "Rock",
			Size = Vector3.new(s, s * rng:NextNumber(0.5, 1), s * rng:NextNumber(0.7, 1.3)),
			CFrame = CFrame.new(polar(radius, angle, -55)) * CFrame.Angles(rng:NextNumber(0, 6.28), rng:NextNumber(0, 6.28), 0),
			Color = Color3.fromRGB(80, 85, 90),
			Material = Enum.Material.Slate,
			Parent = seabed,
		})
	end
	local coralColors = {
		Color3.fromRGB(255, 110, 140), Color3.fromRGB(255, 160, 60), Color3.fromRGB(170, 90, 255), Color3.fromRGB(60, 220, 200),
	}
	for _ = 1, 40 do
		local angle = rng:NextNumber(0, math.pi * 2)
		local radius = rng:NextNumber(78, 140)
		local s = rng:NextNumber(2, 5)
		makePart({
			Name = "Coral",
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(s, s, s),
			CFrame = CFrame.new(polar(radius, angle, -55)),
			Color = coralColors[rng:NextInteger(1, #coralColors)],
			Material = Enum.Material.Pebble,
			CanCollide = false,
			Parent = seabed,
		})
	end
end

---------------------------------------------------------------------------
-- ISLAND: sand, grass, palm trees, lighthouse, title sign
---------------------------------------------------------------------------
local lighthouseLamp

local function buildPalm(position)
	local folder = Instance.new("Model")
	folder.Name = "Palm"
	folder.Parent = World
	local lean = rng:NextNumber(0, 6.28)
	local top = position
	for i = 1, 5 do
		local segCF = CFrame.new(top) * CFrame.Angles(0, lean, 0) * CFrame.Angles(math.rad(6 * i), 0, 0)
		local seg = makePart({
			Size = Vector3.new(1.3 - i * 0.08, 3, 1.3 - i * 0.08),
			CFrame = segCF * CFrame.new(0, 1.5, 0),
			Color = Color3.fromRGB(120, 85, 50),
			Material = Enum.Material.Wood,
			Parent = folder,
		})
		top = (seg.CFrame * CFrame.new(0, 1.5, 0)).Position
	end
	for i = 1, 6 do
		local a = math.rad(i * 60)
		makePart({
			Size = Vector3.new(1.6, 0.25, 7),
			CFrame = CFrame.new(top) * CFrame.Angles(0, a, 0) * CFrame.Angles(math.rad(-20), 0, 0) * CFrame.new(0, 0, -3.2),
			Color = Color3.fromRGB(60, 160, 70),
			Material = Enum.Material.Grass,
			CanCollide = false,
			Parent = folder,
		})
	end
	for i = 1, 3 do
		makePart({
			Shape = Enum.PartType.Ball,
			Size = Vector3.new(0.9, 0.9, 0.9),
			CFrame = CFrame.new(top + Vector3.new(math.cos(i * 2.1) * 0.7, -0.6, math.sin(i * 2.1) * 0.7)),
			Color = Color3.fromRGB(90, 60, 30),
			Parent = folder,
		})
	end
end

local function buildIsland()
	makePart({
		Name = "IslandSand",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(60, 150, 150),
		CFrame = CFrame.new(0, -27, 0) * UPRIGHT,
		Color = Color3.fromRGB(226, 205, 155),
		Material = Enum.Material.Sand,
	})
	makePart({
		Name = "IslandGrass",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(1.2, 118, 118),
		CFrame = CFrame.new(0, 3, 0) * UPRIGHT,
		Color = Color3.fromRGB(95, 165, 75),
		Material = Enum.Material.Grass,
	})

	local spawn = Instance.new("SpawnLocation")
	spawn.Name = "SalvageSpawn"
	spawn.Anchored = true
	spawn.Size = Vector3.new(10, 1, 10)
	spawn.CFrame = CFrame.new(0, 3.6, 20)
	spawn.Color = Color3.fromRGB(226, 205, 155)
	spawn.Material = Enum.Material.Sand
	spawn.Neutral = true
	spawn.Duration = 0
	spawn.TopSurface = Enum.SurfaceType.Smooth
	spawn.Parent = World

	-- Title sign in the middle of the island
	for _, x in ipairs({ -13, 13 }) do
		makePart({
			Size = Vector3.new(1.2, 14, 1.2),
			CFrame = CFrame.new(x, 10, 0),
			Color = Color3.fromRGB(100, 70, 45),
			Material = Enum.Material.Wood,
		})
	end
	local board = makePart({
		Name = "TitleSign",
		Size = Vector3.new(28, 7, 0.8),
		CFrame = CFrame.new(0, 14, 0),
		Color = Color3.fromRGB(20, 45, 70),
		Material = Enum.Material.WoodPlanks,
	})
	addSurfaceText(board, Enum.NormalId.Front, "DEEP SEA SALVAGE", Color3.fromRGB(90, 255, 230))
	addSurfaceText(board, Enum.NormalId.Back, "DEEP SEA SALVAGE", Color3.fromRGB(90, 255, 230))

	-- Lighthouse: striped tower with a rotating lamp
	local lhPos = Vector3.new(-34, 3.6, -30)
	for i = 0, 5 do
		makePart({
			Name = "LighthouseTower",
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(5, 9 - i * 0.6, 9 - i * 0.6),
			CFrame = CFrame.new(lhPos + Vector3.new(0, 2.5 + i * 5, 0)) * UPRIGHT,
			Color = (i % 2 == 0) and Color3.fromRGB(240, 240, 240) or Color3.fromRGB(200, 45, 45),
			Material = Enum.Material.SmoothPlastic,
		})
	end
	makePart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 8, 8),
		CFrame = CFrame.new(lhPos + Vector3.new(0, 30.3, 0)) * UPRIGHT,
		Color = Color3.fromRGB(40, 40, 45),
		Material = Enum.Material.Metal,
	})
	makePart({
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(4, 5.5, 5.5),
		CFrame = CFrame.new(lhPos + Vector3.new(0, 32.6, 0)) * UPRIGHT,
		Color = Color3.fromRGB(200, 240, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.6,
		CanCollide = false,
	})
	makePart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(6, 6, 6),
		CFrame = CFrame.new(lhPos + Vector3.new(0, 35.5, 0)),
		Color = Color3.fromRGB(200, 45, 45),
	})
	lighthouseLamp = makePart({
		Name = "LighthouseLamp",
		Size = Vector3.new(1.6, 1.6, 1.6),
		CFrame = CFrame.new(lhPos + Vector3.new(0, 32.6, 0)),
		Color = Color3.fromRGB(255, 240, 180),
		Material = Enum.Material.Neon,
		CanCollide = false,
	})
	local spot = Instance.new("SpotLight")
	spot.Face = Enum.NormalId.Front
	spot.Range = 60
	spot.Angle = 25
	spot.Brightness = 6
	spot.Color = Color3.fromRGB(255, 240, 190)
	spot.Parent = lighthouseLamp
	local glow = Instance.new("PointLight")
	glow.Range = 14
	glow.Brightness = 2
	glow.Color = Color3.fromRGB(255, 230, 160)
	glow.Parent = lighthouseLamp

	for _, pos in ipairs({
		Vector3.new(25, 3.6, -25), Vector3.new(38, 3.6, 10), Vector3.new(-40, 3.6, 18),
		Vector3.new(10, 3.6, -45), Vector3.new(-15, 3.6, 42), Vector3.new(30, 3.6, 38),
	}) do
		buildPalm(pos)
	end
end

---------------------------------------------------------------------------
-- BAYS: a pier from the island to each player's salvage dock
---------------------------------------------------------------------------
local Bays = {}

local function lampPost(cf, parent)
	makePart({
		Size = Vector3.new(0.5, 6, 0.5),
		CFrame = cf * CFrame.new(0, 3, 0),
		Color = Color3.fromRGB(45, 45, 50),
		Material = Enum.Material.Metal,
		Parent = parent,
	})
	local bulb = makePart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(1, 1, 1),
		CFrame = cf * CFrame.new(0, 6.3, 0),
		Color = Color3.fromRGB(255, 210, 140),
		Material = Enum.Material.Neon,
		CanCollide = false,
		Parent = parent,
	})
	local light = Instance.new("PointLight")
	light.Range = 16
	light.Brightness = 1.5
	light.Color = Color3.fromRGB(255, 200, 130)
	light.Parent = bulb
end

local function buildBay(index)
	local angle = math.rad((index - 1) * 360 / BAY_COUNT)
	local folder = Instance.new("Folder")
	folder.Name = "Bay" .. index
	folder.Parent = World

	local outward = polar(1, angle, 0)
	local wood = Color3.fromRGB(150, 110, 70)
	local darkWood = Color3.fromRGB(95, 68, 42)

	-- Pier from the island to the bay
	local pierCenter = polar(98, angle, 3.5)
	local pierCF = CFrame.lookAt(pierCenter, pierCenter + outward)
	makePart({
		Name = "Pier",
		Size = Vector3.new(10, 1, 82),
		CFrame = pierCF,
		Color = wood,
		Material = Enum.Material.WoodPlanks,
		Parent = folder,
	})
	for z = -40, 40, 10 do
		for _, x in ipairs({ -4.6, 4.6 }) do
			makePart({
				Size = Vector3.new(1, 16, 1),
				CFrame = pierCF * CFrame.new(x, -7, z),
				Color = darkWood,
				Material = Enum.Material.Wood,
				Parent = folder,
			})
		end
	end
	for z = -30, 30, 30 do
		lampPost(pierCF * CFrame.new(5.2, 0.5, z), folder)
	end

	-- Bay platform
	local bayCF = CFrame.lookAt(polar(150, angle, 3.5), polar(151, angle, 3.5))
	makePart({
		Name = "Deck",
		Size = Vector3.new(60, 1, 24),
		CFrame = bayCF,
		Color = wood,
		Material = Enum.Material.WoodPlanks,
		Parent = folder,
	})
	for _, x in ipairs({ -29, -15, 0, 15, 29 }) do
		for _, z in ipairs({ -11, 11 }) do
			makePart({
				Size = Vector3.new(1.2, 16, 1.2),
				CFrame = bayCF * CFrame.new(x, -7, z),
				Color = darkWood,
				Material = Enum.Material.Wood,
				Parent = folder,
			})
		end
	end
	lampPost(bayCF * CFrame.new(-28, 0.5, 10), folder)
	lampPost(bayCF * CFrame.new(28, 0.5, 10), folder)

	-- Barrels for decoration
	for _, x in ipairs({ -26, -24, 25 }) do
		makePart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(2.4, 2, 2),
			CFrame = bayCF * CFrame.new(x, 1.7, 7) * UPRIGHT,
			Color = Color3.fromRGB(110, 70, 40),
			Material = Enum.Material.Wood,
			Parent = folder,
		})
	end

	-- Entrance arch with the owner's name
	for _, x in ipairs({ -7, 7 }) do
		makePart({
			Size = Vector3.new(1, 11, 1),
			CFrame = bayCF * CFrame.new(x, 6, 11),
			Color = darkWood,
			Material = Enum.Material.Wood,
			Parent = folder,
		})
	end
	local sign = makePart({
		Name = "BaySign",
		Size = Vector3.new(16, 3, 0.5),
		CFrame = bayCF * CFrame.new(0, 11, 11),
		Color = Color3.fromRGB(20, 45, 70),
		Material = Enum.Material.WoodPlanks,
		Parent = folder,
	})
	local signFront = addSurfaceText(sign, Enum.NormalId.Front, "Unclaimed Bay", Color3.fromRGB(255, 230, 160))
	local signBack = addSurfaceText(sign, Enum.NormalId.Back, "Unclaimed Bay", Color3.fromRGB(255, 230, 160))

	-- Berths: crane + mooring spot for each sub
	local berths = {}
	for i = 1, Config.MaxFleet do
		local x = (i - 3) * 11
		local craneBase = bayCF * CFrame.new(x + 4.5, 0.5, -10.5)
		local post = makePart({
			Name = "Crane",
			Size = Vector3.new(10, 1, 1),
			CFrame = craneBase * CFrame.new(0, 5, 0) * UPRIGHT,
			Shape = Enum.PartType.Cylinder,
			Color = Color3.fromRGB(230, 170, 40),
			Material = Enum.Material.Metal,
			Parent = folder,
		})
		local armStart = (bayCF * CFrame.new(x + 4.5, 10, -10.5)).Position
		local armEnd = (bayCF * CFrame.new(x, 10, -17)).Position
		local armLength = (armEnd - armStart).Magnitude
		makePart({
			Size = Vector3.new(0.6, 0.6, armLength),
			CFrame = CFrame.lookAt((armStart + armEnd) / 2, armEnd),
			Color = Color3.fromRGB(230, 170, 40),
			Material = Enum.Material.Metal,
			Parent = folder,
		})
		local ropeTop = armEnd
		local ropeBottom = armEnd - Vector3.new(0, 10.5, 0)
		makePart({
			Size = Vector3.new(0.15, 10.5, 0.15),
			CFrame = CFrame.new((ropeTop + ropeBottom) / 2),
			Color = Color3.fromRGB(40, 35, 30),
			Material = Enum.Material.Fabric,
			CanCollide = false,
			Parent = folder,
		})
		makePart({
			Size = Vector3.new(0.8, 0.5, 0.8),
			CFrame = CFrame.new(ropeBottom),
			Color = Color3.fromRGB(60, 60, 65),
			Material = Enum.Material.Metal,
			CanCollide = false,
			Parent = folder,
		})

		local nameLabel, gui = addBillboard(post, "Empty Berth", Color3.fromRGB(200, 220, 230), 7.5, 90, 220)
		nameLabel.Size = UDim2.fromScale(1, 0.5)
		local statusLabel = Instance.new("TextLabel")
		statusLabel.Size = UDim2.fromScale(1, 0.5)
		statusLabel.Position = UDim2.fromScale(0, 0.5)
		statusLabel.BackgroundTransparency = 1
		statusLabel.Font = Enum.Font.GothamBold
		statusLabel.TextScaled = true
		statusLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
		statusLabel.TextStrokeTransparency = 0.3
		statusLabel.Text = ""
		statusLabel.Parent = gui
		gui.Size = UDim2.new(0, 220, 0, 60)

		berths[i] = {
			subCF = bayCF * CFrame.new(x, -3.2, -17),
			crateCF = bayCF * CFrame.new(x, 2, -6.5),
			nameLabel = nameLabel,
			statusLabel = statusLabel,
		}
	end

	-- Ship display slots (restored ships float here)
	local shipSlots = {}
	for j = 1, #Config.Ships do
		shipSlots[j] = bayCF * CFrame.new((j - (#Config.Ships + 1) / 2) * 13, -3.2, -46)
	end

	Bays[index] = {
		index = index,
		cf = bayCF,
		folder = folder,
		owner = nil,
		signLabels = { signFront, signBack },
		berths = berths,
		shipSlots = shipSlots,
	}
end

---------------------------------------------------------------------------
-- MODELS: submarines, crates, restored ships
---------------------------------------------------------------------------
local function buildSubModel(subDef)
	local _, tier = Config.GetSub(subDef.id)
	local model = Instance.new("Model")
	model.Name = subDef.id
	local root = makePart({
		Name = "Root",
		Size = Vector3.new(1, 1, 1),
		Transparency = 1,
		CanCollide = false,
		CFrame = CFrame.new(),
		Parent = model,
	})
	model.PrimaryPart = root

	local L = 4.5 + tier * 0.7
	local D = 2.6 + tier * 0.25
	local glowing = subDef.id == "Leviathan" or subDef.id == "AbyssCrawler"

	local function add(props, cf)
		props.Parent = model
		props.CanCollide = false
		props.CFrame = cf
		return makePart(props)
	end

	local alongZ = CFrame.Angles(0, math.rad(90), 0)
	add({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(L, D, D), Color = subDef.bodyColor, Material = subDef.material }, alongZ)
	add({ Shape = Enum.PartType.Ball, Size = Vector3.new(D, D, D), Color = subDef.bodyColor, Material = subDef.material }, CFrame.new(0, 0, L / 2))
	add({ Shape = Enum.PartType.Ball, Size = Vector3.new(D, D, D), Color = subDef.bodyColor, Material = subDef.material }, CFrame.new(0, 0, -L / 2))

	-- trim rings
	for _, z in ipairs({ -L * 0.25, L * 0.25 }) do
		add({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(0.45, D + 0.15, D + 0.15),
			Color = subDef.trimColor,
			Material = glowing and Enum.Material.Neon or Enum.Material.Metal,
		}, CFrame.new(0, 0, z) * alongZ)
	end

	-- front viewing window
	local window = add({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(D * 0.6, D * 0.6, D * 0.6),
		Color = Color3.fromRGB(150, 235, 255),
		Material = Enum.Material.Glass,
		Transparency = 0.15,
	}, CFrame.new(0, D * 0.1, -L / 2 - D * 0.28))
	if tier >= 3 then
		local light = Instance.new("SpotLight")
		light.Face = Enum.NormalId.Front
		light.Range = 30
		light.Angle = 50
		light.Brightness = 4
		light.Color = Color3.fromRGB(200, 240, 255)
		light.Parent = window
	end

	-- conning tower + periscope
	add({ Size = Vector3.new(D * 0.45, D * 0.5, L * 0.3), Color = subDef.trimColor, Material = subDef.material },
		CFrame.new(0, D * 0.55, -L * 0.05))
	add({ Size = Vector3.new(0.25, 1.2, 0.25), Color = Color3.fromRGB(60, 60, 65), Material = Enum.Material.Metal },
		CFrame.new(0, D * 0.8 + 0.6, -L * 0.12))

	-- portholes
	for _, side in ipairs({ -1, 1 }) do
		for _, z in ipairs({ -L * 0.1, L * 0.15 }) do
			add({
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(0.55, 0.55, 0.55),
				Color = glowing and subDef.trimColor or Color3.fromRGB(255, 230, 150),
				Material = Enum.Material.Neon,
			}, CFrame.new(side * D * 0.48, D * 0.12, z))
		end
	end

	-- tail fins + propeller
	local tailZ = L / 2 + D * 0.2
	add({ Size = Vector3.new(D * 1.6, 0.18, 1), Color = subDef.trimColor, Material = Enum.Material.Metal }, CFrame.new(0, 0, tailZ))
	add({ Size = Vector3.new(0.18, D * 1.2, 1), Color = subDef.trimColor, Material = Enum.Material.Metal }, CFrame.new(0, 0, tailZ))
	local hubZ = L / 2 + D / 2 + 0.15
	add({ Shape = Enum.PartType.Ball, Size = Vector3.new(0.6, 0.6, 0.6), Color = Color3.fromRGB(70, 70, 75), Material = Enum.Material.Metal },
		CFrame.new(0, 0, hubZ))
	for k = 0, 2 do
		add({ Size = Vector3.new(0.15, D * 0.8, 0.25), Color = Color3.fromRGB(200, 170, 80), Material = Enum.Material.Metal },
			CFrame.new(0, 0, hubZ) * CFrame.Angles(0, 0, math.rad(k * 60)))
	end

	if glowing then
		local light = Instance.new("PointLight")
		light.Range = 12
		light.Brightness = 1.5
		light.Color = subDef.trimColor
		light.Parent = root
	end

	return model
end

local function buildCrate(rarity, cf, parent)
	local rarityDef = Config.Rarities[rarity]
	local crate = makePart({
		Name = "HaulCrate",
		Size = Vector3.new(3, 3, 3),
		CFrame = cf * CFrame.Angles(0, rng:NextNumber(-0.3, 0.3), 0),
		Color = Color3.fromRGB(120, 85, 50),
		Material = Enum.Material.WoodPlanks,
		Parent = parent,
	})
	for _, y in ipairs({ -0.9, 0.9 }) do
		local band = makePart({
			Size = Vector3.new(3.1, 0.35, 3.1),
			CFrame = crate.CFrame * CFrame.new(0, y, 0),
			Color = rarityDef.color,
			Material = Enum.Material.Neon,
			CanCollide = false,
			Parent = crate,
		})
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = crate
		weld.Part1 = band
		weld.Parent = band
	end
	local light = Instance.new("PointLight")
	light.Color = rarityDef.color
	light.Range = 6 + rarity * 3
	light.Brightness = 1 + rarity * 0.5
	light.Parent = crate
	if rarity >= 3 then
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Color = ColorSequence.new(rarityDef.color)
		sparkles.LightEmission = 1
		sparkles.Rate = 6 + rarity * 6
		sparkles.Lifetime = NumberRange.new(1, 1.6)
		sparkles.Speed = NumberRange.new(2, 5)
		sparkles.SpreadAngle = Vector2.new(60, 60)
		sparkles.Size = NumberSequence.new(rarity >= 5 and 0.8 or 0.45)
		sparkles.Parent = crate
	end
	return crate
end

local HULL_COLORS = {
	Color3.fromRGB(135, 95, 58),
	Color3.fromRGB(110, 85, 55),
	Color3.fromRGB(35, 30, 35),
	Color3.fromRGB(240, 235, 225),
	Color3.fromRGB(80, 220, 210),
}

local function buildShipModel(shipDef, cf, parent)
	local model = Instance.new("Model")
	model.Name = shipDef.id
	local rarityDef = Config.Rarities[shipDef.rarity]
	local ghost = shipDef.rarity == 5
	local hullColor = HULL_COLORS[shipDef.rarity]

	local function add(props, offset)
		props.Parent = model
		props.CFrame = cf * offset
		if ghost then
			props.Transparency = 0.45
			if props.Material ~= Enum.Material.Neon then
				props.Material = Enum.Material.Glass
			end
		end
		return makePart(props)
	end

	local hull = add({ Name = "Hull", Size = Vector3.new(5, 2.6, 10), Color = hullColor, Material = Enum.Material.WoodPlanks }, CFrame.new(0, 0.3, 0))
	add({ Size = Vector3.new(3.54, 2.6, 3.54), Color = hullColor, Material = Enum.Material.WoodPlanks },
		CFrame.new(0, 0.3, -5) * CFrame.Angles(0, math.rad(45), 0))
	add({ Size = Vector3.new(4.6, 0.2, 9.6), Color = Color3.fromRGB(170, 130, 85), Material = Enum.Material.WoodPlanks }, CFrame.new(0, 1.65, 0))
	add({ Size = Vector3.new(3.6, 2.2, 3), Color = hullColor, Material = Enum.Material.Wood }, CFrame.new(0, 2.8, 3))
	add({ Size = Vector3.new(4, 0.3, 3.4), Color = rarityDef.color, Material = Enum.Material.Wood }, CFrame.new(0, 4.05, 3))
	add({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(11, 0.5, 0.5), Color = Color3.fromRGB(100, 70, 45), Material = Enum.Material.Wood },
		CFrame.new(0, 7.1, -1) * UPRIGHT)
	add({ Size = Vector3.new(5, 5, 0.25), Color = rarityDef.color, Material = ghost and Enum.Material.Neon or Enum.Material.Fabric },
		CFrame.new(0, 7, -1.35))
	add({ Size = Vector3.new(3.6, 2.4, 0.25), Color = rarityDef.color, Material = ghost and Enum.Material.Neon or Enum.Material.Fabric },
		CFrame.new(0, 10.6, -1.35))
	add({ Size = Vector3.new(0.1, 1, 1.6), Color = rarityDef.color, Material = Enum.Material.Fabric }, CFrame.new(0, 12.2, -0.2))
	if shipDef.rarity == 4 then
		add({ Size = Vector3.new(5.1, 0.4, 10.1), Color = Color3.fromRGB(255, 200, 60), Material = Enum.Material.Metal }, CFrame.new(0, 1, 0))
	end
	local lantern = add({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(0.8, 0.8, 0.8),
		Color = ghost and rarityDef.color or Color3.fromRGB(255, 200, 120),
		Material = Enum.Material.Neon,
	}, CFrame.new(0, 2.3, 4.8))
	local light = Instance.new("PointLight")
	light.Color = ghost and rarityDef.color or Color3.fromRGB(255, 190, 110)
	light.Range = ghost and 20 or 10
	light.Brightness = ghost and 3 or 1.5
	light.Parent = lantern

	if ghost then
		local mist = Instance.new("ParticleEmitter")
		mist.Color = ColorSequence.new(rarityDef.color)
		mist.LightEmission = 1
		mist.Transparency = NumberSequence.new(0.5, 1)
		mist.Rate = 15
		mist.Lifetime = NumberRange.new(2, 3)
		mist.Speed = NumberRange.new(1, 2)
		mist.Size = NumberSequence.new(1.2, 0)
		mist.Parent = hull
	end

	addBillboard(hull, shipDef.name, rarityDef.color, 13, 160, 220)
	model.PrimaryPart = hull
	model.Parent = parent
	return model
end

-- Smoothly move a model between two CFrames (yields)
local function tweenModel(model, fromCF, toCF, duration)
	local alpha = Instance.new("NumberValue")
	local conn = alpha.Changed:Connect(function(a)
		if model.Parent then
			model:PivotTo(fromCF:Lerp(toCF, a))
		end
	end)
	local tween = TweenService:Create(alpha, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut), { Value = 1 })
	tween:Play()
	tween.Completed:Wait()
	conn:Disconnect()
	alpha:Destroy()
end

---------------------------------------------------------------------------
-- BUILD THE WORLD
---------------------------------------------------------------------------
buildLighting()
buildOcean()
buildIsland()
for i = 1, BAY_COUNT do
	buildBay(i)
end

---------------------------------------------------------------------------
-- PLAYER DATA
---------------------------------------------------------------------------
local store
pcall(function()
	store = DataStoreService:GetDataStore("DeepSeaSalvage_v1")
end)

local Sessions = {}
local currentEvent = nil

local function defaultData()
	return {
		coins = 0,
		pearls = 0,
		subs = { { id = Config.StartingSub, depth = 1 } },
		parts = {},
		ships = {},
		pity = 0,
		stats = { hauls = 0, fragments = 0, breaches = 0 },
	}
end

local function reconcile(data)
	local fresh = defaultData()
	for key, value in pairs(fresh) do
		if data[key] == nil then
			data[key] = value
		end
	end
	for key, value in pairs(fresh.stats) do
		if data.stats[key] == nil then
			data.stats[key] = value
		end
	end
	-- drop subs that no longer exist in the config and clamp depths
	local cleaned = {}
	for _, sub in ipairs(data.subs) do
		local def = Config.GetSub(sub.id)
		if def and #cleaned < Config.MaxFleet then
			sub.depth = math.clamp(tonumber(sub.depth) or 1, 1, def.maxDepth)
			table.insert(cleaned, sub)
		end
	end
	if #cleaned == 0 then
		cleaned = { { id = Config.StartingSub, depth = 1 } }
	end
	data.subs = cleaned
	return data
end

local function loadData(player)
	if not store then
		return defaultData(), false
	end
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return store:GetAsync("player_" .. player.UserId)
		end)
		if ok then
			return reconcile(result or defaultData()), true
		end
		warn("[Salvage] Load attempt " .. attempt .. " failed: " .. tostring(result))
		task.wait(1)
	end
	-- Loading failed: play with fresh data but don't save, so we never overwrite real progress
	return defaultData(), false
end

local function saveData(session)
	if not store or not session.canSave then
		return
	end
	local ok, err = pcall(function()
		store:SetAsync("player_" .. session.player.UserId, session.data)
	end)
	if not ok then
		warn("[Salvage] Save failed for " .. session.player.Name .. ": " .. tostring(err))
	end
end

---------------------------------------------------------------------------
-- STATE SYNC
---------------------------------------------------------------------------
local function coinMultiplier(data)
	local mult = 1
	for shipId in pairs(data.ships) do
		local ship = Config.GetShip(shipId)
		if ship then
			mult += ship.bonus
		end
	end
	return mult
end

local function pushState(session)
	if not session.active then
		return
	end
	local subs = {}
	for i, sub in ipairs(session.data.subs) do
		local entry = session.fleet[i]
		subs[i] = {
			id = sub.id,
			depth = sub.depth,
			status = entry and entry.status or "Docked",
			endTime = entry and entry.endTime or 0,
			zone = entry and entry.zone or sub.depth,
		}
	end
	StateUpdate:FireClient(session.player, {
		coins = session.data.coins,
		pearls = session.data.pearls,
		subs = subs,
		parts = session.data.parts,
		ships = session.data.ships,
		multiplier = coinMultiplier(session.data),
		pity = session.data.pity,
	})
end

local function notify(player, payload)
	Notify:FireClient(player, payload)
end

local function announce(text, color)
	Notify:FireAllClients({ kind = "announce", text = text, color = color })
end

---------------------------------------------------------------------------
-- LOOT
---------------------------------------------------------------------------
local function rollRarity(zone, luck)
	local adjusted = {}
	local total = 0
	for i, weight in ipairs(zone.weights) do
		local w = weight
		if i >= 3 then
			w *= luck
		end
		adjusted[i] = w
		total += w
	end
	local roll = rng:NextNumber() * total
	for i, w in ipairs(adjusted) do
		roll -= w
		if roll <= 0 and w > 0 then
			return i
		end
	end
	return 1
end

local function pickPart(data, rarity)
	local ships = Config.ShipsOfRarity(rarity)
	local all, missing = {}, {}
	for _, ship in ipairs(ships) do
		for _, partName in ipairs(ship.parts) do
			local entry = { ship = ship, part = partName }
			table.insert(all, entry)
			if (data.parts[Config.PartKey(ship.id, partName)] or 0) == 0 then
				table.insert(missing, entry)
			end
		end
	end
	local pool = all
	if #missing > 0 and rng:NextNumber() < Config.MissingPartBias then
		pool = missing
	end
	return pool[rng:NextInteger(1, #pool)]
end

local function rollHaul(session, zoneIndex, subDef)
	local zone = Config.Zones[zoneIndex]
	local data = session.data
	local count = (currentEvent == "StormSurge") and 2 or 1
	local fragments = {}
	local best = 1
	for _ = 1, count do
		local rarity = rollRarity(zone, subDef.luck)
		if zone.weights[4] > 0 then
			if rarity >= 4 then
				data.pity = 0
			else
				data.pity += 1
				if data.pity >= Config.PityLimit then
					rarity = 4
					data.pity = 0
				end
			end
		end
		local pick = pickPart(data, rarity)
		table.insert(fragments, { ship = pick.ship.id, part = pick.part, rarity = rarity })
		best = math.max(best, rarity)
	end
	return {
		fragments = fragments,
		coins = math.floor(zone.coins * coinMultiplier(data)),
		best = best,
	}
end

local function checkShipComplete(session, shipId)
	local data = session.data
	if data.ships[shipId] then
		return
	end
	local ship = Config.GetShip(shipId)
	for _, partName in ipairs(ship.parts) do
		if (data.parts[Config.PartKey(shipId, partName)] or 0) == 0 then
			return
		end
	end
	data.ships[shipId] = true
	for slot, def in ipairs(Config.Ships) do
		if def.id == shipId then
			session.shipModels[shipId] = buildShipModel(def, session.bay.shipSlots[slot], session.bay.folder)
		end
	end
	notify(session.player, { kind = "ship", ship = shipId })
	announce(session.player.DisplayName .. " restored " .. ship.name .. "!", Config.Rarities[ship.rarity].color)
end

---------------------------------------------------------------------------
-- FLEET LOOP: dive -> surface -> crate -> collect -> dive again
---------------------------------------------------------------------------
local startDive

local function collectCrate(session, index)
	local entry = session.fleet[index]
	if not entry or entry.status ~= "Haul" or not entry.haul then
		return
	end
	local haul = entry.haul
	entry.haul = nil
	if entry.crate then
		entry.crate:Destroy()
		entry.crate = nil
	end

	local data = session.data
	local total = haul.coins
	data.stats.hauls += 1
	for _, frag in ipairs(haul.fragments) do
		local key = Config.PartKey(frag.ship, frag.part)
		local owned = data.parts[key] or 0
		local isNew = owned == 0
		data.parts[key] = owned + 1
		data.stats.fragments += 1
		local sold = 0
		if not isNew then
			sold = Config.Rarities[frag.rarity].sellValue
			total += sold
		end
		notify(session.player, {
			kind = "loot",
			rarity = frag.rarity,
			ship = frag.ship,
			part = frag.part,
			isNew = isNew,
			sold = sold,
		})
		if frag.rarity == 5 then
			announce(session.player.DisplayName .. " pulled up a GHOST fragment!", Config.Rarities[5].color)
		elseif frag.rarity == 4 and isNew then
			announce(session.player.DisplayName .. " found a Royal fragment!", Config.Rarities[4].color)
		end
		if isNew then
			checkShipComplete(session, frag.ship)
		end
	end
	data.coins += total
	notify(session.player, { kind = "coins", amount = total })
	startDive(session, index)
	pushState(session)
end

local function spawnCrate(session, index)
	local entry = session.fleet[index]
	local berth = session.bay.berths[index]
	local rarityDef = Config.Rarities[entry.haul.best]
	local crate = buildCrate(entry.haul.best, berth.crateCF, session.bay.folder)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Haul Up"
	prompt.ObjectText = session.player.DisplayName .. "'s " .. rarityDef.name .. " Crate"
	prompt.HoldDuration = rarityDef.holdTime
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = crate
	prompt.Triggered:Connect(function(who)
		if who ~= session.player then
			notify(who, { kind = "error", text = "That's not your haul!" })
			return
		end
		collectCrate(session, index)
	end)
	entry.crate = crate
end

local function finishDive(session, index)
	local entry = session.fleet[index]
	local subData = session.data.subs[index]
	local subDef = Config.GetSub(subData.id)
	entry.status = "Surfacing"

	local breach = Config.BreachChance(subDef, entry.zone)
	if currentEvent == "StormSurge" then
		breach += Config.StormExtraBreach
	end
	local breached = rng:NextNumber() < breach
	local haul = not breached and rollHaul(session, entry.zone, subDef) or nil

	task.spawn(function()
		local berth = session.bay.berths[index]
		if entry.model and entry.model.Parent then
			tweenModel(entry.model, entry.model:GetPivot(), berth.subCF, DIVE_ANIM_TIME)
		end
		if not session.active then
			return
		end
		if breached then
			session.data.stats.breaches += 1
			entry.status = "Repairing"
			entry.endTime = now() + Config.RepairTime
			notify(session.player, { kind = "breach", sub = subDef.name, zone = Config.Zones[entry.zone].name })
		else
			entry.haul = haul
			entry.status = "Haul"
			spawnCrate(session, index)
		end
		pushState(session)
	end)
end

startDive = function(session, index)
	local entry = session.fleet[index]
	local subData = session.data.subs[index]
	if not entry or not subData or not session.active then
		return
	end
	local subDef = Config.GetSub(subData.id)
	local zone = Config.Zones[subData.depth]
	entry.zone = subData.depth
	entry.status = "Diving"
	entry.endTime = now() + zone.diveTime * subDef.speed

	local berth = session.bay.berths[index]
	task.spawn(function()
		if entry.model and entry.model.Parent then
			local deepCF = berth.subCF * CFrame.new(0, -30, -22) * CFrame.Angles(math.rad(-25), 0, 0)
			tweenModel(entry.model, berth.subCF, deepCF, DIVE_ANIM_TIME)
		end
	end)
end

local function addFleetEntry(session, index)
	local subData = session.data.subs[index]
	local subDef = Config.GetSub(subData.id)
	local berth = session.bay.berths[index]
	local model = buildSubModel(subDef)
	model:PivotTo(berth.subCF)
	model.Parent = session.bay.folder
	session.fleet[index] = { status = "Docked", endTime = 0, zone = subData.depth, model = model }
	startDive(session, index)
end

local function teleportToBay(session)
	local character = session.player.Character
	if character and session.bay then
		character:PivotTo(session.bay.cf * CFrame.new(0, 4, 6))
	end
end

---------------------------------------------------------------------------
-- PLAYER JOIN / LEAVE
---------------------------------------------------------------------------
local function claimBay(player)
	for _, bay in ipairs(Bays) do
		if not bay.owner then
			bay.owner = player
			for _, label in ipairs(bay.signLabels) do
				label.Text = player.DisplayName .. "'s Salvage Co."
			end
			return bay
		end
	end
	return nil
end

local function releaseBay(bay)
	bay.owner = nil
	for _, label in ipairs(bay.signLabels) do
		label.Text = "Unclaimed Bay"
	end
	for _, berth in ipairs(bay.berths) do
		berth.nameLabel.Text = "Empty Berth"
		berth.statusLabel.Text = ""
	end
end

local function onPlayerAdded(player)
	local bay = claimBay(player)
	if not bay then
		player:Kick("This server's salvage bays are all taken. Please join another server!")
		return
	end
	local session = {
		player = player,
		bay = bay,
		fleet = {},
		shipModels = {},
		active = true,
		loaded = false,
		lastClick = 0,
		krakenHits = 0,
	}
	Sessions[player] = session

	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		task.wait(0.1)
		teleportToBay(session)
	end)
	if player.Character then
		task.spawn(teleportToBay, session)
	end

	local data, canSave = loadData(player)
	if not session.active then
		return -- left while loading
	end
	session.data = data
	session.canSave = canSave
	session.loaded = true

	for i = 1, #data.subs do
		addFleetEntry(session, i)
	end
	for slot, def in ipairs(Config.Ships) do
		if data.ships[def.id] then
			session.shipModels[def.id] = buildShipModel(def, bay.shipSlots[slot], bay.folder)
		end
	end

	pushState(session)
	notify(player, { kind = "welcome", canSave = canSave })
end

local function onPlayerRemoving(player)
	local session = Sessions[player]
	if not session then
		return
	end
	session.active = false
	Sessions[player] = nil
	if session.loaded then
		saveData(session)
	end
	for _, entry in pairs(session.fleet) do
		if entry.model then
			entry.model:Destroy()
		end
		if entry.crate then
			entry.crate:Destroy()
		end
	end
	for _, model in pairs(session.shipModels) do
		model:Destroy()
	end
	releaseBay(session.bay)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end

game:BindToClose(function()
	local pending = 0
	for _, session in pairs(Sessions) do
		if session.loaded then
			pending += 1
			task.spawn(function()
				saveData(session)
				pending -= 1
			end)
		end
	end
	local start = os.clock()
	while pending > 0 and os.clock() - start < 25 do
		task.wait(0.2)
	end
end)

-- Autosave
task.spawn(function()
	while true do
		task.wait(90)
		for _, session in pairs(Sessions) do
			if session.loaded then
				task.spawn(saveData, session)
			end
		end
	end
end)

---------------------------------------------------------------------------
-- CLIENT ACTIONS
---------------------------------------------------------------------------
Action.OnServerEvent:Connect(function(player, action, arg1, arg2)
	local session = Sessions[player]
	if not session or not session.loaded then
		return
	end
	local data = session.data

	if action == "BuySub" and typeof(arg1) == "string" then
		local subDef = Config.GetSub(arg1)
		if not subDef then
			return
		end
		if #data.subs >= Config.MaxFleet then
			notify(player, { kind = "error", text = "Your fleet is full (" .. Config.MaxFleet .. " subs)." })
			return
		end
		local wallet = subDef.currency == "Pearls" and "pearls" or "coins"
		if data[wallet] < subDef.price then
			notify(player, { kind = "error", text = "Not enough " .. subDef.currency .. "!" })
			return
		end
		data[wallet] -= subDef.price
		table.insert(data.subs, { id = subDef.id, depth = subDef.maxDepth })
		addFleetEntry(session, #data.subs)
		notify(player, { kind = "bought", sub = subDef.name })
		pushState(session)
	elseif action == "SetDepth" and typeof(arg1) == "number" and typeof(arg2) == "number" then
		local subData = data.subs[math.floor(arg1)]
		if not subData then
			return
		end
		local subDef = Config.GetSub(subData.id)
		local depth = math.floor(arg2)
		if depth >= 1 and depth <= subDef.maxDepth then
			subData.depth = depth
			pushState(session)
		end
	elseif action == "GoToBay" then
		teleportToBay(session)
	elseif action == "RequestState" then
		pushState(session)
	end
end)

---------------------------------------------------------------------------
-- EVENTS
---------------------------------------------------------------------------
local EventHandlers = {}

-- STORM SURGE: dark sky, lightning, double fragments, more breaches
EventHandlers.StormSurge = function(ctx)
	local atmosphere = Lighting:FindFirstChild("SalvageAtmosphere")
	local cc = Lighting:FindFirstChild("SalvageColor")
	local clouds = workspace.Terrain:FindFirstChild("SalvageClouds")
	ctx.saved = {
		brightness = Lighting.Brightness,
		outdoor = Lighting.OutdoorAmbient,
		density = atmosphere.Density,
		atmoColor = atmosphere.Color,
		tint = cc.TintColor,
		saturation = cc.Saturation,
		cover = clouds.Cover,
		cloudColor = clouds.Color,
		wave = workspace.Terrain.WaterWaveSize,
	}
	local info = TweenInfo.new(4)
	TweenService:Create(Lighting, info, { Brightness = 0.8, OutdoorAmbient = Color3.fromRGB(70, 80, 100) }):Play()
	TweenService:Create(atmosphere, info, { Density = 0.55, Color = Color3.fromRGB(120, 130, 150) }):Play()
	TweenService:Create(cc, info, { TintColor = Color3.fromRGB(185, 195, 225), Saturation = -0.2 }):Play()
	TweenService:Create(clouds, info, { Cover = 0.95, Color = Color3.fromRGB(90, 95, 110) }):Play()
	workspace.Terrain.WaterWaveSize = 0.6

	task.spawn(function()
		while not ctx.finished do
			task.wait(rng:NextNumber(3, 8))
			if ctx.finished then
				break
			end
			local before = Lighting.Brightness
			Lighting.Brightness = 6
			task.wait(0.08)
			Lighting.Brightness = before
			task.wait(0.12)
			Lighting.Brightness = 4
			task.wait(0.06)
			Lighting.Brightness = before
		end
	end)

	return function()
		local s = ctx.saved
		TweenService:Create(Lighting, info, { Brightness = s.brightness, OutdoorAmbient = s.outdoor }):Play()
		TweenService:Create(atmosphere, info, { Density = s.density, Color = s.atmoColor }):Play()
		TweenService:Create(cc, info, { TintColor = s.tint, Saturation = s.saturation }):Play()
		TweenService:Create(clouds, info, { Cover = s.cover, Color = s.cloudColor }):Play()
		workspace.Terrain.WaterWaveSize = s.wave
	end
end

-- TREASURE TIDE: floating golden chests around the island
EventHandlers.TreasureTide = function(ctx)
	local folder = Instance.new("Folder")
	folder.Name = "TreasureTide"
	folder.Parent = World
	for _ = 1, Config.TreasureChests do
		local bayAngle = rng:NextInteger(0, BAY_COUNT - 1) * (360 / BAY_COUNT)
		local angle = math.rad(bayAngle + rng:NextNumber(12, 48))
		local pos = polar(rng:NextNumber(78, 135), angle, 0.8)
		local chest = makePart({
			Name = "TreasureChest",
			Size = Vector3.new(3, 2, 2),
			CFrame = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0),
			Color = Color3.fromRGB(255, 195, 50),
			Material = Enum.Material.Metal,
			Parent = folder,
		})
		local lid = makePart({
			Size = Vector3.new(3.1, 0.6, 2.1),
			CFrame = chest.CFrame * CFrame.new(0, 1.2, 0),
			Color = Color3.fromRGB(120, 70, 30),
			Material = Enum.Material.Wood,
			Parent = chest,
		})
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = chest
		weld.Part1 = lid
		weld.Parent = lid
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 210, 80)
		light.Range = 14
		light.Brightness = 2
		light.Parent = chest
		local sparkles = Instance.new("ParticleEmitter")
		sparkles.Color = ColorSequence.new(Color3.fromRGB(255, 220, 90))
		sparkles.LightEmission = 1
		sparkles.Rate = 12
		sparkles.Speed = NumberRange.new(2, 4)
		sparkles.Parent = chest

		local prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Open"
		prompt.ObjectText = "Treasure Chest"
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 12
		prompt.RequiresLineOfSight = false
		prompt.Parent = chest
		prompt.Triggered:Connect(function(who)
			local session = Sessions[who]
			if not session or not session.loaded or chest:GetAttribute("Claimed") then
				return
			end
			chest:SetAttribute("Claimed", true)
			session.data.pearls += Config.TreasureChestPearls
			session.data.coins += Config.TreasureChestCoins
			notify(who, { kind = "chest", pearls = Config.TreasureChestPearls, coins = Config.TreasureChestCoins })
			pushState(session)
			chest:Destroy()
		end)
	end
	return function()
		folder:Destroy()
	end
end

-- KRAKEN ATTACK: co-op boss, click the tentacles
local function buildTentacle(baseCF, parent)
	local model = Instance.new("Model")
	model.Name = "Tentacle"
	local root = makePart({
		Name = "Root",
		Size = Vector3.new(1, 1, 1),
		Transparency = 1,
		CanCollide = false,
		CFrame = baseCF,
		Parent = model,
	})
	model.PrimaryPart = root
	local y = 0
	for s = 1, 9 do
		local radius = 5.5 - s * 0.5
		local height = 4
		local bend = math.sin(s * 0.5) * s * 0.35
		local seg = makePart({
			Shape = Enum.PartType.Cylinder,
			Size = Vector3.new(height + 0.6, radius, radius),
			CFrame = baseCF * CFrame.new(bend, y + height / 2, 0) * CFrame.Angles(0, 0, math.rad(90 + s * 3)),
			Color = Color3.fromRGB(120, 40, 140),
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			Parent = model,
		})
		seg.Name = "Segment"
		if s % 2 == 0 then
			makePart({
				Shape = Enum.PartType.Ball,
				Size = Vector3.new(radius * 0.35, radius * 0.35, radius * 0.35),
				CFrame = baseCF * CFrame.new(bend, y + height / 2, -radius * 0.45),
				Color = Color3.fromRGB(255, 150, 190),
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				Parent = model,
			})
		end
		y += height
	end
	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 60, 60)
	highlight.FillTransparency = 0.3
	highlight.OutlineTransparency = 1
	highlight.Enabled = false
	highlight.Parent = model
	local click = Instance.new("ClickDetector")
	click.MaxActivationDistance = 250
	click.Parent = model
	model.Parent = parent
	return model, click, highlight
end

EventHandlers.Kraken = function(ctx)
	local folder = Instance.new("Folder")
	folder.Name = "Kraken"
	folder.Parent = World

	local maxHP = Config.KrakenBaseHP + Config.KrakenHPPerPlayer * #Players:GetPlayers()
	local hp = maxHP
	remotes:SetAttribute("KrakenMax", maxHP)
	remotes:SetAttribute("KrakenHP", hp)
	for _, session in pairs(Sessions) do
		session.krakenHits = 0
	end

	local tentacles = {}
	local startTime = os.clock()
	for k = 0, BAY_COUNT - 1 do
		local angle = math.rad(k * (360 / BAY_COUNT) + 30)
		local base = CFrame.lookAt(polar(112, angle, -38), polar(0, 0, -38))
		local model, click, highlight = buildTentacle(base, folder)
		local t = { model = model, base = base, phase = k * 1.3 }
		table.insert(tentacles, t)
		click.MouseClick:Connect(function(who)
			local session = Sessions[who]
			if not session or ctx.finished or hp <= 0 then
				return
			end
			if os.clock() - session.lastClick < 0.12 then
				return
			end
			session.lastClick = os.clock()
			session.krakenHits += 1
			hp -= 1
			remotes:SetAttribute("KrakenHP", math.max(hp, 0))
			highlight.Enabled = true
			task.delay(0.08, function()
				highlight.Enabled = false
			end)
			if hp <= 0 then
				ctx.defeated = true
				ctx.done = true
			end
		end)
	end

	-- rise, sway, and sink
	local sinkStart
	local conn = RunService.Heartbeat:Connect(function()
		local t = os.clock()
		local rise = math.clamp((t - startTime) / 3, 0, 1) * 32
		if sinkStart then
			rise *= 1 - math.clamp((t - sinkStart) / 2, 0, 1)
		end
		for _, tentacle in ipairs(tentacles) do
			local sway = CFrame.Angles(math.sin(t * 1.4 + tentacle.phase) * 0.18, 0, math.cos(t * 1.1 + tentacle.phase) * 0.18)
			tentacle.model:PivotTo(CFrame.new(0, rise, 0) * tentacle.base * sway)
		end
	end)

	return function()
		sinkStart = os.clock()
		if ctx.defeated then
			for _, session in pairs(Sessions) do
				if session.loaded and session.krakenHits > 0 then
					local coins = math.min(300 + session.krakenHits * 40, 3000)
					local pearls = Config.KrakenPearls + (session.krakenHits >= 25 and 2 or 0)
					session.data.coins += coins
					session.data.pearls += pearls
					notify(session.player, { kind = "kraken", coins = coins, pearls = pearls, hits = session.krakenHits })
					pushState(session)
				end
			end
			announce("The Kraken has been driven back to the deep!", Color3.fromRGB(255, 150, 190))
		else
			announce("The Kraken slipped away... it'll be back.", Color3.fromRGB(200, 120, 220))
		end
		task.delay(2.2, function()
			conn:Disconnect()
			folder:Destroy()
		end)
		remotes:SetAttribute("KrakenHP", 0)
		remotes:SetAttribute("KrakenMax", 0)
	end
end

local eventOrder = { "StormSurge", "TreasureTide", "Kraken" }

local function runEvent(id)
	local def = Config.Events[id]
	local ctx = { done = false, finished = false }
	local endTime = now() + Config.EventDuration
	currentEvent = id
	remotes:SetAttribute("EventId", id)
	remotes:SetAttribute("EventEnd", endTime)
	announce(def.name .. "! " .. def.desc, Color3.fromRGB(255, 220, 90))

	local cleanup = EventHandlers[id](ctx)
	while now() < endTime and not ctx.done do
		task.wait(0.25)
	end
	ctx.finished = true
	cleanup()

	currentEvent = nil
	remotes:SetAttribute("EventId", "")
	remotes:SetAttribute("EventEnd", 0)
end

task.spawn(function()
	while true do
		task.wait(Config.EventInterval)
		if #Players:GetPlayers() > 0 then
			runEvent(eventOrder[rng:NextInteger(1, #eventOrder)])
		end
	end
end)

---------------------------------------------------------------------------
-- MAIN LOOPS
---------------------------------------------------------------------------
-- Rotating lighthouse beam
RunService.Heartbeat:Connect(function()
	if lighthouseLamp then
		local pos = lighthouseLamp.Position
		lighthouseLamp.CFrame = CFrame.new(pos) * CFrame.Angles(0, os.clock() * 0.8, 0) * CFrame.Angles(math.rad(-8), 0, 0)
	end
end)

local function statusText(entry)
	local t = math.max(0, math.ceil(entry.endTime - now()))
	if entry.status == "Diving" then
		return "Diving... " .. t .. "s", Color3.fromRGB(140, 220, 255)
	elseif entry.status == "Surfacing" then
		return "Surfacing!", Color3.fromRGB(140, 255, 200)
	elseif entry.status == "Haul" then
		return "HAUL READY!", Color3.fromRGB(255, 220, 90)
	elseif entry.status == "Repairing" then
		return "Repairing hull " .. t .. "s", Color3.fromRGB(255, 110, 110)
	end
	return "", Color3.new(1, 1, 1)
end

while true do
	task.wait(0.25)
	local t = now()
	for _, session in pairs(Sessions) do
		if session.loaded and session.active then
			for i, entry in pairs(session.fleet) do
				if entry.status == "Diving" and t >= entry.endTime then
					finishDive(session, i)
				elseif entry.status == "Repairing" and t >= entry.endTime then
					startDive(session, i)
					pushState(session)
				end
				local berth = session.bay.berths[i]
				local subDef = Config.GetSub(session.data.subs[i].id)
				local nameText = subDef.name .. "  |  " .. Config.Zones[entry.zone].name
				if berth.nameLabel.Text ~= nameText then
					berth.nameLabel.Text = nameText
				end
				local text, color = statusText(entry)
				if berth.statusLabel.Text ~= text then
					berth.statusLabel.Text = text
					berth.statusLabel.TextColor3 = color
				end
			end
		end
	end
end
