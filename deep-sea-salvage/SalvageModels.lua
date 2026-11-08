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

return Models
