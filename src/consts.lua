-- Zen Fortress Constants (LÖVE2D port)
local C = {}

-- Display
C.WIDTH = 1080
C.HEIGHT = 1920
C.CENTER_X = C.WIDTH / 2
C.CENTER_Y = C.HEIGHT / 2

-- Colors {r, g, b}
C.COLOR = {
    BACKGROUND = {0.039, 0.039, 0.059},
    GRID = {0.102, 0.102, 0.180},
    TURRET = {0, 0.831, 1},
    ENEMY = {1, 0.278, 0.341},
    PROJECTILE = {1, 0.843, 0},
    UI_TEXT = {0.878, 0.878, 0.878},
    ACCENT = {0.486, 0.227, 0.929},
    HP_BAR = {0.176, 0.784, 0.278},
    HP_BAR_BG = {0.2, 0.2, 0.2},
    XP_BAR = {0.486, 0.227, 0.929},
    XP_BAR_BG = {0.2, 0.2, 0.2},
    GOLD = {1, 0.843, 0},
    BOSS = {0.8, 0.2, 0.9},
    OVERLAY = {0, 0, 0, 0.6},
}

-- Enemy types
C.ENEMY = {
    GRUNT = {
        shape = "circle",
        baseHP = 20,
        baseSpeed = 2.0,
        radius = 20,
        color = C.COLOR.ENEMY,
        xpValue = 2,
        goldValue = 5,
    },
    TANK = {
        shape = "rect",
        baseHP = 80,
        baseSpeed = 1.0,
        radius = 25,
        color = {0.6, 0.3, 0.3},
        xpValue = 8,
        goldValue = 15,
    },
    SPEEDSTER = {
        shape = "triangle",
        baseHP = 15,
        baseSpeed = 4.0,
        radius = 15,
        color = {1, 0.5, 0.2},
        xpValue = 3,
        goldValue = 8,
    },
    BOSS = {
        shape = "hexagon",
        baseHP = 300,
        baseSpeed = 0.8,
        radius = 40,
        color = C.COLOR.BOSS,
        xpValue = 50,
        goldValue = 100,
    },
}

-- Turret types
C.TURRET = {
    BLASTER = {
        shape = "circle",
        range = 150,
        fireRate = 1.0,
        baseDamage = 10,
        radius = 25,
        color = C.COLOR.TURRET,
        special = "none",
    },
    CANNON = {
        shape = "rect",
        range = 100,
        fireRate = 0.4,
        baseDamage = 35,
        radius = 28,
        color = {0, 0.7, 0.9},
        special = "splash",
        splashRadius = 50,
        splashDamageRatio = 0.5,
    },
    SNIPER = {
        shape = "diamond",
        range = 350,
        fireRate = 0.25,
        baseDamage = 60,
        radius = 22,
        color = {0.3, 0.8, 1},
        special = "pierce",
        pierceCount = 2,
    },
    ZAPPER = {
        shape = "triangle",
        range = 120,
        fireRate = 2.5,
        baseDamage = 5,
        radius = 20,
        color = {0.5, 1, 0.8},
        special = "chain",
        chainCount = 3,
        chainDecay = 0.6,
    },
}

-- Turret anchor points (normalized 0-1 positions, path-adjacent)
C.TURRET_ANCHORS = {
    {x = 0.25, y = 0.30},
    {x = 0.75, y = 0.30},
    {x = 0.20, y = 0.50},
    {x = 0.80, y = 0.50},
    {x = 0.25, y = 0.70},
    {x = 0.75, y = 0.70},
    {x = 0.50, y = 0.40},
    {x = 0.50, y = 0.60},
}

-- Wave system
C.WAVE = {
    BASE_ENEMIES = 3,
    ENEMIES_PER_WAVE = 1.2,
    HP_SCALE_PER_WAVE = 0.08,
    SPEED_SCALE_PER_WAVE = 0.01,
    SPAWN_INTERVAL_BASE = 1.2,
    SPAWN_INTERVAL_SCALE = -0.02,
    SPAWN_INTERVAL_MIN = 0.4,
    WAVE_TRANSITION_TIME = 3.0,
    BOSS_WAVE_INTERVAL = 10,
    BONUS_WAVE_INTERVAL = 5,
    BONUS_HP_MULT = 1.2,
    BONUS_GOLD_MULT = 1.5,
}

-- Progression
C.PLAYER = {
    BASE_XP_PER_KILL = 0.1,
    XP_PER_LEVEL = 100,
    XP_LEVEL_SCALE = 1.0,
    STARTING_GOLD = 50,
    STARTING_WAVE = 1,
    MAX_LEVEL = 100,
}

-- Turret leveling
C.TURRET_LEVEL = {
    MAX_LEVEL = 10,
    DAMAGE_PER_LEVEL = 0.15,
    FIRE_RATE_PER_LEVEL = 0.05,
    COST_BASE = 50,
    COST_SCALE = 1.5,
}

-- Upgrade system
C.UPGRADE = {
    MAX_TEMP_PER_RUN = 3,
    DAMAGE_BOOST = 0.20,
    FIRE_RATE_BOOST = 0.25,
    RANGE_BOOST = 0.30,
    GOLD_BOOST = 0.20,
    SLOW_FIELD = 0.20,
    SHIELD_INSTANCES = 3,
    EXTRA_TURRET_DURATION = 1,
    PERM_XP_BOOST = 0.15,
    PERM_GOLD_BOSS = 0.30,
    PERM_STARTING_GOLD = 50,
}

-- Path waypoints (normalized 0-1, screen path)
C.PATH_WAYPOINTS = {
    {x = -0.05, y = 0.20},
    {x = 0.30, y = 0.20},
    {x = 0.30, y = 0.40},
    {x = 0.70, y = 0.40},
    {x = 0.70, y = 0.60},
    {x = 0.30, y = 0.60},
    {x = 0.30, y = 0.80},
    {x = 0.70, y = 0.80},
    {x = 0.70, y = 1.00},
    {x = 1.05, y = 1.00},
}

-- Player base HP
C.BASE_HP = 20

-- Projectile speed
C.PROJECTILE_SPEED = 600

-- Game states
C.STATE = {
    MENU = "MENU",
    PLAYING = "PLAYING",
    UPGRADE_SELECT = "UPGRADE_SELECT",
    PAUSED = "PAUSED",
    WAVE_TRANSITION = "WAVE_TRANSITION",
}

-- Audio volumes
C.AUDIO = {
    FIRE_VOLUME = 0.3,
    DEATH_VOLUME = 0.4,
    UPGRADE_VOLUME = 0.5,
    BOSS_VOLUME = 0.6,
    AMBIENT_VOLUME = 0.15,
}

return C