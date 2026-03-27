Config = {}

Config.Framework = 'qbx' -- Options: 'qb', 'ox' or 'qbx' 
Config.Debug = true -- Enable/disable debug prints & spawn peds
Config.TargetSystem = 'ox_target' -- Options: 'qb-target' or 'ox_target'
Config.MenuSystem = 'ox_lib' -- Options: 'qb-menu' or 'ox_lib'
Config.NotifySystem = 'ox_lib' -- Options: 'qb-core' or 'ox_lib'
Config.InventorySystem = 'ox_inventory' -- Options: 'qb-inventory' or 'ox_inventory'
Config.EnforceArenaLoadoutItemsOnly = true -- Arena inventory lock: when true, players can only keep items defined in Config.Loadouts while playing in arena. Recommended to prevent players from bringing in other items into the arena.
Config.ArenaItemLockIntervalMs = 1500 -- Don't set this too low to avoid performance issues. 
Config.MaxItemEventAmount = 2000000000 -- Safety cap for client-triggered item amount events.
Config.ArenaItemWhitelist = { -- Items in this list are never removed when entering/playing in the arena
	-- 'water',
}

-- Leaderboard Settings
Config.LeaderboardEnabled = true -- Enable/disable the kill leaderboard
Config.LeaderboardKey = 166 -- F5 key (see https://docs.fivem.net/docs/game-references/controls/ for key codes)
Config.LeaderboardAccentColor = '#EC213A' -- Hex color for leaderboard + killfeed accent styling in NUI
Config.ShowFinalScoreboardOnExit = true -- Show a final scoreboard snapshot when leaving the arena

-- Match Timer Settings
Config.MatchTimerEnabled = true -- Enable/disable the match timer feature
Config.MaxMatchDurationMinutes = 10 -- Maximum duration for a match in minutes

-- Lobby Game Mode Settings
Config.DefaultGameMode = 'ffa' -- Lobby default mode when created
Config.GameModes = {
	{
		id = 'ffa',
		label = 'menu.ffa',
		description = 'menu.ffa_desc',
		icon = 'fas fa-user',
		iconColor = '#f39c12',
		teamBased = false,
	},
	{
		id = 'teams',
		label = 'menu.teams',
		description = 'menu.teams_desc',
		icon = 'fas fa-users',
		iconColor = '#9b59b6',
		teamBased = true,
	},
}
Config.DeathmatchEnabledByDefault = true -- Lobby deathmatch toggle default. When enabled, hit players respawn in arena.

Config.ZoneType = 'circle' -- Options: 'circle' or 'poly'

-- Define the airsoft zone configuration
Config.AirsoftZone = {
	coordinates = vector3(2025.99, 2784.98, 50), -- Center of the circlezone
	radius = 58.5, -- Only used if Config.ZoneType is 'circle'
	thickness = 50, -- Only used if Config.ZoneType is 'poly' (total vertical height of the zone)
	points = { -- Only used if Config.ZoneType is 'poly' (must be vector3)
		vector3(2020.0, 2780.0, 50.0),
		vector3(2030.0, 2780.0, 50.0),
		vector3(2030.0, 2790.0, 50.0),
		vector3(2020.0, 2790.0, 50.0),
	},
}

Config.EnterLocation = {
	coords = vector4(2024.5, 2844.17, 50.28, 0), -- Position of the enter ped
	model = 's_m_y_marine_01', -- Ped model
}

Config.ExitLocation = {
	coords = vector4(2024.67, 2841.7, 50.31, 180), -- Position of the exit ped
	model = 'a_m_y_hipster_01', -- Ped model
}

-- Configurable spawn locations within the airsoft zone
Config.SpawnLocations = {
	vector3(2025.83, 2751.73, 50.29),
	vector3(1994.17, 2745.99, 49.67),
	vector3(2006.41, 2823.64, 50.28),
	vector3(2042.01, 2827.47, 50.44),
	vector3(2066.32, 2762.93, 50.31),
}

-- Location where the player will be teleported if hit/dead
Config.TeleportOnHit = true
Config.ContinuePlayingAfterDeath = true -- Legacy fallback when lobby deathmatch state is unavailable.
Config.RefillLoadoutAmmoOnRespawn = true -- If true, replenishes only missing ammo up to selected loadout amounts when the player is hit/respawns.
Config.KillerFallbackDistance = 60.0 -- Fallback distance used to resolve killer if direct attribution fails
Config.ReturnLocation = vector3(2024.36, 2846.33, 50.26)

-- Blip configuration for the airsoft zone
Config.AirsoftBlip = {
	enabled = true, -- Toggle to enable or disable the blip
	coords = vector3(2025.99, 2784.98, 76.39), -- Coordinates for the blip
	sprite = 432, -- Blip sprite/icon
	color = 1, -- Blip color
	scale = 0.8, -- Blip scale
	name = 'Airsoft Arena', -- Blip name
}

-- Define loadouts with weapons, ammo, and their labels
Config.Loadouts = {
	{
		name = 'Loadout 1',
		weapons = {
			{ name = 'weapon_pistol', label = 'Pistol' },
		},
		ammo = {
			{ name = 'pistol_ammo', amount = 10 },
		},
		price = 100,
	},
	{
		name = 'Loadout 2',
		weapons = {
			{ name = 'weapon_airsoftm4', label = 'Assault Rifle' },
		},
		ammo = {
			{ name = 'rifle_ammo', amount = 10 },
		},
		price = 100,
	},
	{
		name = 'Loadout 3',
		weapons = {
			{ name = 'weapon_airsoftr870', label = 'Shotgun' },
		},
		ammo = {
			{ name = 'shotgun_ammo', amount = 10 },
		},
		price = 100,
	},
	{
		name = 'Loadout 4 (OX)',
		weapons = {
			{ name = 'weapon_airsoftglock20', label = 'Pistol' },
		},
		ammo = {
			{ name = 'ammo-airsoft', amount = 100 },
		},
		price = 100,
	},
}
