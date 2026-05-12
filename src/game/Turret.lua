-- Turret: one turret entity with layered geometric visuals
local C = require("consts")

local Turret = {}
Turret.__index = Turret

function Turret.new(towerTypeKey, anchorX, anchorY)
    local self = setmetatable({}, Turret)
    local def = C.TURRET[towerTypeKey]
    self.typeKey = towerTypeKey
    self.def = def
    self.anchorX = anchorX
    self.anchorY = anchorY
    self.x = anchorX
    self.y = anchorY
    self.target = nil
    self.cooldown = 0
    self.dead = false
    self.turretLevel = 1
    self.pulseTime = math.random() * math.pi * 2

    -- Compute stats
    self:recomputeStats()

    -- Display
    self.group = display.newGroup()
    self.group.x = self.x
    self.group.y = self.y
    self:buildVisuals()

    -- Targeting laser
    self.targetLine = nil

    return self
end

function Turret:setLevel(level)
    self.turretLevel = level
    self:recomputeStats()
end

function Turret:recomputeStats()
    local def = self.def
    local lvl = self.turretLevel
    local dmgMult = 1 + (lvl - 1) * C.TURRET_LEVEL.DAMAGE_PER_LEVEL
    local frMult = 1 + (lvl - 1) * C.TURRET_LEVEL.FIRE_RATE_PER_LEVEL
    self.damage = math.floor(def.baseDamage * dmgMult)
    self.fireRate = def.fireRate * frMult
    self.range = def.range
end

function Turret:applyBoost(damageBoost, fireRateBoost, rangeBoost)
    self.damage = math.floor(self.damage * (1 + damageBoost))
    self.fireRate = self.fireRate * (1 + fireRateBoost)
    self.range = self.range * (1 + rangeBoost)
end

function Turret:buildVisuals()
    local r = self.def.radius
    local c = self.def.color
    local cr, cg, cb = c[1], c[2], c[3]

    -- Range ring (subtle background)
    self.rangeRing = display.newCircle(self.group, 0, 0, self.range)
    self.rangeRing:setStrokeColor(1, 1, 1, 0.06)
    self.rangeRing.strokeWidth = 1
    self.rangeRing:setFillColor(0, 0, 0, 0.04)

    -- Outer energy field (subtle rotating ring)
    self.energyRing = display.newCircle(self.group, 0, 0, r + 16)
    self.energyRing:setStrokeColor(cr, cg, cb, 0.25)
    self.energyRing.strokeWidth = 1.5
    self.energyRing:setFillColor(0, 0, 0, 0)

    -- Second outer ring (offset)
    self.energyRing2 = display.newCircle(self.group, 0, 0, r + 22)
    self.energyRing2:setStrokeColor(cr, cg, cb, 0.15)
    self.energyRing2.strokeWidth = 1
    self.energyRing2:setFillColor(0, 0, 0, 0)

    -- Base platform (ground shadow)
    self.basePlatform = display.newCircle(self.group, 0, 4, r + 12)
    self.basePlatform:setFillColor(0, 0, 0, 0.25)

    -- Turret-specific visuals
    if self.typeKey == "BLASTER" then
        self:buildBlaster(cr, cg, cb, r)
    elseif self.typeKey == "CANNON" then
        self:buildCannon(cr, cg, cb, r)
    elseif self.typeKey == "SNIPER" then
        self:buildSniper(cr, cg, cb, r)
    elseif self.typeKey == "ZAPPER" then
        self:buildZapper(cr, cg, cb, r)
    end

    -- Targeting line (built in update)
end

