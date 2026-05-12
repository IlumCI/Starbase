-- Enemy: one enemy entity with layered visual effects
local C = require("consts")
local Path = require("game.Path")

local Enemy = {}
Enemy.__index = Enemy

function Enemy.new(enemyTypeKey, wave, isBonus)
    local self = setmetatable({}, Enemy)
    local def = C.ENEMY[enemyTypeKey]
    self.typeKey = enemyTypeKey
    self.def = def
    self.wave = wave
    self.isBonus = isBonus or false

    -- Compute HP and speed for this wave
    local hpMult = (1 + wave * C.WAVE.HP_SCALE_PER_WAVE)
    if isBonus then hpMult = hpMult * C.WAVE.BONUS_HP_MULT end
    self.maxHP = math.floor(def.baseHP * hpMult)
    self.hp = self.maxHP

    local speedMult = (1 + wave * C.WAVE.SPEED_SCALE_PER_WAVE)
    self.speed = def.baseSpeed * speedMult

    self.pathLength = Path.getTotalLength()
    self.progress = 0
    self.waypoints = Path.getWaypoints()
    self.waypointIdx = 1
    self.dead = false
    self.reachedEnd = false
    self.x = self.waypoints[1].x
    self.y = self.waypoints[1].y
    self.radius = def.radius
    self.rotation = 0
    self.wobblePhase = math.random() * math.pi * 2

    -- Display
    self.group = display.newGroup()
    self.group.x = self.x
    self.group.y = self.y
    self:buildVisuals()
    self:buildHPBar()

    -- Particle trail data
    self.trailTimer = 0
    self.trailPoints = {}

    return self
end

function Enemy:buildVisuals()
    local r = self.radius
    local c = self.def.color
    local cr, cg, cb = c[1], c[2], c[3]

    -- Layer 0: outer glow ring
    self.outerGlow = display.newCircle(self.group, 0, 0, r + 12)
    self.outerGlow:setFillColor(cr, cg, cb, 0.06)
    self.outerGlow:toBack()

    -- Layer 1: outer ring / halo
    self.haloRing = display.newCircle(self.group, 0, 0, r + 6)
    self.haloRing:setStrokeColor(cr, cg, cb, 0.5)
    self.haloRing.strokeWidth = 1.5
    self.haloRing:setFillColor(0, 0, 0, 0)

    -- Layer 2: pulsing ring
    self.pulseRing = display.newCircle(self.group, 0, 0, r + 2)
    self.pulseRing:setStrokeColor(cr, cg, cb, 0.8)
    self.pulseRing.strokeWidth = 1
    self.pulseRing:setFillColor(0, 0, 0, 0)

    -- Layer 3: main body
    if self.def.shape == "circle" then
        self:buildGrunt(cr, cg, cb, r)
    elseif self.def.shape == "rect" then
        self:buildTank(cr, cg, cb, r)
    elseif self.def.shape == "triangle" then
        self:buildSpeedster(cr, cg, cb, r)
    elseif self.def.shape == "hexagon" then
        self:buildBoss(cr, cg, cb, r)
    end
end

function Enemy:buildGrunt(cr, cg, cb, r)
    -- Inner circle with gradient effect (darker center)
    local inner = display.newCircle(self.group, 0, 0, r - 4)
    inner:setFillColor(cr * 0.4, cg * 0.4, cb * 0.4)

    -- Main circle
    self.mainBody = display.newCircle(self.group, 0, 0, r - 2)
    self.mainBody:setFillColor(cr, cg, cb)
    self.mainBody:setStrokeColor(1, 1, 1, 0.25)
    self.mainBody.strokeWidth = 1.5

    -- Inner core
    local core = display.newCircle(self.group, 0, 0, r * 0.35)
    core:setFillColor(1, 1, 1, 0.3)

    -- Small orbiting dots
    for i = 1, 3 do
        local angle = (i / 3) * math.pi * 2
        local dot = display.newCircle(self.group, math.cos(angle) * (r + 4), math.sin(angle) * (r + 4), 3)
        dot:setFillColor(cr, cg, cb, 0.6)
    end

    -- Chevrons on top
    local chevron = display.newLine(self.group, -r * 0.4, -r * 0.2, 0, -r * 0.5, r * 0.4, -r * 0.2)
    chevron:setStrokeColor(1, 1, 1, 0.4)
    chevron.strokeWidth = 1.5
