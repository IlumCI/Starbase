-- GameLoop: core game state machine
local C = require("consts")
local PS = require("game.meta.PlayerState")
local Path = require("game.Path")
local Enemy = require("game.Enemy")
local Turret = require("game.Turret")
local WM = require("game.WaveManager")
local US = require("game.UpgradeSystem")

local GameLoop = {}
GameLoop.__index = GameLoop

function GameLoop.new()
    local self = setmetatable({}, GameLoop)
    self.state = C.STATE.MENU
    self.enemies = {}
    self.turrets = {}
    self.projectiles = {}
    self.waveManager = WM.new(self)

    -- Groups for display
    self.bgGroup = display.newGroup()
    self.pathGroup = display.newGroup()
    self.enemyGroup = display.newGroup()
    self.turretGroup = display.newGroup()
    self.projGroup = display.newGroup()
    self.uiGroup = display.newGroup()

    -- Build background
    self:buildBackground()

    -- Build path visual
    self:buildPathVisual()

    -- Current upgrade choices
    self.upgradeChoices = {}

    -- Transition countdown
    self.transitionCountdown = 0
    self.waveStartGold = 0

    return self
end

function GameLoop:buildBackground()
    -- Solid background
    local bg = display.newRect(self.bgGroup, C.CENTER_X, C.CENTER_Y, C.WIDTH, C.HEIGHT)
    bg:setFillColor(unpack(C.COLOR.BACKGROUND))

    -- Grid lines
    local gridSpacing = 80
    for x = 0, C.WIDTH, gridSpacing do
        local line = display.newLine(self.bgGroup, x, 0, x, C.HEIGHT)
        line:setStrokeColor(unpack(C.COLOR.GRID))
        line.strokeWidth = 1
    end
    for y = 0, C.HEIGHT, gridSpacing do
        local line = display.newLine(self.bgGroup, 0, y, C.WIDTH, y)
        line:setStrokeColor(unpack(C.COLOR.GRID))
        line.strokeWidth = 1
    end
end

