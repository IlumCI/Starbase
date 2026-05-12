-- TurretTargeting: Neural network-based multi-factor target selection.
-- Replaces simple closest-first with learned multi-objective scoring.
-- Features: distance, HP ratio, path progress, enemy type, threat, value.
-- Trains online: after each wave, scores are evaluated and the network is trained.

local NN = require("game.ml.NeuralNetwork")
local C = require("consts")

local Targeting = {}
Targeting.__index = Targeting

-- Enemy type one-hot encoding (index 1-4)
local TYPE_MAP = { GRUNT = 1, TANK = 2, SPEEDSTER = 3, BOSS = 4 }
local TYPE_COUNT = 4

-- Input feature count
local N_FEATURES = 6

-- ─────────────────────────────────────────────────────────────────
-- Constructor
-- ─────────────────────────────────────────────────────────────────
function Targeting.new()
    local self = setmetatable({}, Targeting)

    -- NN: 6 inputs → 12 hidden (leaky ReLU) → 1 output (score)
    self.net = NN.new({N_FEATURES, 12, 1}, "leaky")
    self.net:init({N_FEATURES, 12, 1})

    -- Training buffer: each entry = {input, target}
    -- where target = 1.0 (good) or 0.0 (bad) based on wave outcome
    self.trainingBuffer = {}

    -- Rolling stats for online normalization
    self.maxEnemyHP = 300   -- boss baseline, will grow with waves
    self.maxPathProgress = 1.0

    -- Hyperparameters
    self.lr = 0.02
    self.batchSize = 16
    self.epochsPerUpdate = 3

    -- Heuristic fallback weights (used before network is trained enough)
    self.heurWeights = {
        distance = 1.0,
        hpRatio  = 0.3,
        progress = 2.0,
        typeBonus = { BOSS = 1.5, TANK = 1.2, SPEEDSTER = 1.0, GRUNT = 0.8 },
        threat = 1.0,
        value = 0.5,
    }

    return self
end

-- ─────────────────────────────────────────────────────────────────
-- Feature extraction
-- ─────────────────────────────────────────────────────────────────
function Targeting:_extractFeatures(enemy, turret, range)
    local def = enemy.def
    local typeIdx = TYPE_MAP[enemy.typeKey] or 1

    -- 1. Normalized distance (0=close, 1=far)
    local dx = enemy.x - turret.x
    local dy = enemy.y - turret.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local normDist = math.max(0, math.min(1, dist / math.max(1, range)))

    -- 2. HP ratio (0=dying, 1=full)
    local hpRatio = math.max(0, enemy.hp / math.max(1, self.maxEnemyHP))

    -- 3. Path progress (0=start, 1=end — higher = more urgent)
    local progress = math.max(0, math.min(1, enemy.progress))

    -- 4. Enemy type (one-hot encoding)
    local typeOneHot = {0, 0, 0, 0}
    typeOneHot[typeIdx] = 1.0

    -- 5. Threat: HP / remaining path distance (urgency proxy)
    local remainingPath = math.max(0.01, 1.0 - enemy.progress)
    local threat = math.min(3.0, (enemy.hp / math.max(1, self.maxEnemyHP)) / remainingPath)

    -- 6. Value: normalized XP reward
    local maxVal = 100  -- boss baseline
    local value = (def.xpValue + def.goldValue * 0.1) / maxVal

    return {
        normDist,
        math.max(0, math.min(1, hpRatio)),
        progress,
        typeOneHot[1],
        typeOneHot[2],
        typeOneHot[3],
        -- typeOneHot[4] (boss) = 1 - sum(other 3)
        1.0 - typeOneHot[1] - typeOneHot[2] - typeOneHot[3],
        threat / 3.0,
        value,
    }
    -- Note: we return 9 values but network expects 6.
    -- Compress: combine type into 1 float encoding + threat + value.
    -- Revised feature vector (6 values):
end

