-- BackgroundEffects: ambient floating particles and background animation
local C = require("consts")

local BGEffects = {}
BGEffects.__index = BGEffects

function BGEffects.new(parentGroup)
    local self = setmetatable({}, BGEffects)
    self.group = display.newGroup()
    if parentGroup then parentGroup:insert(self.group) end

    self.particles = {}
    self:spawnParticles(30)

    return self
end

function BGEffects:spawnParticles(count)
    for i = 1, count do
        local x = math.random() * C.WIDTH
        local y = math.random() * C.HEIGHT
        local size = math.random() * 2 + 1
        local alpha = math.random() * 0.15 + 0.05

        local dot = display.newCircle(self.group, x, y, size)
        dot:setFillColor(unpack(C.COLOR.TURRET))
        dot.alpha = alpha

        local speed = math.random() * 15 + 5
        local angle = math.random() * math.pi * 2
        local vx = math.cos(angle) * speed
        local vy = math.sin(angle) * speed

        local p = {
            obj = dot,
            x = x,
            y = y,
            vx = vx,
            vy = vy,
            size = size,
            baseAlpha = alpha,
            phase = math.random() * math.pi * 2,
        }
        table.insert(self.particles, p)
    end
end

function BGEffects:update(dt)
    for _, p in ipairs(self.particles) do
        p.x = p.x + p.vx * dt
        p.y = p.y + p.vy * dt

        -- Wrap around
        if p.x < -10 then p.x = C.WIDTH + 10 end
        if p.x > C.WIDTH + 10 then p.x = -10 end
        if p.y < -10 then p.y = C.HEIGHT + 10 end
        if p.y > C.HEIGHT + 10 then p.y = -10 end

        -- Twinkle
        p.phase = p.phase + dt * 1.5
        p.obj.alpha = p.baseAlpha * (0.5 + 0.5 * math.sin(p.phase))

        p.obj.x = p.x
        p.obj.y = p.y
    end
end

function BGEffects:destroy()
    for _, p in ipairs(self.particles) do
        p.obj:removeSelf()
    end
    self.particles = {}
    self.group:removeSelf()
end

return BGEffects