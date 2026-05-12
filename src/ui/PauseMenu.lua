-- PauseMenu: pause overlay
local C = require("consts")
local PS = require("game.meta.PlayerState")

local PauseMenu = {}
PauseMenu.__index = PauseMenu

function PauseMenu.new(gameLoop)
    local self = setmetatable({}, PauseMenu)
    self.gameLoop = gameLoop
    self.group = display.newGroup()
    self.group.isVisible = false

    -- Dimmed background
    self.overlay = display.newRect(self.group, C.CENTER_X, C.CENTER_Y, C.WIDTH, C.HEIGHT)
    self.overlay:setFillColor(unpack(C.COLOR.OVERLAY))
    self.overlay.isHitTestable = true

    -- Title
    self.titleText = display.newText({
        parent = self.group,
        text = "PAUSED",
        x = C.CENTER_X,
        y = C.CENTER_Y - 200,
        font = native.systemFontBold,
        fontSize = 42,
        align = "center",
    })
    self.titleText:setFillColor(1, 1, 1)

    -- Stats
    self.statsText = display.newText({
        parent = self.group,
        text = "Wave: 0  |  Gold: 0  |  LV.1",
        x = C.CENTER_X,
        y = C.CENTER_Y - 140,
        font = native.systemFont,
        fontSize = 18,
        align = "center",
    })
    self.statsText:setFillColor(0.7, 0.7, 0.7)

    -- Buttons
    self.buttons = {}

    local btnW, btnH = 300, 60
    local startY = C.CENTER_Y - 30
    local spacing = 80

    self:addButton("RESUME", startY, function()
        self:hide()
        self.gameLoop.state = C.STATE.PLAYING
    end, { 0.2, 0.5, 0.2 })

    self:addButton("BANK & EXIT", startY + spacing, function()
        PS:bankProgress()
        self:hide()
        self.gameLoop:showMenuUI()
        self.gameLoop.state = C.STATE.MENU
    end, { 0.3, 0.3, 0.5 })

    self:addButton("QUIT (DISCARD)", startY + spacing * 2, function()
        PS:discardRun()
        self:hide()
        self.gameLoop:showMenuUI()
        self.gameLoop.state = C.STATE.MENU
    end, { 0.5, 0.2, 0.2 })

    return self
end

function PauseMenu:addButton(label, y, onTap, color)
    local btn = display.newRoundedRect(self.group, C.CENTER_X, y, 300, 60, 12)
    btn:setFillColor(unpack(color))
    btn:setStrokeColor(1, 1, 1, 0.2)
    btn.strokeWidth = 1
    btn.isHitTestable = true

    local text = display.newText({
        parent = self.group,
        text = label,
        x = C.CENTER_X,
        y = y,
        font = native.systemFontBold,
        fontSize = 20,
        align = "center",
    })
    text:setFillColor(1, 1, 1)

    btn:addEventListener("tap", function()
        if onTap then onTap() end
        return true
    end)

    table.insert(self.buttons, { btn = btn, text = text })
end

function PauseMenu:update()
    self.statsText.text = string.format(
        "Wave: %d  |  Gold: %d  |  LV.%d",
        PS.run.wave, PS.run.gold, PS.data.playerLevel
    )
end

function PauseMenu:show()
    self:update()
    self.group.isVisible = true
end

function PauseMenu:hide()
    self.group.isVisible = false
end

function PauseMenu:destroy()
    self.group:removeSelf()
end

return PauseMenu