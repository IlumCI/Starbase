-- UpgradeSystem: definitions and selection for roguelike upgrades
local C = require("consts")

local US = {}

-- Upgrade definitions
US.DEFS = {
    -- Temporary (per run)
    { id = "damage_boost_1", name = "Damage +20%", desc = "+20% damage this run", temp = true, category = "damage", rarity = 1 },
    { id = "damage_boost_2", name = "Damage +40%", desc = "+40% damage this run", temp = true, category = "damage", rarity = 2 },
    { id = "damage_boost_3", name = "Damage +60%", desc = "+60% damage this run", temp = true, category = "damage", rarity = 3 },
    { id = "fire_rate_boost_1", name = "Fire Rate +25%", desc = "+25% fire rate this run", temp = true, category = "fire_rate", rarity = 1 },
    { id = "fire_rate_boost_2", name = "Fire Rate +50%", desc = "+50% fire rate this run", temp = true, category = "fire_rate", rarity = 2 },
    { id = "fire_rate_boost_3", name = "Fire Rate +75%", desc = "+75% fire rate this run", temp = true, category = "fire_rate", rarity = 3 },
    { id = "range_boost_1", name = "Range +30%", desc = "+30% range this run", temp = true, category = "range", rarity = 1 },
    { id = "range_boost_2", name = "Range +60%", desc = "+60% range this run", temp = true, category = "range", rarity = 2 },
    { id = "range_boost_3", name = "Range +90%", desc = "+90% range this run", temp = true, category = "range", rarity = 3 },
    { id = "gold_boost_1", name = "Gold +20%", desc = "+20% gold this run", temp = true, category = "gold", rarity = 1 },
    { id = "gold_boost_2", name = "Gold +40%", desc = "+40% gold this run", temp = true, category = "gold", rarity = 2 },
    { id = "gold_boost_3", name = "Gold +60%", desc = "+60% gold this run", temp = true, category = "gold", rarity = 3 },
    { id = "slow_field", name = "Slow Field", desc = "Enemies move 20% slower this run", temp = true, category = "utility", rarity = 1 },
    { id = "slow_field_2", name = "Slow Field II", desc = "Enemies move 35% slower this run", temp = true, category = "utility", rarity = 2 },
    { id = "shield_1", name = "Shield +3", desc = "Absorb first 3 hits this run", temp = true, category = "defense", rarity = 1 },
    { id = "shield_2", name = "Shield +6", desc = "Absorb first 6 hits this run", temp = true, category = "defense", rarity = 2 },
    { id = "shield_3", name = "Shield +10", desc = "Absorb first 10 hits this run", temp = true, category = "defense", rarity = 3 },
    { id = "extra_turret", name = "Extra Turret", desc = "Deploy 1 extra turret this run", temp = true, category = "special", rarity = 1 },

    -- Permanent
    { id = "unlock_sniper", name = "Unlock Sniper", desc = "Permanently unlock Sniper turret", temp = false, category = "unlock", rarity = 1 },
    { id = "unlock_zapper", name = "Unlock Zapper", desc = "Permanently unlock Zapper turret", temp = false, category = "unlock", rarity = 1 },
    { id = "starting_gold_1", name = "Rich Start", desc = "+50 starting gold per run", temp = false, category = "permanent_gold", rarity = 1 },
    { id = "starting_gold_2", name = "Richer Start", desc = "+100 starting gold per run", temp = false, category = "permanent_gold", rarity = 2 },
    { id = "starting_gold_3", name = "Wealthy Start", desc = "+150 starting gold per run", temp = false, category = "permanent_gold", rarity = 3 },
    { id = "xp_boost_1", name = "XP Boost", desc = "+15% XP gain permanently", temp = false, category = "permanent_meta", rarity = 1 },
    { id = "xp_boost_2", name = "XP Boost II", desc = "+30% XP gain permanently", temp = false, category = "permanent_meta", rarity = 2 },
    { id = "boss_bonus_1", name = "Boss Hunter", desc = "+30% gold from bosses permanently", temp = false, category = "permanent_meta", rarity = 1 },
    { id = "wave_skip", name = "Quick Start", desc = "Start at wave 3 instead of 1", temp = false, category = "permanent_meta", rarity = 3 },
}

