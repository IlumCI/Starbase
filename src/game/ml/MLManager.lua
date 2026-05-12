-- MLManager: owns all ML subsystems, coordinates training, and
-- exposes a unified interface to the rest of the game engine.
local NN = require("game.ml.NeuralNetwork")
local Targeting = require("game.ml.TurretTargeting")
local Trajectory = require("game.ml.ProjectileTrajectory")
local Evasion = require("game.ml.EnemyEvasion")
local DGen = require("game.ml.DestructionGenerator")
local Adaptor = require("game.ml.DifficultyAdaptor")

local ML = {}
ML.__index = ML

-- ─────────────────────────────────────────────────────────────────
-- Constructor
-- ─────────────────────────────────────────────────────────────────
function ML.new()
    local self = setmetatable({}, ML)

    self.targeting = Targeting.new()
    self.trajectory = Trajectory.new()
    self.evasion = Evasion.new()
    self.destruction = DGen.new()
    self.adaptor = Adaptor.new()

    -- Training frequency (train every N wave clears)
    self.trainFrequency = 1
    self.trainCounter = 0

    -- Tracking stats
    self.totalKills = 0
    self.totalMisses = 0

    -- Whether ML features are enabled (can be toggled for performance)
    self.enabled = true

    return self
end

-- ─────────────────────────────────────────────────────────────────
-- Update: called every frame from GameLoop
-- ─────────────────────────────────────────────────────────────────
function ML:update(dt)
    if not self.enabled then return end
    -- Per-frame updates handled by individual systems
    -- (tracking is done in entity methods)
end

-- ─────────────────────────────────────────────────────────────────
-- Called every wave clear: train all systems
-- ─────────────────────────────────────────────────────────────────
function ML:onWaveClear(waveNum, enemiesKilled, waveTime)
    if not self.enabled then return end

    self.trainCounter = self.trainCounter + 1

    -- Train targeting
    local tLoss = self.targeting:train()

    -- Train trajectory
    local trLoss = self.trajectory:train()

    -- Train evasion
    local eLoss = self.evasion:train()

    -- Train destruction
    local dLoss = self.destruction:train()

    -- Log
    local totalLoss = tLoss + trLoss + eLoss + dLoss
    return {
        targetingLoss = tLoss,
        trajectoryLoss = trLoss,
        evasionLoss = eLoss,
        destructionLoss = dLoss,
        totalLoss = totalLoss,
    }
end

-- Called after each enemy death (before removing from world)
function ML:onEnemyDeath(enemy, projectiles, damageSource)
    if not self.enabled then return end

    self.totalKills = self.totalKills + 1

    -- Destruction generator feedback
    self.destruction:autoFeedback(enemy.typeKey, self.totalKills)

    -- Train evasion: record outcome for evasion net
    -- Check if enemy survived (death = outcome for evasion)
    -- We'll check in onWaveClear instead
end

-- Called when an enemy reaches the end
function ML:onEnemyReachedEnd(enemy, projectiles)
    if not self.enabled then return end

    -- Record evasion failure
    self.evasion:recordOutcome(enemy, projectiles, false)
end

-- Called after wave ends
function ML:onWaveEnd(waveNum, cleared, hpLeft, maxHP, enemiesKilled, clearTime, enemiesReachedEnd)
    if not self.enabled then return end

    -- Record wave outcome for difficulty adaptor
    self.adaptor:recordWave(waveNum, cleared, hpLeft, maxHP, enemiesKilled, clearTime, enemiesReachedEnd)

    -- Update targeting maxHP
    local maxEnemyHP = maxHP * 2  -- rough estimate
    self.targeting:updateMaxHP(maxEnemyHP)

    -- Train all systems
    self:onWaveClear(waveNum, enemiesKilled, clearTime)
end

-- Called at run start
function ML:onRunStart()
    if not self.enabled then return end
    -- Adaptor reset is handled by GameLoop
end

-- Called at run end
function ML:onRunEnd()
    if not self.enabled then return end
    -- Persist trained state handled by Persistence
end

-- ─────────────────────────────────────────────────────────────────
-- Per-enemy update: tracking (called from GameLoop per enemy)
-- ─────────────────────────────────────────────────────────────────
function ML:updateEnemy(enemy, dt)
    if not self.enabled then return end
    self.trajectory:updateEnemy(enemy, dt)
