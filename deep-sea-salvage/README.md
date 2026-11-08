# Deep Sea Salvage (Roblox prototype)

You run a fleet of submarines that dive into the deep and haul up fragments of
sunken ships. Find every fragment of a ship and it's restored, floats at your
bay, and gives you a permanent coin bonus. Better subs reach deeper zones with
rarer loot, but deeper dives have a higher chance of a **hull breach**, which
loses the whole haul.

Everything is built in code from parts, so you don't need to import any models,
meshes or images.

## Setup in Roblox Studio (about 5 minutes)

1. Open Roblox Studio and create a new place from the **Baseplate** template.
   (The server script removes the baseplate and puts an ocean in its place.)
2. **ReplicatedStorage**: right-click, choose *Insert Object* > **ModuleScript**,
   and rename it to exactly `SalvageConfig`. Delete the default text and paste
   in all of `SalvageConfig.lua`.
3. **ServerScriptService**: insert a **Script**, rename it to `SalvageServer`,
   and paste in all of `SalvageServer.server.lua`.
4. **StarterPlayer > StarterPlayerScripts**: insert a **LocalScript**, rename it
   to `SalvageClient`, and paste in all of `SalvageClient.client.lua`.
5. Press **Play**.

### To make saving work
- Publish the place (*File > Publish to Roblox*).
- In *Game Settings > Security*, turn on **Enable Studio Access to API Services**.
- If you skip this, the game still runs but shows "Saving is OFF".

### Server size
There are **6 bays**, one per player. Set the place's max players to **6**
(Game Settings > Places, or the Creator Dashboard). If a 7th player joins,
they're kicked with a message telling them to find another server.

## How to play
- You spawn at your own bay ("YourName's Salvage Co.") with a free **Rowboat Diver**.
- Subs dive on their own. When one surfaces, a glowing **crate** appears on your
  dock. Walk up to it and **hold E** to haul it up. Rarer crates take longer to hold.
- The **FLEET** menu sets each sub's dive depth (1-5). It shows the zone, the
  breach risk, and how many coins each haul pays.
- The **SHOP** sells better subs. Up to 5 subs per player. The Leviathan costs
  **Pearls**, which you only get from events.
- The **LOGBOOK** shows every ship and which fragments you still need.
- Duplicate fragments are **spares**. Auto-sell is on by default, so spares are
  sold for coins straight away. Turn Auto-sell off in the Logbook to keep them
  for trading.
- **MY BAY** teleports you home.

### Levels
- Every haul gives XP. Deeper zones, rarer fragments and new fragments give more.
- Your level shows above your head and in the player list.
- **Trading unlocks at Level 10** (`Config.TradeUnlockLevel`).

### Eggs and pets
- Every haul has a **5% chance** to also bring up the egg of the zone it was in:
  Tide Pool, Kelp, Twilight, Midnight or Abyss. The egg sits on top of the crate.
- Hatch eggs in the **PETS** menu for coins. Deeper eggs cost more and hatch
  better pets: 250 coins for a Tide Pool Egg up to 150,000 for an Abyss Egg.
- Players who hit the Kraken at least 10 times in a fight that's won get a
  **Kraken Egg**, which hatches for 5 Pearls.
- There are 23 pets in 5 rarities (Common to Legendary). Each one boosts
  **coins**, **luck**, **hull** (lower breach chance) or **XP**.
- Equip up to 3 pets. Equipped pets swim along behind you, and other players can
  see them. **Equip Best** picks your strongest 3.
- You can hold up to 40 pets. Releasing a pet gives coins. Release needs two
  taps so you can't do it by accident.

### Trading (Level 10+)
1. Open **TRADE** and press **Request Trade** next to another Level 10+ player.
2. They get a pop-up and press **Accept**.
3. Both of you tap items to add them: spare fragments, unequipped pets and eggs.
   You can't trade the last copy of a fragment you own, or an equipped pet.
4. Both press **READY**, then both press **CONFIRM**. Changing anything resets
   both players' Ready and Confirm, so nobody can swap an item at the last second.
5. The trade completes and both players' data is saved straight away.
   Receiving the last missing fragment restores that ship instantly.

### Events (every 4 minutes, each lasts 90 seconds)
| Event | What happens |
|---|---|
| Storm Surge | Sky goes dark with lightning. Every haul has 2 fragments, but breach risk goes up 8%. |
| Treasure Tide | 12 golden chests float around the island. Swim out and open them for Pearls and coins. |
| Kraken Attack | Tentacles rise around the island. Everyone clicks them to drive it off. Players who helped get Pearls and coins. |

## Tuning

Simulated pacing for levels and eggs: Level 10 in ~21 minutes, Level 20 in
~80 minutes, and about 20 eggs in the first 30 minutes.

All balance numbers are in `SalvageConfig.lua`: prices, drop weights per zone,
breach chances, dive times, event timers, ship bonuses and pity. Adding a ship
means adding one line to `Config.Ships`. It shows up automatically in the
Logbook, the loot table and the bay display.

Pacing with the current numbers, from a simulation of a player who always buys
the best sub and dives as deep as it can (events not included):

| Milestone | Average time |
|---|---|
| Brass Bell | ~4 min |
| Bathysphere | ~22 min |
| Abyss Crawler | ~52 min |
| Crown Galleon (Royal) | ~28 min |
| The Hollow Tide (Secret) | ~2 hours |

## Known limitations
- **Not yet tested in Roblox Studio.** The scripts compile with the official
  Luau compiler and pass its analyzer. The server logic (dive loop, levels,
  hatching, equipping, trading, selling) also passed 56 automated checks
  against a fake Roblox setup. Nobody has played it in-engine yet, though, and
  the visuals and UI layout haven't been seen at all.
  If something breaks, the **Output** window (View > Output) shows the error
  and its line number.
- **No sounds.** Asset IDs couldn't be checked, so none are included.
- **Simple visuals.** Everything is built from basic parts. It looks good for a
  prototype, but a real release would want proper meshes.
- **Not much content yet.** There are 8 ships, about 2 hours of play. A
  released game needs a lot more.
- **Trade safety is basic.** Both players are saved right after a trade, but
  there's no session locking. If a server crashed at exactly the wrong moment,
  an item could be duplicated or lost. That's fine for testing; a public
  release needs session locking.
- Pets follow you but don't animate (no swimming wiggle). They float and bob.
- No gamepasses or leaderboards yet.
