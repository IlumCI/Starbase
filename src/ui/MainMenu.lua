-- MainMenu: meta screen (start run, view stats, upgrade turrets)
local C = require("consts")
local PS = require("game.meta.PlayerState")

local MainMenu = {}
MainMenu.__index = MainMenu

function MainMenu.new(gameLoop)
    local self = setmetatable({}, MainMenu)
    self.gameLoop = gameLoop
    self.group = display.newGroup()

    -- Title
    self.titleText = display.newText({
        parent = self.group,
        text = "ZEN FORTRESS",
        x = C.CENTER_X,
        y = 180,
        font = native.systemFontBold,
        fontSize = 48,
        align = "center",
    })
    self.titleText:setFillColor(unpack(C.COLOR.TURRET))

    -- Subtitle
    self.subText = display.newText({
        parent = self.group,
        text = "Infinite Defense",
        x = C.CENTER_X,
        y = 235,
        font = native.systemFont,
        fontSize = 20,
        align = "center",
    })
    self.subText:setFillColor(0.5, 0.5, 0.6)

    -- Start button
    self.startBtn = display.newRoundedRect(self.group, C.CENTER_X, 340, 300, 70, 16)
    self.startBtn:setFillColor(0, 0.6, 0.4)
    self.startBtn:setStrokeColor(0, 1, 0.6, 0.4)
    self.startBtn.strokeWidth = 2
    self.startBtn.isHitTestable = true
    self.startBtn:addEventListener("tap", function()
        self:onStartTap()
        return true
    end)

    self.startLabel = display.newText({
        parent = self.group,
        text = "START RUN",
        x = C.CENTER_X,
        y = 340,
        font = native.systemFontBold,
        fontSize = 26,
        align = "center",
    })
    self.startLabel:setFillColor(1, 1, 1)

    -- Divider
    self:makeDivider(430)

    -- Turret section label
    self.turretLabel = display.newText({
        parent = self.group,
        text = "TURRETS (tap to level up)",
        x = C.CENTER_X,
        y = 460,
        font = native.systemFontBold,
        fontSize = 18,
        align = "center",
    })
    self.turretLabel:setFillColor(0.6, 0.6, 0.7)

    -- Turret cards
    self.turretCards = {}
    local turretTypes = { "BLASTER", "CANNON", "SNIPER", "ZAPPER" }
    local cols = 2
    local cardW, cardH = 300, 100
    local startX = C.CENTER_X - cardW - 10
    local startY = 540
    local spacingY = 120

    for i, tkey in ipairs(turretTypes) do
        local col = (i - 1) % cols
        local row = math.floor((i - 1) / cols)
        local cx = startX + col * (cardW + 20)
        local cy = startY + row * spacingY
        local card = self:makeTurretCard(cx, cy, cardW, cardH, tkey)
        table.insert(self.turretCards, card)
    end

    -- Divider
    self:makeDivider(810)

    -- Stats section
    self.statsLabel = display.newText({
        parent = self.group,
        text = "STATS",
        x = C.CENTER_X,
        y = 840,
        font = native.systemFontBold,
        fontSize = 18,
        align = "center",
    })
    self.statsLabel:setFillColor(0.6, 0.6, 0.7)

    self.statsText = display.newText({
        parent = self.group,
        text = "Waves Cleared: 0\nPlayer Level: 1\nHighest Wave: 0",
        x = C.CENTER_X,
        y = 900,
        font = native.systemFont,
        fontSize = 18,
        align = "center",
    })
    self.statsText:setFillColor(0.7, 0.7, 0.8)

    -- Banked gold
    self.goldText = display.newText({
        parent = self.group,
        text = "Banked Gold: 0",
        x = C.CENTER_X,
        y = 1000,
        font = native.systemFontBold,
        fontSize = 22,
        align = "center",
    })
    self.goldText:setFillColor(unpack(C.COLOR.GOLD))

    -- Banked gold icon
    self.goldIcon = display.newCircle(self.group, C.CENTER_X - 130, 1000, 10)
    self.goldIcon:setFillColor(unpack(C.COLOR.GOLD))

    -- Continue button (if previous run was in progress)
    self.continueBtn = display.newRoundedRect(self.group, C.CENTER_X, 1100, 300, 60, 12)
    self.continueBtn:setFillColor(0.2, 0.2, 0.35)
    self.continueBtn:setStrokeColor(0.4, 0.4, 0.5)
    self.continueBtn.strokeWidth = 1
    self.continueBtn.isHitTestable = true
    self.continueBtn:addEventListener("tap", function()
        self:onContinueTap()
        return true
    end)
    self.continueBtn.isVisible = false

    self.continueLabel = display.newText({
        parent = self.group,
        text = "CONTINUE LAST RUN",
        x = C.CENTER_X,
        y = 1100,
        font = native.systemFontBold,
        fontSize = 18,
        align = "center",
    })
    self.continueLabel:setFillColor(0.6, 0.6, 0.8)
    self.continueLabel.isVisible = false

    return self
end