end

function Enemy:buildTank(cr, cg, cb, r)
    -- Main square body
    self.mainBody = display.newRect(self.group, 0, 0, r * 2, r * 2)
    self.mainBody:setFillColor(cr, cg, cb)
    self.mainBody:setStrokeColor(1, 1, 1, 0.2)
    self.mainBody.strokeWidth = 2

    -- Inner square (armor plate)
    local innerSq = display.newRect(self.group, 0, 0, r * 1.2, r * 1.2)
    innerSq:setFillColor(cr * 0.3, cg * 0.3, cb * 0.3)
    innerSq:setStrokeColor(1, 1, 1, 0.15)
    innerSq.strokeWidth = 1

    -- Cross pattern
    local hLine = display.newLine(self.group, -r * 0.8, 0, r * 0.8, 0)
    hLine:setStrokeColor(1, 1, 1, 0.2)
    hLine.strokeWidth = 1.5
    local vLine = display.newLine(self.group, 0, -r * 0.8, 0, r * 0.8)
    vLine:setStrokeColor(1, 1, 1, 0.2)
    vLine.strokeWidth = 1.5

    -- Corner bolts
    for dx = -1, 1, 2 do
        for dy = -1, 1, 2 do
            local bolt = display.newCircle(self.group, dx * r * 0.7, dy * r * 0.7, 4)
            bolt:setFillColor(1, 1, 1, 0.4)
        end
    end

    -- Shield ring
    local shield = display.newRect(self.group, 0, 0, r * 2.3, r * 2.3)
    shield:setStrokeColor(cr, cg, cb, 0.4)
    shield.strokeWidth = 1
    shield:setFillColor(0, 0, 0, 0)
    shield.rotation = 45
end

function Enemy:buildSpeedster(cr, cg, cb, r)
    -- Triangle body
    local pts = { 0, -r, r * 0.866, r * 0.5, -r * 0.866, r * 0.5 }
    self.mainBody = display.newPolygon(self.group, 0, 0, pts)
    self.mainBody:setFillColor(cr, cg, cb)
    self.mainBody:setStrokeColor(1, 1, 1, 0.25)
    self.mainBody.strokeWidth = 1.5

    -- Inner triangle (hollow feel)
    local innerPts = { 0, -r * 0.5, r * 0.4, r * 0.25, -r * 0.4, r * 0.25 }
    local innerTri = display.newPolygon(self.group, 0, 0, innerPts)
    innerTri:setFillColor(cr * 0.3, cg * 0.3, cb * 0.3)

    -- Speed lines behind
    for i = 1, 3 do
        local yOff = (i - 2) * r * 0.5
        local speedLine = display.newLine(self.group, -r * 1.5, yOff, -r * 0.3, yOff)
        speedLine:setStrokeColor(cr, cg, cb, 0.3)
        speedLine.strokeWidth = 1.5
    end

    -- Glowing edge
    local edge = display.newPolygon(self.group, 0, 0, pts)
    edge:setFillColor(0, 0, 0, 0)
    edge:setStrokeColor(1, 1, 1, 0.4)
    edge.strokeWidth = 1

    -- Motion trail (faint dots)
    for i = 1, 4 do
        local trailDot = display.newCircle(self.group, -r * 1.5 - i * 12, 0, 3 - i * 0.5)
        trailDot:setFillColor(cr, cg, cb, 0.2 - i * 0.04)
    end
end