function US.getChoices(count, playerState)
    local pool = {}

    -- Separate temp and perm upgrades
    local tempPool = {}
    local permPool = {}
    for _, def in ipairs(US.DEFS) do
        -- Filter out already-granted permanent upgrades
        if def.temp then
            -- Check if this upgrade is already active (stacking rules)
            local alreadyActive = false
            if def.category == "damage" then alreadyActive = playerState.run.damageBoost > 0 end
            -- Allow stacking for now
            table.insert(tempPool, def)
        else
            -- Check if already owned
            if not playerState:hasPermanentUpgrade(def.id) then
                -- Check unlock prerequisites
                if def.id == "unlock_sniper" and not playerState:isTurretUnlocked("SNIPER") then
                    table.insert(permPool, def)
                elseif def.id == "unlock_zapper" and not playerState:isTurretUnlocked("ZAPPER") then
                    table.insert(permPool, def)
                elseif def.id ~= "unlock_sniper" and def.id ~= "unlock_zapper" then
                    table.insert(permPool, def)
                end
            end
        end
    end

    -- Limit temp upgrades per run
    local maxTemp = C.UPGRADE.MAX_TEMP_PER_RUN
    if playerState.run.tempUpgradeCount >= maxTemp then
        tempPool = {}
    end

    -- Combine: mostly temp, at most 1 permanent
    local choices = {}
    local hasPermThisRound = false

    -- Shuffle pools
    local function shuffle(t)
        for i = #t, 2, -1 do
            local j = math.random(1, i)
            t[i], t[j] = t[j], t[i]
        end
        return t
    end

    tempPool = shuffle(tempPool)
    permPool = shuffle(permPool)

    -- Always include 1 permanent if available and count >= 2
    if count >= 2 and #permPool > 0 and math.random() < 0.5 then
        local permDef = table.remove(permPool, 1)
        table.insert(choices, permDef)
        hasPermThisRound = true
    end

    -- Fill rest with temp
    for i = 1, count - #choices do
        local def = table.remove(tempPool, 1)
        if def then table.insert(choices, def) end
    end

    -- Shuffle final choices
    for i = #choices, 2, -1 do
        local j = math.random(1, i)
        choices[i], choices[j] = choices[j], choices[i]
    end

    return choices
end

function US.applyUpgrade(upgradeId, playerState, gameLoop)
    for _, def in ipairs(US.DEFS) do
        if def.id == upgradeId then
            if def.temp then
                playerState.run.tempUpgradeCount = playerState.run.tempUpgradeCount + 1
                if def.category == "damage" then
                    playerState.run.damageBoost = playerState.run.damageBoost + (def.rarity * C.UPGRADE.DAMAGE_BOOST)
                elseif def.category == "fire_rate" then
                    playerState.run.fireRateBoost = playerState.run.fireRateBoost + (def.rarity * C.UPGRADE.FIRE_RATE_BOOST)
                elseif def.category == "range" then
                    playerState.run.rangeBoost = playerState.run.rangeBoost + (def.rarity * C.UPGRADE.RANGE_BOOST)
                elseif def.category == "gold" then
                    playerState.run.goldBoost = playerState.run.goldBoost + (def.rarity * C.UPGRADE.GOLD_BOOST)
                elseif def.category == "utility" then
                    if def.id == "slow_field" then
                        playerState.run.slowField = playerState.run.slowField + C.UPGRADE.SLOW_FIELD
                    else
                        playerState.run.slowField = playerState.run.slowField + (C.UPGRADE.SLOW_FIELD * 1.75)
                    end
                elseif def.category == "defense" then
                    local mult = def.rarity
                    if def.id == "shield_1" then playerState.run.shieldInstances = playerState.run.shieldInstances + C.UPGRADE.SHIELD_INSTANCES
                    elseif def.id == "shield_2" then playerState.run.shieldInstances = playerState.run.shieldInstances + (C.UPGRADE.SHIELD_INSTANCES * 2)
                    else playerState.run.shieldInstances = playerState.run.shieldInstances + 10
                    end
                elseif def.category == "special" and def.id == "extra_turret" then
                    playerState.run.extraTurretCount = playerState.run.extraTurretCount + 1
                end
                -- Re-apply boosts to turrets
                if gameLoop then
                    gameLoop:applyBoostsToTurrets()
                end
            else
                -- Permanent
                if def.id == "unlock_sniper" then
                    playerState:unlockTurret("SNIPER")
                elseif def.id == "unlock_zapper" then
                    playerState:unlockTurret("ZAPPER")
                else
                    playerState:grantPermanentUpgrade(def.id)
                end
            end
            return true
        end
    end
    return false
end

return US