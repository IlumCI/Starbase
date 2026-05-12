-- Zen Fortress — Solar2D main entry point
local C = require("consts")
local GameLoop = require("game.GameLoop")
local MainMenu = require("ui.MainMenu")
local HUD = require("ui.HUD")
local UpgradeScreen = require("ui.UpgradeScreen")
local PauseMenu = require("ui.PauseMenu")

-- Set up display
display.setStatusBar(display.HiddenStatusBar)
local screenGroup = display.newGroup()

-- Game instance
local game = nil
local mainMenu = nil
local hud = nil
local upgradeScreen = nil
local pauseMenu = nil

local lastTime = 0

function initGame()
    game = GameLoop.new()
    screenGroup:insert(game.bgGroup)
    screenGroup:insert(game.pathGroup)
    screenGroup:insert(game.enemyGroup)
    screenGroup:insert(game.turretGroup)
    screenGroup:insert(game.projGroup)
    screenGroup:insert(game.uiGroup)

    hud = HUD.new(game)
    screenGroup:insert(hud.group)

    upgradeScreen = UpgradeScreen.new(game)
    screenGroup:insert(upgradeScreen.group)

    pauseMenu = PauseMenu.new(game)
    screenGroup:insert(pauseMenu.group)

    mainMenu = MainMenu.new(game)
    screenGroup:insert(mainMenu.group)

    -- Wire up UI callbacks
    game.showUpgradeScreen = function(self)
        upgradeScreen:show(self.upgradeChoices)
    end
    game.hideUpgradeScreen = function(self)
        upgradeScreen:hide()
    end
    game.showMenuUI = function(self)
        mainMenu:show()
        hud:hide()
    end
    game.hideMenuUI = function(self)
        mainMenu:hide()
    end
    game.onPauseTap = function(self)
        if self.state == C.STATE.PLAYING then
            self.state = C.STATE.PAUSED
            pauseMenu:show()
        end
    end
    game.onUpgradeSelected = function(self, id)
        local US = require("game.UpgradeSystem")
        US.applyUpgrade(id, require("game.meta.PlayerState"), self)
        upgradeScreen:hide()
        local PS = require("game.meta.PlayerState")
        PS.run.wave = PS.run.wave + 1
        self.waveManager:startNextWave(PS.run.wave)
        self.waveStartGold = PS.run.gold
        self.state = C.STATE.PLAYING
    end

    -- Show main menu
    mainMenu:show()
    hud:hide()
end

-- Runtime update
local pulseTime = 0
local trailPoints = {}  -- { [projId] = { {x,y}, ... } }

local function onEnterFrame(event)
    local dt = event.time / 1000 - lastTime
    lastTime = event.time / 1000
    if dt < 0 or dt > 0.5 then dt = 0.016 end

    pulseTime = pulseTime + dt

    if game then
        game:update(dt)
        hud:update(game.waveManager.waveNumber or 1)

        -- Spawn visual effects
        updateVisualEffects(dt)
    end
end

function updateVisualEffects(dt)
    if not game then return end

    -- Turret glow pulse
    for _, turret in ipairs(game.turrets) do
        if turret.group and turret.def and turret.energyRing then
            local pulse = 0.5 + 0.5 * math.sin(pulseTime * 3 + turret.x * 0.01)
            turret.energyRing.alpha = 0.15 + pulse * 0.2
            turret.energyRing2.alpha = 0.08 + pulse * 0.1
        end
    end

    -- Enemy subtle rotation / wobble
    for _, enemy in ipairs(game.enemies) do
        if enemy.group and not enemy.dead then
            local wobble = math.sin(pulseTime * 4 + enemy.y * 0.02) * 3
            enemy.group.rotation = wobble
        end
    end
end

-- Input handlers
local function onTouch(event)
    -- Reserved for future touch-to-place mechanics if needed
end

function scene(event)
    if event.phase == "did" then
        -- nothing
    end
end

-- Boot
initGame()
Runtime:addEventListener("enterFrame", onEnterFrame)
Runtime:addEventListener("touch", onTouch)

-- Cleanup on exit
local function onSystemEvent(event)
    if event.type == "applicationExit" then
        if game then
            local PS = require("game.meta.PlayerState")
            PS:discardRun()
        end
    end
end
Runtime:addEventListener("system", onSystemEvent)