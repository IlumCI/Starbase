-- ProjectileTrajectory: ML-based lead targeting for turrets.
-- Enemies follow waypoints but deviate slightly; fast enemies (Speedster)
-- are hard to hit with naive aim. This module:
--   1. Tracks enemy position history (sliding window)
--   2. Uses a small NN to predict velocity + acceleration
--   3. Computes the intercept point so turrets fire *ahead* of targets
--   4. Trained online: hit/miss feedback updates the predictor.

local NN = require("game.ml.NeuralNetwork")
local C = require("consts")

local Trajectory = {}
Trajectory.__index = Trajectory

-- ─────────────────────────────────────────────────────────────────
-- Per-enemy tracking entry
-- ─────────────────────────────────────────────────────────────────
local function newTracker()
    return {
        positions = {},      -- {{x,y}, ...} ring buffer, newest last
        velocities = {},     -- {vx, vy} ring buffer
        vx_ema = 0,          -- exponential moving average vx
        vy_ema = 0,          -- EMA vy
        ax_ema = 0,          -- EMA acceleration x
        ay_ema = 0,          -- EMA acceleration y
        speed_ema = 0,
        hitCount = 0,
        missCount = 0,
    }
end

-- ─────────────────────────────────────────────────────────────────
-- Constructor
-- ─────────────────────────────────────────────────────────────────
function Trajectory.new()
    local self = setmetatable({}, Trajectory)

    -- Per-enemy position trackers (indexed by enemy object)
    self.trackers = {}

    -- Lead factor: how much to lead targets (0=naive aim, 1=max lead)
    -- Learns from hit/miss feedback
    self.leadFactor = 0.5

    -- NN: predicts correction to naive intercept based on:
    --   - enemy speed (normalized)
    --   - distance to target (normalized)
    --   - recent accuracy (hit rate over last N shots)
    -- Output: correction factor (multiplier on naive lead time)
    self.correctionNet = NN.new({3, 6, 1}, "leaky")
    self.correctionNet:init({3, 6, 1})

    -- Accuracy history ring buffer
    self.accuracyWindow = {}
    self.maxAccuracyHistory = 20

    -- Hyperparameters
    self.emaAlpha = 0.4   -- smoothing factor for velocity EMA
    self.historyLen = 6   -- keep last N positions for prediction
    self.maxCorrection = 2.5  -- clamp correction factor

    -- Training buffer: {input, target} pairs
    self.trainingBuffer = {}
    self.batchSize = 12
    self.lr = 0.03

    -- Debug: track average prediction error
    self.avgHitImprovement = 0
    self.hitSamples = 0

    return self
end

-- ─────────────────────────────────────────────────────────────────
-- Tracker management
-- ─────────────────────────────────────────────────────────────────
function Trajectory:getTracker(enemy)
    return self.trackers[enemy]
end

function Trajectory:ensureTracker(enemy)
    if not self.trackers[enemy] then
        self.trackers[enemy] = newTracker()
    end
    return self.trackers[enemy]
end

function Trajectory:removeTracker(enemy)
    self.trackers[enemy] = nil
end

