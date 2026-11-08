--[[
	DEEP SEA SALVAGE - Shared creature models
	Type: ModuleScript
	Name it exactly: SalvageModels
	Put it in: ReplicatedStorage

	Builds pets and enemies out of parts. The client uses it for pets and the
	pet previews; the server uses it for the enemies in the hunting grounds.
	Models.Build(def, scale) works for anything with a shape, color and accent
	(see Config.Pets and Config.Enemies).
]]

local Models = {}

local function new(className, props)
	local obj = Instance.new(className)
	for key, value in pairs(props or {}) do
		if key ~= "Parent" then
			obj[key] = value
		end
	end
	if props and props.Parent then
		obj.Parent = props.Parent
	end
	return obj
end

local function petPart(model, size, cf, color, material, transparency, shape)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Transparency = transparency or 0
	p.Parent = model
	return p
end

local function ellipsoid(model, size, cf, color, material, transparency)
	local p = petPart(model, size, cf, color, material, transparency)
	new("SpecialMesh", { MeshType = Enum.MeshType.Sphere, Parent = p })
	return p
end

local function ball(model, d, cf, color, material)
	return petPart(model, Vector3.new(d, d, d), cf, color, material, 0, Enum.PartType.Ball)
end

function Models.Build(def, scale)
	local model = Instance.new("Model")
	model.Name = def.id
	local s = (scale or 1) * (0.8 + (def.rarity or 1) * 0.12)
	local root = petPart(model, Vector3.new(0.2, 0.2, 0.2), CFrame.new(), def.color, nil, 1)
	root.Name = "Root"
	model.PrimaryPart = root

	local function C(x, y, z)
		return CFrame.new(x * s, y * s, z * s)
	end
	local accentMat = def.glow and Enum.Material.Neon or Enum.Material.SmoothPlastic
	local function eyes(x, y, z, size)
		local e = size or 1
		for _, side in ipairs({ -1, 1 }) do
			ball(model, 0.32 * s * e, C(side * x, y, z), Color3.new(1, 1, 1))
			ball(model, 0.17 * s * e, C(side * x * 1.05, y, z - 0.12 * e),
				def.angry and Color3.fromRGB(255, 30, 30) or Color3.new(0.05, 0.05, 0.05), def.angry and Enum.Material.Neon or nil)
		end
	end

	local shape = def.shape
	if shape == "fish" then
		local body = def.round and Vector3.new(1.6, 1.5, 1.7) or Vector3.new(1.0, 1.2, 2.0)
		ellipsoid(model, body * s, C(0, 0, 0), def.color)
		if def.stripes then
			for _, z in ipairs({ -0.35, 0.35 }) do
				ellipsoid(model, Vector3.new(body.X + 0.05, body.Y + 0.05, 0.25) * s, C(0, 0, z), def.accent)
			end
		end
		for _, a in ipairs({ 35, -35 }) do
			petPart(model, Vector3.new(0.12, 0.8, 0.6) * s, C(0, a > 0 and 0.2 or -0.2, body.Z / 2 + 0.25) * CFrame.Angles(math.rad(a), 0, 0),
				def.accent, accentMat)
		end
		if def.fin then
			petPart(model, Vector3.new(0.15, 1.0, 0.8) * s, C(0, body.Y / 2 + 0.3, 0.1) * CFrame.Angles(math.rad(-25), 0, 0), def.accent, accentMat)
		else
			petPart(model, Vector3.new(0.1, 0.45, 0.8) * s, C(0, body.Y / 2, 0.1), def.accent, accentMat)
		end
		for _, side in ipairs({ -1, 1 }) do
			petPart(model, Vector3.new(0.5, 0.08, 0.35) * s, C(side * body.X / 2, -0.2, -0.1) * CFrame.Angles(0, 0, side * 0.4), def.accent, accentMat)
		end
		if def.round then
			for k = 0, 7 do
				local a = k * math.pi / 4
				petPart(model, Vector3.new(0.12, 0.35, 0.12) * s,
					CFrame.Angles(0, 0, a) * C(0, body.Y / 2 + 0.05, 0), def.accent)
			end
		end
		if def.lure then
			petPart(model, Vector3.new(0.07, 0.07, 1.0) * s, C(0, body.Y / 2 + 0.35, -body.Z / 2 + 0.1) * CFrame.Angles(math.rad(35), 0, 0), def.color)
			local bulb = ball(model, 0.4 * s, C(0, body.Y / 2 + 0.6, -body.Z / 2 - 0.35), def.accent, Enum.Material.Neon)
			new("PointLight", { Color = def.accent, Range = 6, Brightness = 2, Parent = bulb })
		end
		eyes(body.X * 0.36, 0.15, -body.Z * 0.32)
	elseif shape == "crab" then
		ellipsoid(model, Vector3.new(1.8, 0.8, 1.3) * s, C(0, 0, 0), def.color)
		ellipsoid(model, Vector3.new(1.4, 0.5, 1.0) * s, C(0, 0.2, 0.05), def.accent)
		for _, side in ipairs({ -1, 1 }) do
			for k = 1, 3 do
				petPart(model, Vector3.new(0.9, 0.12, 0.12) * s, C(side * 1.0, -0.25, -0.35 + k * 0.3) * CFrame.Angles(0, 0, side * -0.5), def.color)
			end
			petPart(model, Vector3.new(0.15, 0.15, 0.6) * s, C(side * 0.7, 0, -0.75), def.color)
			ellipsoid(model, Vector3.new(0.55, 0.45, 0.65) * s, C(side * 0.85, 0.05, -1.15), def.color)
			petPart(model, Vector3.new(0.08, 0.45, 0.08) * s, C(side * 0.25, 0.55, -0.45), def.color)
			ball(model, 0.26 * s, C(side * 0.25, 0.8, -0.45), Color3.new(1, 1, 1))
			ball(model, 0.14 * s, C(side * 0.25, 0.8, -0.56), Color3.new(0.05, 0.05, 0.05))
		end
	elseif shape == "star" then
		ellipsoid(model, Vector3.new(0.8, 0.8, 0.4) * s, C(0, 0, 0), def.color)
		for k = 0, 4 do
			local rot = CFrame.Angles(0, 0, math.rad(k * 72))
			ellipsoid(model, Vector3.new(0.5, 1.2, 0.3) * s, rot * C(0, 0.65, 0), def.color)
			ball(model, 0.16 * s, rot * C(0, 0.8, -0.13), def.accent)
		end
		eyes(0.16, 0.08, -0.2, 0.7)
	elseif shape == "turtle" then
		ellipsoid(model, Vector3.new(1.8, 0.9, 2.1) * s, C(0, 0.15, 0), def.color)
		ellipsoid(model, Vector3.new(1.6, 0.5, 1.9) * s, C(0, -0.15, 0), def.accent)
		for _, z in ipairs({ -0.45, 0.05, 0.55 }) do
			ellipsoid(model, Vector3.new(0.55, 0.2, 0.45) * s, C(0, 0.55, z), def.accent)
		end
		ellipsoid(model, Vector3.new(0.6, 0.55, 0.75) * s, C(0, 0.05, -1.25), def.accent)
		eyes(0.2, 0.15, -1.45, 0.7)
		for _, side in ipairs({ -1, 1 }) do
			petPart(model, Vector3.new(1.0, 0.12, 0.45) * s, C(side * 1.05, -0.05, -0.55) * CFrame.Angles(0, side * math.rad(-25), 0), def.accent)
			petPart(model, Vector3.new(0.6, 0.12, 0.35) * s, C(side * 0.85, -0.05, 0.75) * CFrame.Angles(0, side * math.rad(25), 0), def.accent)
		end
	elseif shape == "jelly" then
		ellipsoid(model, Vector3.new(1.8, 1.3, 1.8) * s, C(0, 0.4, 0), def.color, accentMat, 0.25)
		ellipsoid(model, Vector3.new(1.0, 0.7, 1.0) * s, C(0, 0.35, 0), def.accent, accentMat, 0.2)
		for k = 0, 5 do
			local a = k * math.pi / 3
			petPart(model, Vector3.new(0.1, 1.4, 0.1) * s,
				CFrame.new(math.cos(a) * 0.55 * s, -0.55 * s, math.sin(a) * 0.55 * s) * CFrame.Angles(math.sin(a) * 0.2, 0, math.cos(a) * 0.2),
				def.accent, accentMat, 0.3)
		end
		eyes(0.3, 0.3, -0.82, 0.8)
	elseif shape == "octopus" then
		ellipsoid(model, Vector3.new(1.4, 1.7, 1.4) * s, C(0, 0.55, 0.1), def.color)
		for _, pos in ipairs({ { 0.35, 0.9, 0.5 }, { -0.4, 1.0, 0.35 }, { 0.1, 1.25, 0.2 } }) do
			ball(model, 0.22 * s, C(pos[1], pos[2], pos[3] - 0.6), def.accent, accentMat)
		end
		for k = 0, 7 do
			local rot = CFrame.Angles(0, math.rad(k * 45), 0)
			petPart(model, Vector3.new(0.22, 1.3, 0.22) * s, rot * C(0, -0.45, -0.5) * CFrame.Angles(math.rad(-35), 0, 0), def.color)
			ball(model, 0.25 * s, rot * C(0, -0.95, -0.85), def.accent, accentMat)
		end
		eyes(0.32, 0.45, -0.55)
	elseif shape == "ray" then
		petPart(model, Vector3.new(2.35, 0.12, 2.35) * s, C(0, -0.05, 0) * CFrame.Angles(0, math.rad(45), 0), def.accent, accentMat)
		petPart(model, Vector3.new(2.2, 0.2, 2.2) * s, C(0, 0, 0) * CFrame.Angles(0, math.rad(45), 0), def.color)
		ellipsoid(model, Vector3.new(0.9, 0.45, 1.6) * s, C(0, 0.08, 0), def.color)
		petPart(model, Vector3.new(0.08, 0.08, 2.0) * s, C(0, 0, 2.0), def.color)
		ball(model, 0.18 * s, C(0, 0, 3.0), def.accent, accentMat)
		eyes(0.3, 0.22, -0.6, 0.7)
	else -- eel
		local segments = 6
		for i = 1, segments do
			local d = 0.9 - i * 0.08
			ball(model, d * s, C(math.sin(i * 0.9) * 0.3, 0, (i - 1) * 0.55), (i % 2 == 0) and def.accent or def.color,
				(i % 2 == 0) and accentMat or nil)
			if (def.rarity or 4) >= 4 then
				petPart(model, Vector3.new(0.05, 0.35, 0.3) * s, C(math.sin(i * 0.9) * 0.3, d * 0.5, (i - 1) * 0.55), def.accent, accentMat)
			end
		end
		ellipsoid(model, Vector3.new(0.9, 0.8, 1.2) * s, C(0, 0, -0.6), def.color)
		if (def.rarity or 4) >= 4 then
			for _, side in ipairs({ -1, 1 }) do
				petPart(model, Vector3.new(0.1, 0.55, 0.1) * s, C(side * 0.25, 0.5, -0.4) * CFrame.Angles(math.rad(30), 0, 0), def.accent, accentMat)
			end
		end
		eyes(0.25, 0.2, -0.95, 0.8)
	end

	if def.glow then
		new("PointLight", { Color = def.accent, Range = 8, Brightness = 1.5, Parent = root })
	end
	return model
