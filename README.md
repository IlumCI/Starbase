# Zen Fortress

An infinite auto-battler tower defense game built with Solar2D (Lua).

## Project Structure

```
zen-game/
├── SPEC.md                  ← Full game design specification
├── config.lua               ← Solar2D display configuration
├── build.settings           ← Android build settings
├── src/
│   ├── main.lua             ← Entry point
│   ├── consts.lua           ← All magic numbers
│   ├── game/
│   │   ├── GameLoop.lua     ← Core state machine
│   │   ├── WaveManager.lua  ← Wave spawning
│   │   ├── Enemy.lua        ← Enemy entities
│   │   ├── Turret.lua       ← Turret entities
│   │   ├── Projectile.lua   ← Projectile entities
│   │   ├── Path.lua         ← Enemy path waypoints
│   │   └── UpgradeSystem.lua ← Roguelike upgrades
│   ├── meta/
│   │   ├── Persistence.lua  ← JSON save/load
│   │   └── PlayerState.lua   ← Player + run state
│   └── ui/
│       ├── HUD.lua
│       ├── MainMenu.lua
│       ├── PauseMenu.lua
│       └── UpgradeScreen.lua
└── assets/                  ← (add audio files here)
```

## Building for Android

### Option 1: Solar2D Corona Simulator (GUI)

1. Install [Solar2D](https://solar2d.com/) (formerly Corona SDK)
2. `git clone` this repo, or copy the `zen-game/` folder
3. Open Solar2D Simulator
4. File → Open → select `zen-game/` folder
5. File → Build → Android → fill in package name, keystore, etc.

### Option 2: Command Line (Corona Builder)

```bash
# Install Corona CLI tools
wget https://developer.coronalabs.com/downloads/coronasdk-linux
chmod +x coronasdk-linux
sudo mv coronasdk-linux /usr/local/bin/corona

# Build
corona build build.settings zen-game
```

### Option 3: Termux (local build, requires X11)

```bash
# Install Solar2D for Linux
wget https://solar2d.org/downloads/Solar2D-Linux-2024.3604.tar.gz
tar xzf Solar2D-Linux-2024.3604.tar.gz
cd Solar2D-Linux-2024.3604
./solar2d

# Or use the Android NDK + Solar2D makefile approach
```

### Build Checklist

1. Add audio files to `assets/audio/` (optional — game works without):
   - `fire.wav` — turret shot
   - `death.wav` — enemy death
   - `upgrade.wav` — upgrade select
   - `boss.wav` — boss spawn
   - `ambient.wav` — background drone
2. Edit `build.settings` — set your `package` name and signing keystore
3. Edit `config.lua` — adjust display dimensions if needed
4. Build for Android APK

## Running

- After build: install the APK on Android device
- Touch `START RUN` to begin
- Turrets auto-fire — watch and enjoy
- After each wave: pick 1 of 3 upgrades
- No game over — quit anytime and progress is banked

## Development

- All game logic is in `src/`
- Magic numbers in `src/consts.lua` — tweak there first
- Enemy types in `src/consts.lua` → `C.ENEMY`
- Turret types in `src/consts.lua` → `C.TURRET`
- Upgrades in `src/game/UpgradeSystem.lua` → `US.DEFS`
- Save file: `Documents/zen_fortress_save.json`

## Key Design Decisions

- No manual turret placement — turrets auto-position on fixed anchors
- Roguelike upgrade selection after each wave
- Infinite runs — no game over, no win condition
- Permanent progression via player level + turret upgrades + permanent upgrades
- Minimalist aesthetic — geometric shapes, muted dark palette, cyan/red/gold accents
- Solar2D — Lua, cross-platform, free (MIT)