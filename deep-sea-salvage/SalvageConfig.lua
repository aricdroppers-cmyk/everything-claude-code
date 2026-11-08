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
	{ name = "Mythic", color = Color3.fromRGB(255, 90, 220), releaseValue = 50000 }, -- Mystic season pass only
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
-- SEASON PETS (only from the season pass). Each one has 3 versions: the
-- normal one, a "Radiant" one after your 1st season prestige and a
-- "Celestial" one after your 2nd. Mythic (rarity 6) pets are Mystic-pass only.
---------------------------------------------------------------------------
Config.SeasonPetBases = {
	{ id = "CoralSprite", name = "Coral Sprite", rarity = 3, shape = "star",
		color = rgb(255, 120, 150), accent = rgb(255, 230, 240), bonus = { coins = 0.15, xp = 0.1 } },
	{ id = "CrownedTurtle", name = "Crowned Turtle", rarity = 4, shape = "turtle",
		color = rgb(60, 130, 140), accent = rgb(255, 205, 70), bonus = { coins = 0.3, hull = 0.02 } },
	{ id = "TideWyrm", name = "Tide Wyrm", rarity = 4, shape = "eel",
		color = rgb(40, 110, 200), accent = rgb(160, 240, 255), glow = true, bonus = { luck = 0.25, xp = 0.1 } },
	{ id = "SovereignRay", name = "Sovereign Ray", rarity = 5, shape = "ray",
		color = rgb(30, 30, 60), accent = rgb(255, 205, 70), glow = true, bonus = { coins = 0.6, luck = 0.3 } },
	{ id = "MysticMinnow", name = "Mystic Minnow", rarity = 5, shape = "fish",
		color = rgb(150, 80, 230), accent = rgb(255, 140, 255), glow = true, bonus = { coins = 0.5, luck = 0.2 } },
	{ id = "MysticJelly", name = "Mystic Jelly", rarity = 6, shape = "jelly",
		color = rgb(200, 120, 255), accent = rgb(120, 255, 240), glow = true, bonus = { luck = 0.6, xp = 0.4 } },
	{ id = "AstralOctopus", name = "Astral Octopus", rarity = 6, shape = "octopus",
		color = rgb(40, 20, 90), accent = rgb(255, 120, 230), glow = true, bonus = { coins = 1.2, luck = 0.4 } },
	{ id = "MysticLeviathan", name = "Mystic Leviathan", rarity = 6, shape = "eel",
		color = rgb(90, 30, 160), accent = rgb(90, 255, 230), glow = true, bonus = { coins = 2.0, luck = 0.8, xp = 0.5 } },
}
Config.SeasonPetVariants = {
	{ prefix = "", idPrefix = "", bonusMult = 1 },
	{ prefix = "Radiant ", idPrefix = "Radiant", bonusMult = 1.5, accent = rgb(255, 215, 90) },
	{ prefix = "Celestial ", idPrefix = "Celestial", bonusMult = 2.25, accent = rgb(150, 240, 255), lighten = 0.35 },
}
for _, base in ipairs(Config.SeasonPetBases) do
	for _, variant in ipairs(Config.SeasonPetVariants) do
		local bonus = {}
		for stat, value in pairs(base.bonus) do
			bonus[stat] = value * variant.bonusMult
		end
		table.insert(Config.Pets, {
			id = variant.idPrefix .. base.id,
			name = variant.prefix .. base.name,
			egg = nil, -- season only
			season = true,
			rarity = base.rarity,
			weight = 0,
			shape = base.shape,
			color = variant.lighten and base.color:Lerp(Color3.new(1, 1, 1), variant.lighten) or base.color,
			accent = variant.accent or base.accent,
			glow = base.glow or variant.prefix ~= "",
			bonus = bonus,
		})
	end
end

-- ids of one season pet in all 3 versions, e.g. SeasonPet("CoralSprite")
function Config.SeasonPet(baseId)
	local ids = {}
	for _, variant in ipairs(Config.SeasonPetVariants) do
		table.insert(ids, variant.idPrefix .. baseId)
	end
	return ids
end

