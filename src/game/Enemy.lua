-- Enemy: one enemy entity with layered visual effects (LÖVE2D canvas-based)
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

    -- Animation state
    self.flashTimer = 0
    self.spawnDeathEffect = false
    self.animDirty = true  -- rebuild canvas when anim state changes
    self.pulsePhase = 0

    -- Trail particles
    self.trailTimer = 0
    self.trailPoints = {}

    -- HP bar data (not rendered in canvas, drawn separately)
    self.hpRatio = 1.0

    -- Canvas
    self.canvas = love.graphics.newCanvas(C.WIDTH, C.HEIGHT)
    self:buildVisuals()

    return self
end

-- Helper: draw a hexagon at (0,0) with given radius
local function drawHex(r)
    local pts = {}
    for i = 0, 5 do
        local angle = (i / 6) * math.pi * 2 - math.pi / 6
        table.insert(pts, math.cos(angle) * r)
        table.insert(pts, math.sin(angle) * r)
    end
    love.graphics.polygon("fill", unpack(pts))
end

-- Helper: draw a hexagon outline at (0,0) with given radius
local function drawHexLine(r, sw)
    local pts = {}
    for i = 0, 5 do
        local angle = (i / 6) * math.pi * 2 - math.pi / 6
        table.insert(pts, math.cos(angle) * r)
        table.insert(pts, math.sin(angle) * r)
    end
    love.graphics.setLineWidth(sw or 1.5)
    love.graphics.polygon("line", unpack(pts))
end

-- Helper: draw a triangle at (0,0) with given size (pointing up)
local function drawTri(r)
    love.graphics.polygon("fill",
        0, -r,
        r * 0.866, r * 0.5,
        -r * 0.866, r * 0.5
    )
end

-- Helper: draw a triangle outline
local function drawTriLine(r, sw)
    love.graphics.polygon("line",
        0, -r,
        r * 0.866, r * 0.5,
        -r * 0.866, r * 0.5
    )
end

function Enemy:buildVisuals()
    local r = self.radius
    local c = self.def.color
    local cr, cg, cb = c[1], c[2], c[3]

    self.canvas:renderTo(function()
        love.graphics.clear()
        love.graphics.setBlendMode("alpha")

        -- Apply rotation centered on canvas (entity drawn at center)
        love.graphics.push()
        love.graphics.translate(C.WIDTH / 2, C.HEIGHT / 2)
        love.graphics.rotate(self.rotation)

        local flash = self.flashTimer > 0
        local fr, fg, fb = cr, cg, cb
        if flash then fr, fg, fb = 1, 1, 1 end

        -- Layer 0: outer glow
        love.graphics.setColor(fr, fg, fb, 0.06)
        love.graphics.circle("fill", 0, 0, r + 12)

        -- Layer 1: halo ring
        love.graphics.setColor(fr, fg, fb, 0.5)
        love.graphics.setLineWidth(1.5)
        love.graphics.circle("line", 0, 0, r + 6)

        -- Layer 2: pulse ring
        local pulseAlpha = 0.3 + math.sin(self.pulsePhase * 2) * 0.3
        love.graphics.setColor(fr, fg, fb, pulseAlpha)
        love.graphics.circle("line", 0, 0, r + 2)

        -- Layer 3: main body (type-specific)
        if self.typeKey == "GRUNT" then
            self:renderGrunt(fr, fg, fb, r)
        elseif self.typeKey == "TANK" then
            self:renderTank(fr, fg, fb, r)
        elseif self.typeKey == "SPEEDSTER" then
            self:renderSpeedster(fr, fg, fb, r)
        elseif self.typeKey == "BOSS" then
            self:renderBoss(fr, fg, fb, r)
        end

        love.graphics.pop()
    end)
end

function Enemy:renderGrunt(fr, fg, fb, r)
    -- Inner circle (dark center)
    love.graphics.setColor(fr * 0.4, fg * 0.4, fb * 0.4)
    love.graphics.circle("fill", 0, 0, r - 4)

    -- Main circle
    love.graphics.setColor(fr, fg, fb)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("fill", 0, 0, r - 2)
    love.graphics.setColor(1, 1, 1, 0.25)
    love.graphics.circle("line", 0, 0, r - 2)

    -- Core
    love.graphics.setColor(1, 1, 1, 0.3)
    love.graphics.circle("fill", 0, 0, r * 0.35)

    -- Orbiting dots
    for i = 1, 3 do
        local angle = (i / 3) * math.pi * 2 + self.rotation
        local dx = math.cos(angle) * (r + 4)
        local dy = math.sin(angle) * (r + 4)
        love.graphics.setColor(fr, fg, fb, 0.6)
        love.graphics.circle("fill", dx, dy, 3)
    end

    -- Chevron
    love.graphics.setColor(1, 1, 1, 0.4)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(-r * 0.4, -r * 0.2, 0, -r * 0.5, r * 0.4, -r * 0.2)
