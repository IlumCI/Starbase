-- PauseMenu: pause overlay (LÖVE2D version)
local C = require("consts")
local PS = require("game.meta.PlayerState")

local PauseMenu = {}
PauseMenu.__index = PauseMenu

function PauseMenu.new(gameLoop)
    local self = setmetatable({}, PauseMenu)
    self.gameLoop = gameLoop
    self.canvas = love.graphics.newCanvas(C.WIDTH, C.HEIGHT)
    self.visible = false

    -- Stats display lines
    self.statsLines = {
        "Wave: 0  |  Gold: 0  |  LV.1",
    }

    -- Buttons
    self.buttons = {}

    local btnW, btnH = 300, 60
    local startY = C.CENTER_Y - 50
    local spacing = 80

    table.insert(self.buttons, {
        x = C.CENTER_X - btnW / 2, y = startY, w = btnW, h = btnH,
        label = "RESUME",
        onTap = function()
            self:hide()
            self.gameLoop.state = C.STATE.PLAYING
        end,
        color = { 0.2, 0.5, 0.2 },
    })

    table.insert(self.buttons, {
        x = C.CENTER_X - btnW / 2, y = startY + spacing, w = btnW, h = btnH,
        label = "BANK & EXIT",
        onTap = function()
            PS:bankProgress()
            self:hide()
            self.gameLoop:showMenuUI()
            self.gameLoop.state = C.STATE.MENU
        end,
        color = { 0.3, 0.3, 0.5 },
    })

    table.insert(self.buttons, {
        x = C.CENTER_X - btnW / 2, y = startY + spacing * 2, w = btnW, h = btnH,
        label = "QUIT (DISCARD)",
        onTap = function()
            PS:discardRun()
            self:hide()
            self.gameLoop:showMenuUI()
            self.gameLoop.state = C.STATE.MENU
        end,
        color = { 0.5, 0.2, 0.2 },
    })

    self:buildCanvas()
    return self
end

function PauseMenu:buildCanvas()
    self.canvas:renderTo(function()
        self:drawContent()
    end)
end

function PauseMenu:drawContent()
    -- Dimmed overlay
    love.graphics.setColor(unpack(C.COLOR.OVERLAY))
    love.graphics.rectangle("fill", 0, 0, C.WIDTH, C.HEIGHT)

    -- Title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("PAUSED", C.CENTER_X - 55, C.CENTER_Y - 220)

    -- Stats
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.print(self.statsLines[1], C.CENTER_X - 120, C.CENTER_Y - 160)

    -- Buttons
    for _, btn in ipairs(self.buttons) do
        love.graphics.setColor(unpack(btn.color))
        love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h)
        love.graphics.setColor(1, 1, 1, 0.2)
        love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(btn.label, btn.x + 70, btn.y + 20)
    end
end

function PauseMenu:update()
    self.statsLines[1] = string.format(
        "Wave: %d  |  Gold: %d  |  LV.%d",
        PS.run.wave, PS.run.gold, PS.data.playerLevel
    )
    self:buildCanvas()
end

function PauseMenu:show()
    self:update()
    self.visible = true
end

function PauseMenu:hide()
    self.visible = false
end

function PauseMenu:destroy()
    self.canvas = nil
end

function PauseMenu:onPress(x, y)
    for _, btn in ipairs(self.buttons) do
        if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
            btn.onTap()
            return { x = btn.x, y = btn.y, w = btn.w, h = btn.h, r = btn.color[1], g = btn.color[2], b = btn.color[3] }
        end
    end
    return nil
end

return PauseMenu
