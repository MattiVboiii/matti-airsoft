-- config.lua
Config = {}

Config.Debug = true -- Toggle debug mode for the PolyZone

-- Location where the player will be teleported
Config.TeleportLocation = vector3(-208.99, -1017.44, 30.14)

-- PolyZone configuration
Config.AirsoftZone = {
    -- Coordinates for the PolyZone
    coordinates = {
        vector2(-2264.09, 361.74),
        vector2(-2264.09, 371.74),
        vector2(-2254.09, 371.74),
        vector2(-2254.09, 361.74)
    },
    minZ = 187.6, -- Minimum Z level for the zone
    maxZ = 189.6 -- Maximum Z level for the zone
}

-- Configurable qb-target location for teleporting
Config.TargetLocation = {
    coords = vector3(-2267.64, 376.02, 188.6), -- Position of the target
    size = vector3(1, 1, 1), -- Size of the target zone
    minZ = 187.6, -- Minimum Z level for the target zone
    maxZ = 189.6  -- Maximum Z level for the target zone
}

-- Configurable spawn locations within the airsoft zone
Config.SpawnLocations = {
    vector3(-2263.31, 370.97, 188.6),
    vector3(-2259.91, 368.66, 188.6),
    vector3(-2257.9, 369.49, 188.6),
    vector3(-2259.15, 366.35, 188.6)
}

-- Define loadouts with weapons, ammo, and their labels
Config.Loadouts = {
    {
        name = "Loadout 1",
        weapons = {
            { name = "weapon_airsoftglock20", label = "Pistol" },
            -- { name = "weapon_smg", label = "Submachine Gun" }
        },
        ammo = {
            { name = "pistol_ammo", amount = 10 },
            -- { name = "smg_ammo", amount = 100 }
        }
    },
    {
        name = "Loadout 2",
        weapons = {
            { name = "weapon_airsoftm4", label = "Assault Rifle" },
            -- { name = "weapon_shotgun", label = "Shotgun" }
        },
        ammo = {
            { name = "rifle_ammo", amount = 10 },
            -- { name = "shotgun_ammo", amount = 30 }
        }
    },
    {
        name = "Loadout 3",
        weapons = {
            { name = "weapon_airsoftr870", label = "Shotgun" },
            -- { name = "weapon_shotgun", label = "Shotgun" }
        },
        ammo = {
            { name = "shotgun_ammo", amount = 10 },
            -- { name = "shotgun_ammo", amount = 30 }
        }
    }
}