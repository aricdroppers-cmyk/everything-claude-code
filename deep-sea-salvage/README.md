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

### Quests
- **QUESTS** has 3 daily quests (new at midnight UTC) and 2 weekly quests (new
  on Monday).
- Rewards are coins (multiplied by your level), Pearls and **season XP**.

### Rebirth
- **REBIRTH** is unlocked at Level 25 with 250K coins. Each later rebirth needs
  10 more levels and 3x the coins. There are 10 rebirths in total.
- **You lose:** level, coins, subs and shop weapons.
- **You keep:** ships, fragments, pets, eggs, Pearls, season progress, season
  weapons, game passes and boosts.
- **Each rebirth gives, forever:** +50% coins, +25% XP, +5% luck, +15% damage
  and +100 health.

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
| Premium Season Pass | Developer product | 400 R$ |
| Mystic Season Pass | Developer product | 1000 R$ |

The season passes are **developer products**, not game passes, because game
passes last forever and a season pass has to be sold again each season.

### Making purchases real
1. In the **Creator Dashboard**, open your experience, then
   **Monetization > Passes**. Create the 5 passes.
2. Under **Monetization > Developer Products**, create the 5 products (3 boosts
   and 2 season passes).
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
| First rebirth possible | ~2.2 hours |
| Secret ship (The Hollow Tide) | ~2 hours |

**Season pass pace (estimate, not simulated):** an active player earns roughly
1,000-2,000 season XP an hour, plus about 1,200 a day from daily quests. That
works out to about 15-25 hours for the full pass, and 50+ hours for both
prestiges. Tune `Config.Season.xpPerTier` once you see real numbers.

## Known limitations
- **Not yet tested in Roblox Studio.** All 5 scripts compile with the official
  Luau compiler and pass its analyzer. The server was also run against a fake
  Roblox setup with real 3D math, and passed 117 automated checks covering:
  - dives, levels, hatching and trading
  - season rewards, the retroactive pass purchase, prestige scaling and quests
  - rebirth, boosts, game passes and receipt handling (a purchase is never
    granted twice)
  - portals, enemy spawning and AI, weapon hits, kills and the Leviathan timer

  The visuals and UI layout haven't been seen in-engine yet.
- **Combat is simple.** There are no animations: creatures glide toward you and
  a slash flashes when you swing. Weapon grip angles may need adjusting
  (`tool.Grip` in the server script).
- **Balance is a first pass.** Enemy health and damage, weapon damage and
  season XP all need real playtesting.
- **Upgrading from Premium to Mystic costs the full 1000 R$.** A cheaper
  "Premium to Mystic" upgrade product (around 600 R$) would be fairer. It's
  easy to add.
- **Trade and purchase safety is basic.** Saves happen right away, but there's
  no session locking. A public release should add it.
- No sounds (asset IDs couldn't be checked).
