# matti-airsoft — Airsoft Arena for QBCore / Qbox / ox_core

Competitive airsoft matches for FiveM with lobbies, multiple game modes, loadouts, and arena inventory handling.

## Features

### Gameplay

- **Loadouts** — configurable weapon sets with prices; host picks one for the match
- **Game modes** — FFA, Teams, and Gun Game (`Config.GameModes`)
- **Last Man Standing** — host toggle (one life → spectator); when off, hits teleport-respawn
- **Score limit** — kills-to-win (host can change; `0` = timer only)
- **Match timer** — optional time limit; host can override the default in the lobby
- **Spawn protection** — short invulnerability after spawn/respawn
- **Spectator** — eliminated players stay in the arena (free-fly, no combat); press **E** to leave early
- **Leaderboard / match recap** — live board, final scoreboard with MVP and win reason
- **Career stats** — “My Stats” in the lobby browser (DB-backed)
- **Ammo refill** — optional top-up to loadout amounts on respawn

### Arena

- **Random spawns** inside the zone
- **Entry / exit peds** with target interaction
- **Inventory stash** — non-loadout items are stored server-side for the match and returned on exit (not deleted)
- **Match isolation** — other players in the arena who aren’t in your match stay visible but non-interactive (`airsoftInMatch` state bags)
- **Live arena board** — top scores near the enter ped for bystanders

### Framework

- **Frameworks**: `qb`, `qbx`, `ox` (`Config.Framework`)
- **Target**: qb-target / ox_target
- **Inventory**: qb-inventory / ox_inventory
- **Menu / notify**: qb-menu or ox_lib / qb-core or ox_lib

### Exports

```lua
exports['matti-airsoft']:IsPlayerInArena(playerId)
exports['matti-airsoft']:GetActiveLobby()
exports['matti-airsoft']:GetActiveLobbyId()
```

## Screenshots

### Loadout selection

