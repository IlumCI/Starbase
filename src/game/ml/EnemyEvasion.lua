-- EnemyEvasion: ML-driven evasion for enemies.
-- Enemies follow a fixed path, but when projectiles are nearby they
-- use a neural network to compute an evasion steering force.
-- The network learns: which nearby projectiles are actually threatening,
-- and in which direction to steer to maximize survival.
--
-- Architecture:
--   Input (4): nearest_threat_dist (norm), threat_count, projectile_density, enemy_speed_norm
--   Hidden (8): leaky ReLU
--   Output (2): evasion direction (dx, dy) normalized
--
-- Training: when enemy dies to projectile → negative sample.
--          when enemy survives wave with projectiles nearby → positive sample.

local NN = require("game.ml.NeuralNetwork")

local Evasion = {}
Evasion.__index = Evasion

-- ─────────────────────────────────────────────────────────────────
-- Constructor
-- ─────────────────────────────────────────────────────────────────
function Evasion.new()
    local self = setmetatable({}, Evasion)

    -- NN: 4 inputs → 8 hidden → 2 outputs (evasion direction)
    self.net = NN.new({4, 8, 2}, "leaky")
    self.net:init({4, 8, 2})

    -- Perception range (how far enemies can "see" projectiles)
    self.perceptionRange = 120

    -- Steering strength multiplier
    self.steerStrength = 60.0

    -- Training buffer: {input, target} pairs
    self.trainingBuffer = {}
    self.maxBuffer = 512
    self.batchSize = 16
    self.lr = 0.05

    -- Survival stats per enemy type
    self.typeSurvival = {}  -- typeKey → {survived=0, died=0}

    -- Enable/disable per enemy type
    self.enabledFor = { SPEEDSTER = true, GRUNT = true, TANK = false, BOSS = false }

    -- Cooldown per enemy (don't evade every frame)
    self.evadeCooldown = 0.3  -- seconds between evasion decisions

    -- Heuristic fallback when NN isn't ready
    self.fallbackStrength = 0.3  -- weak steering factor

    return self
end

-- ─────────────────────────────────────────────────────────────────
-- Feature extraction from game state
-- ─────────────────────────────────────────────────────────────────

-- Gather features for an enemy given nearby projectiles
function Evasion:_extractFeatures(enemy, projectiles)
    local maxDist = self.perceptionRange
    local projCount = 0
    local minDist = maxDist
    local totalDist = 0
    local avgVx = 0
    local avgVy = 0
    local headingX = 0
    local headingY = 0

    for _, proj in ipairs(projectiles) do
        if not proj.dead then
            local dx = proj.x - enemy.x
            local dy = proj.y - enemy.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist < maxDist then
                projCount = projCount + 1
                minDist = math.min(minDist, dist)
                totalDist = totalDist + dist
                -- Projectile velocity (estimated)
                if proj.trail and #proj.trail >= 2 then
                    local t1 = proj.trail[1]
                    local t2 = proj.trail[2]
                    if t1 and t2 then
                        avgVx = avgVx + (t1.x - t2.x) * 10  -- approx vx
                        avgVy = avgVy + (t1.y - t2.y) * 10
                    end
                end
            end
        end
    end

    if projCount == 0 then
        return nil  -- no threats, no evasion needed
    end

    local avgDist = totalDist / projCount
    local density = projCount / 8.0  -- normalize (assume max ~8 nearby)

    -- Normalized nearest threat distance (0=very close, 1=at perception edge)
    local nearestNorm = math.max(0, math.min(1, minDist / maxDist))

    -- Enemy speed normalized (speedster=1.0, tank=0.5, boss=0.2)
    local maxSpeed = 5.0
    local speedNorm = math.min(1.0, (enemy.speed or 2.0) / maxSpeed)

    -- Projectile density
    local densityNorm = math.min(1.0, density)

    -- Threat approach speed (are projectiles closing in?)
    local approachSpeed = math.sqrt(avgVx * avgVx + avgVy * avgVy) / 800.0
    approachSpeed = math.min(1.0, approachSpeed)

    return {
        nearestNorm,
        densityNorm,
        speedNorm,
        approachSpeed,
    }
end

-- Compute evasion direction from NN output
function Evasion:_nnToDirection(nnOutput)
    local dx = nnOutput[1] * 2 - 1  -- [0,1] → [-1,1]
    local dy = nnOutput[2] * 2 - 1
    local len = math.sqrt(dx * dx + dy * dy)
    if len < 0.001 then return 0, 0 end
    return dx / len, dy / len
end

-- ─────────────────────────────────────────────────────────────────
-- Main: compute evasion steering for one enemy
-- ─────────────────────────────────────────────────────────────────
function Evasion:computeEvasion(enemy, projectiles, pathDirX, pathDirY, dt)
    if not self.enabledFor[enemy.typeKey] then
        return 0, 0
    end

    local feat = self:_extractFeatures(enemy, projectiles)
    if not feat then return 0, 0 end

    -- Cooldown check
    if (enemy.evadeTimer or 0) > 0 then
        return 0, 0
    end

    -- Query NN for evasion direction
    local blendFactor = self:getBlendFactor()
    local nnDirX, nnDirY = 0, 0
    if blendFactor > 0 then
        local nnOut = self.net:predict(feat)
        nnDirX, nnDirY = self:_nnToDirection(nnOut)
    end

    -- Heuristic fallback: steer perpendicular to path
    local perpX = -pathDirY
    local perpY = pathDirX

    -- Determine which side has fewer threats
    local rightX = pathDirY  -- 90° clockwise from path
    local rightY = -pathDirX
    local leftX = -pathDirY  -- 90° counter-clockwise
    local leftY = pathDirX

    local rightThreat = 0
    local leftThreat = 0
    for _, proj in ipairs(projectiles) do
        if not proj.dead then
            local dx = proj.x - enemy.x
            local dy = proj.y - enemy.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist < self.perceptionRange then
                local dotR = dx * rightX + dy * rightY
                local dotL = dx * leftX + dy * leftY
                local weight = 1.0 / math.max(1, dist)
                rightThreat = rightThreat + math.max(0, dotR) * weight
                leftThreat = leftThreat + math.max(0, dotL) * weight
            end
        end
    end

    local heurDirX, heurDirY
    if rightThreat < leftThreat then
        heurDirX, heurDirY = rightX, rightY
    else
        heurDirX, heurDirY = leftX, leftY
    end

    -- Blend
    local evDirX = blendFactor * nnDirX + (1 - blendFactor) * heurDirX
    local evDirY = blendFactor * nnDirY + (1 - blendFactor) * heurDirY
    local evLen = math.sqrt(evDirX * evDirX + evDirY * evDirY)
    if evLen < 0.001 then return 0, 0 end
    evDirX, evDirY = evDirX / evLen, evDirY / evLen

    -- Evasion strength based on how close the nearest threat is
    local threatIntensity = 1.0 - feat[1]  -- 0=far, 1=close
    local strength = self.steerStrength * threatIntensity * (0.3 + blendFactor * 0.7)

    -- Apply cooldown
    enemy.evadeTimer = self.evadeCooldown + math.random() * 0.1

    return evDirX * strength, evDirY * strength
end

function Evasion:getBlendFactor()
    local n = #self.trainingBuffer
    if n < 8 then return 0.0 end
    if n < 32 then return 0.3 end
    return math.min(0.85, 0.3 + (n - 32) * 0.005)
end

-- ─────────────────────────────────────────────────────────────────
-- Record outcome for training
-- ─────────────────────────────────────────────────────────────────
function Evasion:recordOutcome(enemy, projectiles, survived)
    local feat = self:_extractFeatures(enemy, projectiles)
    if not feat then return end

    -- Build target: if survived → prefer the evasion direction that was used
    -- (we just record that this situation was navigated)
    -- If died → the evasion was insufficient → target = reduce intensity
    local target
    if survived then
        -- Survived: mark this as a situation that can be navigated
        target = {1.0, 1.0}
    else
        -- Died to projectile: negative outcome
        target = {0.0, 0.0}
    end

    table.insert(self.trainingBuffer, { input = feat, target = target })

    if #self.trainingBuffer > self.maxBuffer then
        table.remove(self.trainingBuffer, 1)
    end

    -- Track per-type survival
    if not self.typeSurvival[enemy.typeKey] then
        self.typeSurvival[enemy.typeKey] = {survived = 0, died = 0}
    end
    if survived then
        self.typeSurvival[enemy.typeKey].survived = self.typeSurvival[enemy.typeKey].survived + 1
    else
        self.typeSurvival[enemy.typeKey].died = self.typeSurvival[enemy.typeKey].died + 1
    end

    -- Enable evasion for types that are dying frequently
    local s = self.typeSurvival[enemy.typeKey]
    if s and s.died > 0 and s.died / (s.survived + s.died) > 0.4 then
        self.enabledFor[enemy.typeKey] = true
    end
end

-- Call periodically to train the network
function Evasion:train()
    if #self.trainingBuffer < 4 then return 0 end

    local batch = {}
    local maxSamples = math.min(#self.trainingBuffer, self.batchSize)
    for i = 1, maxSamples do
        batch[i] = self.trainingBuffer[math.random(#self.trainingBuffer)]
    end

    local loss = self.net:trainBatch(batch, self.lr, 3)
    return loss
end

-- Update cooldown timers (call each frame)
function Evasion:update(dt)
    -- Nothing to do here; cooldown is per-enemy
end

-- ─────────────────────────────────────────────────────────────────
-- Serialization
-- ─────────────────────────────────────────────────────────────────
function Evasion:serialize()
    return {
        net = self.net:serialize(),
        trainingBuffer = self.trainingBuffer,
        typeSurvival = self.typeSurvival,
        enabledFor = self.enabledFor,
        steerStrength = self.steerStrength,
        perceptionRange = self.perceptionRange,
    }
end

function Evasion.deserialize(data)
    local self = setmetatable({}, Evasion)
    self.net = NN.deserialize(data.net)
    self.trainingBuffer = data.trainingBuffer or {}
    self.typeSurvival = data.typeSurvival or {}
    self.enabledFor = data.enabledFor or { SPEEDSTER = true, GRUNT = true, TANK = false, BOSS = false }
    self.steerStrength = data.steerStrength or 60.0
    self.perceptionRange = data.perceptionRange or 120
    self.maxBuffer = 512
    self.batchSize = 16
    self.lr = 0.05
    self.evadeCooldown = 0.3
    self.fallbackStrength = 0.3
    return self
end

return Evasion
