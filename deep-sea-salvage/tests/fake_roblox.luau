-- ===== Fake Roblox environment v2: real Vector3/CFrame, child tracking, fake clocks =====
local fakeNow, fakeClock, fakeTime = 1000, 500, 1700000000
local os = { clock = function() return fakeClock end, time = function() return fakeTime end }

-- Vector3
local Vec = {}
local function v3(x, y, z)
	return setmetatable({ X = x or 0, Y = y or 0, Z = z or 0 }, Vec)
end
Vec.__add = function(a, b) return v3(a.X + b.X, a.Y + b.Y, a.Z + b.Z) end
Vec.__sub = function(a, b) return v3(a.X - b.X, a.Y - b.Y, a.Z - b.Z) end
Vec.__mul = function(a, b)
	if type(a) == "number" then return v3(b.X * a, b.Y * a, b.Z * a) end
	if type(b) == "number" then return v3(a.X * b, a.Y * b, a.Z * b) end
	return v3(a.X * b.X, a.Y * b.Y, a.Z * b.Z)
end
Vec.__div = function(a, b) return v3(a.X / b, a.Y / b, a.Z / b) end
Vec.__unm = function(a) return v3(-a.X, -a.Y, -a.Z) end
Vec.__eq = function(a, b) return a.X == b.X and a.Y == b.Y and a.Z == b.Z end
Vec.__tostring = function(a) return string.format("(%.1f, %.1f, %.1f)", a.X, a.Y, a.Z) end
Vec.__index = function(v, k)
	if k == "Magnitude" then
		return math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
	elseif k == "Unit" then
		local m = math.sqrt(v.X * v.X + v.Y * v.Y + v.Z * v.Z)
		return m > 0 and v3(v.X / m, v.Y / m, v.Z / m) or v3(0, 0, 0)
	elseif k == "Dot" then
		return function(a, b) return a.X * b.X + a.Y * b.Y + a.Z * b.Z end
	elseif k == "Cross" then
		return function(a, b) return v3(a.Y * b.Z - a.Z * b.Y, a.Z * b.X - a.X * b.Z, a.X * b.Y - a.Y * b.X) end
	elseif k == "Lerp" then
		return function(a, b, t) return a + (b - a) * t end
	end
	return nil
end
local Vector3 = { new = v3 }

-- CFrame (position + row-major 3x3 rotation)
local CF = {}
local I = { 1, 0, 0, 0, 1, 0, 0, 0, 1 }
local function cfm(p, m) return setmetatable({ p = p, m = m }, CF) end
local function mulMat(a, b)
	local r = {}
	for i = 0, 2 do
		for j = 0, 2 do
			r[i * 3 + j + 1] = a[i * 3 + 1] * b[j + 1] + a[i * 3 + 2] * b[3 + j + 1] + a[i * 3 + 3] * b[6 + j + 1]
		end
	end
	return r
end
local function mulVec(m, v)
	return v3(m[1] * v.X + m[2] * v.Y + m[3] * v.Z, m[4] * v.X + m[5] * v.Y + m[6] * v.Z, m[7] * v.X + m[8] * v.Y + m[9] * v.Z)
end
local function lookAt(at, target, up)
	local look = (target - at).Unit
	if look.Magnitude == 0 then return cfm(at, I) end
	local right = look:Cross(up or v3(0, 1, 0)).Unit
	if right.Magnitude == 0 then right = v3(1, 0, 0) end
	local up2 = right:Cross(look)
	return cfm(at, { right.X, up2.X, -look.X, right.Y, up2.Y, -look.Y, right.Z, up2.Z, -look.Z })
end
CF.__mul = function(a, b)
	if getmetatable(b) == CF then
		return cfm(a.p + mulVec(a.m, b.p), mulMat(a.m, b.m))
	end
	return a.p + mulVec(a.m, b)
end
CF.__add = function(a, v) return cfm(a.p + v, a.m) end
CF.__sub = function(a, v) return cfm(a.p - v, a.m) end
CF.__index = function(c, k)
	if k == "Position" then return c.p
	elseif k == "X" then return c.p.X
	elseif k == "Y" then return c.p.Y
	elseif k == "Z" then return c.p.Z
	elseif k == "LookVector" then return v3(-c.m[3], -c.m[6], -c.m[9])
	elseif k == "RightVector" then return v3(c.m[1], c.m[4], c.m[7])
	elseif k == "UpVector" then return v3(c.m[2], c.m[5], c.m[8])
	elseif k == "Lerp" then
		return function(a, b, t) return cfm(a.p:Lerp(b.p, t), t < 0.5 and a.m or b.m) end
	end
	return nil