![image](https://github.com/user-attachments/assets/6c69564e-46a1-4adf-9f9b-185a3c610374)
![image](https://github.com/user-attachments/assets/52f2d3a1-1ece-49a8-9b3b-a2d61a442cdf)

### Arena access

![image](https://github.com/user-attachments/assets/8f1cd476-3149-4f3a-b099-395d62fb36d3)
![image](https://github.com/user-attachments/assets/dc8d958d-36e1-4a56-8bcc-d58719db2197)

### Match notifications

![image](https://github.com/user-attachments/assets/07c4bf14-e37c-406c-bbc2-9768fe809520)
![image](https://github.com/user-attachments/assets/c47c5ed3-094d-4a82-af9e-9bd5c6e1ca57)
![image](https://github.com/user-attachments/assets/1734da67-f623-426f-b106-9cd3a5d32e28)

### Developer tools

![image](https://github.com/user-attachments/assets/f503072d-90c2-4bd9-ab14-8920d22c6b76)
![image](https://github.com/user-attachments/assets/e53f8654-b817-496c-bfb9-f66ea64a2505)

## Recommended map

[iakkoise’s Softair Map](https://www.gta5-mods.com/maps/ymap-softair-sp-fivem-alt-v) — lightweight arena using native GTA props.

## Weapons

Use non-lethal airsoft guns when possible (stun instead of kill). Recommended pack: [Localspetsnaz’s Airsoft Guns](https://forum.cfx.re/t/free-standalone-add-on-standalone-add-on-airsoft-guns/5026328).

**Loadout item names must exist in your inventory.** Default config uses `weapon_airsoftm4`, `weapon_airsoftr870`, `weapon_airsoftglock20`, and `ammo-airsoft` — register those in ox_inventory / qb items or change `Config.Loadouts` to items you already have.

<details>
<summary>Installation — airsoft guns</summary>

Add the weapon resources and start them in `server.cfg`.

### QBCore

1. `qb-core/shared/items.lua`:

```lua
weapon_airsoftglock20 = {
  name = 'weapon_airsoftglock20',
  label = 'Airsoft Glock 20',
  weight = 1000,
  type = 'weapon',
  ammotype = 'AMMO_PISTOL',
  image = 'weapon_pistol.png',
  unique = true,
  useable = false,
  description = 'Airsoft Glock 20'
},
```

2. `qb-core/shared/weapons.lua`:

```lua
[`weapon_airsoftglock20`] = {
  name = 'weapon_airsoftglock20',
  label = 'Airsoft Glock 20',
  weapontype = 'Pistol',
  ammotype = 'AMMO_PISTOL',
  damagereason = 'Hit by a BB'
},
```

3. `qb-weapons/config.lua` (durability) and `qb-weapons/client/weapdraw.lua` as needed for each airsoft weapon.

### ox_inventory

In `ox_inventory/data/weapons.lua` **Weapons**:

```lua
['WEAPON_AIRSOFTGLOCK20'] = {
  label = 'Airsoft Glock 20',
  weight = 1000,
  durability = 0.05,
  ammoname = 'ammo-airsoft',
},
['WEAPON_AIRSOFTM4'] = {
  label = 'Airsoft M4',
  weight = 2800,
  durability = 0.05,
  ammoname = 'ammo-airsoft',
},
['WEAPON_AIRSOFTR870'] = {
  label = 'Airsoft Remington 870',
  weight = 3200,
  durability = 0.05,
  ammoname = 'ammo-airsoft',
},
```

In **Ammo**:

```lua
['ammo-airsoft'] = {
  label = 'Airsoft BB',
  weight = 1,
},
```

Restart `ox_inventory` after editing.

</details>

## Dependencies

- [ox_lib](https://github.com/overextended/ox_lib)
- [oxmysql](https://github.com/overextended/oxmysql) (career stats)

Plus your chosen framework / target / inventory resources.

## Config notes

| Option                                                        | Notes                                                    |
| ------------------------------------------------------------- | -------------------------------------------------------- |
| `Config.Framework`                                            | `'qb'`, `'qbx'`, or `'ox'`                               |
| `Config.TargetSystem`                                         | `'qb-target'` or `'ox_target'`                           |
| `Config.MenuSystem`                                           | `'qb-menu'` or `'ox_lib'`                                |
| `Config.NotifySystem`                                         | `'qb-core'` or `'ox_lib'`                                |
| `Config.InventorySystem`                                      | `'qb-inventory'` or `'ox_inventory'`                     |
| `Config.ZoneType`                                             | `'circle'` or `'poly'`                                   |
| `Config.GameModes` / `Config.DefaultGameMode`                 | FFA, teams, gungame                                      |
| `Config.DefaultScoreLimit`                                    | Default kills-to-win; host can change (`0` = timer only) |
| `Config.DefaultMatchDurationMinutes`                          | Default timer; host can change                           |
| `Config.MatchTimerEnabled` / `Config.MaxMatchDurationMinutes` | Timer on/off and max host setting                        |
| `Config.SpawnProtectionSeconds`                               | Invulnerability after spawn (`0` = off)                  |
| `Config.EnforceArenaLoadoutItemsOnly`                         | Stash non-loadout items in-arena (returned on exit)      |
| `Config.ArenaItemLockIntervalMs`                              | How often to re-check arena inventory                    |
| `Config.ArenaItemWhitelist`                                   | Items kept in the bag during a match                     |
| `Config.LeaderboardEnabled` / `Config.LeaderboardAccentColor` | Live board + UI accent                                   |
| `Config.ShowFinalScoreboardOnExit`                            | Final recap when leaving                                 |
| `Config.RefillLoadoutAmmoOnRespawn`                           | Top up ammo to loadout amounts                           |
| `Config.Loadouts`                                             | Weapons + ammo names must match your inventory items     |

Shared helpers: `shared/utils.lua`, `shared/locale.lua`.

## Police / dispatch

Example ps-dispatch no-alert zone:

```lua
[3] = {
  label = "Airsoft Arena",
  coords = vector3(2025.99, 2784.98, 76.39),
  length = 14.0,
  width = 5.0,
  heading = 270,
  minZ = 28.62,
  maxZ = 32.62
},
```

## Disclaimer(s)

- If you don't follow this README, some things might not work as intended. I will not provide any support for custom modifications — you will have to figure those out yourself.

- Questions about the default setup are fine. Bugs for the stock config: please report them [here](https://github.com/MattiVboiii/matti-airsoft/issues).

- Will I add support for ESX? No. I have no interest in supporting ESX and will not add compatibility for it. I only support QBCore, Qbox, and ox_core.

- Although ox_core is listed as supported, I have not heavily tested it myself. If you hit problems on ox_core, reach out and we can work through them.

- I currently use Qbox for testing and development, and I'm often too lazy to re-test every change on other frameworks. Sorry in advance if something breaks elsewhere — I'll try to fix reported issues.

- Tests are mostly done locally on 2 clients. If you find bugs, glitches, or cheat issues with more players, let me know ASAP.

- I made this script for fun and to learn, not as a perfect product. Contributions and PRs are always welcome.

- The V2 of this script is considered feature-complete for major overhauls. Future updates will focus on minor features, bug fixes, and performance improvements.

See [CHANGELOG.md](CHANGELOG.md) for release history.