function Enemy:buildBoss(cr, cg, cb, r)
    -- Large outer hexagon
    local outerPts = self:hexPoints(r + 15)
    local outerHex = display.newPolygon(self.group, 0, 0, outerPts)
    outerHex:setStrokeColor(cr, cg, cb, 0.4)
    outerHex.strokeWidth = 2
    outerHex:setFillColor(0, 0, 0, 0)

    -- Main hexagon
    local mainPts = self:hexPoints(r)
    self.mainBody = display.newPolygon(self.group, 0, 0, mainPts)
    self.mainBody:setFillColor(cr * 0.6, cg * 0.4, cb * 0.8)
    self.mainBody:setStrokeColor(cr, cg, cb, 0.8)
    self.mainBody.strokeWidth = 2

    -- Inner hexagon (darker)
    local innerPts = self:hexPoints(r * 0.6)
    local innerHex = display.newPolygon(self.group, 0, 0, innerPts)
    innerHex:setFillColor(cr * 0.2, cg * 0.1, cb * 0.3)

    -- Center eye / core
    local eye = display.newCircle(self.group, 0, 0, r * 0.25)
    eye:setFillColor(1, 0, 1, 0.8)
    local eyeRing = display.newCircle(self.group, 0, 0, r * 0.35)
    eyeRing:setStrokeColor(1, 0, 1, 0.6)
    eyeRing.strokeWidth = 1.5
    eyeRing:setFillColor(0, 0, 0, 0)

    -- Radiating spikes (6 directions)
    for i = 0, 5 do
        local angle = (i / 6) * math.pi * 2
        local spikeLen = r * 0.4
        local spike = display.newLine(self.group,
            math.cos(angle) * r * 0.5, math.sin(angle) * r * 0.5,
            math.cos(angle) * (r * 0.5 + spikeLen), math.sin(angle) * (r * 0.5 + spikeLen))
        spike:setStrokeColor(cr, cg, cb, 0.7)
        spike.strokeWidth = 2
    end

    -- Pulsing outer ring
    self.bossPulse = display.newCircle(self.group, 0, 0, r + 18)
    self.bossPulse:setStrokeColor(cr, cg, cb, 0.3)
    self.bossPulse.strokeWidth = 1
    self.bossPulse:setFillColor(0, 0, 0, 0)

    -- Textured fill (cross lines)
    for i = 0, 2 do
        local angle = (i / 3) * math.pi * 2
        local line = display.newLine(self.group,
            math.cos(angle) * r * 0.3, math.sin(angle) * r * 0.3,
            math.cos(angle) * r * 0.8, math.sin(angle) * r * 0.8)
        line:setStrokeColor(1, 1, 1, 0.1)
        line.strokeWidth = 1
    end
end

function Enemy:hexPoints(r)
    local pts = {}
    for i = 0, 5 do
        local angle = (i / 6) * math.pi * 2 - math.pi / 6
        table.insert(pts, math.cos(angle) * r)
        table.insert(pts, math.sin(angle) * r)
    end
    return pts
end

function Enemy:buildHPBar()
    self.hpBarBg = display.newRect(self.group, 0, -self.radius - 16, self.radius * 2.8, 4)
    self.hpBarBg:setFillColor(0.15, 0.15, 0.15)
    self.hpBarBg.anchorX = 0.5

    self.hpBar = display.newRect(self.group, 0, -self.radius - 16, self.radius * 2.8, 4)
    self.hpBar:setFillColor(unpack(C.COLOR.HP_BAR))
    self.hpBar.anchorX = 0
    self.hpBar.width = self.radius * 2.8

    -- HP bar glow
    self.hpBarGlow = display.newRect(self.group, 0, -self.radius - 16, self.radius * 2.8, 4)
    self.hpBarGlow:setFillColor(unpack(C.COLOR.HP_BAR))
    self.hpBarGlow.anchorX = 0
    self.hpBarGlow.alpha = 0.3
    self.hpBarGlow.width = self.radius * 2.8

    self.hpBar:toFront()
    self.hpBarGlow:toFront()
    self.hpBarBg:toFront()
