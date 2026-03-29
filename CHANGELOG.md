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

### 🐛 Bug Fixes

- Fixed `fxmanifest.lua` version number that had been incorrectly bumped to `2.0.3`; reverted to `2.0.2`.

---

## [2.0.1] - 2026-03-25

> **Full diff**: [`2.0.0...2.0.1`](https://github.com/MattiVboiii/matti-airsoft/compare/2.0.0...2.0.1)

### ✨ New Features

- **Saved inventories** — players' original items (name, amount, slot, metadata) are now saved server-side and fully restored after leaving the arena, replacing the old restore-credits system.
- **Arena item whitelist** (`Config.ArenaItemWhitelist`) — items added to this list are never removed when a player enters or plays in the arena.
- **Configurable killer fallback distance** (`Config.KillerFallbackDistance`, default `60.0`) — replaces the hardcoded 25-unit radius used when direct kill attribution fails.

### 🔧 Improvements

- Inventory slot and metadata are now preserved when saving and restoring a player's inventory, so items return to their original slots with their original data intact.
- Removal notifications are now deduplicated: each disallowed item triggers at most one notification per arena session instead of one per lock interval tick.
- `matti-airsoft:setLobbyLoadout` now resolves the loadout from the server-side `Config.Loadouts` by name; the client-supplied loadout object is no longer trusted directly.
- `Utils.HandlePlayerItem` forwards slot and metadata to both `ox_inventory` and `qb-inventory` calls.

### 🔒 Security & Validation

- Added server-side input validation to lobby events (`createLobby`, `joinLobby`, `setGameMode`, `setLobbyLoadout`): lobby names are capped at 50 characters, lobby IDs are coerced to numbers, and game-mode values must be strings.
- `matti-airsoft:giveItem` and `matti-airsoft:removeItem` now enforce stricter guards (amount bounds, type checks, loadout-grant verification) to prevent client-side exploitation.
- Player disconnect cleanup extended to `loadoutGrantState`, `savedInventories`, and `pendingArenaStatusChecks`.

### 📄 Documentation

- Added `CHANGELOG.md` documenting all changes from `1.1.1` through `2.0.0`.

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