function Turret:buildBlaster(cr, cg, cb, r)
    -- Layered concentric circles
    local outerRing = display.newCircle(self.group, 0, 0, r + 3)
    outerRing:setStrokeColor(cr, cg, cb, 0.6)
    outerRing.strokeWidth = 2
    outerRing:setFillColor(0, 0, 0, 0)

    -- Dashed effect (small segments)
    for i = 0, 7 do
        local angle = (i / 8) * math.pi * 2
        local dot = display.newCircle(self.group,
            math.cos(angle) * (r + 8),
            math.sin(angle) * (r + 8),
            2.5)
        dot:setFillColor(cr, cg, cb, 0.5)
    end

    -- Main body
    self.mainBody = display.newCircle(self.group, 0, 0, r)
    self.mainBody:setFillColor(cr * 0.15, cg * 0.15, cb * 0.15)
    self.mainBody:setStrokeColor(cr, cg, cb, 0.9)
    self.mainBody.strokeWidth = 2

    -- Inner fill gradient (lighter center)
    local inner = display.newCircle(self.group, 0, 0, r * 0.7)
    inner:setFillColor(cr * 0.25, cg * 0.25, cb * 0.25)

    -- Barrel (line extending outward)
    self.barrel = display.newLine(self.group, 0, 0, r, 0)
    self.barrel:setStrokeColor(cr, cg, cb, 1)
    self.barrel.strokeWidth = 4
    self.barrel.curWidth = 4

    -- Barrel tip glow
    self.barrelTip = display.newCircle(self.group, r, 0, 4)
    self.barrelTip:setFillColor(cr, cg, cb)

    -- Energy core
    self.core = display.newCircle(self.group, 0, 0, r * 0.3)
    self.core:setFillColor(cr, cg, cb, 0.8)

    -- Core ring
    local coreRing = display.newCircle(self.group, 0, 0, r * 0.4)
    coreRing:setStrokeColor(cr, cg, cb, 0.6)
    coreRing.strokeWidth = 1
    coreRing:setFillColor(0, 0, 0, 0)
end

function Turret:buildCannon(cr, cg, cb, r)
    -- Square base
    self.mainBody = display.newRect(self.group, 0, 0, r * 2, r * 2)
    self.mainBody:setFillColor(cr * 0.1, cg * 0.1, cb * 0.1)
    self.mainBody:setStrokeColor(cr, cg, cb, 0.8)
    self.mainBody.strokeWidth = 2

    -- Diagonal lines on body
    local d1 = display.newLine(self.group, -r * 0.7, -r * 0.7, r * 0.7, r * 0.7)
    d1:setStrokeColor(cr, cg, cb, 0.3)
    d1.strokeWidth = 1.5
    local d2 = display.newLine(self.group, r * 0.7, -r * 0.7, -r * 0.7, r * 0.7)
    d2:setStrokeColor(cr, cg, cb, 0.3)
    d2.strokeWidth = 1.5

    -- Corner accents
    for dx = -1, 1, 2 do
        for dy = -1, 1, 2 do
            local corner = display.newCircle(self.group, dx * r * 0.7, dy * r * 0.7, 3)
            corner:setFillColor(cr, cg, cb, 0.7)
        end
    end

    -- Wide barrel
    self.barrel = display.newRect(self.group, r * 0.5, 0, r * 1.2, r * 0.6)
    self.barrel:setFillColor(cr * 0.3, cg * 0.3, cb * 0.3)
    self.barrel:setStrokeColor(cr, cg, cb, 1)
    self.barrel.strokeWidth = 1.5

    -- Barrel opening
    self.barrelTip = display.newCircle(self.group, r * 1.7, 0, r * 0.35)
    self.barrelTip:setFillColor(cr, cg, cb)

    -- Inner glow
    local innerGlow = display.newRect(self.group, 0, 0, r * 1.4, r * 1.4)
    innerGlow:setFillColor(cr, cg, cb, 0.1)
    innerGlow.rotation = 45

    -- Cross symbol
    local cross = display.newLine(self.group, -r * 0.3, 0, r * 0.3, 0)
    cross:setStrokeColor(cr, cg, cb, 0.5)
    cross.strokeWidth = 2
    local crossV = display.newLine(self.group, 0, -r * 0.3, 0, r * 0.3)
    crossV:setStrokeColor(cr, cg, cb, 0.5)
    crossV.strokeWidth = 2
end