---------------------------------------------------------------------------
-- WEAPONS. Bought in the Shop (WEAPONS tab). The equipped one is your tool.
---------------------------------------------------------------------------
Config.Weapons = {
	{ id = "DriftwoodSpear", name = "Driftwood Spear", style = "spear", damage = 6, range = 11, cooldown = 0.45,
		price = 0, currency = "Coins", color = rgb(150, 110, 70), tip = rgb(210, 210, 215) },
	{ id = "BrassHarpoon", name = "Brass Harpoon", style = "harpoon", damage = 15, range = 12, cooldown = 0.45,
		price = 1500, currency = "Coins", color = rgb(205, 160, 60), tip = rgb(240, 240, 245) },
	{ id = "CoralTrident", name = "Coral Trident", style = "trident", damage = 40, range = 12, cooldown = 0.45,
		price = 15000, currency = "Coins", color = rgb(255, 120, 140), tip = rgb(255, 210, 220) },
	{ id = "AbyssalCutlass", name = "Abyssal Cutlass", style = "blade", damage = 110, range = 10, cooldown = 0.35,
		price = 120000, currency = "Coins", color = rgb(40, 40, 50), tip = rgb(255, 60, 80) },
	{ id = "StormLance", name = "Storm Lance", style = "spear", damage = 280, range = 15, cooldown = 0.45,
		price = 600000, currency = "Coins", color = rgb(70, 80, 120), tip = rgb(255, 240, 90), glow = true },
	{ id = "LeviathanFang", name = "Leviathan Fang", style = "blade", damage = 600, range = 13, cooldown = 0.4,
		price = 120, currency = "Pearls", color = rgb(10, 80, 90), tip = rgb(60, 255, 230), glow = true },
	-- season pass only
	{ id = "TidebreakerTrident", name = "Tidebreaker Trident", style = "trident", damage = 900, range = 14, cooldown = 0.4,
		seasonOnly = true, color = rgb(30, 90, 170), tip = rgb(160, 240, 255), glow = true },
	{ id = "MysticTrident", name = "Mystic Trident", style = "trident", damage = 1800, range = 16, cooldown = 0.35,
		seasonOnly = true, color = rgb(120, 60, 200), tip = rgb(255, 120, 255), glow = true },
}
Config.StartingWeapon = "DriftwoodSpear"

function Config.GetWeapon(id)
	for index, weapon in ipairs(Config.Weapons) do
		if weapon.id == id then
			return weapon, index
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- ENEMIES. Built from the same shapes as pets, just bigger and angrier.
-- height = how high above the floor they swim (0 = walks on the floor)
---------------------------------------------------------------------------
Config.Enemies = {
	{ id = "SnappyCrab", name = "Snappy Crab", shape = "crab", scale = 2.2, height = 0,
		color = rgb(230, 80, 55), accent = rgb(255, 210, 170),
		hp = 40, damage = 5, reach = 5, speed = 9, coins = 8, xp = 6, seasonXp = 2 },
	{ id = "StingJelly", name = "Sting Jelly", shape = "jelly", scale = 2.2, height = 4,
		color = rgb(255, 140, 200), accent = rgb(255, 220, 240),
		hp = 30, damage = 6, reach = 5, speed = 6, coins = 10, xp = 8, seasonXp = 2 },
	{ id = "MorayEel", name = "Moray Eel", shape = "eel", scale = 2.8, height = 3,
		color = rgb(90, 130, 50), accent = rgb(220, 230, 90),
		hp = 180, damage = 12, reach = 6, speed = 15, coins = 45, xp = 20, seasonXp = 4 },
	{ id = "PufferBrute", name = "Puffer Brute", shape = "fish", round = true, scale = 3.2, height = 3,
		color = rgb(235, 210, 110), accent = rgb(130, 90, 40),
		hp = 300, damage = 16, reach = 7, speed = 7, coins = 70, xp = 30, seasonXp = 5 },
	{ id = "Barracuda", name = "Barracuda", shape = "fish", fin = true, scale = 3.2, height = 4,
		color = rgb(150, 170, 190), accent = rgb(60, 70, 90),
		hp = 700, damage = 22, reach = 7, speed = 19, coins = 160, xp = 60, seasonXp = 8 },
	{ id = "GiantSquid", name = "Giant Squid", shape = "octopus", scale = 4, height = 4,
		color = rgb(200, 60, 70), accent = rgb(255, 170, 160),
		hp = 1100, damage = 28, reach = 9, speed = 9, coins = 250, xp = 90, seasonXp = 10 },
	{ id = "GreatShark", name = "Great Shark", shape = "fish", fin = true, scale = 6, height = 5,
		color = rgb(110, 125, 140), accent = rgb(230, 235, 240),
		hp = 3000, damage = 40, reach = 11, speed = 21, coins = 600, xp = 180, seasonXp = 15 },
	{ id = "AnglerHorror", name = "Angler Horror", shape = "fish", lure = true, round = true, scale = 5, height = 5,
		color = rgb(45, 40, 55), accent = rgb(255, 240, 140), glow = true,
		hp = 3800, damage = 46, reach = 10, speed = 11, coins = 800, xp = 240, seasonXp = 18 },
	{ id = "AbyssalHorror", name = "Abyssal Horror", shape = "octopus", scale = 6, height = 5,
		color = rgb(20, 18, 28), accent = rgb(255, 40, 70), glow = true,
		hp = 9000, damage = 70, reach = 12, speed = 12, coins = 2000, xp = 600, seasonXp = 30 },
	{ id = "Leviathan", name = "THE LEVIATHAN", shape = "eel", scale = 14, height = 12, boss = true,
		color = rgb(15, 60, 70), accent = rgb(60, 255, 230), glow = true,
		hp = 150000, hpPerPlayer = 60000, damage = 120, reach = 26, speed = 14, attackCooldown = 2.5,
		coins = 50000, xp = 5000, seasonXp = 300, pearls = 20, eggChance = 0.5 },
}
Config.EnemyAttackCooldown = 1.8
Config.EnemyAggroRange = 40
Config.EnemyFragmentChance = 0.08 -- chance a kill drops a fragment (zone drop rates)
Config.EnemyEggChance = 0.015 -- chance a kill drops the zone's egg
Config.BossInterval = 300 -- seconds between Leviathan spawns
Config.PlayerBaseHealth = 100
Config.HealthPerLevel = 20

