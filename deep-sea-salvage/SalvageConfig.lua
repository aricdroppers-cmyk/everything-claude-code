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
		breach = 0.00, coins = 15, diveTime = 10 },
	{ name = "Kelp Reef", depthText = "50-200m", weights = { 60, 30, 9, 1, 0 },
		breach = 0.05, coins = 35, diveTime = 14 },
	{ name = "Twilight Drop", depthText = "200-1000m", weights = { 40, 38, 19, 2.95, 0.05 },
		breach = 0.10, coins = 80, diveTime = 18 },
	{ name = "Midnight Hollow", depthText = "1-4km", weights = { 22, 38, 32, 7.7, 0.3 },
		breach = 0.18, coins = 180, diveTime = 24 },
	{ name = "The Abyss", depthText = "4km+", weights = { 10, 32, 42, 15, 1 },
		breach = 0.28, coins = 400, diveTime = 30 },
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
-- HELPERS (used by both server and client)
---------------------------------------------------------------------------
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
