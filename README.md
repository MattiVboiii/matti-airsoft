# 🔫 matti-airsoft - Ultimate Airsoft Arena for QBCore / QBox / OXCore

Welcome to the most thrilling airsoft experience for your FiveM server! This script brings competitive, safe airsoft battles to your players with complete customization options.

## 🎯 Key Features

### Core Gameplay

- **Realistic Loadouts**: Choose from pre-configured weapon sets with configurable pricing
- **Dynamic Arenas**: Random spawn locations keep matches fresh and unpredictable
- **Safety First**: Automatic ejection when players are "downed"
- **Lobby System**: Players join a shared lobby; the lobby owner can adjust settings before and during matches
- **Game Modes**: Free-for-all (FFA) and team-based deathmatch — lobby owner can toggle the mode from the UI
- **Leaderboard**: Real-time kill tracking with a final scoreboard snapshot on exit (toggle with `Config.LeaderboardKey`)
- **Match Timer**: Configurable time-limited rounds that automatically end the match when the clock runs out
- **Ammo Replenishment**: Optionally replenish missing ammo on each respawn (`Config.RefillLoadoutAmmoOnRespawn`)

### Immersive Elements

- **Interactive Peds**: Entry/Exit NPCs with full customization
- **Visual Feedback**: Clear arena status notifications and killfeed styling
- **Arena Inventory Lock**: Prevent players from bringing or using non-loadout items inside the arena
- **Debug Tools**: Developer-friendly features for testing spawns and zones

### Framework Support

- **Target Systems**: Works with both qb-target and ox_target
- **Inventory Compatible**: Supports qb-inventory and ox_inventory
- **Menu System**: Works with qb-menu and ox_lib
- **Notification Options**: Choose between qb-core or ox_lib styles

## 🎮 Screenshot Gallery

### Loadout Selection