-- Called every frame per enemy
function Trajectory:updateEnemy(enemy, dt)
    local t = self:ensureTracker(enemy)

    -- Add current position
    table.insert(t.positions, { x = enemy.x, y = enemy.y, t = love.timer.getTime() or 0 })

    -- Keep ring buffer at historyLen
    while #t.positions > self.historyLen do
        table.remove(t.positions, 1)
    end

    -- Need at least 2 positions to compute velocity
    if #t.positions < 2 then return end

    -- Compute velocity from last 2 positions
    local pos1 = t.positions[#t.positions - 1]
    local pos2 = t.positions[#t.positions]
    local dt_pos = math.max(0.001, (pos2.t or dt) - (pos1.t or 0))
    local vx = (pos2.x - pos1.x) / dt_pos
    local vy = (pos2.y - pos1.y) / dt_pos
    local speed = math.sqrt(vx * vx + vy * vy)

    -- Update EMA
    local a = self.emaAlpha
    t.vx_ema = t.vx_ema * (1 - a) + vx * a
    t.vy_ema = t.vy_ema * (1 - a) + vy * a
    t.speed_ema = t.speed_ema * (1 - a) + speed * a

    -- Acceleration (change in velocity)
    if #t.velocities > 0 then
        local prev = t.velocities[#t.velocities]
        local ax = vx - prev.vx
        local ay = vy - prev.vy
        t.ax_ema = t.ax_ema * (1 - a) + ax * a
        t.ay_ema = t.ay_ema * (1 - a) + ay * a
    end

    table.insert(t.velocities, { vx = vx, vy = vy, speed = speed })
    while #t.velocities > self.historyLen - 1 do
        table.remove(t.velocities, 1)
    end
end

-- ─────────────────────────────────────────────────────────────────
-- Intercept calculation
-- ─────────────────────────────────────────────────────────────────

-- Solve the quadratic intercept equation:
--   |(turretPos + dir * projSpeed * t) - (enemyPos + vel * t)|^2 = r^2
-- where dir is the normalized direction from turret to predicted intercept.
-- We simplify by assuming direction ~= enemy velocity direction (small angle).
--
-- Returns: predicted intercept position {x, y}, or nil if no intercept possible.
function Trajectory:computeIntercept(turretX, turretY, enemy, projSpeed)
    local t = self.trackers[enemy]
    if not t or #t.positions < 2 then
        return enemy.x, enemy.y
    end

    -- Use EMA velocity as prediction
    local evx = t.vx_ema
    local evy = t.vy_ema

    -- Enemy predicted position at time t (simple linear extrapolation)
    -- (enemy already at its current position)
    local ex = enemy.x
    local ey = enemy.y

    -- Relative position
    local rx = ex - turretX
    local ry = ey - turretY

    -- Relative velocity (enemy minus projectile)
    -- We're solving: |R + (v_e - v_p) * t|^2 = 0  (for exact intercept)
    -- where v_p = projSpeed * (R / |R|) at intercept
    -- This is a quadratic. Simplified closed-form for game use:

    local a = projSpeed * projSpeed - (evx * evx + evy * evy)
    local b = -2 * (rx * evx + ry * evy)
    local c = -(rx * rx + ry * ry)

    local disc = b * b - 4 * a * c
    if disc < 0 then
        -- No intercept possible (enemy too fast), just aim directly
        return ex, ey
    end

    local t1 = (-b - math.sqrt(disc)) / (2 * a)
    local t2 = (-b + math.sqrt(disc)) / (2 * a)
    local t_intercept = t1 > 0 and t1 or (t2 > 0 and t2 or 0)

    -- Clamp to reasonable time window (don't lead too far)
    local maxLeadTime = 2.0
    t_intercept = math.max(0, math.min(maxLeadTime, t_intercept))

    -- Predicted intercept point (simple linear)
    local predictX = ex + evx * t_intercept
    local predictY = ey + evy * t_intercept

    -- NN correction factor based on enemy type, speed, distance
    local corr = self:_getCorrectionFactor(enemy, turretX, turretY, projSpeed)

    -- Blend naive intercept with direct aim
    -- corr > 1 means NN thinks we should lead more
    -- corr < 1 means NN thinks naive lead is too aggressive
    local blendX = predictX * corr + ex * (1 - corr)
    local blendY = predictY * corr + ey * (1 - corr)

    return blendX, blendY
end

-- Compute correction factor from the NN
function Trajectory:_getCorrectionFactor(enemy, turretX, turretY, projSpeed)
    local t = self.trackers[enemy]

    -- Input features
    local speed = (t and t.speed_ema) or enemy.speed or 2.0
    local maxSpeed = 6.0  -- speedster max
    local speedNorm = math.min(1.0, speed / maxSpeed)

    local dx = enemy.x - turretX
    local dy = enemy.y - turretY
    local dist = math.sqrt(dx * dx + dy * dy)
    local maxDist = 600
    local distNorm = math.min(1.0, dist / maxDist)

    -- Recent accuracy (hit rate in last N shots)
    local accuracy = self:getAccuracy()

    local feat = {speedNorm, distNorm, accuracy}
    local raw = self.correctionNet:predict(feat)[1]

    -- Map output [-0.5, 2.0] → correction factor
    local corr = math.max(0.2, math.min(self.maxCorrection, 0.5 + raw * 1.5))
    return corr
end

-- ─────────────────────────────────────────────────────────────────
-- Accuracy tracking
-- ─────────────────────────────────────────────────────────────────
function Trajectory:recordHit(enemy)
    local t = self.trackers[enemy]
    if t then
        t.hitCount = t.hitCount + 1
    end

    table.insert(self.accuracyWindow, 1)  -- 1 = hit
    while #self.accuracyWindow > self.maxAccuracyHistory do
        table.remove(self.accuracyWindow)
    end

    -- Record training sample: high accuracy → high correction reward
    self:_recordTrainingSample(enemy, 1.0)
end

function Trajectory:recordMiss(enemy)
    local t = self.trackers[enemy]
    if t then
        t.missCount = t.missCount + 1
    end

    table.insert(self.accuracyWindow, 0)  -- 0 = miss
    while #self.accuracyWindow > self.maxAccuracyHistory do
        table.remove(self.accuracyWindow)
    end

    -- Record training sample: miss → reduce correction or keep as-is
    self:_recordTrainingSample(enemy, 0.0)
end

function Trajectory:getAccuracy()
    if #self.accuracyWindow == 0 then return 0.5 end
    local hits = 0
    for i = 1, #self.accuracyWindow do
        hits = hits + self.accuracyWindow[i]
    end
    return hits / #self.accuracyWindow
end

-- ─────────────────────────────────────────────────────────────────
-- Online training
-- ─────────────────────────────────────────────────────────────────
function Trajectory:_recordTrainingSample(enemy, hitQuality)
    local t = self.trackers[enemy]
    if not t then return end

    local speedNorm = math.min(1.0, t.speed_ema / 6.0)
    local distNorm = 0.5  -- unknown at training time; use default
    local accuracy = self:getAccuracy()

    -- Target: if hitQuality = 1 (good) → current lead factor is good → target = current output
    -- If hitQuality = 0 (miss) → reduce lead factor
    -- The NN learns to predict when to adjust lead
    local currentOutput = self.correctionNet:predict({speedNorm, distNorm, accuracy})[1]
    local target = hitQuality * 1.0 + (1 - hitQuality) * (currentOutput * 0.5)

    table.insert(self.trainingBuffer, {
        input = {speedNorm, distNorm, accuracy},
        target = {target}
    })

    if #self.trainingBuffer > 256 then
        table.remove(self.trainingBuffer, 1)
    end
end

function Trajectory:train()
    if #self.trainingBuffer < 4 then return 0 end

    local batch = {}
    local maxSamples = math.min(#self.trainingBuffer, self.batchSize)
    for i = 1, maxSamples do
        batch[i] = self.trainingBuffer[math.random(#self.trainingBuffer)]
    end

    local loss = self.correctionNet:trainBatch(batch, self.lr, 2)
    return loss
end

-- ─────────────────────────────────────────────────────────────────
-- Serialization
-- ─────────────────────────────────────────────────────────────────
function Trajectory:serialize()
    return {
        correctionNet = self.correctionNet:serialize(),
        leadFactor = self.leadFactor,
        accuracyWindow = self.accuracyWindow,
        trainingBuffer = self.trainingBuffer,
    }
end

function Trajectory.deserialize(data)
    local self = setmetatable({}, Trajectory)
    self.correctionNet = NN.deserialize(data.correctionNet)
    self.leadFactor = data.leadFactor or 0.5
    self.accuracyWindow = data.accuracyWindow or {}
    self.trainingBuffer = data.trainingBuffer or {}
    self.trackers = {}
    self.emaAlpha = 0.4
    self.historyLen = 6
    self.maxCorrection = 2.5
    self.batchSize = 12
    self.lr = 0.03
    self.avgHitImprovement = 0
    self.hitSamples = 0
    self.maxAccuracyHistory = 20
    return self
end

return Trajectory
