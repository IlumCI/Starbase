-- Projectile: visual-enhanced projectiles with trails (LÖVE2D canvas-based)
local C = require("consts")

local Projectile = {}
Projectile.__index = Projectile

function Projectile.new(turret, target, damage, special, leadX, leadY)
    local self = setmetatable({}, Projectile)
    self.turretDef = turret.def
    self.damage = damage
    self.special = special

    -- Start position from turret
    self.startX = turret.x
    self.startY = turret.y
    self.x = turret.x
    self.y = turret.y

    -- Target (live reference for tracking)
    self.target = target
    -- Use ML lead target position if provided, else fall back to target position
    self.targetX = leadX or target.x
    self.targetY = leadY or target.y

    self.speed = C.PROJECTILE_SPEED
    self.dead = false
    self.hitSomething = false  -- set true when it damages any enemy

    -- Track which enemies were already hit (for pierce)
    self.hitTargets = {}

    -- Trail of past positions
    self.trail = {}
    self.maxTrail = 8

    -- Rotation angle (pointing toward target)
    self.rotation = 0

    -- Animation state
    self.ringAngle = math.random() * math.pi * 2

    -- Canvas
    self.canvas = love.graphics.newCanvas(C.WIDTH, C.HEIGHT)
    self:buildVisuals()

    return self
end

function Projectile:buildVisuals()
    local c = self.turretDef.color
    local cr, cg, cb = c[1], c[2], c[3]

    self.canvas:renderTo(function()
        love.graphics.clear()
        love.graphics.setBlendMode("alpha")

        -- Render centered on canvas
        love.graphics.push()
        love.graphics.translate(C.WIDTH / 2, C.HEIGHT / 2)

        -- Draw trail (fading circles behind projectile)
        for i, pt in ipairs(self.trail) do
            if i > 1 then
                local alpha = (1 - (i / self.maxTrail)) * 0.4
                local radius = math.max(1, 5 - i * 0.6)
                love.graphics.setColor(cr, cg, cb, alpha)
                love.graphics.circle("fill", pt.x - self.x, pt.y - self.y, radius)
            end
        end

        -- Rotate toward target
        love.graphics.rotate(self.rotation)

        -- Type-specific visuals
        if self.special == "splash" then
            self:renderSplash(cr, cg, cb)
        elseif self.special == "pierce" then
            self:renderPierce(cr, cg, cb)
        elseif self.special == "chain" then
            self:renderChain(cr, cg, cb)
        else
            self:renderNone(cr, cg, cb)
        end

        love.graphics.pop()
    end)
end

function Projectile:renderNone(cr, cg, cb)
    -- Outer glow
    love.graphics.setColor(cr, cg, cb, 0.2)
    love.graphics.circle("fill", 0, 0, 8)
    -- Main orb
    love.graphics.setColor(cr, cg, cb)
    love.graphics.circle("fill", 0, 0, 5)
    -- Inner core
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.circle("fill", 0, 0, 2.5)
end

function Projectile:renderSplash(cr, cg, cb)
    -- Outer glow
    love.graphics.setColor(cr, cg, cb, 0.15)
    love.graphics.circle("fill", 0, 0, 14)
    -- Main orb
    love.graphics.setColor(cr, cg, cb, 0.9)
    love.graphics.circle("fill", 0, 0, 10)
    -- Stroke
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.setLineWidth(1)
    love.graphics.circle("line", 0, 0, 10)
    -- Inner glow
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.circle("fill", 0, 0, 5)
    -- Rotating ring (rendered rotating in update)
    love.graphics.setColor(cr, cg, cb, 0.4)
    love.graphics.setLineWidth(1.5)
    love.graphics.push()
    love.graphics.rotate(self.ringAngle)
    love.graphics.circle("line", 0, 0, 16)
    love.graphics.pop()
end

function Projectile:renderPierce(cr, cg, cb)
    love.graphics.setColor(cr, cg, cb)
    love.graphics.setLineWidth(4)
    love.graphics.line(-16, 0, 16, 0)
    -- Tip (white)
    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.setLineWidth(2)
    love.graphics.line(12, 0, 20, 0)
    -- Trail
    love.graphics.setColor(cr, cg, cb, 0.4)
    love.graphics.setLineWidth(2)
    love.graphics.line(-16, 0, -28, 0)
end

function Projectile:renderChain(cr, cg, cb)
    -- Electric ball
    love.graphics.setColor(cr, cg, cb)
    love.graphics.circle("fill", 0, 0, 6)
    -- Inner core
    love.graphics.setColor(1, 1, 1, 0.7)
    love.graphics.circle("fill", 0, 0, 3)

    -- Lightning bolts (4 directions, offset by ring angle)
    love.graphics.setColor(cr, cg, cb, 0.6)
    love.graphics.setLineWidth(1.5)
    for i = 1, 4 do
        local angle = (i / 4) * math.pi * 2 + self.ringAngle
        local bx = math.cos(angle) * 6
        local by = math.sin(angle) * 6
        local ex = math.cos(angle) * 12
        local ey = math.sin(angle) * 12
        love.graphics.line(bx, by, ex, ey)
    end
end

function Projectile:update(dt, enemies, gameLoop)
    if self.dead then return end

    -- Record trail point
    table.insert(self.trail, 1, { x = self.x, y = self.y })
    if #self.trail > self.maxTrail then
        table.remove(self.trail)
    end

    -- Update target position (track live target)
    if self.target and not self.target.dead and not self.target.reachedEnd then
        self.targetX = self.target.x
        self.targetY = self.target.y
    end

    local dx = self.targetX - self.x
    local dy = self.targetY - self.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local moveDist = self.speed * dt

    -- Rotate projectile toward target
    self.rotation = math.atan2(dy, dx)

    -- Rotate ring for splash/chain
    self.ringAngle = self.ringAngle + dt * 200 * math.pi / 180

    if dist <= moveDist then
        -- Reached target
        self.x = self.targetX
        self.y = self.targetY
        self.dead = true

        if gameLoop then
            gameLoop:onProjectileHit(self)
        end
    else
        -- Move toward target
        self.x = self.x + (dx / dist) * moveDist
        self.y = self.y + (dy / dist) * moveDist
    end

    -- Rebuild visuals
    self:buildVisuals()
end

function Projectile:destroy()
    self.canvas = nil
end

return Projectile