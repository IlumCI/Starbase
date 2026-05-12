-- DifficultyAdaptor: ML-based adaptive difficulty system.
-- Tracks player performance across waves and uses a neural network
-- to predict the optimal difficulty adjustments, keeping the player
-- in the "flow zone" (challenging but not frustrating).
--
-- Architecture:
--   Input (6): hp_ratio, wave_clear_rate (last 5 waves), dps_est, wave_number_norm, accuracy, turret_upgrade_level
--   Hidden (8, 4): leaky ReLU
--   Output (3): hp_mult_delta, speed_mult_delta, spawn_interval_delta
--
-- Training: after each wave, the outcome is labeled and the network is trained.
-- Positive outcome (survived with good HP) → reduce difficulty slightly.
-- Negative outcome (lost HP, struggled) → increase difficulty slightly.

local NN = require("game.ml.NeuralNetwork")

local Adaptor = {}
Adaptor.__index = Adaptor

-- ─────────────────────────────────────────────────────────────────
-- Constructor
-- ─────────────────────────────────────────────────────────────────
function Adaptor.new()
    local self = setmetatable({}, Adaptor)

    -- NN: 6 inputs → 8 → 4 → 3 outputs (difficulty deltas)
    self.net = NN.new({6, 8, 4, 3}, "leaky")
    self.net:init({6, 8, 4, 3})

    -- Current difficulty state
    self.hpMultiplier = 1.0      -- applied to enemy HP
    self.speedMultiplier = 1.0   -- applied to enemy speed
    self.spawnIntervalMult = 1.0 -- applied to spawn interval (higher = slower spawns)

    -- Performance history (rolling window)
    self.waveHistory = {}  -- {{hp_left, clear_time, enemies_killed, wave_num}, ...}
    self.maxHistory = 15

    -- Running stats
    self.wavesCompleted = 0
    self.totalKills = 0
    self.totalDamageTaken = 0
    self.lastWaveHP = 20  -- base HP
    self.turretUpgradeLevel = 1

    -- State: "easy" | "flow" | "hard" | "overwhelmed"
    self.state = "flow"
    self.stateConfidence = 0.5

    -- Multipliers range
    self.minHP = 0.5
    self.maxHP = 3.0
    self.minSpeed = 0.7
    self.maxSpeed = 1.5
    self.minSpawn = 0.7
    self.maxSpawn = 1.5

    -- How much the NN can change per update
    self.maxDelta = 0.15

    -- Training buffer
    self.trainingBuffer = {}
    self.maxBuffer = 128

    -- Player session stats
    self.avgHPLeft = 1.0  -- ratio of HP remaining (0-1)
    self.avgClearRate = 1.0  -- waves cleared / waves started

    -- Flow zone thresholds
    self.flowHPHigh = 0.75  -- above this: too easy
    self.flowHPLow = 0.25    -- below this: too hard
    self.flowClearRateHigh = 1.0
    self.flowClearRateLow = 0.5

    return self
end