![image](https://github.com/user-attachments/assets/6c69564e-46a1-4adf-9f9b-185a3c610374)
![image](https://github.com/user-attachments/assets/52f2d3a1-1ece-49a8-9b3b-a2d61a442cdf)

### Arena Access

![image](https://github.com/user-attachments/assets/8f1cd476-3149-4f3a-b099-395d62fb36d3)
![image](https://github.com/user-attachments/assets/dc8d958d-36e1-4a56-8bcc-d58719db2197)

### Match Notifications

![image](https://github.com/user-attachments/assets/07c4bf14-e37c-406c-bbc2-9768fe809520)
![image](https://github.com/user-attachments/assets/c47c5ed3-094d-4a82-af9e-9bd5c6e1ca57)
![image](https://github.com/user-attachments/assets/1734da67-f623-426f-b106-9cd3a5d32e28)

### Developer Tools

![image](https://github.com/user-attachments/assets/f503072d-90c2-4bd9-ab14-8920d22c6b76)
![image](https://github.com/user-attachments/assets/e53f8654-b817-496c-bfb9-f66ea64a2505)

_🎥 Video preview coming soon!_

## 🗺️ Recommended Maps

For the best experience, pair this script with [iakkoise's Softair Map](https://www.gta5-mods.com/maps/ymap-softair-sp-fivem-alt-v) - a lightweight, optimized arena using native GTA props.

## 🔫 Weapon Recommendations

(Not using this? Prepare to encounter revive bugs for now)

Enhance realism with [Localspetsnaz's Airsoft Guns Pack](https://forum.cfx.re/t/free-standalone-add-on-standalone-add-on-airsoft-guns/5026328):

- Non-lethal BB pellets that stun instead of kill
- Authentic airsoft weapon models
- Complete setup guide below:

<details>
<summary>📖 Installation Guide</summary>

Add guns to your server resources and start them in `server.cfg`

## QBCore Setup

1. In `qb-core/shared/items.lua`:
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
2. In `qb-core/shared/weapons.lua`:
   ```lua
   [`weapon_airsoftglock20`] = {
     name = 'weapon_airsoftglock20',
     label = 'Airsoft Glock 20',
     weapontype = 'Pistol',
     ammotype = 'AMMO_PISTOL',
     damagereason = 'Hit by a BB'
   },
   ```
3. In `qb-weapons/config.lua` (Durability section):
   ```lua
   weapon_airsoftglock20 = 0.05,
   ```
4. In `qb-weapons/client/weapdraw.lua`:

   ```lua
   'WEAPON_AIRSOFTGLOCK20',
   ```

## Ox_Inventory Setup

1. In `ox_inventory/data/weapons.lua` (Weapons section)
   ```lua
   ['WEAPON_AIRSOFTGLOCK20'] = {
			label = 'Airsoft Glock 20',
			weight = 0,
			durability = 0.1,
			ammoname = 'ammo-airsoft',
   },
   ```

2. OPTIONAL - In `ox_inventory/data/weapons.lua` (Ammo section)
   ```lua
   ['ammo-airsoft'] = {
			label = 'Airsoft bullet',
			weight = 1,
	},
   ```
      </details>

## 🚨 Pro Tip for Police Systems

Using ps-dispatch? Prevent false alerts by adding a NoDispatchZone:

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

## ⚙️ Dependencies

- [ox_lib](https://github.com/overextended/ox_lib) - For version checking & creating zone

## ⚙️ Config Notes

- `Config.Framework` — set to `'qb'` or `'qbx'` to match your server framework.
- `Config.TargetSystem` — `'qb-target'` or `'ox_target'`.
- `Config.MenuSystem` — `'qb-menu'` or `'ox_lib'`.
- `Config.NotifySystem` — `'qb-core'` or `'ox_lib'`.
- `Config.InventorySystem` — `'qb-inventory'` or `'ox_inventory'`.
- `Config.ZoneType` — `'circle'` (radius-based) or `'poly'` (polygon points).
- `Config.GameModes` / `Config.DefaultGameMode` — define available game modes (FFA, teams, etc.) and the default when a lobby is created.
- `Config.DeathmatchEnabledByDefault` — when `true`, hit players respawn in the arena automatically (lobby owner can override).
- `Config.EnforceArenaLoadoutItemsOnly` — when `true`, players can only keep loadout items while inside the arena. Recommended to prevent item smuggling.
- `Config.ArenaItemLockIntervalMs` — interval (ms) between arena inventory enforcement checks. Don't set too low.
- `Config.ArenaItemWhitelist` — items in this list are never removed when entering or playing in the arena.
- `Config.LeaderboardEnabled` / `Config.LeaderboardKey` — toggle the kill leaderboard and set the keybind (default: F5).
- `Config.LeaderboardAccentColor` — hex colour for leaderboard and killfeed accent styling.
- `Config.ShowFinalScoreboardOnExit` — show a final scoreboard snapshot when a player leaves the arena.
- `Config.MatchTimerEnabled` / `Config.MaxMatchDurationMinutes` — enable time-limited rounds and set the maximum duration.
- `Config.RefillLoadoutAmmoOnRespawn` — replenishes only missing ammo up to the selected loadout amounts on each respawn.
- `Config.KillerFallbackDistance` — fallback distance used to resolve the killer if direct attribution fails.
- `Config.MaxItemEventAmount` — server-side hard cap for client-triggered item amount events.
- Internal shared helpers live in `shared/utils.lua` and are loaded via `fxmanifest.lua`.

## ⚠️ Disclaimer(s)

- If you don't follow this README, some things might not work as intended. I will not provide any support for custom modifications, you will have to figure it out yourself.

- If you have any questions about the default setup, feel free to ask. If you encounter any bugs, please report them [here](https://github.com/MattiVboiii/matti-airsoft/issues).

- Will I add support for ESX? No. I have no interest in supporting ESX and will not add compatibility for it. I will only support QBCore, QBox & OXCore (still WIP).

- Although I added that it supports OXCore, I have absolutely no idea if that's true since I have never tried it, but I think it works 75%... So if you encounter any problems on OXCore, please reach out and we will figure out a solution together.

- I currently use QBox for testing and development, I'm mostly too lazy to test on other frameworks. So I'm sorry in advance if there are any issues with other frameworks, but I will try my best to fix them if they come up.

- Tests are done locally on 2 clients, meaning gameplay is only tested for 2 people. If you encounter any bugs/glitches/cheats with more people, let me know ASAP!

- Keep in mind that I made this script for fun and to learn, not to create a perfect product. If you want to contribute or help out, feel free to do so, PR's are always welcome!

- The V2 of this script is considered feature-complete in terms of major overhauls. Future updates will focus on minor features, bug fixes, and performance improvements.
