-- Turret: one turret entity with layered geometric visuals (LÖVE2D canvas-based)
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

    -- Computed stats
    self:recomputeStats()

    -- Barrel angle (radians)
    self.barrelAngle = 0
    self.energyRingAngle = 0

    -- Muzzle flash flag (handled by GameLoop)
    self.muzzleFlashTimer = 0

    -- ML reference (set by GameLoop when placing turrets)
    self.ml = nil

    -- Lead target position (computed by ML trajectory predictor)
    self.leadTargetX = nil
    self.leadTargetY = nil

    -- Canvas
    self.useNNTargeting = false

    -- Canvas
    self.canvas = love.graphics.newCanvas(C.WIDTH, C.HEIGHT)
    self:buildVisuals()

    return self
end

function Turret:setLevel(level)
    self.turretLevel = level
    self:recomputeStats()
end

-- Inject ML reference from GameLoop (called when placing turrets)
function Turret:setML(ml)
    self.ml = ml
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

    self.canvas:renderTo(function()
        love.graphics.clear()

        -- Render everything centered on canvas
        love.graphics.setBlendMode("alpha")
        love.graphics.push()
        love.graphics.translate(C.WIDTH / 2, C.HEIGHT / 2)

        -- Range ring
        love.graphics.setColor(1, 1, 1, 0.06)
        love.graphics.setLineWidth(1)
        love.graphics.circle("line", 0, 0, self.range)
        love.graphics.setColor(0, 0, 0, 0.04)
        love.graphics.circle("fill", 0, 0, self.range)

        -- Energy rings (animated via pulseTime)
        local pulseScale1 = 1 + math.sin(self.pulseTime * 1.5) * 0.05
        love.graphics.setColor(cr, cg, cb, 0.25)
        love.graphics.setLineWidth(1.5)
        love.graphics.push()
        love.graphics.rotate(self.energyRingAngle)
        love.graphics.scale(pulseScale1, pulseScale1)
        love.graphics.circle("line", 0, 0, r + 16)
        love.graphics.pop()

        local pulseScale2 = 1 + math.cos(self.pulseTime * 1.5) * 0.05
        love.graphics.setColor(cr, cg, cb, 0.15)
        love.graphics.setLineWidth(1)
        love.graphics.push()
        love.graphics.rotate(-self.energyRingAngle * 0.7)
        love.graphics.scale(pulseScale2, pulseScale2)
        love.graphics.circle("line", 0, 0, r + 22)
        love.graphics.pop()

        -- Base platform (shadow)
        love.graphics.setColor(0, 0, 0, 0.25)
        love.graphics.circle("fill", 0, 4, r + 12)

        -- Type-specific body (barrel will be rendered on top)
        if self.typeKey == "BLASTER" then
            self:renderBlaster(cr, cg, cb, r)
        elseif self.typeKey == "CANNON" then
            self:renderCannon(cr, cg, cb, r)
        elseif self.typeKey == "SNIPER" then
            self:renderSniper(cr, cg, cb, r)
        elseif self.typeKey == "ZAPPER" then
            self:renderZapper(cr, cg, cb, r)
        end

        -- Barrel (rotates toward target)
        self:renderBarrel(cr, cg, cb, r)

        -- Core glow
        love.graphics.setColor(cr, cg, cb, 0.9)
        love.graphics.circle("fill", 0, 0, r * 0.2)

        love.graphics.pop()
    end)
end

