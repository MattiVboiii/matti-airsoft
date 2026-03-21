# Changelog

## [2.0.0] - 2026-03-21

> **Full diff**: [`1.1.1...2.0.0`](https://github.com/MattiVboiii/matti-airsoft/compare/1.1.1...2.0.0)

### 💥 Breaking Changes

- `client.lua` and `server.lua` have been **removed** and replaced by a fully modular file structure under `client/` and `server/`. Update your `fxmanifest.lua` (already done) and remove any direct references to the old single-file setup.

---

### ✨ New Features

#### Leaderboard & Kill Feed
- Added an interactive **kill leaderboard** UI (HTML/CSS/JS) tracking kills, deaths, and K/D ratio per player.
- Leaderboard can be toggled in-game via a configurable key (`Config.LeaderboardKey`, default `F5`).
- Accent colour is fully configurable (`Config.LeaderboardAccentColor`).
- Kill feed broadcasts hits to all players in the arena in real time.

#### Team Support
- Players can now choose a **team** when joining a lobby.
- The leaderboard displays team badges and highlights rows per team.
- Team scores are tracked and broadcast alongside individual stats.
- Game modes can require or restrict team play.

#### Lobby System
- New **multi-player lobby** system: players can create or join a named lobby before entering the arena.
- Lobby management is handled server-side (`server/lobby.lua`).
- Supports game mode selection (e.g. team vs. free-for-all) directly from the lobby menu.

#### Loadout Menu & Pricing
- A new **loadout selection menu** is presented to players on entry, powered by `ox_lib` or `qb-menu`.
- Each loadout now has a configurable **price** checked against the player's inventory/balance before purchase.
- A "random loadout" option is available from the menu.

#### Match Timer
- Optional **match timer** (`Config.MatchTimerEnabled`) automatically ends a match after `Config.MaxMatchDurationMinutes` minutes.

#### Arena Inventory Lock
- `Config.EnforceArenaLoadoutItemsOnly` — when `true`, only items defined in `Config.Loadouts` are permitted while a player is inside the arena.
- Lock interval is configurable via `Config.ArenaItemLockIntervalMs`.

#### Version Checker
- Integrated **remote version check** on resource start using `ox_lib`, alerting server owners when an update is available.

---

### 🏗️ Code Restructuring

The codebase was split from two monolithic files into purpose-focused modules:

| New file | Responsibility |
|---|---|
| `client/init.lua` | Bootstraps client-side logic, handles disconnects |
| `client/combat.lua` | Hit detection, death handling, respawn logic |
| `client/events.lua` | Client-side event listeners |
| `client/inventory.lua` | Arena item enforcement |
| `client/leaderboard.lua` | NUI leaderboard open/close |
| `client/loadout.lua` | Weapon/ammo grant & removal |
| `client/menu.lua` | Loadout selection menu |
| `client/player_entities.lua` | Spawn-point selection, ped management |
| `client/shared.lua` | Shared client state (in-arena flag, etc.) |
| `client/zone.lua` | Arena zone entry/exit detection |
| `server/init.lua` | Match timer, disconnect cleanup |
| `server/callbacks.lua` | Loadout affordability checks |
| `server/commands.lua` | Admin/debug commands |
| `server/events.lua` | Server-side event handlers |
| `server/leaderboard.lua` | Stat tracking, leaderboard broadcasting |
| `server/lobby.lua` | Lobby creation, joining, game-mode logic |
| `server/shared.lua` | Shared server state & utility functions |

---

### 🔧 Configuration Changes (`config.lua`)

New keys added (all have sensible defaults):

| Key | Default | Description |
|---|---|---|
| `Config.EnforceArenaLoadoutItemsOnly` | `true` | Lock inventory to loadout items while in arena |
| `Config.ArenaItemLockIntervalMs` | `1500` | Interval (ms) for the item lock check |
| `Config.LeaderboardEnabled` | `true` | Toggle leaderboard feature |
| `Config.LeaderboardKey` | `166` (F5) | Key to open/close leaderboard |
| `Config.LeaderboardAccentColor` | `'#EC213A'` | Hex accent colour for leaderboard UI |
| `Config.MatchTimerEnabled` | `true` | Toggle match timer |
| `Config.MaxMatchDurationMinutes` | `10` | Auto-end match after N minutes |
| `Config.ContinuePlayingAfterDeath` | `true` | Respawn in arena instead of ejecting on death |
| `Config.MenuSystem` | `'ox_lib'` | Menu backend (`'qb-menu'` or `'ox_lib'`) |

Each `Config.Loadouts` entry now accepts a `price` field (integer, in whatever currency your framework uses).

---

### 🌐 UI (HTML / CSS / JS)

- New `html/index.html`, `html/style.css`, `html/script.js` implementing the leaderboard NUI.
- Team badges with colour-coded row highlighting.
- Kill-feed overlay with timed fade-out.

---

### 🌍 Localisation

- `locales/en.lua` and `locales/nl.lua` — added strings for:
  - Lobby management (create, join, leave)
  - Team selection
  - Leaderboard headings (Player, Team, Kills, Deaths, K/D)
  - Match timer notifications
  - Arena item lock warnings

---

### 🐛 Bug Fixes & Refactors

- Simplified and unified debug print statements throughout the codebase.
- Enhanced framework detection to cleanly support `qb`, `qbx`, and `ox`.
- `Data` and `Utils` tables introduced server-side for cleaner state management.
- Grace period added for kill credit: recent hits within a short window are attributed correctly even if a third party deals the final blow.
- Removed redundant comments and consolidated duplicate logic.

---

## [1.1.1] - 2025-04-03

> **Full diff**: [`1.1.0...1.1.1`](https://github.com/MattiVboiii/matti-airsoft/compare/1.1.0...1.1.1)

Minor patch release — see GitHub for details.

---

## [1.1.0] - 2024-11-13

- Added `ox_inventory` support.
- Lots of refactoring.
- Changed version check to `ox_lib`.
- Tested on both QBOX & (recent) QBCore.
- Added code comments.

---

## [1.0.6] - 2024-09-16 — [1.0.0] - 2024-09-11

Earlier patch and initial releases. See [GitHub Releases](https://github.com/MattiVboiii/matti-airsoft/releases) for details.