end
local function angles(rx, ry, rz)
	local cx, sx, cy, sy, cz, sz = math.cos(rx), math.sin(rx), math.cos(ry), math.sin(ry), math.cos(rz), math.sin(rz)
	local Rx = { 1, 0, 0, 0, cx, -sx, 0, sx, cx }
	local Ry = { cy, 0, sy, 0, 1, 0, -sy, 0, cy }
	local Rz = { cz, -sz, 0, sz, cz, 0, 0, 0, 1 }
	return cfm(v3(0, 0, 0), mulMat(mulMat(Rx, Ry), Rz))
end
local CFrame = {
	new = function(x, y, z)
		if x == nil then return cfm(v3(0, 0, 0), I) end
		if type(x) == "table" then
			if y then return lookAt(x, y) end
			return cfm(x, I)
		end
		return cfm(v3(x, y, z), I)
	end,
	Angles = angles,
	fromEulerAnglesXYZ = angles,
	lookAt = lookAt,
}

-- Generic mock instances with real parent/child tracking
local mt = {}
local function newMock(name)
	return setmetatable({ __name = name, __props = {}, __children = {}, __attrs = {} }, mt)
end
local function isA(obj, class)
	local cn = rawget(obj, "__props").ClassName
	if cn == class or class == "Instance" then return true end
	if class == "BasePart" then return cn == "Part" or cn == "SpawnLocation" or cn == "WedgePart" end
	return false
end
local function descendants(obj, out)
	for _, c in ipairs(rawget(obj, "__children")) do
		table.insert(out, c)
		descendants(c, out)
	end
	return out
end
local methods = {
	FindFirstChild = function(self, name)
		for _, c in ipairs(rawget(self, "__children")) do
			if rawget(c, "__props").Name == name then return c end
		end
		return nil
	end,
	FindFirstChildOfClass = function(self, class)
		for _, c in ipairs(rawget(self, "__children")) do
			if rawget(c, "__props").ClassName == class then return c end
		end
		return nil
	end,
	WaitForChild = function(self, name)
		for _, c in ipairs(rawget(self, "__children")) do
			if rawget(c, "__props").Name == name then return c end
		end
		return newMock(name)
	end,
	GetChildren = function(self) return table.clone(rawget(self, "__children")) end,
	GetDescendants = function(self) return descendants(self, {}) end,
	IsA = function(self, class) return isA(self, class) end,
	Destroy = function(self)
		local parent = rawget(self, "__props").Parent
		if type(parent) == "table" and rawget(parent, "__children") then
			local list = rawget(parent, "__children")
			local i = table.find(list, self)
			if i then table.remove(list, i) end
		end
		rawget(self, "__props").Parent = nil
		rawset(self, "__destroyed", true)
	end,
	SetAttribute = function(self, k, v) rawget(self, "__attrs")[k] = v end,
	GetAttribute = function(self, k) return rawget(self, "__attrs")[k] end,
	GetPivot = function(self)
		local primary = rawget(self, "__props").PrimaryPart
		local cf = primary and rawget(primary, "__props").CFrame
		return (getmetatable(cf) == CF) and cf or CFrame.new()
	end,
	PivotTo = function(self, cf)
		local primary = rawget(self, "__props").PrimaryPart
		if primary then rawget(primary, "__props").CFrame = cf end
	end,
	GetExtentsSize = function() return v3(4, 3, 4) end,
}
mt.__index = function(self, key)
	if key == "Connect" or key == "Once" then
		return function(_, fn)
			local hs = rawget(self, "__handlers") or {}
			rawset(self, "__handlers", hs)
			table.insert(hs, fn)
			return newMock("conn")
		end
	end
	local props = rawget(self, "__props")
	if props[key] ~= nil then return props[key] end
	if methods[key] then return methods[key] end
	if key == "Position" then
		local cf = props.CFrame
		if getmetatable(cf) == CF then return cf.p end
	end
	if key == "Parent" then return nil end
	local child = newMock(key)
	props[key] = child
	return child
end
mt.__newindex = function(self, key, value)
	local props = rawget(self, "__props")
	if key == "Parent" then
		local old = props.Parent
		if type(old) == "table" and rawget(old, "__children") then
			local list = rawget(old, "__children")
			local i = table.find(list, self)
			if i then table.remove(list, i) end
		end
		if type(value) == "table" and rawget(value, "__children") then
			table.insert(rawget(value, "__children"), self)
		end
	end
	props[key] = value
