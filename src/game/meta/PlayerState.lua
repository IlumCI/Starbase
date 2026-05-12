-- PlayerState: in-memory + banked player state
local P = require("game.meta.Persistence")
local C = require("consts")

local PS = {}

function PS.init()
    local save = P.load()
    PS.data = save or P.getDefault()
    PS.run = {
        gold = C.PLAYER.STARTING_GOLD,
        xp = 0,
        wave = C.PLAYER.STARTING_WAVE,
        hp = C.BASE_HP,
        damageBoost = 0,
        fireRateBoost = 0,
        rangeBoost = 0,
        goldBoost = 0,
        slowField = 0,
        shieldInstances = 0,
        extraTurretCount = 0,
        tempUpgradeCount = 0,
        enemiesKilled = 0,
        activeTurrets = {},
    }
    PS:computeStartingGold()
end

function PS:computeStartingGold()
    local extra = 0
    for _, up in ipairs(PS.data.permanentUpgrades or {}) do
        if up == "starting_gold_1" then extra = extra + C.UPGRADE.PERM_STARTING_GOLD end
        if up == "starting_gold_2" then extra = extra + C.UPGRADE.PERM_STARTING_GOLD end
        if up == "starting_gold_3" then extra = extra + C.UPGRADE.PERM_STARTING_GOLD end
    end
    local lvl = PS.data.playerLevel
    local levelBonus = (lvl - 1) * 5
    PS.run.gold = C.PLAYER.STARTING_GOLD + extra + levelBonus
end

function PS:getTurretLevel(towerType)
    return PS.data.turretLevels[towerType] or 1
end

function PS:upgradeTurret(towerType)
    local cur = PS:getTurretLevel(towerType)
    if cur >= C.TURRET_LEVEL.MAX_LEVEL then return false end
    local cost = PS:turretUpgradeCost(towerType)
    if PS.data.bankedGold < cost then return false end
    PS.data.bankedGold = PS.data.bankedGold - cost
    PS.data.turretLevels[towerType] = cur + 1
    PS:save()
    return true
end

function PS:turretUpgradeCost(towerType)
    local lvl = PS:getTurretLevel(towerType)
    return math.floor(C.TURRET_LEVEL.COST_BASE * (C.TURRET_LEVEL.COST_SCALE ^ (lvl - 1)))
end

function PS:addXP(amount)
    local xpBoost = 0
    for _, up in ipairs(PS.data.permanentUpgrades or {}) do
        if up == "xp_boost_1" then xpBoost = xpBoost + C.UPGRADE.PERM_XP_BOOST end
        if up == "xp_boost_2" then xpBoost = xpBoost + C.UPGRADE.PERM_XP_BOOST end
    end
    local gained = math.floor(amount * (1 + xpBoost))
    PS.run.xp = PS.run.xp + gained
    PS.data.totalXP = PS.data.totalXP + gained
    local needed = PS:xpToNextLevel()
    if PS.run.xp >= needed then
        PS.run.xp = PS.run.xp - needed
        PS.data.playerLevel = math.min(PS.data.playerLevel + 1, C.PLAYER.MAX_LEVEL)
        PS:save()
        return true -- leveled up
    end
    return false
end

function PS:xpToNextLevel()
    return PS.data.playerLevel * C.PLAYER.XP_PER_LEVEL
end

function PS:addGold(amount)
    local boost = PS.run.goldBoost
    local bossBoost = 0
    for _, up in ipairs(PS.data.permanentUpgrades or {}) do
        if up == "boss_bonus_1" then bossBoost = bossBoost + C.UPGRADE.PERM_GOLD_BOSS end
    end
    -- applied externally via isBoss flag
    local gained = math.floor(amount * (1 + boost))
    PS.run.gold = PS.run.gold + gained
end

function PS:addGoldBoss(amount)
    local boost = PS.run.goldBoost
    local bossBoost = 0
    for _, up in ipairs(PS.data.permanentUpgrades or {}) do
        if up == "boss_bonus_1" then bossBoost = bossBoost + C.UPGRADE.PERM_GOLD_BOSS end
    end
    local gained = math.floor(amount * (1 + boost) * (1 + bossBoost))
    PS.run.gold = PS.run.gold + gained
end

function PS:bankProgress()
    -- Called on "Bank & Exit" — save all run progress
    PS.data.bankedGold = PS.data.bankedGold + PS.run.gold
    PS.data.wavesCleared = math.max(PS.data.wavesCleared, PS.run.wave - 1)
    PS.data.highestWave = math.max(PS.data.highestWave, PS.run.wave - 1)
    PS:save()
end

function PS:discardRun()
    -- Called on "Quit" — no bank, just save level data
    PS:save()
end

function PS:save()
    P.save(PS.data)
end

function PS:hasPermanentUpgrade(id)
    for _, v in ipairs(PS.data.permanentUpgrades or {}) do
        if v == id then return true end
    end
    return false
end

function PS:grantPermanentUpgrade(id)
    if PS:hasPermanentUpgrade(id) then return false end
    table.insert(PS.data.permanentUpgrades, id)
    PS:save()
end

function PS:unlockTurret(towerType)
    for _, t in ipairs(PS.data.unlockedTurrets) do
        if t == towerType then return false end
    end
    table.insert(PS.data.unlockedTurrets, towerType)
    PS:save()
    return true
end

function PS:isTurretUnlocked(towerType)
    for _, t in ipairs(PS.data.unlockedTurrets) do
        if t == towerType then return true end
    end
    return false
end

function PS:countPermanentUpgrades()
    return #PS.data.permanentUpgrades
end

return PS