end

function Enemy:renderTank(fr, fg, fb, r)
    local size = r * 2

    -- Shield ring (rotated square)
    love.graphics.setColor(fr, fg, fb, 0.4)
    love.graphics.setLineWidth(1)
    love.graphics.push()
    love.graphics.rotate(math.pi / 4)
    love.graphics.rectangle("line", -r * 1.15, -r * 1.15, r * 2.3, r * 2.3)
    love.graphics.pop()

    -- Main square body
    love.graphics.setColor(fr, fg, fb)
    love.graphics.rectangle("fill", -r, -r, size, size)
    love.graphics.setColor(1, 1, 1, 0.2)
    love.graphics.setLineWidth(2)
    love.graphics.rectangle("line", -r, -r, size, size)

    -- Inner armor plate
    love.graphics.setColor(fr * 0.3, fg * 0.3, fb * 0.3)
    love.graphics.rectangle("fill", -r * 0.6, -r * 0.6, r * 1.2, r * 1.2)

    -- Cross pattern
    love.graphics.setColor(1, 1, 1, 0.2)
    love.graphics.setLineWidth(1.5)
    love.graphics.line(-r * 0.8, 0, r * 0.8, 0)
    love.graphics.line(0, -r * 0.8, 0, r * 0.8)

    -- Corner bolts
    love.graphics.setColor(1, 1, 1, 0.4)
    for dx = -1, 1, 2 do
        for dy = -1, 1, 2 do
            love.graphics.circle("fill", dx * r * 0.7, dy * r * 0.7, 4)
        end
    end
end

function Enemy:renderSpeedster(fr, fg, fb, r)
    -- Speed lines (behind body)
    love.graphics.setColor(fr, fg, fb, 0.3)
    love.graphics.setLineWidth(1.5)
    for i = 1, 3 do
        local yOff = (i - 2) * r * 0.5
        love.graphics.line(-r * 1.5, yOff, -r * 0.3, yOff)
    end

    -- Main triangle body
    love.graphics.setColor(fr, fg, fb)
    love.graphics.setLineWidth(1.5)
    drawTri(r)
    love.graphics.setColor(1, 1, 1, 0.25)
    drawTriLine(r, 1.5)

    -- Inner triangle
    love.graphics.setColor(fr * 0.3, fg * 0.3, fb * 0.3)
    love.graphics.polygon("fill",
        0, -r * 0.5,
        r * 0.4, r * 0.25,
        -r * 0.4, r * 0.25
    )

    -- Glowing edge overlay
    love.graphics.setColor(1, 1, 1, 0.4)
    drawTriLine(r, 1)

    -- Motion trail dots
    for i = 1, 4 do
        love.graphics.setColor(fr, fg, fb, 0.2 - i * 0.04)
        love.graphics.circle("fill", -r * 1.5 - i * 12, 0, 3 - i * 0.5)
    end
end

function Enemy:renderBoss(fr, fg, fb, r)
    -- Outer hexagonal ring
    love.graphics.setColor(fr, fg, fb, 0.4)
    love.graphics.setLineWidth(2)
    drawHexLine(r + 15, 2)

    -- Pulsing outer ring
    local bPulseScale = 1.05 + math.sin(self.pulsePhase * 1.5) * 0.1
    local bPulseAlpha = 0.15 + math.sin(self.pulsePhase * 2) * 0.1
    love.graphics.setColor(fr, fg, fb, bPulseAlpha)
    love.graphics.circle("line", 0, 0, (r + 18) * bPulseScale)

    -- Main hexagon
    love.graphics.setColor(fr * 0.6, fg * 0.4, fb * 0.8)
    drawHex(r)
    love.graphics.setColor(fr, fg, fb, 0.8)
    love.graphics.setLineWidth(2)
    drawHexLine(r, 2)

    -- Inner hexagon
    love.graphics.setColor(fr * 0.2, fg * 0.1, fb * 0.3)
    drawHex(r * 0.6)

    -- Radiating spikes (6 directions)
    love.graphics.setColor(fr, fg, fb, 0.7)
    love.graphics.setLineWidth(2)
    for i = 0, 5 do
        local angle = (i / 6) * math.pi * 2
        local spikeLen = r * 0.4
        love.graphics.line(
            math.cos(angle) * r * 0.5, math.sin(angle) * r * 0.5,
            math.cos(angle) * (r * 0.5 + spikeLen), math.sin(angle) * (r * 0.5 + spikeLen)
        )
    end

    -- Center eye
    love.graphics.setColor(1, 0, 1, 0.8)
    love.graphics.circle("fill", 0, 0, r * 0.25)
    love.graphics.setColor(1, 0, 1, 0.6)
    love.graphics.setLineWidth(1.5)
    love.graphics.circle("line", 0, 0, r * 0.35)

    -- Textured fill (radial lines)
    love.graphics.setColor(1, 1, 1, 0.1)
    love.graphics.setLineWidth(1)
    for i = 0, 2 do
        local angle = (i / 3) * math.pi * 2
        love.graphics.line(
            math.cos(angle) * r * 0.3, math.sin(angle) * r * 0.3,
            math.cos(angle) * r * 0.8, math.sin(angle) * r * 0.8
        )
    end
