-- Projectile: visual-enhanced projectiles with trails
local C = require("consts")

local Projectile = {}
Projectile.__index = Projectile

function Projectile.new(turret, target, damage, special)
    local self = setmetatable({}, Projectile)
    self.x = turret.x
    self.y = turret.y
    self.target = target
    self.targetX = target.x
    self.targetY = target.y
    self.damage = damage
    self.special = special
    self.turretDef = turret.def
    self.speed = C.PROJECTILE_SPEED
    self.dead = false
    self.hitTargets = {}
    self.startX = self.x
    self.startY = self.y
    self.trail = {}
    self.maxTrail = 8

    -- Display
    self.group = display.newGroup()
    self.group.x = self.x
    self.group.y = self.y
    self:buildVisuals()

    return self
end

function Projectile:buildVisuals()
    local c = self.turretDef.color
    local cr, cg, cb = c[1], c[2], c[3]

    if self.special == "splash" then
        -- Cannon: larger, glowing orb
        self.main = display.newCircle(self.group, 0, 0, 10)
        self.main:setFillColor(cr, cg, cb, 0.9)
        self.main:setStrokeColor(1, 1, 1, 0.3)
        self.main.strokeWidth = 1

        -- Inner glow
        local inner = display.newCircle(self.group, 0, 0, 5)
        inner:setFillColor(1, 1, 1, 0.5)

        -- Outer glow
        local outer = display.newCircle(self.group, 0, 0, 14)
        outer:setFillColor(cr, cg, cb, 0.15)

        -- Rotating ring
        self.ring = display.newCircle(self.group, 0, 0, 16)
        self.ring:setStrokeColor(cr, cg, cb, 0.4)
        self.ring.strokeWidth = 1.5
        self.ring:setFillColor(0, 0, 0, 0)
        self.ring.rotation = math.random() * 360

    elseif self.special == "pierce" then
        -- Sniper: long needle
        self.main = display.newLine(self.group, -16, 0, 16, 0)
        self.main:setStrokeColor(cr, cg, cb, 1)
        self.main.strokeWidth = 4
        local tip = display.newLine(self.group, 12, 0, 20, 0)
        tip:setStrokeColor(1, 1, 1, 0.8)
        tip.strokeWidth = 2
        local trail = display.newLine(self.group, -16, 0, -28, 0)
        trail:setStrokeColor(cr, cg, cb, 0.4)
        trail.strokeWidth = 2

    elseif self.special == "chain" then
        -- Zapper: electric ball
        self.main = display.newCircle(self.group, 0, 0, 6)
        self.main:setFillColor(cr, cg, cb, 1)
        -- Lightning bolts around it
        for i = 1, 4 do
            local angle = (i / 4) * math.pi * 2
            local bolt = display.newLine(self.group,
                math.cos(angle) * 6, math.sin(angle) * 6,
                math.cos(angle) * 12, math.sin(angle) * 12)
            bolt:setStrokeColor(cr, cg, cb, 0.6)
            bolt.strokeWidth = 1.5
        end
        local inner = display.newCircle(self.group, 0, 0, 3)
        inner:setFillColor(1, 1, 1, 0.7)

    else
        -- Blaster: small glowing orb with trail
        self.main = display.newCircle(self.group, 0, 0, 5)
        self.main:setFillColor(cr, cg, cb, 1)
        local inner = display.newCircle(self.group, 0, 0, 2.5)
        inner:setFillColor(1, 1, 1, 0.8)
        local glow = display.newCircle(self.group, 0, 0, 8)
        glow:setFillColor(cr, cg, cb, 0.2)
    end

    -- Trail group
    self.trailGroup = display.newGroup()
    self.group:insert(self.trailGroup)
    self.trailObjects = {}
end

function Projectile:update(dt, enemies, onHit)
    if self.dead then return end

    -- Record trail point
    table.insert(self.trail, 1, { x = self.x, y = self.y })
    if #self.trail > self.maxTrail then
        table.remove(self.trail)
    end

    -- Update target position
    if self.target and not self.target.dead and not self.target.reachedEnd then
        self.targetX = self.target.x
        self.targetY = self.target.y
    end

    local dx = self.targetX - self.x
    local dy = self.targetY - self.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local moveDist = self.speed * dt

    -- Rotate ring on splash projectiles
    if self.ring then
        self.ring.rotation = self.ring.rotation + dt * 200
    end

    if dist <= moveDist then
        self.x = self.targetX
        self.y = self.targetY
        self.group.x = self.x
        self.group.y = self.y
        self.dead = true
        if onHit then onHit(self) end
    else
        self.x = self.x + (dx / dist) * moveDist
        self.y = self.y + (dy / dist) * moveDist
        self.group.x = self.x
        self.group.y = self.y

        -- Rotate projectile toward target
        local angle = math.atan2(dy, dx) * 180 / math.pi
        if self.main then
            -- For lines, rotate
            if self.main.path then
                self.main.rotation = angle
            end
        end
    end

    -- Update trail visuals
    self:updateTrail()
end

function Projectile:updateTrail()
    if not self.trailGroup then return end
    -- Clear old trail
    for _, t in ipairs(self.trailObjects) do
        t:removeSelf()
    end
    self.trailObjects = {}

    local c = self.turretDef.color
    local cr, cg, cb = c[1], c[2], c[3]

    for i, pt in ipairs(self.trail) do
        if i > 1 then
            local alpha = 1 - (i / self.maxTrail)
            local radius = math.max(1, 5 - i * 0.6)
            local dot = display.newCircle(self.trailGroup,
                pt.x - self.x,
                pt.y - self.y,
                radius)
            dot:setFillColor(cr, cg, cb, alpha * 0.4)
        end
    end
end

function Projectile:destroy()
    self.group:removeSelf()
    self.group = nil
end

return Projectile