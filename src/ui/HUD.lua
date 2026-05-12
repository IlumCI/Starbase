-- HUD: in-game heads-up display (LÖVE2D version)
local C = require("consts")
local PS = require("game.meta.PlayerState")

local HUD = {}
HUD.__index = HUD

function HUD.new(gameLoop)
    local self = setmetatable({}, HUD)
    self.gameLoop = gameLoop
    self.canvas = love.graphics.newCanvas(C.WIDTH, C.HEIGHT)
    self.visible = false
    self.waveNumber = 1

    -- Pause button hitbox (set after canvas creation)
    self.pauseBtn = { x = 30, y = C.HEIGHT - 62, w = 80, h = 44 }

    self:buildCanvas()
    return self
end

function HUD:buildCanvas()
    self.canvas:renderTo(function()
        -- Wave text
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("WAVE 1", 30, 20)

        -- Gold icon (small circle)
        love.graphics.setColor(unpack(C.COLOR.GOLD))
        love.graphics.circle("fill", 18, 60, 8)

        -- Gold text
        love.graphics.setColor(unpack(C.COLOR.GOLD))
        love.graphics.print("0", 30, 50)

        -- HP bar background
        love.graphics.setColor(unpack(C.COLOR.HP_BAR_BG))
        love.graphics.rectangle("fill", C.WIDTH - 160, 20, 140, 20)

        -- HP bar fill (0 width initially)
        love.graphics.setColor(unpack(C.COLOR.HP_BAR))
        love.graphics.rectangle("fill", C.WIDTH - 160, 20, 140, 20)

        -- HP label
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("HP", C.WIDTH - 170, 21)

        -- XP bar background
        love.graphics.setColor(unpack(C.COLOR.XP_BAR_BG))
        love.graphics.rectangle("fill", C.WIDTH - 160, 50, 140, 12)

        -- XP bar fill (0 width initially)
        love.graphics.setColor(unpack(C.COLOR.XP_BAR))
        love.graphics.rectangle("fill", C.WIDTH - 160, 50, 0, 12)

        -- Player level badge
        love.graphics.setColor(unpack(C.COLOR.ACCENT))
        love.graphics.print("LV.1", C.WIDTH - 60, C.HEIGHT - 60)

        -- Pause button background
        love.graphics.setColor(0.2, 0.2, 0.3, 1)
        love.graphics.rectangle("fill", self.pauseBtn.x, self.pauseBtn.y, self.pauseBtn.w, self.pauseBtn.h)

        -- Pause button stroke
        love.graphics.setColor(0.4, 0.4, 0.5, 1)
        love.graphics.rectangle("line", self.pauseBtn.x, self.pauseBtn.y, self.pauseBtn.w, self.pauseBtn.h)

        -- Pause button label
        love.graphics.setColor(1, 1, 1, 1)
        local px, py = self.pauseBtn.x, self.pauseBtn.y
        love.graphics.print("PAUSE", px + 6, py + 13)

        -- Wave transition text (placeholder, drawn elsewhere)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("", C.CENTER_X, C.CENTER_Y - 100)
    end)
end

function HUD:update(waveNumber)
    self.waveNumber = waveNumber

    self.canvas:renderTo(function()
        -- Wave text
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("WAVE " .. waveNumber, 30, 20)

        -- Gold text
        love.graphics.setColor(unpack(C.COLOR.GOLD))
        love.graphics.circle("fill", 18, 60, 8)
        love.graphics.print(tostring(PS.run.gold), 30, 50)

        -- HP bar
        local maxHP = C.BASE_HP
        local hpRatio = math.max(0, PS.run.hp / maxHP)
        love.graphics.setColor(unpack(C.COLOR.HP_BAR_BG))
        love.graphics.rectangle("fill", C.WIDTH - 160, 20, 140, 20)
        love.graphics.setColor(unpack(C.COLOR.HP_BAR))
        love.graphics.rectangle("fill", C.WIDTH - 160, 20, 140 * hpRatio, 20)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("HP", C.WIDTH - 170, 21)

        -- XP bar
        local xpNeeded = PS:xpToNextLevel()
        local xpRatio = math.min(1, PS.run.xp / xpNeeded)
        love.graphics.setColor(unpack(C.COLOR.XP_BAR_BG))
        love.graphics.rectangle("fill", C.WIDTH - 160, 50, 140, 12)
        love.graphics.setColor(unpack(C.COLOR.XP_BAR))
        love.graphics.rectangle("fill", C.WIDTH - 160, 50, 140 * xpRatio, 12)

        -- Player level
        love.graphics.setColor(unpack(C.COLOR.ACCENT))
        love.graphics.print("LV." .. PS.data.playerLevel, C.WIDTH - 60, C.HEIGHT - 60)

        -- Pause button
        love.graphics.setColor(0.2, 0.2, 0.3, 1)
        love.graphics.rectangle("fill", self.pauseBtn.x, self.pauseBtn.y, self.pauseBtn.w, self.pauseBtn.h)
        love.graphics.setColor(0.4, 0.4, 0.5, 1)
        love.graphics.rectangle("line", self.pauseBtn.x, self.pauseBtn.y, self.pauseBtn.w, self.pauseBtn.h)
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.print("PAUSE", self.pauseBtn.x + 6, self.pauseBtn.y + 13)

        -- Wave transition countdown
        local wm = self.gameLoop.waveManager
        if wm and wm:isInTransition() then
            local t = math.ceil(wm:getTransitionTime())
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print("NEXT WAVE IN " .. t, C.CENTER_X - 80, C.CENTER_Y - 120)
        end
    end)
end

function HUD:show()
    self.visible = true
end

function HUD:hide()
    self.visible = false
end

function HUD:destroy()
    self.canvas = nil
end

function HUD:onPress(x, y)
    local btn = self.pauseBtn
    if x >= btn.x and x <= btn.x + btn.w and y >= btn.y and y <= btn.y + btn.h then
        self.gameLoop:onPauseTap()
        return { btn.x, btn.y, btn.w, btn.h, 0.4, 0.4, 0.5 }
    end
    return nil
end

return HUD