-- ─────────────────────────────────────────────────────────────────
-- Build feature vector from current state
-- ─────────────────────────────────────────────────────────────────
function Adaptor:_buildFeatures(waveNum)
    -- Rolling average HP left (last N waves)
    local hpHistory = {}
    for i = math.max(1, #self.waveHistory - 4), #self.waveHistory do
        local entry = self.waveHistory[i]
        if entry then
            table.insert(hpHistory, entry.hpRatio or 1.0)
        end
    end
    while #hpHistory < 5 do table.insert(hpHistory, 1, 1.0) end
    local avgHP = 0
    for i = 1, 5 do avgHP = avgHP + (hpHistory[i] or 1.0) end
    avgHP = avgHP / 5

    -- Clear rate (last 10 waves)
    local clearCount = 0
    local totalCount = math.min(10, #self.waveHistory)
    for i = math.max(1, #self.waveHistory - totalCount + 1), #self.waveHistory do
        if self.waveHistory[i] and self.waveHistory[i].cleared then
            clearCount = clearCount + 1
        end
    end
    local clearRate = totalCount > 0 and (clearCount / totalCount) or 1.0

    -- DPS estimate (kills per second normalized)
    local totalTime = 0
    local totalKills = 0
    for i = 1, #self.waveHistory do
        local e = self.waveHistory[i]
        if e then
            totalTime = totalTime + (e.clearTime or 1)
            totalKills = totalKills + (e.enemiesKilled or 0)
        end
    end
    local dps = totalTime > 0 and (totalKills / totalTime) or 0
    local dpsNorm = math.min(1.0, dps / 5.0)  -- normalize (5 kills/sec = max)

    -- Wave number (difficulty naturally increases with wave)
    local waveNorm = math.min(1.0, waveNum / 100.0)

    -- Turret upgrade level
    local turretLevel = math.min(1.0, self.turretUpgradeLevel / 10.0)

    -- Accuracy (estimated: enemies killed / (enemies killed + enemies that reached end))
    local denom = self.totalKills + self.totalDamageTaken
    local accuracy = denom > 0 and (self.totalKills / denom) or 0.5
    accuracy = math.min(1.0, accuracy)

    return {
        math.max(0, math.min(1, avgHP)),
        math.max(0, math.min(1, clearRate)),
        math.max(0, math.min(1, dpsNorm)),
        math.max(0, math.min(1, waveNorm)),
        math.max(0, math.min(1, accuracy)),
        math.max(0, math.min(1, turretLevel)),
    }
end

-- ─────────────────────────────────────────────────────────────────
-- Query difficulty adjustments
-- ─────────────────────────────────────────────────────────────────
function Adaptor:getMultipliers(waveNum)
    -- Use the NN to predict delta adjustments
    local features = self:_buildFeatures(waveNum)
    local delta = self.net:predict(features)

    -- Clamp and apply to current multipliers
    local hpDelta = (delta[1] * 2 - 1) * self.maxDelta
    local speedDelta = (delta[2] * 2 - 1) * self.maxDelta
    local spawnDelta = (delta[3] * 2 - 1) * self.maxDelta * 0.5  -- spawn is gentler

    self.hpMultiplier = math.max(self.minHP, math.min(self.maxHP,
        self.hpMultiplier + hpDelta))
    self.speedMultiplier = math.max(self.minSpeed, math.min(self.maxSpeed,
        self.speedMultiplier + speedDelta))
    self.spawnIntervalMult = math.max(self.minSpawn, math.min(self.maxSpawn,
        self.spawnIntervalMult + spawnDelta))

    return {
        hpMultiplier = self.hpMultiplier,
        speedMultiplier = self.speedMultiplier,
        spawnIntervalMult = self.spawnIntervalMult,
    }
end

-- Current multipliers (without querying NN)
function Adaptor:currentMultipliers()
    return {
        hpMultiplier = self.hpMultiplier,
        speedMultiplier = self.speedMultiplier,
        spawnIntervalMult = self.spawnIntervalMult,
    }
end

-- ─────────────────────────────────────────────────────────────────
-- Record wave outcome and train
-- ─────────────────────────────────────────────────────────────────
function Adaptor:recordWave(waveNum, cleared, hpLeft, maxHP, enemiesKilled, clearTime, enemiesReachedEnd)
    local hpRatio = maxHP > 0 and math.max(0, math.min(1, hpLeft / maxHP)) or 0

    -- Determine outcome quality
    local quality
    if not cleared then
        quality = 0.0  -- wave failed
    elseif hpRatio > self.flowHPHigh then
        quality = 0.2  -- too easy — reduce difficulty target
    elseif hpRatio < self.flowHPLow then
        quality = 0.8  -- too hard — increase difficulty target
    else
        quality = 0.5  -- flow zone
    end

    -- Record in history
    table.insert(self.waveHistory, {
        cleared = cleared,
        hpRatio = hpRatio,
        enemiesKilled = enemiesKilled or 0,
        clearTime = clearTime or 1,
        waveNum = waveNum,
        enemiesReachedEnd = enemiesReachedEnd or 0,
    })
    while #self.waveHistory > self.maxHistory do
        table.remove(self.waveHistory, 1)
    end

    -- Update running stats
    self.wavesCompleted = cleared and (self.wavesCompleted + 1) or self.wavesCompleted
    self.totalKills = self.totalKills + (enemiesKilled or 0)
    self.totalDamageTaken = self.totalDamageTaken + (enemiesReachedEnd or 0)
    self.lastWaveHP = hpLeft

    -- Update rolling averages
    local n = #self.waveHistory
    self.avgHPLeft = 0
    self.avgClearRate = 0
    for i = 1, n do
        self.avgHPLeft = self.avgHPLeft + (self.waveHistory[i].hpRatio or 0)
        self.avgClearRate = self.avgClearRate + (self.waveHistory[i].cleared and 1 or 0)
    end
    self.avgHPLeft = self.avgHPLeft / math.max(1, n)
    self.avgClearRate = self.avgClearRate / math.max(1, n)

    -- Update state
    self.state = self:_computeState()

    -- Record training sample
    self:_recordTrainingSample(waveNum, quality)

    -- Train NN
    self:train()
end

function Adaptor:_computeState()
    local hp = self.avgHPLeft
    local cr = self.avgClearRate

    if cr < 0.3 then return "overwhelmed" end
    if hp < self.flowHPLow and cr < 0.7 then return "hard" end
    if hp > self.flowHPHigh and cr >= 1.0 then return "easy" end
    return "flow"
end

function Adaptor:_recordTrainingSample(waveNum, quality)
    local features = self:_buildFeatures(waveNum)

    -- Target: if quality is low (player struggling) → want higher multipliers
    -- if quality is high (player succeeding) → want lower multipliers
    -- Output is normalized delta [0,1], want higher delta when struggling
    local hpTarget = quality
    local speedTarget = quality
    local spawnTarget = quality

    -- Add some noise to targets for exploration
    local function addNoise(v)
        return math.max(0, math.min(1, v + (math.random() - 0.5) * 0.1))
    end

    table.insert(self.trainingBuffer, {
        input = features,
        target = {addNoise(hpTarget), addNoise(speedTarget), addNoise(spawnTarget)}
    })

    while #self.trainingBuffer > self.maxBuffer do
        table.remove(self.trainingBuffer, 1)
    end
end

function Adaptor:train()
    if #self.trainingBuffer < 4 then return 0 end

    local batch = {}
    local maxSamples = math.min(#self.trainingBuffer, 16)
    for i = 1, maxSamples do
        batch[i] = self.trainingBuffer[math.random(#self.trainingBuffer)]
    end

    local loss = self.net:trainBatch(batch, 0.05, 3)
    return loss
end

-- ─────────────────────────────────────────────────────────────────
-- Tuning: expose current state for UI/debug
-- ─────────────────────────────────────────────────────────────────
function Adaptor:getState()
    return {
        state = self.state,
        hpMultiplier = self.hpMultiplier,
        speedMultiplier = self.speedMultiplier,
        spawnIntervalMult = self.spawnIntervalMult,
        wavesCompleted = self.wavesCompleted,
        avgHPLeft = self.avgHPLeft,
        avgClearRate = self.avgClearRate,
        trainingSamples = #self.trainingBuffer,
    }
end

-- Call when player upgrades turrets (increases difficulty)
function Adaptor:onTurretUpgrade(level)
    self.turretUpgradeLevel = level
    -- When player gets stronger, nudge difficulty slightly higher
    self.hpMultiplier = math.min(self.maxHP, self.hpMultiplier * 1.05)
    self.speedMultiplier = math.min(self.maxSpeed, self.speedMultiplier * 1.03)
end

-- Reset for new run
function Adaptor:reset()
    self.hpMultiplier = 1.0
    self.speedMultiplier = 1.0
    self.spawnIntervalMult = 1.0
    self.waveHistory = {}
    self.wavesCompleted = 0
    self.totalKills = 0
    self.totalDamageTaken = 0
    self.avgHPLeft = 1.0
    self.avgClearRate = 1.0
    self.state = "flow"
end

-- ─────────────────────────────────────────────────────────────────
-- Serialization
-- ─────────────────────────────────────────────────────────────────
function Adaptor:serialize()
    return {
        net = self.net:serialize(),
        hpMultiplier = self.hpMultiplier,
        speedMultiplier = self.speedMultiplier,
        spawnIntervalMult = self.spawnIntervalMult,
        waveHistory = self.waveHistory,
        trainingBuffer = self.trainingBuffer,
        wavesCompleted = self.wavesCompleted,
        totalKills = self.totalKills,
        totalDamageTaken = self.totalDamageTaken,
        turretUpgradeLevel = self.turretUpgradeLevel,
        avgHPLeft = self.avgHPLeft,
        avgClearRate = self.avgClearRate,
    }
end

function Adaptor.deserialize(data)
    local self = setmetatable({}, Adaptor)
    self.net = NN.deserialize(data.net)
    self.hpMultiplier = data.hpMultiplier or 1.0
    self.speedMultiplier = data.speedMultiplier or 1.0
    self.spawnIntervalMult = data.spawnIntervalMult or 1.0
    self.waveHistory = data.waveHistory or {}
    self.trainingBuffer = data.trainingBuffer or {}
    self.wavesCompleted = data.wavesCompleted or 0
    self.totalKills = data.totalKills or 0
    self.totalDamageTaken = data.totalDamageTaken or 0
    self.turretUpgradeLevel = data.turretUpgradeLevel or 1
    self.avgHPLeft = data.avgHPLeft or 1.0
    self.avgClearRate = data.avgClearRate or 1.0
    self.maxHistory = 15
    self.maxBuffer = 128
    self.maxDelta = 0.15
    self.minHP = 0.5
    self.maxHP = 3.0
    self.minSpeed = 0.7
    self.maxSpeed = 1.5
    self.minSpawn = 0.7
    self.maxSpawn = 1.5
    self.flowHPHigh = 0.75
    self.flowHPLow = 0.25
    self.state = "flow"
    self.stateConfidence = 0.5
    return self
end

return Adaptor