function Config.GetEnemy(id)
	for _, enemy in ipairs(Config.Enemies) do
		if enemy.id == id then
			return enemy
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- HUNTING GROUNDS (one per zone, reached through portals on the island)
---------------------------------------------------------------------------
Config.Arenas = {
	{ id = "Shallows", zone = 1, level = 1, maxEnemies = 7, enemies = { "SnappyCrab", "StingJelly" },
		floor = rgb(225, 205, 150), floorMaterial = Enum.Material.Sand, rock = rgb(170, 150, 120),
		water = rgb(90, 190, 210), fog = 0.35 },
	{ id = "Kelp", zone = 2, level = 5, maxEnemies = 6, enemies = { "MorayEel", "PufferBrute" },
		floor = rgb(90, 120, 70), floorMaterial = Enum.Material.Grass, rock = rgb(80, 95, 70),
		water = rgb(50, 140, 110), fog = 0.45 },
	{ id = "Twilight", zone = 3, level = 12, maxEnemies = 6, enemies = { "Barracuda", "GiantSquid" },
		floor = rgb(60, 70, 110), floorMaterial = Enum.Material.Slate, rock = rgb(50, 55, 85),
		water = rgb(40, 70, 150), fog = 0.55 },
	{ id = "Midnight", zone = 4, level = 20, maxEnemies = 5, enemies = { "GreatShark", "AnglerHorror" },
		floor = rgb(30, 30, 50), floorMaterial = Enum.Material.Basalt, rock = rgb(25, 25, 40),
		water = rgb(20, 25, 70), fog = 0.65 },
	{ id = "Abyss", zone = 5, level = 30, maxEnemies = 5, enemies = { "AbyssalHorror" }, boss = "Leviathan",
		floor = rgb(15, 12, 20), floorMaterial = Enum.Material.Basalt, rock = rgb(20, 15, 25),
		water = rgb(10, 10, 30), fog = 0.75 },
}

Config.ArenaSize = 180

-- Where hunting ground number i is (far away from the island, out of the water)
function Config.ArenaCenter(index)
	return Vector3.new(1100, 0, (index - 3) * 260)
end

---------------------------------------------------------------------------
-- REBIRTH. Resets level, coins, subs and weapons for permanent bonuses.
-- You KEEP: restored ships, fragments, pets, eggs, pearls, season progress,
-- game passes and boosts.
---------------------------------------------------------------------------
Config.Rebirth = {
	max = 15,
	-- Requirement for rebirth number (r + 1): Level levelBase + levelPer * r,
	-- coins coinsBase * coinsGrowth ^ r. Simulated (hauling only, perfect play):
	-- 1st ~20 min, 2nd ~26 min, 3rd ~38 min, 4th ~52 min, 5th ~78 min, ...
	levelBase = 7,
	levelPer = 3,
	coinsBase = 13000,
	coinsGrowth = 2.3,
	-- Bonus from rebirth number n = first + grow * (n - 1), so every rebirth
	-- gives a bit more than the one before it.
	bonus = {
		coins = { first = 0.25, grow = 0.05 },
		xp = { first = 0.15, grow = 0.03 },
		luck = { first = 0.03, grow = 0.01 },
		damage = { first = 0.10, grow = 0.03 },
		health = { first = 50, grow = 15 },
	},
	pearlsFirst = 5, -- pearls handed out on rebirth number n: first + per * (n - 1)
	pearlsPer = 5,
}