end

function Enemy:update(dt, slowField, evadeDx, evadeDy, evadeStrength)
    if self.dead or self.reachedEnd then return end

    -- Speed with slow field
    local speed = self.speed
    if slowField > 0 then
        speed = speed * (1 - slowField)
    end

    -- Movement along path
    local movement = (speed / self.pathLength) * dt

    -- Apply ML evasion steering (perpendicular to path)
    if evadeDx and evadeDy and evadeStrength and evadeStrength > 0 then
        -- Scale evasion by strength, cap it
        local strength = math.min(evadeStrength, 80)
        self.x = self.x + evadeDx * strength * dt
        self.y = self.y + evadeDy * strength * dt
    end
    if ml and projectiles then
        -- Get path direction at current progress
        local pathDirX, pathDirY = self:_getPathDirection()
        evadeX, evadeY = ml:computeEvasion(self, projectiles, pathDirX, pathDirY, dt)
    end

    -- Movement along path
    local movement = (speed / self.pathLength) * dt

    -- Apply ML evasion steering (small perpendicular displacement)
    -- Scale evasion to be subtle (doesn't override path following)
    local evadeScale = dt * 30
    self.progress = self.progress + movement

    if self.progress >= 1 then
        self.progress = 1
        self.reachedEnd = true
        self.x = self.waypoints[#self.waypoints].x
        self.y = self.waypoints[#self.waypoints].y
    else
        local pos = Path.getPositionAtProgress(self.progress, self.waypoints)
        self.x = pos.x + evadeX * evadeScale
        self.y = pos.y + evadeY * evadeScale
    end

    -- Clamp to screen bounds
    self.x = math.max(0, math.min(C.WIDTH, self.x))
    self.y = math.max(0, math.min(C.HEIGHT, self.y))

    -- Animation
    self.wobblePhase = self.wobblePhase + dt * 2.5
    self.pulsePhase = self.wobblePhase

    -- Wobble rotation (add evasion rotation for visual flair)
    local wobble = math.sin(self.wobblePhase) * 2.5 * math.pi / 180
    local evadeRot = (evadeX + evadeY) * 0.01  -- subtle rotation from evasion
    self.rotation = wobble + evadeRot

    -- Evasion cooldown update
    if self.evadeTimer and self.evadeTimer > 0 then
        self.evadeTimer = self.evadeTimer - dt
    end

    -- Flash timer
    if self.flashTimer > 0 then
        self.flashTimer = self.flashTimer - dt
        if self.flashTimer <= 0 then
            self.flashTimer = 0
        end
    end

    -- HP ratio
    self.hpRatio = math.max(0, self.hp / self.maxHP)

    -- Trail timer
    self.trailTimer = self.trailTimer + dt
    if self.trailTimer >= 0.05 then
        self.trailTimer = 0
        table.insert(self.trailPoints, 1, { x = self.x, y = self.y })
        if #self.trailPoints > 8 then
            table.remove(self.trailPoints)
        end
    end

    -- Rebuild visuals
    self:buildVisuals()
end

-- Get unit direction vector along path at current progress
function Enemy:_getPathDirection()
    local idx = self.waypointIdx or 1
    if idx >= #self.waypoints then
        return 1, 0  -- default forward
    end
    local wp1 = self.waypoints[idx]
    local wp2 = self.waypoints[idx + 1]
    if not wp1 or not wp2 then return 1, 0 end
    local dx = wp2.x - wp1.x
    local dy = wp2.y - wp1.y
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 1 then return 1, 0 end
    return dx / len, dy / len
end

function Enemy:takeDamage(amount)
    if self.dead then return false end
    self.hp = self.hp - amount
    self.hpRatio = math.max(0, self.hp / self.maxHP)

    -- White flash
    self.flashTimer = 0.06

    if self.hp <= 0 then
        self.dead = true
        self.spawnDeathEffect = true
        return true
    end

    -- Rebuild with flash color
    self:buildVisuals()
    return false
end

function Enemy:destroy()
    self.canvas = nil
end

return Enemy
