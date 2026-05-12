-- MainMenu: meta screen (start run, view stats, upgrade turrets) (LÖVE2D version)
local C = require("consts")
local PS = require("game.meta.PlayerState")

local MainMenu = {}
MainMenu.__index = MainMenu

function MainMenu.new(gameLoop)
    local self = setmetatable({}, MainMenu)
    self.gameLoop = gameLoop
    self.canvas = love.graphics.newCanvas(C.WIDTH, C.HEIGHT)
    self.visible = false

    -- Button definitions
    self.buttons = {}

    -- Start button
    table.insert(self.buttons, {
        x = C.CENTER_X - 150, y = 305, w = 300, h = 70,
        label = "START RUN",
        onTap = function() self:onStartTap() end,
        color = { 0, 0.6, 0.4 },
    })

    -- Turret cards (2x2 grid)
    self.turretCards = {}
    local turretTypes = { "BLASTER", "CANNON", "SNIPER", "ZAPPER" }
    local cardW, cardH = 300, 100
    local cols = 2
    local startX = C.CENTER_X - cardW - 10
    local startY = 500
    local spacingX = cardW + 20
    local spacingY = 120

    for i, tkey in ipairs(turretTypes) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local cx = startX + col * spacingX
        local cy = startY + row * spacingY
        table.insert(self.turretCards, {
            tkey = tkey,
            x = cx, y = cy, w = cardW, h = cardH,
            levelText = "Lv.1",
            costText = "50g to upgrade",
            locked = false,
            maxLevel = false,
        })
    end

    -- Stats data
    self.statsLines = {
        "Waves Cleared: 0",
        "Player Level: 1",
        "Highest Wave: 0",
    }

    -- Banked gold
    self.bankedGold = 0

    -- Continue button
    table.insert(self.buttons, {
        x = C.CENTER_X - 150, y = 1070, w = 300, h = 60,
        label = "CONTINUE LAST RUN",
        onTap = function() self:onContinueTap() end,
        color = { 0.2, 0.2, 0.35 },
        visible = false,
    })

    self:buildCanvas()
    return self
end

function MainMenu:buildCanvas()
    self.canvas:renderTo(function()
        self:drawContent()
    end)
end

function MainMenu:drawContent()
    -- Title
    love.graphics.setColor(unpack(C.COLOR.TURRET))
    love.graphics.print("ZEN FORTRESS", C.CENTER_X - 120, 170)

    -- Subtitle
    love.graphics.setColor(0.5, 0.5, 0.6, 1)
    love.graphics.print("Infinite Defense", C.CENTER_X - 75, 225)

    -- Start button
    for _, btn in ipairs(self.buttons) do
        if btn.label == "START RUN" then
            love.graphics.setColor(unpack(btn.color))
            love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h)
            love.graphics.setColor(0, 1, 0.6, 0.4)
            love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h)
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(btn.label, btn.x + 75, btn.y + 22)
        end
    end

    -- Divider
    love.graphics.setColor(0.3, 0.3, 0.4, 0.5)
    love.graphics.line(100, 420, C.WIDTH - 100, 420)

    -- Turret section label
    love.graphics.setColor(0.6, 0.6, 0.7, 1)
    love.graphics.print("TURRETS (tap to level up)", C.CENTER_X - 145, 450)

    -- Turret cards
    for _, card in ipairs(self.turretCards) do
        local def = C.TURRET[card.tkey]
        local bgColor = card.locked and { 0.08, 0.08, 0.1 } or { 0.12, 0.12, 0.18 }
        local strokeColor
        if card.locked then
            strokeColor = { 0.2, 0.2, 0.2 }
        else
            strokeColor = { def.color[1], def.color[2], def.color[3], 0.5 }
        end

        love.graphics.setColor(unpack(bgColor))
        love.graphics.rectangle("fill", card.x, card.y, card.w, card.h)
        love.graphics.setColor(unpack(strokeColor))
        love.graphics.rectangle("line", card.x, card.y, card.w, card.h)

        -- Type name
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print(card.tkey, card.x + 15, card.y + 10)

        -- Level
        love.graphics.setColor(unpack(C.COLOR.ACCENT))
        love.graphics.print(card.levelText, card.x + card.w - 70, card.y + 10)

        -- Cost / status
        if card.locked then
            love.graphics.setColor(0.4, 0.4, 0.4, 1)
            love.graphics.print("LOCKED", card.x + 15, card.y + 40)
        else
            love.graphics.setColor(0.5, 0.5, 0.6, 1)
            love.graphics.print(card.costText, card.x + 15, card.y + 40)
        end
    end

    -- Divider
    love.graphics.setColor(0.3, 0.3, 0.4, 0.5)
    love.graphics.line(100, 810, C.WIDTH - 100, 810)

    -- Stats section label
    love.graphics.setColor(0.6, 0.6, 0.7, 1)
    love.graphics.print("STATS", C.CENTER_X - 30, 840)

    -- Stats lines
    love.graphics.setColor(0.7, 0.7, 0.8, 1)
    local statY = 900
    for _, line in ipairs(self.statsLines) do
        love.graphics.print(line, C.CENTER_X - 100, statY)
        statY = statY + 30
    end

    -- Banked gold
    love.graphics.setColor(unpack(C.COLOR.GOLD))
    love.graphics.circle("fill", C.CENTER_X - 130, 1010, 10)
    love.graphics.setColor(unpack(C.COLOR.GOLD))
    love.graphics.print("Banked Gold: " .. self.bankedGold, C.CENTER_X - 100, 1000)

    -- Continue button
    for _, btn in ipairs(self.buttons) do
        if btn.label == "CONTINUE LAST RUN" then
            if btn.visible then
                love.graphics.setColor(unpack(btn.color))
                love.graphics.rectangle("fill", btn.x, btn.y, btn.w, btn.h)
                love.graphics.setColor(0.4, 0.4, 0.5, 1)
                love.graphics.rectangle("line", btn.x, btn.y, btn.w, btn.h)
                love.graphics.setColor(0.6, 0.6, 0.8, 1)
                love.graphics.print(btn.label, btn.x + 40, btn.y + 20)
            end
        end
    end