function GameLoop:buildPathVisual()
    local waypoints = Path.getWaypoints()
    for i = 1, #waypoints - 1 do
        local line = display.newLine(self.pathGroup,
            waypoints[i].x, waypoints[i].y,
            waypoints[i + 1].x, waypoints[i + 1].y)
        line:setStrokeColor(0.2, 0.2, 0.35, 0.8)
        line.strokeWidth = 30
    end
    -- Start marker
    local startCircle = display.newCircle(self.pathGroup, waypoints[1].x, waypoints[1].y, 20)
    startCircle:setFillColor(0, 0.5, 0)
    startCircle:setStrokeColor(0, 1, 0, 0.5)
    startCircle.strokeWidth = 2
    -- End marker (player base)
    local endPt = waypoints[#waypoints]
    self.baseMarker = display.newCircle(self.pathGroup, endPt.x, endPt.y, 25)
    self.baseMarker:setFillColor(0.8, 0.1, 0.1)
    self.baseMarker:setStrokeColor(1, 0.2, 0.2, 0.6)
    self.baseMarker.strokeWidth = 3
end

function GameLoop:startRun()
    PS.init()
    self.state = C.STATE.PLAYING

    -- Clear old entities
    self:clearEntities()

    -- Place turrets based on unlocked turrets
    self:placeTurrets()

    -- Start wave 1
    self.waveManager:startNextWave(PS.run.wave)
    self.waveStartGold = PS.run.gold

    -- Hide menu UI if shown
    self:hideMenuUI()
end

function GameLoop:placeTurrets()
    -- Clear existing
    for _, t in ipairs(self.turrets) do t:destroy() end
    self.turrets = {}

    local unlocked = PS.data.unlockedTurrets
    local turretKeys = {}
    for _, t in ipairs(unlocked) do table.insert(turretKeys, t) end

    -- Fill remaining slots with what we have (up to TURRET_ANCHORS count)
    local maxSlots = math.min(#C.TURRET_ANCHORS, #turretKeys + PS.run.extraTurretCount)
    for i = 1, maxSlots do
        local typeKey = turretKeys[(i - 1) % #turretKeys + 1]
        local anchor = C.TURRET_ANCHORS[i]
        local ax = anchor.x * C.WIDTH
        local ay = anchor.y * C.HEIGHT
        local turret = Turret.new(typeKey, ax, ay, PS.data.playerLevel)
        turret:setLevel(PS:getTurretLevel(typeKey))
        table.insert(self.turrets, turret)
        self.turretGroup:insert(turret.group)
    end
end

function GameLoop:applyBoostsToTurrets()
    local boost = PS.run
    for _, turret in ipairs(self.turrets) do
        turret:applyBoost(boost.damageBoost, boost.fireRateBoost, boost.rangeBoost)
    end
end

function GameLoop:clearEntities()
    for _, e in ipairs(self.enemies) do e:destroy() end
    for _, t in ipairs(self.turrets) do t:destroy() end
    for _, p in ipairs(self.projectiles) do p:destroy() end
    self.enemies = {}
    self.turrets = {}
    self.projectiles = {}
end

function GameLoop:update(dt)
    if self.state == C.STATE.PLAYING then
        self.waveManager:update(dt)

        -- Update enemies
        for i = #self.enemies, 1, -1 do
            local enemy = self.enemies[i]
            enemy:update(dt, PS.run.slowField)
            if enemy.reachedEnd then
                -- Damage player
                if PS.run.shieldInstances > 0 then
                    PS.run.shieldInstances = PS.run.shieldInstances - 1
                else
                    PS.run.hp = PS.run.hp - 1
                end
                table.remove(self.enemies, i):destroy()
            elseif enemy.dead then
                -- Killed — award XP and gold
                local isBoss = (enemy.typeKey == "BOSS")
                local baseGold = enemy.def.goldValue
                local goldMult = self.waveManager.isBonusWave and C.WAVE.BONUS_GOLD_MULT or 1.0
                if isBoss then
                    PS:addGoldBoss(baseGold * goldMult)
                else
                    PS:addGold(math.floor(baseGold * goldMult))
                end
                local xpGain = enemy.def.xpValue
                PS:addXP(xpGain)
                PS.run.enemiesKilled = PS.run.enemiesKilled + 1
                self.waveManager:onEnemyKilled()
                table.remove(self.enemies, i):destroy()
            end
        end

        -- Update turrets
        for _, turret in ipairs(self.turrets) do
            turret:update(dt, self.enemies, self.projectiles, self)
        end

        -- Update projectiles
        for i = #self.projectiles, 1, -1 do
            local proj = self.projectiles[i]
            proj:update(dt, self.enemies, function(p)
                self:onProjectileHit(p)
            end)
            if proj.dead then
                table.remove(self.projectiles, i):destroy()
            end
        end

        -- Check wave clear
        if self.waveManager:isWaveClear() and self.waveManager.waveTransitionTimer <= 0 then
            -- Wave complete — move to upgrade select
            self.state = C.STATE.UPGRADE_SELECT
            self.upgradeChoices = US.getChoices(3, PS)
            self:showUpgradeScreen()
        end

        -- Check player HP
        if PS.run.hp <= 0 then
            -- Player base destroyed — bank what we have
            PS:bankProgress()
            self.state = C.STATE.MENU
            self:showMenuUI()
        end
    end
end

function GameLoop:onProjectileHit(proj)
    local special = proj.special
    local enemies = self.enemies

    if special == "splash" then
        local def = proj.turretDef
        local radius = def.splashRadius or 50
        local ratio = def.splashDamageRatio or 0.5
        for _, enemy in ipairs(enemies) do
            if not enemy.dead and not enemy.reachedEnd then
                local dx = enemy.x - proj.x
                local dy = enemy.y - proj.y
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist < radius then
                    local dmg = dist < 20 and proj.damage or math.floor(proj.damage * ratio)
                    enemy:takeDamage(dmg)
                end
            end
        end
    elseif special == "pierce" then
        local def = proj.turretDef
        local count = def.pierceCount or 2
        local hitCount = 0
        for _, enemy in ipairs(enemies) do
            if not enemy.dead and not enemy.reachedEnd and hitCount < count then
                local dx = enemy.x - proj.x
                local dy = enemy.y - proj.y
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist < enemy.radius + 15 then
                    enemy:takeDamage(proj.damage)
                    hitCount = hitCount + 1
                end
            end
        end
    elseif special == "chain" then
        local def = proj.turretDef
        local chainCount = def.chainCount or 3
        local decay = def.chainDecay or 0.6
        local hit = {}
        local first = nil
        for _, enemy in ipairs(enemies) do
            if not enemy.dead and not enemy.reachedEnd then
                local dx = enemy.x - proj.x
                local dy = enemy.y - proj.y
                local dist = math.sqrt(dx * dx + dy * dy)
                if dist < 30 then
                    enemy:takeDamage(proj.damage)
                    table.insert(hit, enemy)
                    if not first then first = enemy end
                    break
                end
            end
        end
        if first then
            local chainDmg = math.floor(proj.damage * decay)
            local last = first
            for i = 2, chainCount do
                local nextEnemy = nil
                local minD = 200
                for _, enemy in ipairs(enemies) do
                    if not enemy.dead and not enemy.reachedEnd then
                        local alreadyHit = false
                        for _, h in ipairs(hit) do if h == enemy then alreadyHit = true; break end end
                        if not alreadyHit then
                            local dx = enemy.x - last.x
                            local dy = enemy.y - last.y
                            local d = math.sqrt(dx * dx + dy * dy)
                            if d < minD then
                                minD = d
                                nextEnemy = enemy
                            end
                        end
                    end
                end
                if nextEnemy then
                    nextEnemy:takeDamage(chainDmg)
                    table.insert(hit, nextEnemy)
                    last = nextEnemy
                    chainDmg = math.floor(chainDmg * decay)
                else
                    break
                end
            end
        end
    else
        -- Basic single target
        if proj.target and not proj.target.dead then
            proj.target:takeDamage(proj.damage)
        end
    end
end

function GameLoop:onUpgradeSelected(upgradeId)
    US.applyUpgrade(upgradeId, PS, self)
    self:hideUpgradeScreen()

    -- Advance wave
    PS.run.wave = PS.run.wave + 1
    self.waveManager:startNextWave(PS.run.wave)
    self.waveStartGold = PS.run.gold

    self.state = C.STATE.PLAYING
end

-- UI stubs (implemented in ui/ files)
function GameLoop:showUpgradeScreen() end
function GameLoop:hideUpgradeScreen() end
function GameLoop:showMenuUI() end
function GameLoop:hideMenuUI() end

function GameLoop:destroy()
    self:clearEntities()
    self.bgGroup:removeSelf()
    self.pathGroup:removeSelf()
    self.enemyGroup:removeSelf()
    self.turretGroup:removeSelf()
    self.projGroup:removeSelf()
    self.uiGroup:removeSelf()
end

return GameLoop