function Turret:buildSniper(cr, cg, cb, r)
    -- Diamond shape
    local pts = { 0, -r, r, 0, 0, r, -r, 0 }
    self.mainBody = display.newPolygon(self.group, 0, 0, pts)
    self.mainBody:setFillColor(cr * 0.08, cg * 0.08, cb * 0.08)
    self.mainBody:setStrokeColor(cr, cg, cb, 0.8)
    self.mainBody.strokeWidth = 2

    -- Long barrel (extending up)
    self.barrel = display.newLine(self.group, 0, -r * 0.3, 0, -r * 2.2)
    self.barrel:setStrokeColor(cr, cg, cb, 1)
    self.barrel.strokeWidth = 3

    -- Scope (small circle at top of barrel)
    self.barrelTip = display.newCircle(self.group, 0, -r * 2.2, r * 0.3)
    self.barrelTip:setFillColor(cr, cg, cb)
    local scopeRing = display.newCircle(self.group, 0, -r * 2.2, r * 0.4)
    scopeRing:setStrokeColor(cr, cg, cb, 0.6)
    scopeRing.strokeWidth = 1
    scopeRing:setFillColor(0, 0, 0, 0)

    -- Crosshair inside diamond
    local hLine = display.newLine(self.group, -r * 0.5, 0, r * 0.5, 0)
    hLine:setStrokeColor(cr, cg, cb, 0.5)
    hLine.strokeWidth = 1.5
    local vLine = display.newLine(self.group, 0, -r * 0.5, 0, r * 0.5)
    vLine:setStrokeColor(cr, cg, cb, 0.5)
    vLine.strokeWidth = 1.5

    -- Concentric diamond rings
    local innerPts = { 0, -r * 0.6, r * 0.6, 0, 0, r * 0.6, -r * 0.6, 0 }
    local inner = display.newPolygon(self.group, 0, 0, innerPts)
    inner:setStrokeColor(cr, cg, cb, 0.3)
    inner.strokeWidth = 1
    inner:setFillColor(0, 0, 0, 0)

    -- Tick marks on outer diamond
    for i = 0, 3 do
        local angle = (i / 4) * math.pi * 2 - math.pi / 2
        local outerPts2 = { 0, -r, r, 0, 0, r, -r, 0 }
        -- Inner tick
        local tx = math.cos(angle) * r * 0.75
        local ty = math.sin(angle) * r * 0.75
        local tick = display.newCircle(self.group, tx, ty, 2.5)
        tick:setFillColor(cr, cg, cb, 0.7)
    end

    -- Energy core
    self.core = display.newCircle(self.group, 0, 0, r * 0.2)
    self.core:setFillColor(cr, cg, cb, 0.9)
end

function Turret:buildZapper(cr, cg, cb, r)
    -- Triangle body (pointing up)
    local pts = { 0, -r, r * 0.866, r * 0.5, -r * 0.866, r * 0.5 }
    self.mainBody = display.newPolygon(self.group, 0, 0, pts)
    self.mainBody:setFillColor(cr * 0.1, cg * 0.1, cb * 0.1)
    self.mainBody:setStrokeColor(cr, cg, cb, 0.8)
    self.mainBody.strokeWidth = 2

    -- Lightning bolt shape inside
    local bolt = display.newLine(self.group, -r * 0.2, -r * 0.4, r * 0.1, 0, -r * 0.1, 0, r * 0.2, r * 0.4)
    bolt:setStrokeColor(cr, cg, cb, 0.8)
    bolt.strokeWidth = 2

    -- Inner triangle
    local innerPts = { 0, -r * 0.5, r * 0.4, r * 0.25, -r * 0.4, r * 0.25 }
    local inner = display.newPolygon(self.group, 0, 0, innerPts)
    inner:setFillColor(cr * 0.05, cg * 0.05, cb * 0.05)
    inner:setStrokeColor(cr, cg, cb, 0.4)
    inner.strokeWidth = 1

    -- Energy dots on edges
    for i = 0, 2 do
        local angle = (i / 3) * math.pi * 2 - math.pi / 2
        local dot = display.newCircle(self.group,
            math.cos(angle) * r * 0.8,
            math.sin(angle) * r * 0.8,
            3)
        dot:setFillColor(cr, cg, cb, 0.6)
    end

    -- Outer triangle ring
    local outerPts = { 0, -r - 8, (r + 8) * 0.866, (r + 8) * 0.5, -(r + 8) * 0.866, (r + 8) * 0.5 }
    local outer = display.newPolygon(self.group, 0, 0, outerPts)
    outer:setStrokeColor(cr, cg, cb, 0.3)
    outer.strokeWidth = 1.5
    outer:setFillColor(0, 0, 0, 0)

    -- Arc segments
    for i = 0, 2 do
        local angle = (i / 3) * math.pi * 2 - math.pi / 2
        local arcX = math.cos(angle) * (r + 12)
        local arcY = math.sin(angle) * (r + 12)
        local arcDot = display.newCircle(self.group, arcX, arcY, 2)
        arcDot:setFillColor(cr, cg, cb, 0.4)
    end

    -- Barrel (shoots from top)
    self.barrel = display.newLine(self.group, 0, -r * 0.5, 0, -r * 1.5)
    self.barrel:setStrokeColor(cr, cg, cb, 1)
    self.barrel.strokeWidth = 3
    self.barrelTip = display.newCircle(self.group, 0, -r * 1.5, 3.5)
    self.barrelTip:setFillColor(cr, cg, cb)

    -- Core
    self.core = display.newCircle(self.group, 0, 0, r * 0.2)
    self.core:setFillColor(cr, cg, cb, 0.9)
