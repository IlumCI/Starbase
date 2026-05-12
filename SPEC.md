# Zen Fortress — Project Spec

## 1. Project Overview

**Name:** Zen Fortress
**Engine:** Solar2D (Lua)
**Type:** Infinite auto-battler with roguelike upgrade selection
**Platform:** Android

**Core loop:** Enemies spawn in waves. Turrets auto-fire. Player selects upgrade after each wave. Runs are infinite — no win/lose, just progression. Player can quit anytime and return with permanent upgrades intact.

---

## 2. Visual & Rendering

**Aesthetic:** Minimalist geometric. Flat shapes, clean lines, muted palette. Inspired by abstract strategy games — nothing noisy or cluttered.

**Resolution:** 9:16 portrait, 1080x1920 logical (scales to device)

**Scene layers (bottom to top):**
1. Background — solid color, subtle grid pattern
2. Enemy path — thin line, slightly lighter than background
3. Enemies — simple shapes (circle, square, triangle) with fill color + stroke
4. Turrets — geometric icons, no sprites
5. Projectiles — small dots/lines
6. UI overlay — wave counter, gold, player level, upgrade card

**Color palette:**
- Background: `#0a0a0f` (near black)
- Grid: `#1a1a2e` (dark blue-gray)
- Turrets: `#00d4ff` (cyan)
- Enemies: `#ff4757` (red)
- Projectiles: `#ffd700` (gold)
- UI text: `#e0e0e0` (light gray)
- Accent: `#7c3aed` (purple — for upgrades/selection)

**Fonts:** Use built-in Sans Bold (system font) — no external font assets needed.

---

## 3. Game Systems

### 3.1 Wave System

- Waves are infinite. Wave N spawns `3 + floor(N * 1.2)` enemies.
- Enemy HP scales: `baseHP * (1 + N * 0.08)`. Base HP differs by enemy type.
- Enemy speed scales slightly: `baseSpeed * (1 + N * 0.01)`.
- Enemy spawn interval decreases slightly with wave (faster spawns over time).
- Between waves: 3-second countdown, then player picks 1 upgrade from 3 choices.
- After wave 5, 10, 15... bonus wave (enemies are 20% tankier, gold reward is 50% higher).

### 3.2 Enemy Types

| Type | Shape | Base HP | Speed | Behavior |
|------|-------|---------|-------|----------|
| Grunt | Circle | 20 | 2.0 | Straight path, no special |
| Tank | Square | 80 | 1.0 | Straight path, 2x HP |
| Speedster | Triangle | 15 | 4.0 | Zigzag movement |
| Boss (every 10 waves) | Hexagon | 300 * wave_mult | 0.8 | Straight, high HP |

Enemies follow a pre-defined path (array of waypoints). Path is a simple winding curve across the screen.

### 3.3 Turret System

**Turrets are auto-placed.** Player does not manually position them. Instead:
- Player starts with 2 turrets.
- Additional turrets are unlocked via permanent upgrades.
- Turrets are positioned on fixed anchor points along the path automatically.
- Turrets have a targeting priority: closest enemy in range, then highest HP.

**Turret types:**

| Type | Shape | Range | Fire Rate | Damage | Special |
|------|-------|-------|-----------|--------|---------|
| Blaster | Circle | 150 | 1.0/s | 10 | Basic single target |
| Cannon | Square | 100 | 0.4/s | 35 | Splash damage (50px radius, 50% dmg to nearby) |
| Sniper | Diamond | 350 | 0.25/s | 60 | Piercing (hits 2 enemies) |
| Zapper | Triangle | 120 | 2.5/s | 5 | Chain lightning (hits up to 3 enemies, 60% decay) |

Turrets can be upgraded between runs (permanent). Each turret has 10 levels:
- Level up costs gold. Each level: +15% damage, +5% fire rate.
- Max level turret is significantly stronger than base.

### 3.4 Upgrade / Roguelike System

After each wave, player sees 3 randomly selected upgrades. Choose 1. Upgrades fall into categories:

**Temporary (per run):**
- `damage_boost_*` — +20% damage for this run
- `fire_rate_boost_*` — +25% fire rate for this run
- `range_boost_*` — +30% range for this run
- `gold_boost_*` — +20% gold from kills this run
- `extra_turret_spawn` — spawns 1 extra turret on the field for this run
- `shield_*` — absorb first N damage instances this run
- `slow_field_*` — enemies move 20% slower this run

**Permanent (persist across runs):**
- `unlock_turret_*` — unlock a new turret type (capped at 4 active)
- `starting_gold_*` — start runs with +50 gold
- `xp_boost_*` — +15% XP gain permanently
- `boss_bonus_*` — +30% gold from boss kills permanently
- `wave_skip_*` — start at wave 3 (skip first 2 waves)

Only 1 permanent upgrade can appear per selection pool. Maximum 3 temp upgrades per run (resets each run).

### 3.5 Progression / Meta Layer

**Player Level (permanent):**
- XP gained per enemy kill: `floor(enemy_hp * 0.1)`
- XP to level up: `level * 100`
- Each level: +5 base gold per run start
- Max level: 100

**Gold (per run):**
- Earned from killing enemies
- Spent on: turret level ups (between runs in upgrade menu)
- Lost on run end (only persistent gold upgrades carry over)

**Persistent Storage:**
- Player level + XP
- Permanent upgrade status (unlocked turrets, XP boost, etc.)
- Turret level ups
- Total waves completed (stat only)

### 3.6 Game Over / Loop

There is no traditional game over. The player manually exits when satisfied. On exit:
- Current run XP + gold are banked
- Permanent upgrades are retained
- Next session resumes with current player level + turret levels + permanent upgrades