end

-- ─────────────────────────────────────────────────────────────────
-- Per-projectile: record hit/miss for trajectory training
-- ─────────────────────────────────────────────────────────────────
function ML:onProjectileHit(proj, enemy)
    if not self.enabled then return end
    self.trajectory:recordHit(enemy)
end

function ML:onProjectileMiss(proj)
    if not self.enabled then return end
    self.totalMisses = self.totalMisses + 1
    -- Get the target enemy from the projectile's last known target
    if proj.target then
        self.trajectory:recordMiss(proj.target)
    end
end

-- ─────────────────────────────────────────────────────────────────
-- Turret targeting: select best target using ML
-- ─────────────────────────────────────────────────────────────────
function ML:selectTarget(enemies, turret)
    if not self.enabled then return turret:findTarget(enemies) end
    return self.targeting:selectTarget(enemies, turret, turret.range)
end

-- ─────────────────────────────────────────────────────────────────
-- Turret aiming: compute lead target position
-- ─────────────────────────────────────────────────────────────────
function ML:computeIntercept(turretX, turretY, enemy, projSpeed)
    if not self.enabled then return enemy.x, enemy.y end
    return self.trajectory:computeIntercept(turretX, turretY, enemy, projSpeed)
end

-- ─────────────────────────────────────────────────────────────────
-- Enemy evasion: compute steering force
-- ─────────────────────────────────────────────────────────────────
function ML:computeEvasion(enemy, projectiles, pathDirX, pathDirY, dt)
    if not self.enabled then return 0, 0 end
    return self.evasion:computeEvasion(enemy, projectiles, pathDirX, pathDirY, dt)
end

-- Record evasion outcome for training
function ML:recordEvasionOutcome(enemy, projectiles, survived)
    if not self.enabled then return end
    self.evasion:recordOutcome(enemy, projectiles, survived)
end

-- ─────────────────────────────────────────────────────────────────
-- Particle generation: generate destruction particles
-- ─────────────────────────────────────────────────────────────────
function ML:generateDestruction(enemy, damageSource)
    if not self.enabled then return nil end
    return self.destruction:generate(enemy, damageSource)
end

-- ─────────────────────────────────────────────────────────────────
-- Difficulty: get current multipliers
-- ─────────────────────────────────────────────────────────────────
function ML:getDifficultyMultipliers(waveNum)
    if not self.enabled then
        return { hpMultiplier = 1.0, speedMultiplier = 1.0, spawnIntervalMult = 1.0 }
    end
    return self.adaptor:getMultipliers(waveNum)
end

function ML:getDifficultyState()
    if not self.enabled then return nil end
    return self.adaptor:getState()
end

function ML:onTurretUpgrade(level)
    if not self.enabled then return end
    self.adaptor:onTurretUpgrade(level)
end

-- ─────────────────────────────────────────────────────────────────
-- Reset for new run
-- ─────────────────────────────────────────────────────────────────
function ML:reset()
    self.adaptor:reset()
    self.totalKills = 0
    self.totalMisses = 0
    self.trainCounter = 0
end

-- ─────────────────────────────────────────────────────────────────
-- Serialization (save/load)
-- ─────────────────────────────────────────────────────────────────
function ML:serialize()
    return {
        targeting = self.targeting:serialize(),
        trajectory = self.trajectory:serialize(),
        evasion = self.evasion:serialize(),
        destruction = self.destruction:serialize(),
        adaptor = self.adaptor:serialize(),
        enabled = self.enabled,
    }
end

function ML.deserialize(data)
    local self = setmetatable({}, ML)
    self.targeting = Targeting.deserialize(data.targeting)
    self.trajectory = Trajectory.deserialize(data.trajectory)
    self.evasion = Evasion.deserialize(data.evasion)
    self.destruction = DGen.deserialize(data.destruction)
    self.adaptor = Adaptor.deserialize(data.adaptor)
    self.enabled = data.enabled ~= false
    self.totalKills = 0
    self.totalMisses = 0
    self.trainFrequency = 1
    self.trainCounter = 0
    return self
end

return ML
