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