function Turret:renderBlaster(cr, cg, cb, r)
    -- Dashed ring segments
    for i = 0, 7 do
        local angle = (i / 8) * math.pi * 2
        love.graphics.setColor(cr, cg, cb, 0.5)
        love.graphics.circle("fill",
            math.cos(angle) * (r + 8),
            math.sin(angle) * (r + 8),
            2.5
        )
    end

    -- Outer ring
    love.graphics.setColor(cr, cg, cb, 0.6)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", 0, 0, r + 3)

    -- Main body
    love.graphics.setColor(cr * 0.15, cg * 0.15, cb * 0.15)
    love.graphics.circle("fill", 0, 0, r)
    love.graphics.setColor(cr, cg, cb, 0.9)
    love.graphics.setLineWidth(2)
    love.graphics.circle("line", 0, 0, r)

    -- Inner fill
    love.graphics.setColor(cr * 0.25, cg * 0.25, cb * 0.25)
    love.graphics.circle("fill", 0, 0, r * 0.7)

    -- Core ring
    love.graphics.setColor(cr, cg, cb, 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", 0, 0, r * 0.4)
end

function Turret:renderCannon(cr, cg, cb, r)
    local size = r * 2

    -- Inner glow (rotated square)
    love.graphics.setColor(cr, cg, cb, 0.1)
    love.graphics.push()
    love.graphics.rotate(math.pi / 4)
    love.graphics.rectangle("fill", -r * 0.7, -r * 0.7, r * 1.4, r * 1.4)
    love.graphics.pop()

    -- Main square body
    love.graphics.setColor(cr * 0.1, cg * 0.1, cb * 0.1)
    love.graphics.rectangle("fill", -r, -r, size, size)
    love.graphics.setColor(cr, cg, cb, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", -r, -r, size, size)

    -- Diagonal cross pattern
    love.graphics.setColor(cr, cg, cb, 0.3)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(-r * 0.7, -r * 0.7, r * 0.7, r * 0.7)
    love.graphics.line(r * 0.7, -r * 0.7, -r * 0.7, r * 0.7)

    -- Corner accents
    love.graphics.setColor(cr, cg, cb, 0.7)
    for dx = -1, 1, 2 do
        for dy = -1, 1, 2 do
            love.graphics.circle("fill", dx * r * 0.7, dy * r * 0.7, 3)
        end
    end

    -- Cross symbol
    love.graphics.setColor(cr, cg, cb, 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.line(-r * 0.3, 0, r * 0.3, 0)
    love.graphics.line(0, -r * 0.3, 0, r * 0.3)
end

function Turret:renderSniper(cr, cg, cb, r)
    -- Outer concentric diamond rings
    local function diamondLine(sz, alpha)
        love.graphics.setColor(cr, cg, cb, alpha)
        love.graphics.setLineWidth(1)
        love.graphics.polygon("line",
            0, -sz, sz, 0, 0, sz, -sz, 0
        )
    end
    diamondLine(r, 0.3)

    -- Main diamond body
    love.graphics.setColor(cr * 0.08, cg * 0.08, cb * 0.08)
    love.graphics.polygon("fill",
        0, -r, r, 0, 0, r, -r, 0
    )
    love.graphics.setColor(cr, cg, cb, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line",
        0, -r, r, 0, 0, r, -r, 0
    )

    -- Crosshair inside diamond
    love.graphics.setColor(cr, cg, cb, 0.5)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(-r * 0.5, 0, r * 0.5, 0)
    love.graphics.line(0, -r * 0.5, 0, r * 0.5)

    -- Tick marks on diamond corners
    for i = 0, 3 do
        local angle = (i / 4) * math.pi * 2 - math.pi / 2
        local tx = math.cos(angle) * r * 0.75
        local ty = math.sin(angle) * r * 0.75
        love.graphics.setColor(cr, cg, cb, 0.7)
        love.graphics.circle("fill", tx, ty, 2.5)
    end

    -- Scope ring
    love.graphics.setColor(cr, cg, cb, 0.6)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", 0, -r * 2.2, r * 0.4)
end

function Turret:renderZapper(cr, cg, cb, r)
    -- Outer triangle ring
    love.graphics.setColor(cr, cg, cb, 0.3)
    love.graphics.setLineWidth(1.5)
    love.graphics.polygon("line",
        0, -(r + 8),
        (r + 8) * 0.866, (r + 8) * 0.5,
        -(r + 8) * 0.866, (r + 8) * 0.5
    )

    -- Arc dots on outer ring
    for i = 0, 2 do
        local angle = (i / 3) * math.pi * 2 - math.pi / 2
        local ax = math.cos(angle) * (r + 12)
        local ay = math.sin(angle) * (r + 12)
        love.graphics.setColor(cr, cg, cb, 0.4)
        love.graphics.circle("fill", ax, ay, 2)
    end

    -- Main triangle body
    love.graphics.setColor(cr * 0.1, cg * 0.1, cb * 0.1)
    love.graphics.polygon("fill",
        0, -r, r * 0.866, r * 0.5, -r * 0.866, r * 0.5
    )
    love.graphics.setColor(cr, cg, cb, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.polygon("line",
        0, -r, r * 0.866, r * 0.5, -r * 0.866, r * 0.5
    )

    -- Lightning bolt shape
    love.graphics.setColor(cr, cg, cb, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.line(-r * 0.2, -r * 0.4, r * 0.1, 0)
    love.graphics.line(r * 0.1, 0, -r * 0.1, 0)
    love.graphics.line(-r * 0.1, 0, r * 0.2, r * 0.4)

    -- Inner triangle
    love.graphics.setColor(cr * 0.05, cg * 0.05, cb * 0.05)
    love.graphics.setLineWidth(1)
    love.graphics.polygon("fill",
        0, -r * 0.5, r * 0.4, r * 0.25, -r * 0.4, r * 0.25
    )
    love.graphics.setColor(cr, cg, cb, 0.4)
    love.graphics.polygon("line",
        0, -r * 0.5, r * 0.4, r * 0.25, -r * 0.4, r * 0.25
    )

    -- Energy dots on edges
    for i = 0, 2 do
        local angle = (i / 3) * math.pi * 2 - math.pi / 2
        love.graphics.setColor(cr, cg, cb, 0.6)
        love.graphics.circle("fill",
            math.cos(angle) * r * 0.8,
            math.sin(angle) * r * 0.8,
            3
        )
    end
end

function Turret:renderBarrel(cr, cg, cb, r)
    love.graphics.setColor(cr, cg, cb)
    love.graphics.setLineWidth(4)
    love.graphics.line(0, 0, math.cos(self.barrelAngle) * r, math.sin(self.barrelAngle) * r)
    love.graphics.setLineWidth(1)
    love.graphics.circle("fill", math.cos(self.barrelAngle) * r, math.sin(self.barrelAngle) * r, 4)
end

function Turret:update(dt, enemies, projectiles, gameLoop)
    -- Cooldown
    if self.cooldown > 0 then
        self.cooldown = self.cooldown - dt
    end
    if self.cooldown < 0 then self.cooldown = 0 end

    -- Pulse animation
    self.pulseTime = self.pulseTime + dt * 2.5
    self.energyRingAngle = self.pulseTime * 30 * math.pi / 180

    -- Muzzle flash timer
    if self.muzzleFlashTimer > 0 then
        self.muzzleFlashTimer = self.muzzleFlashTimer - dt
        if self.muzzleFlashTimer < 0 then self.muzzleFlashTimer = 0 end
    end

    -- Find target and fire
    self:findTargetAndFire(enemies, projectiles, gameLoop)

    -- Rebuild visuals
    self:buildVisuals()
end

function Turret:findTargetAndFire(enemies, projectiles, gameLoop)
    -- Use ML-based targeting when available
    local target
    if self.ml and gameLoop and gameLoop.ml then
        target = gameLoop.ml:selectTarget(enemies, self)
    else
        target = self:findTarget(enemies)
    end
    self.target = target
    if not target then return end

    -- Compute lead target position using ML trajectory predictor (for fast enemies)
    local leadX, leadY
    if self.ml and gameLoop and gameLoop.ml then
        leadX, leadY = gameLoop.ml:computeIntercept(self.x, self.y, target, C.PROJECTILE_SPEED)
    else
        leadX, leadY = target.x, target.y
    end

    self.leadTargetX = leadX
    self.leadTargetY = leadY

    -- Barrel aims at lead position
    local dx = leadX - self.x
    local dy = leadY - self.y
    self.barrelAngle = math.atan2(dy, dx)

    -- Fire if ready
    if self.cooldown <= 0 then
        self:fire(projectiles, target, leadX, leadY)
        self.cooldown = 1.0 / self.fireRate
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

function Turret:fire(projectiles, target, leadX, leadY)
    if not target then return end
    local Projectile = require("game.Projectile")
    local proj = Projectile.new(self, target, self.damage, self.def.special, leadX, leadY)
    table.insert(projectiles, proj)

    -- Muzzle flash flag (GameLoop handles visual)
    self.muzzleFlashTimer = 0.15
end

function Turret:destroy()
    self.canvas = nil
end

return Turret