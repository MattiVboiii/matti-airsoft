# Changelog

## [2.0.3] - 2026-08-30

> **Full diff**: [`2.0.2...2.0.3`](https://github.com/MattiVboiii/matti-airsoft/compare/2.0.2...2.0.3)

### ✨ New Features

- **Mode registry** (`server/modes/`) — FFA, Teams, and Gun Game each own their own scoring and win logic.
- **Score limit** — host can set kills-to-win in the lobby menu (default `Config.DefaultScoreLimit`; `0` = timer only). Match ends as soon as the target is reached.
- **Gun Game** — weapon progression is derived from `Config.Loadouts` (no second weapon list). Leaderboard shows the current tier; final-tier kill wins the match.
- **Last Man Standing** — host toggle for every mode (one life → spectator). Not a separate game mode.
- **Eliminated spectator** — stay visible in the arena, cannot shoot or take damage, free-fly cam inside zone bounds, press **E** to leave early.
- **Spawn protection** — brief invulnerability after spawn/respawn (`Config.SpawnProtectionSeconds`).
- **Live arena board** — read-only top-3 panel for players near the enter ped.
- **Match recap** — final scoreboard shows win reason, MVP, and best kill streak.
- **Career stats** — “My Stats” in the lobby browser using the existing DB stats callback.
- **Match isolation** — visible-but-non-interactive arena players via `airsoftInMatch` state bags (`server/match.lua`, `client/interaction.lua`) instead of routing buckets; persistent career stats in DB (`server/stats.lua`).
- Exports `IsPlayerInArena`, `GetActiveLobby`, and `GetActiveLobbyId`.

### 🔧 Improvements

- Match timer and score limit defaults are config-only; the host can change both in-game (noted in `config.lua`).
- Removed `Config.TeleportOnHit`, `Config.DeathmatchEnabledByDefault`, and LMS as a game mode. Hits either teleport-respawn or enter spectator based on the LMS toggle.
- Framework support for **QBCore**, **Qbox**, and **ox_core**: ox_lib callbacks, native player/money/revive APIs, locale no longer depends on `qb-core`.
- Arena inventory is stashed server-side in one pass (and returned on exit, leave, or disconnect) instead of per-item client events that could permanently wipe bags a few seconds after entering.
- Players are revived when a match ends or they leave the arena (including last-stand / dead states).
- Spectators are blocked from combat.
- Kill tracking is derived from loadout weapons via `SharedUtils.GetLoadoutWeaponNames()`.
- Config cleaned up (debug off by default, lobby/timer defaults). Combat, leaderboard, inventory, and zone handling hardened.

### 📄 Documentation

- Config comments for timer/score-limit defaults and in-game host overrides.
- README updated for v2.0.x features, config, and framework support ([#5](https://github.com/MattiVboiii/matti-airsoft/pull/5), [#6](https://github.com/MattiVboiii/matti-airsoft/pull/6)).

---

## [2.0.2] - 2026-03-29

> **Full diff**: [`2.0.1...2.0.2`](https://github.com/MattiVboiii/matti-airsoft/compare/2.0.1...2.0.2)

Deathmatch and inventory-lock release — hit players can respawn in-arena (lobby host toggle, FFA and teams); arena inventory can no longer be opened or manipulated while inside. Zone checks moved onto the zone library; shared helpers extracted to `shared/utils.lua`; leaderboard, loadout, menu, and item-request validation cleaned up. README installation steps revised.

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

Patch — framework compatibility and readability refactor.

---

## [1.1.0] - 2024-11-13

> **Full diff**: [`1.0.6...1.1.0`](https://github.com/MattiVboiii/matti-airsoft/compare/1.0.6...1.1.0)

Inventory and tooling update — `ox_inventory` support, version check moved to `ox_lib`, own-loadout option commented out to reduce exploits, refactoring and extra code comments. Tested on Qbox and recent QBCore.

---

## [1.0.6] - 2024-09-16

> **Full diff**: [`1.0.5...1.0.6`](https://github.com/MattiVboiii/matti-airsoft/compare/1.0.5...1.0.6)

Revive after death, teleport-on-hit config, anti-cheat hardening, and gun install instructions in the README.

---

## [1.0.5] - 2024-09-14

> **Full diff**: [`1.0.4...1.0.5`](https://github.com/MattiVboiii/matti-airsoft/compare/1.0.4...1.0.5)

Configurable `ox_lib` notification support.

---

## [1.0.4] - 2024-09-13

> **Full diff**: [`1.0.3...1.0.4`](https://github.com/MattiVboiii/matti-airsoft/compare/1.0.3...1.0.4)

Configurable `ox_lib` menu support.

---

## [1.0.3] - 2024-09-13

> **Full diff**: [`1.0.2...1.0.3`](https://github.com/MattiVboiii/matti-airsoft/compare/1.0.2...1.0.3)

Configurable `ox_target` support.

---

## [1.0.2] - 2024-09-12

> **Full diff**: [`1.0.0...1.0.2`](https://github.com/MattiVboiii/matti-airsoft/compare/1.0.0...1.0.2)

Loadout prices, `/exitarena`, arena status, version checker, locales, and version-checker fix.

---

## [1.0.0] - 2024-09-11

> **Full changelog**: [commits](https://github.com/MattiVboiii/matti-airsoft/commits/1.0.0)

Initial release — loadouts, peds, circle/poly zones, inventory save, target/menu, teleports, and spawn points.
