-- DestructionGenerator: ML-driven procedural particle burst generation.
-- When enemies die, a neural network generates the particle effect parameters
-- (count, spread, velocity, lifetime, colors) instead of using a static pattern.
-- The generator learns from demonstrated patterns and player preference data.
--
-- Architecture:
--   Input (4): enemy_type (one-hot), hp_ratio_killed, damage_source, wave_progress
--   Hidden (10): leaky ReLU
--   Output (8): particle_count_norm, spread_angle_norm, vel_magnitude_norm,
--               lifetime_norm, color_r, color_g, color_b (0-1)
--
-- Training: uses curated seed patterns + player variety feedback.

local NN = require("game.ml.NeuralNetwork")
local C = require("consts")

local DGen = {}
DGen.__index = DGen

-- ─────────────────────────────────────────────────────────────────
-- Seed patterns (demonstrated effects for initial training)
-- ─────────────────────────────────────────────────────────────────
-- Each seed: {type, hpRatio, source, waveProgress} → {count, spread, vel, life, r, g, b}
local SEEDS = {
    -- Grunt: small burst, red-orange
    { input = {1,0,0,0, 0.3, 0.5, 0.2}, target = {0.3, 0.4, 0.3, 0.3, 1.0, 0.3, 0.2} },
    { input = {1,0,0,0, 0.5, 0.5, 0.3}, target = {0.4, 0.5, 0.4, 0.35, 1.0, 0.4, 0.25} },
    { input = {1,0,0,0, 0.8, 0.5, 0.5}, target = {0.5, 0.6, 0.5, 0.4, 1.0, 0.5, 0.3} },
    -- Tank: large burst, dark red with armor shards
    { input = {0,1,0,0, 0.5, 0.5, 0.2}, target = {0.7, 0.5, 0.6, 0.5, 0.6, 0.3, 0.2} },
    { input = {0,1,0,0, 0.8, 0.5, 0.5}, target = {0.8, 0.6, 0.7, 0.6, 0.7, 0.35, 0.25} },
    -- Speedster: elongated streak, orange-yellow
    { input = {0,0,1,0, 0.5, 0.5, 0.3}, target = {0.5, 0.8, 0.6, 0.25, 1.0, 0.7, 0.2} },
    { input = {0,0,1,0, 0.9, 0.5, 0.7}, target = {0.6, 0.9, 0.8, 0.3, 1.0, 0.8, 0.25} },
    -- Boss: massive explosion, purple-pink
    { input = {0,0,0,1, 0.5, 0.5, 0.2}, target = {1.0, 0.7, 0.9, 0.7, 0.8, 0.2, 0.9} },
    { input = {0,0,0,1, 0.9, 0.5, 0.8}, target = {1.0, 0.8, 1.0, 0.8, 0.9, 0.3, 1.0} },
}

-- ─────────────────────────────────────────────────────────────────
-- Constructor
-- ─────────────────────────────────────────────────────────────────
function DGen.new()
    local self = setmetatable({}, DGen)

    -- NN: 7 inputs → 10 hidden → 7 outputs
    self.net = NN.new({7, 10, 7}, "leaky")
    self.net:init({7, 10, 7})

    -- Pre-train on seed patterns
    self:seed()

    -- Variety buffer: history of recent effects (for feedback training)
    self.choices = {}  -- {typeKey, output}
    self.maxChoices = 32

    -- Training buffer for player preference signals
    self.trainingBuffer = {}
    self.maxBuffer = 256

    -- Variability: add small random noise to output for variety
    self.noiseScale = 0.05

    -- Parameters mapping (output → game values)
    self.paramScale = {
        particleCount = {min = 6, max = 24, scale = 1},
        spreadAngle   = {min = 0.1, max = 1.2, scale = 1},  -- radians
        velMagnitude  = {min = 80, max = 400, scale = 1},
        lifetime      = {min = 0.15, max = 0.6, scale = 1},
        -- Colors are output directly (0-1)
    }

    return self
end

-- ─────────────────────────────────────────────────────────────────
-- Seed training
-- ─────────────────────────────────────────────────────────────────
function DGen:seed()
    -- Pre-train on seed patterns for a few epochs
    self.net:trainBatch(SEEDS, 0.1, 8)
end

-- ─────────────────────────────────────────────────────────────────
-- Build input feature vector
-- ─────────────────────────────────────────────────────────────────
function DGen:_buildInput(enemy, damageSource)
    -- Enemy type (one-hot: GRUNT=1, TANK=2, SPEEDSTER=3, BOSS=4)
    local oneHot = {0, 0, 0, 0}
    local typeIdx = ({GRUNT=1, TANK=2, SPEEDSTER=3, BOSS=4})[enemy.typeKey] or 1
    oneHot[typeIdx] = 1

    -- HP ratio at death (how much HP did it have when killed)
    local hpRatio = math.max(0, math.min(1, enemy.hp / math.max(1, enemy.maxHP)))

    -- Wave progress (normalized)
    local waveProg = math.min(1.0, (enemy.wave or 1) / 50.0)

    -- Damage source (proximity, projectile, splash)
    local srcNorm = ({none=0.2, splash=0.5, pierce=0.6, chain=0.8})[damageSource or "none"] or 0.2

    return {
        oneHot[1], oneHot[2], oneHot[3], oneHot[4],
        hpRatio, waveProg, srcNorm
    }
end

