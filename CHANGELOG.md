# Changelog

## [2.0.2] - 2026-03-29

> **Full diff**: [`2.0.1...2.0.2`](https://github.com/MattiVboiii/matti-airsoft/compare/2.0.1...2.0.2)

### ✨ New Features

- **Deathmatch mode** (`Config.GameModes`) — players respawn in the arena after being hit. Supports both team-based and free-for-all play; the lobby owner can toggle the mode from the UI; the leaderboard displays final scores when exiting the arena; ammo is replenished on each respawn.
- **Arena inventory restrictions** — items can no longer be manipulated by players while inside the arena, complementing the existing whitelist/save-restore system.

### 🔧 Improvements

- Refactored arena zone checks and zone handling to use a new zone library integration.
- Shared utility functions extracted into a new `shared/utils.lua` (`SharedUtils`) module for item-name normalisation and validation; all `server/` and `client/` scripts updated to use `SharedUtils`.
- Leaderboard translations moved to a dedicated function in `client/init.lua` for cleaner NUI messaging.
- `GetCurrentAmmoCount` added in `client/loadout.lua` to centralise ammo checks across loadout handling.
- `Menu.ShowSingleInput` added in `client/menu.lua` for consistent single-input dialogs.
- `ValidateItemRequest` added to `server/callbacks.lua` to enforce stricter server-side item-request validation.
- `EnsureTeamScores` added to `server/lobby.lua` for consistent team-score initialisation.
- `SendLeaderboardVisibility` function introduced in `client/leaderboard.lua`; `Show`/`Hide` functions updated to use it.
- Player teleportation now validates spawn locations before teleporting to prevent edge-case errors.
- Inventory system configuration updated and arena inventory commands refined.
- HTML updated with `aria-live` attributes on dynamic elements for accessibility; CSS improved for scrollbar visibility and HUD styling.
- Match time expiration locale messages updated for clarity in English and Dutch (`locales/en.lua`, `locales/nl.lua`).

### 📄 Documentation

- Revised README installation steps for improved clarity and formatting.

---

## [2.0.1] - 2026-03-25

> **Full diff**: [`2.0.0...2.0.1`](https://github.com/MattiVboiii/matti-airsoft/compare/2.0.0...2.0.1)

Security & inventory patch — server-side saved inventories with full slot/metadata restore, arena item whitelist (`Config.ArenaItemWhitelist`), configurable killer fallback distance (`Config.KillerFallbackDistance`), server-side input validation on lobby events, stricter `giveItem`/`removeItem` guards, and deduplication of arena item-removal notifications. Added `CHANGELOG.md`.

---

## [2.0.0] - 2026-03-21

> **Full diff**: [`1.1.1...2.0.0`](https://github.com/MattiVboiii/matti-airsoft/compare/1.1.1...2.0.0)

Major release — complete modular rewrite with leaderboard, team support, lobby system, loadout menu & pricing, match timer, arena inventory lock, and version checker. `client.lua` / `server.lua` replaced by `client/` and `server/` module directories. New `Config` keys added. See [GitHub Releases](https://github.com/MattiVboiii/matti-airsoft/releases/tag/2.0.0) for full details.

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
