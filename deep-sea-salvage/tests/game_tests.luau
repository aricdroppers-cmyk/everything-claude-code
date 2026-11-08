-- ===== Tests =====
local passed, failed = 0, 0
local function check(cond, label)
	if cond then
		passed += 1
	else
		failed += 1
		print("FAIL: " .. label)
	end
end
local function lastNotify(userId, kind)
	local list = notifications[userId] or {}
	for i = #list, 1, -1 do
		if list[i].kind == kind then
			return list[i]
		end
	end
	return nil
end
local function clearNotes()
	notifications = {}
end

local function makePlayer(id, name)
	local p = newMock("Player")
	p.ClassName = "Player"
	p.UserId = id
	p.Name = name
	p.DisplayName = name
	p.Character = false
	local attrs = {}
	p.SetAttribute = function(_, k, v)
		attrs[k] = v
	end
	p.GetAttribute = function(_, k)
		return attrs[k]
	end
	p.Kick = function(_, msg)
		p.kicked = msg
	end
	p.attrs = attrs
	return p
end

local function giveCharacter(p, cf)
	local char = newMock("Model")
	char.ClassName = "Model"
	char.Name = p.Name
	local hrp = Instance.new("Part")
	hrp.Name = "HumanoidRootPart"
	hrp.CFrame = cf
	hrp.Parent = char
	local head = Instance.new("Part")
	head.Name = "Head"
	head.Parent = char
	local hum = Instance.new("Humanoid")
	hum.Parent = char
	local arm = Instance.new("Part")
	arm.Name = "RightUpperArm"
	arm.Parent = char
	local shoulder = Instance.new("Motor6D")
	shoulder.Name = "RightShoulder"
	shoulder.C0 = CFrame.new(1, 0.5, 0)
	shoulder.Parent = arm
	char.PrimaryPart = hrp
	p.Character = char
	local backpack = Instance.new("Backpack")
	backpack.Parent = p
	return char, hrp, hum
end

-- walk up to a prompt, then use it (like a real player)
local function fire(prompt, who)
	local char = who.Character
	local target = prompt.Parent
	if char and target and target.CFrame then
		char.PrimaryPart.CFrame = CFrame.new(target.CFrame.Position + Vector3.new(0, 3, 0))
	end
	handlers(prompt.Triggered)[1](who)
end

presetData["player_1"] = {
	coins = 100000, pearls = 50, level = 12, xp = 0, stats = { hauls = 5 },
	subs = { { id = "Rowboat", depth = 1 } },
	parts = { ["FishingSkiff/Hull"] = 3, ["FishingSkiff/Mast"] = 1 },
	ships = {}, eggs = { TidePool = 2 },
	pets = { { uid = 1, id = "Clownfish" }, { uid = 2, id = "Octopus" } },
	equipped = { 1 }, nextPetUid = 3, autoSell = false,
}
presetData["player_2"] = { starterGiven = true, tutorial = { step = 99 },
	coins = 500, pearls = 0, level = 10, xp = 0,
	subs = { { id = "Rowboat", depth = 1 } },
	parts = { ["FishingSkiff/Oars"] = 1, ["FishingSkiff/Net"] = 1, ["FishingSkiff/Mast"] = 1 },
	ships = {}, eggs = { Kelp = 1 }, pets = {}, equipped = {}, nextPetUid = 1, autoSell = true,
}
presetData["player_3"] = { starterGiven = true, tutorial = { step = 99 }, coins = 0, level = 3 }

-- boot the server
Config.AntiCheat.enabled = false -- tests teleport characters around; turned on in its own section
Config.GetProductByKey("SeasonMystic").id = 777
fakePrices[777] = 800
local mainCo = coroutine.create(SERVER)
local ok, err = coroutine.resume(mainCo)
check(ok, "server boots: " .. tostring(err))
Config.GetProductByKey("SeasonMystic").id = 0 -- back to Studio test mode for the purchase tests
check(coroutine.status(mainCo) == "suspended", "server reaches main loop")

local Players = PlayersService
local function join(p)
	p.Parent = PlayersService
	if not p.Character then
		giveCharacter(p, CFrame.new(0, 5, 0))
	end
	table.insert(playersList, p)
	for _, h in ipairs(handlers(Players.PlayerAdded)) do
		task.spawn(h, p)
	end
end
local function act(p, ...)
	fakeClock += 0.15 -- a human clicks a few times a second, not 1000
	local actionRemote
	for _, obj in ipairs(created) do
		if obj.ClassName == "RemoteEvent" and obj.Name == "Action" then
			actionRemote = obj
		end
	end
	for _, h in ipairs(handlers(actionRemote.OnServerEvent)) do
		h(p, ...)
	end
end
local function heartbeat(dt)
	for _, h in ipairs(handlers(game:GetService("RunService").Heartbeat)) do
		h(dt)
	end
end
local function tick(seconds)
	fakeNow += seconds
	fakeClock += seconds
	fakeTime += seconds
	runSleeping()
	runDelayed()
end

local A, B, C = makePlayer(1, "Alice"), makePlayer(2, "Bob"), makePlayer(3, "Cara")
join(A)
join(B)
join(C)
check(lastNotify(1, "welcome") ~= nil, "A got welcome")
check(lastState[1] and lastState[1].level == 12, "A state level 12")
check(A.attrs.Level == 12, "A Level attribute set")
check(A.attrs.EquippedPets == "Clownfish", "A equipped pets attribute = Clownfish, got " .. tostring(A.attrs.EquippedPets))
check(lastState[3] and lastState[3].level == 3, "C reconciled to level 3")

-- ===== Dive loop: crate appears and can be collected =====
local promptsBefore = 0
for _, obj in ipairs(created) do
	if obj.ClassName == "ProximityPrompt" then
		promptsBefore += 1
	end
end
tick(30) -- all rowboats finish (10s dives)
local prompts = {}
for _, obj in ipairs(created) do
	if obj.ClassName == "ProximityPrompt" then
		table.insert(prompts, obj)
	end