function Config.RebirthRequirement(rebirths)
	local r = Config.Rebirth
	-- rounded to a tidy number (13,000 x 2.3 is 29,899.999... in floating point)
	local coins = r.coinsBase * r.coinsGrowth ^ rebirths
	local step = coins >= 1e6 and 10000 or (coins >= 1e5 and 1000 or 100)
	return r.levelBase + r.levelPer * rebirths, math.floor(coins / step + 0.5) * step
end

-- What rebirth number n gives on its own
function Config.RebirthBonusFor(n)
	local out = {}
	for stat, b in pairs(Config.Rebirth.bonus) do
		out[stat] = b.first + b.grow * (n - 1)
	end
	out.pearls = Config.Rebirth.pearlsFirst + Config.Rebirth.pearlsPer * (n - 1)
	return out
end

-- Everything you have after r rebirths
function Config.RebirthTotals(r)
	local totals = { coins = 0, xp = 0, luck = 0, damage = 0, health = 0 }
	for n = 1, r do
		local b = Config.RebirthBonusFor(n)
		for stat in pairs(totals) do
			totals[stat] += b[stat]
		end
	end
	return totals
end

---------------------------------------------------------------------------
-- QUESTS. Daily quests reset at midnight UTC, weekly ones every Monday.
-- Reward coins are multiplied by your level when you finish the quest.
-- levels = XP worth that many of your current levels (helps toward rebirth).
---------------------------------------------------------------------------
Config.DailyQuestCount = 3
Config.DailyQuests = {
	{ id = "Haul", text = "Haul up %d crates", stat = "hauls", target = 40, reward = { coins = 150, pearls = 2, seasonXp = 400, levels = 0.5 } },
	{ id = "Defeat", text = "Defeat %d sea creatures", stat = "kills", target = 25, reward = { coins = 200, pearls = 2, seasonXp = 400, levels = 0.5 } },
	{ id = "NewFrag", text = "Find %d fragments you didn't have", stat = "newFragments", target = 3, reward = { coins = 200, pearls = 3, seasonXp = 450, levels = 0.5 } },
	{ id = "Hatch", text = "Hatch %d eggs", stat = "hatches", target = 2, reward = { coins = 150, pearls = 2, seasonXp = 350, levels = 0.5 } },
	{ id = "Hunter", text = "Defeat %d creatures in Kelp Reef or deeper", stat = "deepKills", target = 15, reward = { coins = 250, pearls = 3, seasonXp = 450, levels = 0.5 } },
	{ id = "Drifters", text = "Open %d Tide Bottles floating in the sea", stat = "drifters", target = 3, reward = { coins = 200, pearls = 3, seasonXp = 400, levels = 0.5 } },
	{ id = "DeepDive", text = "Finish %d dives in Twilight Drop or deeper", stat = "deepDives", target = 15, reward = { coins = 250, pearls = 3, seasonXp = 450, levels = 0.5 } },
	{ id = "Chests", text = "Open %d treasure chests", stat = "chests", target = 2, reward = { coins = 150, pearls = 3, seasonXp = 350, levels = 0.5 } },
	{ id = "Kraken", text = "Hit the Kraken %d times", stat = "krakenHits", target = 30, reward = { coins = 200, pearls = 3, seasonXp = 400, levels = 0.5 } },
	{ id = "Fragments", text = "Collect %d fragments", stat = "fragments", target = 50, reward = { coins = 150, pearls = 2, seasonXp = 350, levels = 0.5 } },
}
Config.WeeklyQuestCount = 2
Config.WeeklyQuests = {
	{ id = "WeeklyHaul", text = "Haul up %d crates", stat = "hauls", target = 500, reward = { coins = 2000, pearls = 15, seasonXp = 2500, levels = 2 } },
	{ id = "WeeklyDefeat", text = "Defeat %d sea creatures", stat = "kills", target = 300, reward = { coins = 2500, pearls = 15, seasonXp = 2500, levels = 2 } },
	{ id = "WeeklyHatch", text = "Hatch %d eggs", stat = "hatches", target = 15, reward = { coins = 2000, pearls = 12, seasonXp = 2000, levels = 2 } },
	{ id = "WeeklyDeep", text = "Finish %d dives in Twilight Drop or deeper", stat = "deepDives", target = 150, reward = { coins = 2500, pearls = 15, seasonXp = 2500, levels = 2 } },
	{ id = "WeeklyRebirth", text = "Rebirth %d times", stat = "rebirths", target = 2, reward = { coins = 3000, pearls = 20, seasonXp = 3000, levels = 2 } },
}

