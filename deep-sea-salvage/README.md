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
- Duplicate fragments are sold for coins automatically.
- **MY BAY** teleports you home.

### Events (every 4 minutes, each lasts 90 seconds)
| Event | What happens |
|---|---|
| Storm Surge | Sky goes dark with lightning. Every haul has 2 fragments, but breach risk goes up 8%. |
| Treasure Tide | 12 golden chests float around the island. Swim out and open them for Pearls and coins. |
| Kraken Attack | Tentacles rise around the island. Everyone clicks them to drive it off. Players who helped get Pearls and coins. |

## Tuning
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
  Luau compiler and pass its analyzer, but nobody has played them in-engine.
  If something breaks, the **Output** window (View > Output) shows the error
  and its line number.
- **No sounds.** Asset IDs couldn't be checked, so none are included.
- **Simple visuals.** Everything is built from basic parts. It looks good for a
  prototype, but a real release would want proper meshes.
- **Not much content yet.** There are 8 ships, about 2 hours of play. A
  released game needs a lot more.
- No trading, gamepasses or leaderboards yet.
