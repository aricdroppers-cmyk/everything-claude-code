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

local WHITE = Color3.new(1, 1, 1)
local BLACK = Color3.fromRGB(14, 14, 18)

local function darker(c, f)
	return c:Lerp(Color3.new(0, 0, 0), f)
end

local function lighter(c, f)
	return c:Lerp(Color3.new(1, 1, 1), f)
end

-- Realistic-ish sea creatures built from parts. Front = -Z, up = +Y.
function Models.Build(def, scale)
	local model = Instance.new("Model")
	model.Name = def.id
	local s = (scale or 1) * (0.8 + (def.rarity or 1) * 0.12)
	local root = petPart(model, Vector3.new(0.2, 0.2, 0.2), CFrame.new(), def.color, nil, 1)
	root.Name = "Root"
	model.PrimaryPart = root

	local color, accent = def.color, def.accent
	local accentMat = def.glow and Enum.Material.Neon or Enum.Material.SmoothPlastic
	local function C(x, y, z)
		return CFrame.new(x * s, y * s, z * s)
	end
	local function V(x, y, z)
		return Vector3.new(x * s, y * s, z * s)
	end
	local function E(size, cf, c, mat, tr)
		return ellipsoid(model, size, cf, c, mat, tr)
	end
	local function B(size, cf, c, mat, tr)
		return petPart(model, size, cf, c, mat, tr)
	end
	local function A(x, y, z)
		return CFrame.Angles(math.rad(x), math.rad(y), math.rad(z))
	end

	-- an eye looking along (dx, 0, dz): white, dark iris, shiny highlight
	local function eye(x, y, z, size, dx, dz, irisColor, slit)
		local d = size * s
		local dir = Vector3.new(dx, 0, dz).Unit
		local base = Vector3.new(x * s, y * s, z * s)
		ball(model, d, CFrame.new(base), def.angry and Color3.fromRGB(255, 235, 200) or WHITE)
		local irisPos = base + dir * d * 0.28
		local pupil = def.angry and Color3.fromRGB(230, 30, 30) or (irisColor or BLACK)
		if slit then
			E(Vector3.new(d * 0.55, d * 0.22, d * 0.55), CFrame.lookAt(irisPos, irisPos + dir), pupil, def.angry and Enum.Material.Neon or nil)
		else
			E(Vector3.new(d * 0.62, d * 0.62, d * 0.3), CFrame.lookAt(irisPos, irisPos + dir), pupil, def.angry and Enum.Material.Neon or nil)
		end
		local glint = base + dir * d * 0.46 + Vector3.new(0, d * 0.16, 0)
		ball(model, d * 0.2, CFrame.new(glint), WHITE, Enum.Material.Neon)
	end

	-- a chain of balls along points, shrinking from r0 to r1 (tentacles, arms, bodies)
	local function _chain(points, r0, r1, c, mat)
		for i, p in ipairs(points) do
			local t = (#points > 1) and (i - 1) / (#points - 1) or 0
			local d = (r0 + (r1 - r0) * t) * s
			ball(model, d, CFrame.new(p.X * s, p.Y * s, p.Z * s), c, mat)
		end
	end

	-- a smooth tube through points: stretched, overlapping segments (tentacles, arms, bodies)
	local function tube(points, r0, r1, c, mat, tr)
		local n = #points
		for i = 1, n - 1 do
			local a = points[i] * s
			local b = points[i + 1] * s
			local t = (n > 2) and (i - 1) / (n - 2) or 0
			local d = (r0 + (r1 - r0) * t) * s
			local len = (b - a).Magnitude
			if len > 0.001 then
				E(Vector3.new(d, d, len + d * 0.9), CFrame.lookAt((a + b) / 2, b), c, mat, tr)
			end
		end
	end

	local shape = def.shape
	if shape == "fish" and def.fin then
		------------------------------------------------------------------ shark
		local back, belly = darker(color, 0.1), lighter(color, 0.75)
		E(V(1.0, 1.05, 2.8), C(0, 0, 0), color)
		E(V(0.85, 0.55, 2.4), C(0, -0.25, -0.05), belly)
		E(V(0.7, 0.7, 1.3), C(0, 0.05, -1.3), color) -- snout
		E(V(0.55, 0.3, 0.9), C(0, -0.2, -1.45), belly)
		E(V(0.45, 0.55, 1.3), C(0, 0.05, 1.5), back) -- tail stock
		E(V(0.14, 1.3, 0.85), C(0, 0.85, 0.0) * A(-30, 0, 0), back) -- dorsal fin
		E(V(0.12, 1.45, 0.5), C(0, 0.6, 2.15) * A(-42, 0, 0), back) -- tail upper lobe
		E(V(0.12, 0.85, 0.42), C(0, -0.35, 2.05) * A(38, 0, 0), back)
		for _, side in ipairs({ -1, 1 }) do
			E(V(1.35, 0.12, 0.6), C(side * 0.8, -0.35, -0.3) * A(0, side * -20, side * -25), back) -- pectoral
			for k = 0, 2 do
				B(V(0.04, 0.38, 0.06), C(side * 0.47, 0.0, -0.7 + k * 0.16), darker(color, 0.35)) -- gill slits
			end
			eye(side * 0.33, 0.18, -1.35, 0.2, side * 0.8, -0.6)
		end
		E(V(0.5, 0.06, 0.4), C(0, -0.32, -1.55), darker(color, 0.5)) -- mouth line
	elseif shape == "fish" then
		------------------------------------------------------------------ fish
		local round = def.round
		local W, H, L = 1.0, 1.15, 2.0
		if round then
			W, H, L = 1.55, 1.45, 1.65
		end
		local belly = lighter(color, 0.45)
		E(V(W, H, L), C(0, 0, 0), color)
		E(V(W * 0.92, H * 0.55, L * 0.8), C(0, -H * 0.22, -0.05), belly) -- lighter belly
		E(V(W * 0.85, H * 0.45, L * 0.75), C(0, H * 0.25, 0.05), darker(color, 0.12)) -- darker back
		E(V(W * 0.55, H * 0.6, 0.9), C(0, 0, L * 0.5), color) -- tail stock
		E(V(W * 1.02, H * 0.92, 0.08), C(0, 0, -L * 0.18), darker(color, 0.25)) -- gill line
		if def.stripes then
			for _, band in ipairs({ { -L * 0.22, 0.95 }, { L * 0.1, 1.0 }, { L * 0.42, 0.62 } }) do
				E(V(W * band[2] + 0.07, H * band[2] + 0.07, 0.3), C(0, 0, band[1]), BLACK)
				E(V(W * band[2] + 0.09, H * band[2] + 0.09, 0.2), C(0, 0, band[1]), accent)
			end
		end
		-- forked tail
		for _, a in ipairs({ 32, -32 }) do
			E(V(0.08, 0.95, 0.7), C(0, a > 0 and 0.28 or -0.28, L * 0.5 + 0.55) * A(a, 0, 0), accent, accentMat)
		end
		-- dorsal + bottom fins
		E(V(0.08, 0.55, L * 0.6), C(0, H * 0.5 + 0.1, 0.1) * A(-8, 0, 0), accent, accentMat)
		E(V(0.08, 0.35, L * 0.3), C(0, -H * 0.5 - 0.05, 0.3), accent, accentMat)
		for _, side in ipairs({ -1, 1 }) do
			E(V(0.55, 0.06, 0.38), C(side * W * 0.5, -0.15, -L * 0.08) * A(0, side * -25, side * -30), accent, accentMat) -- pectoral
			eye(side * W * 0.36, H * 0.12, -L * 0.3, round and 0.42 or 0.34, side * 0.85, -0.5)
		end
		E(V(W * 0.32, H * 0.14, 0.12), C(0, -H * 0.12, -L * 0.5), darker(color, 0.45)) -- mouth
		if round then
			-- spikes all over, and spots on the back
			local n = 26
			for i = 1, n do
				local y = 1 - (i - 0.5) / n * 2
				local r = math.sqrt(1 - y * y)
				local a = i * 2.399963
				local dir = Vector3.new(math.cos(a) * r, y, math.sin(a) * r)
				if dir.Z > -0.55 then
					local base = Vector3.new(dir.X * W * 0.5, dir.Y * H * 0.5, dir.Z * L * 0.5) * s
					B(Vector3.new(0.07, 0.07, 0.42) * s, CFrame.lookAt(base, base + dir) * CFrame.new(0, 0, -0.12 * s), lighter(accent, 0.3))
				end
			end
			for _, p in ipairs({ { 0.3, 0.55, 0.1 }, { -0.35, 0.5, 0.3 }, { 0.05, 0.62, 0.45 }, { -0.1, 0.6, -0.15 } }) do
				E(V(0.22, 0.06, 0.22), C(p[1], p[2], p[3]), darker(accent, 0.2))
			end
		end
		if def.lure then
			-- angler: jaw with teeth, glowing lure on a curved stalk
			E(V(W * 0.8, H * 0.3, 0.5), C(0, -H * 0.25, -L * 0.48), darker(color, 0.35))
			for k = -2, 2 do
				B(V(0.06, 0.18, 0.06), C(k * 0.13, -H * 0.12, -L * 0.52), WHITE)
			end
			local stalk = {}
			for k = 0, 5 do
				local t = k / 5
				table.insert(stalk, Vector3.new(0, H * 0.5 + 0.1 + math.sin(t * math.pi * 0.8) * 0.7, -L * 0.15 - t * 0.9))
			end
			tube(stalk, 0.1, 0.06, darker(color, 0.2))
			local bulb = ball(model, 0.38 * s, CFrame.new(0, (H * 0.5 + 0.35) * s, (-L * 0.15 - 1.05) * s), accent, Enum.Material.Neon)
			new("PointLight", { Color = accent, Range = 6, Brightness = 2, Parent = bulb })
		end
	elseif shape == "crab" then
		------------------------------------------------------------------ crab
		E(V(1.9, 0.75, 1.35), C(0, 0, 0), color)
		E(V(1.7, 0.4, 1.2), C(0, -0.2, 0.05), lighter(color, 0.45)) -- underside
		for _, p in ipairs({ { 0.35, 0.33, -0.1 }, { -0.4, 0.32, 0.05 }, { 0, 0.36, 0.25 }, { 0.6, 0.25, 0.2 }, { -0.65, 0.24, -0.2 } }) do
			ball(model, 0.18 * s, C(p[1], p[2], p[3]), darker(color, 0.15)) -- shell bumps
		end
		for _, side in ipairs({ -1, 1 }) do
			for k = 1, 4 do
				local z = -0.4 + k * 0.24
				B(V(0.62, 0.12, 0.12), C(side * 1.05, 0.05, z) * A(0, side * (10 - k * 8), side * 28), color) -- upper leg
				B(V(0.6, 0.1, 0.1), C(side * 1.55, -0.3, z + 0.05) * A(0, side * (10 - k * 8), side * -55), darker(color, 0.1)) -- lower leg
				ball(model, 0.1 * s, C(side * 1.72, -0.55, z + 0.06), darker(color, 0.45)) -- tip
			end
			-- claw: arm, forearm, pincer + moving finger
			B(V(0.18, 0.18, 0.55), C(side * 0.75, 0.0, -0.75) * A(0, side * 25, 0), color)
			E(V(0.32, 0.3, 0.6), C(side * 0.95, 0.05, -1.05) * A(0, side * 10, 0), color)
			E(V(0.55, 0.45, 0.75), C(side * 1.05, 0.1, -1.45), color)
			E(V(0.2, 0.18, 0.55), C(side * 0.95, 0.22, -1.85) * A(-15, 0, 0), darker(color, 0.25))
			E(V(0.2, 0.16, 0.5), C(side * 1.1, -0.02, -1.85) * A(15, 0, 0), darker(color, 0.4))
			-- eye stalks
			B(V(0.08, 0.42, 0.08), C(side * 0.22, 0.5, -0.5) * A(10, 0, 0), color)
			eye(side * 0.22, 0.76, -0.53, 0.22, side * 0.3, -1)
		end
	elseif shape == "star" then
		------------------------------------------------------------------ starfish (no eyes, like the real thing)
		E(V(0.85, 0.85, 0.42), C(0, 0, 0), color)
		for k = 0, 4 do
			local a = math.rad(k * 72)
			local pts = {}
			for i = 0, 4 do
				local r = 0.15 + i * 0.32
				table.insert(pts, Vector3.new(math.sin(a) * r, math.cos(a) * r, -0.012 * i * i))
			end
			tube(pts, 0.62, 0.2, color)
			for i = 1, 3 do
				local r = 0.35 + i * 0.28
				ball(model, 0.1 * s, C(math.sin(a) * r, math.cos(a) * r, -0.2), accent) -- bumps
			end
		end
		ball(model, 0.14 * s, C(0, 0, -0.22), darker(color, 0.3))
	elseif shape == "turtle" then
		------------------------------------------------------------------ sea turtle
		local skin = accent
		E(V(1.9, 0.85, 2.25), C(0, 0.12, 0), color) -- shell
		E(V(2.0, 0.3, 2.35), C(0, -0.08, 0), lighter(color, 0.25)) -- shell rim
		E(V(1.65, 0.35, 1.95), C(0, -0.25, 0), lighter(skin, 0.4)) -- belly plate
		-- shell plates
		local plates = { { 0, 0.52, -0.45, 0.5 }, { 0, 0.56, 0.05, 0.55 }, { 0, 0.52, 0.55, 0.5 },
			{ -0.55, 0.42, -0.3, 0.45 }, { 0.55, 0.42, -0.3, 0.45 }, { -0.55, 0.42, 0.35, 0.45 }, { 0.55, 0.42, 0.35, 0.45 } }
		for _, p in ipairs(plates) do
			E(V(p[4] + 0.06, 0.1, p[4] * 0.9 + 0.06), C(p[1], p[2] - 0.01, p[3]), darker(color, 0.35))
			E(V(p[4], 0.12, p[4] * 0.9), C(p[1], p[2], p[3]), lighter(color, 0.1))
		end
		-- head with beak
		E(V(0.5, 0.45, 0.6), C(0, 0.0, -1.2), skin) -- neck
		E(V(0.62, 0.55, 0.72), C(0, 0.1, -1.55), skin)
		E(V(0.3, 0.2, 0.3), C(0, 0.0, -1.88), darker(skin, 0.35)) -- beak
		for _, side in ipairs({ -1, 1 }) do
			eye(side * 0.24, 0.2, -1.65, 0.2, side * 0.7, -0.7)
			E(V(1.35, 0.1, 0.42), C(side * 1.15, -0.1, -0.6) * A(0, side * -30, side * -8), skin) -- front flipper
			for k = 0, 1 do
				E(V(0.18, 0.05, 0.14), C(side * (1.0 + k * 0.4), -0.04, -0.62 - k * 0.15), darker(skin, 0.35)) -- spots
			end
			E(V(0.65, 0.1, 0.35), C(side * 0.85, -0.12, 0.85) * A(0, side * 30, 0), skin) -- back flipper
		end
		E(V(0.14, 0.12, 0.35), C(0, -0.08, 1.3), skin) -- tail
	elseif shape == "jelly" then
		------------------------------------------------------------------ jellyfish (no eyes)
		local glowMat = def.glow and Enum.Material.Neon or nil
		E(V(1.9, 1.35, 1.9), C(0, 0.45, 0), color, glowMat, 0.3) -- bell
		E(V(1.2, 0.8, 1.2), C(0, 0.4, 0), lighter(color, 0.3), glowMat, 0.35)
		for k = 0, 3 do
			local a = math.rad(k * 90 + 45)
			E(V(0.35, 0.12, 0.35), C(math.cos(a) * 0.3, 0.55, math.sin(a) * 0.3), accent, accentMat, 0.1) -- inner rings
		end
		for k = 0, 11 do
			local a = math.rad(k * 30)
			E(V(0.32, 0.12, 0.22), C(math.cos(a) * 0.9, -0.1, math.sin(a) * 0.9) * A(0, -k * 30, 0), lighter(color, 0.2), glowMat, 0.2) -- frilly rim
		end
		for k = 0, 3 do
			-- oral arms: wavy ribbons hanging from the middle
			local a = math.rad(k * 90)
			local pts = {}
			for i = 0, 5 do
				local w = math.sin(i * 0.9 + k) * 0.18
				table.insert(pts, Vector3.new(math.cos(a) * (0.18 + w), -0.15 - i * 0.3, math.sin(a) * (0.18 + w)))
			end
			tube(pts, 0.26, 0.12, accent, accentMat, 0.15)
		end
		for k = 0, 7 do
			-- long thin tentacles
			local a = math.rad(k * 45 + 15)
			local pts = {}
			for i = 0, 5 do
				local w = math.sin(i * 0.8 + k) * 0.12
				table.insert(pts, Vector3.new(math.cos(a) * (0.82 + w), -0.12 - i * 0.38, math.sin(a) * (0.82 + w)))
			end
			tube(pts, 0.06, 0.035, lighter(accent, 0.3), accentMat, 0.3)
		end
	elseif shape == "octopus" then
		------------------------------------------------------------------ octopus
		E(V(1.35, 1.6, 1.45), C(0, 0.75, 0.25) * A(-15, 0, 0), color) -- mantle
		E(V(1.15, 0.85, 1.1), C(0, 0.1, -0.05), color) -- head
		for _, p in ipairs({ { 0.35, 1.0, 0.55 }, { -0.4, 1.15, 0.35 }, { 0.1, 1.4, 0.3 }, { -0.15, 0.7, 0.7 }, { 0.45, 0.6, 0.3 } }) do
			E(V(0.18, 0.18, 0.08), C(p[1], p[2], p[3] - 0.05), darker(accent, 0.1), accentMat) -- skin spots
		end
		for _, side in ipairs({ -1, 1 }) do
			E(V(0.4, 0.35, 0.35), C(side * 0.45, 0.32, -0.3), color) -- eye bulges
			eye(side * 0.5, 0.35, -0.38, 0.3, side * 0.6, -0.8, BLACK, true)
		end
		E(V(0.16, 0.16, 0.3), C(0.35, -0.05, -0.5) * A(0, 0, 0), darker(color, 0.15)) -- siphon
		for k = 0, 7 do
			local a = math.rad(k * 45 + 22.5)
			local pts = {}
			for i = 0, 5 do
				local t = i / 5
				local r = 0.35 + t * 1.25
				local y = -0.25 - math.sin(t * math.pi * 0.75) * 0.55 + t * t * 0.55 -- out, down, then curling up
				table.insert(pts, Vector3.new(math.sin(a) * r, y, -math.cos(a) * r))
			end
			tube(pts, 0.44, 0.12, color)
			for i = 1, 3 do
				local p = pts[i + 1]
				ball(model, 0.1 * s, C(p.X * 1.0, p.Y - 0.14, p.Z * 1.0), lighter(accent, 0.3), accentMat) -- suckers
			end
		end
	elseif shape == "ray" then
		------------------------------------------------------------------ manta / ray
		E(V(3.2, 0.28, 1.9), C(0, 0, 0.1), color) -- wings
		E(V(3.0, 0.2, 1.7), C(0, -0.08, 0.1), lighter(accent, 0.35)) -- lighter underside
		E(V(1.0, 0.5, 2.0), C(0, 0.12, 0), darker(color, 0.05)) -- body ridge
		for _, side in ipairs({ -1, 1 }) do
			E(V(0.7, 0.14, 0.5), C(side * 1.65, 0.12, 0.3) * A(0, 0, side * 18), color) -- curled wing tips
			E(V(0.22, 0.12, 0.45), C(side * 0.35, -0.02, -0.95) * A(0, side * 15, 0), color) -- head fins
			eye(side * 0.34, 0.22, -0.6, 0.18, side * 0.8, -0.6)
			for k = 0, 2 do
				E(V(0.2, 0.05, 0.2), C(side * (0.6 + k * 0.32), 0.15, 0.1 + k * 0.12), accent, accentMat) -- spots
			end
		end
		local tail = {}
		for i = 0, 7 do
			table.insert(tail, Vector3.new(math.sin(i * 0.5) * 0.12, 0.05, 1.05 + i * 0.32))
		end
		tube(tail, 0.18, 0.05, color)
		B(V(0.06, 0.06, 0.3), C(0, 0.05, 3.5), accent, accentMat)
	else
		------------------------------------------------------------------ eel / sea dragon / elder serpent
		local dragon = (def.rarity or 1) >= 4
		local elder = (def.rarity or 1) >= 6 -- Mythic: raised neck, crown, glowing spine, wing fins, tail fluke
		local hy = elder and 1.2 or 0 -- head lift
		local n = elder and 16 or 14
		local pts = {}
		for i = 0, n - 1 do
			if elder then
				-- S-coil: neck rises from the coils, body winds back and forth
				local lift = math.max(0, 4 - i) * 0.3
				table.insert(pts, Vector3.new(math.sin(i * 0.5) * 0.95, lift, -0.15 + i * 0.2))
			else
				table.insert(pts, Vector3.new(math.sin(i * 0.55) * 0.35, math.sin(i * 0.3) * 0.08, -0.2 + i * 0.3))
			end
		end
		tube(pts, elder and 0.95 or 0.85, 0.22, color)
		for i = 1, n - 2 do
			local p = pts[i]
			local d = ((elder and 0.95 or 0.85) + (0.22 - (elder and 0.95 or 0.85)) * (i - 1) / (n - 1))
			if elder and i >= 4 then
				E(V(0.09, 0.5 * d + 0.18, 0.2), C(p.X, p.Y + d * 0.5 + 0.12, p.Z) * A(-28, 0, 0), accent, Enum.Material.Neon) -- glowing spine spikes
				for _, side in ipairs({ -1, 1 }) do
					if i % 2 == 1 then
						E(V(0.1, 0.1, 0.1), C(p.X + side * d * 0.46, p.Y, p.Z), lighter(accent, 0.3), Enum.Material.Neon) -- glowing side lights
					end
				end
			elseif elder then
				E(V(0.08, 0.5, 0.32), C(p.X, p.Y, p.Z + d * 0.5 + 0.08) * A(70, 0, 0), accent, Enum.Material.Neon) -- mane down the back of the neck
			else
				E(V(0.06, 0.3, 0.32), C(p.X, p.Y + d * 0.5 + 0.05, p.Z), accent, accentMat) -- fin ribbon
			end
			if i % 2 == 0 then
				E(V(d * 0.5, 0.06, 0.22), C(p.X, p.Y - d * 0.42, p.Z), lighter(color, 0.4)) -- lighter belly scales
			end
		end
		E(V(elder and 1.2 or 0.85, elder and 1.0 or 0.75, elder and 1.6 or 1.15), C(0, 0.02 + hy, -0.6), color) -- head
		if elder then
			E(V(0.8, 0.55, 0.9), C(0, -0.05 + hy, -1.15), color) -- long snout
			E(V(0.9, 0.12, 1.2), C(0, 0.42 + hy, -0.6), lighter(accent, 0.2), Enum.Material.Neon, 0.2) -- glowing brow ridge
		end
		E(V(0.7, 0.28, elder and 1.2 or 0.85), C(0, -0.25 + hy - (elder and 0.1 or 0), -0.62 - (elder and 0.4 or 0)), darker(color, 0.25)) -- jaw
		E(V(0.5, 0.12, 0.4), C(0, -0.15 + hy - (elder and 0.12 or 0), -1.0 - (elder and 0.45 or 0)), darker(color, 0.6)) -- open mouth
		for k = -1, 1 do
			B(V(0.05, elder and 0.18 or 0.12, 0.05), C(k * 0.12, -0.08 + hy - (elder and 0.12 or 0), -1.05 - (elder and 0.45 or 0)), WHITE) -- teeth
		end
		for _, side in ipairs({ -1, 1 }) do
			if elder then
				eye(side * 0.34, 0.24 + hy, -0.9, 0.26, side * 0.7, -0.7, accent, true)
				for k = 0, 2 do -- crown of swept-back horns
					B(V(0.1, 0.75 - k * 0.15, 0.1), C(side * (0.2 + k * 0.1), 0.6 + hy - k * 0.05, -0.45 + k * 0.28) * A(-55 + k * 5, 0, side * -(14 + k * 10)),
						lighter(accent, 0.35), Enum.Material.Neon)
				end
				E(V(0.05, 0.05, 0.75), C(side * 0.3, -0.18 + hy, -1.2) * A(25, side * 25, 0), accent, Enum.Material.Neon) -- whiskers
				local wing = pts[6]
				for k = 0, 2 do -- swept-back fin spines
					E(V(0.95 - k * 0.2, 0.06, 0.16), C(wing.X + side * (0.55 + k * 0.05), wing.Y + 0.15, wing.Z + k * 0.18) * A(0, side * -(45 + k * 12), side * -30),
						accent, Enum.Material.Neon, 0.1)
				end
				local tip = pts[n]
				E(V(0.07, 0.6, 0.38), C(tip.X, tip.Y + side * 0.22, tip.Z + 0.12) * A(side * -40, 0, 0), accent, Enum.Material.Glass, 0.15) -- tail fluke
			else
				eye(side * 0.3, 0.2, -0.85, 0.24, side * 0.7, -0.7)
				if dragon then
					B(V(0.1, 0.5, 0.1), C(side * 0.25, 0.55, -0.4) * A(35, 0, side * -12), lighter(accent, 0.2), accentMat) -- horns
					B(V(0.08, 0.35, 0.08), C(side * 0.27, 0.85, -0.22) * A(70, 0, side * -12), lighter(accent, 0.2), accentMat)
					E(V(0.05, 0.05, 0.6), C(side * 0.3, -0.18, -1.1) * A(25, side * 25, 0), accent, accentMat) -- whiskers
				end
			end
		end
	end

	if def.glow then
		new("PointLight", { Color = accent, Range = 8, Brightness = 1.5, Parent = root })
	end
	return model
end

-- Store icons (generated by tools/icons.py; the same data drives the preview page)
Models.Icons = {
	DoubleCoins = {
		{ "cyl", { 0.3, 2, 2 }, { 0, -1.2, 0.25 }, { 0, 0, 90 }, { 205, 145, 30 }, "metal", 0 },
		{ "cyl", { 0.31, 1.75, 1.75 }, { 0, -1.19, 0.25 }, { 0, 0, 90 }, { 255, 200, 50 }, "metal", 0 },
		{ "cyl", { 0.3, 2, 2 }, { 0.1, -0.9, 0.2 }, { 0, 0, 90 }, { 205, 145, 30 }, "metal", 0 },
		{ "cyl", { 0.31, 1.75, 1.75 }, { 0.1, -0.89, 0.2 }, { 0, 0, 90 }, { 255, 200, 50 }, "metal", 0 },
		{ "cyl", { 0.3, 2, 2 }, { -0.06, -0.6, 0.28 }, { 0, 0, 90 }, { 205, 145, 30 }, "metal", 0 },
		{ "cyl", { 0.31, 1.75, 1.75 }, { -0.06, -0.59, 0.28 }, { 0, 0, 90 }, { 255, 200, 50 }, "metal", 0 },
		{ "cyl", { 0.3, 2, 2 }, { 0.08, -0.3, 0.22 }, { 0, 0, 90 }, { 205, 145, 30 }, "metal", 0 },
		{ "cyl", { 0.31, 1.75, 1.75 }, { 0.08, -0.29, 0.22 }, { 0, 0, 90 }, { 255, 200, 50 }, "metal", 0 },
		{ "cyl", { 0.3, 2, 2 }, { -0.02, 0, 0.24 }, { 0, 0, 90 }, { 205, 145, 30 }, "metal", 0 },
		{ "cyl", { 0.31, 1.75, 1.75 }, { -0.02, 0.01, 0.24 }, { 0, 0, 90 }, { 255, 200, 50 }, "metal", 0 },
		{ "cyl", { 0.4, 2.2, 2.2 }, { 0.15, 0.6, -0.8 }, { 0, 80, 0 }, { 205, 145, 30 }, "metal", 0 },
		{ "cyl", { 0.42, 1.85, 1.85 }, { 0.15, 0.6, -0.8 }, { 0, 80, 0 }, { 255, 200, 50 }, "metal", 0 },
		{ "ell", { 0.28, 0.6, 0.1 }, { 0.11, 0.92, -1.03 }, { 0, -10, 0 }, { 255, 228, 120 }, "neon", 0 },
		{ "ell", { 0.28, 0.6, 0.1 }, { -0.188, 0.699, -1.03 }, { 0, -10, 72 }, { 255, 228, 120 }, "neon", 0 },
		{ "ell", { 0.28, 0.6, 0.1 }, { -0.074, 0.341, -1.03 }, { 0, -10, 144 }, { 255, 228, 120 }, "neon", 0 },
		{ "ell", { 0.28, 0.6, 0.1 }, { 0.294, 0.341, -1.03 }, { 0, -10, 216 }, { 255, 228, 120 }, "neon", 0 },
		{ "ell", { 0.28, 0.6, 0.1 }, { 0.408, 0.699, -1.03 }, { 0, -10, 288 }, { 255, 228, 120 }, "neon", 0 },
		{ "cyl", { 0.25, 1, 1 }, { -1.25, -1.25, -0.6 }, { 70, 20, 90 }, { 255, 200, 50 }, "metal", 0 },
		{ "cyl", { 0.25, 1, 1 }, { 1.3, -1.3, -0.3 }, { 110, 20, 90 }, { 255, 200, 50 }, "metal", 0 },
		{ "cyl", { 0.25, 1, 1 }, { -1, -1.35, 0.9 }, { 85, 20, 90 }, { 255, 200, 50 }, "metal", 0 },
		{ "ball", { 0.35, 0.35, 0.35 }, { 1, 1.55, -1 }, { 0, 0, 0 }, { 255, 255, 230 }, "neon", 0 },
	},
	BoostCoins = {
		{ "cyl", { 0.3, 2, 2 }, { 0, -1.2, 0.25 }, { 0, 0, 90 }, { 205, 145, 30 }, "metal", 0 },
		{ "cyl", { 0.31, 1.75, 1.75 }, { 0, -1.19, 0.25 }, { 0, 0, 90 }, { 255, 200, 50 }, "metal", 0 },
		{ "cyl", { 0.3, 2, 2 }, { 0.1, -0.9, 0.2 }, { 0, 0, 90 }, { 205, 145, 30 }, "metal", 0 },
		{ "cyl", { 0.31, 1.75, 1.75 }, { 0.1, -0.89, 0.2 }, { 0, 0, 90 }, { 255, 200, 50 }, "metal", 0 },
		{ "cyl", { 0.3, 2, 2 }, { -0.06, -0.6, 0.28 }, { 0, 0, 90 }, { 205, 145, 30 }, "metal", 0 },
		{ "cyl", { 0.31, 1.75, 1.75 }, { -0.06, -0.59, 0.28 }, { 0, 0, 90 }, { 255, 200, 50 }, "metal", 0 },
		{ "cyl", { 0.3, 2, 2 }, { 0.08, -0.3, 0.22 }, { 0, 0, 90 }, { 205, 145, 30 }, "metal", 0 },
		{ "cyl", { 0.31, 1.75, 1.75 }, { 0.08, -0.29, 0.22 }, { 0, 0, 90 }, { 255, 200, 50 }, "metal", 0 },
		{ "cyl", { 0.3, 2, 2 }, { -0.02, 0, 0.24 }, { 0, 0, 90 }, { 205, 145, 30 }, "metal", 0 },
		{ "cyl", { 0.31, 1.75, 1.75 }, { -0.02, 0.01, 0.24 }, { 0, 0, 90 }, { 255, 200, 50 }, "metal", 0 },
		{ "cyl", { 0.4, 2.2, 2.2 }, { 0.15, 0.6, -0.8 }, { 0, 80, 0 }, { 205, 145, 30 }, "metal", 0 },
		{ "cyl", { 0.42, 1.85, 1.85 }, { 0.15, 0.6, -0.8 }, { 0, 80, 0 }, { 255, 200, 50 }, "metal", 0 },
		{ "ell", { 0.28, 0.6, 0.1 }, { 0.11, 0.92, -1.03 }, { 0, -10, 0 }, { 255, 228, 120 }, "neon", 0 },
		{ "ell", { 0.28, 0.6, 0.1 }, { -0.188, 0.699, -1.03 }, { 0, -10, 72 }, { 255, 228, 120 }, "neon", 0 },
		{ "ell", { 0.28, 0.6, 0.1 }, { -0.074, 0.341, -1.03 }, { 0, -10, 144 }, { 255, 228, 120 }, "neon", 0 },
		{ "ell", { 0.28, 0.6, 0.1 }, { 0.294, 0.341, -1.03 }, { 0, -10, 216 }, { 255, 228, 120 }, "neon", 0 },
		{ "ell", { 0.28, 0.6, 0.1 }, { 0.408, 0.699, -1.03 }, { 0, -10, 288 }, { 255, 228, 120 }, "neon", 0 },
		{ "cyl", { 0.25, 1, 1 }, { -1.25, -1.25, -0.6 }, { 70, 20, 90 }, { 255, 200, 50 }, "metal", 0 },
		{ "cyl", { 0.25, 1, 1 }, { 1.3, -1.3, -0.3 }, { 110, 20, 90 }, { 255, 200, 50 }, "metal", 0 },
		{ "cyl", { 0.25, 1, 1 }, { -1, -1.35, 0.9 }, { 85, 20, 90 }, { 255, 200, 50 }, "metal", 0 },
		{ "ball", { 0.35, 0.35, 0.35 }, { 1, 1.55, -1 }, { 0, 0, 0 }, { 255, 255, 230 }, "neon", 0 },
	},
	LuckyDiver = {
		{ "ell", { 0.8, 1.05, 0.32 }, { -0.905, 0.759, 0 }, { 0, 0, 27 }, { 70, 190, 70 }, "plastic", 0 },
		{ "ell", { 0.8, 1.05, 0.32 }, { -0.509, 1.155, 0 }, { 0, 0, 63 }, { 70, 190, 70 }, "plastic", 0 },
		{ "ell", { 0.08, 0.95, 0.34 }, { -0.424, 0.674, -0.02 }, { 0, 0, 45 }, { 40, 130, 45 }, "plastic", 0 },
		{ "ell", { 0.22, 0.35, 0.34 }, { -0.516, 0.936, -0.04 }, { 0, 0, 45 }, { 130, 230, 110 }, "neon", 0 },
		{ "ell", { 0.8, 1.05, 0.32 }, { -0.509, -0.655, 0 }, { 0, 0, 117 }, { 70, 190, 70 }, "plastic", 0 },
		{ "ell", { 0.8, 1.05, 0.32 }, { -0.905, -0.259, 0 }, { 0, 0, 153 }, { 70, 190, 70 }, "plastic", 0 },
		{ "ell", { 0.08, 0.95, 0.34 }, { -0.424, -0.174, -0.02 }, { 0, 0, 135 }, { 40, 130, 45 }, "plastic", 0 },
		{ "ell", { 0.22, 0.35, 0.34 }, { -0.686, -0.266, -0.04 }, { 0, 0, 135 }, { 130, 230, 110 }, "neon", 0 },
		{ "ell", { 0.8, 1.05, 0.32 }, { 0.905, -0.259, 0 }, { 0, 0, 207 }, { 70, 190, 70 }, "plastic", 0 },
		{ "ell", { 0.8, 1.05, 0.32 }, { 0.509, -0.655, 0 }, { 0, 0, 243 }, { 70, 190, 70 }, "plastic", 0 },
		{ "ell", { 0.08, 0.95, 0.34 }, { 0.424, -0.174, -0.02 }, { 0, 0, 225 }, { 40, 130, 45 }, "plastic", 0 },
		{ "ell", { 0.22, 0.35, 0.34 }, { 0.516, -0.436, -0.04 }, { 0, 0, 225 }, { 130, 230, 110 }, "neon", 0 },
		{ "ell", { 0.8, 1.05, 0.32 }, { 0.509, 1.155, 0 }, { 0, 0, 297 }, { 70, 190, 70 }, "plastic", 0 },
		{ "ell", { 0.8, 1.05, 0.32 }, { 0.905, 0.759, 0 }, { 0, 0, 333 }, { 70, 190, 70 }, "plastic", 0 },
		{ "ell", { 0.08, 0.95, 0.34 }, { 0.424, 0.674, -0.02 }, { 0, 0, 315 }, { 40, 130, 45 }, "plastic", 0 },
		{ "ell", { 0.22, 0.35, 0.34 }, { 0.686, 0.766, -0.04 }, { 0, 0, 315 }, { 130, 230, 110 }, "neon", 0 },
		{ "ball", { 0.55, 0.55, 0.55 }, { 0, 0.25, -0.05 }, { 0, 0, 0 }, { 40, 130, 45 }, "plastic", 0 },
		{ "ball", { 0.22, 0.22, 0.22 }, { 0.12, -0.25, 0.05 }, { 0, 0, 0 }, { 40, 130, 45 }, "plastic", 0 },
		{ "ball", { 0.22, 0.22, 0.22 }, { 0.22, -0.57, 0.05 }, { 0, 0, 0 }, { 40, 130, 45 }, "plastic", 0 },
		{ "ball", { 0.22, 0.22, 0.22 }, { 0.32, -0.89, 0.05 }, { 0, 0, 0 }, { 40, 130, 45 }, "plastic", 0 },
		{ "ball", { 0.22, 0.22, 0.22 }, { 0.42, -1.21, 0.05 }, { 0, 0, 0 }, { 40, 130, 45 }, "plastic", 0 },
		{ "ball", { 0.22, 0.22, 0.22 }, { 0.52, -1.53, 0.05 }, { 0, 0, 0 }, { 40, 130, 45 }, "plastic", 0 },
		{ "ball", { 0.3, 0.3, 0.3 }, { 0.55, 0.9, -0.25 }, { 0, 0, 0 }, { 220, 245, 255 }, "glass", 0.3 },
	},
	BoostLuck = {
		{ "ell", { 0.8, 1.05, 0.32 }, { -0.905, 0.759, 0 }, { 0, 0, 27 }, { 70, 190, 70 }, "plastic", 0 },
		{ "ell", { 0.8, 1.05, 0.32 }, { -0.509, 1.155, 0 }, { 0, 0, 63 }, { 70, 190, 70 }, "plastic", 0 },
		{ "ell", { 0.08, 0.95, 0.34 }, { -0.424, 0.674, -0.02 }, { 0, 0, 45 }, { 40, 130, 45 }, "plastic", 0 },
		{ "ell", { 0.22, 0.35, 0.34 }, { -0.516, 0.936, -0.04 }, { 0, 0, 45 }, { 130, 230, 110 }, "neon", 0 },
		{ "ell", { 0.8, 1.05, 0.32 }, { -0.509, -0.655, 0 }, { 0, 0, 117 }, { 70, 190, 70 }, "plastic", 0 },
		{ "ell", { 0.8, 1.05, 0.32 }, { -0.905, -0.259, 0 }, { 0, 0, 153 }, { 70, 190, 70 }, "plastic", 0 },
		{ "ell", { 0.08, 0.95, 0.34 }, { -0.424, -0.174, -0.02 }, { 0, 0, 135 }, { 40, 130, 45 }, "plastic", 0 },
		{ "ell", { 0.22, 0.35, 0.34 }, { -0.686, -0.266, -0.04 }, { 0, 0, 135 }, { 130, 230, 110 }, "neon", 0 },
		{ "ell", { 0.8, 1.05, 0.32 }, { 0.905, -0.259, 0 }, { 0, 0, 207 }, { 70, 190, 70 }, "plastic", 0 },
		{ "ell", { 0.8, 1.05, 0.32 }, { 0.509, -0.655, 0 }, { 0, 0, 243 }, { 70, 190, 70 }, "plastic", 0 },
		{ "ell", { 0.08, 0.95, 0.34 }, { 0.424, -0.174, -0.02 }, { 0, 0, 225 }, { 40, 130, 45 }, "plastic", 0 },
		{ "ell", { 0.22, 0.35, 0.34 }, { 0.516, -0.436, -0.04 }, { 0, 0, 225 }, { 130, 230, 110 }, "neon", 0 },
		{ "ell", { 0.8, 1.05, 0.32 }, { 0.509, 1.155, 0 }, { 0, 0, 297 }, { 70, 190, 70 }, "plastic", 0 },
		{ "ell", { 0.8, 1.05, 0.32 }, { 0.905, 0.759, 0 }, { 0, 0, 333 }, { 70, 190, 70 }, "plastic", 0 },
		{ "ell", { 0.08, 0.95, 0.34 }, { 0.424, 0.674, -0.02 }, { 0, 0, 315 }, { 40, 130, 45 }, "plastic", 0 },
		{ "ell", { 0.22, 0.35, 0.34 }, { 0.686, 0.766, -0.04 }, { 0, 0, 315 }, { 130, 230, 110 }, "neon", 0 },
		{ "ball", { 0.55, 0.55, 0.55 }, { 0, 0.25, -0.05 }, { 0, 0, 0 }, { 40, 130, 45 }, "plastic", 0 },
		{ "ball", { 0.22, 0.22, 0.22 }, { 0.12, -0.25, 0.05 }, { 0, 0, 0 }, { 40, 130, 45 }, "plastic", 0 },
		{ "ball", { 0.22, 0.22, 0.22 }, { 0.22, -0.57, 0.05 }, { 0, 0, 0 }, { 40, 130, 45 }, "plastic", 0 },
		{ "ball", { 0.22, 0.22, 0.22 }, { 0.32, -0.89, 0.05 }, { 0, 0, 0 }, { 40, 130, 45 }, "plastic", 0 },
		{ "ball", { 0.22, 0.22, 0.22 }, { 0.42, -1.21, 0.05 }, { 0, 0, 0 }, { 40, 130, 45 }, "plastic", 0 },
		{ "ball", { 0.22, 0.22, 0.22 }, { 0.52, -1.53, 0.05 }, { 0, 0, 0 }, { 40, 130, 45 }, "plastic", 0 },
		{ "ball", { 0.3, 0.3, 0.3 }, { 0.55, 0.9, -0.25 }, { 0, 0, 0 }, { 220, 245, 255 }, "glass", 0.3 },
	},
	AutoHaul = {
		{ "block", { 2.2, 2, 2.2 }, { 0, -0.5, 0 }, { 0, 25, 0 }, { 165, 115, 66 }, "wood", 0 },
		{ "block", { 2.24, 0.06, 2.24 }, { 0, -0.85, 0 }, { 0, 25, 0 }, { 110, 72, 38 }, "plastic", 0 },
		{ "block", { 2.24, 0.06, 2.24 }, { 0, -0.2, 0 }, { 0, 25, 0 }, { 110, 72, 38 }, "plastic", 0 },
		{ "block", { 2.24, 0.06, 2.24 }, { 0, 0.45, 0 }, { 0, 25, 0 }, { 110, 72, 38 }, "plastic", 0 },
		{ "block", { 0.2, 2.1, 0.2 }, { 1.422, -0.5, 0.518 }, { 0, 25, 0 }, { 120, 125, 135 }, "metal", 0 },
		{ "block", { 0.2, 2.1, 0.2 }, { 0.518, -0.5, -1.422 }, { 0, 25, 0 }, { 120, 125, 135 }, "metal", 0 },
		{ "block", { 0.2, 2.1, 0.2 }, { -0.518, -0.5, 1.422 }, { 0, 25, 0 }, { 120, 125, 135 }, "metal", 0 },
		{ "block", { 0.2, 2.1, 0.2 }, { -1.422, -0.5, -0.518 }, { 0, 25, 0 }, { 120, 125, 135 }, "metal", 0 },
		{ "block", { 0.12, 0.3, 0.2 }, { 0, 0.65, 0 }, { 0, 0, 0 }, { 120, 125, 135 }, "metal", 0 },
		{ "block", { 0.12, 0.3, 0.2 }, { 0, 0.97, 0 }, { 0, 90, 0 }, { 120, 125, 135 }, "metal", 0 },
		{ "block", { 0.12, 0.3, 0.2 }, { 0, 1.29, 0 }, { 0, 180, 0 }, { 120, 125, 135 }, "metal", 0 },
		{ "block", { 0.12, 0.3, 0.2 }, { 0, 1.61, 0 }, { 0, 270, 0 }, { 120, 125, 135 }, "metal", 0 },
		{ "block", { 0.18, 0.7, 0.18 }, { 0, 2, 0 }, { 0, 0, 0 }, { 120, 125, 135 }, "metal", 0 },
		{ "block", { 2.8, 0.3, 0.3 }, { 0, 2.35, 0 }, { 0, 0, 0 }, { 255, 175, 40 }, "metal", 0 },
		{ "block", { 0.25, 0.45, 0.25 }, { 1.3, 2.05, 0 }, { 0, 0, 0 }, { 255, 175, 40 }, "metal", 0 },
	},
	PetSlots = {
		{ "ell", { 1.8, 1.45, 0.55 }, { 0, -0.45, 0 }, { 0, 0, 0 }, { 255, 140, 195 }, "plastic", 0 },
		{ "ell", { 0.6, 0.35, 0.2 }, { -0.35, -0.2, -0.25 }, { 0, 0, 20 }, { 255, 220, 240 }, "neon", 0 },
		{ "ell", { 0.75, 0.95, 0.5 }, { -1, 0.55, 0 }, { 0, 0, 20 }, { 225, 85, 155 }, "plastic", 0 },
		{ "ell", { 0.75, 0.95, 0.5 }, { -0.35, 1, 0 }, { 0, 0, 5 }, { 225, 85, 155 }, "plastic", 0 },
		{ "ell", { 0.75, 0.95, 0.5 }, { 0.35, 1, 0 }, { 0, 0, -5 }, { 225, 85, 155 }, "plastic", 0 },
		{ "ell", { 0.75, 0.95, 0.5 }, { 1, 0.55, 0 }, { 0, 0, -20 }, { 225, 85, 155 }, "plastic", 0 },
		{ "ell", { 0.22, 0.28, 0.15 }, { -0.42, 1.15, -0.22 }, { 0, 0, 0 }, { 255, 220, 240 }, "neon", 0 },
		{ "ell", { 0.22, 0.28, 0.15 }, { 0.28, 1.15, -0.22 }, { 0, 0, 0 }, { 255, 220, 240 }, "neon", 0 },
	},
	VIP = {
		{ "ell", { 2.1, 1.3, 2.1 }, { 0, 0.15, 0 }, { 0, 0, 0 }, { 170, 25, 45 }, "fabric", 0 },
		{ "cyl", { 0.95, 2.7, 2.7 }, { 0, -0.55, 0 }, { 0, 0, 90 }, { 255, 200, 50 }, "metal", 0 },
		{ "cyl", { 0.2, 2.85, 2.85 }, { 0, -0.98, 0 }, { 0, 0, 90 }, { 205, 145, 30 }, "metal", 0 },
		{ "cyl", { 0.2, 2.85, 2.85 }, { 0, -0.12, 0 }, { 0, 0, 90 }, { 205, 145, 30 }, "metal", 0 },
		{ "ball", { 0.42, 0.42, 0.42 }, { 0, 1, 0 }, { 0, 0, 0 }, { 255, 228, 120 }, "metal", 0 },
		{ "ell", { 0.6, 1.45, 0.32 }, { 0, 0.45, -1.2 }, { 0, 0, 0 }, { 255, 200, 50 }, "metal", 0 },
		{ "ball", { 0.42, 0.42, 0.42 }, { 0, 1.25, -1.224 }, { 0, 0, 0 }, { 255, 228, 120 }, "metal", 0 },
		{ "ell", { 0.5, 0.42, 0.25 }, { 0, -0.55, -1.356 }, { 0, 0, 0 }, { 255, 40, 70 }, "neon", 0 },
		{ "ell", { 0.6, 1.45, 0.32 }, { 1.141, 0.45, -0.371 }, { 0, -72, 0 }, { 255, 200, 50 }, "metal", 0 },
		{ "ball", { 0.42, 0.42, 0.42 }, { 1.164, 1.25, -0.378 }, { 0, 0, 0 }, { 255, 228, 120 }, "metal", 0 },
		{ "ell", { 0.5, 0.42, 0.25 }, { 1.29, -0.55, -0.419 }, { 0, -72, 0 }, { 60, 150, 255 }, "neon", 0 },
		{ "ell", { 0.6, 1.45, 0.32 }, { 0.705, 0.45, 0.971 }, { 0, -144, 0 }, { 255, 200, 50 }, "metal", 0 },
		{ "ball", { 0.42, 0.42, 0.42 }, { 0.719, 1.25, 0.99 }, { 0, 0, 0 }, { 255, 228, 120 }, "metal", 0 },
		{ "ell", { 0.5, 0.42, 0.25 }, { 0.797, -0.55, 1.097 }, { 0, -144, 0 }, { 70, 220, 110 }, "neon", 0 },
		{ "ell", { 0.6, 1.45, 0.32 }, { -0.705, 0.45, 0.971 }, { 0, -216, 0 }, { 255, 200, 50 }, "metal", 0 },
		{ "ball", { 0.42, 0.42, 0.42 }, { -0.719, 1.25, 0.99 }, { 0, 0, 0 }, { 255, 228, 120 }, "metal", 0 },
		{ "ell", { 0.5, 0.42, 0.25 }, { -0.797, -0.55, 1.097 }, { 0, -216, 0 }, { 180, 90, 255 }, "neon", 0 },
		{ "ell", { 0.6, 1.45, 0.32 }, { -1.141, 0.45, -0.371 }, { 0, -288, 0 }, { 255, 200, 50 }, "metal", 0 },
		{ "ball", { 0.42, 0.42, 0.42 }, { -1.164, 1.25, -0.378 }, { 0, 0, 0 }, { 255, 228, 120 }, "metal", 0 },
		{ "ell", { 0.5, 0.42, 0.25 }, { -1.29, -0.55, -0.419 }, { 0, -288, 0 }, { 255, 150, 30 }, "neon", 0 },
		{ "ball", { 0.2, 0.2, 0.2 }, { 0, -0.98, -1.42 }, { 0, 0, 0 }, { 255, 250, 235 }, "plastic", 0 },
		{ "ball", { 0.2, 0.2, 0.2 }, { 0.616, -0.98, -1.279 }, { 0, 0, 0 }, { 255, 250, 235 }, "plastic", 0 },
		{ "ball", { 0.2, 0.2, 0.2 }, { 1.11, -0.98, -0.885 }, { 0, 0, 0 }, { 255, 250, 235 }, "plastic", 0 },
		{ "ball", { 0.2, 0.2, 0.2 }, { 1.384, -0.98, -0.316 }, { 0, 0, 0 }, { 255, 250, 235 }, "plastic", 0 },
		{ "ball", { 0.2, 0.2, 0.2 }, { 1.384, -0.98, 0.316 }, { 0, 0, 0 }, { 255, 250, 235 }, "plastic", 0 },
		{ "ball", { 0.2, 0.2, 0.2 }, { 1.11, -0.98, 0.885 }, { 0, 0, 0 }, { 255, 250, 235 }, "plastic", 0 },
		{ "ball", { 0.2, 0.2, 0.2 }, { 0.616, -0.98, 1.279 }, { 0, 0, 0 }, { 255, 250, 235 }, "plastic", 0 },
		{ "ball", { 0.2, 0.2, 0.2 }, { 0, -0.98, 1.42 }, { 0, 0, 0 }, { 255, 250, 235 }, "plastic", 0 },
		{ "ball", { 0.2, 0.2, 0.2 }, { -0.616, -0.98, 1.279 }, { 0, 0, 0 }, { 255, 250, 235 }, "plastic", 0 },
		{ "ball", { 0.2, 0.2, 0.2 }, { -1.11, -0.98, 0.885 }, { 0, 0, 0 }, { 255, 250, 235 }, "plastic", 0 },
		{ "ball", { 0.2, 0.2, 0.2 }, { -1.384, -0.98, 0.316 }, { 0, 0, 0 }, { 255, 250, 235 }, "plastic", 0 },
		{ "ball", { 0.2, 0.2, 0.2 }, { -1.384, -0.98, -0.316 }, { 0, 0, 0 }, { 255, 250, 235 }, "plastic", 0 },
		{ "ball", { 0.2, 0.2, 0.2 }, { -1.11, -0.98, -0.885 }, { 0, 0, 0 }, { 255, 250, 235 }, "plastic", 0 },
		{ "ball", { 0.2, 0.2, 0.2 }, { -0.616, -0.98, -1.279 }, { 0, 0, 0 }, { 255, 250, 235 }, "plastic", 0 },
	},
	BigStorage = {
		{ "block", { 2.7, 1.5, 1.8 }, { 0, -0.55, 0 }, { 0, 20, 0 }, { 150, 95, 52 }, "wood", 0 },
		{ "block", { 2.74, 0.05, 1.84 }, { 0, -0.95, 0 }, { 0, 20, 0 }, { 95, 58, 30 }, "plastic", 0 },
		{ "block", { 2.74, 0.05, 1.84 }, { 0, -0.45, 0 }, { 0, 20, 0 }, { 95, 58, 30 }, "plastic", 0 },
		{ "cyl", { 2.75, 1.82, 1.82 }, { 0, 0.2, 0 }, { 0, 20, 0 }, { 150, 95, 52 }, "wood", 0 },
		{ "block", { 0.25, 2.25, 1.95 }, { -1, -0.15, 0.36 }, { 0, 20, 0 }, { 255, 200, 50 }, "metal", 0 },
		{ "block", { 0.25, 2.25, 1.95 }, { 1, -0.15, -0.36 }, { 0, 20, 0 }, { 255, 200, 50 }, "metal", 0 },
		{ "block", { 0.6, 0.7, 0.22 }, { -0.32, -0.15, -0.9 }, { 0, 20, 0 }, { 255, 228, 120 }, "metal", 0 },
		{ "ball", { 0.2, 0.2, 0.2 }, { -0.34, -0.2, -1.02 }, { 0, 0, 0 }, { 40, 30, 20 }, "plastic", 0 },
		{ "ball", { 0.45, 0.45, 0.45 }, { 0.3, 1.15, -0.2 }, { 0, 0, 0 }, { 255, 228, 120 }, "metal", 0 },
		{ "ball", { 0.45, 0.45, 0.45 }, { -0.4, 1.1, 0.1 }, { 0, 0, 0 }, { 90, 220, 255 }, "neon", 0 },
		{ "ball", { 0.45, 0.45, 0.45 }, { 0, 1.25, 0.2 }, { 0, 0, 0 }, { 255, 60, 90 }, "neon", 0 },
		{ "ball", { 0.45, 0.45, 0.45 }, { 0.75, 1, 0.1 }, { 0, 0, 0 }, { 255, 200, 50 }, "metal", 0 },
		{ "ball", { 0.45, 0.45, 0.45 }, { -0.8, 1, -0.1 }, { 0, 0, 0 }, { 255, 200, 50 }, "metal", 0 },
		{ "ball", { 0.45, 0.45, 0.45 }, { 0.4, 1.3, 0.3 }, { 0, 0, 0 }, { 120, 255, 140 }, "neon", 0 },
		{ "cyl", { 0.12, 0.6, 0.6 }, { -0.1, 1.35, -0.3 }, { 40, 20, 90 }, { 255, 200, 50 }, "metal", 0 },
	},
	BigTank = {
		{ "block", { 3, 2.2, 1.8 }, { 0, 0, 0 }, { 0, 15, 0 }, { 200, 235, 255 }, "glass", 0.7 },
		{ "block", { 2.85, 1.55, 1.65 }, { 0, -0.3, 0 }, { 0, 15, 0 }, { 60, 150, 240 }, "plastic", 0.4 },
		{ "block", { 2.85, 0.28, 1.65 }, { 0, -0.95, 0 }, { 0, 15, 0 }, { 235, 215, 150 }, "plastic", 0 },
		{ "block", { 3.1, 0.18, 1.9 }, { 0, 1.12, 0 }, { 0, 15, 0 }, { 40, 50, 70 }, "metal", 0 },
		{ "block", { 3.1, 0.18, 1.9 }, { 0, -1.12, 0 }, { 0, 15, 0 }, { 40, 50, 70 }, "metal", 0 },
		{ "block", { 0.12, 2.2, 0.12 }, { 1.657, 0, 0.467 }, { 0, 15, 0 }, { 40, 50, 70 }, "metal", 0 },
		{ "block", { 0.12, 2.2, 0.12 }, { 1.202, 0, -1.233 }, { 0, 15, 0 }, { 40, 50, 70 }, "metal", 0 },
		{ "block", { 0.12, 2.2, 0.12 }, { -1.202, 0, 1.233 }, { 0, 15, 0 }, { 40, 50, 70 }, "metal", 0 },
		{ "block", { 0.12, 2.2, 0.12 }, { -1.657, 0, -0.467 }, { 0, 15, 0 }, { 40, 50, 70 }, "metal", 0 },
		{ "block", { 0.55, 0.7, 0.45 }, { 0.75, -0.45, 0.2 }, { 0, 15, 0 }, { 170, 170, 185 }, "plastic", 0 },
		{ "block", { 0.25, 0.25, 0.25 }, { 0.62, -0.02, 0.24 }, { 0, 15, 0 }, { 170, 170, 185 }, "plastic", 0 },
		{ "block", { 0.25, 0.25, 0.25 }, { 0.9, -0.02, 0.15 }, { 0, 15, 0 }, { 170, 170, 185 }, "plastic", 0 },
		{ "ball", { 0.45, 0.45, 0.45 }, { -0.9, -0.8, 0.3 }, { 0, 0, 0 }, { 120, 120, 130 }, "plastic", 0 },
		{ "ball", { 0.3, 0.3, 0.3 }, { -0.6, -0.85, 0.5 }, { 0, 0, 0 }, { 140, 140, 150 }, "plastic", 0 },
		{ "ell", { 1, 0.6, 0.35 }, { -0.45, -0.05, -0.45 }, { 0, 15, 0 }, { 255, 140, 40 }, "plastic", 0 },
		{ "ell", { 1.02, 0.62, 0.1 }, { -0.45, -0.05, -0.45 }, { 0, 15, 0 }, { 255, 255, 255 }, "plastic", 0 },
		{ "block", { 0.1, 0.55, 0.4 }, { -1, -0.05, -0.3 }, { 0, 15, 0 }, { 255, 200, 150 }, "plastic", 0 },
		{ "ell", { 0.75, 0.45, 0.28 }, { 0.55, 0.35, -0.2 }, { 0, 195, 0 }, { 60, 230, 210 }, "plastic", 0 },
		{ "ball", { 0.2, 0.2, 0.2 }, { -1.05, -0.7, 0.45 }, { 0, 0, 0 }, { 60, 170, 70 }, "plastic", 0 },
		{ "ball", { 0.2, 0.2, 0.2 }, { -0.983, -0.45, 0.45 }, { 0, 0, 0 }, { 60, 170, 70 }, "plastic", 0 },
		{ "ball", { 0.2, 0.2, 0.2 }, { -0.977, -0.2, 0.45 }, { 0, 0, 0 }, { 60, 170, 70 }, "plastic", 0 },
		{ "ball", { 0.2, 0.2, 0.2 }, { -1.039, 0.05, 0.45 }, { 0, 0, 0 }, { 60, 170, 70 }, "plastic", 0 },
		{ "ball", { 0.14, 0.14, 0.14 }, { 0.1, 0.55, -0.5 }, { 0, 0, 0 }, { 230, 250, 255 }, "glass", 0.35 },
		{ "ball", { 0.17, 0.17, 0.17 }, { 0.25, 0.8, -0.5 }, { 0, 0, 0 }, { 230, 250, 255 }, "glass", 0.35 },
		{ "ball", { 0.2, 0.2, 0.2 }, { 0.05, 0.98, -0.5 }, { 0, 0, 0 }, { 230, 250, 255 }, "glass", 0.35 },
	},
	DoubleDamage = {
		{ "ball", { 1.7, 1.7, 1.7 }, { 0, 0.25, 0.6 }, { 0, 0, 0 }, { 255, 140, 40 }, "neon", 0.5 },
		{ "block", { 0.32, 2.4, 0.1 }, { -0.225, 0.468, -0.1 }, { 0, 0, 40 }, { 220, 228, 240 }, "metal", 0 },
		{ "block", { 0.06, 2, 0.12 }, { -0.193, 0.43, -0.1 }, { 0, 0, 40 }, { 160, 170, 190 }, "metal", 0 },
		{ "block", { 0.23, 0.23, 0.1 }, { -1.016, 1.41, -0.1 }, { 0, 0, 85 }, { 220, 228, 240 }, "metal", 0 },
		{ "block", { 1.15, 0.2, 0.22 }, { 0.591, -0.505, -0.1 }, { 0, 0, 40 }, { 255, 200, 50 }, "metal", 0 },
		{ "ball", { 0.28, 0.28, 0.28 }, { 0.147, -0.878, -0.1 }, { 0, 0, 0 }, { 255, 228, 120 }, "metal", 0 },
		{ "ball", { 0.28, 0.28, 0.28 }, { 1.036, -0.132, -0.1 }, { 0, 0, 0 }, { 255, 228, 120 }, "metal", 0 },
		{ "block", { 0.24, 0.18, 0.24 }, { 0.72, -0.658, -0.1 }, { 0, 0, 40 }, { 95, 50, 30 }, "plastic", 0 },
		{ "block", { 0.24, 0.18, 0.24 }, { 0.848, -0.811, -0.1 }, { 0, 0, 40 }, { 60, 30, 18 }, "plastic", 0 },
		{ "block", { 0.24, 0.18, 0.24 }, { 0.977, -0.964, -0.1 }, { 0, 0, 40 }, { 95, 50, 30 }, "plastic", 0 },
		{ "ball", { 0.36, 0.36, 0.36 }, { 1.144, -1.164, -0.1 }, { 0, 0, 0 }, { 255, 50, 70 }, "neon", 0 },
		{ "block", { 0.32, 2.4, 0.1 }, { 0.225, 0.468, 0.1 }, { 0, 0, -40 }, { 220, 228, 240 }, "metal", 0 },
		{ "block", { 0.06, 2, 0.12 }, { 0.193, 0.43, 0.1 }, { 0, 0, -40 }, { 160, 170, 190 }, "metal", 0 },
		{ "block", { 0.23, 0.23, 0.1 }, { 1.016, 1.41, 0.1 }, { 0, 0, 5 }, { 220, 228, 240 }, "metal", 0 },
		{ "block", { 1.15, 0.2, 0.22 }, { -0.591, -0.505, 0.1 }, { 0, 0, -40 }, { 255, 200, 50 }, "metal", 0 },
		{ "ball", { 0.28, 0.28, 0.28 }, { -1.036, -0.132, 0.1 }, { 0, 0, 0 }, { 255, 228, 120 }, "metal", 0 },
		{ "ball", { 0.28, 0.28, 0.28 }, { -0.147, -0.878, 0.1 }, { 0, 0, 0 }, { 255, 228, 120 }, "metal", 0 },
		{ "block", { 0.24, 0.18, 0.24 }, { -0.72, -0.658, 0.1 }, { 0, 0, -40 }, { 95, 50, 30 }, "plastic", 0 },
		{ "block", { 0.24, 0.18, 0.24 }, { -0.848, -0.811, 0.1 }, { 0, 0, -40 }, { 60, 30, 18 }, "plastic", 0 },
		{ "block", { 0.24, 0.18, 0.24 }, { -0.977, -0.964, 0.1 }, { 0, 0, -40 }, { 95, 50, 30 }, "plastic", 0 },
		{ "ball", { 0.36, 0.36, 0.36 }, { -1.144, -1.164, 0.1 }, { 0, 0, 0 }, { 255, 50, 70 }, "neon", 0 },
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
	wood = Enum.Material.Wood,
	fabric = Enum.Material.Fabric,
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