end
mt.__call = function() return newMock("ret") end
for _, op in ipairs({ "__add", "__sub", "__mul", "__div", "__unm", "__mod", "__pow", "__idiv" }) do
	mt[op] = function() return newMock("math") end
end
mt.__concat = function(a, b) return tostring(a) .. tostring(b) end
mt.__tostring = function(self) return "mock:" .. tostring(rawget(self, "__name")) end
mt.__len = function() return 0 end

local function handlers(signal)
	return rawget(signal, "__handlers") or {}
end

local function ctor()
	return setmetatable({}, { __index = function() return function() return newMock("value") end end })
end
local Vector2, UDim2, UDim = ctor(), ctor(), ctor()
local function color3(r, g, b, scale)
	local c = newMock("Color3")
	scale = scale or 1
	c.R, c.G, c.B = (tonumber(r) or 1) / scale, (tonumber(g) or 1) / scale, (tonumber(b) or 1) / scale
	c.ToHex = function() return "a0b0c0" end
	c.Lerp = function(self) return self end
	return c
end
local Color3 = {
	new = function(r, g, b) return color3(r, g, b, 1) end,
	fromRGB = function(r, g, b) return color3(r, g, b, 255) end,
	fromHSV = function() return color3(1, 1, 1, 1) end,
}
local TweenInfo, NumberRange, NumberSequence, ColorSequence = ctor(), ctor(), ctor(), ctor()
local NumberSequenceKeypoint = ctor()
local Enum = newMock("Enum")

local created = {}
local clientPlayer = nil
local clientErrors = {}
local notifications = {}
local lastState = {}
local announcements = {}

local Instance = {
	new = function(className)
		local obj = newMock(className)
		obj.ClassName = className
		obj.Name = className
		if className == "RemoteEvent" then
			obj.FireClient = function(self, p, payload)
				if self.Name == "StateUpdate" then
					lastState[p.UserId] = payload
				else
					notifications[p.UserId] = notifications[p.UserId] or {}
					table.insert(notifications[p.UserId], payload)
				end
				if clientPlayer and p == clientPlayer then
					for _, h in ipairs(handlers(self.OnClientEvent)) do
						local ok, err = pcall(h, payload)
						if not ok then table.insert(clientErrors, "OnClientEvent(" .. tostring(payload.kind or "state") .. "): " .. tostring(err)) end
					end
				end
			end
			obj.FireAllClients = function(self, payload)
				table.insert(announcements, payload)
				if clientPlayer then
					for _, h in ipairs(handlers(self.OnClientEvent)) do
						local ok, err = pcall(h, payload)
						if not ok then table.insert(clientErrors, "FireAllClients: " .. tostring(err)) end
					end
				end
			end
			obj.FireServer = function(self, ...)
				for _, h in ipairs(handlers(self.OnServerEvent)) do
					h(clientPlayer, ...)
				end
			end
		elseif className == "Humanoid" then
			obj.Health = 100
			obj.MaxHealth = 100
			obj.TakeDamage = function(self, d)
				self.Health = math.max(0, self.Health - d)
				for _, h in ipairs(handlers(self.HealthChanged)) do
					h(self.Health)
				end
			end
			obj.WalkSpeed = 16
		end
		table.insert(created, obj)
		return obj
	end,
}

local playersList = {}
local PlayersService = newMock("Players")
PlayersService.GetPlayers = function() return table.clone(playersList) end
PlayersService.GetNameFromUserIdAsync = function(_, id) return "User" .. tostring(id) end
PlayersService.GetPlayerByUserId = function(_, id)
	for _, p in ipairs(playersList) do
		if p.UserId == id then return p end
	end
	return nil
end

local savedData, presetData = {}, {}
local function deepcopy(t)
	if type(t) ~= "table" then return t end
	local c = {}
	for k, v in pairs(t) do c[k] = deepcopy(v) end
	return c
end
local orderedData = {} -- [storeName] = { [key] = value }
local DataStoreService = newMock("DataStoreService")
DataStoreService.GetOrderedDataStore = function(_, name)
	orderedData[name] = orderedData[name] or {}
	local data = orderedData[name]
	return {
		SetAsync = function(_, key, value) data[key] = value end,
		GetSortedAsync = function(_, ascending, size)
			local list = {}
			for k, v in pairs(data) do table.insert(list, { key = k, value = v }) end
			table.sort(list, function(a, b) if ascending then return a.value < b.value end return a.value > b.value end)
			while #list > size do table.remove(list) end
			return { GetCurrentPage = function() return list end }
		end,
	}
