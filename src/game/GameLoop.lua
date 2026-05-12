-- GameLoop: core game state machine (LÖVE2D port)
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

    -- Background canvas
    self.bgCanvas = love.graphics.newCanvas(C.WIDTH, C.HEIGHT)
    self:buildBackground()

    -- Current upgrade choices
    self.upgradeChoices = {}

    -- Transition countdown
    self.transitionCountdown = 0
    self.waveStartGold = 0

    -- Pulse time for visual effects
    self.pulseTime = 0

    -- Death effect pool (transient circles rendered in draw)
    self.deathEffects = {}  -- { {x, y, r, cr, cg, cb, timer}, ... }
    self.muzzleFlashes = {}  -- { {x, y, r, cr, cg, cb, timer}, ... }

    -- UI visibility
    self.showingMenu = false
    self.showingUpgrade = false
    self.showingPause = false

    -- UI refs (set by main.lua)
    self.mainMenu = nil
    self.hud = nil
    self.upgradeScreen = nil
    self.pauseMenu = nil

    -- Press highlight (touch feedback)
    self.pressedButton = nil  -- {x, y, w, h, r, g, b} or nil
    self.pressHighlightAlpha = 0  -- 0-1 for fade out

    return self
end

function GameLoop:buildBackground()
    self.bgCanvas:renderTo(function()
        -- Solid background
        love.graphics.setColor(C.COLOR.BACKGROUND[1], C.COLOR.BACKGROUND[2], C.COLOR.BACKGROUND[3])
        love.graphics.rectangle("fill", 0, 0, C.WIDTH, C.HEIGHT)

        -- Grid lines
        local gridSpacing = 80
        love.graphics.setColor(C.COLOR.GRID[1], C.COLOR.GRID[2], C.COLOR.GRID[3])
        for x = 0, C.WIDTH, gridSpacing do
            love.graphics.setLineWidth(1)
            love.graphics.line(x, 0, x, C.HEIGHT)
        end
        for y = 0, C.HEIGHT, gridSpacing do
            love.graphics.line(0, y, C.WIDTH, y)
        end

        -- Path visual
        local waypoints = Path.getWaypoints()
        love.graphics.setColor(0.2, 0.2, 0.35, 0.8)
        love.graphics.setLineWidth(30)
        for i = 1, #waypoints - 1 do
            love.graphics.line(waypoints[i].x, waypoints[i].y, waypoints[i + 1].x, waypoints[i + 1].y)
        end

        -- Start marker
        love.graphics.setColor(0, 0.5, 0)
        love.graphics.circle("fill", waypoints[1].x, waypoints[1].y, 20)
        love.graphics.setColor(0, 1, 0, 0.5)
        love.graphics.setLineWidth(2)
        love.graphics.circle("line", waypoints[1].x, waypoints[1].y, 20)

        -- End marker (player base)
        local endPt = waypoints[#waypoints]
        love.graphics.setColor(0.8, 0.1, 0.1)
        love.graphics.circle("fill", endPt.x, endPt.y, 25)
        love.graphics.setColor(1, 0.2, 0.2, 0.6)
        love.graphics.setLineWidth(3)
        love.graphics.circle("line", endPt.x, endPt.y, 25)
    end)
end

function GameLoop:startRun()
    PS.init()
    self.state = C.STATE.PLAYING

    -- Clear old entities
    self:clearEntities()

    -- Place turrets
    self:placeTurrets()

    -- Start wave 1
    self.waveManager:startNextWave(PS.run.wave)
    self.waveStartGold = PS.run.gold

    self.showingMenu = false
    self.showingUpgrade = false
    self.showingPause = false
end

function GameLoop:placeTurrets()
    for _, t in ipairs(self.turrets) do t:destroy() end
    self.turrets = {}

    local unlocked = PS.data.unlockedTurrets
    local turretKeys = {}
    for _, t in ipairs(unlocked) do table.insert(turretKeys, t) end

    local maxSlots = math.min(#C.TURRET_ANCHORS, #turretKeys + PS.run.extraTurretCount)
    for i = 1, maxSlots do
        local typeKey = turretKeys[(i - 1) % #turretKeys + 1]
        local anchor = C.TURRET_ANCHORS[i]
        local ax = anchor.x * C.WIDTH
        local ay = anchor.y * C.HEIGHT
        local turret = Turret.new(typeKey, ax, ay, PS.data.playerLevel)
        turret:setLevel(PS:getTurretLevel(typeKey))
        table.insert(self.turrets, turret)
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
    self.pulseTime = self.pulseTime + dt

    -- Fade out press highlight
    if self.pressedButton then
        self.pressHighlightAlpha = self.pressHighlightAlpha - dt * 4
        if self.pressHighlightAlpha <= 0 then
            self.pressedButton = nil
            self.pressHighlightAlpha = 0
        end
    end

    -- Update death/muzzle effects
    for i = #self.deathEffects, 1, -1 do
        self.deathEffects[i].timer = self.deathEffects[i].timer - dt
        if self.deathEffects[i].timer <= 0 then
            table.remove(self.deathEffects, i)
        end
    end
    for i = #self.muzzleFlashes, 1, -1 do
        self.muzzleFlashes[i].timer = self.muzzleFlashes[i].timer - dt
        if self.muzzleFlashes[i].timer <= 0 then
            table.remove(self.muzzleFlashes, i)
        end
    end

    if self.state == C.STATE.PLAYING then
        self.waveManager:update(dt)

        -- Update enemies
        for i = #self.enemies, 1, -1 do
            local enemy = self.enemies[i]
            enemy:update(dt, PS.run.slowField)
            if enemy.reachedEnd then
                if PS.run.shieldInstances > 0 then
                    PS.run.shieldInstances = PS.run.shieldInstances - 1
                else
                    PS.run.hp = PS.run.hp - 1
                end
                table.remove(self.enemies, i):destroy()
            elseif enemy.dead then
                local isBoss = (enemy.typeKey == "BOSS")
                local baseGold = enemy.def.goldValue
                local goldMult = self.waveManager.isBonusWave and C.WAVE.BONUS_GOLD_MULT or 1.0
                if isBoss then
                    PS:addGoldBoss(baseGold * goldMult)
                else
                    PS:addGold(math.floor(baseGold * goldMult))
                end
                PS:addXP(enemy.def.xpValue)
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
            self.state = C.STATE.UPGRADE_SELECT
            self.upgradeChoices = US.getChoices(3, PS)
            self.upgradeScreen:show(self.upgradeChoices)
            self.showingUpgrade = true
        end

        -- Check player HP
        if PS.run.hp <= 0 then
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
        if proj.target and not proj.target.dead then
            proj.target:takeDamage(proj.damage)
        end
    end
end

function GameLoop:onUpgradeSelected(upgradeId)
    US.applyUpgrade(upgradeId, PS, self)
    self.upgradeScreen:hide()
    self.showingUpgrade = false
    PS.run.wave = PS.run.wave + 1
    self.waveManager:startNextWave(PS.run.wave)
    self.waveStartGold = PS.run.gold
    self.state = C.STATE.PLAYING
end

function GameLoop:onPauseTap()
    if self.state == C.STATE.PLAYING then
        self.state = C.STATE.PAUSED
        self.pauseMenu:show()
        self.showingPause = true
    end
end

-- Unified press handler: returns button highlight data or nil
function GameLoop:onPress(x, y)
    local function makeHighlight(btn)
        return { x = btn.x, y = btn.y, w = btn.w, h = btn.h, r = btn.r or 0.5, g = btn.g or 0.5, b = btn.b or 0.5 }
    end

    -- Check upgrade screen
    if self.showingUpgrade and self.upgradeScreen then
        local result = self.upgradeScreen:onPress(x, y)
        if result then
            self.pressedButton = result
            self.pressHighlightAlpha = 1.0
            return true
        end
    end

    -- Check pause menu
    if self.showingPause and self.pauseMenu then
        local result = self.pauseMenu:onPress(x, y)
        if result then
            self.pressedButton = result
            self.pressHighlightAlpha = 1.0
            return true
        end
    end

    -- Check main menu
    if self.showingMenu and self.mainMenu then
        local result = self.mainMenu:onPress(x, y)
        if result then
            self.pressedButton = result
            self.pressHighlightAlpha = 1.0
            return true
        end
    end

    -- Check HUD (pause button)
    if not self.showingMenu and not self.showingUpgrade and not self.showingPause then
        if self.hud then
            local result = self.hud:onPress(x, y)
            if result then
                self.pressedButton = result
                self.pressHighlightAlpha = 1.0
                return true
            end
        end
    end

    self.pressedButton = nil
    return false
end

-- Back button / escape key handler
function GameLoop:onBack()
    if self.showingUpgrade then
        -- Can't go back from upgrade selection
        return
    end
    if self.showingPause then
        -- Resume from pause
        self.pauseMenu:hide()
        self.showingPause = false
        self.state = C.STATE.PLAYING
    elseif self.state == C.STATE.PLAYING then
        self:onPauseTap()
    elseif self.state == C.STATE.PAUSED then
        -- Already handled above
    end
end

function GameLoop:showMenuUI()
    self.mainMenu:show()
    self.showingMenu = true
end

function GameLoop:hideMenuUI()
    self.mainMenu:hide()
    self.showingMenu = false
end

function GameLoop:addDeathEffect(x, y, r, cr, cg, cb)
    -- Burst particles
    for i = 1, 8 do
        local angle = (i / 8) * math.pi * 2
        local dist = r * 1.5
        local px = x + math.cos(angle) * dist
        local py = y + math.sin(angle) * dist
        table.insert(self.deathEffects, {
            x = px, y = py, r = 6,
            cr = cr, cg = cg, cb = cb,
            timer = 0.3, totalTimer = 0.3
        })
    end
    -- Central burst
    table.insert(self.deathEffects, {
        x = x, y = y, r = r * 0.5,
        cr = 1, cg = 1, cb = 1,
        timer = 0.35, totalTimer = 0.35
    })
end

function GameLoop:addMuzzleFlash(x, y, r, cr, cg, cb)
    table.insert(self.muzzleFlashes, {
        x = x, y = y, r = r,
        cr = cr, cg = cg, cb = cb,
        timer = 0.15, totalTimer = 0.15
    })
end

function GameLoop:draw()
    -- Background (always drawn)
    love.graphics.draw(self.bgCanvas, 0, 0)

    -- Enemies
    for _, enemy in ipairs(self.enemies) do
        if enemy.canvas then
            love.graphics.draw(enemy.canvas, enemy.x, enemy.y, 0, 1, 1, C.WIDTH / 2, C.HEIGHT / 2)
        end
        -- HP bar (screen space, no rotation)
        if not enemy.dead and not enemy.reachedEnd and enemy.maxHP then
            local hpRatio = math.max(0, enemy.hp / enemy.maxHP)
            local barW = enemy.radius * 2.8
            local barH = 4
            local barX = enemy.x - barW / 2
            local barY = enemy.y - enemy.radius - 16
            love.graphics.setColor(0.15, 0.15, 0.15)
            love.graphics.rectangle("fill", barX, barY, barW, barH)
            love.graphics.setColor(C.COLOR.HP_BAR[1], C.COLOR.HP_BAR[2], C.COLOR.HP_BAR[3])
            love.graphics.rectangle("fill", barX, barY, barW * hpRatio, barH)
        end
    end

    -- Turrets
    for _, turret in ipairs(self.turrets) do
        if turret.canvas then
            love.graphics.draw(turret.canvas, turret.x, turret.y)
        end
    end

    -- Projectiles
    for _, proj in ipairs(self.projectiles) do
        if proj.canvas then
            love.graphics.draw(proj.canvas, proj.x, proj.y)
        end
    end

    -- Death effects
    for _, e in ipairs(self.deathEffects) do
        local alpha = e.timer / e.totalTimer
        love.graphics.setColor(e.cr, e.cg, e.cb, alpha)
        local scale = 1 + (1 - alpha) * 3
        love.graphics.circle("fill", e.x, e.y, e.r * scale)
    end

    -- Muzzle flashes
    for _, m in ipairs(self.muzzleFlashes) do
        local alpha = m.timer / m.totalTimer
        -- White flash
        love.graphics.setColor(1, 1, 1, alpha * 0.9)
        love.graphics.circle("fill", m.x, m.y, m.r * 0.5 * (1 + (1 - alpha) * 2))
        -- Color flash
        love.graphics.setColor(m.cr, m.cg, m.cb, alpha)
        love.graphics.circle("fill", m.x, m.y, m.r * 0.3 * (1 + (1 - alpha) * 3))
    end

    -- UI layers
    if not self.showingMenu and not self.showingUpgrade and not self.showingPause then
        if self.hud and self.hud.visible then
            love.graphics.draw(self.hud.canvas, 0, 0)
        end
    end

    if self.showingMenu and self.mainMenu and self.mainMenu.visible then
        love.graphics.draw(self.mainMenu.canvas, 0, 0)
    end

    if self.showingUpgrade and self.upgradeScreen and self.upgradeScreen.visible then
        love.graphics.draw(self.upgradeScreen.canvas, 0, 0)
    end

    if self.showingPause and self.pauseMenu and self.pauseMenu.visible then
        love.graphics.draw(self.pauseMenu.canvas, 0, 0)
    end

    -- Press highlight overlay (touch feedback)
    if self.pressedButton then
        local b = self.pressedButton
        local a = math.max(0, self.pressHighlightAlpha)
        love.graphics.setColor(b.r, b.g, b.b, 0.25 * a)
        love.graphics.rectangle("fill", b.x, b.y, b.w, b.h)
        love.graphics.setColor(b.r, b.g, b.b, 0.5 * a)
        love.graphics.setLineWidth(3)
        love.graphics.rectangle("line", b.x, b.y, b.w, b.h)
        love.graphics.setLineWidth(1)
    end
end

function GameLoop:destroy()
    self:clearEntities()
    self.bgCanvas = nil
end

return GameLoop