end

function Enemy:update(dt, slowField)
    if self.dead or self.reachedEnd then return end
    local speed = self.speed
    if slowField > 0 then
        speed = speed * (1 - slowField)
    end
    local movement = (speed / self.pathLength) * dt
    self.progress = self.progress + movement

    if self.progress >= 1 then
        self.progress = 1
        self.reachedEnd = true
        self.x = self.waypoints[#self.waypoints].x
        self.y = self.waypoints[#self.waypoints].y
    else
        local pos = Path.getPositionAtProgress(self.progress, self.waypoints)
        self.x = pos.x
        self.y = pos.y
    end
    self.group.x = self.x
    self.group.y = self.y

    -- Visual animations
    self.wobblePhase = self.wobblePhase + dt * 2.5
    local wobble = math.sin(self.wobblePhase) * 2.5
    self.group.rotation = wobble

    -- Pulse effects
    if self.haloRing then
        self.haloRing.xScale = 1 + math.sin(self.wobblePhase * 1.3) * 0.08
        self.haloRing.yScale = 1 + math.sin(self.wobblePhase * 1.3) * 0.08
    end
    if self.pulseRing then
        self.pulseRing.alpha = 0.3 + math.sin(self.wobblePhase * 2) * 0.3
    end
    if self.bossPulse then
        self.bossPulse.xScale = 1.05 + math.sin(self.wobblePhase * 1.5) * 0.1
        self.bossPulse.yScale = 1.05 + math.sin(self.wobblePhase * 1.5) * 0.1
        self.bossPulse.alpha = 0.15 + math.sin(self.wobblePhase * 2) * 0.1
    end

    -- HP bar follows rotation (undo it)
    local hpAngle = -self.group.rotation
    if self.hpBarBg then
        self.hpBarBg.rotation = hpAngle
        self.hpBar.rotation = hpAngle
        self.hpBarGlow.rotation = hpAngle
    end
end

function Enemy:takeDamage(amount)
    if self.dead then return false end
    self.hp = self.hp - amount

    local ratio = math.max(0, self.hp / self.maxHP)
    self.hpBar.width = self.radius * 2.8 * ratio
    self.hpBarGlow.width = self.radius * 2.8 * ratio

    -- Flash white on hit
    if self.mainBody then
        self.mainBody:setFillColor(1, 1, 1, 0.9)
        local cr, cg, cb = self.def.color[1], self.def.color[2], self.def.color[3]
        timer.performWithDelay(60, function()
            if self.mainBody then
                self.mainBody:setFillColor(cr, cg, cb)
            end
        end)
    end

    if self.hp <= 0 then
        self.dead = true
        self:spawnDeathEffect()
        return true
    end
    return false
end

function Enemy:spawnDeathEffect()
    -- Burst particles (simple circles)
    local cr, cg, cb = self.def.color[1], self.def.color[2], self.def.color[3]
    for i = 1, 8 do
        local angle = (i / 8) * math.pi * 2
        local dist = self.radius * 1.5
        local px = self.group.x + math.cos(angle) * dist
        local py = self.group.y + math.sin(angle) * dist
        local particle = display.newCircle(self.group.parent, px, py, 6)
        particle:setFillColor(cr, cg, cb)
        transition.to(particle, {
            xScale = 0.1,
            yScale = 0.1,
            alpha = 0,
            x = px + math.cos(angle) * 30,
            y = py + math.sin(angle) * 30,
            time = 300,
            onComplete = function() particle:removeSelf() end
        })
    end

    -- Central burst
    local burst = display.newCircle(self.group.parent, self.group.x, self.group.y, self.radius * 0.5)
    burst:setFillColor(1, 1, 1)
    transition.to(burst, {
        xScale = 4,
        yScale = 4,
        alpha = 0,
        time = 350,
        onComplete = function() burst:removeSelf() end
    })
end

function Enemy:destroy()
    self.group:removeSelf()
    self.group = nil
end

return Enemy