end

function Turret:update(dt, enemies, projectiles, gameState)
    self.cooldown = self.cooldown - dt
    if self.cooldown < 0 then self.cooldown = 0 end
    self.pulseTime = self.pulseTime + dt * 2.5

    -- Animate energy rings
    if self.energyRing then
        self.energyRing.rotation = self.pulseTime * 30
    end
    if self.energyRing2 then
        self.energyRing2.rotation = -self.pulseTime * 20
        self.energyRing2.xScale = 1 + math.sin(self.pulseTime * 1.5) * 0.05
        self.energyRing2.yScale = 1 + math.cos(self.pulseTime * 1.5) * 0.05
    end

    -- Barrel direction
    self:findTargetAndFire(enemies, projectiles)
end

function Turret:findTargetAndFire(enemies, projectiles)
    self.target = self:findTarget(enemies)
    if self.target then
        local dx = self.target.x - self.x
        local dy = self.target.y - self.y
        local angle = math.atan2(dy, dx) * 180 / math.pi

        -- Rotate barrel toward target
        if self.barrel then
            local barX = self.barrel.path and self.barrel.path and self.barrel.path.x1 or 0
            self.barrel.rotation = angle
            if self.barrelTip then self.barrelTip.rotation = angle end
        end

        -- Fire if ready
        if self.cooldown <= 0 then
            self:fire(projectiles)
            self.cooldown = 1.0 / self.fireRate
        end
    end
end

function Turret:findTarget(enemies)
    local best = nil
    local bestDist = self.range + 1
    local bestHP = -1
    for _, enemy in ipairs(enemies) do
        if not enemy.dead and not enemy.reachedEnd then
            local dx = enemy.x - self.x
            local dy = enemy.y - self.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist <= self.range then
                if dist < bestDist or (dist == bestDist and enemy.hp > bestHP) then
                    best = enemy
                    bestDist = dist
                    bestHP = enemy.hp
                end
            end
        end
    end
    return best
end

function Turret:fire(projectiles)
    if not self.target then return end
    local proj = require("game.Projectile").new(self, self.target, self.damage, self.def.special)
    table.insert(projectiles, proj)

    -- Muzzle flash
    self:spawnMuzzleFlash()
end

function Turret:spawnMuzzleFlash()
    local cr, cg, cb = self.def.color[1], self.def.color[2], self.def.color[3]
    local angle = (self.barrel and self.barrel.rotation or 0) * math.pi / 180
    local barrelLen = self.def.radius * 1.5
    local flashX = self.x + math.cos(angle) * barrelLen
    local flashY = self.y + math.sin(angle) * barrelLen

    -- Main flash
    local flash = display.newCircle(self.group.parent, flashX, flashY, self.def.radius * 0.5)
    flash:setFillColor(1, 1, 1, 0.9)
    transition.to(flash, {
        xScale = 3,
        yScale = 3,
        alpha = 0,
        time = 150,
        onComplete = function() flash:removeSelf() end
    })

    -- Color flash
    local cflash = display.newCircle(self.group.parent, flashX, flashY, self.def.radius * 0.3)
    cflash:setFillColor(cr, cg, cb)
    transition.to(cflash, {
        xScale = 4,
        yScale = 4,
        alpha = 0,
        time = 200,
        onComplete = function() cflash:removeSelf() end
    end)
end

function Turret:destroy()
    self.group:removeSelf()
    self.group = nil
end

return Turret