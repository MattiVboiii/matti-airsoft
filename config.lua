Config = {}

Config.Framework = "qbx" -- Options: 'qb', 'ox' or 'qbx'
Config.Debug = false -- Enable/disable debug prints & spawn peds
Config.TargetSystem = "ox_target" -- Options: 'qb-target' or 'ox_target'
Config.MenuSystem = "ox_lib" -- Options: 'qb-menu' or 'ox_lib'
Config.NotifySystem = "ox_lib" -- Options: 'qb-core' or 'ox_lib'
Config.InventorySystem = "ox_inventory" -- Options: 'qb-inventory' or 'ox_inventory'
Config.EnforceArenaLoadoutItemsOnly = true -- Strip non-loadout items while in the arena
Config.ArenaItemLockIntervalMs = 1500 -- How often to scan inventory (ms). Don't set too low.
Config.ArenaItemWhitelist = { -- Items never removed when entering the arena
	-- 'water',
}

-- Leaderboard
Config.LeaderboardEnabled = true
Config.LeaderboardAccentColor = "#EC213A"
Config.ShowFinalScoreboardOnExit = true

-- Match timer
Config.MatchTimerEnabled = true
Config.MaxMatchDurationMinutes = 10
Config.DefaultMatchDurationMinutes = 5

-- Lobby
Config.DefaultGameMode = "ffa"
Config.MaxLobbyPlayers = 16
Config.DeathmatchEnabledByDefault = true -- When enabled, hit players respawn in the arena

Config.GameModes = {
	{
		id = "ffa",
		label = "menu.ffa",
		description = "menu.ffa_desc",
		icon = "fas fa-user",
		iconColor = "#f39c12",
		teamBased = false,
	},
	{
		id = "teams",
		label = "menu.teams",
		description = "menu.teams_desc",
		icon = "fas fa-users",
		iconColor = "#9b59b6",
		teamBased = true,
	},
}

-- Arena zone
Config.ZoneType = "circle" -- Options: 'circle' or 'poly'
Config.AirsoftZone = {
	coordinates = vector3(2025.99, 2784.98, 50),
	radius = 58.5,
	thickness = 50,
	points = {
		vector3(2020.0, 2780.0, 50.0),
		vector3(2030.0, 2780.0, 50.0),
		vector3(2030.0, 2790.0, 50.0),
		vector3(2020.0, 2790.0, 50.0),
	},
}

Config.EnterLocation = {
	coords = vector4(2024.5, 2844.17, 50.28, 0),
	model = "s_m_y_marine_01",
}

Config.ExitLocation = {
	coords = vector4(2024.67, 2841.7, 50.31, 180),
	model = "a_m_y_hipster_01",
}

Config.SpawnLocations = {
	vector3(2025.83, 2751.73, 50.29),
	vector3(1994.17, 2745.99, 49.67),
	vector3(2006.41, 2823.64, 50.28),
	vector3(2042.01, 2827.47, 50.44),
	vector3(2066.32, 2762.93, 50.31),
}

Config.ReturnLocation = vector3(2024.36, 2846.33, 50.26)

-- Gameplay
Config.TeleportOnHit = true
Config.RefillLoadoutAmmoOnRespawn = true

-- Map blip
Config.AirsoftBlip = {
	enabled = true,
	coords = vector3(2025.99, 2784.98, 76.39),
	sprite = 432,
	color = 1,
	scale = 0.8,
	name = "Airsoft Arena",
}

-- Loadouts (weapons here are also used for kill tracking)
Config.Loadouts = {
	{
		name = "Loadout 1",
		weapons = {
			{ name = "weapon_pistol", label = "Pistol" },
		},
		ammo = {
			{ name = "pistol_ammo", amount = 10 },
		},
		price = 100,
	},
	{
		name = "Loadout 2",
		weapons = {
			{ name = "weapon_airsoftm4", label = "Assault Rifle" },
		},
		ammo = {
			{ name = "rifle_ammo", amount = 10 },
		},
		price = 100,
	},
	{
		name = "Loadout 3",
		weapons = {
			{ name = "weapon_airsoftr870", label = "Shotgun" },
		},
		ammo = {
			{ name = "shotgun_ammo", amount = 10 },
		},
		price = 100,
	},
	{
		name = "Loadout 4 (OX)",
		weapons = {
			{ name = "weapon_airsoftglock20", label = "Pistol" },
		},
		ammo = {
			{ name = "ammo-airsoft", amount = 100 },
		},
		price = 100,
	},
}