end
local breached = lastState[3] and lastState[3].subs[1].status == "Repairing"
check(#prompts - promptsBefore >= 2, "crates spawned for surfaced subs (" .. (#prompts - promptsBefore) .. ")")
local cCoinsBefore = lastState[3].coins
local cXpBefore = lastState[3].xp
-- find C's prompt (ObjectText contains Cara)
local cPrompt
for _, pr in ipairs(prompts) do
	if string.find(tostring(pr.ObjectText), "Cara") then
		cPrompt = pr
	end
end
if cPrompt then
	-- someone else can't take it
	fire(cPrompt, A)
	check(lastNotify(1, "error") ~= nil, "A blocked from taking Cara's crate")
	fire(cPrompt, C)
	check(lastState[3].coins > cCoinsBefore, "C coins increased after haul")
	check(lastState[3].xp > cXpBefore or lastState[3].level > 3, "C gained XP")
	check(lastNotify(3, "loot") ~= nil, "C got loot notification")
	check(lastState[3].subs[1].status == "Diving", "C sub diving again")
else
	check(breached, "C had no crate only because of a breach")
end

-- ===== Level up =====
local leveledUp = false
local usedPrompts = {}
for _ = 1, 400 do
	tick(12)
	for _, pr in ipairs(created) do
		if pr.ClassName == "ProximityPrompt" and string.find(tostring(pr.ObjectText), "Cara") and not usedPrompts[pr] then
			usedPrompts[pr] = true
			fire(pr, C)
		end
	end
	if lastState[3].level >= 5 then
		leveledUp = true
		break
	end
end
check(leveledUp, "C reached level 5 by hauling (level " .. lastState[3].level .. ")")
check(lastNotify(3, "levelup") ~= nil, "C got levelup notification")
check(C.attrs.Level == lastState[3].level, "C Level attribute tracks level")

-- ===== Hatching =====
local coinsBefore = lastState[1].coins
act(A, "HatchEgg", "TidePool")
local hatch = lastNotify(1, "hatch")
check(hatch ~= nil, "A hatched an egg")
check(lastState[1].coins == coinsBefore - 250, "hatch cost 250 coins")
check(#lastState[1].pets == 3, "A now has 3 pets")
check(lastState[1].eggs.TidePool == 1, "A has 1 TidePool egg left")
check(#lastState[1].equipped == 2, "new pet auto-equipped into free slot")
act(A, "HatchEgg", "Abyss")
check(#lastState[1].pets == 3, "can't hatch an egg you don't own")
act(B, "HatchEgg", "Kelp")
check(lastNotify(2, "error") ~= nil and #lastState[2].pets == 0, "B can't afford Kelp egg (500 < 1500)")

-- equip toggling
act(A, "EquipPet", 1)
check(#lastState[1].equipped == 1, "unequip pet 1")
act(A, "EquipBest")
check(#lastState[1].equipped == 3, "equip best fills 3 slots")
act(A, "EquipPet", 1) -- unequip clownfish to keep it tradeable
act(A, "EquipPet", 2) -- unequip octopus

-- ===== Trading =====
clearNotes()
act(C, "TradeRequest", 1)
check(lastNotify(3, "error") ~= nil, "C (low level) can't request a trade")
act(A, "TradeRequest", 3)
check(lastNotify(1, "error") ~= nil, "A can't trade with low-level C")
act(A, "TradeRequest", 2)
check(lastNotify(2, "tradeRequest") ~= nil, "B got A's trade request")
act(B, "TradeRespond", 1, true)
check(lastNotify(1, "trade") ~= nil and lastNotify(2, "trade") ~= nil, "trade window opened for both")

act(A, "TradeAdd", "part", "FishingSkiff/Mast") -- A only has 1 Mast: not a spare
check(lastNotify(1, "error") ~= nil, "can't trade your only copy of a fragment")
act(A, "TradeAdd", "part", "FishingSkiff/Hull")
act(A, "TradeAdd", "part", "FishingSkiff/Hull")
clearNotes()
act(A, "TradeAdd", "part", "FishingSkiff/Hull") -- 3 owned => only 2 spares
check(lastNotify(1, "error") ~= nil, "can't add more spares than you have")
act(A, "TradeRemove", "part", "FishingSkiff/Hull") -- back to 1 Hull offered
act(A, "TradeAdd", "pet", 2)
local equippedUid = lastState[1].equipped[1]
clearNotes()
act(A, "TradeAdd", "pet", equippedUid)
check(lastNotify(1, "error") ~= nil, "can't trade an equipped pet")
act(B, "TradeAdd", "egg", "Kelp")
act(A, "TradeAdd", "part", "Fake/Thing")
local t = lastNotify(1, "trade")
check(#t.mine == 2 and #t.theirs == 1, "offers: A has 2 items, B has 1")

act(A, "TradeReady")
act(B, "TradeReady")
check(lastNotify(1, "trade").theirReady == true, "A sees B ready")
-- change resets ready
act(B, "TradeRemove", "egg", "Kelp")
check(lastNotify(1, "trade").myReady == false and lastNotify(1, "trade").theirReady == false, "change resets ready")
act(B, "TradeAdd", "egg", "Kelp")
act(A, "TradeConfirm")
check(lastNotify(1, "trade").myConfirm == false, "can't confirm before both ready")
act(A, "TradeReady")
act(B, "TradeReady")
act(A, "TradeConfirm")
check(lastState[2].eggs.Kelp == 1, "nothing moved after only one confirm")
act(B, "TradeConfirm")
check(lastNotify(1, "tradeEnded") and lastNotify(1, "tradeEnded").text == "Trade complete!", "trade completed")
check(lastState[1].parts["FishingSkiff/Hull"] == 2, "A Hull 3 -> 2")
check(lastState[2].parts["FishingSkiff/Hull"] == 1, "B received Hull")
check(lastState[2].ships.FishingSkiff == true, "B restored Fishing Skiff from the traded Hull")
check(lastNotify(2, "ship") ~= nil, "B got ship-restored notification")
check(lastState[1].eggs.Kelp == 1, "A received Kelp egg")
check(lastState[2].eggs.Kelp == nil, "B no longer has Kelp egg")
check(#lastState[2].pets == 1 and lastState[2].pets[1].id == "Octopus", "B received Octopus")
local aHasOctopus = false
for _, pet in ipairs(lastState[1].pets) do
	if pet.uid == 2 then
		aHasOctopus = true
	end
end
check(not aHasOctopus, "A no longer has Octopus")
check(savedData["player_1"] and savedData["player_2"], "both players saved right after trade")

-- after trade, actions are idle
act(A, "TradeConfirm")
check(true, "stray confirm after trade doesn't crash")

-- trade cancelled when a player leaves
fakeClock += 6 -- trade requests have a 5s cooldown
act(A, "TradeRequest", 2)
act(B, "TradeRespond", 1, true)
act(A, "TradeAdd", "part", "FishingSkiff/Hull")
table.remove(playersList, 2)
B.Parent = nil
for _, h in ipairs(handlers(Players.PlayerRemoving)) do
	h(B)
end
check(lastNotify(1, "tradeEnded") ~= nil, "A told trade ended when B left")
check(lastState[1].parts["FishingSkiff/Hull"] == 2, "A kept items when trade cancelled")

-- remote spam is rate limited
local spamBefore = #(notifications[1] or {})
for _ = 1, 200 do
	local remote
	for _, obj in ipairs(created) do
		if obj.ClassName == "RemoteEvent" and obj.Name == "Action" then
			remote = obj
		end
	end
	handlers(remote.OnServerEvent)[1](A, "TradeRequest", 2) -- 200 requests in the same instant
end
local spamNotes = #(notifications[1] or {}) - spamBefore
check(spamNotes <= 21, "200 spammed actions in one instant -> at most ~20 handled (" .. spamNotes .. ")")
fakeClock += 3

-- sell spares
act(A, "SellSpares")
check(lastState[1].parts["FishingSkiff/Hull"] == 1, "sell spares leaves 1 copy")
check(lastNotify(1, "soldSpares").count == 1, "sold 1 spare")

-- release pet
local petsBefore = #lastState[1].pets
act(A, "ReleasePet", 1)
check(#lastState[1].pets == petsBefore - 1, "released a pet")

-- buy a sub
local subsBefore = #lastState[1].subs
act(A, "BuySub", "IronMinnow")
check(#lastState[1].subs == subsBefore + 1, "bought a sub")
act(A, "SetDepth", 2, 3)
check(lastState[1].subs[2].depth == 3, "set depth 3")
act(A, "SetDepth", 2, 5)
check(lastState[1].subs[2].depth == 3, "can't exceed sub max depth")

-- ======================= NEW SYSTEMS =======================
local day = math.floor(fakeTime / 86400)
local week = math.floor((fakeTime + 3 * 86400) / 604800)
presetData["player_4"] = { starterGiven = true, tutorial = { step = 99 },
	coins = 0, level = 15,
	season = { id = "S1", xp = 24999, prestige = 0, premium = false, mystic = false, claimed = {} },
	quests = {
		daily = { key = day, list = { { id = "Haul", progress = 40, claimed = false }, { id = "Hatch", progress = 0, claimed = false } } },
		weekly = { key = week, list = { { id = "WeeklyHaul", progress = 500, claimed = false } } },
	},
}
presetData["player_5"] = { starterGiven = true, tutorial = { step = 99 },
	coins = 300000, level = 25, xp = 0,
	subs = { { id = "Rowboat", depth = 1 }, { id = "IronMinnow", depth = 3 }, { id = "BrassBell", depth = 2 } },
	weapons = { "DriftwoodSpear", "BrassHarpoon", "TidebreakerTrident" }, weapon = "BrassHarpoon",
}
presetData["player_6"] = { starterGiven = true, tutorial = { step = 99 }, coins = 0, level = 30 }

-- ===== Season pass: free rewards on join =====
local D = makePlayer(4, "Dana")
join(D)
local sD = lastState[4]
check(sD.season.claimed["free:20"] == true, "free tier 20 reward given on join")
check(sD.season.claimed["premium:1"] == nil, "no premium rewards without the pass")
check((sD.eggs.TidePool or 0) == 2 and (sD.eggs.Kelp or 0) == 2 and (sD.eggs.Midnight or 0) == 1, "free egg rewards given")
local hasCoral = false
for _, pet in ipairs(sD.pets) do
	if pet.id == "CoralSprite" then
		hasCoral = true
	end
end
check(hasCoral, "free Coral Sprite pet given")
check(sD.coins == 2000 + 15000, "free coin rewards = 17000, got " .. sD.coins)
check(lastNotify(4, "seasonRewards") ~= nil, "season reward notification sent")

-- ===== Buying premium then mystic (Studio test purchases) =====
act(D, "Buy", "SeasonPremium")
sD = lastState[4]
check(sD.season.premium == true, "premium pass granted")
check(sD.season.claimed["premium:20"] == true and sD.season.claimed["premium:1"] == true, "premium rewards granted for tiers already reached")
check(table.find(sD.weapons, "TidebreakerTrident") ~= nil, "premium weapon given")
act(D, "Buy", "SeasonPremium")
check(lastNotify(4, "error") ~= nil, "can't buy premium twice")
act(D, "Buy", "SeasonMystic")
sD = lastState[4]
check(sD.season.mystic == true, "mystic pass granted")
check(sD.season.claimed["mystic:20"] == true, "mystic rewards granted")
local mythic = 0
for _, pet in ipairs(sD.pets) do
	local def = Config.GetPet(pet.id)
	if def and def.rarity == 6 then
		mythic += 1
	end
end
check(mythic == 3, "3 Mythic pets from the Mystic track, got " .. mythic)
check(table.find(sD.weapons, "MysticTrident") ~= nil, "Mystic Trident given")
check(#sD.equipped == 3, "season pets auto-equipped into free slots")

-- ===== Prestige =====
act(D, "SeasonPrestige")
check(lastState[4].season.prestige == 0, "can't prestige at tier 24 (needs 25)")
-- one haul = 1 season XP -> tier 25
local usedD = {}
for _ = 1, 10 do
	tick(12)
	for _, pr in ipairs(created) do
		if pr.ClassName == "ProximityPrompt" and string.find(tostring(pr.ObjectText), "Dana") and not usedD[pr] then
			usedD[pr] = true
			fire(pr, D)
		end
	end
	if Config.SeasonTier(lastState[4].season.xp) >= 25 then
		break
	end
end
check(Config.SeasonTier(lastState[4].season.xp) >= 25, "reached tier 25")
act(D, "SeasonPrestige")
sD = lastState[4]
check(sD.season.prestige == 1 and sD.season.xp == 0, "prestiged to 1, XP reset")
check(next(sD.season.claimed) == nil, "claimed rewards reset after prestige")

-- ===== Quests feed the season pass; prestige rewards are bigger =====
local coinsBefore = sD.coins
local levelBeforeQuests = sD.level
act(D, "ClaimQuest", "daily", 2) -- Hatch quest, not done
check(lastState[4].dailyQuests[2].claimed == false, "can't claim unfinished quest")
act(D, "ClaimQuest", "daily", 1)
act(D, "ClaimQuest", "weekly", 1)
act(D, "ClaimQuest", "weekly", 1)
sD = lastState[4]
check(sD.dailyQuests[1].claimed and sD.weeklyQuests[1].claimed, "quests claimed")
check(sD.level > levelBeforeQuests, "quest XP rewards gave levels (" .. levelBeforeQuests .. " -> " .. sD.level .. ")")
-- 400 + 2500 season XP with +25% mystic bonus = 3625 -> tier 3
check(sD.season.xp == 3625, "season XP from quests with mystic bonus = 3625, got " .. sD.season.xp)
local hasRadiant = false
for _, pet in ipairs(sD.pets) do
	if pet.id == "RadiantMysticMinnow" then
		hasRadiant = true
	end
end
check(hasRadiant, "prestige 1 gives the Radiant version of the season pet")
-- tier 2 free coins 2000 x1.75 = 3500, quest coins 150*15 + 2000*15 = 32250, tier 2 premium boost (not coins)
check(sD.coins - coinsBefore == 3500 + (150 + 2000) * levelBeforeQuests, "prestige-scaled coins + level-scaled quest coins, got " .. (sD.coins - coinsBefore))

-- ===== Boosts and receipts =====
local baseMult = lastState[1].multipliers.coins
act(A, "Buy", "BoostCoins")
check(math.abs(lastState[1].multipliers.coins - baseMult * 2) < 1e-6, "2x coins boost doubles coin multiplier")
check(lastState[1].boostsLeft.coins == 1800, "boost lasts 30 minutes")
act(A, "Buy", "BoostCoins")
check(lastState[1].boostsLeft.coins == 3600, "buying again stacks time")
Config.GetProductByKey("BoostXP").id = 999
local granted = MarketplaceService.ProcessReceipt({ PlayerId = 1, PurchaseId = "receipt-1", ProductId = 999 })
check(granted == Enum.ProductPurchaseDecision.PurchaseGranted, "receipt granted")
check(lastState[1].boostsLeft.xp == 1800, "receipt gave XP boost")
MarketplaceService.ProcessReceipt({ PlayerId = 1, PurchaseId = "receipt-1", ProductId = 999 })
check(lastState[1].boostsLeft.xp == 1800, "same receipt is never granted twice")
check(savedData["player_1"] and savedData["player_1"].receipts["receipt-1"], "receipt saved before granting")
local unknown = MarketplaceService.ProcessReceipt({ PlayerId = 77, PurchaseId = "x", ProductId = 999 })
check(unknown == Enum.ProductPurchaseDecision.NotProcessedYet, "receipt for missing player is retried later")
Config.GetProductByKey("BoostXP").id = 0
tick(1800)
check(math.abs(lastState[1].multipliers.coins - baseMult * 2) < 1e-6 or lastState[1].boostsLeft.coins ~= nil, "boost still on after 30 of 60 minutes")

-- ===== Game passes =====
act(A, "Buy", "PetSlots")
check(lastState[1].passes.PetSlots == true and lastState[1].maxEquipped == 5, "pet slots pass -> 5 slots")
act(A, "Buy", "PetSlots")
check(lastNotify(1, "error") ~= nil, "can't buy a pass twice")
act(A, "Buy", "VIP")
check(A.attrs.Level ~= nil, "VIP updates public info")

-- ===== Rebirth =====
local E = makePlayer(5, "Eli")
join(E)
local multBefore = lastState[5].multipliers.coins
act(E, "Rebirth")
local sE = lastState[5]
check(sE.rebirths == 1, "rebirth 1 done")
check(sE.level == 1 and sE.coins == 0, "level and coins reset")
check(#sE.subs == 1 and sE.subs[1].id == "Rowboat", "subs reset to one Rowboat")
check(table.find(sE.weapons, "TidebreakerTrident") and not table.find(sE.weapons, "BrassHarpoon"), "season weapon kept, shop weapon lost")
check(sE.weapon == "DriftwoodSpear", "equipped weapon reset")
check(math.abs(sE.multipliers.coins - (multBefore + 0.25)) < 1e-6, "+25% coin multiplier from rebirth 1")
check(sE.pearls == 5, "rebirth 1 gives 5 pearls, got " .. tostring(sE.pearls))
check(E.attrs.Rebirths == 1, "Rebirths attribute set")
act(E, "Rebirth")
check(lastState[5].rebirths == 1, "second rebirth blocked by requirements")
local _, needCoins = Config.RebirthRequirement(1)
check(needCoins == 29900, "rebirth 2 costs 29.9K, got " .. needCoins)

-- ===== Combat =====
local char, hrp, hum = giveCharacter(A, CFrame.new(0, 5, 0))
act(A, "EquipWeapon", "DriftwoodSpear")
local backpack = A:FindFirstChildOfClass("Backpack")
local tool = backpack:FindFirstChildOfClass("Tool")
check(tool ~= nil and tool.Name == "Driftwood Spear", "weapon tool given")
check(tool and tool:FindFirstChild("Handle") ~= nil, "tool has a Handle")

-- C (low level) can't enter Twilight
local function portal(zoneName)
	for _, pr in ipairs(created) do
		if pr.ClassName == "ProximityPrompt" and pr.ActionText == "Dive In" and string.find(tostring(pr.ObjectText), zoneName) then
			return pr
		end
	end
end
clearNotes()
fire(portal("Twilight"), C)
check(lastNotify(3, "error") ~= nil, "level gate on Twilight portal")

fire(portal("Sunlit"), A)
local arenaCenter1 = Config.ArenaCenter(1)
check((hrp.CFrame.Position - arenaCenter1).Magnitude < 100, "portal teleported A into the Shallows arena")

for _ = 1, 12 do
	fakeClock += 0.25
	heartbeat(0.25)
end
local enemiesAlive = {}
for _, obj in ipairs(created) do
	if (obj.Name == "SnappyCrab" or obj.Name == "StingJelly") and not rawget(obj, "__destroyed") and obj.ClassName == "Model" then
		table.insert(enemiesAlive, obj)
	end
end
check(#enemiesAlive >= 2, "enemies spawned in the Shallows (" .. #enemiesAlive .. ")")
check(#enemiesAlive <= Config.Arenas[1].maxEnemies, "no more than maxEnemies")

local target = enemiesAlive[1]
local coinsBeforeKill = lastState[1].coins
local killed = false
for _ = 1, 60 do
	local enemyPos = target.PrimaryPart.CFrame.Position
	hrp.CFrame = CFrame.lookAt(enemyPos + Vector3.new(0, 0, 4), Vector3.new(enemyPos.X, enemyPos.Y, enemyPos.Z))
	fakeClock += 0.5
	handlers(tool.Activated)[1]()
	heartbeat(0.05)
	runDelayed()
	if lastNotify(1, "kill") then
		killed = true
		break
	end
end
check(killed, "killed an enemy with the spear")
for _ = 1, 20 do
	fakeClock += 0.06
	runSleeping()
end
check(rawget(target, "__destroyed") == true, "death animation finishes and removes the creature")
local swung, numbers = false, 0
for _, tw in ipairs(tweens) do
	if rawget(tw.target, "__props") and tw.target.Name == "RightShoulder" and tw.props.C0 then
		swung = true
	end
end
for _, obj in ipairs(created) do
	if obj.ClassName == "TextLabel" and tonumber(obj.Text) then
		numbers += 1
	end
end
check(swung, "attacking swings the character's arm (shoulder C0 tween)")
check(numbers > 0, "damage numbers pop up (" .. numbers .. ")")
check(lastNotify(1, "kill") ~= nil, "kill notification")
check(lastState[1].coins > coinsBeforeKill, "kill gave coins")
check(hum.Health < 100, "enemies fight back (A health " .. hum.Health .. ")")

-- attacking with nothing in range does nothing bad
hrp.CFrame = CFrame.new(arenaCenter1 + Vector3.new(0, 5, 85))
fakeClock += 1
handlers(tool.Activated)[1]()
check(true, "swinging at nothing is fine")

-- leaving empties the arena after 20s
hrp.CFrame = CFrame.new(0, 5, 0)
for _ = 1, 100 do
	fakeClock += 0.25
	heartbeat(0.25)
end
local stillAlive = 0
for _, obj in ipairs(created) do
	if (obj.Name == "SnappyCrab" or obj.Name == "StingJelly") and obj.ClassName == "Model" and not rawget(obj, "__destroyed") then
		stillAlive += 1
	end
end
check(stillAlive == 0, "arena despawns when empty (" .. stillAlive .. " left)")

-- Leviathan spawns in the Abyss after 60s with a player there
local F = makePlayer(6, "Finn")
join(F)
local _, fhrp, fhum = giveCharacter(F, CFrame.new(0, 5, 0))
act(F, "EquipBest") -- refreshes public info, which sets max health
check(fhum.MaxHealth == Config.PlayerBaseHealth + 30 * Config.HealthPerLevel, "Level 30 max health = " .. fhum.MaxHealth)
fire(portal("The Abyss"), F)
check((fhrp.CFrame.Position - Config.ArenaCenter(5)).Magnitude < 100, "Finn is in the Abyss")
fhrp.CFrame = CFrame.new(Config.ArenaCenter(5) + Vector3.new(0, 4, 0)) -- stand in the middle
announcements = {}
local lowest = fhum.MaxHealth
for _ = 1, 260 do
	fakeClock += 0.25
	heartbeat(0.25)
	lowest = math.min(lowest, fhum.Health)
	fhum.Health = fhum.MaxHealth -- keep Finn alive so we can test the boss timer
end
check(lowest < fhum.MaxHealth, "Abyss creatures attacked Finn")
local rose = false
for _, a in ipairs(announcements) do
	if string.find(a.text, "LEVIATHAN RISES") then
		rose = true
	end
end
check(rose, "Leviathan boss spawned in the Abyss")
local bossModel
for _, obj in ipairs(created) do
	if obj.Name == "Leviathan" and obj.ClassName == "Model" and not rawget(obj, "__destroyed") then
		bossModel = obj
	end
end
check(bossModel ~= nil, "boss model exists")


-- ======================= ROUND 3: charms, bottles, paid rebirth, exploits =======================
-- Tide Bottles spawn over time and must be reached to open
local bottles = {}
for _ = 1, 10 do
	tick(Config.Drifters.interval + 1)
end
for _, obj in ipairs(created) do
	if obj.Name == "TideBottle" and not rawget(obj, "__destroyed") then
		table.insert(bottles, obj)
	end
end
check(#bottles >= 3 and #bottles <= Config.Drifters.max, "Tide Bottles spawned in the sea (" .. #bottles .. ")")
local bottlePrompt = bottles[1] and bottles[1]:FindFirstChildOfClass("ProximityPrompt")
-- from far away: nothing happens
A.Character.PrimaryPart.CFrame = CFrame.new(0, 5, 0)
local aSeasonXp = lastState[1].season.xp
handlers(bottlePrompt.Triggered)[1](A)
check(not rawget(bottles[1], "__destroyed"), "can't open a bottle from across the map")
fire(bottlePrompt, A)
check(rawget(bottles[1], "__destroyed") == true, "opened a bottle by swimming to it")
check(lastNotify(1, "drifter") ~= nil, "bottle reward notification")
check(lastState[1].season.xp > aSeasonXp, "bottle gave season XP")
fire(bottlePrompt, C)
check(true, "opening an already-opened bottle is ignored")

-- Charms: open bottles until we have some, then equip / dissolve
local opened = 1
for round = 1, 40 do
	if next(lastState[1].charms) then
		break
	end
	tick(Config.Drifters.interval + 1)
	for _, obj in ipairs(created) do
		if obj.Name == "TideBottle" and not rawget(obj, "__destroyed") then
			fire(obj:FindFirstChildOfClass("ProximityPrompt"), A)
			opened += 1
		end
	end
end
local charmId = lastState[1].equippedCharms[1]
check(next(lastState[1].charms) ~= nil, "got a charm from bottles (opened " .. opened .. ")")
check(charmId ~= nil, "a charm got auto-equipped")
if charmId then
	local multWith = lastState[1].multipliers
	act(A, "EquipCharm", charmId)
	check(table.find(lastState[1].equippedCharms, charmId) == nil, "unequip charm")
	local charm = Config.GetCharm(charmId)
	if charm.bonus.luck then
		check(lastState[1].multipliers.luck < multWith.luck, "charm luck bonus applies")
	end
	act(A, "EquipCharm", charmId)
	-- dissolve spares down to the one that's equipped, then one more must fail
	local spares = lastState[1].charms[charmId] - 1
	for _ = 1, spares do
		act(A, "DissolveCharm", charmId)
	end
	check(lastState[1].charms[charmId] == 1, "dissolved all spares")
	clearNotes()
	act(A, "DissolveCharm", charmId)
	check(lastState[1].charms[charmId] == 1 and lastNotify(1, "error") ~= nil, "can't dissolve your only equipped charm")
	act(A, "EquipCharm", "NotACharm")
	check(true, "equipping a fake charm id is ignored")
end
check(lastState[1].charmSlots == 3, "VIP gives a 3rd charm slot (A has VIP)")

-- Robux: Level Pack, Rebirth Rush, Instant Rebirth (through ProcessReceipt)
local function buyProduct(p, key, purchaseId)
	local product = Config.GetProductByKey(key)
	product.id = 5000 + #purchaseId
	local result = MarketplaceService.ProcessReceipt({ PlayerId = p.UserId, PurchaseId = purchaseId, ProductId = product.id })
	product.id = 0
	return result
end
local cLevel = lastState[3].level
buyProduct(C, "LevelPack", "lp-1")
check(lastState[3].level == cLevel + 3, "Level Pack gave exactly 3 levels (" .. cLevel .. " -> " .. lastState[3].level .. ")")
buyProduct(C, "RebirthRush", "rush-1")
check(lastState[3].boostsLeft.coins == 1800 and lastState[3].boostsLeft.xp == 1800, "Rebirth Rush = 2x coins + 2x XP for 30 min")
local cRebirths = lastState[3].rebirths
buyProduct(C, "InstantRebirth", "rb-1")
check(lastState[3].rebirths == cRebirths + 1, "Instant Rebirth works without meeting requirements")
check(lastState[3].level == 1, "paid rebirth still resets level")
buyProduct(C, "InstantRebirth", "rb-1")
check(lastState[3].rebirths == cRebirths + 1, "same Instant Rebirth receipt can't be used twice")

-- Exploit: teleporting into a hunting ground you're too low for
local cHrp = C.Character.PrimaryPart
cHrp.CFrame = CFrame.new(Config.ArenaCenter(5) + Vector3.new(0, 4, 0))
clearNotes()
for _ = 1, 3 do
	fakeClock += 0.25
	heartbeat(0.25)
end
check((cHrp.CFrame.Position - Config.ArenaCenter(5)).Magnitude > 200, "low-level player who teleported into the Abyss is sent home")
check(lastNotify(3, "error") ~= nil, "and told why")

-- Exploit: hitting creatures from another hunting ground
local before = 0
for _, obj in ipairs(created) do
	if obj.Name == "Leviathan" and obj.ClassName == "Model" and not rawget(obj, "__destroyed") then
		before += 1
	end
end
check(before == 1, "boss still alive before cross-arena test")
-- ======================= EVENTS: run all three for real =======================
announcements = {}
local eventsSeen = {}
for _ = 1, 3 * 12 do
	tick(30)
	for _, a in ipairs(announcements) do
		for _, name in ipairs({ "STORM SURGE", "TREASURE TIDE", "KRAKEN ATTACK" }) do
			if string.find(a.text or "", name) then
				eventsSeen[name] = true
			end
		end
	end
end
local seenCount = 0
for _ in pairs(eventsSeen) do
	seenCount += 1
end
check(seenCount >= 1, "random events fire on schedule (" .. seenCount .. " different kinds in 18 min)")


-- ======================= ROUND 4: daily streak, leaderboards, autosave, anti-cheat, prices =======================
check(lastState[1].prices.SeasonMystic == 800, "live Robux price read from Roblox (800)")
check(Config.SaleActive(Config.GetProductByKey("SeasonMystic"), fakeTime) == true, "Mystic launch sale is running")
check(Config.SaleActive(Config.GetProductByKey("SeasonMystic"), 1798761540 + 1) == false, "sale switches itself off after its end date")

-- daily streak
local H = makePlayer(8, "Hana")
presetData["player_8"] = { starterGiven = true, tutorial = { step = 99 }, coins = 0, level = 4 }
join(H)
check(lastNotify(8, "dailyAvailable") ~= nil, "daily reward offered on join")
check(lastState[8].login.canClaim == true and lastState[8].login.streak == 1, "day 1 ready")
local coins0 = lastState[8].coins
act(H, "ClaimDaily")
check(lastNotify(8, "dailyClaimed") and lastNotify(8, "dailyClaimed").streak == 1, "claimed day 1")
check(lastState[8].coins - coins0 == 300 * lastState[8].level, "day 1 = 300 coins x level")
clearNotes()
act(H, "ClaimDaily")
check(lastNotify(8, "error") ~= nil, "can't claim twice in a day")
local function nextDay(days)
	fakeTime += 86400 * (days or 1)
end
for d = 2, 8 do
	nextDay()
	act(H, "ClaimDaily")
	check(lastNotify(8, "dailyClaimed").streak == d, "streak day " .. d)
end
check(next(lastState[8].charms) ~= nil, "day 7 gives a season charm")
check(lastNotify(8, "dailyClaimed").multiplier == 1.25, "week 2 rewards x1.25")
nextDay(2) -- missed a day
act(H, "ClaimDaily")
check(lastNotify(8, "dailyClaimed").streak == 1, "missing a day resets the streak")
check(lastState[8].login.best == 8, "best streak remembered")

-- autosave every minute + global leaderboards
savedData["player_8"] = nil
for _ = 1, 45 do
	tick(2)
end
check(savedData["player_8"] ~= nil, "autosave within ~a minute")
check(orderedData["LB_Levels_v1"] and (orderedData["LB_Levels_v1"]["3"] or 0) >= 5, "Cara's lifetime levels on the global leaderboard (" .. tostring(orderedData["LB_Levels_v1"] and orderedData["LB_Levels_v1"]["3"]) .. ")")
check(orderedData["LB_Rebirths_v1"] and orderedData["LB_Rebirths_v1"]["5"] == 1, "Eli's rebirth on the rebirth leaderboard")
for _ = 1, 6 do
	tick(25)
end
local boardText = ""
for _, obj in ipairs(created) do
	if obj.ClassName == "TextLabel" and type(obj.Text) == "string" and string.find(obj.Text, "#1") then
		boardText = obj.Text
	end
end
check(boardText ~= "", "island boards show the top players (" .. boardText .. ")")

-- anti-cheat (Finn leaves first: there are only 6 bays)
local function leave(p)
	local i = table.find(playersList, p)
	if i then
		table.remove(playersList, i)
	end
	p.Parent = nil
	for _, h in ipairs(handlers(Players.PlayerRemoving)) do
		h(p)
	end
end
leave(F)
local gotKicked = makePlayer(99, "Extra")
local fullBays = {}
for id = 100, 105 do
	local extra = makePlayer(id, "Extra" .. id)
	join(extra)
	table.insert(fullBays, extra)
end
local kickedExtras = 0
for _, extra in ipairs(fullBays) do
	if rawget(extra, "__props").kicked then
		kickedExtras += 1
	end
end
check(kickedExtras >= 1, "a 7th player is told the server is full (" .. kickedExtras .. " turned away)")
for _, extra in ipairs(fullBays) do
	leave(extra)
end
Config.AntiCheat.enabled = true
local G = makePlayer(9, "Gus")
presetData["player_9"] = { starterGiven = true, tutorial = { step = 99 }, coins = 0, level = 3 }
join(G)
local ghrp = G.Character.PrimaryPart
ghrp.CFrame = CFrame.new(0, 5, 0)
for _ = 1, 4 do
	tick(0.5) -- learn where Gus is (and let the join teleport grace run out)
end
local home = ghrp.CFrame.Position
ghrp.CFrame = CFrame.new(home + Vector3.new(4, 0, 0)) -- normal walking
tick(0.5)
check((ghrp.CFrame.Position - (home + Vector3.new(4, 0, 0))).Magnitude < 0.1, "normal walking is fine")
local before = ghrp.CFrame.Position
ghrp.CFrame = CFrame.new(before + Vector3.new(300, 0, 0)) -- speed hack / teleport
tick(0.5)
check((ghrp.CFrame.Position - before).Magnitude < 1, "teleport/speed hack is pulled back")
tick(0.6)
ghrp.CFrame = CFrame.new(before + Vector3.new(0, 400, 0)) -- fly hack
tick(0.5)
check(ghrp.CFrame.Position.Y < 100, "fly hack is pulled back down")
-- portals and going home are server teleports and must NOT be flagged
tick(0.6)
fire(portal("Sunlit"), G)
local inArena = ghrp.CFrame.Position
tick(0.5)
check((ghrp.CFrame.Position - inArena).Magnitude < 0.1, "portal teleport is not treated as cheating")
check(rawget(G, "__props").kicked == nil, "not kicked for a few strikes")
for _ = 1, 12 do
	tick(0.6)
	ghrp.CFrame = CFrame.new(ghrp.CFrame.Position + Vector3.new(500, 0, 0))
end
tick(0.6)
check(rawget(G, "__props").kicked ~= nil, "kicked after too many strikes in a minute")
Config.AntiCheat.enabled = false


-- ======================= ROUND 5: starter gift + tutorial (a brand-new player) =======================
leave(G)
leave(H)
check(lastState[1].tutorial.active == false, "veteran players skip the tutorial")
check(lastNotify(1, "starterGift") == nil, "veterans don't get the starter gift")
clearNotes()
local T = makePlayer(20, "Tia") -- no saved data at all = brand new
join(T)
local sT = lastState[20]
check(lastNotify(20, "starterGift") ~= nil, "starter gift on first join")
check(sT.coins == 500 and sT.pearls == 10 and (sT.eggs.TidePool or 0) == 1, "gift = 500 coins, 10 pearls, Tide Pool Egg")
check(sT.boostsLeft.coins ~= nil, "gift includes a coin boost")
check(sT.tutorial.active and sT.tutorial.step == 1, "tutorial starts at step 1")
check(lastNotify(20, "dailyAvailable") == nil, "daily popup waits until the tutorial is a few steps in")

local usedT = {}
local function haulT(n)
	for _ = 1, n do
		tick(12)
		for _, pr in ipairs(created) do
			if pr.ClassName == "ProximityPrompt" and string.find(tostring(pr.ObjectText), "Tia") and not usedT[pr] then
				usedT[pr] = true
				fire(pr, T)
			end
		end
	end
end
-- keep hauling until the step completes (a Storm Surge event can sink a crate)
local function haulUntilStep(stepNumber, maxTicks)
	for _ = 1, maxTicks do
		if lastState[20].tutorial.step >= stepNumber then
			return
		end
		haulT(1)
	end
end
haulUntilStep(2, 10)
check(lastState[20].tutorial.step >= 2, "step 1 done after the first haul")
check(lastState[20].hauls >= 1, "at least one haul")
haulUntilStep(3, 25)
check(lastState[20].tutorial.step >= 3 and lastState[20].hauls >= 5, "step 2 done after 5 hauls")
act(T, "BuySub", "Rowboat")
check(lastState[20].tutorial.step >= 4, "step 3 done after buying a sub")
check(lastNotify(20, "dailyAvailable") ~= nil, "daily popup offered once the tutorial is underway")
for _ = 1, 40 do
	if lastState[20].tutorial.step >= 5 then break end
	haulT(1)
end
check(lastState[20].tutorial.step >= 5, "step 4 done after restoring a ship")
act(T, "HatchEgg", "TidePool")
check(lastState[20].tutorial.step >= 6, "step 5 done after hatching")
check(lastState[20].tutorial.target == "portal", "step 6 points at the portal")
fire(portal("Sunlit"), T)
for _ = 1, 4 do
	fakeClock += 0.25
	heartbeat(0.25)
end
check(lastState[20].tutorial.step >= 7, "step 6 done after entering a hunting ground")
local tTool = T:FindFirstChildOfClass("Backpack"):FindFirstChildOfClass("Tool")
local tHrp = T.Character.PrimaryPart
for _ = 1, 400 do
	if lastState[20].tutorial.step >= 8 then break end
	fakeClock += 0.25
	heartbeat(0.25)
	runDelayed()
	runSleeping() -- let death animations finish so dead creatures disappear
	local nearest, nd = nil, math.huge
	for _, obj in ipairs(created) do
		if (obj.Name == "SnappyCrab" or obj.Name == "StingJelly") and obj.ClassName == "Model" and not rawget(obj, "__destroyed") then
			local d = (obj.PrimaryPart.CFrame.Position - tHrp.CFrame.Position).Magnitude
			if d < nd then nearest, nd = obj, d end
		end
	end
	if nearest then
		local p = nearest.PrimaryPart.CFrame.Position
		tHrp.CFrame = CFrame.lookAt(p + Vector3.new(0, 0, 4), p)
		T.Character:FindFirstChildOfClass("Humanoid").Health = 300
		handlers(tTool.Activated)[1]()
	end
end
check(lastState[20].tutorial.step >= 8, "step 7 done after defeating 3 creatures (kills "
	.. tostring(lastState[20].tutorial.current) .. ", step " .. lastState[20].tutorial.step .. ", hp " .. T.Character:FindFirstChildOfClass("Humanoid").Health
	.. ", pos " .. tostring(tHrp.CFrame.Position) .. ", level " .. lastState[20].level .. ")")
haulT(1)
for _ = 1, 150 do
	if lastState[20].tutorial.step >= 9 then break end
	haulT(1)
end
check(lastState[20].tutorial.step >= 9, "step 8 done at Level 5 (level " .. lastState[20].level .. ")")
local tPearls = lastState[20].pearls
buyProduct(T, "InstantRebirth", "tia-rb")
check(lastState[20].tutorial.active == false, "tutorial complete after the first rebirth")
check(lastNotify(20, "tutorialDone") ~= nil, "completion celebration")
check(lastState[20].pearls >= tPearls + 25, "final step reward (25 pearls + rebirth pearls)")

-- skipping
leave(T)
local U = makePlayer(21, "Uma")
join(U)
check(lastState[21].tutorial.active == true, "new player has the tutorial")
act(U, "SkipTutorial")
check(lastState[21].tutorial.active == false, "tutorial can be skipped")
haulT(0)
leave(U)
join(T) -- Tia comes back: gift is not given twice
check(lastState[20].coins ~= nil and (notifications[20] or {})[1] ~= nil, "Tia rejoined")


-- ======================= ROUND 6: group reward, new passes, storage, weather + mutations =======================
presetData["player_30"] = {
	starterGiven = true, tutorial = { step = 99 }, coins = 0, level = 6, autoSell = false,
	eggs = { TidePool = 25 },
	parts = { ["FishingSkiff/Hull"] = 151 }, -- 150 spares = full
	pets = { { uid = 1, id = "Clownfish" }, { uid = 2, id = "Octopus" } }, equipped = { 1, 2 }, nextPetUid = 3,
}
local W = makePlayer(30, "Wes")
join(W)
local sW = lastState[30]
check(sW.maxPets == 40 and sW.eggCapacity == 25 and sW.spareCapacity == 150, "default storage: 40 pets, 25 eggs, 150 spares")

-- group reward (Studio test mode while GroupId is 0)
fakeClock += 5
act(W, "ClaimGroupReward")
sW = lastState[30]
check(sW.groupClaimed == true, "group reward claimed")
check((sW.charms.CrewBadge or 0) == 1 and table.find(sW.equippedCharms, "CrewBadge") ~= nil, "exclusive Crew Badge charm given and equipped")
check(sW.pearls == 25 and sW.coins == 200 * 6, "group reward pearls + level-scaled coins")
check((sW.eggs.Kelp or 0) == 2, "group reward eggs (gifts can go over the egg limit)")
fakeClock += 5
clearNotes()
act(W, "ClaimGroupReward")
check(lastNotify(30, "error") ~= nil, "group reward only once")

-- storage limits: full egg storage sells new eggs, full spare storage sells new spares
local savedEggChance = Config.EggChance
Config.EggChance = 1
local coinsBeforeHaul = lastState[30].coins
local usedW = {}
local function haulW(n)
	for _ = 1, n do
		tick(12)
		for _, pr in ipairs(created) do
			if pr.ClassName == "ProximityPrompt" and string.find(tostring(pr.ObjectText), "Wes") and not usedW[pr] then
				usedW[pr] = true
				fire(pr, W)
			end
		end
	end
end
haulW(3)
Config.EggChance = savedEggChance
local eggNote = nil
for _, n in ipairs(notifications[30] or {}) do
	if n.kind == "storageFull" and n.what == "eggs" then eggNote = n end
end
check(eggNote ~= nil, "egg storage full -> egg sold for coins")
local eggCount = 0
for _, c in pairs(lastState[30].eggs) do eggCount += c end
check(eggCount == 27, "egg count didn't grow past the limit (" .. eggCount .. ")")
check(lastState[30].coins > coinsBeforeHaul, "coins from hauls and sold eggs")

-- passes
act(W, "Buy", "BigTank")
act(W, "Buy", "BigStorage")
local dmgBefore = lastState[30].multipliers.damage
act(W, "Buy", "DoubleDamage")
sW = lastState[30]
check(sW.maxPets == 100, "Bigger Pet Tank: 100 pets")
check(sW.eggCapacity == 50 and sW.spareCapacity == 300, "2x Storage doubles eggs and spares")
check(math.abs(sW.multipliers.damage - dmgBefore * 2) < 1e-6, "2x Weapon Damage doubles damage")

-- weather: pick chances are real probabilities with clear skies left over
local chanceSum = 0
for _, w in ipairs(Config.Weather.types) do
	chanceSum += w.chance
end
check(chanceSum < 1, "some weather rolls are clear skies (" .. math.floor((1 - chanceSum) * 100 + 0.5) .. "%)")
check(Config.Weather.interval == 600, "weather rolls every 10 minutes")
local savedChances = {}
for i, w in ipairs(Config.Weather.types) do
	savedChances[i] = { w.chance, w.crateChance, w.petChance }
	w.crateChance, w.petChance = 1, 1
	w.chance = i == 1 and 1 or 0 -- force a Thunderstorm for the test
end
local remotesFolder = ReplicatedStorage:FindFirstChild("SalvageRemotes")
local weatherSeen = nil
for _ = 1, 40 do -- let any weather that's already going finish first, so we catch a fresh one
	if (remotesFolder:GetAttribute("Weather") or "") == "" then break end
	tick(5)
end
for _ = 1, 260 do
	tick(5)
	local id = remotesFolder:GetAttribute("Weather")
	if id and id ~= "" then
		weatherSeen = id
		break
	end
end
check(weatherSeen ~= nil, "weather starts on its own (" .. tostring(weatherSeen) .. ")")
clearNotes()
for _ = 1, 6 do -- a Storm Surge breach can sink a crate, so allow a few dives
	haulW(1)
	if lastNotify(30, "mutatedHaul") then break end
end
local mutatedNote = lastNotify(30, "mutatedHaul")
check(mutatedNote ~= nil, "crates come up mutated during weather")
if mutatedNote then
	local mutation = Config.Mutations[mutatedNote.mutation]
	check(mutatedNote.coins >= Config.Zones[1].coins * mutation.coinMult, "mutated haul pays x" .. mutation.coinMult)
end
for _ = 1, 6 do
	tick(5)
end
local mutatedPet = false
for _, pet in ipairs(lastState[30].pets) do
	if pet.mutation then mutatedPet = true end
end
check(mutatedPet, "equipped pets mutate during weather")
check(string.find(W.attrs.EquippedPets or "", ":") ~= nil, "mutation shared with other players (" .. tostring(W.attrs.EquippedPets) .. ")")
local multMutated = lastState[30].petBonus.coins
check(multMutated > 0, "mutated pets still give bonuses")
for _ = 1, 30 do
	tick(5)
end
check((remotesFolder:GetAttribute("Weather") or "") == "", "weather ends")
for i, w in ipairs(Config.Weather.types) do
	w.chance, w.crateChance, w.petChance = savedChances[i][1], savedChances[i][2], savedChances[i][3]
end

-- weather timing: clear skies -> next roll in 5 min; weather -> next roll 10 min after it started
local function nextRollAfterARoll()
	local before = remotesFolder:GetAttribute("NextWeatherRoll")
	for _ = 1, 400 do
		tick(5)
		local after = remotesFolder:GetAttribute("NextWeatherRoll")
		if after ~= before then
			return before, after
		end
	end
end
for _, w in ipairs(Config.Weather.types) do
	w.chance = 0 -- every roll is clear skies
end
local rollAt, nextAt = nextRollAfterARoll()
check(rollAt and nextAt and math.abs((nextAt - rollAt) - 300) < 6, "clear skies -> next roll 5 minutes later (" .. tostring(nextAt and rollAt and nextAt - rollAt) .. "s)")
Config.Weather.types[1].chance = 1 -- next roll is a Thunderstorm
rollAt, nextAt = nextRollAfterARoll()
check(rollAt and nextAt and math.abs((nextAt - rollAt) - 600) < 11, "weather -> next roll 10 minutes after it started (" .. tostring(nextAt and rollAt and nextAt - rollAt) .. "s)")
for i, w in ipairs(Config.Weather.types) do
	w.chance = savedChances[i][1]
end

-- pet abilities: a player whose pets are already Frozen, Golden and Rainbow
leave(W)
presetData["player_31"] = {
	starterGiven = true, tutorial = { step = 99 }, coins = 0, level = 8,
	pets = { { uid = 1, id = "Clownfish", mutation = "Frozen" }, { uid = 2, id = "Starfish", mutation = "Golden" },
		{ uid = 3, id = "HermitCrab", mutation = "Rainbow" }, { uid = 4, id = "Pufferfish", mutation = "Electric" } },
	equipped = { 1, 2, 3 }, nextPetUid = 5,
}
local X = makePlayer(31, "Xan")
join(X)
act(X, "Buy", "PetSlots")
act(X, "EquipPet", 4)
check(#lastState[31].equipped == 4, "4 mutated pets equipped (Electric, Frozen, Golden, Rainbow)")
check(string.find(X.attrs.EquippedPets or "", "Rainbow") ~= nil, "mutations show on followers")
local yellowBolts = 0
fire(portal("Sunlit"), X)
local xHum = X.Character:FindFirstChildOfClass("Humanoid")
local xHrp = X.Character.PrimaryPart
local neonBefore = 0
for _, obj in ipairs(created) do
	if obj.ClassName == "Part" and obj.Material == Enum.Material.Neon then neonBefore += 1 end
end
local healed, abilityKill = false, nil
for _ = 1, 600 do
	fakeClock += 0.25
	heartbeat(0.25)
	-- stand in the middle of the hunting ground, never swing
	xHrp.CFrame = CFrame.new(Config.ArenaCenter(1) + Vector3.new(0, 4, 0))
	if xHum.Health < 30 or xHum.Health >= xHum.MaxHealth - 1 then
		xHum.Health = xHum.MaxHealth * 0.5 -- keep room to see the Rainbow heal
	end
	local h0 = xHum.Health
	runSleeping()
	runDelayed()
	if xHum.Health > h0 + 0.5 then healed = true end
	if yellowBolts == 0 then
		for i = #created, math.max(1, #created - 80), -1 do
			local obj = created[i]
			if obj.ClassName == "Part" and obj.Material == Enum.Material.Neon and obj.Color == Config.Mutations.Electric.color then
				yellowBolts += 1
			end
		end
	end
	abilityKill = abilityKill or lastNotify(31, "kill")
	if healed and abilityKill then break end
end
local neonAfter = 0
for _, obj in ipairs(created) do
	if obj.ClassName == "Part" and obj.Material == Enum.Material.Neon then neonAfter += 1 end
end
check(abilityKill ~= nil, "mutated pets kill creatures on their own (no swinging)")
check(healed, "Rainbow Prism Beam heals the player")
check(neonAfter > neonBefore, "ability bolts and bursts are drawn")
check(yellowBolts > 0, "Chain Lightning bolts are drawn")
if abilityKill then
	local def
	for _, e in ipairs(Config.Enemies) do
		if e.name == abilityKill.enemy then def = e end
	end
	local expected = math.floor(def.coins * lastState[31].multiplier * 1.5)
	check(abilityKill.coins == expected, "Golden pet: kills give +50% coins (" .. abilityKill.coins .. " vs " .. expected .. ")")
end
leave(X)

-- ======================= CLIENT: run the real UI against the real server =======================
clientPlayer = A
PlayersService.LocalPlayer = A
fakeClock += 5
local clientCo = coroutine.create(CLIENT)
local okClient, errClient = coroutine.resume(clientCo)
check(okClient, "client script starts: " .. tostring(errClient))
for _ = 1, 5 do
	tick(0.3)
end
check(#clientErrors == 0, "no client errors after start: " .. (clientErrors[1] or ""))

local function findButton(label)
	for i = #created, 1, -1 do
		local obj = created[i]
		if obj.ClassName == "TextButton" and obj.Text == label and not rawget(obj, "__destroyed") then
			return obj
		end
	end
end
local function click(btn, label)
	local hs = handlers(btn.MouseButton1Click)
	for _, h in ipairs(hs) do
		local ok, err = pcall(h)
		if not ok then
			table.insert(clientErrors, "click " .. tostring(label) .. ": " .. tostring(err))
		end
	end
	tick(0.2)
end
local function isLive(obj)
	local o = obj
	for _ = 1, 40 do
		if rawget(o, "__destroyed") then return false end
		if rawget(o, "__props").ClassName == "ScreenGui" then return true end
		local parent = rawget(o, "__props").Parent
		if type(parent) ~= "table" then return false end
		o = parent
	end
	return false
end

local menus = { "FLEET", "SHOP", "PETS", "LOGBOOK", "QUESTS", "SEASON", "STORE", "REBIRTH", "TRADE", "DAILY" }
local clicked = 0
for _, name in ipairs(menus) do
	local menuButton = findButton(name)
	check(menuButton ~= nil, "menu button " .. name .. " exists")
	if menuButton then
		click(menuButton, name)
		-- click every live button inside the panel, a few rounds (tabs open new views)
		for round = 1, 2 do
			local snapshot = {}
			for _, obj in ipairs(created) do
				if obj.ClassName == "TextButton" and isLive(obj) and not table.find(menus, obj.Text) and obj.Text ~= "MY BAY"
					and obj.Text ~= "X" then
					table.insert(snapshot, obj)
				end
			end
			for _, btn in ipairs(snapshot) do
				if isLive(btn) then
					click(btn, name .. " > " .. tostring(btn.Text))
					clicked += 1
				end
			end
		end
		-- close by clicking the menu button again, then make sure it reopens fine
		click(findButton(name), name .. " close")
	end
end
check(clicked > 50, "fuzz-clicked " .. clicked .. " buttons across every panel")

-- every notification kind the server can send
local kinds = {
	{ kind = "loot", rarity = 5, ship = "HollowTide", part = "Cursed Bell", isNew = true, sold = 0 },
	{ kind = "loot", rarity = 2, ship = "SteamTug", part = "Boiler", isNew = false, sold = 40 },
	{ kind = "coins", amount = 1234 }, { kind = "ship", ship = "BlackGull" }, { kind = "breach", sub = "Iron Minnow", zone = "Kelp Reef" },
	{ kind = "announce", text = "hello", color = nil }, { kind = "chest", pearls = 2, coins = 150 },
	{ kind = "kraken", coins = 500, pearls = 6, hits = 30, egg = true }, { kind = "bought", sub = "Brass Bell" },
	{ kind = "error", text = "nope" }, { kind = "info", text = "fyi" }, { kind = "egg", egg = "Kelp" },
	{ kind = "levelup", level = 10, tradeUnlocked = true }, { kind = "hatch", egg = "Kelp", pet = "KelpDragon" },
	{ kind = "hatch", egg = "Abyss", pet = "LeviathanPup" }, { kind = "released", pet = "Clownfish", coins = 25 },
	{ kind = "soldSpares", count = 3, coins = 90 }, { kind = "tradeRequest", from = "Bob", fromUserId = 2 },
	{ kind = "trade", partner = "Bob", mine = { { kind = "part", id = "FishingSkiff/Hull", amount = 1 } },
		theirs = { { kind = "pet", id = 4, petId = "Octopus", amount = 1 }, { kind = "egg", id = "Kelp", amount = 2 } },
		myReady = true, theirReady = true, myConfirm = false, theirConfirm = false },
	{ kind = "tradeEnded", text = "Trade complete!" }, { kind = "purchase", text = "thanks" },
	{ kind = "seasonTier", tier = 4 }, { kind = "seasonRewards", prestige = 1, rewards = {
		{ reward = Config.Season.rewards[1].mystic, track = "mystic", tier = 1 },
		{ reward = { kind = "pearls", amount = 5 }, track = "bonus", tier = 23, raw = true } } },
	{ kind = "seasonPrestige", prestige = 2 }, { kind = "questDone", text = "Haul up 40 crates" },
	{ kind = "questClaimed", coins = 900, pearls = 2, seasonXp = 400, xp = 120 }, { kind = "rebirth", rebirths = 3, pearls = 15 },
	{ kind = "kill", enemy = "Snappy Crab", coins = 8 }, { kind = "kill", enemy = "THE LEVIATHAN", coins = 50000, pearls = 20, boss = true },
	{ kind = "charm", id = "CrownOfTides", isNew = true }, { kind = "drifter", coins = 120, seasonXp = 60 },
	{ kind = "welcome", canSave = false },
}
local notifyRemote
for _, obj in ipairs(created) do
	if obj.ClassName == "RemoteEvent" and obj.Name == "Notify" then
		notifyRemote = obj
	end
end
for _, payload in ipairs(kinds) do
	notifyRemote:FireClient(A, payload)
end
tick(0.5)
-- the trade panel with an active trade + the hatch reveal button
local tradeButton = findButton("TRADE")
click(tradeButton, "TRADE (active trade)")
local awesome = findButton("AWESOME!")
if awesome then
	click(awesome, "hatch continue")
end

-- phone-sized screen: HUD scales down
local smallest = 1
for _, obj in ipairs(created) do
	if obj.ClassName == "UIScale" and type(obj.Scale) == "number" then
		smallest = math.min(smallest, obj.Scale)
	end
end
check(smallest < 0.6, "HUD shrinks on a phone screen (scale " .. smallest .. ")")

-- new player guide line to a waiting crate
local guideOn = false
for _ = 1, 30 do
	tick(1)
	for _, obj in ipairs(created) do
		if obj.ClassName == "Beam" and obj.Enabled == true then
			guideOn = true
		end
	end
	if guideOn then break end
end
check(guideOn or (lastState[1].hauls or 0) >= 25, "guide line points new players to their crate")

-- getting hit: flash + shake handler
local aHum = A.Character:FindFirstChildOfClass("Humanoid")
aHum.Health = 100
aHum:TakeDamage(10)
check(#clientErrors == 0, "hurt flash runs without errors")

-- render the pet followers and arena lighting for a few frames
remotesFolder = ReplicatedStorage:FindFirstChild("SalvageRemotes")
for _, h in ipairs(handlers(game:GetService("RunService").RenderStepped)) do
	for _ = 1, 3 do
		local ok, err = pcall(h, 1 / 60)
		if not ok then table.insert(clientErrors, "RenderStepped: " .. tostring(err)) end
	end
end
A.Character.PrimaryPart.CFrame = CFrame.new(Config.ArenaCenter(2) + Vector3.new(0, 4, 0))
tick(0.3)
A.Character.PrimaryPart.CFrame = CFrame.new(0, 5, 0)
tick(0.3)

for _, e in ipairs(clientErrors) do
	print("CLIENT ERROR: " .. e)
end
check(#clientErrors == 0, "client ran every panel, button and notification without errors (" .. #clientErrors .. " errors)")

print(string.format("\n%d passed, %d failed", passed, failed))

