# Zen Fortress

Infinite auto-battler tower defense for Android. Built with LÖVE2D.

## Game

- Wave-based tower defense with roguelike progression
- 4 turret types: Blaster, Cannon, Sniper, Zapper
- 4 enemy types: Grunt, Tank, Speedster, Boss
- Between waves: choose from 3 upgrades (temp or permanent)
- Bank gold between runs to level up turrets
- Runs are infinite -- survive as long as you can

## Dev

```bash
# Install LÖVE2D
# Ubuntu: sudo apt install love
# macOS: brew install love
# Windows: https://love2d.org

# Run locally
love src/

# Build .love for packaging
cd src && zip -r ../game.love . && cd ..
```

## Build APK

Push to `main` branch on GitHub -- the `build.yml` workflow:
1. Zips all Lua files into `game.love`
2. Builds APK with `love-android-serviceman`
3. Downloads the artifact from Actions

To trigger manually: Actions tab → Build Android APK → Run workflow

## Project structure

```
src/
├── main.lua              -- LÖVE entry point
├── conf.lua              -- LÖVE config
├── consts.lua            -- All game constants
├── lib/dkjson.lua        -- JSON encoder/decoder
├── game/
│   ├── GameLoop.lua      -- State machine + entity management
│   ├── Path.lua          -- Enemy waypoints
│   ├── WaveManager.lua   -- Wave spawning logic
│   ├── Enemy.lua         -- Enemy entity
│   ├── Turret.lua        -- Turret entity
│   ├── Projectile.lua   -- Projectile entity
│   ├── UpgradeSystem.lua -- Upgrade definitions + selection
│   └── meta/
│       ├── Persistence.lua  -- Save/load
│       └── PlayerState.lua  -- Player data
└── ui/
    ├── HUD.lua            -- In-game HUD
    ├── MainMenu.lua       -- Menu + turret upgrades
    ├── PauseMenu.lua      -- Pause overlay
    └── UpgradeScreen.lua  -- Upgrade card selection
```