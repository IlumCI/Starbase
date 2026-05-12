# Zen Fortress — Specification

## Overview

Zen Fortress is an infinite auto-battler tower defense game for Android, built with LÖVE2D (Lua).
Runs are endless — survive as long as possible while banking gold to permanently upgrade turrets.

## Game Architecture

### Core Loop
1. Build phase: select 1 of 3 upgrades (temporary for this run, or permanent if banked)
2. Wave phase: enemies auto-path toward the exit; turrets auto-fire
3. Wave clear → repeat from step 1
4. HP reaches 0 → run ends; banked gold converts to permanent upgrades

### Coordinate System
- Virtual pixels: `C.WIDTH × C.HEIGHT` (16:9 aspect, scales to device)
- Enemy movement: progress along pre-defined path `[0 → 1]`, interpolated via `Path.getPositionAtProgress`
- Anchors: normalized `(0–1)` fractions of screen dimensions

---

## File Map

```
src/
  main.lua                  — LÖVE entry point; scene router
  consts.lua                — All tuning constants (C table)
  game/
    GameLoop.lua            — Main update/render loop; owns all entities
    Enemy.lua               — Enemy: path following, HP, effects
    Turret.lua              — Turret: targeting, firing, rotation
    Projectile.lua         — Projectile: movement, collision
    WaveManager.lua         — Wave sequencing, spawn queue, timing
    ParticlePool.lua        — Object pool for death/muzzle particles
    Path.lua                — Waypoint paths and interpolation
    EnemyDef.lua            — Enemy type definitions (stats, colors, shapes)
    TurretDef.lua           — Turret type definitions (damage, range, rate)
    UpgradeSystem.lua       — Upgrade selection and application
    Persistence.lua         — Save/load via love.filesystem (JSON)
    ui/
      HUD.lua               — In-game HUD (HP, gold, wave, XP bar)
      UpgradeScreen.lua     — Upgrade card UI (widget-based)
      MenuUI.lua            — Main menu, pause, game-over overlays
  lib/ (utility modules)
  ml/ (ML subsystems — see ML Architecture section)
```

---

## Entities

### Enemy
- **Path following**: `enemy.progress` (0→1) advances each frame by `(speed / pathLength) * dt`
- **Position**: interpolated from waypoints; perpendicular displacement applied for evasion
- **Types**: GRUNT, TANK, SPEEDSTER, BOSS (each with unique HP, speed, reward, shape)
- **States**: `dead`, `reachedEnd`, `dead`; once set, `update()` returns early
- **Damage sources**: tracked as `enemy.damageSource` string for ML feedback

### Turret
- **Targeting**: falls back to `findTarget()` (nearest-in-range) when ML disabled
- **ML targeting**: `gameLoop.ml:selectTarget(enemies, turret)` — NN scores every enemy
- **Lead prediction**: `gameLoop.ml:computeIntercept(x, y, enemy, projSpeed)` — predicts intercept position
- **Fire rate**: governed by cooldown; barrel animates toward `leadTargetX/Y`
- **Types**: BLASTER (rapid-fire), CANNON (splash), SNIPER (high damage, slow), ZAPPER (chain)

### Projectile
- **Speed**: `C.PROJECTILE_SPEED` constant (modified by damage boosts)
- **Lead targeting**: if `leadX/leadY` provided, moves toward that position instead of enemy's current position
- **Collision**: circle-circle against enemy radii; `hitSomething` flag records whether it hit anything

---

## Wave System

### WaveManager State
- `waveNumber`, `waveActive`, `waveCleared`, `spawnQueue[]`
- `hpMultiplier`, `speedMultiplier`, `spawnIntervalMult` — set by ML DifficultyAdaptor each wave

### Spawn Flow
```
startNextWave(waveNum)
  → buildSpawnQueue(waveNum)
  → spawnQueue populated with enemy type keys
  → isBossWave flagged every BOSS_WAVE_INTERVAL waves

update(dt) per frame:
  → decrement spawnTimer
  → when timer ≤ 0: pop queue, Enemy.new(), apply ML multipliers
  → applyMultipliers called before first spawn
```

### ML Timing Hooks
- `waveManager:onWaveStart()` — called when wave begins; records wall-clock start time
- `waveManager:onEnemyKilled()` — increments kill count; final kill triggers `waveCleared`
- `waveManager:onEnemyReachedEnd()` — increments leak count for difficulty tracking
- `waveManager:getWaveClearTime()` — returns elapsed seconds since wave start

---

## Persistence

- Saves to `love.filesystem` (maps to `%APPDATA%/ZenFortress/` on desktop, app-private storage on Android)
- Persists: gold, XP, unlocked turrets, turret levels, run history
- ML state (neural network weights, training buffers, difficulty adaptor) also persisted between runs

---

## ML Architecture

