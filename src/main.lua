-- Zen Fortress — LÖVE2D main entry point
local C = require("consts")
local GameLoop = require("game.GameLoop")
local MainMenu = require("ui.MainMenu")
local HUD = require("ui.HUD")
local UpgradeScreen = require("ui.UpgradeScreen")
local PauseMenu = require("ui.PauseMenu")
local Haptics = require("lib.Haptics")

-- Initialize LÖVE2D
function love.load()
    love.window.setTitle("Zen Fortress")
    love.window.setMode(C.WIDTH, C.HEIGHT, {
        fullscreen = false,
        resizable = false,
        vsync = true,
        minwidth = 540,
        minheight = 960,
    })
    love.graphics.setBackgroundColor(C.COLOR.BACKGROUND[1], C.COLOR.BACKGROUND[2], C.COLOR.BACKGROUND[3])

    -- Initialize haptics
    Haptics.init()

    -- Create game
    game = GameLoop.new()

    -- Create UI
    hud = HUD.new(game)
    game.hud = hud

    upgradeScreen = UpgradeScreen.new(game)
    game.upgradeScreen = upgradeScreen

    pauseMenu = PauseMenu.new(game)
    game.pauseMenu = pauseMenu

    mainMenu = MainMenu.new(game)
    game.mainMenu = mainMenu

    -- Show main menu
    game:showMenuUI()

    -- Track last time
    lastTime = love.timer.getTime()

    -- For letterboxing
    screenW, screenH = love.window.getMode()
    offsetX, offsetY = 0, 0

    -- Mobile-friendly: disable screensaver
    love.system.setPowerSaving(true)
end

function love.update(dt)
    if dt > 0.5 then dt = 0.016 end  -- cap at ~60fps equivalent
    if game then
        game:update(dt)
    end
end

function love.draw()
    local sw, sh = love.window.getMode()

    -- Letterbox centering
    local scaleX = sw / C.WIDTH
    local scaleY = sh / C.HEIGHT
    local scale = math.min(scaleX, scaleY)
    local offsetX = (sw - C.WIDTH * scale) / 2
    local offsetY = (sh - C.HEIGHT * scale) / 2

    love.graphics.push()
    love.graphics.translate(offsetX, offsetY)
    love.graphics.scale(scale)

    if game then
        game:draw()
    end

    love.graphics.pop()
end

-- Convert screen coords to game coords
local function screenToGame(x, y)
    local sw, sh = love.window.getMode()
    local scaleX = sw / C.WIDTH
    local scaleY = sh / C.HEIGHT
    local scale = math.min(scaleX, scaleY)
    local offsetX = (sw - C.WIDTH * scale) / 2
    local offsetY = (sh - C.HEIGHT * scale) / 2

    local gx = (x - offsetX) / scale
    local gy = (y - offsetY) / scale
    return gx, gy
end

function love.mousepressed(x, y, button, istouch, presses)
    if button ~= 1 then return end
    local gx, gy = screenToGame(x, y)
    if gx >= 0 and gx <= C.WIDTH and gy >= 0 and gy <= C.HEIGHT then
        if game then
            game:onPress(gx, gy)
        end
    end
end

-- Touch input (multi-touch)
function love.touchpressed(id, x, y, dx, dy, pressure)
    local gx, gy = screenToGame(x, y)
    if game then
        Haptics.press()
        game:onPress(gx, gy)
    end
end

-- Keyboard / Android back button
function love.keypressed(key)
    if key == "escape" or key == "back" or key == "backspace" then
        if game then
            game:onBack()
        end
    end
    if key == "p" or key == "pause" then
        if game then
            game:onPauseTap()
        end
    end
end

function love.quit()
    if game then
        local PS = require("game.meta.PlayerState")
        PS:discardRun()
    end
    return false
end