-- ─────────────────────────────────────────────────────────────────
-- Generate particle parameters
-- ─────────────────────────────────────────────────────────────────
function DGen:generate(enemy, damageSource)
    local input = self:_buildInput(enemy, damageSource)
    local raw = self.net:predict(input)

    -- Apply noise for variety (important for game feel)
    for i = 1, 7 do
        raw[i] = raw[i] + (math.random() - 0.5) * self.noiseScale * 2
        raw[i] = math.max(0, math.min(1, raw[i]))
    end

    -- Map to game parameters
    local ps = self.paramScale
    local particleCount = math.floor(ps.particleCount.min + raw[1] * (ps.particleCount.max - ps.particleCount.min))
    local spreadAngle   = ps.spreadAngle.min   + raw[2] * (ps.spreadAngle.max   - ps.spreadAngle.min)
    local velMagnitude  = ps.velMagnitude.min   + raw[3] * (ps.velMagnitude.max  - ps.velMagnitude.min)
    local lifetime      = ps.lifetime.min       + raw[4] * (ps.lifetime.max       - ps.lifetime.min)
    local r, g, b       = raw[5], raw[6], raw[7]

    -- Build particle list
    local particles = {}
    for i = 1, particleCount do
        local angle = (i / particleCount) * math.pi * 2 + (math.random() - 0.5) * spreadAngle
        local speedVar = velMagnitude * (0.6 + math.random() * 0.8)
        local lifeVar = lifetime * (0.7 + math.random() * 0.6)
        table.insert(particles, {
            angle    = angle,
            speed    = speedVar,
            lifetime = lifeVar,
            size     = 3 + math.random() * 5,
            r = r, g = g, b = b,
            -- Initial velocity (will be scaled in GameLoop)
            vx       = math.cos(angle) * speedVar,
            vy       = math.sin(angle) * speedVar,
        })
    end

    -- Store for feedback training
    table.insert(self.choices, {typeKey=enemy.typeKey, output=raw})
    while #self.choices > self.maxChoices do table.remove(self.choices, 1) end

    return particles
end

-- ─────────────────────────────────────────────────────────────────
-- Feedback-based training
-- ─────────────────────────────────────────────────────────────────
-- Signal types:
--   "variety" — prefer effects that differ from recent choices
--   "punch"   — big explosions on boss death
--   "sustain" — frequent variety keeps players engaged

function DGen:feedback(signal, enemyType)
    local targets = {}

    if signal == "variety" then
        -- Reward effects that differ from recent history
        -- Find the least-used recent pattern
        -- Simple: just add the seed patterns back as negative samples
        -- (this keeps the network from collapsing to a single output)
        -- Add a small random perturbation of a seed as a "new" pattern
        local seedIdx = math.random(#SEEDS)
        local noisySeed = {
            input = SEEDS[seedIdx].input,
            target = {}
        }
        for i = 1, 7 do
            noisySeed.target[i] = math.max(0, math.min(1,
                SEEDS[seedIdx].target[i] + (math.random() - 0.5) * 0.3
            ))
        end
        table.insert(self.trainingBuffer, noisySeed)

    elseif signal == "punch" then
        -- Boss punch: push output toward high values (big explosion)
        local seedIdx = math.random(#SEEDS)
        local punchTarget = {}
        for i = 1, 7 do
            punchTarget[i] = math.min(1.0, SEEDS[seedIdx].target[i] * 1.2 + 0.1)
        end
        table.insert(self.trainingBuffer, {
            input = {0, 0, 0, 1, 0.5, 0.5, 0.5},  -- boss input
            target = punchTarget
        })

    elseif signal == "sustain" then
        -- Mix of variety + punch
        for j = 1, 2 do
            local seedIdx = math.random(#SEEDS)
            local noisyTarget = {}
            for i = 1, 7 do
                noisyTarget[i] = math.max(0, math.min(1,
                    SEEDS[seedIdx].target[i] + (math.random() - 0.5) * 0.2
                ))
            end
            table.insert(self.trainingBuffer, {
                input = SEEDS[seedIdx].input,
                target = noisyTarget
            })
        end
    end

    if #self.trainingBuffer > self.maxBuffer then
        table.remove(self.trainingBuffer, 1)
    end
end

function DGen:train()
    if #self.trainingBuffer < 2 then return 0 end

    local batch = {}
    local maxSamples = math.min(#self.trainingBuffer, 16)
    for i = 1, maxSamples do
        batch[i] = self.trainingBuffer[math.random(#self.trainingBuffer)]
    end

    local loss = self.net:trainBatch(batch, 0.05, 3)
    return loss
end

-- Auto-generate feedback: call after each enemy type dies enough
function DGen:autoFeedback(enemyTypeKey, totalKilled)
    if totalKilled % 5 == 0 and totalKilled > 0 then
        self:feedback("variety", enemyTypeKey)
    end
    if totalKilled % 10 == 0 and totalKilled > 0 then
        self:feedback("sustain", enemyTypeKey)
    end
end

-- ─────────────────────────────────────────────────────────────────
-- Serialization
-- ─────────────────────────────────────────────────────────────────
function DGen:serialize()
    return {
        net = self.net:serialize(),
        trainingBuffer = self.trainingBuffer,
        noiseScale = self.noiseScale,
    }
end

function DGen.deserialize(data)
    local self = setmetatable({}, DGen)
    self.net = NN.deserialize(data.net)
    self.trainingBuffer = data.trainingBuffer or {}
    self.noiseScale = data.noiseScale or 0.05
    self.choices = {}
    self.maxChoices = 32
    self.maxBuffer = 256
    self.paramScale = {
        particleCount = {min=6, max=24, scale=1},
        spreadAngle   = {min=0.1, max=1.2, scale=1},
        velMagnitude  = {min=80, max=400, scale=1},
        lifetime      = {min=0.15, max=0.6, scale=1},
    }
    return self
end

return DGen