function MainMenu:makeDivider(y)
    local line = display.newLine(self.group, 100, y, C.WIDTH - 100, y)
    line:setStrokeColor(0.3, 0.3, 0.4, 0.5)
    line.strokeWidth = 1
end

function MainMenu:makeTurretCard(x, y, w, h, tkey)
    local card = {}
    card.tkey = tkey
    card.group = display.newGroup()
    card.group.x = x
    card.group.y = y
    self.group:insert(card.group)

    card.bg = display.newRoundedRect(card.group, 0, 0, w, h, 12)
    local def = C.TURRET[tkey]
    card.bg:setFillColor(0.12, 0.12, 0.18)
    card.bg:setStrokeColor(def.color[1], def.color[2], def.color[3], 0.5)
    card.bg.strokeWidth = 2
    card.bg.isHitTestable = true

    card.typeText = display.newText({
        parent = card.group,
        text = tkey,
        x = 20,
        y = -10,
        font = native.systemFontBold,
        fontSize = 18,
        align = "left",
        width = w - 80,
    })
    card.typeText:setFillColor(1, 1, 1)
    card.typeText.anchorX = 0

    card.levelText = display.newText({
        parent = card.group,
        text = "Lv.1",
        x = w - 80,
        y = -10,
        font = native.systemFontBold,
        fontSize = 18,
        align = "right",
    })
    card.levelText:setFillColor(unpack(C.COLOR.ACCENT))
    card.levelText.anchorX = 1

    card.costText = display.newText({
        parent = card.group,
        text = "50g to upgrade",
        x = 20,
        y = 25,
        font = native.systemFont,
        fontSize = 14,
        align = "left",
    })
    card.costText:setFillColor(0.5, 0.5, 0.6)
    card.costText.anchorX = 0

    card.lockedText = display.newText({
        parent = card.group,
        text = "LOCKED",
        x = 0,
        y = 0,
        font = native.systemFontBold,
        fontSize = 16,
        align = "center",
    })
    card.lockedText:setFillColor(0.4, 0.4, 0.4)
    card.lockedText.isVisible = false

    card.tapHandler = function()
        self:onTurretTap(tkey, card)
    end
    card.bg:addEventListener("tap", card.tapHandler)

    return card
end

function MainMenu:onTurretTap(tkey, card)
    if not PS:isTurretUnlocked(tkey) then return end
    local cost = PS:turretUpgradeCost(tkey)
    if PS.data.bankedGold < cost then return end
    if PS:getTurretLevel(tkey) >= C.TURRET_LEVEL.MAX_LEVEL then return end
    local ok = PS:upgradeTurret(tkey)
    if ok then
        -- Visual feedback
        card.bg:setFillColor(0.2, 0.3, 0.2)
        timer.performWithDelay(200, function()
            card.bg:setFillColor(0.12, 0.12, 0.18)
        end)
        self:refresh()
    end
end

function MainMenu:onStartTap()
    self.group.isVisible = false
    self.gameLoop:startRun()
end

function MainMenu:onContinueTap()
    self.group.isVisible = false
    self.gameLoop:state = C.STATE.PLAYING
end

function MainMenu:refresh()
    -- Update stats
    self.statsText.text = string.format(
        "Waves Cleared: %d\nPlayer Level: %d\nHighest Wave: %d",
        PS.data.wavesCleared,
        PS.data.playerLevel,
        PS.data.highestWave
    )
    self.goldText.text = "Banked Gold: " .. PS.data.bankedGold

    -- Update turret cards
    for _, card in ipairs(self.turretCards) do
        local tkey = card.tkey
        local unlocked = PS:isTurretUnlocked(tkey)
        local lvl = PS:getTurretLevel(tkey)
        card.levelText.text = "Lv." .. lvl

        if not unlocked then
            card.lockedText.isVisible = true
            card.bg:setStrokeColor(0.2, 0.2, 0.2)
            card.bg:setFillColor(0.08, 0.08, 0.1)
            card.costText.text = "Unlock via upgrade"
            card.costText:setFillColor(0.3, 0.3, 0.3)
        else
            card.lockedText.isVisible = false
            local def = C.TURRET[tkey]
            card.bg:setStrokeColor(def.color[1], def.color[2], def.color[3], 0.5)
            card.bg:setFillColor(0.12, 0.12, 0.18)

            if lvl >= C.TURRET_LEVEL.MAX_LEVEL then
                card.costText.text = "MAX LEVEL"
                card.costText:setFillColor(0.3, 0.8, 0.3)
            else
                local cost = PS:turretUpgradeCost(tkey)
                card.costText.text = cost .. "g to upgrade"
                card.costText:setFillColor(0.5, 0.5, 0.6)
            end
        end
    end

    -- Show continue button if there was a run in progress
    local hasRun = PS.data.wavesCleared > 0
    self.continueBtn.isVisible = hasRun
    self.continueLabel.isVisible = hasRun
end

function MainMenu:show()
    self:refresh()
    self.group.isVisible = true
end

function MainMenu:hide()
    self.group.isVisible = false
end

function MainMenu:destroy()
    self.group:removeSelf()
end

return MainMenu