---------------------------------------------------------------------------
-- ROBUX: GAME PASSES (permanent) and DEVELOPER PRODUCTS (boosts, season passes)
-- Create these in the Creator Dashboard and paste their ids here.
-- While an id is 0, buying it in Studio just gives it to you for free so you
-- can test (it never works like that in a live game).
---------------------------------------------------------------------------
Config.GamePasses = {
	{ key = "DoubleCoins", name = "2x Coins", desc = "Double coins from everything, forever.", price = 149, id = 0 },
	{ key = "LuckyDiver", name = "Lucky Diver", desc = "+50% luck on every dive and every kill.", price = 199, id = 0 },
	{ key = "AutoHaul", name = "Auto Haul", desc = "Crates haul themselves up. No walking back to your bay!", price = 199, id = 0 },
	{ key = "PetSlots", name = "+2 Pet Slots", desc = "Equip 5 pets instead of 3.", price = 149, id = 0 },
	{ key = "VIP", name = "VIP Diver", desc = "+20% XP, +10% coins and a gold VIP tag.", price = 249, id = 0 },
}
Config.Products = {
	{ key = "BoostCoins", name = "2x Coins (30 min)", desc = "Double coins for 30 minutes.", price = 29, id = 0, boost = "coins", minutes = 30 },
	{ key = "BoostLuck", name = "2x Luck (30 min)", desc = "Double luck for 30 minutes.", price = 39, id = 0, boost = "luck", minutes = 30 },
	{ key = "BoostXP", name = "2x XP (30 min)", desc = "Double XP for 30 minutes.", price = 25, id = 0, boost = "xp", minutes = 30 },
	{ key = "RebirthRush", name = "Rebirth Rush (30 min)", desc = "2x Coins AND 2x XP for 30 minutes. Rebirth way faster.", price = 49, id = 0, boost = { "coins", "xp" }, minutes = 30 },
	{ key = "LevelPack", name = "+3 Levels", desc = "Instantly gain 3 levels.", price = 49, id = 0, levels = 3 },
	{ key = "InstantRebirth", name = "Instant Rebirth", desc = "Rebirth right now, no level or coin requirement. You still get all the rebirth rewards.", price = 99, id = 0, rebirth = true },
	{ key = "SeasonPremium", name = "Premium Season Pass", desc = "Unlocks the Premium reward track this season. +10% season XP.", price = 400, id = 0, seasonPass = "premium" },
	{ key = "SeasonMystic", name = "Mystic Season Pass", desc = "Everything in Premium PLUS the Mystic track: 3 Mythic pets, the Mystic Trident (best weapon), the biggest rewards and +25% season XP.", price = 800, id = 0, seasonPass = "mystic",
		-- Launch sale. The price players pay is the one you set in the Creator Dashboard
		-- (set it to 800). After saleEnds the "20% OFF" label hides itself, so set the
		-- dashboard price back to originalPrice then. saleEnds is a UTC time
		-- (os.time) - this one is 2026-12-31 23:59 UTC.
		originalPrice = 1000, saleLabel = "20% OFF", saleEnds = 1798761540 },
}
Config.BoostMultiplier = 2

-- Is a product's sale running right now?
function Config.SaleActive(product, now)
	return product.originalPrice ~= nil and (product.saleEnds == nil or (now or os.time()) < product.saleEnds)
end

---------------------------------------------------------------------------
-- DAILY LOGIN STREAK. Log in every day to grow your streak. Miss a day and
-- it goes back to day 1. Every full week multiplies the rewards (x1.25 per
-- week, up to x2). coins with perLevel = true are multiplied by your level.
---------------------------------------------------------------------------
Config.DailyRewards = {
	{ { kind = "coins", amount = 300, perLevel = true } },
	{ { kind = "egg", id = "TidePool", amount = 2 } },
	{ { kind = "pearls", amount = 10 } },
	{ { kind = "boost", boost = "luck", minutes = 15 }, { kind = "coins", amount = 300, perLevel = true } },
	{ { kind = "egg", id = "Kelp", amount = 2 } },
	{ { kind = "pearls", amount = 20 }, { kind = "boost", boost = "coins", minutes = 30 } },
	{ { kind = "charm", amount = 1 }, { kind = "pearls", amount = 30 }, { kind = "boost", boost = "all", minutes = 30 } },
}
Config.DailyWeekBonus = 0.25
Config.DailyMaxMultiplier = 2

---------------------------------------------------------------------------
-- STARTER GIFT (given once, the very first time someone joins)
---------------------------------------------------------------------------
Config.StarterGift = {
	{ kind = "coins", amount = 500 },
	{ kind = "pearls", amount = 10 },
	{ kind = "egg", id = "TidePool", amount = 1 },
	{ kind = "boost", boost = "coins", minutes = 15 },
}