end
DataStoreService.GetDataStore = function()
	return {
		GetAsync = function(_, key) return deepcopy(presetData[key]) end,
		SetAsync = function(_, key, data) savedData[key] = deepcopy(data) end,
	}
end

local MarketplaceService = newMock("MarketplaceService")
local prompts = {}
MarketplaceService.PromptGamePassPurchase = function(_, p, id) table.insert(prompts, { "pass", p, id }) end
MarketplaceService.PromptProductPurchase = function(_, p, id) table.insert(prompts, { "product", p, id }) end
MarketplaceService.UserOwnsGamePassAsync = function() return false end
local fakePrices = {}
MarketplaceService.GetProductInfo = function(_, id) return { PriceInRobux = fakePrices[id] } end

local function encode(v)
	if type(v) ~= "table" then return tostring(v) end
	local keys = {}
	for k in pairs(v) do table.insert(keys, tostring(k)) end
	table.sort(keys)
	local parts = {}
	for _, k in ipairs(keys) do
		local value = v[k]
		if value == nil then value = v[tonumber(k)] end
		table.insert(parts, k .. "=" .. encode(value))
	end
	return "{" .. table.concat(parts, ",") .. "}"
end
local HttpService = newMock("HttpService")
HttpService.JSONEncode = function(_, v) return encode(v) end
local tagged = {}
local CollectionServiceFake = newMock("CollectionService")
CollectionServiceFake.AddTag = function(_, obj, tag)
	tagged[tag] = tagged[tag] or {}
	table.insert(tagged[tag], obj)
end
CollectionServiceFake.GetTagged = function(_, tag)
	local list = {}
	for _, obj in ipairs(tagged[tag] or {}) do
		if not rawget(obj, "__destroyed") then table.insert(list, obj) end
	end
	return list
end
local tweens = {}
local TweenServiceFake = newMock("TweenService")
TweenServiceFake.Create = function(_, target, info, props)
	table.insert(tweens, { target = target, props = props })
	local tw = newMock("Tween")
	tw.Play = function() end
	tw.Cancel = function() end
	return tw
end
local ReplicatedStorage = newMock("ReplicatedStorage")
ReplicatedStorage.Name = "ReplicatedStorage"
local services = {
	Players = PlayersService,
	DataStoreService = DataStoreService,
	MarketplaceService = MarketplaceService,
	ReplicatedStorage = ReplicatedStorage,
	HttpService = HttpService,
	TweenService = TweenServiceFake,
	CollectionService = CollectionServiceFake,
}
local game = newMock("game")
game.GetService = function(_, name)
	services[name] = services[name] or newMock(name)
	return services[name]
end
local workspace = newMock("workspace")
workspace.GetServerTimeNow = function() return fakeNow end
local fakeCamera = newMock("Camera")
fakeCamera.ViewportSize = { X = 844, Y = 390 } -- a phone in landscape
workspace.CurrentCamera = fakeCamera

local Random = {
	new = function()
		return {
			NextNumber = function(_, a, b)
				a, b = a or 0, b or 1
				return a + math.random() * (b - a)
			end,
			NextInteger = function(_, a, b) return math.random(a, b) end,
		}
	end,
}

local delayed = {}
local sleeping = {}
local task = {
	wait = function(t)
		local co = coroutine.running()
		table.insert(sleeping, { co = co, at = fakeClock + (t or 0.03) })
		return coroutine.yield()
	end,
	spawn = function(f, ...)
		local co = coroutine.create(f)
		local ok, err = coroutine.resume(co, ...)
		if not ok then error(err, 0) end
		return co
	end,
	delay = function(t, f, ...)
		table.insert(delayed, { at = fakeClock + t, f = f, args = { ... } })
	end,
}
task.defer = task.spawn
local function runSleeping()
	local due = {}
	for i = #sleeping, 1, -1 do
		if sleeping[i].at <= fakeClock then
			table.insert(due, table.remove(sleeping, i))
		end
	end
	for _, d in ipairs(due) do
		if coroutine.status(d.co) == "suspended" then
			local ok, err = coroutine.resume(d.co)
			if not ok then print("background task error: " .. tostring(err)) end
		end
	end
end
local function runDelayed()
	local due = {}
	for i = #delayed, 1, -1 do
		if delayed[i].at <= fakeClock then
			table.insert(due, table.remove(delayed, i))
		end
	end
	for _, d in ipairs(due) do
		task.spawn(d.f, table.unpack(d.args))
	end
end
local warn = print