end

-- Store icons (generated by tools/icons.py; the same data drives the preview page)
Models.Icons = {
	DoubleCoins = {
		{ "cyl", { 0.34, 2, 2 }, { 0, -1.15, 0.2 }, { 0, 0, 90 }, { 255, 200, 50 }, "metal", 0 },
		{ "cyl", { 0.34, 2, 2 }, { 0.12, -0.79, 0.15 }, { 0, 0, 90 }, { 205, 145, 30 }, "metal", 0 },
		{ "cyl", { 0.34, 2, 2 }, { -0.08, -0.43, 0.22 }, { 0, 0, 90 }, { 255, 200, 50 }, "metal", 0 },
		{ "cyl", { 0.34, 2, 2 }, { 0.05, -0.07, 0.18 }, { 0, 0, 90 }, { 205, 145, 30 }, "metal", 0 },
		{ "cyl", { 0.4, 2.1, 2.1 }, { 0.15, 0.55, -0.75 }, { 0, 80, 0 }, { 255, 200, 50 }, "metal", 0 },
		{ "cyl", { 0.08, 1.45, 1.45 }, { 0.12, 0.55, -0.97 }, { 0, 80, 0 }, { 255, 228, 120 }, "neon", 0 },
		{ "block", { 0.28, 0.75, 0.1 }, { 0.09, 0.55, -1.03 }, { 0, -10, 0 }, { 205, 145, 30 }, "metal", 0 },
	},
	BoostCoins = {
		{ "cyl", { 0.34, 2, 2 }, { 0, -1.15, 0.2 }, { 0, 0, 90 }, { 255, 200, 50 }, "metal", 0 },
		{ "cyl", { 0.34, 2, 2 }, { 0.12, -0.79, 0.15 }, { 0, 0, 90 }, { 205, 145, 30 }, "metal", 0 },
		{ "cyl", { 0.34, 2, 2 }, { -0.08, -0.43, 0.22 }, { 0, 0, 90 }, { 255, 200, 50 }, "metal", 0 },
		{ "cyl", { 0.34, 2, 2 }, { 0.05, -0.07, 0.18 }, { 0, 0, 90 }, { 205, 145, 30 }, "metal", 0 },
		{ "cyl", { 0.4, 2.1, 2.1 }, { 0.15, 0.55, -0.75 }, { 0, 80, 0 }, { 255, 200, 50 }, "metal", 0 },
		{ "cyl", { 0.08, 1.45, 1.45 }, { 0.12, 0.55, -0.97 }, { 0, 80, 0 }, { 255, 228, 120 }, "neon", 0 },
		{ "block", { 0.28, 0.75, 0.1 }, { 0.09, 0.55, -1.03 }, { 0, -10, 0 }, { 205, 145, 30 }, "metal", 0 },
	},
	LuckyDiver = {
		{ "ell", { 1.15, 1.45, 0.4 }, { -0.552, 0.752, 0 }, { 0, 0, 45 }, { 95, 205, 75 }, "plastic", 0 },
		{ "ell", { 0.25, 0.9, 0.42 }, { -0.537, 0.737, -0.02 }, { 0, 0, 45 }, { 150, 240, 120 }, "plastic", 0 },
		{ "ell", { 1.15, 1.45, 0.4 }, { -0.552, -0.352, 0 }, { 0, 0, 135 }, { 95, 205, 75 }, "plastic", 0 },
		{ "ell", { 0.25, 0.9, 0.42 }, { -0.537, -0.337, -0.02 }, { 0, 0, 135 }, { 150, 240, 120 }, "plastic", 0 },
		{ "ell", { 1.15, 1.45, 0.4 }, { 0.552, -0.352, 0 }, { 0, 0, 225 }, { 95, 205, 75 }, "plastic", 0 },
		{ "ell", { 0.25, 0.9, 0.42 }, { 0.537, -0.337, -0.02 }, { 0, 0, 225 }, { 150, 240, 120 }, "plastic", 0 },
		{ "ell", { 1.15, 1.45, 0.4 }, { 0.552, 0.752, 0 }, { 0, 0, 315 }, { 95, 205, 75 }, "plastic", 0 },
		{ "ell", { 0.25, 0.9, 0.42 }, { 0.537, 0.737, -0.02 }, { 0, 0, 315 }, { 150, 240, 120 }, "plastic", 0 },
		{ "ball", { 0.7, 0.7, 0.7 }, { 0, 0.2, -0.05 }, { 0, 0, 0 }, { 60, 160, 50 }, "plastic", 0 },
		{ "block", { 0.22, 1.5, 0.22 }, { 0.35, -1.3, 0 }, { 0, 0, -20 }, { 60, 150, 50 }, "plastic", 0 },
	},
	BoostLuck = {
		{ "ell", { 1.15, 1.45, 0.4 }, { -0.552, 0.752, 0 }, { 0, 0, 45 }, { 95, 205, 75 }, "plastic", 0 },
		{ "ell", { 0.25, 0.9, 0.42 }, { -0.537, 0.737, -0.02 }, { 0, 0, 45 }, { 150, 240, 120 }, "plastic", 0 },
		{ "ell", { 1.15, 1.45, 0.4 }, { -0.552, -0.352, 0 }, { 0, 0, 135 }, { 95, 205, 75 }, "plastic", 0 },
		{ "ell", { 0.25, 0.9, 0.42 }, { -0.537, -0.337, -0.02 }, { 0, 0, 135 }, { 150, 240, 120 }, "plastic", 0 },
		{ "ell", { 1.15, 1.45, 0.4 }, { 0.552, -0.352, 0 }, { 0, 0, 225 }, { 95, 205, 75 }, "plastic", 0 },
		{ "ell", { 0.25, 0.9, 0.42 }, { 0.537, -0.337, -0.02 }, { 0, 0, 225 }, { 150, 240, 120 }, "plastic", 0 },
		{ "ell", { 1.15, 1.45, 0.4 }, { 0.552, 0.752, 0 }, { 0, 0, 315 }, { 95, 205, 75 }, "plastic", 0 },
		{ "ell", { 0.25, 0.9, 0.42 }, { 0.537, 0.737, -0.02 }, { 0, 0, 315 }, { 150, 240, 120 }, "plastic", 0 },
		{ "ball", { 0.7, 0.7, 0.7 }, { 0, 0.2, -0.05 }, { 0, 0, 0 }, { 60, 160, 50 }, "plastic", 0 },
		{ "block", { 0.22, 1.5, 0.22 }, { 0.35, -1.3, 0 }, { 0, 0, -20 }, { 60, 150, 50 }, "plastic", 0 },
	},
	AutoHaul = {
		{ "block", { 2.2, 2, 2.2 }, { 0, -0.5, 0 }, { 0, 25, 0 }, { 160, 112, 64 }, "plastic", 0 },
		{ "block", { 2.3, 0.3, 2.3 }, { 0, 0.2, 0 }, { 0, 25, 0 }, { 95, 62, 34 }, "plastic", 0 },
		{ "block", { 2.3, 0.3, 2.3 }, { 0, -1.2, 0 }, { 0, 25, 0 }, { 95, 62, 34 }, "plastic", 0 },
		{ "block", { 2.25, 0.3, 0.3 }, { 0, -0.5, 0 }, { 0, 25, 45 }, { 255, 205, 70 }, "neon", 0 },
		{ "block", { 0.25, 1.4, 0.25 }, { 0, 1.25, 0 }, { 0, 0, 0 }, { 110, 115, 125 }, "metal", 0 },
		{ "ball", { 0.55, 0.55, 0.55 }, { 0, 0.55, 0 }, { 0, 0, 0 }, { 140, 145, 155 }, "metal", 0 },
		{ "block", { 2.6, 0.3, 0.3 }, { 0, 2, 0 }, { 0, 0, 0 }, { 255, 175, 40 }, "metal", 0 },
	},
	PetSlots = {
		{ "ell", { 1.8, 1.45, 0.55 }, { 0, -0.45, 0 }, { 0, 0, 0 }, { 255, 140, 195 }, "plastic", 0 },
		{ "ell", { 0.75, 0.95, 0.5 }, { -1, 0.55, 0 }, { 0, 0, 20 }, { 225, 85, 155 }, "plastic", 0 },
		{ "ell", { 0.75, 0.95, 0.5 }, { -0.35, 1, 0 }, { 0, 0, 5 }, { 225, 85, 155 }, "plastic", 0 },
		{ "ell", { 0.75, 0.95, 0.5 }, { 0.35, 1, 0 }, { 0, 0, -5 }, { 225, 85, 155 }, "plastic", 0 },
		{ "ell", { 0.75, 0.95, 0.5 }, { 1, 0.55, 0 }, { 0, 0, -20 }, { 225, 85, 155 }, "plastic", 0 },
	},
	VIP = {
		{ "cyl", { 0.9, 2.7, 2.7 }, { 0, -0.55, 0 }, { 0, 0, 90 }, { 255, 200, 50 }, "metal", 0 },
		{ "cyl", { 0.92, 2.2, 2.2 }, { 0, -0.55, 0 }, { 0, 0, 90 }, { 205, 145, 30 }, "metal", 0 },
		{ "block", { 0.55, 1.2, 0.3 }, { 0, 0.4, -1.15 }, { 0, 0, 0 }, { 255, 200, 50 }, "metal", 0 },
		{ "ball", { 0.45, 0.45, 0.45 }, { 0, 1.1, -1.15 }, { 0, 0, 0 }, { 255, 228, 120 }, "metal", 0 },
		{ "ball", { 0.42, 0.42, 0.42 }, { 0, -0.55, -1.242 }, { 0, 0, 0 }, { 255, 60, 80 }, "neon", 0 },
		{ "block", { 0.55, 1.2, 0.3 }, { 1.094, 0.4, -0.355 }, { 0, -72, 0 }, { 255, 200, 50 }, "metal", 0 },
		{ "ball", { 0.45, 0.45, 0.45 }, { 1.094, 1.1, -0.355 }, { 0, 0, 0 }, { 255, 228, 120 }, "metal", 0 },
		{ "ball", { 0.42, 0.42, 0.42 }, { 1.181, -0.55, -0.384 }, { 0, 0, 0 }, { 80, 170, 255 }, "neon", 0 },
		{ "block", { 0.55, 1.2, 0.3 }, { 0.676, 0.4, 0.93 }, { 0, -144, 0 }, { 255, 200, 50 }, "metal", 0 },
		{ "ball", { 0.45, 0.45, 0.45 }, { 0.676, 1.1, 0.93 }, { 0, 0, 0 }, { 255, 228, 120 }, "metal", 0 },
		{ "ball", { 0.42, 0.42, 0.42 }, { 0.73, -0.55, 1.005 }, { 0, 0, 0 }, { 90, 230, 120 }, "neon", 0 },
		{ "block", { 0.55, 1.2, 0.3 }, { -0.676, 0.4, 0.93 }, { 0, -216, 0 }, { 255, 200, 50 }, "metal", 0 },
		{ "ball", { 0.45, 0.45, 0.45 }, { -0.676, 1.1, 0.93 }, { 0, 0, 0 }, { 255, 228, 120 }, "metal", 0 },
		{ "ball", { 0.42, 0.42, 0.42 }, { -0.73, -0.55, 1.005 }, { 0, 0, 0 }, { 190, 100, 255 }, "neon", 0 },
		{ "block", { 0.55, 1.2, 0.3 }, { -1.094, 0.4, -0.355 }, { 0, -288, 0 }, { 255, 200, 50 }, "metal", 0 },
		{ "ball", { 0.45, 0.45, 0.45 }, { -1.094, 1.1, -0.355 }, { 0, 0, 0 }, { 255, 228, 120 }, "metal", 0 },
		{ "ball", { 0.42, 0.42, 0.42 }, { -1.181, -0.55, -0.384 }, { 0, 0, 0 }, { 255, 160, 40 }, "neon", 0 },
	},
	BigStorage = {
		{ "block", { 2.7, 1.5, 1.8 }, { 0, -0.55, 0 }, { 0, 20, 0 }, { 150, 95, 52 }, "plastic", 0 },
		{ "cyl", { 2.75, 1.82, 1.82 }, { 0, 0.2, 0 }, { 0, 20, 0 }, { 110, 66, 34 }, "plastic", 0 },
		{ "block", { 0.25, 2.1, 1.9 }, { -1, -0.2, 0.35 }, { 0, 20, 0 }, { 255, 200, 50 }, "metal", 0 },
		{ "block", { 0.25, 2.1, 1.9 }, { 1, -0.2, -0.35 }, { 0, 20, 0 }, { 255, 200, 50 }, "metal", 0 },
		{ "block", { 0.55, 0.6, 0.2 }, { -0.32, -0.1, -0.88 }, { 0, 20, 0 }, { 255, 228, 120 }, "metal", 0 },
		{ "ball", { 0.5, 0.5, 0.5 }, { 0.3, 1.15, -0.2 }, { 0, 0, 0 }, { 255, 228, 120 }, "neon", 0 },
		{ "ball", { 0.4, 0.4, 0.4 }, { -0.4, 1.1, 0.1 }, { 0, 0, 0 }, { 90, 220, 255 }, "neon", 0 },
	},
	BigTank = {
		{ "block", { 3, 2.2, 1.8 }, { 0, 0, 0 }, { 0, 15, 0 }, { 200, 235, 255 }, "glass", 0.65 },
		{ "block", { 2.85, 1.55, 1.65 }, { 0, -0.3, 0 }, { 0, 15, 0 }, { 60, 150, 240 }, "plastic", 0.35 },
		{ "block", { 2.85, 0.25, 1.65 }, { 0, -0.95, 0 }, { 0, 15, 0 }, { 235, 215, 150 }, "plastic", 0 },
		{ "ell", { 1, 0.6, 0.35 }, { -0.5, -0.1, -0.4 }, { 0, 15, 0 }, { 255, 140, 40 }, "plastic", 0 },
		{ "block", { 0.1, 0.5, 0.4 }, { -1.05, -0.1, -0.25 }, { 0, 15, 0 }, { 255, 220, 200 }, "plastic", 0 },
		{ "ell", { 0.8, 0.5, 0.3 }, { 0.6, 0.3, -0.1 }, { 0, 195, 0 }, { 60, 230, 210 }, "plastic", 0 },
		{ "block", { 0.15, 1.2, 0.15 }, { 0.9, -0.35, 0.3 }, { 0, 0, 10 }, { 70, 180, 70 }, "plastic", 0 },
		{ "block", { 0.15, 0.9, 0.15 }, { -1, -0.5, 0.4 }, { 0, 0, -10 }, { 70, 180, 70 }, "plastic", 0 },
		{ "block", { 3.05, 0.2, 1.85 }, { 0, 1.12, 0 }, { 0, 15, 0 }, { 40, 50, 70 }, "metal", 0 },
	},
	DoubleDamage = {
		{ "ball", { 1.6, 1.6, 1.6 }, { 0, 0.2, 0.6 }, { 0, 0, 0 }, { 255, 140, 40 }, "neon", 0.45 },
		{ "block", { 0.3, 2.6, 0.12 }, { -0.289, 0.545, -0.1 }, { 0, 0, 40 }, { 225, 230, 240 }, "metal", 0 },
		{ "block", { 1.1, 0.22, 0.22 }, { 0.579, -0.489, -0.1 }, { 0, 0, 40 }, { 255, 200, 50 }, "metal", 0 },
		{ "block", { 0.22, 0.7, 0.22 }, { 0.836, -0.796, -0.1 }, { 0, 0, 40 }, { 110, 60, 35 }, "plastic", 0 },
		{ "ball", { 0.35, 0.35, 0.35 }, { 1.093, -1.102, -0.1 }, { 0, 0, 0 }, { 255, 200, 50 }, "metal", 0 },
		{ "block", { 0.3, 2.6, 0.12 }, { 0.289, 0.545, 0.1 }, { 0, 0, -40 }, { 225, 230, 240 }, "metal", 0 },
		{ "block", { 1.1, 0.22, 0.22 }, { -0.579, -0.489, 0.1 }, { 0, 0, -40 }, { 255, 200, 50 }, "metal", 0 },
		{ "block", { 0.22, 0.7, 0.22 }, { -0.836, -0.796, 0.1 }, { 0, 0, -40 }, { 110, 60, 35 }, "plastic", 0 },
		{ "ball", { 0.35, 0.35, 0.35 }, { -1.093, -1.102, 0.1 }, { 0, 0, 0 }, { 255, 200, 50 }, "metal", 0 },
	},
	BoostXP = {
		{ "ball", { 1.1, 1.1, 0.6 }, { 0, 0, 0 }, { 0, 0, 0 }, { 255, 220, 70 }, "plastic", 0 },
		{ "ell", { 0.75, 1.5, 0.45 }, { 0, 0.85, 0 }, { 0, 0, 0 }, { 255, 210, 50 }, "plastic", 0 },
		{ "ell", { 0.75, 1.5, 0.45 }, { -0.808, 0.263, 0 }, { 0, 0, 72 }, { 255, 210, 50 }, "plastic", 0 },
		{ "ell", { 0.75, 1.5, 0.45 }, { -0.5, -0.688, 0 }, { 0, 0, 144 }, { 255, 210, 50 }, "plastic", 0 },
		{ "ell", { 0.75, 1.5, 0.45 }, { 0.5, -0.688, 0 }, { 0, 0, 216 }, { 255, 210, 50 }, "plastic", 0 },
		{ "ell", { 0.75, 1.5, 0.45 }, { 0.808, 0.263, 0 }, { 0, 0, 288 }, { 255, 210, 50 }, "plastic", 0 },
		{ "ball", { 0.5, 0.5, 0.3 }, { 0, 0, -0.3 }, { 0, 0, 0 }, { 255, 245, 180 }, "neon", 0 },
	},
	RebirthRush = {
		{ "block", { 0.55, 1.7, 0.35 }, { 0.3, 0.85, 0 }, { 0, 0, -28 }, { 255, 230, 60 }, "neon", 0 },
		{ "block", { 1.4, 0.42, 0.35 }, { 0, 0, 0 }, { 0, 0, 0 }, { 255, 230, 60 }, "neon", 0 },
		{ "block", { 0.55, 1.7, 0.35 }, { -0.3, -0.85, 0 }, { 0, 0, -28 }, { 255, 230, 60 }, "neon", 0 },
		{ "ball", { 1.8, 1.8, 1.8 }, { 0, 0, 0.6 }, { 0, 0, 0 }, { 255, 170, 40 }, "neon", 0.6 },
	},
	LevelPack = {
		{ "block", { 0.75, 1.7, 0.4 }, { 0, -0.55, 0 }, { 0, 0, 0 }, { 90, 220, 90 }, "plastic", 0 },
		{ "block", { 0.55, 1.6, 0.42 }, { -0.5, 0.55, 0 }, { 0, 0, -45 }, { 90, 220, 90 }, "plastic", 0 },
		{ "block", { 0.55, 1.6, 0.42 }, { 0.5, 0.55, 0 }, { 0, 0, 45 }, { 90, 220, 90 }, "plastic", 0 },
		{ "ball", { 0.5, 0.5, 0.5 }, { 0, 1.12, 0 }, { 0, 0, 0 }, { 150, 255, 150 }, "neon", 0 },
	},
	InstantRebirth = {
		{ "block", { 0.5, 0.42, 0.38 }, { -0.575, 0.996, 0 }, { 0, 0, 30 }, { 255, 145, 50 }, "plastic", 0 },
		{ "block", { 0.5, 0.42, 0.38 }, { -0.93, 0.676, 0 }, { 0, 0, 54 }, { 255, 145, 50 }, "plastic", 0 },
		{ "block", { 0.5, 0.42, 0.38 }, { -1.125, 0.239, 0 }, { 0, 0, 78 }, { 255, 145, 50 }, "plastic", 0 },
		{ "block", { 0.5, 0.42, 0.38 }, { -1.125, -0.239, 0 }, { 0, 0, 102 }, { 255, 145, 50 }, "plastic", 0 },
		{ "block", { 0.5, 0.42, 0.38 }, { -0.93, -0.676, 0 }, { 0, 0, 126 }, { 255, 145, 50 }, "plastic", 0 },
		{ "block", { 0.5, 0.42, 0.38 }, { -0.575, -0.996, 0 }, { 0, 0, 150 }, { 255, 145, 50 }, "plastic", 0 },
		{ "block", { 0.5, 0.42, 0.38 }, { -0.12, -1.144, 0 }, { 0, 0, 174 }, { 255, 145, 50 }, "plastic", 0 },
		{ "block", { 0.5, 0.42, 0.38 }, { 0.355, -1.094, 0 }, { 0, 0, 198 }, { 255, 145, 50 }, "plastic", 0 },
		{ "block", { 0.5, 0.42, 0.38 }, { 0.77, -0.855, 0 }, { 0, 0, 222 }, { 255, 145, 50 }, "plastic", 0 },
		{ "block", { 0.5, 0.42, 0.38 }, { 1.051, -0.468, 0 }, { 0, 0, 246 }, { 255, 145, 50 }, "plastic", 0 },
		{ "block", { 0.5, 0.42, 0.38 }, { 1.15, -0, 0 }, { 0, 0, 270 }, { 255, 145, 50 }, "plastic", 0 },
		{ "block", { 0.5, 0.42, 0.38 }, { 1.051, 0.468, 0 }, { 0, 0, 294 }, { 255, 145, 50 }, "plastic", 0 },
		{ "block", { 0.5, 0.42, 0.38 }, { 0.77, 0.855, 0 }, { 0, 0, 318 }, { 255, 145, 50 }, "plastic", 0 },
		{ "block", { 0.9, 0.3, 0.4 }, { -0.205, 1.344, 0 }, { 0, 0, -30 }, { 255, 200, 80 }, "neon", 0 },
		{ "block", { 0.9, 0.3, 0.4 }, { -0.155, 0.894, 0 }, { 0, 0, 40 }, { 255, 200, 80 }, "neon", 0 },
		{ "ball", { 0.8, 0.8, 0.8 }, { 0, 0, 0 }, { 0, 0, 0 }, { 255, 220, 120 }, "neon", 0 },
	},
	SeasonPremium = {
		{ "block", { 2.9, 1.6, 0.25 }, { 0, 0, 0 }, { 0, 0, 12 }, { 255, 200, 50 }, "plastic", 0 },
		{ "block", { 2.95, 0.3, 0.28 }, { 0, 0.3, 0 }, { 0, 0, 12 }, { 205, 145, 30 }, "plastic", 0 },
		{ "cyl", { 0.3, 0.55, 0.55 }, { -1.45, -0.3, 0 }, { 0, 90, 0 }, { 40, 50, 80 }, "plastic", 0 },
		{ "cyl", { 0.3, 0.55, 0.55 }, { 1.45, 0.3, 0 }, { 0, 90, 0 }, { 40, 50, 80 }, "plastic", 0 },
		{ "ball", { 0.6, 0.6, 0.3 }, { 0.2, -0.3, -0.15 }, { 0, 0, 0 }, { 255, 245, 200 }, "neon", 0 },
	},
	SeasonMystic = {
		{ "ball", { 2.3, 2.3, 2.3 }, { 0, 0.35, 0 }, { 0, 0, 0 }, { 205, 160, 255 }, "glass", 0.45 },
		{ "ball", { 1.1, 1.1, 1.1 }, { 0, 0.35, 0 }, { 0, 0, 0 }, { 255, 110, 240 }, "neon", 0 },
		{ "cyl", { 0.5, 1.7, 1.7 }, { 0, -0.95, 0 }, { 0, 0, 90 }, { 255, 200, 50 }, "metal", 0 },
		{ "cyl", { 0.3, 2.1, 2.1 }, { 0, -1.25, 0 }, { 0, 0, 90 }, { 205, 145, 30 }, "metal", 0 },
		{ "ball", { 0.3, 0.3, 0.3 }, { 0.9, 1.3, -0.3 }, { 0, 0, 0 }, { 255, 255, 255 }, "neon", 0 },
		{ "ball", { 0.22, 0.22, 0.22 }, { -1, 1, -0.2 }, { 0, 0, 0 }, { 255, 255, 255 }, "neon", 0 },
	},
}


