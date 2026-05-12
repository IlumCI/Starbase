-- UpgradeScreen: 3-card upgrade selection modal (LÖVE2D version)
local C = require("consts")

local UpgradeScreen = {}
UpgradeScreen.__index = UpgradeScreen

function UpgradeScreen.new(gameLoop)
    local self = setmetatable({}, UpgradeScreen)
    self.gameLoop = gameLoop
    self.canvas = love.graphics.newCanvas(C.WIDTH, C.HEIGHT)
    self.visible = false

    self.cardWidth = 280
    self.cardHeight = 360
    self.cardSpacing = 20

    -- Cards
    self.cards = {}
    local cardCount = 3
    local totalWidth = cardCount * self.cardWidth + (cardCount - 1) * self.cardSpacing
    local startX = C.CENTER_X - totalWidth / 2

    for i = 1, cardCount do
        local cx = startX + (i - 1) * (self.cardWidth + self.cardSpacing)
        local cy = C.CENTER_Y + 50
        table.insert(self.cards, {
            x = cx, y = cy,
            w = self.cardWidth, h = self.cardHeight,
            upgradeId = nil,
            name = "???",
            desc = "???",
            color = C.COLOR.ACCENT,
            visible = false,
            index = i,
        })
    end

    self:buildCanvas()
    return self
end

function UpgradeScreen:buildCanvas()
    self.canvas:renderTo(function()
        self:drawContent()
    end)
end

function UpgradeScreen:drawContent()
    -- Dimmed overlay
    love.graphics.setColor(unpack(C.COLOR.OVERLAY))
    love.graphics.rectangle("fill", 0, 0, C.WIDTH, C.HEIGHT)

    -- Title
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print("WAVE COMPLETE", C.CENTER_X - 90, 150)

    -- Subtitle
    love.graphics.setColor(0.7, 0.7, 0.7, 1)
    love.graphics.print("Choose your upgrade", C.CENTER_X - 85, 195)

    -- Cards
    for _, card in ipairs(self.cards) do
        if card.visible then
            local c = card.color

            -- Card background
            love.graphics.setColor(0.15, 0.15, 0.22, 1)
            love.graphics.rectangle("fill", card.x, card.y, card.w, card.h)

            -- Card stroke
            love.graphics.setColor(unpack(c))
            love.graphics.rectangle("line", card.x, card.y, card.w, card.h)

            -- Icon background circle
            love.graphics.setColor(c[1], c[2], c[3], 0.4)
            love.graphics.circle("fill", card.x + card.w / 2, card.y + 70, 40)

            -- Icon circle
            love.graphics.setColor(unpack(c))
            love.graphics.circle("fill", card.x + card.w / 2, card.y + 70, 30)

            -- Name
            love.graphics.setColor(1, 1, 1, 1)
            love.graphics.print(card.name, card.x + 20, card.y + 140)

            -- Description (may wrap)
            love.graphics.setColor(0.7, 0.7, 0.7, 1)
            local desc = card.desc
            local maxCharsPerLine = 22
            -- Simple word wrap
            while #desc > 0 do
                local cut = math.min(maxCharsPerLine, #desc)
                love.graphics.print(desc:sub(1, cut), card.x + 20, card.y + 180)
                desc = desc:sub(cut + 1)
                if #desc > 0 then
                    love.graphics.print(desc:sub(1, cut), card.x + 20, card.y + 200)
                    break
                end
            end
        end
    end
end

function UpgradeScreen:show(choices)
    self.visible = true

    for i, card in ipairs(self.cards) do
        local data = choices[i]
        if data then
            card.visible = true
            card.upgradeId = data.id
            card.name = data.name
            card.desc = data.desc

            -- Color by category
            local color
            if data.temp then
                if data.category == "damage" then
                    color = { 1, 0.3, 0.3 }
                elseif data.category == "fire_rate" then
                    color = { 1, 0.6, 0.1 }
                elseif data.category == "range" then
                    color = { 0.3, 0.8, 1 }
                elseif data.category == "gold" then
                    color = C.COLOR.GOLD
                elseif data.category == "defense" then
                    color = C.COLOR.HP_BAR
                elseif data.category == "utility" then
                    color = { 0.5, 0.5, 1 }
                else
                    color = C.COLOR.ACCENT
                end
            else
                color = { 0.8, 0.6, 1 }
            end
            card.color = color
        else
            card.visible = false
            card.upgradeId = nil
        end
    end

    self:buildCanvas()
end

function UpgradeScreen:hide()
    self.visible = false
end

function UpgradeScreen:destroy()
    self.canvas = nil
end

function UpgradeScreen:onMousePressed(x, y, button)
    if not self.visible then return false end
    if button ~= 1 then return false end

    for _, card in ipairs(self.cards) do
        if card.visible then
            if x >= card.x and x <= card.x + card.w and y >= card.y and y <= card.y + card.h then
                if card.upgradeId then
                    self.gameLoop:onUpgradeSelected(card.upgradeId)
                end
                return true
            end
        end
    end

    return false
end

return UpgradeScreen
