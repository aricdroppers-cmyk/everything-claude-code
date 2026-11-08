--[[
	DEEP SEA SALVAGE - Shared Config
	Type: ModuleScript
	Name it exactly: SalvageConfig
	Put it in: ReplicatedStorage

	Every number that controls the game's balance lives here, so you can
	tweak prices, drop rates and timers without touching the other scripts.
]]

local Config = {}

---------------------------------------------------------------------------
-- RARITIES (index 1 = most common, 5 = secret)
---------------------------------------------------------------------------
Config.Rarities = {
	{ name = "Driftwood", color = Color3.fromRGB(181, 140, 92), sellValue = 10, holdTime = 0.4 },
	{ name = "Brass", color = Color3.fromRGB(230, 182, 60), sellValue = 40, holdTime = 0.8 },
	{ name = "Pirate", color = Color3.fromRGB(225, 70, 70), sellValue = 150, holdTime = 1.2 },
	{ name = "Royal", color = Color3.fromRGB(165, 100, 255), sellValue = 600, holdTime = 1.8 },
	{ name = "Ghost", color = Color3.fromRGB(90, 255, 230), sellValue = 5000, holdTime = 2.5, secret = true },
}

---------------------------------------------------------------------------
-- SHIPS (the "skeletons" of this game). Find every fragment to restore one.
-- bonus = permanent extra coin multiplier once restored (0.05 = +5%)
---------------------------------------------------------------------------
Config.Ships = {
	{ id = "FishingSkiff", name = "Fishing Skiff", rarity = 1, bonus = 0.03,
		parts = { "Hull", "Mast", "Oars", "Net" } },
	{ id = "OldRaft", name = "Old Raft", rarity = 1, bonus = 0.03,
		parts = { "Logs", "Rope", "Patched Sail", "Paddle" } },
	{ id = "SteamTug", name = "Steam Tug", rarity = 2, bonus = 0.06,
		parts = { "Boiler", "Hull", "Smokestack", "Propeller", "Wheel" } },
	{ id = "DivingBell", name = "Diving Bell", rarity = 2, bonus = 0.06,
		parts = { "Bell", "Porthole", "Chain", "Air Valve" } },
	{ id = "BlackGull", name = "The Black Gull", rarity = 3, bonus = 0.12,
		parts = { "Hull", "Jolly Roger", "Cannon", "Mast", "Figurehead" } },
	{ id = "SeaSerpent", name = "Sea Serpent", rarity = 3, bonus = 0.12,
		parts = { "Hull", "Crow's Nest", "Treasure Map", "Cannon", "Serpent Prow" } },
	{ id = "CrownGalleon", name = "Crown Galleon", rarity = 4, bonus = 0.25,
		parts = { "Gilded Hull", "Crown Figurehead", "Golden Sail", "Treasury", "Main Mast", "Royal Anchor" } },
	{ id = "HollowTide", name = "The Hollow Tide", rarity = 5, bonus = 0.75,
		parts = { "Spectral Hull", "Cursed Bell", "Phantom Sail", "Captain's Lantern", "Soul Anchor" } },
}

---------------------------------------------------------------------------
-- DEPTH ZONES. Deeper = better loot + more coins, but a higher chance of a
-- hull breach that loses the whole haul. weights = { Driftwood, Brass, Pirate, Royal, Ghost }
---------------------------------------------------------------------------
Config.Zones = {
	{ name = "Sunlit Shallows", depthText = "0-50m", weights = { 85, 14, 1, 0, 0 },
		breach = 0.00, coins = 15, diveTime = 10, xp = 10 },
	{ name = "Kelp Reef", depthText = "50-200m", weights = { 60, 30, 9, 1, 0 },
		breach = 0.05, coins = 35, diveTime = 14, xp = 16 },
	{ name = "Twilight Drop", depthText = "200-1000m", weights = { 40, 38, 19, 2.95, 0.05 },
		breach = 0.10, coins = 80, diveTime = 18, xp = 26 },
	{ name = "Midnight Hollow", depthText = "1-4km", weights = { 22, 38, 32, 7.7, 0.3 },
		breach = 0.18, coins = 180, diveTime = 24, xp = 42 },
	{ name = "The Abyss", depthText = "4km+", weights = { 10, 32, 42, 15, 1 },
		breach = 0.28, coins = 400, diveTime = 30, xp = 70 },
}