function Targeting:_buildFeatureVector(enemy, turret, range)
    local def = enemy.def
    local typeIdx = TYPE_MAP[enemy.typeKey] or 1

    -- 1. Normalized distance (0=close, 1=far)
    local dx = enemy.x - turret.x
    local dy = enemy.y - turret.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local normDist = math.max(0, math.min(1, dist / math.max(1, range)))

    -- 2. HP ratio (0=dying, 1=full)
    local hpRatio = math.max(0, math.min(1, enemy.hp / math.max(1, self.maxEnemyHP)))

    -- 3. Path progress (0=start, 1=near end)
    local progress = math.max(0, math.min(1, enemy.progress))

    -- 4. Type encoding as single float (1-4 normalized)
    local typeNorm = typeIdx / TYPE_COUNT

    -- 5. Threat (HP / remaining distance — urgency)
    local remainingPath = math.max(0.01, 1.0 - enemy.progress)
    local threat = math.min(2.0, (enemy.hp / math.max(1, self.maxEnemyHP)) / remainingPath) / 2.0

    -- 6. Value (XP + gold normalized)
    local value = math.min(1.0, (def.xpValue + def.goldValue * 0.1) / 110.0)

    return {normDist, hpRatio, progress, typeNorm, threat, value}
end

-- ─────────────────────────────────────────────────────────────────
-- Scoring
-- ─────────────────────────────────────────────────────────────────

-- Score an enemy using the neural network (inference)
function Targeting:scoreEnemyNN(enemy, turret, range)
    local feat = self:_buildFeatureVector(enemy, turret, range)
    local score = self.net:predict(feat)[1]
    return score
end

-- Heuristic fallback score (blended in for early game)
function Targeting:scoreEnemyHeuristic(enemy, turret, range)
    local dx = enemy.x - turret.x
    local dy = enemy.y - turret.y
    local dist = math.sqrt(dx * dx + dy * dy)
    local w = self.heurWeights

    if dist > range then return -1 end

    local remainingPath = math.max(0.01, 1.0 - enemy.progress)
    local typeBonus = w.typeBonus[enemy.typeKey] or 1.0
    local threat = (enemy.hp / math.max(1, self.maxEnemyHP)) / remainingPath

    local score =
        -w.distance * (dist / range) +
        -w.hpRatio * (1 - enemy.hp / math.max(1, enemy.maxHP)) +
        w.progress * enemy.progress +
        (typeBonus - 1.0) * 0.5 +
        w.threat * math.min(2, threat) / 2.0 +
        w.value * ((enemy.def.xpValue + enemy.def.goldValue * 0.1) / 110.0)

    return score
end

-- Blend: NN score + heuristic (more NN as training buffer grows)
function Targeting:scoreEnemy(enemy, turret, range, blendFactor)
    blendFactor = blendFactor or 0.5
    local nnScore = self:scoreEnemyNN(enemy, turret, range)
    local heurScore = self:scoreEnemyHeuristic(enemy, turret, range)
    return blendFactor * nnScore + (1 - blendFactor) * heurScore
end

-- ─────────────────────────────────────────────────────────────────
-- Target selection
-- ─────────────────────────────────────────────────────────────────
function Targeting:selectTarget(enemies, turret, range)
    local best = nil
    local bestScore = -math.huge

    local blend = self:getBlendFactor()

    for _, enemy in ipairs(enemies) do
        if not enemy.dead and not enemy.reachedEnd then
            local dx = enemy.x - turret.x
            local dy = enemy.y - turret.y
            local dist = math.sqrt(dx * dx + dy * dy)
            if dist <= range then
                local score = self:scoreEnemy(enemy, turret, range, blend)
                if score > bestScore then
                    bestScore = score
                    best = enemy
                end
            end
        end
    end

    return best, bestScore
end

-- How much to trust the NN vs heuristic (0→1 as buffer grows)
function Targeting:getBlendFactor()
    local bufSize = #self.trainingBuffer
    if bufSize < 8 then return 0.0 end
    if bufSize < 32 then return 0.3 end
    if bufSize < 64 then return 0.6 end
    return math.min(0.9, 0.6 + (bufSize - 64) * 0.002)
