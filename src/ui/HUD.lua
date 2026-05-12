-- HUD: in-game heads-up display
local C = require("consts")
local PS = require("game.meta.PlayerState")

local HUD = {}
HUD.__index = HUD

function HUD.new(gameLoop)
    local self = setmetatable({}, HUD)
    self.gameLoop = gameLoop
    self.group = display.newGroup()
    self.group.isHitTestable = false

    -- Wave counter
    self.waveText = display.newText({
        parent = self.group,
        text = "WAVE 1",
        x = 30,
        y = 30,
        font = native.systemFontBold,
        fontSize = 28,
        align = "left",
    })
    self.waveText:setFillColor(unpack(C.COLOR.UI_TEXT))
    self.waveText.anchorX = 0
    self.waveText.anchorY = 0

    -- Gold
    self.goldText = display.newText({
        parent = self.group,
        text = "0",
        x = 30,
        y = 65,
        font = native.systemFontBold,
        fontSize = 24,
        align = "left",
    })
    self.goldText:setFillColor(unpack(C.COLOR.GOLD))
    self.goldText.anchorX = 0
    self.goldText.anchorY = 0

    -- Gold icon (small circle)
    self.goldIcon = display.newCircle(self.group, 18, 74, 8)
    self.goldIcon:setFillColor(unpack(C.COLOR.GOLD))

    -- HP bar background
    self.hpBarBg = display.newRect(self.group, C.WIDTH - 160, 30, 140, 20)
    self.hpBarBg:setFillColor(unpack(C.COLOR.HP_BAR_BG))
    self.hpBarBg.anchorX = 0

    -- HP bar fill
    self.hpBar = display.newRect(self.group, C.WIDTH - 160, 30, 140, 20)
    self.hpBar:setFillColor(unpack(C.COLOR.HP_BAR))
    self.hpBar.anchorX = 0

    -- HP label
    self.hpText = display.newText({
        parent = self.group,
        text = "HP",
        x = C.WIDTH - 170,
        y = 31,
        font = native.systemFont,
        fontSize = 14,
        align = "right",
    })
    self.hpText:setFillColor(1, 1, 1)
    self.hpText.anchorX = 1
    self.hpText.anchorY = 0

    -- XP bar background
    self.xpBarBg = display.newRect(self.group, C.WIDTH - 160, 60, 140, 12)
    self.xpBarBg:setFillColor(unpack(C.COLOR.XP_BAR_BG))
    self.xpBarBg.anchorX = 0

    -- XP bar fill
    self.xpBar = display.newRect(self.group, C.WIDTH - 160, 60, 0, 12)
    self.xpBar:setFillColor(unpack(C.COLOR.XP_BAR))
    self.xpBar.anchorX = 0

    -- Player level badge
    self.levelText = display.newText({
        parent = self.group,
        text = "LV.1",
        x = C.WIDTH - 30,
        y = C.HEIGHT - 40,
        font = native.systemFontBold,
        fontSize = 20,
        align = "right",
    })
    self.levelText:setFillColor(unpack(C.COLOR.ACCENT))
    self.levelText.anchorX = 1
    self.levelText.anchorY = 1

    -- Pause button
    self.pauseBtn = display.newRect(self.group, 30, C.HEIGHT - 40, 80, 44)
    self.pauseBtn:setFillColor(0.2, 0.2, 0.3)
    self.pauseBtn:setStrokeColor(0.4, 0.4, 0.5)
    self.pauseBtn.strokeWidth = 1
    self.pauseBtn.isHitTestable = true
    self.pauseBtn:addEventListener("tap", function()
        self.gameLoop:onPauseTap()
    end)

    self.pauseLabel = display.newText({
        parent = self.group,
        text = "PAUSE",
        x = 30,
        y = C.HEIGHT - 40,
        font = native.systemFontBold,
        fontSize = 16,
        align = "center",
    })
    self.pauseLabel:setFillColor(1, 1, 1)

    -- Wave transition text
    self.transitionText = display.newText({
        parent = self.group,
        text = "",
        x = C.CENTER_X,
        y = C.CENTER_Y - 100,
        font = native.systemFontBold,
        fontSize = 36,
        align = "center",
    })
    self.transitionText:setFillColor(1, 1, 1)
    self.transitionText.isVisible = false

    return self
end

function HUD:update(waveNumber)
    self.waveText.text = "WAVE " .. waveNumber
    self.goldText.text = tostring(PS.run.gold)

    -- HP bar
    local maxHP = C.BASE_HP
    local hpRatio = math.max(0, PS.run.hp / maxHP)
    self.hpBar.width = 140 * hpRatio

    -- XP bar
    local xpNeeded = PS:xpToNextLevel()
    local xpRatio = math.min(1, PS.run.xp / xpNeeded)
    self.xpBar.width = 140 * xpRatio

    -- Level
    self.levelText.text = "LV." .. PS.data.playerLevel

    -- Wave transition countdown
    local wm = self.gameLoop.waveManager
    if wm:isInTransition() then
        local t = math.ceil(wm:getTransitionTime())
        self.transitionText.text = "NEXT WAVE IN " .. t
        self.transitionText.isVisible = true
    else
        self.transitionText.isVisible = false
    end
end

function HUD:show()
    self.group.isVisible = true
end

function HUD:hide()
    self.group.isVisible = false
end

function HUD:destroy()
    self.group:removeSelf()
end

return HUD