---------------------------------------------------------------------------
-- SUBMARINES (the "jacks"). Better subs reach deeper zones, have more luck
-- (multiplies Pirate+ drop weights), a stronger hull (less breach chance)
-- and dive faster (speed multiplies dive time, lower = faster).
---------------------------------------------------------------------------
Config.Subs = {
	{ id = "Rowboat", name = "Rowboat Diver", price = 100, currency = "Coins",
		maxDepth = 1, luck = 1.0, hull = 0.00, speed = 1.0,
		bodyColor = Color3.fromRGB(140, 95, 55), trimColor = Color3.fromRGB(90, 60, 35), material = Enum.Material.Wood },
	{ id = "BrassBell", name = "Brass Bell", price = 400, currency = "Coins",
		maxDepth = 2, luck = 1.15, hull = 0.00, speed = 1.0,
		bodyColor = Color3.fromRGB(205, 160, 60), trimColor = Color3.fromRGB(120, 85, 30), material = Enum.Material.Metal },
	{ id = "IronMinnow", name = "Iron Minnow", price = 2500, currency = "Coins",
		maxDepth = 3, luck = 1.35, hull = 0.02, speed = 0.9,
		bodyColor = Color3.fromRGB(95, 105, 115), trimColor = Color3.fromRGB(55, 60, 70), material = Enum.Material.DiamondPlate },
	{ id = "Bathysphere", name = "Bathysphere", price = 12000, currency = "Coins",
		maxDepth = 4, luck = 1.6, hull = 0.04, speed = 0.85,
		bodyColor = Color3.fromRGB(235, 235, 240), trimColor = Color3.fromRGB(255, 120, 30), material = Enum.Material.SmoothPlastic },
	{ id = "AbyssCrawler", name = "Abyss Crawler", price = 60000, currency = "Coins",
		maxDepth = 5, luck = 2.0, hull = 0.07, speed = 0.8,
		bodyColor = Color3.fromRGB(25, 25, 30), trimColor = Color3.fromRGB(255, 40, 60), material = Enum.Material.Metal },
	{ id = "Leviathan", name = "Leviathan", price = 40, currency = "Pearls",
		maxDepth = 5, luck = 2.8, hull = 0.12, speed = 0.65,
		bodyColor = Color3.fromRGB(10, 70, 80), trimColor = Color3.fromRGB(60, 255, 230), material = Enum.Material.Glass },
}

Config.MaxFleet = 5 -- subs per player
Config.StartingSub = "Rowboat" -- everyone gets one free

---------------------------------------------------------------------------
-- LUCK PROTECTION
---------------------------------------------------------------------------
Config.MissingPartBias = 0.35 -- chance a roll is redirected to a fragment you don't own yet
Config.PityLimit = 150 -- hauls without Royal+ before one is guaranteed (in zones that can drop Royal)
Config.RepairTime = 6 -- seconds a sub spends repairing after a breach

---------------------------------------------------------------------------
-- EVENTS
---------------------------------------------------------------------------
Config.EventInterval = 240 -- seconds between events
Config.EventDuration = 90 -- seconds each event lasts
Config.Events = {
	StormSurge = { name = "STORM SURGE", desc = "Double fragments per haul, but +8% breach risk!" },
	TreasureTide = { name = "TREASURE TIDE", desc = "Golden chests are floating around the island. Grab them!" },
	Kraken = { name = "KRAKEN ATTACK", desc = "Tentacles surround the island! Click them to drive it off!" },
}
Config.StormExtraBreach = 0.08
Config.TreasureChests = 12
Config.TreasureChestPearls = 2
Config.TreasureChestCoins = 150
Config.KrakenBaseHP = 80
Config.KrakenHPPerPlayer = 50
Config.KrakenPearls = 6