end

-- ─────────────────────────────────────────────────────────────────
-- Online training: collect samples and periodically train
-- ─────────────────────────────────────────────────────────────────

-- Call after wave ends: evaluate targets and fill training buffer.
-- For each enemy killed, score = kill_quality (how good that choice was).
function Targeting:recordWaveResults(kills, wave, turret)
    -- kills: array of {enemy, killWaveTime} — ordered by kill time
    -- turret: reference turret that made the kills (for feature extraction)
    -- We'll generate training samples: if an enemy was killed quickly and
    -- contributed to wave clear, that's a good target → score = 1.
    -- If enemy reached end, the choice was bad → score = 0.

    local waveQuality = 1.0  -- base
    local enemiesKilled = #kills

    for i, entry in ipairs(kills) do
        local enemy = entry.enemy
        local reached = entry.reachedEnd or false
        local feat = self:_buildFeatureVector(enemy, turret, turret.range)

        -- Target quality:
        -- - Good (1.0): killed enemies, especially fast ones
        -- - Bad (0.0): enemies that reached the end
        local target
        if reached then
            target = 0.0  -- bad choice — let it through
        else
            -- Good choice: killed an enemy.
            -- Reward high-threat, high-value, progressed enemies.
            local remainingPath = math.max(0.01, 1.0 - enemy.progress)
            local threat = (enemy.hp / math.max(1, self.maxEnemyHP)) / remainingPath
            local value = (enemy.def.xpValue + enemy.def.goldValue * 0.1) / 110.0
            local progressBonus = enemy.progress * 0.5
            target = math.min(1.0, math.max(0.0,
                (threat / 3.0) * 0.4 +
                value * 0.3 +
                progressBonus +
                0.3  -- baseline reward for any kill
            ))
        end

        table.insert(self.trainingBuffer, { input = feat, target = {target} })

        -- Cap buffer size
        if #self.trainingBuffer > 512 then
            table.remove(self.trainingBuffer, 1)
        end
    end
end

-- Call periodically (e.g., every wave clear) to train the network
function Targeting:train()
    if #self.trainingBuffer < 4 then return 0 end

    -- Shuffle a sample from the buffer
    local batch = {}
    local maxSamples = math.min(#self.trainingBuffer, self.batchSize)
    local indices = {}
    for i = 1, #self.trainingBuffer do indices[i] = i end
    -- Fisher-Yates shuffle first maxSamples indices
    for i = maxSamples, 2, -1 do
        local j = math.random(i)
        indices[i], indices[j] = indices[j], indices[i]
    end
    for i = 1, maxSamples do
        batch[i] = self.trainingBuffer[indices[i]]
    end

    local loss = self.net:trainBatch(batch, self.lr, self.epochsPerUpdate)
    return loss
end

-- Call when a new enemy type is encountered (boss HP scaling)
function Targeting:updateMaxHP(maxHP)
    self.maxEnemyHP = math.max(self.maxEnemyHP, maxHP)
end

-- ─────────────────────────────────────────────────────────────────
-- Serialization
-- ─────────────────────────────────────────────────────────────────
function Targeting:serialize()
    return {
        net = self.net:serialize(),
        trainingBuffer = self.trainingBuffer,
        maxEnemyHP = self.maxEnemyHP,
        lr = self.lr,
    }
end

function Targeting.deserialize(data)
    local self = setmetatable({}, Targeting)
    self.net = NN.deserialize(data.net)
    self.trainingBuffer = data.trainingBuffer or {}
    self.maxEnemyHP = data.maxEnemyHP or 300
    self.lr = data.lr or 0.02
    self.heurWeights = {
        distance = 1.0,
        hpRatio  = 0.3,
        progress = 2.0,
        typeBonus = { BOSS = 1.5, TANK = 1.2, SPEEDSTER = 1.0, GRUNT = 0.8 },
        threat = 1.0,
        value = 0.5,
    }
    return self
end

return Targeting