end

function MainMenu:onStartTap()
    self.visible = false
    self.gameLoop:startRun()
end

function MainMenu:onContinueTap()
    self.visible = false
    self.gameLoop.state = C.STATE.PLAYING
end

function MainMenu:onTurretTap(tkey, card)
    if card.locked then return end
    if card.maxLevel then return end
    local cost = PS:turretUpgradeCost(tkey)
    if PS.data.bankedGold < cost then return end
    local ok = PS:upgradeTurret(tkey)
    if ok then
        self:refresh()
    end
end

function MainMenu:refresh()
    -- Stats
    self.statsLines = {
        "Waves Cleared: " .. PS.data.wavesCleared,
        "Player Level: " .. PS.data.playerLevel,
        "Highest Wave: " .. PS.data.highestWave,
    }

    -- Banked gold
    self.bankedGold = PS.data.bankedGold

    -- Turret cards
    for _, card in ipairs(self.turretCards) do
        local tkey = card.tkey
        local unlocked = PS:isTurretUnlocked(tkey)
        local lvl = PS:getTurretLevel(tkey)
        card.locked = not unlocked
        card.levelText = "Lv." .. lvl

        if not unlocked then
            card.costText = "Unlock via upgrade"
        else
            if lvl >= C.TURRET_LEVEL.MAX_LEVEL then
                card.maxLevel = true
                card.costText = "MAX LEVEL"
            else
                card.maxLevel = false
                local cost = PS:turretUpgradeCost(tkey)
                card.costText = cost .. "g to upgrade"
            end
        end
    end

    -- Continue button
    local hasRun = PS.data.wavesCleared > 0
    for _, btn in ipairs(self.buttons) do
        if btn.label == "CONTINUE LAST RUN" then
            btn.visible = hasRun
        end
    end

    self:buildCanvas()
end

function MainMenu:show()
    self:refresh()
    self.visible = true
end

function MainMenu:hide()
    self.visible = false
end

function MainMenu:destroy()
    self.canvas = nil
end

function MainMenu:onPress(x, y)
    -- Check turret cards
    for _, card in ipairs(self.turretCards) do
        if x >= card.x and x <= card.x + card.w and y >= card.y and y <= card.y + card.h then
            self:onTurretTap(card.tkey, card)
            return {x=card.x, y=card.y, w=card.w, h=card.h, r=0, g=0.6, b=0.4}
        end
    end

    -- Check buttons
    for _, btn in ipairs(self.buttons) do
        if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
            btn.onTap()
            return {x=btn.x, y=btn.y, w=btn.w, h=btn.h, r=btn.color[1], g=btn.color[2], b=btn.color[3]}
        end
    end

    return nil
end

return MainMenu