---------------------------------------------------------------------------
-- LEVELS
-- Every haul gives XP: the zone's xp + a bonus for the fragment's rarity
-- (+ NewFragmentXP if you didn't own it yet).
---------------------------------------------------------------------------
Config.MaxLevel = 100
Config.FragmentXP = { 0, 4, 12, 30, 150 } -- bonus XP by fragment rarity
Config.NewFragmentXP = 10
Config.TradeUnlockLevel = 10

function Config.XPToNext(level)
	return math.floor(60 * level ^ 1.45)
end

---------------------------------------------------------------------------
-- EGGS. Every successful haul has EggChance to also bring up the egg of the
-- zone it was in. Hatching costs coins (Kraken Eggs cost Pearls).
---------------------------------------------------------------------------
Config.EggChance = 0.05
Config.Eggs = {
	{ id = "TidePool", name = "Tide Pool Egg", zone = 1, cost = 250, currency = "Coins",
		color = Color3.fromRGB(255, 225, 170), spots = Color3.fromRGB(255, 150, 120) },
	{ id = "Kelp", name = "Kelp Egg", zone = 2, cost = 1500, currency = "Coins",
		color = Color3.fromRGB(120, 200, 110), spots = Color3.fromRGB(40, 120, 60) },
	{ id = "Twilight", name = "Twilight Egg", zone = 3, cost = 8000, currency = "Coins",
		color = Color3.fromRGB(90, 120, 220), spots = Color3.fromRGB(180, 220, 255) },
	{ id = "Midnight", name = "Midnight Egg", zone = 4, cost = 40000, currency = "Coins",
		color = Color3.fromRGB(45, 35, 80), spots = Color3.fromRGB(150, 90, 255) },
	{ id = "Abyss", name = "Abyss Egg", zone = 5, cost = 150000, currency = "Coins",
		color = Color3.fromRGB(20, 20, 25), spots = Color3.fromRGB(255, 50, 70) },
	{ id = "Kraken", name = "Kraken Egg", zone = nil, cost = 5, currency = "Pearls",
		color = Color3.fromRGB(130, 50, 150), spots = Color3.fromRGB(255, 150, 190) },
}
Config.KrakenEggMinHits = 10 -- hits needed in a won Kraken fight to get a Kraken Egg

---------------------------------------------------------------------------
-- PETS. weight = chance inside its egg. bonus types:
--   coins = +% coins, luck = multiplies sub luck by (1 + luck),
--   hull = lowers breach chance, xp = +% XP
-- shape decides how the pet is built: fish, crab, star, turtle, jelly,
-- octopus, ray, eel. Optional: glow, stripes, round (puffer), lure, fin.
---------------------------------------------------------------------------
Config.MaxPets = 40
Config.MaxEquipped = 3
Config.PetRarities = {
	{ name = "Common", color = Color3.fromRGB(200, 205, 212), releaseValue = 25 },
	{ name = "Uncommon", color = Color3.fromRGB(100, 225, 120), releaseValue = 120 },
	{ name = "Rare", color = Color3.fromRGB(80, 165, 255), releaseValue = 600 },
	{ name = "Epic", color = Color3.fromRGB(185, 105, 255), releaseValue = 3000 },
	{ name = "Legendary", color = Color3.fromRGB(255, 195, 50), releaseValue = 12000 },
}

local function rgb(r, g, b)
	return Color3.fromRGB(r, g, b)
end

Config.Pets = {
	-- Tide Pool Egg
	{ id = "Clownfish", name = "Clownfish", egg = "TidePool", rarity = 1, weight = 60, shape = "fish",
		color = rgb(255, 130, 40), accent = rgb(255, 255, 255), stripes = true, bonus = { coins = 0.03 } },
	{ id = "HermitCrab", name = "Hermit Crab", egg = "TidePool", rarity = 1, weight = 30, shape = "crab",
		color = rgb(225, 85, 60), accent = rgb(240, 220, 180), bonus = { hull = 0.005 } },
	{ id = "Starfish", name = "Starfish", egg = "TidePool", rarity = 2, weight = 9, shape = "star",
		color = rgb(255, 165, 90), accent = rgb(255, 220, 170), bonus = { xp = 0.08 } },
	{ id = "GoldenGoby", name = "Golden Goby", egg = "TidePool", rarity = 4, weight = 1, shape = "fish",
		color = rgb(255, 200, 50), accent = rgb(255, 245, 190), glow = true, bonus = { coins = 0.15 } },
	-- Kelp Egg
	{ id = "Pufferfish", name = "Pufferfish", egg = "Kelp", rarity = 1, weight = 55, shape = "fish",
		color = rgb(235, 215, 120), accent = rgb(120, 90, 50), round = true, bonus = { coins = 0.05 } },
	{ id = "SeaTurtle", name = "Sea Turtle", egg = "Kelp", rarity = 2, weight = 33, shape = "turtle",
		color = rgb(70, 140, 80), accent = rgb(160, 200, 120), bonus = { hull = 0.01 } },
	{ id = "KelpEel", name = "Kelp Eel", egg = "Kelp", rarity = 3, weight = 10, shape = "eel",
		color = rgb(80, 150, 60), accent = rgb(200, 240, 120), bonus = { luck = 0.08 } },
	{ id = "KelpDragon", name = "Kelp Dragon", egg = "Kelp", rarity = 4, weight = 2, shape = "eel",
		color = rgb(40, 170, 90), accent = rgb(255, 220, 80), glow = true, bonus = { luck = 0.15, coins = 0.1 } },
	-- Twilight Egg
	{ id = "Jellyfish", name = "Jellyfish", egg = "Twilight", rarity = 1, weight = 50, shape = "jelly",
		color = rgb(255, 150, 210), accent = rgb(255, 210, 240), bonus = { xp = 0.1 } },
	{ id = "Lanternfish", name = "Lanternfish", egg = "Twilight", rarity = 2, weight = 35, shape = "fish",
		color = rgb(60, 80, 140), accent = rgb(120, 255, 230), glow = true, bonus = { luck = 0.06 } },
	{ id = "Octopus", name = "Octopus", egg = "Twilight", rarity = 3, weight = 13, shape = "octopus",
		color = rgb(230, 100, 70), accent = rgb(255, 190, 160), bonus = { coins = 0.12 } },
	{ id = "MoonJelly", name = "Moon Jelly", egg = "Twilight", rarity = 5, weight = 2, shape = "jelly",
		color = rgb(200, 230, 255), accent = rgb(140, 200, 255), glow = true, bonus = { luck = 0.25, xp = 0.2 } },
	-- Midnight Egg
	{ id = "Anglerfish", name = "Anglerfish", egg = "Midnight", rarity = 2, weight = 50, shape = "fish",
		color = rgb(50, 45, 60), accent = rgb(255, 240, 140), lure = true, bonus = { coins = 0.15 } },
	{ id = "VampireSquid", name = "Vampire Squid", egg = "Midnight", rarity = 3, weight = 35, shape = "octopus",
		color = rgb(110, 20, 35), accent = rgb(80, 160, 255), glow = true, bonus = { hull = 0.02 } },
	{ id = "AbyssalRay", name = "Abyssal Ray", egg = "Midnight", rarity = 4, weight = 13, shape = "ray",
		color = rgb(40, 40, 80), accent = rgb(150, 110, 255), glow = true, bonus = { luck = 0.2 } },
	{ id = "GulperEel", name = "Gulper Eel", egg = "Midnight", rarity = 5, weight = 2, shape = "eel",
		color = rgb(25, 25, 35), accent = rgb(255, 80, 120), glow = true, bonus = { coins = 0.4 } },
	-- Abyss Egg
	{ id = "GiantIsopod", name = "Giant Isopod", egg = "Abyss", rarity = 3, weight = 55, shape = "crab",
		color = rgb(170, 160, 175), accent = rgb(120, 110, 130), bonus = { hull = 0.03 } },
	{ id = "GhostShark", name = "Ghost Shark", egg = "Abyss", rarity = 4, weight = 35, shape = "fish",
		color = rgb(200, 230, 240), accent = rgb(90, 255, 230), fin = true, glow = true, bonus = { luck = 0.3 } },
	{ id = "AbyssWarden", name = "Abyss Warden", egg = "Abyss", rarity = 5, weight = 9, shape = "octopus",
		color = rgb(20, 20, 30), accent = rgb(255, 40, 60), glow = true, bonus = { coins = 0.6, luck = 0.2 } },
	{ id = "LeviathanPup", name = "Leviathan Pup", egg = "Abyss", rarity = 5, weight = 1, shape = "eel",
		color = rgb(10, 80, 90), accent = rgb(60, 255, 230), glow = true, bonus = { coins = 1.0, luck = 0.4 } },
	-- Kraken Egg (event only)
	{ id = "KrakenSpawn", name = "Kraken Spawn", egg = "Kraken", rarity = 3, weight = 70, shape = "octopus",
		color = rgb(130, 50, 150), accent = rgb(255, 150, 190), bonus = { luck = 0.1, coins = 0.1 } },
	{ id = "StormEel", name = "Storm Eel", egg = "Kraken", rarity = 4, weight = 27, shape = "eel",
		color = rgb(60, 70, 110), accent = rgb(255, 240, 80), glow = true, bonus = { luck = 0.2, xp = 0.15 } },
	{ id = "PearlDragon", name = "Pearl Dragon", egg = "Kraken", rarity = 5, weight = 3, shape = "eel",
		color = rgb(245, 240, 255), accent = rgb(255, 180, 230), glow = true, bonus = { coins = 0.5, luck = 0.3, xp = 0.3 } },
}

---------------------------------------------------------------------------
-- HELPERS (used by both server and client)
---------------------------------------------------------------------------
function Config.GetEgg(id)
	for _, egg in ipairs(Config.Eggs) do
		if egg.id == id then
			return egg
		end
	end
	return nil
end

function Config.EggForZone(zoneIndex)
	for _, egg in ipairs(Config.Eggs) do
		if egg.zone == zoneIndex then
			return egg
		end
	end
	return nil
end

function Config.GetPet(id)
	for _, pet in ipairs(Config.Pets) do
		if pet.id == id then
			return pet
		end
	end
	return nil
end

function Config.PetsInEgg(eggId)
	local list = {}
	for _, pet in ipairs(Config.Pets) do
		if pet.egg == eggId then
			table.insert(list, pet)
		end
	end
	return list
end

-- Sum the bonuses of a list of pet ids
function Config.PetBonusTotals(petIds)
	local totals = { coins = 0, luck = 0, hull = 0, xp = 0 }
	for _, petId in ipairs(petIds) do
		local pet = Config.GetPet(petId)
		if pet then
			for stat, value in pairs(pet.bonus) do
				totals[stat] += value
			end
		end
	end
	return totals
end

-- One number used to rank pets for "Equip Best"
function Config.PetScore(petId)
	local pet = Config.GetPet(petId)
	if not pet then
		return 0
	end
	local b = pet.bonus
	return (b.coins or 0) + (b.luck or 0) + (b.xp or 0) * 0.5 + (b.hull or 0) * 6
end

function Config.DescribeBonus(bonus)
	local parts = {}
	if bonus.coins then
		table.insert(parts, "+" .. math.floor(bonus.coins * 100 + 0.5) .. "% coins")
	end
	if bonus.luck then
		table.insert(parts, "+" .. math.floor(bonus.luck * 100 + 0.5) .. "% luck")
	end
	if bonus.hull then
		table.insert(parts, "-" .. string.format("%.1f", bonus.hull * 100) .. "% breach")
	end
	if bonus.xp then
		table.insert(parts, "+" .. math.floor(bonus.xp * 100 + 0.5) .. "% XP")
	end
	return table.concat(parts, "  ")
end

function Config.IsValidPartKey(key)
	if typeof(key) ~= "string" then
		return false
	end
	for _, ship in ipairs(Config.Ships) do
		for _, partName in ipairs(ship.parts) do
			if Config.PartKey(ship.id, partName) == key then
				return true, ship
			end
		end
	end
	return false
end

function Config.SplitPartKey(key)
	local shipId, partName = string.match(key, "^([^/]+)/(.+)$")
	return shipId, partName
end
function Config.GetSub(id)
	for index, sub in ipairs(Config.Subs) do
		if sub.id == id then
			return sub, index
		end
	end
	return nil
end

function Config.GetShip(id)
	for _, ship in ipairs(Config.Ships) do
		if ship.id == id then
			return ship
		end
	end
	return nil
end

function Config.PartKey(shipId, partName)
	return shipId .. "/" .. partName
end

function Config.ShipsOfRarity(rarity)
	local list = {}
	for _, ship in ipairs(Config.Ships) do
		if ship.rarity == rarity then
			table.insert(list, ship)
		end
	end
	return list
end

-- Breach chance for a given sub at a given depth (before events)
function Config.BreachChance(subDef, depth)
	return math.max(0, Config.Zones[depth].breach - subDef.hull)
end

function Config.FormatNumber(n)
	n = math.floor(n)
	if n >= 1e9 then
		return string.format("%.2fB", n / 1e9)
	elseif n >= 1e6 then
		return string.format("%.2fM", n / 1e6)
	elseif n >= 1e4 then
		return string.format("%.1fK", n / 1e3)
	end
	local s = tostring(n)
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return formatted
end

return Config
