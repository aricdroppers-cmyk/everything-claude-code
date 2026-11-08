# Deep Sea Salvage (Roblox prototype)

You run a fleet of submarines that haul up fragments of sunken ships. Restore
ships, hatch sea pets, hunt creatures in the deep, climb the season pass and
rebirth for permanent power. Everything is built in code from parts, so you
don't need to import any models, meshes or images.

## Setup in Roblox Studio (4 scripts)

1. Create a new place from the **Baseplate** template.
2. **ReplicatedStorage**: add a **ModuleScript** named exactly `SalvageConfig`
   and paste in `SalvageConfig.lua`.
3. **ReplicatedStorage**: add a **ModuleScript** named exactly `SalvageModels`
   and paste in `SalvageModels.lua`.
4. **ServerScriptService**: add a **Script** named `SalvageServer` and paste in
   `SalvageServer.server.lua`.
5. **StarterPlayer > StarterPlayerScripts**: add a **LocalScript** named
   `SalvageClient` and paste in `SalvageClient.client.lua`.
6. Press **Play**.

If you're updating from an earlier version, **replace all of them**. Every file
has changed, and `SalvageModels` is new.

- **Saving:** publish the place and turn on *Game Settings > Security > Enable
  Studio Access to API Services*.
- **Server size:** 6 players (one bay each).
- **Testing trades:** use *Test > Clients and Servers* with 2 players.

## How to play

### Salvage (the core loop)
- Your subs dive on their own. When one surfaces, hold **E** on the crate at
  your bay. Deeper zones give better loot but carry a higher breach risk.
- **FLEET** sets dive depths, **SHOP > SUBS** sells better subs (up to 5), and
  **LOGBOOK** tracks ship fragments. A completed ship floats at your bay and
  gives a permanent coin bonus.
- Duplicate fragments are spares. They're auto-sold by default; turn that off
  in the Logbook to keep them for trading.

### Levels, eggs, pets, trading
- Hauls and kills give XP. Your level shows over your head and in the player list.
- Eggs drop from hauls (5%) and creatures (1.5%). Hatch them for coins in **PETS**.
- There are 23 egg pets plus 24 season pets. Equip 3 (5 with the pass), and
  they follow you around.
- **Trading unlocks at Level 10** and stays unlocked after you rebirth.

### Hunting grounds (combat)
Five glowing **portals** on the island take you to an underwater hunting
ground for each zone. When you step in, the screen turns underwater blue and
gets darker the deeper you go.

| Grounds | Level | Creatures |
|---|---|---|
| Sunlit Shallows | 1 | Snappy Crab, Sting Jelly |
| Kelp Reef | 5 | Moray Eel, Puffer Brute |
| Twilight Drop | 12 | Barracuda, Giant Squid |
| Midnight Hollow | 20 | Great Shark, Angler Horror |
| The Abyss | 30 | Abyssal Horror + **THE LEVIATHAN** (boss, every 5 min) |

- Buy weapons in **SHOP > WEAPONS**, from the Driftwood Spear (free) up to
  the Leviathan Fang (120 Pearls). The season pass adds the Tidebreaker and
  Mystic Tridents.
- Hold your weapon and click (or tap) to attack whatever is in front of you.
- Kills give coins, XP and season XP, with a chance at fragments and eggs.
- Everyone who damages a creature gets the full reward, so hunting together
  never steals kills.
- The Leviathan gives 50,000 coins, 20 Pearls, 3 fragments and a 50% chance of
  an Abyss Egg to everyone who hit it.

### Daily login streak
- Press **DAILY** (top left; a red "!" means a reward is waiting). The popup
  also opens by itself when you join.
- 7 daily rewards that keep getting better:
  - Day 1: coins (multiplied by your level)
  - Day 2: 2 Tide Pool Eggs
  - Day 3: 10 Pearls
  - Day 4: a luck boost and coins
  - Day 5: 2 Kelp Eggs
  - Day 6: Pearls and a coin boost
  - Day 7: a season Charm, 30 Pearls and a 2x Everything boost
- After each full week the rewards grow by 25%, up to x2.
- **Miss a day and the streak resets to day 1.** Days start at midnight UTC.