---------------------------------------------------------------------------
-- TUTORIAL ("Getting Started"). Steps finish by themselves when the check
-- becomes true. progress returns (current, goal) for the progress bar.
-- menu = which menu button pulses, target = "portal" draws the guide line
-- to the Sunlit Shallows portal.
---------------------------------------------------------------------------
Config.Tutorial = {
	{ text = "Haul up your first crate", hint = "Follow the golden line to your dock and hold E on the crate.",
		progress = function(d) return d.stats.hauls, 1 end, reward = { { kind = "coins", amount = 100 } } },
	{ text = "Haul up 5 crates", hint = "Your subs keep diving. Collect each crate as it comes up.",
		progress = function(d) return d.stats.hauls, 5 end, reward = { { kind = "coins", amount = 150 } } },
	{ text = "Buy a second sub", hint = "Open SHOP and buy a sub. More subs = more crates!", menu = "SHOP",
		progress = function(d) return #d.subs, 2 end, reward = { { kind = "pearls", amount = 5 } } },
	{ text = "Restore your first ship", hint = "Open LOGBOOK to see which fragments you still need.", menu = "LOGBOOK",
		progress = function(d) local n = 0 for _ in pairs(d.ships) do n += 1 end return n, 1 end,
		reward = { { kind = "coins", amount = 300 } } },
	{ text = "Hatch an egg", hint = "Open PETS and press HATCH on your Tide Pool Egg.", menu = "PETS",
		progress = function(d) return d.stats.hatched, 1 end, reward = { { kind = "egg", id = "TidePool", amount = 1 } } },
	{ text = "Visit a hunting ground", hint = "Walk to the glowing portals on the island and dive into Sunlit Shallows.", target = "portal",
		progress = function(d) return d.stats.arenaVisits, 1 end, reward = { { kind = "pearls", amount = 5 } } },
	{ text = "Defeat 3 sea creatures", hint = "Press 1 (or tap your spear) to take it out, then click or tap creatures.",
		progress = function(d) return d.stats.kills, 3 end, reward = { { kind = "coins", amount = 400 } } },
	{ text = "Reach Level 5", hint = "Hauls, kills and quests all give XP.",
		progress = function(d) return d.level + d.rebirths * 100, 5 end, reward = { { kind = "boost", boost = "xp", minutes = 15 } } },
	{ text = "Rebirth for the first time", hint = "Open REBIRTH. You need Level 7 and 13K coins.", menu = "REBIRTH",
		progress = function(d) return d.rebirths, 1 end,
		reward = { { kind = "pearls", amount = 25 }, { kind = "charm", amount = 1 } } },
}
Config.TutorialDailyAfterStep = 3 -- don't pop up the daily calendar for brand-new players until this step

---------------------------------------------------------------------------
-- GLOBAL LEADERBOARDS (boards on the island, all servers, all time)
---------------------------------------------------------------------------
Config.Leaderboards = {
	{ id = "Rebirths", title = "MOST REBIRTHS", color = Color3.fromRGB(255, 160, 60), value = function(data) return data.rebirths end },
	{ id = "Levels", title = "MOST LEVELS GAINED", color = Color3.fromRGB(60, 225, 210), value = function(data) return data.stats.levelsGained end },
	{ id = "Kills", title = "TOP HUNTERS", color = Color3.fromRGB(255, 90, 90), value = function(data) return data.stats.kills end },
}
Config.LeaderboardRefresh = 120 -- seconds between board refreshes
Config.AutosaveInterval = 60 -- seconds between saves (and leaderboard updates)

---------------------------------------------------------------------------
-- ANTI-CHEAT (server-side movement checks)
---------------------------------------------------------------------------
Config.AntiCheat = {
	enabled = true,
	interval = 0.5, -- seconds between checks
	speedTolerance = 1.6, -- allowed speed = WalkSpeed x this
	extraStuds = 14, -- slack for lag spikes
	maxRiseSpeed = 90, -- studs per second upward (a jump is ~50)
	maxHeight = 160, -- nobody should ever be this high
	strikesToKick = 10, -- kicked after this many strikes...
	strikeWindow = 60, -- ...within this many seconds
	kick = true,
}

function Config.GetPassByKey(key)
	for _, pass in ipairs(Config.GamePasses) do
		if pass.key == key then
			return pass
		end
	end
	return nil
end

function Config.GetProductByKey(key)
	for _, product in ipairs(Config.Products) do
		if product.key == key then
			return product
		end
	end
	return nil
end

---------------------------------------------------------------------------
-- SEASON PASS
-- Earn season XP from hauls, kills, quests and events. Every tier gives the
-- rewards of the tracks you own (Free always, Premium with either pass,
-- Mystic with the Mystic pass). Reach the last tier, then earn
-- prestigeExtraTiers more tiers of XP to PRESTIGE: the pass resets and every
-- reward gets bigger. Season pets upgrade to Radiant, then Celestial.
-- When you make Season 2, change id + name + rewards. Progress and the
-- season passes reset automatically for the new season id.
---------------------------------------------------------------------------
Config.Season = {
	id = "S1",
	name = "Season 1: Tides of the Deep",
	tiers = 20,
	xpPerTier = 1000,
	prestigeExtraTiers = 5,
	maxPrestige = 2,
	prestigeMultiplier = { 1, 1.75, 2.5 }, -- reward amounts on prestige 0, 1, 2
	premiumXpBonus = 0.1,
	mysticXpBonus = 0.25,
	overflowPearls = 5, -- pearls per extra tier once you can't prestige any more
	xpPerHaul = 1,
	xpPerEvent = 150,
}

---------------------------------------------------------------------------
-- SEASON CHARMS: items found in the water this season.
-- They drop from hauls, creatures and Tide Bottles (floating in the sea around
-- the island). Equip up to CharmSlots of them (+1 with VIP) for their bonus.
-- Charms from an old season keep working, they just stop dropping.
-- When you make Season 2, add new charms with season = "S2".
---------------------------------------------------------------------------
Config.CharmSlots = 2
Config.Charms = {
	{ id = "SeaGlass", name = "Sea-Glass Charm", season = "S1", rarity = 1, weight = 40,
		color = rgb(120, 230, 210), bonus = { luck = 0.05 } },
	{ id = "TideShell", name = "Tide Shell", season = "S1", rarity = 1, weight = 35,
		color = rgb(255, 210, 170), bonus = { coins = 0.06 } },
	{ id = "CoralTotem", name = "Coral Totem", season = "S1", rarity = 2, weight = 14,
		color = rgb(255, 120, 150), bonus = { xp = 0.12 } },
	{ id = "KrakenTooth", name = "Kraken Tooth", season = "S1", rarity = 3, weight = 6,
		color = rgb(235, 225, 210), bonus = { damage = 0.2 } },
	{ id = "StormScale", name = "Storm Scale", season = "S1", rarity = 3, weight = 3.5,
		color = rgb(120, 140, 255), bonus = { luck = 0.12, hull = 0.01 } },
	{ id = "Moonstone", name = "Moonstone", season = "S1", rarity = 4, weight = 1.2,
		color = rgb(200, 220, 255), bonus = { luck = 0.2, xp = 0.15 } },
	{ id = "CrownOfTides", name = "Crown of Tides", season = "S1", rarity = 5, weight = 0.3,
		color = rgb(255, 205, 70), bonus = { luck = 0.35, coins = 0.25 } },
}
Config.CharmChanceHaul = 0.02 -- chance per successful haul
Config.CharmChanceKill = 0.01 -- chance per creature kill
Config.CharmDissolveXp = { 40, 100, 250, 600, 1500 } -- season XP for dissolving a spare, by rarity

-- Tide Bottles: glowing bottles that bob in the sea. Swim out and open them.
Config.Drifters = {
	name = "Tide Bottle",
	interval = 35, -- seconds between new bottles
	max = 8, -- bottles floating at once
	seasonXp = 60,
	coins = 120, -- multiplied by your coin bonus
	charmChance = 0.35,
	color = rgb(90, 255, 230),
}

function Config.GetCharm(id)
	for _, charm in ipairs(Config.Charms) do
		if charm.id == id then
			return charm
		end
	end
	return nil
end

-- Charms that can drop right now (this season's)
function Config.SeasonCharms()
	local list = {}
	for _, charm in ipairs(Config.Charms) do
		if charm.season == Config.Season.id then
			table.insert(list, charm)
		end
	end
	return list
end

function Config.CharmBonusTotals(charmIds)
	local totals = { coins = 0, luck = 0, hull = 0, xp = 0, damage = 0 }
	for _, id in ipairs(charmIds) do
		local charm = Config.GetCharm(id)
		if charm then
			for stat, value in pairs(charm.bonus) do
				totals[stat] += value
			end
		end
	end
	return totals
end

local function coins(amount)
	return { kind = "coins", amount = amount }
end
local function pearls(amount)
	return { kind = "pearls", amount = amount }
end
local function xp(amount)
	return { kind = "xp", amount = amount }
end
local function egg(id, amount)
	return { kind = "egg", id = id, amount = amount }
end
local function boost(which, minutes)
	return { kind = "boost", boost = which, minutes = minutes }
end
local function seasonPet(baseId)
	return { kind = "pet", ids = Config.SeasonPet(baseId) }
end
local function weapon(id)
	return { kind = "weapon", id = id }
end

-- rewards[tier] = { free = ..., premium = ..., mystic = ... } (any can be nil)
Config.Season.rewards = {
	[1] = { premium = pearls(10), mystic = seasonPet("MysticMinnow") },
	[2] = { free = coins(2000), premium = boost("coins", 15), mystic = pearls(30) },
	[3] = { premium = egg("Kelp", 2), mystic = boost("luck", 60) },
	[4] = { free = egg("TidePool", 2), premium = coins(10000), mystic = egg("Midnight", 2) },
	[5] = { premium = seasonPet("TideWyrm"), mystic = seasonPet("MysticJelly") },
	[6] = { free = pearls(5), premium = boost("luck", 30), mystic = coins(100000) },
	[7] = { premium = xp(2000), mystic = boost("coins", 120) },
	[8] = { free = boost("xp", 15), premium = egg("Twilight", 2), mystic = egg("Abyss", 2) },
	[9] = { premium = pearls(25), mystic = pearls(80) },
	[10] = { free = seasonPet("CoralSprite"), premium = weapon("TidebreakerTrident"), mystic = weapon("MysticTrident") },
	[11] = { premium = coins(40000), mystic = xp(10000) },
	[12] = { free = coins(15000), premium = boost("xp", 30), mystic = egg("Abyss", 3) },
	[13] = { premium = egg("Midnight", 2), mystic = boost("luck", 120) },
	[14] = { free = egg("Kelp", 2), premium = pearls(40), mystic = pearls(120) },
	[15] = { premium = seasonPet("CrownedTurtle"), mystic = seasonPet("AstralOctopus") },
	[16] = { free = pearls(15), premium = boost("coins", 60), mystic = coins(500000) },
	[17] = { premium = coins(150000), mystic = boost("all", 60) },
	[18] = { free = boost("coins", 30), premium = egg("Abyss", 1), mystic = egg("Abyss", 5) },
	[19] = { premium = pearls(60), mystic = pearls(200) },
	[20] = { free = egg("Midnight", 1), premium = seasonPet("SovereignRay"), mystic = seasonPet("MysticLeviathan") },
}

-- What a reward actually gives at a prestige level (0, 1 or 2)
function Config.ScaleReward(reward, prestige)
	local mult = Config.Season.prestigeMultiplier[prestige + 1] or 1
	local scaled = table.clone(reward)
	if reward.amount then
		scaled.amount = math.max(1, math.floor(reward.amount * mult + 0.5))
	end
	if reward.minutes then
		scaled.minutes = math.floor(reward.minutes * mult + 0.5)
	end
	if reward.ids then
		scaled.id = reward.ids[math.min(prestige + 1, #reward.ids)]
	end
	return scaled
end

function Config.DescribeReward(reward, prestige)
	local r = Config.ScaleReward(reward, prestige or 0)
	if r.kind == "coins" then
		return Config.FormatNumber(r.amount) .. " Coins", Color3.fromRGB(255, 205, 80)
	elseif r.kind == "pearls" then
		return r.amount .. " Pearls", Color3.fromRGB(235, 230, 255)
	elseif r.kind == "xp" then
		return Config.FormatNumber(r.amount) .. " XP", Color3.fromRGB(60, 225, 210)
	elseif r.kind == "egg" then
		local eggDef = Config.GetEgg(r.id)
		return r.amount .. "x " .. (eggDef and eggDef.name or r.id), eggDef and eggDef.spots or Color3.new(1, 1, 1)
	elseif r.kind == "boost" then
		local label = r.boost == "all" and "2x Everything" or ("2x " .. r.boost:sub(1, 1):upper() .. r.boost:sub(2))
		return label .. " (" .. r.minutes .. "m)", Color3.fromRGB(110, 235, 140)
	elseif r.kind == "pet" then
		local pet = Config.GetPet(r.id)
		return pet and pet.name or r.id, pet and Config.PetRarities[pet.rarity].color or Color3.new(1, 1, 1)
	elseif r.kind == "weapon" then
		local w = Config.GetWeapon(r.id)
		return w and w.name or r.id, Color3.fromRGB(255, 150, 80)
	elseif r.kind == "charm" then
		return (r.amount or 1) .. "x Random Season Charm", Color3.fromRGB(90, 255, 230)
	end
	return "?", Color3.new(1, 1, 1)
end

-- Season tier (0..) reached for an amount of season XP
function Config.SeasonTier(seasonXp)
	return math.floor(seasonXp / Config.Season.xpPerTier)
end

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
	if bonus.damage then
		table.insert(parts, "+" .. math.floor(bonus.damage * 100 + 0.5) .. "% damage")
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
