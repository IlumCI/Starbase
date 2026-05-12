-- WaveManager: spawns enemies per wave
local C = require("consts")
local Enemy = require("game.Enemy")

local WM = {}

function WM.new(gameLoop)
    local self = setmetatable({}, { __index = WM })
    self.gameLoop = gameLoop
    self.spawnQueue = {}
    self.spawnTimer = 0
    self.waveNumber = 0
    self.waveEnemiesTotal = 0
    self.waveEnemiesSpawned = 0
    self.waveEnemiesKilled = 0
    self.isBonusWave = false
    self.isBossWave = false
    self.waveCleared = false
    self.waveActive = false
    self.waveTransitionTimer = 0
    self:reset()
    return self
end

function WM:reset()
    self.spawnQueue = {}
    self.spawnTimer = 0
    self.waveNumber = 0
    self.waveEnemiesTotal = 0
    self.waveEnemiesSpawned = 0
    self.waveEnemiesKilled = 0
    self.isBonusWave = false
    self.isBossWave = false
    self.waveCleared = false
    self.waveActive = false
    self.waveTransitionTimer = C.WAVE.WAVE_TRANSITION_TIME
    -- ML difficulty multipliers (applied to enemy HP/speed/spawn)
    self.hpMultiplier = 1.0
    self.speedMultiplier = 1.0
    self.spawnIntervalMult = 1.0
    -- Wave timing stats
    self.waveClearTime = 0
    self.enemiesReachedEnd = 0
    self.waveStartTime = 0
end

-- Apply ML difficulty multiplier adjustments
function WM:applyMultipliers(mults)
    mults = mults or {}
    self.hpMultiplier = mults.hpMultiplier or 1.0
    self.speedMultiplier = mults.speedMultiplier or 1.0
    self.spawnIntervalMult = mults.spawnIntervalMult or 1.0
end

function WM:startNextWave(currentWave)
    self.waveNumber = currentWave
    self.isBossWave = (currentWave % C.WAVE.BOSS_WAVE_INTERVAL == 0)
    self.isBonusWave = (currentWave % C.WAVE.BONUS_WAVE_INTERVAL == 0)
    self.waveEnemiesTotal = self:computeEnemyCount(currentWave)
    self.waveEnemiesSpawned = 0
    self.waveEnemiesKilled = 0
    self.waveCleared = false
    self.waveActive = true
    self.spawnQueue = self:buildSpawnQueue(currentWave)
    self.spawnTimer = 0
end

function WM:computeEnemyCount(wave)
    local base = C.WAVE.BASE_ENEMIES + math.floor(wave * C.WAVE.ENEMIES_PER_WAVE)
    if self.isBossWave then base = base + 1 end  -- +1 for boss
    return base
end

function WM:buildSpawnQueue(wave)
    local queue = {}
    local total = self.waveEnemiesTotal

    if self.isBossWave then
        -- Last enemy is boss
        local nonBoss = total - 1
        for i = 1, nonBoss do
            table.insert(queue, self:pickEnemyType(wave))
        end
        table.insert(queue, "BOSS")
    else
        for i = 1, total do
            table.insert(queue, self:pickEnemyType(wave))
        end
    end

    return queue
end

function WM:pickEnemyType(wave)
    local roll = math.random()
    if wave >= 15 then
        if roll < 0.25 then return "TANK"
        elseif roll < 0.5 then return "SPEEDSTER"
        elseif roll < 0.75 then return "GRUNT"
        else return "GRUNT" end
    elseif wave >= 8 then
        if roll < 0.2 then return "TANK"
        elseif roll < 0.4 then return "SPEEDSTER"
        else return "GRUNT" end
    elseif wave >= 4 then
        if roll < 0.15 then return "TANK"
        elseif roll < 0.3 then return "SPEEDSTER"
        else return "GRUNT" end
    else
        return "GRUNT"
    end
end

function WM:update(dt)
    if self.waveTransitionTimer > 0 then
        self.waveTransitionTimer = self.waveTransitionTimer - dt
        return
    end

    if not self.waveActive then return end
    if #self.spawnQueue == 0 then
        -- Check if all spawned enemies are dead
        -- (handled by GameLoop checking active enemies)
        return
    end

    self.spawnTimer = self.spawnTimer - dt
    if self.spawnTimer <= 0 then
        if #self.spawnQueue > 0 then
            local etype = table.remove(self.spawnQueue, 1)
            local enemy = Enemy.new(etype, self.waveNumber, self.isBonusWave)
            -- Apply ML-driven difficulty multipliers
            if self.hpMultiplier ~= 1.0 then
                enemy.maxHealth = enemy.maxHealth * self.hpMultiplier
                enemy.health = enemy.maxHealth
            end
            if self.speedMultiplier ~= 1.0 then
                enemy.speed = enemy.speed * self.speedMultiplier
            end
            table.insert(self.gameLoop.enemies, enemy)
            self.waveEnemiesSpawned = self.waveEnemiesSpawned + 1
        end
        -- Compute next spawn interval (ML can slow or accelerate spawns)
        local baseInterval = C.WAVE.SPAWN_INTERVAL_BASE + self.waveNumber * C.WAVE.SPAWN_INTERVAL_SCALE
        self.spawnTimer = math.max(C.WAVE.SPAWN_INTERVAL_MIN, baseInterval * self.spawnIntervalMult)
    end
end

function WM:onEnemyKilled()
    self.waveEnemiesKilled = self.waveEnemiesKilled + 1
    if self.waveEnemiesKilled >= self.waveEnemiesTotal and #self.spawnQueue == 0 then
        self.waveCleared = true
        self.waveActive = false
        self.waveClearTime = self.waveClearTime + (os.clock() - self.waveStartTime)
    end
end

function WM:onEnemyReachedEnd()
    self.enemiesReachedEnd = self.enemiesReachedEnd + 1
end

function WM:onWaveStart()
    self.waveStartTime = os.clock()
    self.enemiesReachedEnd = 0
end

function WM:isWaveClear()
    return self.waveCleared
end

function WM:isInTransition()
    return self.waveTransitionTimer > 0
end

function WM:getTransitionTime()
    return math.max(0, self.waveTransitionTimer)
end

function WM:getSpawnProgress()
    return self.waveEnemiesSpawned, self.waveEnemiesTotal
end

return WM