### Global leaderboards
- Three boards stand behind the spawn: **Most Rebirths**, **Most Levels
  Gained** (lifetime, so rebirths don't wipe it) and **Top Hunters**.
- They cover every server, all time, and refresh every 2 minutes. Scores are
  uploaded with each save.

### Quests
- **QUESTS** has 3 daily quests (new at midnight UTC) and 2 weekly quests (new
  on Monday).
- Rewards are coins (multiplied by your level), Pearls and **season XP**.

### Rebirth
- **Rebirth 1** needs Level 7 and 13K coins, which takes about 20 minutes.
  Each rebirth after that needs **+3 levels and 2.3x the coins**. There are 15
  rebirths in total.
- Simulated with perfect play: about 19, 24, 38, 48, 74 and 99 minutes for
  rebirths 1-6. Real players are a bit slower, but quests and hunting speed
  them up.
- **Each rebirth gives more than the one before:**
  - Rebirth 1 gives +25% coins, +15% XP, +3% luck, +10% damage, +50 health
    and 5 Pearls.
  - Every later rebirth adds +5% coins, +3% XP, +1% luck, +3% damage,
    +15 health and +5 Pearls on top of that.
  - After 5 rebirths your total is x2.75 coins. It's strong but not
    game-breaking.
- **You lose:** level, coins, subs and shop weapons.
- **You keep:** ships, fragments, pets, charms, eggs, Pearls, season progress,
  season weapons, passes and boosts.
- **Faster with quests:** every quest also gives XP worth half a level (daily)
  or 2 levels (weekly). There's also a weekly "Rebirth 2 times" quest.
- **Faster with Robux** (buttons are on the Rebirth panel and in the Store):
  - **Rebirth Rush** (49 R$): 2x coins and 2x XP for 30 minutes.
  - **+3 Levels** (49 R$): instant levels.
  - **Instant Rebirth** (99 R$): rebirth right now with no requirements. You
    still get the full rewards.

### Season charms and Tide Bottles (items found in the water)
- Glowing **Tide Bottles** float in the sea around the island. A new one
  appears every 35 seconds, up to 8 at a time. Swim out and hold E to open one
  for coins, season XP and a **35% chance at a season Charm**.
- Charms also drop from hauls (2%) and creatures (1%).
- There are 7 Season 1 charms:
  - Sea-Glass Charm: +5% luck
  - Tide Shell: +6% coins
  - Coral Totem: +12% XP
  - Kraken Tooth: +20% damage
  - Storm Scale: +12% luck and -1% breach
  - Moonstone: +20% luck and +15% XP
  - **Crown of Tides**: +35% luck and +25% coins (very rare)
- You can equip 2 charms, or 3 with VIP, in **PETS > CHARMS**. Spare charms
  can be **dissolved** for season XP.
- Charms only drop during their season. For Season 2, add new charms with
  `season = "S2"`. Old charms keep working.

### Season pass
- There are 20 tiers, each needing 1,000 season XP. Season XP comes from
  hauls, kills, quests and events.
- There are 3 reward tracks:
  - **Free** gives a reward every 2 tiers: coins, eggs, Pearls, boosts and a
    Coral Sprite pet.
  - **Premium (400 R$)** gives a reward at every tier: more eggs and boosts,
    3 Epic/Legendary season pets and the Tidebreaker Trident. It also gives
    +10% season XP.
  - **Mystic (1000 R$)** includes everything in Premium, plus its own track of
    the best rewards: 3 **Mythic** pets (a rarity only Mystic gives), the
    Mystic Trident (the strongest weapon), the largest egg/coin/Pearl rewards
    and a 2x Everything boost. It also gives +25% season XP.
- Rewards are given automatically when you reach a tier. If you buy a pass
  later, you instantly get its rewards for every tier you've already reached.
- **Prestige:** after tier 20, earn 5 more tiers of XP, then press PRESTIGE.
  The pass resets and every reward is bigger: x1.75 after the first prestige,
  x2.5 after the second. Season pets upgrade to **Radiant**, then
  **Celestial** versions with stronger bonuses. You can prestige 2 times.
  After that, every extra tier gives Pearls.
- **New season:** change `Config.Season.id`, `name` and `rewards`. Everyone's
  season progress and season passes reset automatically, while pets and
  weapons they earned stay.

## Store: game passes, boosts, season passes

| Item | Type | Price |
|---|---|---|
| 2x Coins | Game pass (forever) | 149 R$ |
| Lucky Diver (+50% luck) | Game pass | 199 R$ |
| Auto Haul (crates collect themselves) | Game pass | 199 R$ |
| +2 Pet Slots | Game pass | 149 R$ |
| VIP (+20% XP, +10% coins, gold tag) | Game pass | 249 R$ |
| 2x Coins / 2x Luck / 2x XP (30 min) | Developer product | 29 / 39 / 25 R$ |
| Rebirth Rush (2x Coins + 2x XP, 30 min) | Developer product | 49 R$ |
| +3 Levels | Developer product | 49 R$ |
| Instant Rebirth | Developer product | 99 R$ |
| Premium Season Pass | Developer product | 400 R$ |
| Mystic Season Pass | Developer product | **800 R$** (launch sale, shown as "20% OFF" 1000) |

The season passes are **developer products**, not game passes, because game
passes last forever and a season pass has to be sold again each season.

### The Mystic launch sale
The game shows Mystic as ~~1000~~ **800 R$, 20% OFF**, with a countdown, until
`saleEnds` in the config (currently 31 Dec 2026). After that the sale label
hides itself.

- **Roblox charges whatever price is set in the Creator Dashboard, not the
  config.** Set the Mystic product to 800 there.
- When the sale ends, set the dashboard price back to 1000.
- The game reads the real prices from Roblox and shows those. If the config
  doesn't match, it prints a warning in the Output window.
- Keep the discount honest: only show "20% off" while it really is a
  limited-time sale. Advertising a fake original price can break
  consumer-protection rules (for example in the EU and UK).

### Making purchases real
1. In the **Creator Dashboard**, open your experience, then
   **Monetization > Passes**. Create the 5 passes.
2. Under **Monetization > Developer Products**, create the 8 products (3 boosts,
   Rebirth Rush, +3 Levels, Instant Rebirth and the 2 season passes).
3. Paste each ID into the matching `id = 0` in `Config.GamePasses` and
   `Config.Products`.

Until an ID is set, pressing Buy **in Studio** gives you the item for free so
you can test everything. In a live game it says "isn't for sale yet". Product
purchases are only confirmed to Roblox once they're saved, so a player never
pays for something they don't receive.

## Tuning
Every number is in `SalvageConfig.lua`: drop rates, prices, enemy health and
damage, weapon stats, quest targets, season rewards, rebirth costs and boost
strength.

Simulated pacing (hauling only, no pets or boosts):

| Milestone | Time |
|---|---|
| Level 10 (trading) | ~21 min |
| Level 20 | ~80 min |
| First rebirth possible | ~20 min |
| Secret ship (The Hollow Tide) | ~2 hours |

**Season pass pace (estimate, not simulated):** an active player earns roughly
1,000-2,000 season XP an hour, plus about 1,200 a day from daily quests. That
works out to about 15-25 hours for the full pass, and 50+ hours for both
prestiges. Tune `Config.Season.xpPerTier` once you see real numbers.

## Saving
- Progress is saved **every minute** (spread out across players so Roblox's
  save limits aren't hit). It's also saved when a player leaves, when the
  server shuts down, and right after trades, rebirths, prestiges and Robux
  purchases.

## Anti-cheat
The server watches every character twice a second:
- **Speed hacks and teleports:** moving faster than the server's WalkSpeed
  allows (with slack for lag) is caught.
- **Fly hacks:** rising faster than a jump, or going above the map, is caught.

A caught player is put back where they were and gets a strike. 10 strikes
within a minute is a kick. Server teleports (portals, going home, rebirth) are
whitelisted so they never count.

On top of that, the server already:
- checks distance on every prompt
- rate-limits remote calls
- checks hunting-ground levels
- validates every trade, purchase and click

Settings are in `Config.AntiCheat`. If honest players with bad internet get
pulled back too often, raise `extraStuds`.

## Combat animations
None of these need uploaded animations:
- **Creatures:** they swim with a wiggle (crabs waddle), lunge forward when
  they bite, flinch when hit, grow in when they spawn, and spin, sink and
  shrink when they die.
- **Your character:** your arm swings with each attack (works on R15 and R6
  characters). Damage numbers pop up over whatever gets hit.
- **When you're hit:** the screen flashes red and the camera shakes.

## Testing
`tests/run.sh` runs the real server **and** the real client inside a fake
Roblox, with real 3D math. You need the free `luau` command line tool from
https://github.com/luau-lang/luau/releases. It runs about 190 checks:
- Gameplay: dives, levels, hatching, trading, the season pass (retroactive
  purchases, prestige scaling), quests, rebirth, all 3 Robux rebirth options,
  boosts and receipts (never granted twice), charms and Tide Bottles, portals,
  enemy AI, weapons, the Leviathan, all 3 random events, the daily streak
  (including missing a day), autosave, the global leaderboards, live prices
  and the combat animations.
- Exploits: remote spam, using prompts from far away, teleporting into
  hunting grounds you're too low for, trading items you don't have, and the
  anti-cheat (speed hack, fly hack, kick after repeated strikes, no false
  alarm on portals).
- The UI: opens every menu, **clicks every button**, and sends every
  notification type to the real client UI, checking for crashes.

Run it again after you change anything.

## Known limitations
- **Nobody has seen it in Roblox yet.** The tests prove the code runs and the
  rules work. They can't show what it looks like, so check colors, sizes and
  layout in Studio, especially on a phone (Studio's device emulator).
- **The anti-cheat is solid but not perfect.** It stops speed, fly and
  teleport hacks. Small cheats that stay just under the limits (slightly
  faster walking, noclipping through a wall) can still slip through. No
  Roblox anti-cheat is perfect, so keep an eye on the Output window for
  `[Salvage AntiCheat]` lines in live servers.
- **Animations are done in code, not with uploaded animations.** They look
  decent but not as smooth as hand-made ones. The arm swing might go the
  wrong way on some character types: flip the angles in `swingArm` if it
  looks backwards. Weapon grip angles may also need adjusting (`tool.Grip`).
- **Balance is a first pass.** Enemy health and damage, weapon damage and
  season XP all need real playtesting. Rebirth pacing was simulated.
- **Sounds are placeholders.** They use sounds built into Roblox (a sword
  slash and a ping). Upload your own for a polished feel.
- **Trade and purchase saving needs session locking** before a big public
  launch.
- **Leaderboards and saving only work in a published game** with API access
  turned on. In plain Studio the boards say so.