**Alternative "checkpoint" system:** Player can manually bank progress mid-run (pause menu → "Bank & Exit"). This saves all progress up to current wave and starts fresh.

---

## 4. UI Layout

### 4.1 In-Game HUD

```
[Wave: 12]                    [HP Bar]
[Gold: 450]                   [XP: 340/400]

         < GAME AREA >
         (enemies + turrets)

[Pause]                        [Player Level]
```

- Top-left: wave number, gold
- Top-right: HP bar (player's base HP), XP bar
- Bottom-right: player level badge
- Bottom-left: pause button

### 4.2 Upgrade Selection Screen

```
         WAVE 12 COMPLETE

    Choose your upgrade:

  +-----------------+  +-----------------+
  |                 |  |                 |
  |  [ICON]         |  |  [ICON]         |
  |  DAMAGE BOOST   |  |  FIRE RATE +25% |
  |  +20% this run  |  |  this run only   |
  |                 |  |                 |
  +-----------------+  +-----------------+

             +-----------------+
             |                 |
             |  [ICON]         |
             |  GOLD +20%      |
             |  this run only  |
             +-----------------+
```

Modal overlay, 50% darkened background. Tap to select.

### 4.3 Main Menu / Meta Screen

```
        ZEN FORTRESS

      [START RUN]

      ─────────────
      TURRETS (tap to level up)
      [Blaster Lv.3] [Cannon Lv.1]
      [Sniper Lv.2]  [Zapper Lv.1]
      ─────────────
      [STATS]
      Waves Cleared: 47
      Player Level: 12
      ─────────────
```

### 4.4 Pause Menu

```
      [Resume]
      [Bank & Exit]  ← saves all progress, ends run
      [Quit]         ← discards current run progress
```

---

## 5. Audio

Minimal audio, ambient feel:
- Ambient background loop: low drone/hum (generated procedurally or silence — minimalist)
- Turret fire: short blip (synthesized)
- Enemy death: short thud
- Upgrade select: soft chime
- Boss spawn: low rumble

Use Solar2D audio APIs with bundled `.wav` or procedurally generated via a simple synth helper.

---

## 6. File Structure

```
zen-game/
├── SPEC.md
├── src/
│   ├── main.lua              ← entry point
│   ├── game/
│   │   ├── GameLoop.lua      ← core loop, state machine
│   │   ├── WaveManager.lua   ← wave spawning logic
│   │   ├── Enemy.lua         ← enemy class
│   │   ├── EnemyTypes.lua    ← enemy type definitions
│   │   ├── Turret.lua        ← turret class
│   │   ├── TurretTypes.lua   ← turret type definitions
│   │   ├── Projectile.lua    ← projectile class
│   │   ├── Path.lua          ← enemy path waypoints
│   │   └── UpgradeSystem.lua ← upgrade definitions + selection
│   ├── meta/
│   │   ├── PlayerState.lua   ← player level, XP, gold, stats
│   │   ├── Persistence.lua   ← save/load to JSON file
│   │   └── UpgradeStore.lua  ← permanent upgrade status
│   ├── ui/
│   │   ├── HUD.lua           ← in-game HUD
│   │   ├── UpgradeScreen.lua ← upgrade selection modal
│   │   ├── MainMenu.lua      ← meta screen
│   │   └── PauseMenu.lua     ← pause overlay
│   ├── utils/
│   │   ├── math.lua          ← vector math, lerp, etc.
│   │   └── audio.lua         ← audio helper
│   └── consts.lua            ← all magic numbers centralized
├── assets/
│   └── audio/
│       ├── fire.wav
│       ├── death.wav
│       ├── upgrade.wav
│       ├── boss.wav
│       └── ambient.wav
└── build/
    └── (build outputs)
```

---

## 7. Implementation Priority

**Phase 1 — Foundation:**
1. `consts.lua` — all magic numbers
2. `Persistence.lua` — save/load system
3. `PlayerState.lua` — meta state
4. `Path.lua` — enemy path definition
5. `EnemyTypes.lua` + `Enemy.lua` — spawning and movement
6. `main.lua` — basic Solar2D setup, scene stack

**Phase 2 — Core Combat:**
7. `TurretTypes.lua` + `Turret.lua` — targeting, firing
8. `Projectile.lua` — projectile movement + collision
9. `WaveManager.lua` — wave logic
10. `GameLoop.lua` — enterFrame, state machine (playing/paused/upgrade-select)

**Phase 3 — Player Interaction:**
11. `HUD.lua` — health bar, gold, wave counter
12. `UpgradeScreen.lua` — 3-card selection
13. `PauseMenu.lua`
14. `MainMenu.lua`

**Phase 4 — Polish:**
15. `UpgradeSystem.lua` — upgrade definitions and effects
16. `UpgradeStore.lua` — permanent upgrade logic
17. `TurretTypes.lua` updates — all turret types active
18. Audio integration
19. Visual polish (particles, screen shake on big hits)

**Phase 5 — Build:**
20. Solar2D Android build config
21. Test APK generation

---

## 8. Technical Notes

- Use Solar2D's `display` API for all rendering (no external graphics libs)
- Collision: simple circle-based distance checks (no physics engine needed)
- State machine for game phases: `MENU`, `PLAYING`, `UPGRADE_SELECT`, `PAUSED`, `WAVE_TRANSITION`
- Save data: JSON file written to `system.pathForFile()` — use `io` APIs
- Target 60fps. Solar2D handles this on most Android devices for this scope.
- No external dependencies beyond Solar2D itself