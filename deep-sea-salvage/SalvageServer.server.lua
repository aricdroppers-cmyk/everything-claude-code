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
local CollectionService = game:GetService("CollectionService")
local MarketplaceService = game:GetService("MarketplaceService")

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
		Vector3.new(38, 3.6, 10), Vector3.new(-40, 3.6, 18),
		Vector3.new(-48, 3.6, 30), Vector3.new(20, 3.6, -48), Vector3.new(-45, 3.6, -8),
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

local function freshSeason()
	return { id = Config.Season.id, xp = 0, prestige = 0, premium = false, mystic = false, claimed = {} }
end

local function defaultData()
	return {
		coins = 0,
		pearls = 0,
		subs = { { id = Config.StartingSub, depth = 1 } },
		parts = {},
		ships = {},
		pity = 0,
		stats = { hauls = 0, fragments = 0, breaches = 0, hatched = 0, trades = 0, kills = 0, levelsGained = 0 },
		level = 1,
		bestLevel = 1,
		xp = 0,
		eggs = {},
		pets = {}, -- array of { uid = number, id = petId }
		equipped = {}, -- array of pet uids
		nextPetUid = 1,
		autoSell = true, -- auto-sell spare fragments (turn off to keep them for trading)
		rebirths = 0,
		weapons = { Config.StartingWeapon },
		weapon = Config.StartingWeapon,
		quests = { daily = { key = -1, list = {} }, weekly = { key = -1, list = {} } },
		season = freshSeason(),
		boosts = {}, -- [coins|luck|xp] = os.time() when it runs out
		receipts = {}, -- developer product purchases already granted
		receiptOrder = {},
		testPasses = {}, -- passes "bought" in Studio test mode
		charms = {}, -- [charmId] = how many you own
		equippedCharms = {}, -- charm ids
		login = { claimedDay = -1, streak = 0, best = 0 }, -- daily login streak
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
	data.bestLevel = math.max(data.bestLevel, data.level)
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

	-- drop pets/eggs that no longer exist, and equipped uids that aren't owned
	-- (season rewards can push you past MaxPets, so we never delete pets for that)
	local pets, owned = {}, {}
	for _, pet in ipairs(data.pets) do
		if Config.GetPet(pet.id) then
			table.insert(pets, pet)
			owned[pet.uid] = true
			data.nextPetUid = math.max(data.nextPetUid, pet.uid + 1)
		end
	end
	data.pets = pets
	local equipped = {}
	for _, uid in ipairs(data.equipped) do
		if owned[uid] and #equipped < Config.MaxEquipped + 2 then
			table.insert(equipped, uid)
		end
	end
	data.equipped = equipped
	for eggId in pairs(data.eggs) do
		if not Config.GetEgg(eggId) then
			data.eggs[eggId] = nil
		end
	end

	-- charms
	for id, count in pairs(data.charms) do
		if not Config.GetCharm(id) or type(count) ~= "number" or count < 1 then
			data.charms[id] = nil
		end
	end
	local charmsOn = {}
	for _, id in ipairs(data.equippedCharms) do
		if data.charms[id] and not table.find(charmsOn, id) and #charmsOn < Config.CharmSlots + 1 then
			table.insert(charmsOn, id)
		end
	end
	data.equippedCharms = charmsOn

	-- weapons
	local weapons = {}
	for _, id in ipairs(data.weapons) do
		if Config.GetWeapon(id) and not table.find(weapons, id) then
			table.insert(weapons, id)
		end
	end
	if not table.find(weapons, Config.StartingWeapon) then
		table.insert(weapons, 1, Config.StartingWeapon)
	end
	data.weapons = weapons
	if not table.find(weapons, data.weapon) then
		data.weapon = Config.StartingWeapon
	end

	-- a new season id (an update) resets season progress and the season passes
	if type(data.season) ~= "table" or data.season.id ~= Config.Season.id then
		data.season = freshSeason()
	end
	for key, value in pairs(freshSeason()) do
		if data.season[key] == nil then
			data.season[key] = value
		end
	end
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
		return false
	end
	local ok, err = pcall(function()
		store:SetAsync("player_" .. session.player.UserId, session.data)
	end)
	if not ok then
		warn("[Salvage] Save failed for " .. session.player.Name .. ": " .. tostring(err))
	end
	return ok
end

---------------------------------------------------------------------------
-- STATE SYNC + MULTIPLIERS
---------------------------------------------------------------------------
local function findPet(data, uid)
	for i, pet in ipairs(data.pets) do
		if pet.uid == uid then
			return pet, i
		end
	end
	return nil
end

local function isEquipped(data, uid)
	return table.find(data.equipped, uid) ~= nil
end

local function equippedPetIds(data)
	local ids = {}
	for _, uid in ipairs(data.equipped) do
		local pet = findPet(data, uid)
		if pet then
			table.insert(ids, pet.id)
		end
	end
	return ids
end

local function petBonus(data)
	return Config.PetBonusTotals(equippedPetIds(data))
end

local function hasPass(session, key)
	return session.passes ~= nil and session.passes[key] == true
end

local function boostActive(data, which)
	return (data.boosts[which] or 0) > os.time()
end

local function maxEquipped(session)
	return Config.MaxEquipped + (hasPass(session, "PetSlots") and 2 or 0)
end

local function charmSlots(session)
	return Config.CharmSlots + (hasPass(session, "VIP") and 1 or 0)
end

-- Every bonus in the game, combined in one place
local function getMultipliers(session)
	local data = session.data
	local pets = petBonus(data)
	local charms = Config.CharmBonusTotals(data.equippedCharms)
	local rebirth = Config.RebirthTotals(data.rebirths)

	local coins = 1 + pets.coins + charms.coins + rebirth.coins
	for shipId in pairs(data.ships) do
		local ship = Config.GetShip(shipId)
		if ship then
			coins += ship.bonus
		end
	end
	if hasPass(session, "DoubleCoins") then
		coins *= 2
	end
	if hasPass(session, "VIP") then
		coins *= 1.1
	end
	if boostActive(data, "coins") then
		coins *= Config.BoostMultiplier
	end

	local luck = 1 + pets.luck + charms.luck + rebirth.luck
	if hasPass(session, "LuckyDiver") then
		luck *= 1.5
	end
	if boostActive(data, "luck") then
		luck *= Config.BoostMultiplier
	end

	local xp = 1 + pets.xp + charms.xp + rebirth.xp
	if hasPass(session, "VIP") then
		xp *= 1.2
	end
	if boostActive(data, "xp") then
		xp *= Config.BoostMultiplier
	end

	return {
		coins = coins,
		luck = luck,
		xp = xp,
		hull = pets.hull + charms.hull,
		damage = 1 + rebirth.damage + charms.damage,
		maxHealth = Config.PlayerBaseHealth + data.level * Config.HealthPerLevel + rebirth.health,
	}
end

local function coinMultiplier(session)
	return getMultipliers(session).coins
end

-- Things other players can see: level over your head, pets that follow you
local function updatePublicInfo(session)
	local player = session.player
	local data = session.data
	player:SetAttribute("Level", data.level)
	player:SetAttribute("Rebirths", data.rebirths)
	player:SetAttribute("EquippedPets", table.concat(equippedPetIds(data), ","))
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats then
		leaderstats.Level.Value = data.level
		leaderstats.Rebirths.Value = data.rebirths
		local ships = 0
		for _ in pairs(data.ships) do
			ships += 1
		end
		leaderstats.Ships.Value = ships
	end
	local character = player.Character
	local head = character and character:FindFirstChild("Head")
	if head then
		local tag = head:FindFirstChild("LevelTag")
		if not tag then
			local _
			_, tag = addBillboard(head, "", Color3.fromRGB(90, 255, 230), 2.2, 80, 160)
			tag.Name = "LevelTag"
			tag.Size = UDim2.new(0, 160, 0, 26)
		end
		local label = tag:FindFirstChildOfClass("TextLabel")
		local text = "Lv " .. data.level
		if data.rebirths > 0 then
			text = "R" .. data.rebirths .. "  " .. text
		end
		if hasPass(session, "VIP") then
			text = "[VIP] " .. text
			label.TextColor3 = Color3.fromRGB(255, 205, 80)
		end
		label.Text = text
	end
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		local maxHealth = getMultipliers(session).maxHealth
		if humanoid.MaxHealth ~= maxHealth then
			local ratio = humanoid.MaxHealth > 0 and humanoid.Health / humanoid.MaxHealth or 1
			humanoid.MaxHealth = maxHealth
			humanoid.Health = maxHealth * ratio
		end
	end
end

local function questList(scope)
	local list = {}
	for i, q in ipairs(scope.list) do
		list[i] = { id = q.id, progress = q.progress, claimed = q.claimed, level = q.level }
	end
	return list
end

local LivePrices = {} -- [key] = the real Robux price from Roblox (filled at startup)

local function today()
	return math.floor(os.time() / 86400)
end

local function loginStatus(data)
	local login = data.login
	local day = today()
	local canClaim = login.claimedDay ~= day
	local streak = login.streak
	if canClaim then
		streak = (login.claimedDay == day - 1) and login.streak + 1 or 1
	end
	return { canClaim = canClaim, streak = streak, best = login.best, nextIn = 86400 - os.time() % 86400 }
end

local function pushState(session)
	if not session.active then
		return
	end
	local data = session.data
	local subs = {}
	for i, sub in ipairs(data.subs) do
		local entry = session.fleet[i]
		subs[i] = {
			id = sub.id,
			depth = sub.depth,
			status = entry and entry.status or "Docked",
			endTime = entry and entry.endTime or 0,
			zone = entry and entry.zone or sub.depth,
		}
	end
	local boostsLeft = {}
	for which, expires in pairs(data.boosts) do
		local left = expires - os.time()
		if left > 0 then
			boostsLeft[which] = left
		end
	end
	local mult = getMultipliers(session)
	StateUpdate:FireClient(session.player, {
		coins = data.coins,
		pearls = data.pearls,
		subs = subs,
		parts = data.parts,
		ships = data.ships,
		multiplier = mult.coins,
		multipliers = mult,
		pity = data.pity,
		hauls = data.stats.hauls,
		level = data.level,
		bestLevel = data.bestLevel,
		xp = data.xp,
		xpNeeded = Config.XPToNext(data.level),
		eggs = data.eggs,
		pets = data.pets,
		equipped = data.equipped,
		maxEquipped = maxEquipped(session),
		charms = data.charms,
		equippedCharms = data.equippedCharms,
		charmSlots = charmSlots(session),
		autoSell = data.autoSell,
		petBonus = petBonus(data),
		rebirths = data.rebirths,
		weapons = data.weapons,
		weapon = data.weapon,
		dailyQuests = questList(data.quests.daily),
		weeklyQuests = questList(data.quests.weekly),
		dailyResetIn = 86400 - (os.time() % 86400),
		weeklyResetIn = 604800 - ((os.time() + 3 * 86400) % 604800),
		season = data.season,
		boostsLeft = boostsLeft,
		passes = session.passes or {},
		login = loginStatus(data),
		prices = LivePrices,
		serverTime = os.time(),
		studio = RunService:IsStudio(),
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
	local luck = subDef.luck * getMultipliers(session).luck
	for _ = 1, count do
		local rarity = rollRarity(zone, luck)
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
	local egg = nil
	if rng:NextNumber() < Config.EggChance then
		local eggDef = Config.EggForZone(zoneIndex)
		egg = eggDef and eggDef.id
	end
	return {
		fragments = fragments,
		coins = math.floor(zone.coins * coinMultiplier(session)),
		best = best,
		egg = egg,
		zone = zoneIndex,
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
	updatePublicInfo(session)
	notify(session.player, { kind = "ship", ship = shipId })
	announce(session.player.DisplayName .. " restored " .. ship.name .. "!", Config.Rarities[ship.rarity].color)
end

---------------------------------------------------------------------------
-- FLEET LOOP: dive -> surface -> crate -> collect -> dive again
---------------------------------------------------------------------------
local startDive

-- defined further down
local questProgress, addSeasonXP, giveWeaponTool, giveRandomCharm, isNear, writeLeaderboards

local function addXP(session, amount, raw)
	local data = session.data
	data.xp += math.floor(amount * (raw and 1 or getMultipliers(session).xp))
	local leveled = false
	while data.level < Config.MaxLevel and data.xp >= Config.XPToNext(data.level) do
		data.xp -= Config.XPToNext(data.level)
		data.level += 1
		data.stats.levelsGained += 1
		leveled = true
		local firstTime = data.level > data.bestLevel
		data.bestLevel = math.max(data.bestLevel, data.level)
		notify(session.player, {
			kind = "levelup",
			level = data.level,
			tradeUnlocked = firstTime and data.level == Config.TradeUnlockLevel,
		})
	end
	if leveled then
		updatePublicInfo(session)
	end
end

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
	local xp = Config.Zones[haul.zone].xp
	data.stats.hauls += 1
	for _, frag in ipairs(haul.fragments) do
		local key = Config.PartKey(frag.ship, frag.part)
		local owned = data.parts[key] or 0
		local isNew = owned == 0
		local sold = 0
		xp += Config.FragmentXP[frag.rarity] + (isNew and Config.NewFragmentXP or 0)
		data.stats.fragments += 1
		questProgress(session, "fragments", 1)
		if isNew then
			questProgress(session, "newFragments", 1)
		end
		if isNew or not data.autoSell then
			-- keep it (first copy restores ships, extra copies are spares for trading)
			data.parts[key] = owned + 1
		else
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
	if haul.egg then
		data.eggs[haul.egg] = (data.eggs[haul.egg] or 0) + 1
		notify(session.player, { kind = "egg", egg = haul.egg })
	end
	if rng:NextNumber() < Config.CharmChanceHaul then
		giveRandomCharm(session)
	end
	data.coins += total
	notify(session.player, { kind = "coins", amount = total })
	questProgress(session, "hauls", 1)
	if haul.zone >= 3 then
		questProgress(session, "deepDives", 1)
	end
	addSeasonXP(session, Config.Season.xpPerHaul)
	addXP(session, xp)
	startDive(session, index)
	pushState(session)
end

local function spawnCrate(session, index)
	local entry = session.fleet[index]
	local berth = session.bay.berths[index]
	local rarityDef = Config.Rarities[entry.haul.best]
	local crate = buildCrate(entry.haul.best, berth.crateCF, session.bay.folder)
	if entry.haul.egg then
		local eggDef = Config.GetEgg(entry.haul.egg)
		local egg = makePart({
			Name = "Egg",
			Size = Vector3.new(1.4, 1.8, 1.4),
			CFrame = crate.CFrame * CFrame.new(0, 2.4, 0),
			Color = eggDef.color,
			Material = Enum.Material.SmoothPlastic,
			CanCollide = false,
			Parent = crate,
		})
		local mesh = Instance.new("SpecialMesh")
		mesh.MeshType = Enum.MeshType.Sphere
		mesh.Parent = egg
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = crate
		weld.Part1 = egg
		weld.Parent = egg
		local glow = Instance.new("PointLight")
		glow.Color = eggDef.spots
		glow.Range = 8
		glow.Parent = egg
	end
	local prompt = Instance.new("ProximityPrompt")
	crate:SetAttribute("Owner", session.player.UserId)
	CollectionService:AddTag(crate, "SalvageCrate") -- the client draws a guide line to it for new players
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
		if session.fleet[index] == entry and isNear(who, crate, 12) then
			collectCrate(session, index)
		end
	end)
	entry.crate = crate
	if hasPass(session, "AutoHaul") then
		task.delay(1.5, function()
			if session.active and session.fleet[index] == entry then
				collectCrate(session, index)
			end
		end)
	end
end

local function finishDive(session, index)
	local entry = session.fleet[index]
	local subData = session.data.subs[index]
	local subDef = Config.GetSub(subData.id)
	entry.status = "Surfacing"

	local breach = math.max(0, Config.BreachChance(subDef, entry.zone) - getMultipliers(session).hull)
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
		if not session.active or session.fleet[index] ~= entry then
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

-- Every server teleport goes through here so the anti-cheat doesn't flag it
local function safeTeleport(session, cf)
	local character = session.player.Character
	if character then
		session.acGraceUntil = os.clock() + 2
		session.acLast = nil
		character:PivotTo(cf)
	end
end

local function teleportToBay(session)
	if session.bay then
		safeTeleport(session, session.bay.cf * CFrame.new(0, 4, 6))
	end
end

---------------------------------------------------------------------------
-- PETS
---------------------------------------------------------------------------
local function rollPet(eggId)
	local pool = Config.PetsInEgg(eggId)
	local total = 0
	for _, pet in ipairs(pool) do
		total += pet.weight
	end
	local roll = rng:NextNumber() * total
	for _, pet in ipairs(pool) do
		roll -= pet.weight
		if roll <= 0 then
			return pet
		end
	end
	return pool[#pool]
end

local function givePet(data, petId)
	local uid = data.nextPetUid
	data.nextPetUid += 1
	table.insert(data.pets, { uid = uid, id = petId })
	return uid
end

local function hatchEgg(session, eggId)
	local data = session.data
	local eggDef = Config.GetEgg(eggId)
	if not eggDef or (data.eggs[eggId] or 0) < 1 then
		return
	end
	if #data.pets >= Config.MaxPets then
		notify(session.player, { kind = "error", text = "Your pet tank is full (" .. Config.MaxPets .. "). Release a pet first." })
		return
	end
	local wallet = eggDef.currency == "Pearls" and "pearls" or "coins"
	if data[wallet] < eggDef.cost then
		notify(session.player, { kind = "error", text = "Hatching this egg costs " .. Config.FormatNumber(eggDef.cost) .. " " .. eggDef.currency .. "." })
		return
	end
	data[wallet] -= eggDef.cost
	data.eggs[eggId] -= 1
	if data.eggs[eggId] <= 0 then
		data.eggs[eggId] = nil
	end
	local pet = rollPet(eggId)
	local uid = givePet(data, pet.id)
	data.stats.hatched += 1
	questProgress(session, "hatches", 1)
	-- auto-equip into a free slot
	if #data.equipped < maxEquipped(session) then
		table.insert(data.equipped, uid)
	end
	notify(session.player, { kind = "hatch", egg = eggId, pet = pet.id })
	if pet.rarity >= 4 then
		announce(session.player.DisplayName .. " hatched a " .. Config.PetRarities[pet.rarity].name .. " " .. pet.name .. "!",
			Config.PetRarities[pet.rarity].color)
	end
	updatePublicInfo(session)
	pushState(session)
end

local function toggleEquip(session, uid)
	local data = session.data
	if not findPet(data, uid) then
		return
	end
	local index = table.find(data.equipped, uid)
	if index then
		table.remove(data.equipped, index)
	elseif #data.equipped < maxEquipped(session) then
		table.insert(data.equipped, uid)
	else
		notify(session.player, { kind = "error", text = "You can only equip " .. maxEquipped(session) .. " pets." })
		return
	end
	updatePublicInfo(session)
	pushState(session)
end

local function equipBest(session)
	local data = session.data
	local sorted = table.clone(data.pets)
	table.sort(sorted, function(a, b)
		return Config.PetScore(a.id) > Config.PetScore(b.id)
	end)
	data.equipped = {}
	for i = 1, math.min(maxEquipped(session), #sorted) do
		table.insert(data.equipped, sorted[i].uid)
	end
	updatePublicInfo(session)
	pushState(session)
end

local Trades = {} -- [player] = trade (both players point at the same table)

local function releasePet(session, uid)
	local data = session.data
	local pet, index = findPet(data, uid)
	if not pet then
		return
	end
	if Trades[session.player] then
		notify(session.player, { kind = "error", text = "Finish your trade before releasing pets." })
		return
	end
	local equippedIndex = table.find(data.equipped, uid)
	if equippedIndex then
		table.remove(data.equipped, equippedIndex)
	end
	table.remove(data.pets, index)
	local def = Config.GetPet(pet.id)
	local value = Config.PetRarities[def.rarity].releaseValue
	data.coins += value
	notify(session.player, { kind = "released", pet = pet.id, coins = value })
	updatePublicInfo(session)
	pushState(session)
end

local function sellSpares(session)
	local data = session.data
	if Trades[session.player] then
		notify(session.player, { kind = "error", text = "Finish your trade before selling spares." })
		return
	end
	local total, count = 0, 0
	for key, owned in pairs(data.parts) do
		if owned > 1 then
			local _, ship = Config.IsValidPartKey(key)
			if ship then
				total += (owned - 1) * Config.Rarities[ship.rarity].sellValue
				count += owned - 1
				data.parts[key] = 1
			end
		end
	end
	data.coins += total
	notify(session.player, { kind = "soldSpares", count = count, coins = total })
	pushState(session)
end

---------------------------------------------------------------------------
-- TRADING
-- Flow: request -> accept -> both add items -> both Ready -> both Confirm.
-- Any change to either offer resets Ready/Confirm for both players.
---------------------------------------------------------------------------
local TradeRequests = {} -- [target player] = { from = player, expires = time }

local function emptyOffer()
	return { parts = {}, pets = {}, eggs = {} }
end

local function canTrade(session)
	return session and session.loaded and session.data.bestLevel >= Config.TradeUnlockLevel
end

local function offerItems(session, offer)
	local items = {}
	for key, amount in pairs(offer.parts) do
		table.insert(items, { kind = "part", id = key, amount = amount })
	end
	for uid in pairs(offer.pets) do
		local pet = findPet(session.data, uid)
		if pet then
			table.insert(items, { kind = "pet", id = uid, petId = pet.id, amount = 1 })
		end
	end
	for eggId, amount in pairs(offer.eggs) do
		table.insert(items, { kind = "egg", id = eggId, amount = amount })
	end
	return items
end

local function sendTradeState(trade)
	for _, me in ipairs(trade.players) do
		local them = trade.players[1] == me and trade.players[2] or trade.players[1]
		local mySession, theirSession = Sessions[me], Sessions[them]
		if mySession and theirSession then
			notify(me, {
				kind = "trade",
				partner = them.DisplayName,
				mine = offerItems(mySession, trade.offers[me]),
				theirs = offerItems(theirSession, trade.offers[them]),
				myReady = trade.ready[me] == true,
				theirReady = trade.ready[them] == true,
				myConfirm = trade.confirmed[me] == true,
				theirConfirm = trade.confirmed[them] == true,
			})
		end
	end
end

local function endTrade(trade, message, color)
	for _, p in ipairs(trade.players) do
		if Trades[p] == trade then
			Trades[p] = nil
		end
		if p.Parent then
			notify(p, { kind = "tradeEnded", text = message, color = color })
		end
	end
end

local function resetReady(trade)
	trade.ready = {}
	trade.confirmed = {}
end

-- How many of this item the player could still add to their offer
local function availableToOffer(session, offer, kind, id)
	local data = session.data
	if kind == "part" then
		return math.max(0, (data.parts[id] or 0) - 1 - (offer.parts[id] or 0))
	elseif kind == "egg" then
		return math.max(0, (data.eggs[id] or 0) - (offer.eggs[id] or 0))
	elseif kind == "pet" then
		if findPet(data, id) and not isEquipped(data, id) and not offer.pets[id] then
			return 1
		end
	end
	return 0
end

local function offerStillValid(session, offer)
	local data = session.data
	for key, amount in pairs(offer.parts) do
		if (data.parts[key] or 0) - 1 < amount then
			return false
		end
	end
	for eggId, amount in pairs(offer.eggs) do
		if (data.eggs[eggId] or 0) < amount then
			return false
		end
	end
	for uid in pairs(offer.pets) do
		if not findPet(data, uid) or isEquipped(data, uid) then
			return false
		end
	end
	return true
end

local function countKeys(t)
	local n = 0
	for _ in pairs(t) do
		n += 1
	end
	return n
end

local function executeTrade(trade)
	local a, b = trade.players[1], trade.players[2]
	local sa, sb = Sessions[a], Sessions[b]
	if not sa or not sb then
		endTrade(trade, "Trade cancelled.", Color3.fromRGB(255, 95, 95))
		return
	end
	local oa, ob = trade.offers[a], trade.offers[b]
	if not offerStillValid(sa, oa) or not offerStillValid(sb, ob) then
		endTrade(trade, "Trade cancelled: some items changed before it finished.", Color3.fromRGB(255, 95, 95))
		return
	end
	local petsOutA, petsOutB = countKeys(oa.pets), countKeys(ob.pets)
	if #sa.data.pets - petsOutA + petsOutB > Config.MaxPets or #sb.data.pets - petsOutB + petsOutA > Config.MaxPets then
		endTrade(trade, "Trade cancelled: a pet tank would be over " .. Config.MaxPets .. " pets.", Color3.fromRGB(255, 95, 95))
		return
	end

	local function transfer(from, to, offer)
		local shipsTouched = {}
		for key, amount in pairs(offer.parts) do
			from.data.parts[key] -= amount
			to.data.parts[key] = (to.data.parts[key] or 0) + amount
			local shipId = Config.SplitPartKey(key)
			shipsTouched[shipId] = true
		end
		for eggId, amount in pairs(offer.eggs) do
			from.data.eggs[eggId] -= amount
			if from.data.eggs[eggId] <= 0 then
				from.data.eggs[eggId] = nil
			end
			to.data.eggs[eggId] = (to.data.eggs[eggId] or 0) + amount
		end
		for uid in pairs(offer.pets) do
			local pet, index = findPet(from.data, uid)
			table.remove(from.data.pets, index)
			givePet(to.data, pet.id)
		end
		return shipsTouched
	end

	local touchedB = transfer(sa, sb, oa)
	local touchedA = transfer(sb, sa, ob)
	for shipId in pairs(touchedA) do
		checkShipComplete(sa, shipId)
	end
	for shipId in pairs(touchedB) do
		checkShipComplete(sb, shipId)
	end
	for _, s in ipairs({ sa, sb }) do
		s.data.stats.trades += 1
		updatePublicInfo(s)
		pushState(s)
		task.spawn(saveData, s) -- save both right away so the trade sticks
	end
	endTrade(trade, "Trade complete!", Color3.fromRGB(110, 235, 140))
end

local function startTrade(a, b)
	local trade = {
		players = { a, b },
		offers = { [a] = emptyOffer(), [b] = emptyOffer() },
		ready = {},
		confirmed = {},
	}
	Trades[a] = trade
	Trades[b] = trade
	sendTradeState(trade)
end

local function handleTradeAction(player, session, action, arg1, arg2)
	if action == "TradeRequest" then
		local target = typeof(arg1) == "number" and Players:GetPlayerByUserId(arg1) or nil
		local targetSession = target and Sessions[target]
		if not canTrade(session) then
			notify(player, { kind = "error", text = "Trading unlocks at Level " .. Config.TradeUnlockLevel .. "." })
		elseif not target or target == player or not targetSession then
			notify(player, { kind = "error", text = "That player isn't available." })
		elseif not canTrade(targetSession) then
			notify(player, { kind = "error", text = target.DisplayName .. " hasn't reached Level " .. Config.TradeUnlockLevel .. " yet." })
		elseif Trades[player] or Trades[target] then
			notify(player, { kind = "error", text = "One of you is already trading." })
		elseif os.clock() - (session.lastTradeRequest or -100) < 5 then
			notify(player, { kind = "error", text = "Wait a few seconds before sending another request." })
		else
			session.lastTradeRequest = os.clock()
			TradeRequests[target] = { from = player, expires = os.clock() + 20 }
			notify(target, { kind = "tradeRequest", from = player.DisplayName, fromUserId = player.UserId })
			notify(player, { kind = "info", text = "Trade request sent to " .. target.DisplayName .. "." })
		end
	elseif action == "TradeRespond" then
		local request = TradeRequests[player]
		TradeRequests[player] = nil
		if not request or os.clock() > request.expires or not request.from.Parent then
			notify(player, { kind = "error", text = "That trade request expired." })
			return
		end
		if typeof(arg1) ~= "number" or request.from.UserId ~= arg1 then
			return
		end
		if arg2 ~= true then
			notify(request.from, { kind = "error", text = player.DisplayName .. " declined your trade." })
			return
		end
		if Trades[player] or Trades[request.from] or not canTrade(session) or not canTrade(Sessions[request.from]) then
			notify(player, { kind = "error", text = "That trade can't start right now." })
			return
		end
		startTrade(request.from, player)
	else
		local trade = Trades[player]
		if not trade then
			return
		end
		local offer = trade.offers[player]
		if action == "TradeAdd" then
			local kind, id = arg1, arg2
			if kind == "part" and not Config.IsValidPartKey(id) then
				return
			elseif kind == "egg" and not (typeof(id) == "string" and Config.GetEgg(id)) then
				return
			elseif kind == "pet" and typeof(id) ~= "number" then
				return
			elseif kind ~= "part" and kind ~= "egg" and kind ~= "pet" then
				return
			end
			if availableToOffer(session, offer, kind, id) < 1 then
				notify(player, { kind = "error", text = "You don't have a spare one to trade." })
				return
			end
			if kind == "part" then
				offer.parts[id] = (offer.parts[id] or 0) + 1
			elseif kind == "egg" then
				offer.eggs[id] = (offer.eggs[id] or 0) + 1
			else
				offer.pets[id] = true
			end
			resetReady(trade)
			sendTradeState(trade)
		elseif action == "TradeRemove" then
			local kind, id = arg1, arg2
			if kind == "part" and offer.parts[id] then
				offer.parts[id] -= 1
				if offer.parts[id] <= 0 then
					offer.parts[id] = nil
				end
			elseif kind == "egg" and offer.eggs[id] then
				offer.eggs[id] -= 1
				if offer.eggs[id] <= 0 then
					offer.eggs[id] = nil
				end
			elseif kind == "pet" and offer.pets[id] then
				offer.pets[id] = nil
			else
				return
			end
			resetReady(trade)
			sendTradeState(trade)
		elseif action == "TradeReady" then
			trade.ready[player] = not trade.ready[player]
			trade.confirmed = {}
			sendTradeState(trade)
		elseif action == "TradeConfirm" then
			local a, b = trade.players[1], trade.players[2]
			if not (trade.ready[a] and trade.ready[b]) then
				return
			end
			trade.confirmed[player] = true
			if trade.confirmed[a] and trade.confirmed[b] then
				executeTrade(trade)
			else
				sendTradeState(trade)
			end
		elseif action == "TradeCancel" then
			endTrade(trade, player.DisplayName .. " cancelled the trade.", Color3.fromRGB(255, 95, 95))
		end
	end
end

---------------------------------------------------------------------------
-- BOOSTS
---------------------------------------------------------------------------
local function addBoost(session, which, minutes)
	local data = session.data
	local list = which == "all" and { "coins", "luck", "xp" } or (type(which) == "table" and which or { which })
	for _, b in ipairs(list) do
		local start = math.max(os.time(), data.boosts[b] or 0)
		data.boosts[b] = start + minutes * 60
	end
end

---------------------------------------------------------------------------
-- SEASON PASS
---------------------------------------------------------------------------
local function giveReward(session, r)
	local data = session.data
	if r.kind == "coins" then
		data.coins += r.amount
	elseif r.kind == "pearls" then
		data.pearls += r.amount
	elseif r.kind == "xp" then
		addXP(session, r.amount)
	elseif r.kind == "egg" then
		data.eggs[r.id] = (data.eggs[r.id] or 0) + r.amount
	elseif r.kind == "boost" then
		addBoost(session, r.boost, r.minutes)
	elseif r.kind == "pet" and Config.GetPet(r.id) then
		local uid = givePet(data, r.id)
		if #data.equipped < maxEquipped(session) then
			table.insert(data.equipped, uid)
		end
	elseif r.kind == "charm" then
		for _ = 1, r.amount or 1 do
			giveRandomCharm(session)
		end
	elseif r.kind == "weapon" and Config.GetWeapon(r.id) then
		if table.find(data.weapons, r.id) then
			data.pearls += 50 -- already own it
		else
			table.insert(data.weapons, r.id)
		end
	end
end

local function claimDaily(session)
	local data = session.data
	local status = loginStatus(data)
	if not status.canClaim then
		notify(session.player, { kind = "error", text = "You already claimed today's reward. Come back tomorrow!" })
		return
	end
	data.login.claimedDay = today()
	data.login.streak = status.streak
	data.login.best = math.max(data.login.best, status.streak)
	local days = #Config.DailyRewards
	local dayIndex = (status.streak - 1) % days + 1
	local week = math.floor((status.streak - 1) / days)
	local mult = math.min(Config.DailyMaxMultiplier, 1 + Config.DailyWeekBonus * week)
	local given = {}
	for _, reward in ipairs(Config.DailyRewards[dayIndex]) do
		local r = table.clone(reward)
		if r.amount then
			r.amount = math.max(1, math.floor(r.amount * (r.perLevel and data.level or 1) * mult + 0.5))
		end
		if r.minutes then
			r.minutes = math.floor(r.minutes * mult + 0.5)
		end
		r.perLevel = nil
		giveReward(session, r)
		table.insert(given, r)
	end
	notify(session.player, { kind = "dailyClaimed", streak = status.streak, day = dayIndex, rewards = given, multiplier = mult })
	pushState(session)
	task.spawn(saveData, session)
end

local function seasonTracks(season)
	local tracks = { "free" }
	if season.premium or season.mystic then
		table.insert(tracks, "premium")
	end
	if season.mystic then
		table.insert(tracks, "mystic")
	end
	return tracks
end

-- Hands out every reward you've reached on the tracks you own (safe to call any time)
local function grantSeasonRewards(session)
	local data = session.data
	local season = data.season
	local cfg = Config.Season
	local tier = Config.SeasonTier(season.xp)
	local given = {}
	for t = 1, math.min(tier, cfg.tiers) do
		local row = cfg.rewards[t]
		if row then
			for _, track in ipairs(seasonTracks(season)) do
				local reward = row[track]
				local key = track .. ":" .. t
				if reward and not season.claimed[key] then
					season.claimed[key] = true
					giveReward(session, Config.ScaleReward(reward, season.prestige))
					table.insert(given, { reward = reward, track = track, tier = t })
				end
			end
		end
	end
	if season.prestige >= cfg.maxPrestige then
		for t = cfg.tiers + 1, tier do
			local key = "overflow:" .. t
			if not season.claimed[key] then
				season.claimed[key] = true
				data.pearls += cfg.overflowPearls
				table.insert(given, { reward = { kind = "pearls", amount = cfg.overflowPearls }, track = "bonus", tier = t, raw = true })
			end
		end
	end
	if #given > 0 then
		notify(session.player, { kind = "seasonRewards", rewards = given, prestige = season.prestige })
		updatePublicInfo(session)
	end
end

addSeasonXP = function(session, amount)
	local season = session.data.season
	local cfg = Config.Season
	local bonus = season.mystic and cfg.mysticXpBonus or (season.premium and cfg.premiumXpBonus or 0)
	local before = Config.SeasonTier(season.xp)
	season.xp += math.floor(amount * (1 + bonus) + 0.5)
	local after = Config.SeasonTier(season.xp)
	if after > before then
		notify(session.player, { kind = "seasonTier", tier = after })
		grantSeasonRewards(session)
	end
end

local function canPrestige(season)
	local cfg = Config.Season
	return season.prestige < cfg.maxPrestige and Config.SeasonTier(season.xp) >= cfg.tiers + cfg.prestigeExtraTiers
end

local function seasonPrestige(session)
	local season = session.data.season
	if not canPrestige(season) then
		notify(session.player, { kind = "error", text = "You can't prestige the season pass yet." })
		return
	end
	season.prestige += 1
	season.xp = 0
	season.claimed = {}
	notify(session.player, { kind = "seasonPrestige", prestige = season.prestige })
	announce(session.player.DisplayName .. " reached Season Prestige " .. season.prestige .. "!", Color3.fromRGB(255, 90, 220))
	pushState(session)
	task.spawn(saveData, session)
end

---------------------------------------------------------------------------
-- QUESTS
---------------------------------------------------------------------------
local function getQuestDef(id)
	for _, pool in ipairs({ Config.DailyQuests, Config.WeeklyQuests }) do
		for _, def in ipairs(pool) do
			if def.id == id then
				return def
			end
		end
	end
	return nil
end

local function pickQuests(pool, count)
	local order = {}
	for i = 1, #pool do
		order[i] = i
	end
	for i = #order, 2, -1 do
		local j = rng:NextInteger(1, i)
		order[i], order[j] = order[j], order[i]
	end
	local list = {}
	for i = 1, math.min(count, #pool) do
		table.insert(list, { id = pool[order[i]].id, progress = 0, claimed = false })
	end
	return list
end

local function refreshQuests(session)
	local quests = session.data.quests
	local day = math.floor(os.time() / 86400)
	local week = math.floor((os.time() + 3 * 86400) / 604800) -- weeks start on Monday (UTC)
	if quests.daily.key ~= day then
		quests.daily = { key = day, list = pickQuests(Config.DailyQuests, Config.DailyQuestCount) }
	end
	if quests.weekly.key ~= week then
		quests.weekly = { key = week, list = pickQuests(Config.WeeklyQuests, Config.WeeklyQuestCount) }
	end
end

questProgress = function(session, stat, amount)
	refreshQuests(session)
	for _, scope in ipairs({ session.data.quests.daily, session.data.quests.weekly }) do
		for _, q in ipairs(scope.list) do
			local def = getQuestDef(q.id)
			if def and def.stat == stat and not q.claimed and q.progress < def.target then
				q.progress = math.min(def.target, q.progress + amount)
				if q.progress >= def.target then
					q.level = session.data.level -- reward is locked in now (no saving quests for a higher level)
					notify(session.player, { kind = "questDone", text = string.format(def.text, def.target) })
				end
			end
		end
	end
end

local function claimQuest(session, scopeName, index)
	if scopeName ~= "daily" and scopeName ~= "weekly" then
		return
	end
	refreshQuests(session)
	local data = session.data
	local q = data.quests[scopeName].list[index]
	local def = q and getQuestDef(q.id)
	if not def or q.claimed or q.progress < def.target then
		return
	end
	q.claimed = true
	local level = math.min(q.level or data.level, data.level)
	local coins = def.reward.coins * level
	data.coins += coins
	data.pearls += def.reward.pearls
	local xp = math.floor(Config.XPToNext(data.level) * (def.reward.levels or 0))
	notify(session.player, { kind = "questClaimed", coins = coins, pearls = def.reward.pearls, seasonXp = def.reward.seasonXp, xp = xp })
	addSeasonXP(session, def.reward.seasonXp)
	if xp > 0 then
		addXP(session, xp, true)
	end
	pushState(session)
end

---------------------------------------------------------------------------
-- REBIRTH
---------------------------------------------------------------------------
-- paid = true for the Instant Rebirth product (skips the requirements)
local function doRebirth(session, paid)
	local data = session.data
	local player = session.player
	local needLevel, needCoins = Config.RebirthRequirement(data.rebirths)
	if data.rebirths >= Config.Rebirth.max then
		notify(player, { kind = "error", text = "You've reached the max rebirths!" })
		return false
	elseif not paid and (data.level < needLevel or data.coins < needCoins) then
		notify(player, { kind = "error", text = "Rebirth needs Level " .. needLevel .. " and " .. Config.FormatNumber(needCoins) .. " coins." })
		return false
	elseif Trades[player] then
		if not paid then
			notify(player, { kind = "error", text = "Finish your trade first." })
			return false
		end
		endTrade(Trades[player], "Trade cancelled because " .. player.DisplayName .. " rebirthed.", Color3.fromRGB(255, 95, 95))
	end

	data.rebirths += 1
	local reward = Config.RebirthBonusFor(data.rebirths)
	data.pearls += reward.pearls
	data.coins = 0
	data.level = 1
	data.xp = 0
	data.subs = { { id = Config.StartingSub, depth = 1 } }
	local kept = { Config.StartingWeapon }
	for _, id in ipairs(data.weapons) do
		local w = Config.GetWeapon(id)
		if w and w.seasonOnly then
			table.insert(kept, id) -- season pass weapons are never taken away
		end
	end
	data.weapons = kept
	if not table.find(kept, data.weapon) then
		data.weapon = Config.StartingWeapon
	end

	for _, entry in pairs(session.fleet) do
		if entry.model then
			entry.model:Destroy()
		end
		if entry.crate then
			entry.crate:Destroy()
		end
	end
	session.fleet = {}
	addFleetEntry(session, 1)
	giveWeaponTool(session)
	updatePublicInfo(session)
	teleportToBay(session)
	questProgress(session, "rebirths", 1)
	notify(player, { kind = "rebirth", rebirths = data.rebirths, pearls = reward.pearls })
	announce(player.DisplayName .. " just reached Rebirth " .. data.rebirths .. "!", Color3.fromRGB(255, 205, 80))
	pushState(session)
	task.spawn(saveData, session)
	return true
end

-- +n levels right away (Level Pack product)
local function giveLevels(session, n)
	local data = session.data
	for _ = 1, n do
		if data.level >= Config.MaxLevel then
			break
		end
		addXP(session, Config.XPToNext(data.level) - data.xp, true)
	end
end

---------------------------------------------------------------------------
-- ROBUX PURCHASES
---------------------------------------------------------------------------
local function refreshPasses(session)
	local passes = {}
	for _, pass in ipairs(Config.GamePasses) do
		if pass.id ~= 0 then
			local ok, owns = pcall(function()
				return MarketplaceService:UserOwnsGamePassAsync(session.player.UserId, pass.id)
			end)
			if ok and owns then
				passes[pass.key] = true
			end
		end
		if RunService:IsStudio() and session.data.testPasses[pass.key] then
			passes[pass.key] = true
		end
	end
	session.passes = passes
	-- drop extra equipped pets if the player no longer has the pet slots pass
	while #session.data.equipped > maxEquipped(session) do
		table.remove(session.data.equipped)
	end
	while #session.data.equippedCharms > charmSlots(session) do
		table.remove(session.data.equippedCharms)
	end
end

local function grantProduct(session, product)
	local data = session.data
	if product.boost then
		addBoost(session, product.boost, product.minutes)
	elseif product.levels then
		if data.level >= Config.MaxLevel then
			data.pearls += 50
			notify(session.player, { kind = "purchase", text = "You're max level, so you got 50 Pearls instead." })
		else
			giveLevels(session, product.levels)
		end
	elseif product.rebirth then
		if not doRebirth(session, true) then
			-- already at max rebirths: never take Robux for nothing
			data.pearls += 150
			notify(session.player, { kind = "purchase", text = "You're at max rebirths, so you got 150 Pearls instead." })
		end
	elseif product.seasonPass == "premium" then
		data.season.premium = true
	elseif product.seasonPass == "mystic" then
		data.season.mystic = true
	end
	notify(session.player, { kind = "purchase", text = product.name .. " activated! Thank you!" })
	grantSeasonRewards(session)
	pushState(session)
end

local function handleBuy(session, key)
	local player = session.player
	local pass = Config.GetPassByKey(key)
	local product = Config.GetProductByKey(key)
	if pass then
		if hasPass(session, key) then
			notify(player, { kind = "error", text = "You already own " .. pass.name .. "." })
		elseif pass.id ~= 0 then
			MarketplaceService:PromptGamePassPurchase(player, pass.id)
		elseif RunService:IsStudio() then
			session.data.testPasses[key] = true
			session.passes[key] = true
			notify(player, { kind = "purchase", text = "[Studio test] " .. pass.name .. " given for free." })
			updatePublicInfo(session)
			pushState(session)
		else
			notify(player, { kind = "error", text = pass.name .. " isn't for sale yet." })
		end
	elseif product then
		local season = session.data.season
		if (product.seasonPass == "premium" and (season.premium or season.mystic)) or (product.seasonPass == "mystic" and season.mystic) then
			notify(player, { kind = "error", text = "You already have that season pass." })
		elseif product.levels and session.data.level >= Config.MaxLevel then
			notify(player, { kind = "error", text = "You're already max level!" })
		elseif product.rebirth and session.data.rebirths >= Config.Rebirth.max then
			notify(player, { kind = "error", text = "You're already at max rebirths!" })
		elseif product.rebirth and Trades[player] then
			notify(player, { kind = "error", text = "Finish your trade first." })
		elseif product.id ~= 0 then
			MarketplaceService:PromptProductPurchase(player, product.id)
		elseif RunService:IsStudio() then
			grantProduct(session, product)
		else
			notify(player, { kind = "error", text = product.name .. " isn't for sale yet." })
		end
	end
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
	local session = Sessions[player]
	if not purchased or not session then
		return
	end
	for _, pass in ipairs(Config.GamePasses) do
		if pass.id == passId then
			session.passes[pass.key] = true
			notify(player, { kind = "purchase", text = pass.name .. " unlocked! Thank you!" })
			updatePublicInfo(session)
			pushState(session)
		end
	end
end)

MarketplaceService.ProcessReceipt = function(info)
	local player = Players:GetPlayerByUserId(info.PlayerId)
	local session = player and Sessions[player]
	if not session or not session.loaded then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	local data = session.data
	local purchaseId = tostring(info.PurchaseId)
	if data.receipts[purchaseId] then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end
	local product
	for _, p in ipairs(Config.Products) do
		if p.id ~= 0 and p.id == info.ProductId then
			product = p
		end
	end
	if not product then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	grantProduct(session, product)
	data.receipts[purchaseId] = true
	table.insert(data.receiptOrder, purchaseId)
	while #data.receiptOrder > 50 do
		data.receipts[table.remove(data.receiptOrder, 1)] = nil
	end
	-- only tell Roblox it's done once it's saved, so a purchase is never lost
	if session.canSave and not saveData(session) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

---------------------------------------------------------------------------
-- SEASON CHARMS + TIDE BOTTLES (seasonal items found in the water)
---------------------------------------------------------------------------
-- True when the player's character is close enough to a part to really be
-- using it (stops exploiters triggering prompts from across the map)
isNear = function(player, part, maxDistance)
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	if not hrp or not part or not part.Parent then
		return false
	end
	return (hrp.Position - part.Position).Magnitude <= maxDistance + 6
end

giveRandomCharm = function(session)
	local pool = Config.SeasonCharms()
	if #pool == 0 then
		return
	end
	local total = 0
	for _, charm in ipairs(pool) do
		total += charm.weight
	end
	local roll = rng:NextNumber() * total
	local picked = pool[#pool]
	for _, charm in ipairs(pool) do
		roll -= charm.weight
		if roll <= 0 then
			picked = charm
			break
		end
	end
	local data = session.data
	local isNew = (data.charms[picked.id] or 0) == 0
	data.charms[picked.id] = (data.charms[picked.id] or 0) + 1
	if isNew and #data.equippedCharms < charmSlots(session) then
		table.insert(data.equippedCharms, picked.id)
	end
	notify(session.player, { kind = "charm", id = picked.id, isNew = isNew })
	if picked.rarity >= 4 then
		announce(session.player.DisplayName .. " found a " .. Config.PetRarities[picked.rarity].name .. " " .. picked.name .. "!",
			Config.PetRarities[picked.rarity].color)
	end
end

local function toggleCharm(session, id)
	local data = session.data
	if not data.charms[id] then
		return
	end
	local index = table.find(data.equippedCharms, id)
	if index then
		table.remove(data.equippedCharms, index)
	elseif #data.equippedCharms < charmSlots(session) then
		table.insert(data.equippedCharms, id)
	else
		notify(session.player, { kind = "error", text = "All " .. charmSlots(session) .. " charm slots are full. Unequip one first." })
		return
	end
	pushState(session)
end

local function dissolveCharm(session, id)
	local data = session.data
	local charm = Config.GetCharm(id)
	local count = data.charms[id]
	if not charm or not count then
		return
	end
	local inUse = table.find(data.equippedCharms, id) and 1 or 0
	if count - inUse < 1 then
		notify(session.player, { kind = "error", text = "That's your only " .. charm.name .. " and it's equipped." })
		return
	end
	data.charms[id] = count - 1
	if data.charms[id] <= 0 then
		data.charms[id] = nil
	end
	local xp = Config.CharmDissolveXp[charm.rarity]
	notify(session.player, { kind = "info", text = "Dissolved a " .. charm.name .. " for " .. xp .. " season XP." })
	addSeasonXP(session, xp)
	pushState(session)
end

local drifterFolder = Instance.new("Folder")
drifterFolder.Name = "TideBottles"
drifterFolder.Parent = World

local function spawnDrifter()
	local cfg = Config.Drifters
	local bayAngle = rng:NextInteger(0, BAY_COUNT - 1) * (360 / BAY_COUNT)
	local angle = math.rad(bayAngle + rng:NextNumber(14, 46))
	local pos = polar(rng:NextNumber(75, 170), angle, 0.5)
	local cf = CFrame.new(pos) * CFrame.Angles(0, rng:NextNumber(0, 6.28), math.rad(80))
	local bottle = makePart({
		Name = "TideBottle",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(2.8, 1.5, 1.5),
		CFrame = cf,
		Color = Color3.fromRGB(190, 240, 235),
		Material = Enum.Material.Glass,
		Transparency = 0.35,
		CanCollide = false,
		Parent = drifterFolder,
	})
	local function attach(props, offset)
		props.Parent = bottle
		props.CanCollide = false
		props.CFrame = cf * offset
		local part = makePart(props)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = bottle
		weld.Part1 = part
		weld.Parent = part
		return part
	end
	attach({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.9, 0.7, 0.7), Color = Color3.fromRGB(190, 240, 235),
		Material = Enum.Material.Glass, Transparency = 0.35 }, CFrame.new(1.8, 0, 0))
	attach({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(0.4, 0.75, 0.75), Color = Color3.fromRGB(140, 95, 55),
		Material = Enum.Material.Wood }, CFrame.new(2.4, 0, 0))
	attach({ Shape = Enum.PartType.Cylinder, Size = Vector3.new(1.8, 0.8, 0.8), Color = cfg.color,
		Material = Enum.Material.Neon }, CFrame.new(-0.1, 0, 0))
	local light = Instance.new("PointLight")
	light.Color = cfg.color
	light.Range = 14
	light.Brightness = 2
	light.Parent = bottle
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Color = ColorSequence.new(cfg.color)
	sparkles.LightEmission = 1
	sparkles.Rate = 6
	sparkles.Speed = NumberRange.new(1, 3)
	sparkles.Size = NumberSequence.new(0.35)
	sparkles.Parent = bottle
	addBillboard(bottle, cfg.name, cfg.color, 3, 90, 160)

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Open"
	prompt.ObjectText = cfg.name
	prompt.HoldDuration = 0.6
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = bottle
	prompt.Triggered:Connect(function(who)
		local session = Sessions[who]
		if not session or not session.loaded or bottle:GetAttribute("Claimed") or not isNear(who, bottle, 12) then
			return
		end
		bottle:SetAttribute("Claimed", true)
		local coins = math.floor(cfg.coins * coinMultiplier(session))
		session.data.coins += coins
		notify(who, { kind = "drifter", coins = coins, seasonXp = cfg.seasonXp })
		questProgress(session, "drifters", 1)
		addSeasonXP(session, cfg.seasonXp)
		if rng:NextNumber() < cfg.charmChance then
			giveRandomCharm(session)
		end
		pushState(session)
		bottle:Destroy()
	end)
end

task.spawn(function()
	while true do
		task.wait(Config.Drifters.interval)
		if #Players:GetPlayers() > 0 and #drifterFolder:GetChildren() < Config.Drifters.max then
			spawnDrifter()
		end
	end
end)

---------------------------------------------------------------------------
-- HUNTING GROUNDS: arenas, portals, enemies, weapons, the Leviathan
---------------------------------------------------------------------------
local Models = require(ReplicatedStorage:WaitForChild("SalvageModels"))
local ARENA_SIZE = Config.ArenaSize
local ARENA_HALF = ARENA_SIZE / 2
local Arenas = {}
local Enemies = {}

local arenaCenter = Config.ArenaCenter

local function arenaSpawnCF(arena)
	local spawnPos = arena.center + Vector3.new(0, 4, ARENA_HALF - 22)
	return CFrame.lookAt(spawnPos, arena.center + Vector3.new(0, 4, 0))
end

local function buildArena(index, def)
	local center = arenaCenter(index)
	local folder = Instance.new("Folder")
	folder.Name = "Arena_" .. def.id
	folder.Parent = World
	local zone = Config.Zones[def.zone]

	makePart({
		Name = "Floor",
		Size = Vector3.new(ARENA_SIZE + 40, 4, ARENA_SIZE + 40),
		CFrame = CFrame.new(center - Vector3.new(0, 2, 0)),
		Color = def.floor,
		Material = def.floorMaterial,
		Parent = folder,
	})
	-- invisible walls so nobody falls off
	for _, side in ipairs({ { 1, 0 }, { -1, 0 }, { 0, 1 }, { 0, -1 } }) do
		makePart({
			Name = "Barrier",
			Size = side[1] ~= 0 and Vector3.new(4, 120, ARENA_SIZE + 40) or Vector3.new(ARENA_SIZE + 40, 120, 4),
			CFrame = CFrame.new(center + Vector3.new(side[1] * (ARENA_HALF + 6), 60, side[2] * (ARENA_HALF + 6))),
			Transparency = 1,
			Parent = folder,
		})
	end
	-- ring of cliffs
	for a = 0, 355, 9 do
		local angle = math.rad(a)
		local w, h = rng:NextNumber(14, 24), rng:NextNumber(35, 70)
		makePart({
			Name = "Cliff",
			Size = Vector3.new(w, h, rng:NextNumber(12, 18)),
			CFrame = CFrame.new(center + Vector3.new(math.sin(angle) * (ARENA_HALF + 4), h / 2 - 4, math.cos(angle) * (ARENA_HALF + 4)))
				* CFrame.Angles(rng:NextNumber(-0.15, 0.15), angle + rng:NextNumber(-0.3, 0.3), rng:NextNumber(-0.15, 0.15)),
			Color = def.rock,
			Material = Enum.Material.Slate,
			Parent = folder,
		})
	end
	-- scattered rocks, plants and lights
	for _ = 1, 26 do
		local pos = center + Vector3.new(rng:NextNumber(-ARENA_HALF + 15, ARENA_HALF - 15), 0, rng:NextNumber(-ARENA_HALF + 15, ARENA_HALF - 30))
		local kind = rng:NextInteger(1, 3)
		if kind == 1 then
			local sz = rng:NextNumber(3, 8)
			makePart({
				Size = Vector3.new(sz, sz * 0.7, sz),
				CFrame = CFrame.new(pos) * CFrame.Angles(rng:NextNumber(0, 6), rng:NextNumber(0, 6), 0),
				Color = def.rock,
				Material = Enum.Material.Slate,
				Parent = folder,
			})
		elseif def.zone <= 2 then
			local height = rng:NextNumber(8, 22)
			makePart({
				Size = Vector3.new(0.8, height, 0.4),
				CFrame = CFrame.new(pos + Vector3.new(0, height / 2, 0)) * CFrame.Angles(rng:NextNumber(-0.15, 0.15), rng:NextNumber(0, 6), 0),
				Color = Color3.fromRGB(40, rng:NextInteger(120, 160), 60),
				Material = Enum.Material.Grass,
				CanCollide = false,
				Parent = folder,
			})
		else
			-- glowing crystals / bioluminescent plants in the deep
			local height = rng:NextNumber(3, 9)
			local glowColor = ({ Color3.fromRGB(90, 200, 255), Color3.fromRGB(170, 90, 255), Color3.fromRGB(255, 60, 90) })[math.min(def.zone - 2, 3)]
			local crystal = makePart({
				Size = Vector3.new(1.4, height, 1.4),
				CFrame = CFrame.new(pos + Vector3.new(0, height / 2, 0)) * CFrame.Angles(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0, 6), rng:NextNumber(-0.3, 0.3)),
				Color = glowColor,
				Material = Enum.Material.Neon,
				CanCollide = false,
				Parent = folder,
			})
			local light = Instance.new("PointLight")
			light.Color = glowColor
			light.Range = 16
			light.Brightness = 1.2
			light.Parent = crystal
		end
	end
	-- bubbles rising from vents
	for _ = 1, 5 do
		local vent = makePart({
			Size = Vector3.new(3, 1, 3),
			CFrame = CFrame.new(center + Vector3.new(rng:NextNumber(-60, 60), 0.3, rng:NextNumber(-60, 50))),
			Color = def.rock,
			Material = Enum.Material.Slate,
			Parent = folder,
		})
		local bubbles = Instance.new("ParticleEmitter")
		bubbles.Color = ColorSequence.new(Color3.fromRGB(220, 240, 255))
		bubbles.Transparency = NumberSequence.new(0.3, 1)
		bubbles.Size = NumberSequence.new(0.4, 0.8)
		bubbles.Speed = NumberRange.new(6, 10)
		bubbles.Lifetime = NumberRange.new(3, 5)
		bubbles.Rate = 8
		bubbles.EmissionDirection = Enum.NormalId.Top
		bubbles.Parent = vent
	end

	-- way back to the island
	local returnPad = makePart({
		Name = "ReturnPortal",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 12, 12),
		CFrame = CFrame.new(center + Vector3.new(0, 0.3, ARENA_HALF - 8)) * UPRIGHT,
		Color = Color3.fromRGB(90, 255, 230),
		Material = Enum.Material.Neon,
		Transparency = 0.3,
		Parent = folder,
	})
	local returnPrompt = Instance.new("ProximityPrompt")
	returnPrompt.ActionText = "Return to Island"
	returnPrompt.ObjectText = "Surface"
	returnPrompt.HoldDuration = 0.3
	returnPrompt.RequiresLineOfSight = false
	returnPrompt.MaxActivationDistance = 10
	returnPrompt.Parent = returnPad

	local sign = makePart({
		Size = Vector3.new(1, 1, 1),
		Transparency = 1,
		CanCollide = false,
		CFrame = CFrame.new(center + Vector3.new(0, 14, ARENA_HALF - 8)),
		Parent = folder,
	})
	addBillboard(sign, zone.name:upper() .. " HUNTING GROUNDS", Color3.fromRGB(90, 255, 230), 0, 200, 400)

	local arena = {
		index = index,
		def = def,
		center = center,
		folder = folder,
		enemies = {},
		players = {},
		emptySince = os.clock(),
		nextBoss = nil,
		respawnAt = 0,
	}
	Arenas[index] = arena
	returnPrompt.Triggered:Connect(function(who)
		local session = Sessions[who]
		if session then
			teleportToBay(session)
		end
	end)
	return arena
end

-- Portals on the island
local function buildPortal(arena, angle)
	local def = arena.def
	local zone = Config.Zones[def.zone]
	local base = polar(38, angle, 3.6)
	local facing = CFrame.lookAt(base + Vector3.new(0, 6, 0), Vector3.new(0, 9.6, 0))
	local color = Config.Rarities[math.min(def.zone, 5)].color
	for k = 0, 15 do
		local a = math.rad(k * 22.5)
		makePart({
			Size = Vector3.new(1, 1.6, 1),
			CFrame = facing * CFrame.new(math.cos(a) * 5, math.sin(a) * 5, 0) * CFrame.Angles(0, 0, a),
			Color = color,
			Material = Enum.Material.Neon,
			CanCollide = false,
		})
	end
	local surface = makePart({
		Name = "Portal",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.3, 9.2, 9.2),
		CFrame = facing * CFrame.Angles(0, math.rad(90), 0),
		Color = def.water,
		Material = Enum.Material.Neon,
		Transparency = 0.45,
		CanCollide = false,
	})
	addBillboard(surface, zone.name .. "  |  Lv " .. def.level .. "+", color, 6.5, 120, 260)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Dive In"
	prompt.ObjectText = zone.name .. " Hunting Grounds"
	prompt.HoldDuration = 0.3
	prompt.RequiresLineOfSight = false
	prompt.MaxActivationDistance = 12
	prompt.Parent = surface
	prompt.Triggered:Connect(function(who)
		local session = Sessions[who]
		if not session or not session.loaded or not isNear(who, surface, 12) then
			return
		end
		if session.data.level < def.level then
			notify(who, { kind = "error", text = "You need Level " .. def.level .. " to hunt in " .. zone.name .. "." })
			return
		end
		safeTeleport(session, arenaSpawnCF(arena))
	end)
end

for i, def in ipairs(Config.Arenas) do
	local arena = buildArena(i, def)
	buildPortal(arena, math.rad(100 + (i - 1) * 20))
end

---------------------------------------------------------------------------
-- ENEMIES
---------------------------------------------------------------------------
local function enemyFloorY(enemy)
	return enemy.arena.center.Y + enemy.hover
end

local function spawnEnemy(arena, enemyId)
	local def = Config.GetEnemy(enemyId)
	local buildDef = table.clone(def)
	buildDef.angry = true
	local model = Models.Build(buildDef, def.scale)
	local root = model.PrimaryPart
	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") and part ~= root then
			part.Anchored = false
			part.Massless = true
			local weld = Instance.new("WeldConstraint")
			weld.Part0 = root
			weld.Part1 = part
			weld.Parent = part
		end
	end
	root.Anchored = true
	local extents = model:GetExtentsSize()

	local hp = def.hp
	if def.boss then
		hp += (def.hpPerPlayer or 0) * math.max(1, #arena.players)
	end
	local enemy = {
		def = def,
		arena = arena,
		model = model,
		root = root,
		hp = hp,
		maxHp = hp,
		alive = true,
		radius = math.max(extents.X, extents.Z) / 2,
		hover = def.height + extents.Y / 2,
		lastAttack = 0,
		damageBy = {},
		phase = rng:NextNumber(0, 6),
		spawnedAt = os.clock(),
	}
	local spot = arena.center + Vector3.new(rng:NextNumber(-60, 60), 0, rng:NextNumber(-70, 40))
	enemy.home = spot
	enemy.pos = Vector3.new(spot.X, enemyFloorY(enemy), spot.Z)
	enemy.wander = enemy.pos
	root.CFrame = CFrame.new(enemy.pos)

	-- health bar
	local gui = Instance.new("BillboardGui")
	gui.Size = def.boss and UDim2.new(0, 320, 0, 44) or UDim2.new(0, 150, 0, 34)
	gui.StudsOffset = Vector3.new(0, extents.Y / 2 + 2, 0)
	gui.MaxDistance = def.boss and 400 or 90
	gui.Adornee = root
	local nameLabel = Instance.new("TextLabel")
	nameLabel.Size = UDim2.new(1, 0, 0.55, 0)
	nameLabel.BackgroundTransparency = 1
	nameLabel.Font = Enum.Font.GothamBlack
	nameLabel.TextScaled = true
	nameLabel.TextColor3 = def.boss and Color3.fromRGB(255, 80, 80) or Color3.fromRGB(255, 255, 255)
	nameLabel.TextStrokeTransparency = 0.3
	nameLabel.Text = def.name
	nameLabel.Parent = gui
	local bar = Instance.new("Frame")
	bar.Size = UDim2.new(1, 0, 0.3, 0)
	bar.Position = UDim2.new(0, 0, 0.65, 0)
	bar.BackgroundColor3 = Color3.fromRGB(40, 10, 10)
	bar.BorderSizePixel = 0
	bar.Parent = gui
	local fill = Instance.new("Frame")
	fill.Size = UDim2.fromScale(1, 1)
	fill.BackgroundColor3 = Color3.fromRGB(230, 60, 60)
	fill.BorderSizePixel = 0
	fill.Parent = bar
	gui.Parent = root
	enemy.fill = fill

	local highlight = Instance.new("Highlight")
	highlight.FillColor = Color3.fromRGB(255, 255, 255)
	highlight.FillTransparency = 0.4
	highlight.OutlineTransparency = 1
	highlight.Enabled = false
	highlight.Parent = model
	enemy.highlight = highlight

	model.Parent = arena.folder
	table.insert(arena.enemies, enemy)
	table.insert(Enemies, enemy)
	return enemy
end

-- Model:ScaleTo is a newer Roblox API; if it's missing we just skip scaling
local function scaleModel(model, scale)
	pcall(function()
		model:ScaleTo(scale)
	end)
end

local function removeEnemy(enemy, animateDeath)
	enemy.alive = false
	local index = table.find(enemy.arena.enemies, enemy)
	if index then
		table.remove(enemy.arena.enemies, index)
	end
	index = table.find(Enemies, enemy)
	if index then
		table.remove(Enemies, index)
	end
	if not animateDeath then
		enemy.model:Destroy()
		return
	end
	-- death: spin, sink and shrink away
	local gui = enemy.root:FindFirstChildOfClass("BillboardGui")
	if gui then
		gui:Destroy()
	end
	local startCF = enemy.root.CFrame
	task.spawn(function()
		local steps = 12
		for i = 1, steps do
			local p = i / steps
			if not enemy.model.Parent then
				return
			end
			enemy.root.CFrame = startCF * CFrame.new(0, -p * 3, 0) * CFrame.Angles(0, p * math.pi * 2, p * 0.8)
			scaleModel(enemy.model, math.max(0.05, 1 - p * 0.9))
			task.wait(0.05)
		end
		enemy.model:Destroy()
	end)
end

-- Floating damage number
local function damageNumber(position, amount, color)
	local anchor = makePart({
		Size = Vector3.new(0.2, 0.2, 0.2),
		CFrame = CFrame.new(position + Vector3.new(rng:NextNumber(-1.5, 1.5), 2, rng:NextNumber(-1.5, 1.5))),
		Transparency = 1,
		CanCollide = false,
		CanQuery = false,
	})
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, 90, 0, 36)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 80
	gui.Parent = anchor
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBlack
	label.TextScaled = true
	label.TextColor3 = color
	label.TextStrokeTransparency = 0.2
	label.Text = Config.FormatNumber(amount)
	label.Parent = gui
	TweenService:Create(anchor, TweenInfo.new(0.8, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = anchor.CFrame + Vector3.new(0, 4, 0) }):Play()
	TweenService:Create(label, TweenInfo.new(0.8), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(0.85, function()
		anchor:Destroy()
	end)
end

local function burst(position, color, size)
	local part = makePart({
		Shape = Enum.PartType.Ball,
		Size = Vector3.new(size, size, size),
		CFrame = CFrame.new(position),
		Color = color,
		Material = Enum.Material.Neon,
		Transparency = 0.2,
		CanCollide = false,
		CanQuery = false,
	})
	TweenService:Create(part, TweenInfo.new(0.35), { Size = Vector3.new(size * 2.5, size * 2.5, size * 2.5), Transparency = 1 }):Play()
	task.delay(0.4, function()
		part:Destroy()
	end)
end

-- A fragment dropped by a creature (same rules as one from a crate)
local function giveKillFragment(session, zoneIndex)
	local data = session.data
	local rarity = rollRarity(Config.Zones[zoneIndex], getMultipliers(session).luck)
	local pick = pickPart(data, rarity)
	local key = Config.PartKey(pick.ship.id, pick.part)
	local owned = data.parts[key] or 0
	local isNew = owned == 0
	local sold = 0
	data.stats.fragments += 1
	questProgress(session, "fragments", 1)
	if isNew then
		questProgress(session, "newFragments", 1)
	end
	if isNew or not data.autoSell then
		data.parts[key] = owned + 1
	else
		sold = Config.Rarities[rarity].sellValue
		data.coins += sold
	end
	notify(session.player, { kind = "loot", rarity = rarity, ship = pick.ship.id, part = pick.part, isNew = isNew, sold = sold })
	if rarity == 5 then
		announce(session.player.DisplayName .. " pulled a GHOST fragment off a sea creature!", Config.Rarities[5].color)
	end
	if isNew then
		checkShipComplete(session, pick.ship.id)
	end
end

local function killEnemy(enemy)
	local def = enemy.def
	local zoneIndex = enemy.arena.def.zone
	burst(enemy.root.Position, def.accent, enemy.radius)
	for player in pairs(enemy.damageBy) do
		local session = Sessions[player]
		if session and session.loaded then
			local data = session.data
			local coins = math.floor(def.coins * coinMultiplier(session))
			data.coins += coins
			data.stats.kills += 1
			if def.pearls then
				data.pearls += def.pearls
			end
			questProgress(session, "kills", 1)
			if zoneIndex >= 2 then
				questProgress(session, "deepKills", 1)
			end
			if rng:NextNumber() < Config.CharmChanceKill then
				giveRandomCharm(session)
			end
			addSeasonXP(session, def.seasonXp)
			addXP(session, def.xp)
			local drops = def.boss and 3 or (rng:NextNumber() < Config.EnemyFragmentChance and 1 or 0)
			for _ = 1, drops do
				giveKillFragment(session, zoneIndex)
			end
			if rng:NextNumber() < (def.eggChance or Config.EnemyEggChance) then
				local egg = Config.EggForZone(zoneIndex)
				if egg then
					data.eggs[egg.id] = (data.eggs[egg.id] or 0) + 1
					notify(player, { kind = "egg", egg = egg.id })
				end
			end
			notify(player, { kind = "kill", enemy = def.name, coins = coins, pearls = def.pearls, boss = def.boss })
			pushState(session)
		end
	end
	if def.boss then
		announce("THE LEVIATHAN HAS BEEN SLAIN!", Color3.fromRGB(60, 255, 230))
		enemy.arena.nextBoss = os.clock() + Config.BossInterval
	end
	removeEnemy(enemy, true)
end

local function damageEnemy(enemy, session, amount)
	if not enemy.alive then
		return
	end
	enemy.hp -= amount
	enemy.hitAt = os.clock()
	damageNumber(enemy.root.Position + Vector3.new(0, enemy.hover * 0.3, 0), math.floor(amount), Color3.fromRGB(255, 230, 120))
	enemy.damageBy[session.player] = (enemy.damageBy[session.player] or 0) + amount
	enemy.fill.Size = UDim2.fromScale(math.clamp(enemy.hp / enemy.maxHp, 0, 1), 1)
	enemy.highlight.Enabled = true
	task.delay(0.08, function()
		if enemy.highlight.Parent then
			enemy.highlight.Enabled = false
		end
	end)
	if enemy.hp <= 0 then
		killEnemy(enemy)
	end
end

---------------------------------------------------------------------------
-- WEAPONS
---------------------------------------------------------------------------
local function arenaAt(position)
	for _, arena in ipairs(Arenas) do
		local offset = position - arena.center
		if math.abs(offset.X) <= ARENA_HALF + 10 and math.abs(offset.Z) <= ARENA_HALF + 10 and offset.Y > -20 and offset.Y < 150 then
			return arena
		end
	end
	return nil
end

-- Swing the character's right arm (works for R15 and R6, no animation assets needed)
local function swingArm(session, character)
	local shoulder, axis
	local upperArm = character:FindFirstChild("RightUpperArm")
	if upperArm then
		shoulder = upperArm:FindFirstChild("RightShoulder")
		axis = "X"
	else
		local torso = character:FindFirstChild("Torso")
		shoulder = torso and torso:FindFirstChild("Right Shoulder")
		axis = "Z"
	end
	if not shoulder or not shoulder:IsA("Motor6D") then
		return
	end
	if session.shoulder ~= shoulder then
		session.shoulder = shoulder
		session.shoulderC0 = shoulder.C0
	end
	local rest = session.shoulderC0
	local function rotated(angle)
		return axis == "X" and rest * CFrame.Angles(math.rad(angle), 0, 0) or rest * CFrame.Angles(0, 0, math.rad(angle))
	end
	if session.swingTween then
		session.swingTween:Cancel()
	end
	local raise = TweenService:Create(shoulder, TweenInfo.new(0.08, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { C0 = rotated(110) })
	session.swingTween = raise
	raise:Play()
	task.delay(0.08, function()
		if session.swingTween ~= raise then
			return
		end
		local slash = TweenService:Create(shoulder, TweenInfo.new(0.12, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { C0 = rotated(-20) })
		session.swingTween = slash
		slash:Play()
		task.delay(0.14, function()
			if session.swingTween ~= slash then
				return
			end
			local back = TweenService:Create(shoulder, TweenInfo.new(0.15), { C0 = rest })
			session.swingTween = back
			back:Play()
		end)
	end)
end

local function attack(session)
	local player = session.player
	local character = player.Character
	local hrp = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not hrp or not humanoid or humanoid.Health <= 0 then
		return
	end
	local weapon = Config.GetWeapon(session.data.weapon)
	if os.clock() - (session.lastAttack or 0) < weapon.cooldown * 0.9 then
		return
	end
	session.lastAttack = os.clock()
	swingArm(session, character)
	if session.swingSound and session.swingSound.Parent then
		session.swingSound.PlaybackSpeed = rng:NextNumber(0.9, 1.15)
		session.swingSound:Play()
	end

	-- swing effect
	local slash = makePart({
		Size = Vector3.new(weapon.range * 0.7, 0.15, 0.6),
		CFrame = hrp.CFrame * CFrame.new(0, 0.5, -weapon.range * 0.45) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-25, 25))),
		Color = weapon.tip,
		Material = Enum.Material.Neon,
		Transparency = 0.3,
		CanCollide = false,
		CanQuery = false,
	})
	TweenService:Create(slash, TweenInfo.new(0.15), { Transparency = 1 }):Play()
	task.delay(0.2, function()
		slash:Destroy()
	end)

	local myArena = arenaAt(hrp.Position)
	local best, bestScore = nil, math.huge
	for _, enemy in ipairs(Enemies) do
		if enemy.alive and enemy.arena == myArena then
			local offset = enemy.root.Position - hrp.Position
			local flat = Vector3.new(offset.X, 0, offset.Z)
			local distance = flat.Magnitude - enemy.radius
			if distance <= weapon.range and math.abs(offset.Y) < enemy.radius + 14 then
				local facing = flat.Magnitude > 0.1 and hrp.CFrame.LookVector:Dot(flat.Unit) or 1
				if facing > 0.1 or distance < 4 then
					local score = distance - facing * 5
					if score < bestScore then
						best, bestScore = enemy, score
					end
				end
			end
		end
	end
	if best then
		damageEnemy(best, session, weapon.damage * getMultipliers(session).damage)
	end
end

local function weaponPart(tool, props, offset, handle)
	props.Parent = tool
	props.Anchored = false
	props.CanCollide = false
	props.Massless = true
	props.CFrame = handle.CFrame * offset
	local part = makePart(props)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = handle
	weld.Part1 = part
	weld.Parent = part
	return part
end

giveWeaponTool = function(session)
	local player = session.player
	local backpack = player:FindFirstChildOfClass("Backpack")
	for _, container in ipairs({ backpack, player.Character }) do
		if container then
			for _, item in ipairs(container:GetChildren()) do
				if item:IsA("Tool") and item:GetAttribute("SalvageWeapon") then
					item:Destroy()
				end
			end
		end
	end
	if not backpack then
		return
	end
	local weapon = Config.GetWeapon(session.data.weapon)
	local tool = Instance.new("Tool")
	tool.Name = weapon.name
	tool.CanBeDropped = false
	tool.ToolTip = weapon.damage .. " damage"
	tool:SetAttribute("SalvageWeapon", true)
	local tipMaterial = weapon.glow and Enum.Material.Neon or Enum.Material.Metal
	local isBlade = weapon.style == "blade"
	local handle = makePart({
		Name = "Handle",
		Size = isBlade and Vector3.new(0.3, 0.3, 1.4) or Vector3.new(0.3, 0.3, 5),
		CFrame = CFrame.new(),
		Color = weapon.color,
		Material = weapon.style == "spear" and Enum.Material.Wood or Enum.Material.Metal,
		Anchored = false,
		CanCollide = false,
		Parent = tool,
	})
	if isBlade then
		weaponPart(tool, { Size = Vector3.new(1.2, 0.2, 0.3), Color = weapon.tip, Material = Enum.Material.Metal }, CFrame.new(0, 0, -0.8), handle)
		weaponPart(tool, { Size = Vector3.new(0.12, 0.55, 3.2), Color = weapon.tip, Material = tipMaterial }, CFrame.new(0, 0, -2.5), handle)
	else
		tool.Grip = CFrame.new(0, 0, 1.2)
		if weapon.style == "trident" then
			weaponPart(tool, { Size = Vector3.new(1.4, 0.2, 0.2), Color = weapon.tip, Material = tipMaterial }, CFrame.new(0, 0, -2.5), handle)
			for _, x in ipairs({ -0.6, 0, 0.6 }) do
				weaponPart(tool, { Size = Vector3.new(0.16, 0.16, 1.1), Color = weapon.tip, Material = tipMaterial }, CFrame.new(x, 0, -3.1), handle)
			end
		else
			weaponPart(tool, { Size = Vector3.new(0.5, 0.5, 0.5), Color = weapon.tip, Material = tipMaterial },
				CFrame.new(0, 0, -2.75) * CFrame.Angles(0, math.rad(45), 0), handle)
			weaponPart(tool, { Size = Vector3.new(0.25, 0.25, 1.1), Color = weapon.tip, Material = tipMaterial }, CFrame.new(0, 0, -3.3), handle)
			if weapon.style == "harpoon" then
				for _, x in ipairs({ -0.3, 0.3 }) do
					weaponPart(tool, { Size = Vector3.new(0.1, 0.1, 0.6), Color = weapon.tip, Material = tipMaterial },
						CFrame.new(x, 0, -3.0) * CFrame.Angles(0, x > 0 and -0.6 or 0.6, 0), handle)
				end
			end
		end
	end
	if weapon.glow then
		local light = Instance.new("PointLight")
		light.Color = weapon.tip
		light.Range = 8
		light.Parent = handle
	end
	local swing = Instance.new("Sound")
	swing.Name = "Swing"
	swing.SoundId = "rbxasset://sounds/swordslash.wav" -- built into Roblox
	swing.Volume = 0.5
	swing.Parent = handle
	session.swingSound = swing
	tool.Activated:Connect(function()
		attack(session)
	end)
	tool.Parent = backpack
end

local function buyWeapon(session, id)
	local data = session.data
	local weapon = Config.GetWeapon(id)
	if not weapon or weapon.seasonOnly then
		return
	end
	if table.find(data.weapons, id) then
		notify(session.player, { kind = "error", text = "You already own " .. weapon.name .. "." })
		return
	end
	local wallet = weapon.currency == "Pearls" and "pearls" or "coins"
	if data[wallet] < weapon.price then
		notify(session.player, { kind = "error", text = "Not enough " .. weapon.currency .. "!" })
		return
	end
	data[wallet] -= weapon.price
	table.insert(data.weapons, id)
	data.weapon = id
	giveWeaponTool(session)
	notify(session.player, { kind = "info", text = weapon.name .. " equipped! Click to attack in the hunting grounds." })
	pushState(session)
end

local function equipWeapon(session, id)
	if table.find(session.data.weapons, id) then
		session.data.weapon = id
		giveWeaponTool(session)
		pushState(session)
	end
end

---------------------------------------------------------------------------
-- ENEMY AI (only runs in arenas that have players in them)
---------------------------------------------------------------------------

local occupancyTimer = 0
RunService.Heartbeat:Connect(function(dt)
	occupancyTimer += dt
	if occupancyTimer >= 0.25 then
		occupancyTimer = 0
		for _, arena in ipairs(Arenas) do
			arena.players = {}
		end
		for player, session in pairs(Sessions) do
			local character = player.Character
			local hrp = character and character:FindFirstChild("HumanoidRootPart")
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if session.loaded and hrp and humanoid and humanoid.Health > 0 then
				local arena = arenaAt(hrp.Position)
				if arena and session.data.level < arena.def.level then
					-- got in without using the portal (or rebirthed inside): send them home
					teleportToBay(session)
					notify(player, { kind = "error", text = "You need Level " .. arena.def.level .. " for this hunting ground." })
				elseif arena then
					table.insert(arena.players, { player = player, hrp = hrp, humanoid = humanoid })
				end
			end
		end
		local clock = os.clock()
		for _, arena in ipairs(Arenas) do
			if #arena.players == 0 then
				if #arena.enemies > 0 and clock - arena.emptySince > 20 then
					for i = #arena.enemies, 1, -1 do
						removeEnemy(arena.enemies[i])
					end
				end
				arena.nextBoss = nil
			else
				arena.emptySince = clock
				local regular = 0
				local bossAlive = false
				for _, enemy in ipairs(arena.enemies) do
					if enemy.def.boss then
						bossAlive = true
					else
						regular += 1
					end
				end
				if regular < arena.def.maxEnemies and clock >= arena.respawnAt then
					spawnEnemy(arena, arena.def.enemies[rng:NextInteger(1, #arena.def.enemies)])
					arena.respawnAt = clock + (regular == 0 and 0 or 3)
				end
				if arena.def.boss then
					arena.nextBoss = arena.nextBoss or (clock + 60)
					if not bossAlive and clock >= arena.nextBoss then
						spawnEnemy(arena, arena.def.boss)
						arena.nextBoss = clock + Config.BossInterval
						announce("THE LEVIATHAN RISES IN THE ABYSS!", Color3.fromRGB(255, 60, 90))
					end
				end
			end
		end
	end

	local t = os.clock()
	for _, enemy in ipairs(Enemies) do
		local arena = enemy.arena
		if enemy.alive and #arena.players > 0 then
			local def = enemy.def
			local target, targetDistance = nil, math.huge
			local aggro = def.boss and 200 or Config.EnemyAggroRange
			for _, info in ipairs(arena.players) do
				local flat = Vector3.new(info.hrp.Position.X - enemy.pos.X, 0, info.hrp.Position.Z - enemy.pos.Z)
				local distance = flat.Magnitude - enemy.radius
				if distance < aggro and distance < targetDistance then
					target, targetDistance = info, distance
				end
			end
			local goal
			local speed = def.speed
			if target then
				goal = target.hrp.Position
				if targetDistance <= def.reach and t - enemy.lastAttack >= (def.attackCooldown or Config.EnemyAttackCooldown) then
					enemy.lastAttack = t
					target.humanoid:TakeDamage(def.damage)
					enemy.lungeAt = t
					damageNumber(target.hrp.Position, def.damage, Color3.fromRGB(255, 80, 80))
					burst(target.hrp.Position, Color3.fromRGB(255, 60, 60), 1.5)
				end
			else
				if (enemy.wander - enemy.pos).Magnitude < 3 then
					enemy.wander = enemy.home + Vector3.new(rng:NextNumber(-25, 25), 0, rng:NextNumber(-25, 25))
				end
				goal = enemy.wander
				speed *= 0.4
			end
			local flatGoal = Vector3.new(goal.X - enemy.pos.X, 0, goal.Z - enemy.pos.Z)
			local direction = flatGoal.Magnitude > 0.01 and flatGoal.Unit or Vector3.new(0, 0, -1)
			local stopAt = target and def.reach * 0.7 or 0
			if flatGoal.Magnitude - (target and enemy.radius or 0) > stopAt then
				local step = math.min(speed * dt, flatGoal.Magnitude)
				enemy.pos += direction * step
			end
			local c = arena.center
			local margin = ARENA_HALF - enemy.radius - 4
			enemy.pos = Vector3.new(
				math.clamp(enemy.pos.X, c.X - margin, c.X + margin),
				enemyFloorY(enemy),
				math.clamp(enemy.pos.Z, c.Z - margin, c.Z + margin)
			)
			-- procedural animation: swim wiggle / crab waddle, lunge when biting,
			-- recoil when hit, rise + grow when spawning
			local swimmer = def.height > 0
			local chasing = target ~= nil
			local bob = swimmer and math.sin(t * 2 + enemy.phase) * 0.6 or 0
			local yaw = swimmer and math.sin(t * (chasing and 9 or 5) + enemy.phase) * 0.14 or 0
			local roll = swimmer and 0 or math.sin(t * 12 + enemy.phase) * 0.09
			local forward, pitch = 0, 0
			if enemy.lungeAt then
				local p = (t - enemy.lungeAt) / 0.3
				if p < 1 then
					local s = math.sin(p * math.pi)
					forward += s * math.min(def.reach * 0.5, 6)
					pitch -= s * 0.25
				end
			end
			if enemy.hitAt then
				local p = (t - enemy.hitAt) / 0.2
				if p < 1 then
					local s = math.sin(p * math.pi)
					forward -= s * 1.2
					pitch += s * 0.2
				end
			end
			local appear = math.clamp((t - enemy.spawnedAt) / 0.6, 0, 1)
			if appear < 1 then
				scaleModel(enemy.model, 0.3 + 0.7 * appear)
			elseif not enemy.fullSize then
				enemy.fullSize = true
				scaleModel(enemy.model, 1)
			end
			local position = enemy.pos + Vector3.new(0, bob - (1 - appear) * 4, 0)
			enemy.root.CFrame = CFrame.lookAt(position, position + direction)
				* CFrame.new(0, 0, -forward) * CFrame.Angles(pitch, yaw, roll)
		end
	end
end)

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

	local leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	local levelValue = Instance.new("IntValue")
	levelValue.Name = "Level"
	levelValue.Value = 1
	levelValue.Parent = leaderstats
	local rebirthsValue = Instance.new("IntValue")
	rebirthsValue.Name = "Rebirths"
	rebirthsValue.Parent = leaderstats
	local shipsValue = Instance.new("IntValue")
	shipsValue.Name = "Ships"
	shipsValue.Parent = leaderstats
	leaderstats.Parent = player

	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("HumanoidRootPart", 10)
		character:WaitForChild("Head", 10)
		task.wait(0.1)
		session.acLast = nil
		teleportToBay(session)
		if session.loaded then
			updatePublicInfo(session)
			player:WaitForChild("Backpack", 5)
			giveWeaponTool(session)
		end
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
	refreshPasses(session)
	refreshQuests(session)
	if not session.active then
		return
	end
	session.loaded = true

	for i = 1, #data.subs do
		addFleetEntry(session, i)
	end
	for slot, def in ipairs(Config.Ships) do
		if data.ships[def.id] then
			session.shipModels[def.id] = buildShipModel(def, bay.shipSlots[slot], bay.folder)
		end
	end

	grantSeasonRewards(session)
	updatePublicInfo(session)
	giveWeaponTool(session)
	pushState(session)
	notify(player, { kind = "welcome", canSave = canSave })
	if loginStatus(data).canClaim then
		notify(player, { kind = "dailyAvailable" })
	end
end

local function onPlayerRemoving(player)
	local session = Sessions[player]
	if not session then
		return
	end
	session.active = false
	local trade = Trades[player]
	if trade then
		endTrade(trade, player.DisplayName .. " left, so the trade was cancelled.", Color3.fromRGB(255, 95, 95))
	end
	TradeRequests[player] = nil
	Sessions[player] = nil
	if session.loaded then
		saveData(session)
		writeLeaderboards(session)
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

-- Autosave every minute (spread out so we don't hit DataStore limits) + leaderboards
local LeaderboardStores = {}
for _, lb in ipairs(Config.Leaderboards) do
	pcall(function()
		LeaderboardStores[lb.id] = DataStoreService:GetOrderedDataStore("LB_" .. lb.id .. "_v1")
	end)
end

writeLeaderboards = function(session)
	if not session.canSave then
		return
	end
	session.lbWritten = session.lbWritten or {}
	for _, lb in ipairs(Config.Leaderboards) do
		local lbStore = LeaderboardStores[lb.id]
		local value = math.floor(lb.value(session.data) or 0)
		if lbStore and value > 0 and session.lbWritten[lb.id] ~= value then
			local ok = pcall(function()
				lbStore:SetAsync(tostring(session.player.UserId), value)
			end)
			if ok then
				session.lbWritten[lb.id] = value
			end
		end
	end
end

task.spawn(function()
	while true do
		task.wait(Config.AutosaveInterval)
		local list = {}
		for _, session in pairs(Sessions) do
			if session.loaded then
				table.insert(list, session)
			end
		end
		local gap = math.min(2, Config.AutosaveInterval / math.max(1, #list) / 2)
		for _, session in ipairs(list) do
			task.spawn(function()
				saveData(session)
				writeLeaderboards(session)
			end)
			task.wait(gap)
		end
	end
end)

---------------------------------------------------------------------------
-- LEADERBOARD BOARDS on the island
---------------------------------------------------------------------------
local Boards = {}
local nameCache = {}

local function playerName(userId)
	if nameCache[userId] then
		return nameCache[userId]
	end
	local ok, name = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	if ok and name then
		nameCache[userId] = name
		return name
	end
	return "Player " .. userId
end

local function buildBoard(lb, position)
	local cf = CFrame.lookAt(position, position + Vector3.new(0, 0, -1))
	for _, x in ipairs({ -6.5, 6.5 }) do
		makePart({
			Size = Vector3.new(1, 15, 1),
			CFrame = cf * CFrame.new(x, -1.5, 0.6),
			Color = Color3.fromRGB(100, 70, 45),
			Material = Enum.Material.Wood,
		})
	end
	local board = makePart({
		Name = "Leaderboard_" .. lb.id,
		Size = Vector3.new(14, 12, 0.8),
		CFrame = cf,
		Color = Color3.fromRGB(14, 32, 52),
		Material = Enum.Material.SmoothPlastic,
	})
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	gui.PixelsPerStud = 40
	gui.Parent = board
	local title = Instance.new("TextLabel")
	title.Size = UDim2.new(1, 0, 0.13, 0)
	title.BackgroundColor3 = lb.color
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(14, 32, 52)
	title.Text = lb.title
	title.Parent = gui
	local rows = {}
	for i = 1, 10 do
		local row = Instance.new("TextLabel")
		row.Size = UDim2.new(0.94, 0, 0.082, 0)
		row.Position = UDim2.new(0.03, 0, 0.15 + (i - 1) * 0.085, 0)
		row.BackgroundTransparency = i % 2 == 0 and 1 or 0.85
		row.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
		row.Font = i <= 3 and Enum.Font.GothamBlack or Enum.Font.GothamBold
		row.TextScaled = true
		row.TextXAlignment = Enum.TextXAlignment.Left
		row.TextColor3 = i == 1 and Color3.fromRGB(255, 205, 80) or (i == 2 and Color3.fromRGB(220, 225, 235)
			or (i == 3 and Color3.fromRGB(230, 150, 90) or Color3.fromRGB(235, 245, 250)))
		row.Text = ""
		row.Parent = gui
		rows[i] = row
	end
	rows[1].Text = "  Loading..."
	Boards[lb.id] = rows
end

local function refreshBoards()
	for _, lb in ipairs(Config.Leaderboards) do
		local rows = Boards[lb.id]
		local lbStore = LeaderboardStores[lb.id]
		local ok, page = false, nil
		if lbStore then
			ok, page = pcall(function()
				return lbStore:GetSortedAsync(false, 10):GetCurrentPage()
			end)
		end
		for i = 1, 10 do
			rows[i].Text = ""
		end
		if not ok then
			rows[1].Text = "  Publish the game + turn on API access"
			rows[2].Text = "  to see global leaderboards."
		elseif #page == 0 then
			rows[1].Text = "  Nobody yet. Be the first!"
		else
			for i, entry in ipairs(page) do
				rows[i].Text = string.format("  #%d  %s  -  %s", i, playerName(tonumber(entry.key)), Config.FormatNumber(entry.value))
			end
		end
	end
end

for i, lb in ipairs(Config.Leaderboards) do
	buildBoard(lb, Vector3.new((i - 2) * 18, 9.6, 42))
end
task.spawn(function()
	while true do
		refreshBoards()
		task.wait(Config.LeaderboardRefresh)
	end
end)

---------------------------------------------------------------------------
-- LIVE PRICES: show what Roblox will really charge (the Creator Dashboard price)
---------------------------------------------------------------------------
task.spawn(function()
	for _, pass in ipairs(Config.GamePasses) do
		if pass.id ~= 0 then
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(pass.id, Enum.InfoType.GamePass)
			end)
			if ok and info and info.PriceInRobux then
				LivePrices[pass.key] = info.PriceInRobux
			end
		end
	end
	for _, product in ipairs(Config.Products) do
		if product.id ~= 0 then
			local ok, info = pcall(function()
				return MarketplaceService:GetProductInfo(product.id, Enum.InfoType.Product)
			end)
			if ok and info and info.PriceInRobux then
				LivePrices[product.key] = info.PriceInRobux
				if info.PriceInRobux ~= product.price then
					warn(string.format("[Salvage] %s costs %d R$ on Roblox but %d in the config. Players see the Roblox price.",
						product.name, info.PriceInRobux, product.price))
				end
			end
		end
	end
end)

---------------------------------------------------------------------------
-- ANTI-CHEAT: the server watches every character's movement. Moving faster
-- than WalkSpeed allows, flying up too fast or too high puts you back where
-- you were and gives a strike. Too many strikes in a minute = kick.
-- (WalkSpeed changes made by a cheat on their own computer don't reach the
-- server, so the server's WalkSpeed is the real limit.)
---------------------------------------------------------------------------
local function strike(session, reason)
	local ac = Config.AntiCheat
	local clock = os.clock()
	session.acStrikes = session.acStrikes or {}
	table.insert(session.acStrikes, clock)
	while session.acStrikes[1] and clock - session.acStrikes[1] > ac.strikeWindow do
		table.remove(session.acStrikes, 1)
	end
	warn(string.format("[Salvage AntiCheat] %s: %s (%d strikes)", session.player.Name, reason, #session.acStrikes))
	if ac.kick and #session.acStrikes >= ac.strikesToKick then
		session.player:Kick("Unusual movement was detected. Please rejoin without any cheats.")
	end
end

task.spawn(function()
	local ac = Config.AntiCheat
	while true do
		task.wait(ac.interval)
		if ac.enabled then
			local clock = os.clock()
			for player, session in pairs(Sessions) do
				local character = player.Character
				local hrp = character and character:FindFirstChild("HumanoidRootPart")
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				if session.loaded and hrp and humanoid and humanoid.Health > 0 then
					local pos = hrp.Position
					local last = session.acLast
					if session.acGraceUntil and clock < session.acGraceUntil then
						session.acLast = { pos = pos, t = clock }
					elseif last then
						local dt = math.max(clock - last.t, 0.05)
						local flat = Vector3.new(pos.X - last.pos.X, 0, pos.Z - last.pos.Z).Magnitude
						local rise = pos.Y - last.pos.Y
						local maxFlat = humanoid.WalkSpeed * ac.speedTolerance * dt + ac.extraStuds
						local maxRise = ac.maxRiseSpeed * dt + ac.extraStuds
						local reason
						if flat > maxFlat then
							reason = string.format("moved %.0f studs in %.1fs", flat, dt)
						elseif rise > maxRise then
							reason = string.format("rose %.0f studs in %.1fs", rise, dt)
						elseif pos.Y > ac.maxHeight then
							reason = string.format("too high (y=%.0f)", pos.Y)
						end
						if reason then
							-- put them back where they were
							session.acGraceUntil = clock + 0.5
							character:PivotTo(CFrame.new(last.pos))
							strike(session, reason)
						else
							session.acLast = { pos = pos, t = clock }
						end
					else
						session.acLast = { pos = pos, t = clock }
					end
				end
			end
		end
	end
end)

---------------------------------------------------------------------------
-- CLIENT ACTIONS
---------------------------------------------------------------------------
Action.OnServerEvent:Connect(function(player, action, arg1, arg2)
	local session = Sessions[player]
	if not session or not session.loaded or typeof(action) ~= "string" then
		return
	end
	-- rate limit: about 12 actions a second, bursts of 20 (stops remote spam)
	local clock = os.clock()
	session.tokens = math.min(20, (session.tokens or 20) + (clock - (session.lastTokenTime or clock)) * 12)
	session.lastTokenTime = clock
	if session.tokens < 1 then
		return
	end
	session.tokens -= 1
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
	elseif action == "HatchEgg" and typeof(arg1) == "string" then
		hatchEgg(session, arg1)
	elseif action == "EquipPet" and typeof(arg1) == "number" then
		toggleEquip(session, arg1)
	elseif action == "EquipBest" then
		equipBest(session)
	elseif action == "ReleasePet" and typeof(arg1) == "number" then
		releasePet(session, arg1)
	elseif action == "SellSpares" then
		sellSpares(session)
	elseif action == "SetAutoSell" and typeof(arg1) == "boolean" then
		data.autoSell = arg1
		pushState(session)
	elseif action == "ClaimQuest" and typeof(arg1) == "string" and typeof(arg2) == "number" then
		claimQuest(session, arg1, math.floor(arg2))
	elseif action == "Rebirth" then
		doRebirth(session, false)
	elseif action == "ClaimDaily" then
		claimDaily(session)
	elseif action == "EquipCharm" and typeof(arg1) == "string" then
		toggleCharm(session, arg1)
	elseif action == "DissolveCharm" and typeof(arg1) == "string" then
		dissolveCharm(session, arg1)
	elseif action == "SeasonPrestige" then
		seasonPrestige(session)
	elseif action == "Buy" and typeof(arg1) == "string" then
		handleBuy(session, arg1)
	elseif action == "BuyWeapon" and typeof(arg1) == "string" then
		buyWeapon(session, arg1)
	elseif action == "EquipWeapon" and typeof(arg1) == "string" then
		equipWeapon(session, arg1)
	elseif string.sub(tostring(action), 1, 5) == "Trade" then
		handleTradeAction(player, session, action, arg1, arg2)
	elseif action == "RequestState" then
		refreshQuests(session)
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
			if not session or not session.loaded or chest:GetAttribute("Claimed") or not isNear(who, chest, 12) then
				return
			end
			chest:SetAttribute("Claimed", true)
			session.data.pearls += Config.TreasureChestPearls
			session.data.coins += Config.TreasureChestCoins
			questProgress(session, "chests", 1)
			addSeasonXP(session, 50)
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
			questProgress(session, "krakenHits", 1)
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
					local gotEgg = session.krakenHits >= Config.KrakenEggMinHits
					if gotEgg then
						session.data.eggs.Kraken = (session.data.eggs.Kraken or 0) + 1
					end
					notify(session.player, { kind = "kraken", coins = coins, pearls = pearls, hits = session.krakenHits, egg = gotEgg })
					addSeasonXP(session, Config.Season.xpPerEvent)
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