All ML is **pure Lua** — no external libraries. All networks are hand-written Lua tables.
Modules live under `src/game/ml/`.

### NeuralNetwork.lua — Base Class
Pure Lua feedforward neural network.

```
NN.new(inputSize, hiddenSizes[], outputSize, activation?)
  → forward(inputVec[]) → outputVec[]
  → train(dataset[], learningRate, epochs) → avgLoss
  → setWeights(weights[]), getWeights() → weights[]
  → serialize() → table, deserialize(table) → NN
```

Activations: `sigmoid`, `tanh`, `relu`, `leaky_relu`. Weights initialized via Xavier.

---

### TurretTargeting.lua — NN Target Selector

**Problem**: Nearest-enemy targeting is suboptimal. Should prioritize high-threat or low-HP enemies.

**Network**: 7 inputs → 16 hidden (tanh) → 8 hidden (tanh) → 1 output (sigmoid score)

**Inputs** (per candidate enemy):
1. Distance from turret (normalized 0–1, max range)
2. HP ratio (current / max, 0–1)
3. Path progress (0–1)
4. Enemy type one-hot (4 values): GRUNT=1, TANK=2, SPEEDSTER=3, BOSS=4
5. Speed ratio (current speed / base speed for type)
6. Threat multiplier (HP × speed product, normalized)
7. Tower special encoding (scalar based on turret's special type)

**Output**: Scalar score. All in-range enemies scored; highest wins.

**Training**: After each kill, the chosen target's outcome is stored. Training targets: score=1 for eventually-killed enemies, score=0 for enemies that reached the exit.

**Fallback**: When `enabled=false` or `trainingBuffer` < 16 samples, falls back to nearest-enemy targeting.

---

### ProjectileTrajectory.lua — Lead Target Predictor

**Problem**: Shooting at a fast enemy's current position misses. Must predict intercept point.

**Network**: 7 inputs → 16 hidden (leaky_relu) → 4 hidden (leaky_relu) → 4 outputs

**Inputs**:
1. Enemy X velocity (px/s, normalized)
2. Enemy Y velocity (px/s, normalized)
3. Enemy speed magnitude (normalized)
4. Distance to enemy (normalized by max range)
5. Turret X position (normalized)
6. Turret Y position (normalized)
7. Time step (dt, normalized)

**Outputs** (predicted enemy state `Δt` seconds in future):
1. `Δx` (predicted X displacement)
2. `Δy` (predicted Y displacement)
3. `Δvx` (predicted X velocity)
4. `Δvy` (predicted Y velocity)

**Intercept formula**:
```
relX = enemy.x - turretX,  relY = enemy.y - turretY
dist = sqrt(relX² + relY²)
t = dist / projSpeed
predictedX = enemy.x + nn_output[1]
predictedY = enemy.y + nn_output[2]
```

**Training**: Records `enemy + velocity` each frame. Hit → train on correct trajectory. Miss → penalize.

**Fallback**: Returns `enemy.x, enemy.y` (no prediction) when disabled or buffer < 8 samples.

---

### EnemyEvasion.lua — Projectile Avoidance

**Problem**: Enemies follow a fixed path and are trivially predictable. Should react to incoming projectiles.

**Network**: 13 inputs → 16 hidden (tanh) → 8 hidden (tanh) → 3 outputs

**Inputs**:
1–2. Path tangent (unit direction vector along path, x/y)
3. Speed (normalized)
4. Progress along path (0–1)
5. Health ratio (0–1)
6. Nearby projectile count (weighted by proximity)
7. Nearest projectile: relative X (normalized, negative = incoming)
8. Nearest projectile: relative Y (normalized, negative = incoming)
9. Nearest projectile: relative speed (normalized)
10. Threat score: sum of (speed / distance) for all nearby projectiles
11–12. Evasion bias: outputs from previous frame (recurrent feedback)
13. dt (normalized)

**Outputs**:
1. `steerX` — perpendicular steering direction (x component)
2. `steerY` — perpendicular steering direction (y component)
3. `steerStrength` — magnitude of evasion force (0–1)

**Integration**: Enemies remain on path (progress-based) but receive a small perpendicular displacement:
```
ex = pos.x + steerX * steerStrength * dt * 30
ey = pos.y + steerY * steerStrength * dt * 30
```
Evasion is subtle — enemies don't fully abandon the path.

**Training**: Enemies that survive record `outcome=true` with near-miss data. Enemies that die record `outcome=false`. Network learns to dodge based on projectile proximity.

---

### DestructionGenerator.lua — Procedural Particle Bursts

**Problem**: Hardcoded particle bursts are repetitive. Should vary per enemy type, damage source, and game context.

**Network**: 9 inputs → 16 hidden (relu) → 8 hidden (relu) → 7 outputs

**Inputs**:
1. Enemy type one-hot (4 values): GRUNT, TANK, SPEEDSTER, BOSS
2. Enemy radius (normalized)
3. Enemy color R (0–1)
4. Enemy color G (0–1)
5. Enemy color B (0–1)
6. Kill count (normalized, increases variety over time)
7. Damage source type (one-hot 2 values): TURRET_PROJECTILE, SLOW_FIELD
8. Wave number (normalized)
9. Particle budget (max particles to generate, normalized)

**Outputs** (7 parameters for the burst):
1. `count` — number of particles (scaled by budget)
2. `speed` — initial velocity magnitude (normalized)
3. `spread` — angular spread in radians (0–π)
4. `gravity` — downward acceleration (normalized)
5. `lifetime` — particle lifespan in seconds (normalized)
6. `size` — initial particle size (normalized)
7. `colorShift` — hue shift from enemy color (normalized −1 to 1)

**Generation**: Each particle in the burst gets:
```
angle = spread * (random − 0.5) * 2π
speed_i = speed * (0.5 + random * 0.5) * speedMult
vx = cos(angle) * speed_i
vy = sin(angle) * speed_i − gravity * t
size_i = size * (0.5 + random * 0.5)
```

**Feedback**: Auto-feedback loop — if generated bursts look good (enemy killed in < 2s of spawning), networks are rewarded. Bottleneck samples get retrained.

**Fallback**: Returns `nil` when disabled or buffer < 8 samples, triggering simple hardcoded effect.

---

### DifficultyAdaptor.lua — Adaptive Difficulty

**Problem**: Static wave scaling makes early waves too easy or late waves too hard. ML should learn the player's skill and adjust.

**Network**: 8 inputs → 16 hidden (tanh) → 8 hidden (tanh) → 3 outputs

**Inputs**:
1. Wave number (normalized)
2. Win rate (enemies killed / total spawned, smoothed over last 5 waves)
3. HP remaining ratio (player HP / max HP at wave end)
4. Gold earned per second (normalized)
5. Turret level (average, normalized)
6. Total gold banked (normalized)
7. Enemies leaked ratio (reached end / total spawned, smoothed)
8. Wave clear time (normalized)

**Outputs**:
1. `hpMult` — enemy HP multiplier (clamped 0.5–2.5)
2. `speedMult` — enemy speed multiplier (clamped 0.6–1.8)
3. `spawnMult` — spawn interval multiplier (clamped 0.5–2.0)

**Training**: Each wave's inputs and outputs are stored as training samples. Label quality:
- Wave cleared quickly + high HP = "too easy" → increase multipliers (higher output targets)
- Wave barely cleared or HP very low = "too hard" → decrease multipliers
- Gold-per-second and enemies-leaked ratio also factor into quality score

**State tracking**: Win rate, enemies leaked ratio, gold earned — all smoothed with exponential moving average over last N waves.

**Serialization**: All network weights and training history saved to persistence. ML adapts across runs.

---

### MLManager.lua — Facade

Owns all 5 ML subsystems. Provides a unified interface to GameLoop.

| Method | Delegates to |
|---|---|
| `selectTarget(enemies, turret)` | TurretTargeting |
| `computeIntercept(turX, tY, enemy, pSpeed)` | ProjectileTrajectory |
| `computeEvasion(enemy, projs, pathX, pathY, dt)` | EnemyEvasion |
| `generateDestruction(enemy, src)` | DestructionGenerator |
| `getDifficultyMultipliers(waveNum)` | DifficultyAdaptor |
| `onWaveEnd(wave, cleared, hpLeft, maxHP, kills, time, leaks)` | trains all nets + DifficultyAdaptor |
| `recordEvasionOutcome(enemy, projs, survived)` | EnemyEvasion |
| `onProjectileMiss(proj)` | ProjectileTrajectory |
| `onEnemyDeath(enemy, src)` | DestructionGenerator |
| `serialize()` / `deserialize()` | all subsystems |

**Stats tracked**: `totalKills`, `totalMisses`, `wavesTrained`, `samplesCollected` — surfaced for HUD display.

---

## Input (Mobile)

- **Touch**: `love.touchpressed/moved/released` → maps to tap/drag on virtual widgets
- **Press feedback**: `haptics.vibrate(15)` on turret tap, upgrade selection
- **Back key**: `love.keypressed('escape')` on Android → toggles pause
- **Mouse fallback**: `love.mousepressed/released` for desktop testing

---

## Rendering

- **Canvas-based**: background rendered once to `bgCanvas`; entities composited on main canvas
- **ParticlePool**: object pool for death effects and muzzle flashes — pre-allocated, recycled
- **MLParticles**: separate pool for ML-generated destruction particles
- **Font**: geometric custom Font system (no external assets) for HUD text
- **Layered visuals**: enemies rendered with shape unions, glow rings, wobble animation