local ICON_MATERIALS = {
	plastic = Enum.Material.SmoothPlastic,
	neon = Enum.Material.Neon,
	metal = Enum.Material.Metal,
	glass = Enum.Material.Glass,
}

-- Builds a store icon (crown, coin stack, clover...) out of parts, centered on the origin
function Models.BuildIcon(key)
	local data = Models.Icons[key]
	if not data then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = key .. "Icon"
	local root = petPart(model, Vector3.new(0.2, 0.2, 0.2), CFrame.new(), Color3.new(1, 1, 1), nil, 1)
	root.Name = "Root"
	model.PrimaryPart = root
	for _, p in ipairs(data) do
		local shape, size, pos, rot, color = p[1], p[2], p[3], p[4], p[5]
		local material = ICON_MATERIALS[p[6]] or Enum.Material.SmoothPlastic
		local transparency = p[7] or 0
		local cf = CFrame.new(pos[1], pos[2], pos[3]) * CFrame.Angles(math.rad(rot[1]), math.rad(rot[2]), math.rad(rot[3]))
		local vsize = Vector3.new(size[1], size[2], size[3])
		local c = Color3.fromRGB(color[1], color[2], color[3])
		local uniform = size[1] == size[2] and size[2] == size[3]
		if shape == "ell" or (shape == "ball" and not uniform) then
			ellipsoid(model, vsize, cf, c, material, transparency)
		elseif shape == "ball" then
			petPart(model, vsize, cf, c, material, transparency, Enum.PartType.Ball)
		elseif shape == "cyl" then
			petPart(model, vsize, cf, c, material, transparency, Enum.PartType.Cylinder)
		else
			petPart(model, vsize, cf, c, material, transparency)
		end
	end
	return model
end

return Models
