# matti-airsoft
WELCOME! To my first ever script!

Simple & basic airsoft script made for QBCore

## Features
- 🧍 Peds for Entry/Exit & Debug
- 🎯 qb-target/ox_target & qb-menu/ox_lib support
- 🔔 qb-core/ox_lib notification system
- 🚩 Polyzone/circlezone
- ♻️ Configurable
- 🔫 Priced Loadouts (config, random or your own)
- 🪄 Random spawnlocations
- 💬 Locales

## Preview
Loadouts:

![image](https://github.com/user-attachments/assets/6c69564e-46a1-4adf-9f9b-185a3c610374)
![image](https://github.com/user-attachments/assets/52f2d3a1-1ece-49a8-9b3b-a2d61a442cdf)

Configurable Entry/Exit ped:

![image](https://github.com/user-attachments/assets/8f1cd476-3149-4f3a-b099-395d62fb36d3)
![image](https://github.com/user-attachments/assets/dc8d958d-36e1-4a56-8bcc-d58719db2197)

Arena status notifs:

![image](https://github.com/user-attachments/assets/07c4bf14-e37c-406c-bbc2-9768fe809520)
![image](https://github.com/user-attachments/assets/c47c5ed3-094d-4a82-af9e-9bd5c6e1ca57)
![image](https://github.com/user-attachments/assets/1734da67-f623-426f-b106-9cd3a5d32e28)

Debug prints:

![image](https://github.com/user-attachments/assets/f503072d-90c2-4bd9-ab14-8920d22c6b76)

Debug peds (to show spawn locations):

![image](https://github.com/user-attachments/assets/e53f8654-b817-496c-bfb9-f66ea64a2505)

VIDEO PREVIEW COMING SOON

## Optional map
I personally use iakkoise's [Softair Map](https://www.gta5-mods.com/maps/ymap-softair-sp-fivem-alt-v) because it's lightweight and only uses GTA props

## Optional guns
I personally use Localspetsnaz's [Airsoft Guns Pack](https://forum.cfx.re/t/free-standalone-add-on-standalone-add-on-airsoft-guns/5026328) because they don't kill/hurt the player, they stun them.

### How to install the optional guns?
<details>
<summary>Click here to find out!</summary>
  <blockquote>
  1. Insert your custom guns in your server's resources and make they start in your <code>server.cfg</code><br>
  2. In <code>qb-core/shared/items.lua</code> add this:
  <pre>weapon_airsoftglock20        = { name = 'weapon_airsoftglock20', label = 'Airsoft Glock 20', weight = 1000, type = 'weapon', ammotype = 'AMMO_PISTOL', image = 'weapon_pistol.png', unique = true, useable = false, description = 'Airsoft Glock 20' },</pre>
  (do this with every custom gun and change some values)
  <br><br>
  3. In <code>qb-core/shared/weapons.lua</code> add this:
  <pre>[`weapon_airsoftglock20`]        = { name = 'weapon_airsoftglock20', label = 'Airsoft Glock 20', weapontype = 'Pistol', ammotype = 'AMMO_PISTOL', damagereason = 'Hit by a BB' },</pre>
  (do this with every custom gun and change some values)
  <br><br>
  4. In <code>qb-weapons/config.lua</code> add this in <code>Config.DurabiltyMultiplier</code>
  <pre>weapon_airsoftglock20        = 0.05,</pre>
  (do this with every custom gun and change some values)
  <br><br>
  5. In <code>qb-weapons/client/weapdraw.lua</code> add this
  <pre>'WEAPON_AIRSOFTGLOCK20',</pre>
  (do this with every custom gun and change some values)
</blockquote>
</details>

But if you decide not to use these guns, then the script is made so if the player is dead, they will also get teleported out of the arena.

## Optional TIP
If using [ps-dispatch](https://github.com/Project-Sloth/ps-dispatch), remember to add a `NoDispatchZones` location like:
``` lua
[3] = {label = "Airsoft Arena", coords = vector3(2025.99, 2784.98, 76.39), length = 14.0, width = 5.0, heading = 270, minZ = 28.62, maxZ = 32.62},
```
This way, police won't be notified of any shots in the arena

## Future Plans
- Adding a "who killed who" system
- Adding a leaderboard
- More gamemodes
- Finding a way to revive the player after being killed in the arena
- Adding an ox_lib notify system
- Adding ox_inventory support

## Dependencies
- [PolyZone](https://github.com/mkafrin/PolyZone)
