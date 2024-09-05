-- config.lua
Config = {}

Config.Debug = true -- Toggle debug mode for the CircleZone, prints & debug peds

-- Location where the player will be teleported
Config.TeleportLocation = vector3(2024.36, 2846.33, 50.26)

-- CircleZone configuration
Config.AirsoftZone = {
    coordinates = vector3(2025.99, 2784.98, 76.39),
    radius = 58,
}

Config.EnterLocation = {
    coords = vector4(2024.5, 2844.17, 50.28, 0), -- Position of the enter ped
    model = 's_m_y_marine_01', -- Ped model
}

Config.ExitLocation = {
    coords = vector4(2024.67, 2841.7, 50.31, 180), -- Position of the exit ped
    model = "a_m_y_hipster_01", -- Ped model
}

-- Configurable spawn locations within the airsoft zone
Config.SpawnLocations = {
    vector3(2025.83, 2751.73, 50.29),
    vector3(1994.17, 2745.99, 49.67),
    vector3(2006.41, 2823.64, 50.28),
    vector3(2042.01, 2827.47, 50.44),
    vector3(2066.32, 2762.93, 50.31)
}

-- Blip configuration for the airsoft zone
Config.AirsoftBlip = {
    enabled = true, -- Toggle to enable or disable the blip
    coords = vector3(2025.99, 2784.98, 76.39), -- Coordinates for the blip
    sprite = 432, -- Blip sprite/icon
    color = 1, -- Blip color
    scale = 0.8, -- Blip scale
    name = "Airsoft Arena" -- Blip name
}

-- Define loadouts with weapons, ammo, and their labels
Config.Loadouts = {
    {
        name = "1️⃣ Loadout 1",
        weapons = {
            { name = "weapon_airsoftglock20", label = "Pistol" },
        },
        ammo = {
            { name = "pistol_ammo", amount = 10 },
        }
    },
    {
        name = "2️⃣ Loadout 2",
        weapons = {
            { name = "weapon_airsoftm4", label = "Assault Rifle" },
        },
        ammo = {
            { name = "rifle_ammo", amount = 10 },
        }
    },
    {
        name = "3️⃣ Loadout 3",
        weapons = {
            { name = "weapon_airsoftr870", label = "Shotgun" },
        },
        ammo = {
            { name = "shotgun_ammo", amount = 10 },
        }
    }
}
